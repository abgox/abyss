#Requires -PSEdition Core

if (-not $env:GITHUB_ACTIONS) {
    throw 'It is a script for workflow'
}

function Add-GitHubLabel {
    param(
        [ValidateNotNullOrEmpty()]
        [String[]]$Label
    )

    Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/issues/$pr/labels" -Headers $headers -Method Post -Body (@{ labels = $Label } | ConvertTo-Json) -ContentType 'application/json'
}

function Remove-GitHubLabel {
    param(
        [ValidateNotNullOrEmpty()]
        [string[]]$Label
    )

    foreach ($name in $Label) {
        $encoded = [uri]::EscapeDataString($name)
        try {
            Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/issues/$pr/labels/$encoded" -Headers $headers -Method Delete
        }
        catch {
            if ($_.Exception.Response.StatusCode -ne [System.Net.HttpStatusCode]::NotFound) {
                throw
            }
        }
    }
}

$repo = $env:REPO
$pr = $env:PR_NUMBER
$marker = $env:MARKER
$headers = @{
    Authorization = "Bearer $env:GITHUB_TOKEN"
    Accept        = 'application/vnd.github.v3+json'
}

$page = 1
$files = @()
$api = "https://api.github.com/repos/$repo/pulls/$pr/files?per_page=100"

while ($true) {
    $res = Invoke-RestMethod -Uri "$api&page=$page" -Headers $headers
    if (-not $res) { break }
    $files += $res
    if ($res.Count -lt 100) { break }
    $page++
}

$results = @()
$labels = @{
    'manifest-name-review-needed'    = $false
    'data-persistence-review-needed' = $false
    'json-sorting-needed'            = $false
    'schema-validation-failed'       = $false
}
$has_manifest = $false

$schema_file = "$PSScriptRoot\..\schema\scoop-manifest.en-US.json"
$schema = [Json.Schema.JsonSchema]::FromFile($schema_file)
$schema_options = [Json.Schema.EvaluationOptions]::new()

$extra_dir = "$PSScriptRoot\..\extra"
$pr_extra_files = @()
$pr_extra_files_removed = @()

Write-Host '::group::Manifests'

foreach ($file in $files) {
    if ($file.filename -notmatch '^bucket.*/(.+)\.json$') {
        if ($file.filename -like 'extra/*') {
            if ($file.status -eq 'removed') {
                $pr_extra_files_removed += $file.filename
            }
            else {
                $pr_extra_files += $file.filename
            }
        }
        continue
    }
    $has_manifest = $true
    $m = $matches[1]
    Write-Host $m

    $part = $m.Split('.', 2)
    $publisher = $part[0]
    $id = $part[1]
    $letter = $publisher.ToLower()[0]

    if ($null -eq $id -or $publisher -eq $id) {
        $labels.'manifest-name-review-needed' = $true
    }

    $c = Invoke-RestMethod -Uri $file.raw_url -Headers $headers

    # Schema Validation
    $line_schema = ''
    try {
        $raw_manifest = (Invoke-WebRequest -Uri $file.raw_url -Headers $headers).Content
        $manifest_node = [System.Text.Json.Nodes.JsonNode]::Parse($raw_manifest)
        if ($schema.Evaluate($manifest_node, $schema_options).IsValid) {
            $line_schema = '✅'
        }
        else {
            $line_schema = '❌'
            $labels.'schema-validation-failed' = $true
        }
    }
    catch {
        $line_schema = '❌'
        $labels.'schema-validation-failed' = $true
    }

    $line = @()

    # Status
    $line += $file.status

    # Manifest
    $line += if ($c.homepage) { "[$m]($($c.homepage))" } else { $m }

    # Type
    $type = @()
    if ($c.psmodule) { $type += 'psmodule' }
    if ($c.font) { $type += 'font' }
    $download_url = $c.architecture.'64bit'.url, $c.architecture.'32bit'.url, $c.architecture.arm64.url, $c.url | Select-Object -First 1
    if ($download_url) {
        $download_url | ForEach-Object {
            $extension = $_.Split('/')[-1].Split('.')[-1]
            $type += $extension.Replace('msi_', 'msi')
        }
        $line += $type -join ', '
    }
    else {
        $line += ''
    }

    # WinGet
    $path = "$letter/$($m.Replace('.', '/'))"
    $api = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/$path"
    $url = "https://github.com/microsoft/winget-pkgs/blob/master/manifests/$path"
    try {
        $res = Invoke-RestMethod -Uri $api -Headers $headers -ErrorAction stop
        $line += "[Yes]($url)"
    }
    catch {
        if ($file.status -eq 'added') {
            $line[1] += '📝'
            $line += "[No]($url)"
            $labels.'manifest-name-review-needed' = $true
        }
        else {
            $line += "[No]($url)"
        }
    }

    # Location
    $line += if ($c.location) { "[$($c.location)](https://abyss.abgox.com/docs/external-installation-directory)" } else { '' }

    # Admin
    $admin = 'No'
    if ($c.admin -or $c.pre_install, $c.pre_uninstall -match '(?<!#.*)A-Require-Admin') {
        $admin = 'Yes'
    }
    $line += "[$admin](https://abyss.abgox.com/docs/require-admin)"

    # Persistence
    $persistence = @()
    if ($c.link -or $c.pre_install -match '(?<!#.*)A-New-Link(File|Directory)') {
        $persistence += '[link](https://abyss.abgox.com/docs/features/data-persistence/#link)'
    }
    if ($c.persist) {
        if ($file.status -eq 'added') {
            $persistence += '[persist](https://abyss.abgox.com/docs/features/data-persistence/#persist) 📝'
            $labels.'data-persistence-review-needed' = $true
        }
        else {
            $persistence += '[persist](https://abyss.abgox.com/docs/features/data-persistence/#persist)'
        }
    }
    $line += if ($persistence) { $persistence -join ', ' } else { '' }

    # Extra
    $line += if (Test-Path "$extra_dir\$m") {
        "[Yes](https://github.com/abgox/abyss/tree/main/extra/$m)"
    }
    elseif ($pr_extra_files -like "extra/$m/*") {
        'Yes'
    }
    else {
        'No'
    }

    # Schema
    $line += $line_schema

    $results += '|' + ($line -join '|') + '|'
}

Write-Host '::endgroup::'

$guide = @'

<details>

<summary>Guide</summary>

<br />

- **Status**: The status of the manifest in the PR.
- **Manifest**: The manifest name.
- **Type**: The manifest type.
- **WinGet**: Whether the app already exists in the [winget-pkgs](https://github.com/microsoft/winget-pkgs) repository.
- **Location**: The external installation location of the app.
- **Admin**: Whether the app requires admin permission to install or uninstall.
- **Persistence**: The persistence method used for app data.
- **Extra**: Whether extra files or directories exist for persistence in the [extra](https://github.com/abgox/abyss/tree/main/extra) directory.
- **Schema**: Whether the manifest complies with the [JSON Schema](https://github.com/abgox/abyss/blob/main/schema/scoop-manifest.en-US.json).

</details>

'@

if ($has_manifest) {
    $results = @(
        $marker,
        $guide,
        '',
        '| Status | Manifest | Type | WinGet | Location | Admin | Persistence | Extra | Schema |',
        '| :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: |'
    ) + $results

    .\script\sort-json.ps1

    git -c core.safecrlf=false add -u
    $json_changes = git status --porcelain | Where-Object { $_ -match '\.json$' }
    if ($json_changes) {
        $results += @(
            '',
            '> [!WARNING]',
            '>',
            '> Please run it to sort JSON and commit again.',
            '>',
            '> ```powershell',
            '> .\script\sort-json.ps1',
            '> ```'
        )
        $labels.'json-sorting-needed' = $true
    }
    else {
        Write-Host 'No JSON changes detected, no need to sort JSON.'
    }
}
else {
    $results = @(
        $marker,
        '',
        'No manifests in PR.'
    )
}

$results | Out-File result.md


# Labels
$add_labels = @()
$rm_labels = @()

$labels.Keys | ForEach-Object { if ($labels.$_) { $add_labels += $_ } else { $rm_labels += $_ } }

if ($add_labels) { Add-GitHubLabel $add_labels }
if ($rm_labels) { Remove-GitHubLabel $rm_labels }
