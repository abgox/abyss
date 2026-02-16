#Requires -Version 7.0

param(
    [string]$App = '*',
    [switch]$Recent
)

if (-not $env:GITHUB_ACTIONS -and -not $env:SCOOP_HOME) {
    $env:SCOOP_HOME = Convert-Path (scoop prefix scoop)
}

if (-not $env:SCOOP_HOME) {
    Write-Host "::error::`$env:SCOOP_HOME is not set." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path "$env:SCOOP_HOME\lib\json.ps1")) {
    Write-Host "::error::`$env:SCOOP_HOME\lib\json.ps1 is not found." -ForegroundColor Red
    exit 1
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
        # '32bit' = [ordered]@{
        #     url          = ''
        #     hash         = ''
        #     extract_dir  = ''
        #     extract_to   = ''
        #     env_add_path = ''
        #     bin          = ''
        #     shortcuts    = ''
        #     # pre_install  = ''
        #     # installer    = ''
        #     # post_install = ''
        #     # uninstaller  = ''
        # }
    }
    conflicts      = ''
    extract_dir    = ''
    extract_to     = ''
    env_set        = ''
    env_add_path   = ''
    innosetup      = ''
    psmodule       = ''
    font           = ''
    bin            = ''
    commands       = ''
    shortcuts      = ''
    persist        = ''
    pre_install    = ''
    # installer      = ''
    post_install   = ''
    pre_uninstall  = ''
    # uninstaller    = ''
    post_uninstall = ''
    checkver       = ''
    autoupdate     = [ordered]@{
        architecture = [ordered]@{
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
            # '32bit' = [ordered]@{
            #     url          = ''
            #     hash         = ''
            #     extract_dir  = ''
            #     extract_to   = ''
            #     env_add_path = ''
            #     bin          = ''
            #     shortcuts    = ''
            #     # pre_install  = ''
            #     # installer    = ''
            #     # post_install = ''
            #     # uninstaller  = ''
            # }
        }
        hash         = ''
        extract_dir  = ''
        extract_to   = ''
        env_set      = ''
        env_add_path = ''
        innosetup    = ''
        psmodule     = ''
        bin          = ''
        commands     = ''
        shortcuts    = ''
        persist      = ''
    }
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

            if ($value -is [System.Collections.IDictionary] -and $subOrder -is [System.Collections.IDictionary]) {
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

if ($Recent) {
    Write-Host '::group::Recent Manifests' -ForegroundColor Cyan

    $guid = [Guid]::NewGuid()
    $manifests = git log --since="$([DateTime]::UtcNow.AddDays(-1))" --name-only --pretty=format:"$guid%n" -- 'bucket/' |
    ForEach-Object {
        if ($_ -eq '') { return }
        if ($_ -eq $guid) {
            if ($current) {
                $current
            }
            $current = @()
        }
        else {
            $current += $_
        }
    } |
    Where-Object { $_ -match '\.json$' } |
    Sort-Object -Unique |
    ForEach-Object {
        Write-Host $_
        $fullPath = Join-Path $root $_
        [System.IO.FileInfo]$fullPath
    }

    Write-Host '::endgroup::' -ForegroundColor Cyan
}
else {
    $manifests = Get-ChildItem "$root\bucket" -Recurse -File -Filter "$App.json"
}

foreach ($m in $manifests) {
    $content = Get-Content $m.FullName -Raw
    try {
        $json = $content | ConvertFrom-Json -AsHashtable -ErrorAction Stop
    }
    catch {
        Write-Host "::error::Failed to convert $($m.FullName) to JSON: $_" -ForegroundColor Red
        continue
    }
    $sortedJson = Sort-JsonByOrder -JsonObject $json -Order $order
    $old = $json | ConvertToPrettyJson
    $new = $sortedJson | ConvertToPrettyJson
    if ($new -eq $old) {
        continue
    }
    Set-Content -LiteralPath $m.FullName -Value $new -Encoding utf8
}
