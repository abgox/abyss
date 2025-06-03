param($path)

$manifests = Get-ChildItem "$PSScriptRoot\..\bucket"

$content = @("|App ($($manifests.Length))|Version|Persist|Tag|Description|", "|:-:|:-:|:-:|:-:|-|")

function A-Test-ScriptPattern {
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

foreach ($_ in $manifests) {
    $json = Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable
    $info = @()

    $app = $_.BaseName

    # homepage
    $info += "[$app]($($json.homepage))"

    # version
    # $info += "[v$($json.version)](./bucket/$($_.Name))"
    $info += '<a href="./bucket/' + $_.Name + '"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2F' + $_.Name + '&query=%24.version&prefix=v&label=%20" alt="version" /></a>'

    # persist
    $isPersist = $json.persist
    $isLinkDirectory = $false

    if (!$isPersist) {
        $isLinkDirectory = A-Test-ScriptPattern $json '.*(A-New-LinkDirectory)|(A-New-LinkFile).*'
    }
    if ($isLinkDirectory) {
        $info += '`Link`'
    }
    else {
        $info += if ($isPersist) { '✔️' }else { '➖' }
    }

    # Tag
    $tag = @()

    ## Msix
    $isMsix = A-Test-ScriptPattern $json '.*A-Add-MsixPackage.*'
    $tag += if ($isMsix) { '`Msix`' }

    ## NeedAdmin
    $isNeedAdmin = A-Test-ScriptPattern $json '.*A-New-LinkFile.*'
    $tag += if ($isNeedAdmin) { '`Admin`' }

    ## font
    $tag += if ($app -like "Font-*") { '`Font`' }

    ## AutoUpdate
    $tag += if (!$json.autoupdate) { '`NoUpdate`' }

    ## PSModule
    $tag += if ($json.psmodule) { '`PSModule`' }

    $info += $tag -join ' '

    ## description
    $description = $json.description -split '(?<=。)(?=[^。]+$)'

    if ($path -like "*cn*.md") {
        $info += $description[0]
    }
    else {
        $info += $description[1]
    }

    $content += "|" + ($info -join "|") + "|"
}

function get_static_content($path) {
    $content = Get-Content -Path $path -Encoding UTF8

    $match = $content | Select-String -Pattern "<!-- prettier-ignore-start -->"

    if ($match) {
        $matchLineNumber = ([array]$match.LineNumber)[0]
        $result = $content | Select-Object -First $matchLineNumber
        $result
    }
}

(get_static_content $path) + $content + "<!-- prettier-ignore-end -->" | Out-File $path -Encoding UTF8 -Force
