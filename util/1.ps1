foreach ($_ in 'core', 'file', 'installer', 'lifecycle', 'scoop', 'system', 'var') { . $PSScriptRoot\lib\$_.ps1 }

$roots = @($scoopdir)
if ($globaldir -and $globaldir -ne $scoopdir) { $roots += $globaldir }
$old = '. $bucketsdir\\$bucket\\script\\utils.ps1', '. $bucketsdir\\$bucket\\bin\\utils.ps1', '. $bucketsdir\\$bucket\\util\\1.ps1'
foreach ($root in $roots) {
    Get-ChildItem -LiteralPath "$root\apps" -Depth 2 -File -Filter 'manifest.json' -ErrorAction SilentlyContinue |
    ForEach-Object {
        $filePath = $_.FullName
        $text = [System.IO.File]::ReadAllText($filePath)
        $has = $old | Where-Object { $text -like "*$_*" }
        if ($has) {
            $old | ForEach-Object { $text = $text.Replace($_, '. $bucketsdir\\$bucket\\util\\_.ps1') }
            [System.IO.File]::WriteAllText($filePath, $text)
        }
    }
}
