#!/usr/bin/env pwsh
#Requires -Version 7.6.5

param(
    # Directory holding the generated index files.
    # CI passes the `index` branch checkout so main stays free of bot commits.
    [Parameter(Mandatory)]
    [string]$IndexDir
)

if (-not $env:GITHUB_ACTIONS) {
    throw 'It runs in CI only.'
}

$bucketDir = "$PSScriptRoot\..\bucket"
$manifests = Get-ChildItem $bucketDir -Recurse -Filter *.json | Sort-Object { $_.BaseName }

function Test-ScriptPattern {
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$InputObject,

        [Parameter(Mandatory = $true)]
        [string]$Pattern,

        [string[]]$ScriptSections = @('pre_install', 'post_install', 'pre_uninstall', 'post_uninstall'),

        [string[]]$ScriptProperties = @('installer', 'uninstaller')
    )

    function Test-ObjectForPattern {
        param(
            [PSObject]$Object,
            [string]$SearchPattern
        )

        $found = $false

        foreach ($section in $ScriptSections) {
            if (!$found -and $Object.$section) {
                $found = ($Object.$section -join "`n") -match $SearchPattern
            }
        }

        foreach ($property in $ScriptProperties) {
            if (!$found -and $Object.$property.script) {
                $found = ($Object.$property.script -join "`n") -match $SearchPattern
            }
        }

        return $found
    }

    $patternFound = Test-ObjectForPattern -Object $InputObject -SearchPattern $Pattern

    if (!$patternFound -and $InputObject.architecture) {
        if ($InputObject.architecture.'64bit') {
            $patternFound = Test-ObjectForPattern -Object $InputObject.architecture.'64bit' -SearchPattern $Pattern
        }
        if (!$patternFound -and $InputObject.architecture.'32bit') {
            $patternFound = Test-ObjectForPattern -Object $InputObject.architecture.'32bit' -SearchPattern $Pattern
        }
        if (!$patternFound -and $InputObject.architecture.arm64) {
            $patternFound = Test-ObjectForPattern -Object $InputObject.architecture.arm64 -SearchPattern $Pattern
        }
    }

    return $patternFound
}

$jsonManifests = @()

foreach ($mp in $manifests) {
    $json = Get-Content $mp.FullName -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable

    $app = $mp.BaseName

    $status = if ($json.version -in 'pending', 'renamed', 'deprecated', 'virtual') { $json.version } else { 'active' }

    $tags = @()

    ## Persist
    if ($json.persist) {
        $tags += 'Persist'
    }

    ## Link
    $isLink = $json.link -or (Test-ScriptPattern $json '(?<!#.*)A-New-Link(Directory|File)')
    if ($isLink) {
        $tags += 'Link'
    }

    ## RequireAdmin
    $RequireAdmin = $json.admin -or (Test-ScriptPattern $json '(?<!#.*)A-Require-Admin')
    if ($RequireAdmin) {
        $tags += 'Admin'
    }
    else {
        ## RequireAdminOrDevMode
        $RequireAdminOrDevMode = Test-ScriptPattern $json '(?<!#.*)A-New-LinkFile'
        if ($RequireAdminOrDevMode) {
            $tags += 'AdminOrDevMode'
        }
        else {
            foreach ($l in $json.link) {
                if ($l -like '$dir\*') {
                    $p = $l.Replace('$dir\app\', '').Replace('$dir\', '')
                }
                else {
                    try {
                        $p = $ExecutionContext.InvokeCommand.ExpandString($l).Replace("$home\", '')
                    }
                    catch {
                        continue
                    }
                }
                if (Test-Path "$PSScriptRoot\..\extra\$app\$p" -PathType Leaf) {
                    $tags += 'AdminOrDevMode'
                    break
                }
            }
        }
    }

    ## DenyUpdate
    $DenyUpdate = Test-ScriptPattern $json '(?<!#.*)A-Deny-Update'
    if ($DenyUpdate) {
        $tags += 'DenyUpdate'
    }

    ## UninstallManually
    $UninstallManually = Test-ScriptPattern $json '(?<!#.*)A-Uninstall-Manually'
    if ($UninstallManually) {
        $tags += 'UninstallManually'
    }

    ## NoUpdate
    if (!$json.autoupdate -and $json.version -ne 'nightly') {
        $tags += 'NoUpdate'
    }

    ## Font
    if ($json.font) {
        $tags += 'Font'
    }

    ## PSModule
    if ($json.psmodule) {
        $tags += 'PSModule'
    }

    ## Msix
    $isMsix = $json.msix -or (Test-ScriptPattern $json '(?<!#.*)A-Install-MsixPackage')
    if ($isMsix) {
        $tags += 'Msix'
    }

    $m = [ordered]@{
        id          = $app
        homepage    = $json.homepage
        description = $json.description
        status      = $status
        tags        = $tags
    }
    if ($json.renamed) {
        $m.renamed = $json.renamed
    }
    $jsonManifests += $m
}

[ordered]@{ count = $manifests.Length; manifests = $jsonManifests } | ConvertTo-Json -Depth 10 | Out-File (Join-Path $IndexDir 'manifests.json')
