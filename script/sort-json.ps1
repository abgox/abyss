#Requires -Version 7.0

if (-not $env:GITHUB_ACTIONS -and -not $env:SCOOP_HOME) {
    $env:SCOOP_HOME = Convert-Path (scoop prefix scoop)
}

. $env:SCOOP_HOME\lib\json.ps1

$order = [ordered]@{
    '##'           = ''
    version        = ''
    description    = ''
    homepage       = ''
    license        = [ordered]@{
        identifier = ''
        url        = ''
    }
    notes          = ''
    notes_cn       = ''
    depends        = ''
    suggest        = ''
    # url            = ''
    # hash           = ''
    architecture   = [ordered]@{
        '64bit' = [ordered]@{
            url          = ''
            hash         = ''
            extract_dir  = ''
            extract_to   = ''
            env_add_path = ''
            bin          = ''
            shortcuts    = ''
            # pre_install  = ''
            # installer    = ''
            # post_install = ''
            # uninstaller  = ''
        }
        'arm64' = [ordered]@{
            url          = ''
            hash         = ''
            extract_dir  = ''
            extract_to   = ''
            env_add_path = ''
            bin          = ''
            shortcuts    = ''
            # pre_install  = ''
            # installer    = ''
            # post_install = ''
            # uninstaller  = ''
        }
    }
    extract_dir    = ''
    extract_to     = ''
    env_set        = ''
    env_add_path   = ''
    innosetup      = ''
    psmodule       = ''
    commands       = ''
    bin            = ''
    shortcuts      = ''
    persist        = ''
    pre_install    = ''
    # installer      = ''
    post_install   = ''
    pre_uninstall  = ''
    # uninstaller    = ''
    post_uninstall = ''
    checkver       = ''
    autoupdate     = ''
}

$root = Split-Path $PSScriptRoot -Parent

function Sort-JsonByOrder {
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$JsonObject,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Order
    )

    $result = [ordered]@{}

    foreach ($key in $Order.Keys) {
        if ($JsonObject.Contains($key)) {
            $value = $JsonObject[$key]
            $subOrder = $Order[$key]

            if ($value -is [System.Collections.IDictionary] -and
                $subOrder -is [System.Collections.IDictionary]) {

                $result[$key] = Sort-JsonByOrder $value $subOrder
            }
            else {
                $result[$key] = $value
            }
        }
    }

    foreach ($key in $JsonObject.Keys) {
        if (-not $result.Contains($key)) {
            $result[$key] = $JsonObject[$key]
        }
    }

    return $result
}

Get-ChildItem "$root\bucket" -Recurse -File -Filter *.json | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    $json = $content | ConvertFrom-Json -AsHashtable
    $sortedJson = Sort-JsonByOrder -JsonObject $json -Order $order

    $old = $json | ConvertToPrettyJson
    $new = $sortedJson | ConvertToPrettyJson
    if ($new -ne $old) {
        Set-Content -LiteralPath $_.FullName -Value $new -Encoding utf8
    }
}
