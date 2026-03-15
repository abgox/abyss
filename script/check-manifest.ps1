#Requires -PSEdition Core

if (-not $env:GITHUB_ACTIONS) {
    throw 'It is a script for workflow'
}

function Add-GithubLabel {
    param(
        [ValidateNotNullOrEmpty()]
        [String[]]$Label
    )

    Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/issues/$pr/labels" -Headers $headers -Method Post -Body (@{ labels = $Label } | ConvertTo-Json) -ContentType 'application/json'
}

function Remove-GithubLabel {
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
$add_label = @()
$rm_label = @()
$has = $false

Write-Host '::group::Manifests'

foreach ($file in $files) {
    if ($file.filename -notmatch '^bucket.*/(.+)\.json$') {
        continue
    }
    $has = $true
    $m = $matches[1]
    Write-Host $m

    $part = $m.Split('.', 2)
    $publisher = $part[0]
    $id = $part[1]
    $letter = $publisher.ToLower()[0]

    $c = Invoke-RestMethod -Uri $file.raw_url -Headers $headers

    $line = @()

    # Status
    $line += $file.status

    # Manifest
    $line += if ($c.homepage) { "[$m]($($c.homepage))" } else { $m }

    # Required Fields
    $fields = @(
        'version',
        'description',
        'homepage',
        'license',
        'architecture',
        'pre_install',
        'post_install',
        'pre_uninstall',
        'post_uninstall'
    )
    $pass = $true
    foreach ($field in $fields) {
        if (-not $c.$field) {
            $pass = $false
            break
        }
    }
    if ($pass) {
        $rm_label += 'missing-required-field'
    }
    else {
        $add_label += 'missing-required-field'
    }

    # Type
    $type = @()
    if ($c.psmodule) { $type += 'psmodule' }
    if ($c.font) { $type += 'font' }
    $download_url = $c.architecture.'64bit', $c.architecture.arm64 | Select-Object -First 1
    $extension = $download_url.Split('.')[-1]
    $type += $extension.Replace('msi_', 'msi')
    $line += $type -join ', '

    # In Winget
    $path = "$letter/$($m.Replace('.', '/'))"
    $api = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/$path"
    $url = "https://github.com/microsoft/winget-pkgs/blob/master/manifests/$path"
    try {
        $res = Invoke-RestMethod -Uri $api -Headers $headers -ErrorAction stop
        $line += "[Yes]($url)"
        $rm_label += 'manifest-name-review-needed'
    }
    catch {
        $line += "[No]($url) ⚠️"
        $add_label += 'manifest-name-review-needed'
    }

    # Location
    $line += if ($c.location) { '`' + $c.location + '`' } else { 'Scoop' }

    # Permission
    $permission = ''
    if ($c.pre_install, $c.pre_uninstall -match '(?<!#.*)(A-Require-Admin|A-Stop-Service.+?-RequireAdmin)') {
        $permission = '[Require admin](https://abyss.abgox.com/faq/require-admin)'
    }
    else {
        foreach ($l in $c.link) {
            if ($l -like '$dir\*') {
                $path = $l.Replace('$dir\app\', '').Replace('$dir\', '')
            }
            else {
                $path = $ExecutionContext.InvokeCommand.ExpandString($l).Replace("$home\", '')
            }
            if (Test-Path "extra/$m/$path" -PathType Leaf) {
                $permission = '[Require admin or developer mode](https://abyss.abgox.com/faq/require-admin-or-dev-mode)'
                break
            }
        }
    }
    $line += $permission

    # Persistence
    $persistence = @()
    if ($c.link -or $c.pre_install -match '(?<!#.*)(A-New-LinkFile|A-New-LinkDirectory)') {
        $persistence += '[link](https://abyss.abgox.com/features/data-persistence/#link)'
    }
    if ($c.persist) {
        $persistence += '[persist](https://abyss.abgox.com/features/data-persistence/#persist) ⚠️'
        $add_label += 'data-persistence-review-needed'
    }
    else {
        $rm_label += 'data-persistence-review-needed'
    }
    $line += if ($persistence) { $persistence -join ', ' } else { '' }

    # Extra
    $line += if (Test-Path "extra/$m") { "[Yes](https://github.com/abgox/abyss/tree/main/extra/$m)" } else { 'No' }

    $results += '|' + ($line -join '|') + '|'
}

Write-Host '::endgroup::'

if ($add_label) { Add-GithubLabel ($add_label | Sort-Object -Unique) }
if ($rm_label) { Remove-GithubLabel ($rm_label | Sort-Object -Unique) }

$guide = @'

<details>

<summary>Guide</summary>

<br />

- **Status**: The status of the manifest in the PR.
- **Manifest**: The manifest name.
- **Type**: The manifest type.
- **In Winget**: Whether the app already exists in the [winget-pkgs](https://github.com/microsoft/winget-pkgs) repository.
- **Location**: The installation location of the app.
- **Permission**: The permission required to install or uninstall the app.
- **Persistence**: The persistence method used for app data.
- **Extra**: Whether extra files or directories exist for persistence in the [extra](https://github.com/abgox/abyss/tree/main/extra) directory.

</details>

'@

if ($has) {
    $results = @(
        $marker,
        $guide,
        '',
        '| Status | Manifest | Type | In Winget | Location | Permission | Persistence | Extra |',
        '| :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: |'
    ) + $results
}
else {
    $results = @(
        $marker,
        '',
        'No manifests in PR.'
    )
}

# $results + @(
#     '',
#     '---',
#     'Comment `/check` to run the check again.',
#     "[_View the workflow run for details._]($env:RUN_URL)"
# ) | Out-File result.md

$results | Out-File result.md
