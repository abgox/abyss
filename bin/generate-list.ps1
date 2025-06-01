param($path)

$manifests = Get-ChildItem "$PSScriptRoot\..\bucket"

$content = @("|App ($($manifests.Length))|Version|Persist|Tag|Description|", "|:-:|:-:|:-:|:-:|-|")

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
    $isPersistLink = $false

    if (!$isPersist) {
        function Handle-Persist($obj, $isPersistLink = $isPersistLink) {
            foreach ($_ in @('pre_install', 'post_install', 'pre_uninstall', 'post_uninstall')) {
                if (!$isPersistLink -and $obj.$_) {
                    $isPersistLink = ($obj.$_ -join "`n") -match '.*New-Item.*-ItemType.*Junction.*'
                }
                if (!$isPersistLink -and $obj.$_.script) {
                    $isPersistLink = ($obj.$_.script -join "`n") -match '.*New-Item.*-ItemType.*Junction.*'
                }
            }
            foreach ($_ in @('installer', 'uninstaller')) {
                if (!$isPersistLink -and $obj.$_.script) {
                    $isPersistLink = ($obj.$_.script -join "`n") -match '.*New-Item.*-ItemType.*Junction.*'
                }
            }
            return $isPersistLink
        }
        if ($json.architecture) {
            if ($json.architecture.'64bit') {
                $isPersistLink = Handle-Persist $json.architecture.'64bit'
            }
            if ($json.architecture.'32bit') {
                $isPersistLink = Handle-Persist $json.architecture.'32bit'
            }
            if ($json.architecture.arm64) {
                $isPersistLink = Handle-Persist $json.architecture.arm64
            }
        }
        $isPersistLink = Handle-Persist $json
    }
    if ($isPersistLink) {
        $info += '`Link`'
    }
    else {
        $info += if ($isPersist) { '✔️' }else { '➖' }
    }

    # Tag
    ## font
    $tag = @()
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
