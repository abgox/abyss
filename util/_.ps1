switch ($HookType) {
    'pre_uninstall' {
        $_ = "$dir\abgox-abyss.json"
        if ([System.IO.File]::Exists($_)) {
            $abgox_abyss_version = ([System.IO.File]::ReadAllText($_) | ConvertFrom-Json -ErrorAction SilentlyContinue).version
            [Environment]::SetEnvironmentVariable('__scoop_abgox_abyss_version', $abgox_abyss_version, 'Process')
        }
    }
    'post_uninstall' {
        $abgox_abyss_version = [Environment]::GetEnvironmentVariable('__scoop_abgox_abyss_version', 'Process')
        Remove-Item Env:\__scoop_abgox_abyss_version -ErrorAction SilentlyContinue
    }
}
if ($abgox_abyss_version -notmatch '^\d+$') {
    # Always keep the latest version
    $abgox_abyss_version = 1
}
. $PSScriptRoot\version\$abgox_abyss_version.ps1
