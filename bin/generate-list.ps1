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
    $info += '<a href="./bucket/' + $_.Name + '"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabgox-bucket%2Frefs%2Fheads%2Fmain%2Fbucket%2F' + $_.Name + '&query=%24.version&prefix=v&label=%20" alt="version" /></a>'

    # persist
    $info += if ($json.persist) { '✔️' }else { '➖' }

    # Tag
    ## font
    $tag = @()
    $tag += if ($app -like "Font-*") { '`Font`' }

    ## AutoUpdate
    $tag += if (!$json.autoupdate) { '`NoAutoUpdate`' }

    ## PSModule
    $tag += if ($json.psmodule) { '`PSModule`' }

    $info += $tag -join ' '

    ## description
    function Replace-LastChar {
        param (
            [string]$string,
            [string]$before,
            [string]$after
        )
        $pattern = [regex]::Escape($before) + '(?!.*' + [regex]::Escape($before) + ')'
        return [regex]::Replace($string, $pattern, $after)
    }
    $info += Replace-LastChar $json.description "。" "。<br />"
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
