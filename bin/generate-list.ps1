param($path)

$manifests = Get-ChildItem "$PSScriptRoot\..\bucket"

$content = @("|App ($($manifests.Length))|Persist|Tag|Description|", "|:-:|:-:|:-:|-|")

foreach ($_ in $manifests) {
    $json = Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable
    $info = @()

    $app = $_.BaseName

    # homepage
    $info += "[$app]($($json.homepage))"

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
