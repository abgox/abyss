'core', 'file', 'installer', 'lifecycle', 'scoop', 'system', 'var' | ForEach-Object { . $PSScriptRoot\lib\$_.ps1 }
$abgox_abyss.version = 1
