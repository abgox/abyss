$abgox_abyss_version = 1
if ([System.IO.File]::Exists("$dir\abgox-abyss.json")) {
    $_ = ([System.IO.File]::ReadAllText("$dir\abgox-abyss.json") | ConvertFrom-Json).version
    if ($_) { $abgox_abyss_version = $_ }
}
. $PSScriptRoot\$abgox_abyss_version.ps1
