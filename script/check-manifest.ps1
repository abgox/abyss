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

    # Type
    $type = if ($c.psmodule) { 'psmodule' } elseif ($c.font) { 'font' } else { $null }
    $line += if ($type) { $type } else { '' }

    # Persistence
    $persistence = @()
    if ($c.link -or $c.pre_install -match '(?<!#.*)(A-New-LinkFile|A-New-LinkDirectory)') { $persistence += 'link' }
    if ($c.persist) {
        $persistence += 'persist ⚠️'
        $add_label += 'data-persistence-review-needed'
    }
    else {
        $rm_label += 'data-persistence-review-needed'
    }
    if ($persistence) {
        $line += $persistence -join '<br />'
    }
    else {
        $line += ''
    }

    # Location
    $line += if ($c.location) { '`' + $c.location + '`' } else { 'In Scoop' }

    # Extra
    $line += if (Test-Path "extra/$m") { "[Yes](https://github.com/abgox/abyss/tree/main/extra/$m)" } else { 'No' }

    $results += '|' + ($line -join '|') + '|'
}

Write-Host '::endgroup::'

if ($add_label) { Add-GithubLabel ($add_label | Sort-Object -Unique) }
if ($rm_label) { Remove-GithubLabel ($rm_label | Sort-Object -Unique) }

if ($has) {
    $results = @(
        $marker,
        '',
        '| Manifest | Required Fields | In Winget | Type | Persistence | Location | Extra |',
        '| :-: | :-: | :-: | :-: | :-: | :-: | :-: |'
    ) + $results
}
else {
    $results = @(
        $marker,
        '',
        'No manifests in PR.'
    )
}

$results + @(
    '',
    '---',
    # 'Comment `/check` to run the check again.',
    '',
    "[_View the workflow run for details._]($env:RUN_URL)"
) | Out-File result.md
