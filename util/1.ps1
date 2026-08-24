'core', 'file', 'installer', 'lifecycle', 'scoop', 'system', 'var' | ForEach-Object {
    . $PSScriptRoot\lib\$_.ps1
}
