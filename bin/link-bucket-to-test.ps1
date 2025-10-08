$root_path = scoop config root_path

if (-not $root_path) {
    Write-Host "Scoop does not have a root_path configuration." -ForegroundColor Red
    exit 1
}

New-Item -ItemType SymbolicLink -Path "$root_path\buckets\abyss-test" -Target "$PSScriptRoot\.." -Force
