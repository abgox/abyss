#Requires -Version 7.0

param(
    # The manifests to validate: a manifest file path, an app name (e.g. 'PixPin.PixPin'), or a directory.
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Path,

    # Validate all manifests under the bucket directory.
    [switch]$All
)

$ErrorActionPreference = 'Continue'
$root = Split-Path $PSScriptRoot -Parent
$schema_file = Join-Path $root 'schema\scoop-manifest.en-US.json'

if (!(Test-Path -LiteralPath $schema_file)) {
    Write-Error "Schema file is not found: $schema_file"
    exit 1
}

$schema = [Json.Schema.JsonSchema]::FromFile($schema_file)
$schema_options = [Json.Schema.EvaluationOptions]::new()

function Resolve-Manifests([string[]]$Inputs) {
    $resolved = @()

    foreach ($item in $Inputs) {
        if (Test-Path -LiteralPath $item -PathType Container) {
            $resolved += Get-ChildItem -LiteralPath $item -Recurse -File -Filter '*.json'
        }
        elseif (Test-Path -LiteralPath $item -PathType Leaf) {
            $resolved += (Get-Item -LiteralPath $item)
        }
        elseif ($item -match '\.json$') {
            # A '.json' name like 'PixPin.PixPin.json' that does not exist as a direct path
            $matched = Get-ChildItem "$root\bucket" -Recurse -File -Filter $item -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($matched) { $resolved += $matched } else { Write-Warning "Not found: $item" }
        }
        else {
            # An app name like 'PixPin.PixPin'
            $matched = Get-ChildItem "$root\bucket" -Recurse -File -Filter "$item.json" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($matched) { $resolved += $matched } else { Write-Warning "App not found: $item" }
        }
    }

    return @($resolved | Sort-Object FullName -Unique)
}

function Get-ChangedManifests {
    # Same detection logic as sort-json.ps1: recently changed + uncommitted
    $guid = [guid]::NewGuid()
    $manifests = git -c core.safecrlf=false log --since="1 day ago" --name-only --pretty=format:"$guid%n" -- 'bucket/' |
    ForEach-Object {
        if ($_ -eq '') { return }
        if ($_ -eq $guid) {
            if ($current) { $current }
            $current = @()
        }
        else { $current += $_ }
    } -End {
        if ($current) { $current }
    }
    $trackedChanges = git -c core.safecrlf=false diff --name-only HEAD -- 'bucket/'
    $untrackedChanges = git -c core.safecrlf=false ls-files --others --exclude-standard -- 'bucket/'
    return @($manifests) + @($trackedChanges) + @($untrackedChanges) |
    Where-Object { $_ -match '\.json$' -and (Test-Path $_) } |
    ForEach-Object { Get-Item $_ } |
    Sort-Object FullName -Unique
}

# ===== Resolve targets =====
if ($All) {
    $manifests = @(Get-ChildItem "$root\bucket" -Recurse -File -Filter '*.json')
}
elseif ($Path) {
    $manifests = Resolve-Manifests $Path
}
else {
    $manifests = @(Get-ChangedManifests)
}

if (!$manifests -or $manifests.Count -eq 0) {
    Write-Host 'No manifests to validate.' -ForegroundColor Green
    exit 0
}

Write-Host "Validating $($manifests.Count) manifest(s)..."

# ===== Validate =====
$pass = 0
$failedFiles = [System.Collections.Generic.List[object]]::new()

foreach ($m in $manifests) {
    # Use a path relative to the repository root so that it can be recognized by editors such as VS Code
    $relativePath = [System.IO.Path]::GetRelativePath($root, $m.FullName)
    try {
        $node = [System.Text.Json.Nodes.JsonNode]::Parse([System.IO.File]::ReadAllText($m.FullName))
        if ($schema.Evaluate($node, $schema_options).IsValid) {
            $pass++
            Write-Host "PASS  $relativePath" -ForegroundColor Green
            continue
        }
        $errors = @()
    }
    catch {
        Write-Host "FAIL  $relativePath" -ForegroundColor Red
        Write-Host "      Parse failed: $($_.Exception.Message)" -ForegroundColor DarkRed
        $failedFiles.Add(@{ Item = $m; RelativePath = $relativePath })
        continue
    }

    Write-Host "FAIL  $relativePath" -ForegroundColor Red
    Write-Host '      Schema validation failed. Open the manifest in VS Code for details.' -ForegroundColor DarkRed
    $failedFiles.Add(@{ Item = $m; RelativePath = $relativePath })
}

# ===== Summary =====
Write-Host ''
if ($failedFiles.Count -eq 0) {
    Write-Host "All $($pass) manifest(s) passed." -ForegroundColor Green
    exit 0
}

Write-Host ('{0}/{1} manifest(s) failed:' -f $failedFiles.Count, ($pass + $failedFiles.Count)) -ForegroundColor Red
$failedFiles | ForEach-Object { Write-Host ('  - {0}' -f $_.RelativePath) }
exit 1
