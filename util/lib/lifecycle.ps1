function A-Start-Install {
    # https://abyss.abgox.com/docs/bucket-name
    A-Test-BucketName
    # https://abyss.abgox.com/docs/features/manifest-status-control
    if ($manifest.version -in 'pending', 'renamed', 'deprecated') {
        A-Deny-Manifest
    }
    # https://abyss.abgox.com/docs/require-admin
    if ($manifest.admin) {
        A-Require-Admin
    }
    # https://abyss.abgox.com/docs/deny-if-app-conflict
    if ($manifest.conflicts) {
        A-Deny-IfAppConflict $manifest.conflicts
    }
    if ($manifest.renamed) {
        A-Deny-IfAppConflict $manifest.renamed.old
        A-Move-Persistence
    }

    "{`"version`":$abgox_abyss_version}" | Out-File "$dir\abgox-abyss.json" -Force

    # https://abyss.abgox.com/docs/features/data-persistence/persist
    if ($manifest.persist) {
        foreach ($item in $manifest.persist) {
            if ($item -is [string]) {
                $source = $item
                $target = $item
            }
            else {
                $source = $item[0]
                $target = $item[1]
            }
            $from = "$dir\$source"
            $to = "$persist_dir\$target"
            if (A-Test-Path $from) {
                A-Copy-Item $from $to
            }
            $from = "$bucketsdir\$bucket\extra\$app\$target"
            if (A-Test-Path $from) {
                A-Copy-Item $from $to
            }
            if ($target -match 'AppData\\(Roaming|Local)\\.*') {
                $from = [System.IO.Path]::Combine($home, $target)
                $exists = A-Test-Directory $from
                $isLink = A-Test-Link $from
                if ($exists -and !$isLink) {
                    A-Copy-Item $from $to
                }
            }
        }
    }
    if ($manifest.env_set) {
        $manifest.env_set.PSObject.Properties | ForEach-Object {
            [System.Environment]::SetEnvironmentVariable($_.Name, (A-Resolve-SpecialPath $_.Value), [System.EnvironmentVariableTarget]::Process)
        }
    }
    if ($manifest.env_set_shared) {
        A-Set-EnvVarShared
    }
    if ($manifest.env_add_path_expand) {
        A-Add-Path $manifest.env_add_path_expand
    }
    # https://abyss.abgox.com/docs/features/data-persistence/link
    if ($manifest.link -and !$abgox_abyss.skipLink) {
        $resolved = A-Resolve-LinkTargets $manifest.link
        if (!($manifest.pre_install -match '^\s*A-New-Link$')) {
            if ($resolved.FilePaths) { A-New-LinkFile -LinkPaths $resolved.FilePaths -LinkTargets $resolved.FileTargets }
            if ($resolved.DirPaths) { A-New-LinkDirectory -LinkPaths $resolved.DirPaths -LinkTargets $resolved.DirTargets }
        }
    }
    if ($manifest.msix -and !($manifest.pre_install -match '^\s*A-Install-MsixPackage$')) {
        A-Install-MsixPackage
    }
    if ($manifest.extract_to -and !$manifest.innosetup) {
        $fileNameList = @($fname)
        $extract_tos = @($manifest.extract_to)
        for ($i = 0; $i -lt $fileNameList.Count; $i++) {
            $file = [System.IO.Path]::Combine($dir, $fileNameList[$i])
            if (!(A-Test-Path $file)) {
                continue
            }
            $ext = [System.IO.Path]::GetExtension($file)
            if ($ext -in '.exe', '.ps1', '.bat', '.cmd') {
                $dest_dir = if ($i -lt $extract_tos.Count) { $extract_tos[$i] }else { $extract_tos[-1] }
                $dest_dir = [System.IO.Path]::Combine($dir, $dest_dir)
                $dest_file = [System.IO.Path]::Combine($dest_dir, $fileNameList[$i])
                A-Ensure-Directory $dest_dir
                Write-Host "Moving $file => $dest_file"
                Move-Item -LiteralPath $file -Destination $dest_file -Force -ErrorAction Stop
            }
        }
    }
}

function A-Complete-Install {
    $info = @{}
    if ($manifest.font) {
        if ($manifest.font -is [string]) {
            A-Install-Font $manifest.font
        }
        else {
            A-Install-Font
        }
    }
    if ($manifest.location) {
        $location = A-Resolve-SpecialPath $manifest.location
        if (!(A-Test-Path $location)) {
            A-Show-IssueCreationPrompt
            A-Exit
        }
        $info.location = $location
        A-Show-Notes @(
            "The installation directory: $($manifest.location)",
            'Refer to: https://abyss.abgox.com/docs/external-installation-directory'
        )
    }
    if ($info.Count) {
        $info | ConvertTo-Json | Out-File -LiteralPath $abgox_abyss.path.Info -Force -Encoding utf8
    }
}

function A-Start-Uninstall {
    # https://abyss.abgox.com/docs/features/manifest-status-control
    if ($version -in 'pending', 'deprecated') {
        A-Deny-Update
    }
    if ($version -eq 'renamed') {
        $new = $manifest.renamed.new
        if (!$new) {
            try {
                $jsonFile = if ($app.Contains('.')) {
                    "$bucketsdir\$bucket\bucket\$($app[0])\$($app.Split('.', 2)[0])\$app.json"
                }
                else {
                    "$bucketsdir\$bucket\bucket\#\$app.json"
                }
                $new = Get-Content -LiteralPath $jsonFile -Raw -Encoding utf8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop | Select-Object -ExpandProperty renamed | Select-Object -ExpandProperty new
            }
            catch {
                error $_.Exception.Message
                A-Exit
            }
        }
        if ($cmd -eq 'update') {
            error "'$app' is renamed to '$new'."
            error 'Refer to: https://abyss.abgox.com/docs/deny-manifest'
            A-Show-Notes
            A-Exit
        }
    }
    if ($manifest.admin) {
        A-Require-Admin
    }
    if ($manifest.env_set_shared) {
        A-Set-EnvVarShared -Remove
    }
    if ($manifest.msix -and !($manifest.pre_uninstall -match '^\s*A-Uninstall-MsixPackage$')) {
        A-Uninstall-MsixPackage
    }
    A-Remove-Path
    A-Uninstall-Font
    A-Uninstall-PowerToysRunPlugin
}

function A-Complete-Uninstall {
    $tempPath = @()
    if ($manifest.location) {
        $tempPath += A-Resolve-SpecialPath $manifest.location
    }
    foreach ($c in $manifest.cleanup) {
        $tempPath += A-Resolve-SpecialPath $c
    }
    A-Remove-TempData $tempPath
}
