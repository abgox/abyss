#Requires -Version 7.0

param(
    [switch]$All
)

if (-not $env:SCOOP_HOME) {
    if ($env:GITHUB_ACTIONS) {
        $env:SCOOP_HOME = "$env:Temp\ScoopInstaller-Scoop"
        git clone --depth 1 --branch abyss https://github.com/abgox/ScoopInstaller-Scoop $env:SCOOP_HOME
    }
    else {
        try {
            $env:SCOOP_HOME = Convert-Path (scoop prefix scoop)
        }
        catch {
            Write-Host "::error::`$env:SCOOP_HOME is not set." -ForegroundColor Red
            exit 1
        }
    }
}

if (-not (Test-Path "$env:SCOOP_HOME\lib\json.ps1")) {
    Write-Host "::error::`$env:SCOOP_HOME\lib\json.ps1 is not found." -ForegroundColor Red
    exit 1
}

. $env:SCOOP_HOME\lib\json.ps1

$order = [ordered]@{
    '##'                = ''
    version             = ''
    new                 = '' # abyss
    description         = ''
    homepage            = ''
    license             = [ordered]@{
        identifier = ''
        url        = ''
    }
    notes               = ''
    notes_cn            = '' # abyss
    depends             = ''
    suggest             = ''
    # url            = ''
    # hash           = ''
    architecture        = [ordered]@{
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
    conflicts           = '' # abyss
    location            = '' # abyss
    extract_dir         = ''
    extract_to          = ''
    env_set             = ''
    env_set_shared      = '' # abyss
    env_add_path        = ''
    env_add_path_expand = '' # abyss
    innosetup           = ''
    psmodule            = ''
    font                = '' # abyss
    bin                 = ''
    commands            = '' # abyss
    shortcuts           = ''
    link                = '' # abyss
    persist             = ''
    admin               = '' # abyss
    pre_install         = ''
    # installer      = ''
    post_install        = ''
    pre_uninstall       = ''
    # uninstaller    = ''
    post_uninstall      = ''
    checkver            = ''
    autoupdate          = [ordered]@{
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

if ($All) {
    $manifests = Get-ChildItem "$root\bucket" -Recurse -File -Filter '*.json'
}
else {
    $guid = [guid]::NewGuid()
    $manifests = git log --since="1 day ago" --name-only --pretty=format:"$guid%n" -- 'bucket/' |
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
    }
    $changedManifests = git ls-files --modified --others --exclude-standard -- 'bucket/'
    $manifests = $manifests + $changedManifests |
    Where-Object { $_ -match '\.json$' -and (Test-Path $_) } |
    Sort-Object -Unique
}

Write-Host 'Sorting JSON...'

foreach ($m in $manifests) {
    try {
        $content = Get-Content $m -Raw -ErrorAction Stop
        $json = $content | ConvertFrom-Json -AsHashtable -ErrorAction Stop
    }
    catch {
        Write-Host "::error::Failed to convert JSON: $_" -ForegroundColor Red
        continue
    }
    $sortedJson = Sort-JsonByOrder -JsonObject $json -Order $order
    $old = $json | ConvertToPrettyJson
    $new = $sortedJson | ConvertToPrettyJson
    if ($new -eq $old) {
        continue
    }
    Write-Host "Processing: $m"
    Set-Content -LiteralPath $m -Value $new -Encoding utf8
}
