
function script:startmenu_shortcut([System.IO.FileInfo] $target, $shortcutName, $arguments, [System.IO.FileInfo]$icon, $global) {
    #region 新增: 支持 abyss 的特性
    function A-Test-ScriptPattern {
        param(
            [Parameter(Mandatory = $true)]
            [PSObject]$InputObject,

            [Parameter(Mandatory = $true)]
            [string]$Pattern,

            [string[]]$ScriptSections = @('pre_install', 'post_install', 'pre_uninstall', 'post_uninstall'),

            [string[]]$ScriptProperties = @('installer', 'uninstaller')
        )

        function Test-ObjectForPattern {
            param(
                [PSObject]$Object,
                [string]$SearchPattern
            )

            $found = $false

            foreach ($section in $ScriptSections) {
                if (!$found -and $Object.$section) {
                    $found = ($Object.$section -join "`n") -match $SearchPattern
                }
            }

            foreach ($property in $ScriptProperties) {
                if (!$found -and $Object.$property.script) {
                    $found = ($Object.$property.script -join "`n") -match $SearchPattern
                }
            }

            return $found
        }

        $patternFound = Test-ObjectForPattern -Object $InputObject -SearchPattern $Pattern

        if (!$patternFound -and $InputObject.architecture) {
            if ($InputObject.architecture.'64bit') {
                $patternFound = Test-ObjectForPattern -Object $InputObject.architecture.'64bit' -SearchPattern $Pattern
            }
            if (!$patternFound -and $InputObject.architecture.'32bit') {
                $patternFound = Test-ObjectForPattern -Object $InputObject.architecture.'32bit' -SearchPattern $Pattern
            }
            if (!$patternFound -and $InputObject.architecture.arm64) {
                $patternFound = Test-ObjectForPattern -Object $InputObject.architecture.arm64 -SearchPattern $Pattern
            }
        }

        return $patternFound
    }

    $abgox_abyss = @{}

    # https://abyss.abgox.com/docs/features/extra-features#abgox-abyss-app-shortcuts-action
    $_ = $scoopConfig.'abgox-abyss-app-shortcuts-action'
    $abgox_abyss.shortcutsActionLevel = if ($_) { $_ }else { '1' }

    if ($abgox_abyss.shortcutsActionLevel -eq '0') {
        return
    }
    if ($abgox_abyss.shortcutsActionLevel -eq '2' -and (A-Test-ScriptPattern $manifest '(?<!#.*)A-Install-.*')) {
        $abgox_abyss.locations = @(
            "$env:AppData\Microsoft\Windows\Start Menu\Programs",
            "$env:LocalAppData\Microsoft\Windows\Start Menu\Programs",
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs",
            [Environment]::GetFolderPath('Desktop'),
            "$env:Public\Desktop"
        )

        if ($PSVersionTable.PSVersion.Major -ge 7) {
            $abgox_abyss.found = $abgox_abyss.locations | ForEach-Object -Parallel {
                $result = Get-ChildItem $_ -Filter "$using:shortcutName.lnk" -Recurse -Depth 5 -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($result) { $result.FullName }
            } | Select-Object -First 1
            if ($abgox_abyss.found) { return }
        }
        else {
            foreach ($_ in $abgox_abyss.locations) {
                $abgox_abyss.found = Get-ChildItem $_ -Filter "$shortcutName.lnk" -Recurse -Depth 5 -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($abgox_abyss.found) { return }
            }
        }
    }

    # XXX: https://github.com/ScoopInstaller/Scoop/issues/6605
    # $filename = $target.FullName
    # if ($filename -match '^\$\{?(env:|home)') {
    #     $filename = $filename.Replace("$dir\", '')
    #     $target = [System.IO.FileInfo]::new($ExecutionContext.InvokeCommand.ExpandString($filename))
    # }

    #endregion

    if (!$target.Exists) {
        Write-Host -f DarkRed "Creating shortcut for $shortcutName ($(fname $target)) failed: Couldn't find $target"
        return
    }
    if ($icon -and !$icon.Exists) {
        Write-Host -f DarkRed "Creating shortcut for $shortcutName ($(fname $target)) failed: Couldn't find icon $icon"
        return
    }

    $scoop_startmenu_folder = shortcut_folder $global
    $subdirectory = [System.IO.Path]::GetDirectoryName($shortcutName)
    if ($subdirectory) {
        $subdirectory = ensure $([System.IO.Path]::Combine($scoop_startmenu_folder, $subdirectory))
    }

    $wsShell = New-Object -ComObject WScript.Shell
    $wsShell = $wsShell.CreateShortcut("$scoop_startmenu_folder\$shortcutName.lnk")
    $wsShell.TargetPath = $target.FullName
    $wsShell.WorkingDirectory = $target.DirectoryName
    if ($arguments) {
        $wsShell.Arguments = $arguments
    }
    if ($icon -and $icon.Exists) {
        $wsShell.IconLocation = $icon.FullName
    }
    $wsShell.Save()
    Write-Host "Creating shortcut for $shortcutName ($(fname $target))"
}

function script:show_notes($manifest, $dir, $original_dir, $persist_dir) {
    #region 修改: 本地化输出
    $note = $manifest.notes

    if ($PSUICulture -like 'zh*') {
        $note = $manifest.notes_cn
    }

    if ($note) {
        Microsoft.PowerShell.Utility\Write-Host
        Write-Output 'Notes'
        Microsoft.PowerShell.Utility\Write-Output '-----'
        Write-Output (substitute $note @{
                '$dir'                     = $dir
                '$original_dir'            = $original_dir
                '$persist_dir'             = $persist_dir
                '$app'                     = $app
                '$version'                 = $manifest.version
                '$env:ProgramFiles'        = $env:ProgramFiles
                '${env:ProgramFiles(x86)}' = ${env:ProgramFiles(x86)}
                '$env:ProgramData'         = $env:ProgramData
                '$env:AppData'             = $env:AppData
                '$env:LocalAppData'        = $env:LocalAppData
            })
        Microsoft.PowerShell.Utility\Write-Output '-----'
    }
    #endregion

    #region 新增 commands 字段
    $cmds = @($manifest.commands)

    if ($manifest.psmodule) {
        Remove-Item "$dir\_rels", "$dir\package", "$dir\*Content*.xml" -Recurse -ErrorAction SilentlyContinue
        $psd1 = Import-PowerShellDataFile -LiteralPath "$scoopdir\modules\$($manifest.psmodule.name)\$($manifest.psmodule.name).psd1" -ErrorAction SilentlyContinue
        $cmds += @($psd1.CmdletsToExport) + @($psd1.FunctionsToExport) + @($psd1.AliasesToExport) | Where-Object { $_ -notin '*', $null }
    }
    $bin = $manifest.bin, $manifest.architecture.$architecture.bin | Select-Object -First 1
    if ($bin -is [string]) {
        $cmds += (Split-Path $bin -Leaf) -replace '\.exe$', ''
    }
    elseif ($bin -is [array]) {
        foreach ($b in $bin) {
            if ($b -is [string]) {
                $cmds += (Split-Path $b -Leaf) -replace '\.exe$', ''
            }
            elseif ($b -is [array]) {
                $cmds += $b[1]
            }
        }
    }

    $out = [System.Collections.Generic.HashSet[string]]::new()
    $cmds | ForEach-Object { $_ -and !$out.Contains($_) -and $out.Add($_) } | Out-Null
    if ($out.Count) {
        Microsoft.PowerShell.Utility\Write-Host
        Write-Output 'Commands'
        Microsoft.PowerShell.Utility\Write-Output '-----'
        Microsoft.PowerShell.Utility\Write-Output $out
        Microsoft.PowerShell.Utility\Write-Output '-----'
    }
    #endregion

    #region 新增: 输出字体名称
    $fonts = Get-Content "$dir\abgox-abyss-A-Install-Font.json" -Raw -ErrorAction Ignore | ConvertFrom-Json | Select-Object -ExpandProperty FontName
    if ($fonts) {
        Microsoft.PowerShell.Utility\Write-Host
        Write-Output 'Fonts'
        Microsoft.PowerShell.Utility\Write-Output '-----'
        Microsoft.PowerShell.Utility\Write-Output $fonts
        Microsoft.PowerShell.Utility\Write-Output '-----'
    }
    #endregion
}
