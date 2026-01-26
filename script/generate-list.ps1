#Requires -PSEdition Core

param(
    [array]$PathList = @("app-list.md", "app-list.zh-CN.md")
)

$manifests = Get-ChildItem "$PSScriptRoot\..\bucket" -Recurse -Filter *.json | Sort-Object { $_.BaseName }

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

function Get-StaticContent($path) {
    $content = Get-Content -Path $path -Encoding UTF8

    $match = $content | Select-String -Pattern "\|App \(\d+\)\|Tag\|Description\|"

    if ($match) {
        $matchLineNumber = ([array]$match.LineNumber)[0]
        $result = $content | Select-Object -First ($matchLineNumber - 1)
        $result
    }
}


foreach ($path in $PathList) {
    $content = @("|App ($($manifests.Length))|Tag|Description|", "|-|:-:|-|")

    $isCN = $path -like "*cn*.md"

    foreach ($mp in $manifests) {

        $json = Get-Content $mp.FullName -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable
        $info = @()

        $app = $mp.BaseName

        # homepage
        $info += "[$app]($($json.homepage))"

        # Tag
        $tag = @()

        ## manifest
        $p = $mp.FullName -replace '^.+bucket\\', '' -replace '\\', '/'

        switch ($json.version) {
            deprecated {
                $tag += '<a href="./bucket/' + $p + '"><img src="https://img.shields.io/badge/deprecated-%23d73a49" style="display:inline" alt="deprecated"/></a>'
            }
            pending {
                $tag += '<a href="./bucket/' + $p + '"><img src="https://img.shields.io/badge/pending-%238957e5" style="display:inline" alt="pending"/></a>'
            }
            renamed {
                (Get-Content $mp.FullName -Raw -Encoding UTF8) -match '(?<!#.*)A-Deny-Manifest\s*(''|")(.+?)(''|")"' | Out-Null
                $newName = $Matches[2]
                $tag += '<a href="./bucket/' + $p + '"><img src="https://img.shields.io/badge/renamed-%231f6feb" style="display:inline" alt="renamed"/></a>'
            }
            Default {
                $tag += '<a href="./bucket/' + $p + '"><img src="https://img.shields.io/badge/active-%2328a745" style="display:inline" alt="active"/></a>'
                # $tag += '<a href="./bucket/' + $p + '"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2F' + $p + '&query=%24.version&prefix=v&label=%20" style="display:inline" alt="version" /></a>'
            }
        }

        ## Persist
        $isPersist = $json.persist
        if ($isPersist) {
            $tag += '[Persist](https://abyss.abgox.com/features/data-persistence#persist)'
        }

        ## Link
        $isLink = Test-ScriptPattern $json '(?<!#.*)(A-New-LinkDirectory|A-New-LinkFile)'
        if ($isLink) {
            $tag += '[Link](https://abyss.abgox.com/features/data-persistence#link)'
        }

        ## RequireAdmin
        $RequireAdmin = Test-ScriptPattern $json '(?<!#.*)(A-Require-Admin|A-Stop-Service.+?-RequireAdmin)'
        if ($RequireAdmin) {
            $tag += '[RequireAdmin](https://abyss.abgox.com/faq/require-admin)'
        }

        ## RequireAdminOrDevMode
        $RequireAdminOrDevMode = Test-ScriptPattern $json '(?<!#.*)A-New-LinkFile'
        if ($RequireAdminOrDevMode) {
            $tag += '[RequireAdminOrDevMode](https://abyss.abgox.com/faq/require-admin-or-dev-mode)'
        }

        ## DenyUpdate
        $DenyUpdate = Test-ScriptPattern $json '(?<!#.*)A-Deny-Update'
        if ($DenyUpdate) {
            $tag += '[DenyUpdate](https://abyss.abgox.com/faq/deny-update)'
        }

        ## UninstallManually
        $UninstallManually = Test-ScriptPattern $json '(?<!#.*)A-Uninstall-Manually'
        if ($UninstallManually) {
            $tag += '[UninstallManually](https://abyss.abgox.com/faq/uninstall-manually)'
        }

        ## NoUpdate
        if (!$json.autoupdate) {
            $tag += '[NoUpdate](https://abyss.abgox.com/faq/no-update)'
        }

        ## Font
        if (Test-ScriptPattern $json '(?<!#.*)A-Add-Font') {
            $tag += '[Font](https://abyss.abgox.com/faq/font)'
        }

        ## PSModule
        if ($json.psmodule) {
            $tag += '[PSModule](https://abyss.abgox.com/faq/powershell-module)'
        }

        ## Msix
        $isMsix = Test-ScriptPattern $json '(?<!#.*)A-Add-MsixPackage'
        if ($isMsix) {
            $tag += '[Msix](https://abyss.abgox.com/faq/msix)'
        }

        $info += $tag -join '<br/>'

        ## description
        $description = $json.description -split ' \| '

        for ($i = 0; $i -lt $description.Count; $i++) {
            if ($description[$i] -match '^\(([^)]+)\)\s*(.*)') {
                $description[$i] = @("($($matches[1]))", $matches[2].Trim()) -join '<br/>'
            }
        }


        if ($path -like "*cn*.md") {
            $info += $description[0]
        }
        else {
            if ($description[1]) {
                $info += $description[1]
            }
            else {
                $info += $description[0]
            }
        }

        $content += "|" + ($info -join "|") + "|"
    }

    (Get-StaticContent $path) + $content + "`n<!-- prettier-ignore-end -->" | Out-File $path -Encoding UTF8 -Force
}
