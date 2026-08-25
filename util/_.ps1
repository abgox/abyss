if ([System.IO.File]::Exists("$dir\abgox-abyss.json")) {
    $_ = (Get-Content "$dir\abgox-abyss.json" -ErrorAction Ignore | ConvertFrom-Json).version, 1 | Select-Object -First 1
}
else {
    $_ = 1 # Current latest version
}
. $PSScriptRoot\$_.ps1
