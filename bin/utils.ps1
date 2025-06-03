Write-Host

# 卸载时的操作行为。
# Github: https://github.com/abgox/abyss#config
# Gitee: https://gitee.com/abgox/abyss#config
$uninstallActionLevel = (scoop config).'app-uninstall-action-level'
if ($uninstallActionLevel -eq $null) {
    $uninstallActionLevel = "1"
}


# 如果没有 $cmd，表示在自动化执行更新检查，此时中文内容可能导致错误。
$ShowCN = $PSUICulture -like "zh*" -and $cmd

if ($ShowCN) {
    $cmdMap_zh = @{
        "install"   = "安装"
        "uninstall" = "卸载"
        "update"    = "更新"
    }

    $words = @{
        "Creating directory:"                                                                           = "正在创建目录:"
        "The script in this manifest is incorrectly defined."                                           = "这个清单中的脚本定义有误。"
        "Copying"                                                                                       = "正在复制:"
        "Removing"                                                                                      = "正在删除:"
        "Failed to $cmd $app."                                                                          = "无法$($cmdMap_zh[$cmd]) $app"
        "Please stop the relevant processes and try to $cmd $app again."                                = "请停止相关进程并再次尝试$($cmdMap_zh[$cmd]) $app。"
        "Failed to remove:"                                                                             = "无法删除:"
        "Linking"                                                                                       = "正在链接:"
        "Successfully terminated the process:"                                                          = "成功终止进程:"
        "Failed to terminate the process:"                                                              = "无法终止进程:"
        "You may need to try $cmd $app again or use administrator permissions."                         = "可能需要再次尝试$($cmdMap_zh[$cmd]) $app 或者使用管理员权限。"
        "No running processes found."                                                                   = "未找到正在运行的相关进程。"
        "If failed to uninstall, You may need to try $cmd $app again or use administrator permissions." = "如果卸载失败，可能需要再次尝试$($cmdMap_zh[$cmd]) $app 或者使用管理员权限。"
        "Successfully terminated the service:"                                                          = "成功终止服务:"
        "Failed to terminate the service:"                                                              = "无法终止服务:"
        "Failed to remove the service:"                                                                 = "无法删除服务:"
        "Removing link:"                                                                                = "正在删除链接:"
        "Removing Temp data:"                                                                           = "正在删除临时数据:"
    }

}
else {
    $words = @{
        "Creating directory:"                                                                           = "Creating directory:"
        "The script in this manifest is incorrectly defined."                                           = "The script in this manifest is incorrectly defined."
        "Copying"                                                                                       = "Copying"
        "Removing"                                                                                      = "Removing"
        "Failed to $cmd $app."                                                                          = "Failed to $cmd $app."
        "Please stop the relevant processes and try to $cmd $app again."                                = "Please stop the relevant processes and try to $cmd $app again."
        "Failed to remove:"                                                                             = "Failed to remove:"
        "Linking"                                                                                       = "Linking"
        "Successfully terminated the process:"                                                          = "Successfully terminated the process:"
        "Failed to terminate the process:"                                                              = "Failed to terminate the process:"
        "You may need to try $cmd $app again or use administrator permissions."                         = "You may need to try $cmd $app again or use administrator permissions."
        "No running processes found."                                                                   = "No running processes found."
        "If failed to uninstall, You may need to try $cmd $app again or use administrator permissions." = "If failed to uninstall, You may need to try $cmd $app again or use administrator permissions."
        "Successfully terminated the service:"                                                          = "Successfully terminated the service:"
        "Failed to terminate the service:"                                                              = "Failed to terminate the service:"
        "Failed to remove the service:"                                                                 = "Failed to remove the service:"
        "Removing link:"                                                                                = "Removing link:"
        "Removing Temp data:"                                                                           = "Removing Temp data:"
    }
}

function A-Ensure-Directory {
    <#
    .SYNOPSIS
        确保指定目录路径存在

    .PARAMETER Path
        需要确保存在的目录路径

    .EXAMPLE
        A-Ensure-Directory
        确保 $persist_dir 目录存在

    .EXAMPLE
        A-Ensure-Directory "D:\scoop\persist\VSCode"
    #>
    param (
        [Parameter(Position = 0, ValueFromPipeline)]
        [string]$Path = $persist_dir
    )
    if (!(Test-Path $Path)) {
        Write-Host "$($words["Creating directory:"]) $Path" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function A-New-PersistFile {
    <#
    .SYNOPSIS
        创建文件，可选择设置内容

    .PARAMETER Path
        要创建的文件路径

    .PARAMETER Content
        文件内容。如果指定了此参数，则写入文件内容，否则创建空文件

    .PARAMETER Encoding
        文件编码（默认: utf8），此参数仅在指定了 -content 参数时有效

    .PARAMETER Force
        强制创建文件，即使文件已存在。

    .EXAMPLE
        A-New-PersistFile -path "$persist_dir\data.json" -content "{}"
        创建文件并指定内容

    .EXAMPLE
        A-New-PersistFile -path "$persist_dir\data.ini"
        创建空文件
    #>
    param (
        [Parameter(Position = 0, ValueFromPipeline)]
        [string]$Path,

        [string]$Content,

        [ValidateSet("utf8", "utf8Bom", "utf8NoBom", "unicode", "ansi", "ascii", "bigendianunicode", "bigendianutf32", "oem", "utf7", "utf32")]
        [string]$Encoding = "utf8",

        [switch]$Force
    )

    if (Test-Path $Path) {
        if ($Force) {
            Remove-Item $Path -Force -ErrorAction SilentlyContinue
        }
        else {
            return
        }
    }

    if ($PSBoundParameters.ContainsKey('content')) {
        # 当明确传递了 content 参数时（包括空字符串或 $null）
        A-Ensure-Directory (Split-Path $Path -Parent)
        Set-Content -Path $Path -Value $Content -Encoding $Encoding -Force
    }
    else {
        # 当没有传递 content 参数时
        New-Item -ItemType File -Path $Path -Force | Out-Null
    }
}

function A-New-LinkFile {
    <#
    .SYNOPSIS
        创建文件链接 (SymbolicLink)

    .PARAMETER LinkPaths
        要创建链接的路径数组 (将被替换为链接)

    .PARAMETER LinkTargets
        链接指向的目标路径数组 (链接指向的位置)

    .EXAMPLE
        A-New-LinkFile -LinkPaths @("$env:UserProfile\.config\starship.toml") -LinkTargets @("$persist_dir\starship.toml")
        创建文件链接: "$env:UserProfile\.config\starship.toml" => "$persist_dir\starship.toml"

    .LINK
        https://github.com/abgox/abyss#link
        https://gitee.com/abgox/abyss#link
    #>
    param (
        [array]$LinkPaths,

        [array]$LinkTargets
    )

    if ($LinkPaths.Count -ne $LinkTargets.Count) {
        Write-Host $words["The script in this manifest is incorrectly defined."] -ForegroundColor Red
        exit 1
    }

    $isAdmin = A-Test-Admin
    if (!$isAdmin) {
        if ($ShowCN) {
            Write-Host "$app 需要去链接以下的数据文件:" -ForegroundColor Yellow
            for ($i = 0; $i -lt $LinkPaths.Count; $i++) {
                Write-Host "$($LinkPaths[$i]) => $($LinkTargets[$i])" -ForegroundColor Yellow
            }
            Write-Host "它需要管理员权限。`n请使用管理员身份再次尝试。" -ForegroundColor Red
        }
        else {
            Write-Host "$app needs to link the following data file:"
            for ($i = 0; $i -lt $LinkPaths.Count; $i++) {
                Write-Host "$($LinkPaths[$i]) => $($LinkTargets[$i])" -ForegroundColor Yellow
            }
            Write-Host "It requires administrator permission for $app.`nPlease Try again with administrator permission." -ForegroundColor Red
        }
        exit 1
    }

    A-New-Link -LinkPaths $LinkPaths -LinkTargets $LinkTargets -ItemType SymbolicLink -OutFile "$dir\scoop-install-A-New-LinkFile.jsonc"
}

function A-New-LinkDirectory {
    <#
    .SYNOPSIS
        创建目录链接 (Junction)

    .PARAMETER LinkPaths
        要创建链接的路径数组 (将被替换为链接)

    .PARAMETER LinkTargets
        链接指向的目标路径数组 (链接指向的位置)

    .EXAMPLE
        A-New-LinkDirectory -LinkPaths @("$env:LocalAppData\nvim","$env:LocalAppData\nvim-data") -LinkTargets @("$persist_dir\nvim","$persist_dir\nvim-data")
        创建目录链接: "$env:LocalAppData\nvim" => "$persist_dir\nvim"
        创建目录链接: "$env:LocalAppData\nvim-data" => "$persist_dir\nvim-data"

    .LINK
        https://github.com/abgox/abyss#link
        https://gitee.com/abgox/abyss#link
    #>
    param (
        [array]$LinkPaths,

        [array]$LinkTargets
    )

    A-New-Link -LinkPaths $LinkPaths -LinkTargets $LinkTargets -ItemType Junction -OutFile "$dir\scoop-install-A-New-LinkDirectory.jsonc"
}

function A-Remove-LinkFile {
    <#
    .SYNOPSIS
        删除在应用安装过程中创建的链接文件
    #>

    A-Remove-Link -OutFile "$dir\scoop-install-A-New-LinkFile.jsonc"
}

function A-Remove-LinkDirectory {
    <#
    .SYNOPSIS
        删除在应用安装过程中创建的链接目录
    #>

    A-Remove-Link -OutFile "$dir\scoop-install-A-New-LinkDirectory.jsonc"
}

function A-Remove-TempData {
    <#
    .SYNOPSIS
        删除临时数据目录或文件

    .DESCRIPTION
        该函数用于递归删除指定的临时数据目录或文件。
        根据全局变量 $cmd 和 $uninstallActionLevel 的值决定是否执行删除操作。

    .PARAMETER Paths
        要删除的临时数据路径数组，支持通过管道传入。
        可以包含文件或目录路径。

    .EXAMPLE
        A-Remove-TempData -Paths @("C:\Temp\Logs", "D:\Cache")
        删除指定的两个临时数据目录

    .EXAMPLE
        "C:\Windows\Temp" | A-Remove-TempData
        通过管道传入单个临时目录路径
    #>
    param (
        [Parameter(Position = 0, ValueFromPipeline)]
        [array]$Paths
    )

    if ($cmd -eq "update" -or $uninstallActionLevel -notlike "*3*") {
        return
    }
    foreach ($_ in $Paths) {
        if (Test-Path $_ ) {
            Write-Host "$($words["Removing Temp data:" ]) $_" -ForegroundColor Yellow
            Remove-Item $_ -Force -Recurse -ErrorAction SilentlyContinue
        }
    }
}

function A-Stop-Process {
    <#
    .SYNOPSIS
        停止从指定目录运行的所有进程

    .DESCRIPTION
        该函数用于查找并终止从指定目录路径加载模块的所有进程。
        函数默认会搜索 $dir 和 $dir\current 目录。

    .PARAMETER ExtraPaths
        要搜索运行中可执行文件的额外目录路径数组。
    #>
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [string[]]$ExtraPaths
    )

    $Paths = @($dir, (Split-Path $dir -Parent) + '\current')
    $Paths += $ExtraPaths


    # Msix/Appx 在移除包时会自动终止进程，不需要手动终止
    if ($uninstallActionLevel -notlike "*1*" -or (Test-Path "$dir\scoop-install-A-Add-AppxPackage.jsonc")) {
        return
    }

    $processes = Get-Process
    $NoFound = $true

    foreach ($app_dir in $Paths) {
        # $matched = $processes.where({ $_.Modules.FileName -like "$app_dir\*" })
        $matched = $processes.where({ $_.MainModule.FileName -like "$app_dir\*" })
        foreach ($m in $matched) {
            $NoFound = $false
            try {
                Stop-Process -Id $m.Id -Force -ErrorAction Stop
                Write-Host "$($words["Successfully terminated the process:"]) $($m.Id) $($m.Name) ($($m.MainModule.FileName))" -ForegroundColor Green
            }
            catch {
                Write-Host "$($words["Failed to terminate the process:"]) $($m.Id) $($m.Name)`n$($words["You may need to try $cmd $app again or use administrator permissions."])" -ForegroundColor Red
                exit 1
            }
        }
    }

    if ($NoFound) {
        Write-Host "$($words["No running processes found."])`n$($words["If failed to uninstall, You may need to try $cmd $app again or use administrator permissions."])" -ForegroundColor Yellow
    }

    Start-Sleep -Seconds 1
}

function A-Stop-Service {
    <#
    .SYNOPSIS
        停止并删除 Windows 服务

    .DESCRIPTION
        该函数尝试停止并删除指定的 Windows 服务。

    .PARAMETER ServiceName
        要停止和删除的 Windows 服务名称

    .EXAMPLE
        A-Stop-Service -ServiceName "Everything"

    .EXAMPLE
        "Everything" | A-Stop-Service
    #>
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [string]$ServiceName
    )

    $isExist = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if (!$isExist) {
        return
    }

    try {
        Stop-Service -Name $ServiceName -ErrorAction Stop
        Write-Host "$($words["Successfully terminated the service:"]) $ServiceName" -ForegroundColor Green
    }
    catch {
        Write-Host "$($words["Failed to terminate the service:"]) $ServiceName `n$($words["You may need to try $cmd $app again or use administrator permissions."])" -ForegroundColor Red
        exit 1
    }

    try {
        Remove-Service -Name $ServiceName -ErrorAction Stop
    }
    catch {
        Write-Host "$($words["Failed to remove the service:" ]) $ServiceName `n$($words["You may need to try $cmd $app again or use administrator permissions."])" -ForegroundColor Red
        exit 1
    }
}

function A-Complete-Install {
    <#
    .SYNOPSIS
        处理安装完成后的操作
    #>
}

Function A-Complete-Uninstall {
    <#
    .SYNOPSIS
        处理卸载完成后的操作
    #>
}

function A-Add-Font {
    <#
    .SYNOPSIS
        安装字体

    .DESCRIPTION
        安装字体

    .PARAMETER FontType
        字体类型，支持 ttf, otf, ttc
        默认为 ttf
    #>
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [ValidateSet("ttf", "otf", "ttc")]
        [string]$FontType = "ttf"
    )

    $filter = "*.$($FontType)"

    $ExtMap = @{
        ".ttf" = "TrueType"
        ".otf" = "OpenType"
        ".ttc" = "TrueType"
    }

    $currentBuildNumber = [int] (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber
    $windows10Version1809BuildNumber = 17763
    $isPerUserFontInstallationSupported = $currentBuildNumber -ge $windows10Version1809BuildNumber
    if (!$isPerUserFontInstallationSupported -and !$global) {
        scoop uninstall $app

        if ($ShowCN) {
            Write-Host
            Write-Host "对于 Windows 版本低于 Windows 10 版本 1809 (OS Build 17763)，" -Foreground DarkRed
            Write-Host "字体只能安装为所有用户。" -Foreground DarkRed
            Write-Host
            Write-Host "请使用以下命令为所有用户安装 $app 字体。" -Foreground DarkRed
            Write-Host
            Write-Host "        scoop install sudo"
            Write-Host "        sudo scoop install -g $app"
            Write-Host
        }
        else {
            Write-Host
            Write-Host "For Windows version before Windows 10 Version 1809 (OS Build 17763)," -Foreground DarkRed
            Write-Host "Font can only be installed for all users." -Foreground DarkRed
            Write-Host
            Write-Host "Please use following commands to install '$app' Font for all users." -Foreground DarkRed
            Write-Host
            Write-Host "        scoop install sudo"
            Write-Host "        sudo scoop install -g $app"
            Write-Host
        }
        exit 1
    }
    $fontInstallDir = if ($global) { "$env:windir\Fonts" } else { "$env:LOCALAPPDATA\Microsoft\Windows\Fonts" }
    if (!$global) {
        # Ensure user font install directory exists and has correct permission settings
        # See https://github.com/matthewjberger/scoop-nerd-fonts/issues/198#issuecomment-1488996737
        New-Item $fontInstallDir -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
        $accessControlList = Get-Acl $fontInstallDir
        $allApplicationPackagesAccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule([System.Security.Principal.SecurityIdentifier]::new("S-1-15-2-1"), "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow")
        $allRestrictedApplicationPackagesAccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule([System.Security.Principal.SecurityIdentifier]::new("S-1-15-2-2"), "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow")
        $accessControlList.SetAccessRule($allApplicationPackagesAccessRule)
        $accessControlList.SetAccessRule($allRestrictedApplicationPackagesAccessRule)
        Set-Acl -AclObject $accessControlList $fontInstallDir
    }
    $registryRoot = if ($global) { "HKLM" } else { "HKCU" }
    $registryKey = "${registryRoot}:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    Get-ChildItem $dir -Filter $filter | ForEach-Object {
        $value = if ($global) { $_.Name } else { "$fontInstallDir\$($_.Name)" }
        New-ItemProperty -Path $registryKey -Name $_.Name.Replace($_.Extension, " ($($ExtMap[$_.Extension]))") -Value $value -Force | Out-Null
        Copy-Item -LiteralPath $_.FullName -Destination $fontInstallDir
    }
}

function A-Remove-Font {
    <#
    .SYNOPSIS
        卸载字体

    .DESCRIPTION
        卸载字体

    .PARAMETER FontType
        字体类型，支持 ttf, otf, ttc
        默认为 ttf
    #>
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [ValidateSet("ttf", "otf", "ttc")]
        [string]$FontType = "ttf"
    )

    $filter = "*.$($FontType)"

    $ExtMap = @{
        ".ttf" = "TrueType"
        ".otf" = "OpenType"
        ".ttc" = "TrueType"
    }

    $fontInstallDir = if ($global) { "$env:windir\Fonts" } else { "$env:LOCALAPPDATA\Microsoft\Windows\Fonts" }
    Get-ChildItem $dir -Filter $filter | ForEach-Object {
        Get-ChildItem $fontInstallDir -Filter $_.Name | ForEach-Object {
            try {
                Rename-Item $_.FullName $_.FullName -ErrorVariable LockError -ErrorAction Stop
            }
            catch {
                if ($ShowCN) {
                    Write-Host
                    Write-Host " 错误 " -Background DarkRed -Foreground White -NoNewline
                    Write-Host
                    Write-Host " 无法卸载 $app 字体。" -Foreground DarkRed
                    Write-Host
                    Write-Host " 原因 " -Background DarkCyan -Foreground White -NoNewline
                    Write-Host
                    Write-Host " $app 字体当前被其他应用程序使用，所以无法删除。" -Foreground DarkCyan
                    Write-Host
                    Write-Host " 建议 " -Background Magenta -Foreground White -NoNewline
                    Write-Host
                    Write-Host " 关闭所有使用 $app 字体的应用程序 (例如 vscode) 后，然后再次尝试。" -Foreground Magenta
                    Write-Host
                }
                else {
                    Write-Host
                    Write-Host " Error " -Background DarkRed -Foreground White -NoNewline
                    Write-Host
                    Write-Host " Cannot uninstall '$app' font." -Foreground DarkRed
                    Write-Host
                    Write-Host " Reason " -Background DarkCyan -Foreground White -NoNewline
                    Write-Host
                    Write-Host " The '$app' font is currently being used by another application," -Foreground DarkCyan
                    Write-Host " so it cannot be deleted." -Foreground DarkCyan
                    Write-Host
                    Write-Host " Suggestion " -Background Magenta -Foreground White -NoNewline
                    Write-Host
                    Write-Host " Close all applications that are using '$app' font (e.g. vscode)," -Foreground Magenta
                    Write-Host " and then try again." -Foreground Magenta
                    Write-Host
                }
                exit 1
            }
        }
    }
    $fontInstallDir = if ($global) { "$env:windir\Fonts" } else { "$env:LOCALAPPDATA\Microsoft\Windows\Fonts" }
    $registryRoot = if ($global) { "HKLM" } else { "HKCU" }
    $registryKey = "${registryRoot}:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    Get-ChildItem $dir -Filter $filter | ForEach-Object {
        Remove-ItemProperty -Path $registryKey -Name $_.Name.Replace($_.Extension, " ($($ExtMap[$_.Extension]))") -Force -ErrorAction SilentlyContinue
        Remove-Item "$fontInstallDir\$($_.Name)" -Force -ErrorAction SilentlyContinue
    }
    if ($cmd -eq "uninstall") {
        if ($ShowCN) {
            Write-Host "$app 字体已经成功卸载，重启电脑后将不会再显示。" -Foreground Magenta
        }
        else {
            Write-Host "The '$app' Font family has been uninstalled and will not be present after restarting your computer." -Foreground Magenta
        }
    }
}

function A-Add-MsixPackage {
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [string]$Path
    )

    A-Add-AppxPackage -Path $Path
}

function A-Remove-MsixPackage {
    A-Remove-AppxPackage
}

function A-Add-PowerToysRunPlugin {
    param(
        [string]$PluginName
    )

    $PluginsDir = "$env:LOCALAPPDATA\Microsoft\PowerToys\PowerToys Run\Plugins"
    $PluginPath = "$PluginsDir\$PluginName"
    $OutFile = "$dir\scoop-Install-A-Add-PowerToysRunPlugin.jsonc"

    try {
        if (Test-Path -Path $PluginPath) {
            Write-Host "$($words["Removing"]) $PluginPath" -ForegroundColor Yellow
            Remove-Item -Path $PluginPath -Recurse -Force -ErrorAction Stop
        }
        $CopyingPath = if (Test-Path -Path "$dir\$PluginName") { "$dir\$PluginName" } else { $dir }
        Write-Host "$($words["Copying"]) $CopyingPath => $PluginPath" -ForegroundColor Yellow
        Copy-Item -Path $CopyingPath -Destination $PluginPath -Recurse -Force

        if ($ShowCN) {
            Write-Host "请重启 PowerToys 以加载插件。" -ForegroundColor Green
        }
        else {
            Write-Host "Please restart PowerToys to load the plugin." -ForegroundColor Green
        }

        @{ "PluginName" = $PluginName } | ConvertTo-Json | Out-File -FilePath $OutFile -Force -Encoding utf8
    }
    catch {
        Write-Host "$($words["Failed to remove:"]) $PluginPath" -ForegroundColor Red
        Write-Host $words["Failed to $cmd $app."] -ForegroundColor Red
        if ($ShowCN) {
            Write-Host "请终止 PowerToys 进程并尝试再次 $cmd $app。" -ForegroundColor Red
        }
        else {
            Write-Host "Please stop PowerToys and try to $cmd $app again." -ForegroundColor Red
        }
        exit 1
    }

}

function A-Remove-PowerToysRunPlugin {
    $PluginsDir = "$env:LOCALAPPDATA\Microsoft\PowerToys\PowerToys Run\Plugins"

    $OutFile = "$dir\scoop-Install-A-Add-PowerToysRunPlugin.jsonc"

    try {
        if (Test-Path -Path $OutFile) {
            $PluginName = Get-Content $OutFile -Raw | ConvertFrom-Json | Select-Object -ExpandProperty "PluginName"
            $PluginPath = "$PluginsDir\$PluginName"
        }
        else {
            return
        }

        if (Test-Path -Path $PluginPath) {
            Write-Host "$($words["Removing"]) $PluginPath" -ForegroundColor Yellow
            Remove-Item -Path $PluginPath -Recurse -Force -ErrorAction Stop
        }
    }
    catch {
        Write-Host "$($words["Failed to remove:"]) $PluginPath" -ForegroundColor Red
        Write-Host $words["Failed to $cmd $app."] -ForegroundColor Red
        if ($ShowCN) {
            Write-Host "请终止 PowerToys 进程并尝试再次 $cmd $app。" -ForegroundColor Red
        }
        else {
            Write-Host "Please stop PowerToys and try to $cmd $app again." -ForegroundColor Red
        }
        exit 1
    }
}


function A-Expand-SetupExe {

    $archMap = @{
        '64bit' = '64'
        '32bit' = '32'
        'arm64' = 'arm64'
    }

    $all7z = Get-ChildItem "$dir\`$PLUGINSDIR" -Filter "app*.7z"
    $matched = $all7z | Where-Object { $_.Name -match "app.+$($archMap[$architecture])\.7z" }

    if ($matched.Length) {
        $7z = $matched[0].FullName
    }
    else {
        $7z = $all7z[0].FullName
    }
    Expand-7zipArchive $7z $dir

    Remove-Item "$dir\`$*" -Recurse -Force -ErrorAction SilentlyContinue
}

function A-Test-Admin {
    <#
    .SYNOPSIS
        检查当前用户是否具有管理员权限

    .DESCRIPTION
        该函数检查当前用户是否具有管理员权限，并返回一个布尔值。
    #>
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) -and ($identity.Groups -contains "S-1-5-32-544")
}

function A-Get-InstallerInfoFromWinget {
    <#
    .SYNOPSIS
        从 winget 获取安装信息

    .DESCRIPTION
        该函数使用 winget 获取应用程序安装信息，并返回一个包含安装信息的对象。

    .PARAMETER PackageName
        要获取安装信息的包名。
        格式为 'Microsoft/VisualStudioCode'

    .PARAMETER InstallerType
        要获取的安装包的类型(后缀名)，如 zip/exe/msi/...
    #>
    param(
        [string]$PackageName,
        [string]$InstallerType
    )

    $rootDir = $PackageName.ToLower()[0]
    $parts = $PackageName -split '/'
    $id = $parts -join '.'

    $latestVersion = (Invoke-WebRequest -Uri "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/$rootDir/$PackageName").Content |
    ConvertFrom-Json |
    ForEach-Object { if ($_.Name -notmatch '^\.') { $_.Name } } |
    Sort-Object { try { [version]$_ } catch {} } -Descending |
    Select-Object -First 1

    $installerYaml = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/$rootDir/$PackageName/$latestVersion/$id.installer.yaml"

    $hasCommand = Get-Command -Name ConvertFrom-Yaml -ErrorAction SilentlyContinue
    if (!$hasCommand) {
        Install-Module powershell-yaml -Repository PSGallery -Force
        Import-Module -Name powershell-yaml -Force
        Write-Host "Install and import powershell-yaml module" -ForegroundColor Green
    }

    $installerInfo = ConvertFrom-Yaml $installerYaml.Content

    $scope = $installerInfo.Scope

    foreach ($_ in $installerInfo.Installers) {
        $arch = $_.Architecture
        $type = [regex]::Match($_.InstallerUrl, '\.(\w+)$').Groups[1].Value.ToLower()
        if ($arch -and $type -eq $InstallerType) {
            $res = $arch
            if ($scope) {
                $res += '_' + $scope.ToLower()
            }
            elseif ($_.Scope) {
                $res += '_' + $_.Scope.ToLower()
            }
            $installerInfo.$res = $_
        }
    }

    # 写入到 bin/scoop-auto-check-update-temp-data.jsonc，用于后续读取
    $installerInfo | ConvertTo-Json -Depth 100 | Out-File -FilePath "$PSScriptRoot\scoop-auto-check-update-temp-data.jsonc" -Force -Encoding utf8

    $installerInfo
}



#region 以下的函数不建议在应用清单的脚本中直接使用

function A-New-Link {
    <#
    .SYNOPSIS
        创建符号链接

    .DESCRIPTION
        该函数用于将现有文件替换为指向目标文件的符号链接。
        如果源文件存在且不是链接，会先将其内容复制到目标文件，然后删除源文件并创建链接。

    .PARAMETER linkPaths
        要创建链接的路径数组

    .PARAMETER linkTargets
        链接指向的目标路径数组

    .PARAMETER ItemType
        链接类型，可选值为 SymbolicLink/Junction

    .PARAMETER OutFile
        相关链接路径信息会写入到该文件中

    .LINK
        https://github.com/abgox/abyss#link
        https://gitee.com/abgox/abyss#link
    #>
    param (
        [array]$LinkPaths, # 源路径数组（将被替换为链接）

        [array]$LinkTargets, # 目标路径数组（链接指向的位置）

        [ValidateSet("SymbolicLink", "Junction")]
        [string]$ItemType,

        [string]$OutFile
    )

    if ($LinkPaths.Count -ne $LinkTargets.Count) {
        Write-Host $words["The script in this manifest is incorrectly defined."] -ForegroundColor Red
        exit 1
    }

    $installData = @{
        "LinkPaths" = @()
    }

    for ($i = 0; $i -lt $LinkPaths.Count; $i++) {
        $linkPath = $LinkPaths[$i]
        $linkTarget = $LinkTargets[$i]
        $installData.LinkPaths += $linkPath
        if ($cmd -ne "update" -and (Test-Path $linkPath) -and !(Get-Item $linkPath).LinkType) {
            if (!(Test-Path $linkTarget)) {
                Write-Host "$($words["Copying"]) $linkPath => $linkTarget" -ForegroundColor Yellow
                try {
                    Copy-Item -Path $linkPath -Destination $linkTarget -Recurse -Force -ErrorAction Stop
                }
                catch {
                    Remove-Item $linkTarget -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host $_.Exception.Message -ForegroundColor Red
                    exit 1
                }
            }
            try {
                Write-Host "$($words["Removing"]) $linkPath" -ForegroundColor Yellow
                Remove-Item $linkPath -Recurse -Force -ErrorAction Stop
            }
            catch {
                Write-Host "$($words["Failed to remove:"]) $linkPath" -ForegroundColor Red
                Write-Host $words["Failed to $cmd $app."] -ForegroundColor Red
                Write-Host $words["Please stop the relevant processes and try to $cmd $app again."] -ForegroundColor Red
                exit 1
            }
        }
        A-Ensure-Directory $linkTarget

        if ((Get-Service -Name cexecsvc -ErrorAction SilentlyContinue)) {
            # test if this script is being executed inside a docker container
            if ($ItemType -eq "Junction") {
                cmd.exe /d /c "mklink /j `"$linkPath`" `"$linkTarget`""
            }
            else {
                # SymbolicLink
                cmd.exe /d /c "mklink `"$linkPath`" `"$linkTarget`""
            }
        }
        else {
            New-Item -ItemType $ItemType -Path $linkPath -Target $linkTarget -Force | Out-Null
        }
        Write-Host "$($words["Linking"]) $linkPath => $linkTarget" -ForegroundColor Yellow
    }
    if ($LinkPaths.Count) {
        $installData | ConvertTo-Json | Out-File -FilePath $OutFile -Force -Encoding utf8
    }
}

function A-Remove-Link {
    <#
    .SYNOPSIS
        删除符号链接

    .PARAMETER OutFile
        在创建链接时，相关链接路径信息已写入到该文件中，此处读取该文件并删除链接

    .DESCRIPTION
        该函数用于删除在应用安装过程中创建的链接
    #>
    param(
        [string]$OutFile
    )

    if (Test-Path "$dir\scoop-install-A-Add-AppxPackage.jsonc") {
        # 通过 Msix 打包的程序，在卸载时会删除所有数据文件，因此必须先删除链接目录
    }
    elseif ($cmd -eq "update" -or $uninstallActionLevel -notlike "*2*") {
        return
    }

    if (Test-Path $OutFile) {
        $LinkPaths = Get-Content $OutFile -Raw | ConvertFrom-Json | Select-Object -ExpandProperty "LinkPaths"
        foreach ($_ in $LinkPaths) {
            if (Test-Path $_ ) {
                Write-Host "$($words["Removing link:"]) $_" -ForegroundColor Yellow
                Remove-Item $_ -Force -Recurse -ErrorAction SilentlyContinue
            }
        }
    }
}

function A-Add-AppxPackage {
    <#
    .SYNOPSIS
        安装 AppX/Msix 包并记录安装信息供 Scoop 管理

    .DESCRIPTION
        该函数使用 Add-AppxPackage 命令安装应用程序包 (.appx 或 .msix)，
        然后创建一个 JSON 文件用于 Scoop 管理安装信息。

    .PARAMETER Path
        要安装的 AppX/Msix 包的文件路径。支持管道输入。

    .EXAMPLE
        A-Add-AppxPackage -Path "D:\dl.msixbundle"

    .EXAMPLE
        "D:\dl.msixbundle" | A-Add-AppxPackage
    #>
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [string]$Path
    )

    try {
        Add-AppxPackage -Path $Path -ErrorAction Stop
    }
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        scoop uninstall $app
        exit 1
    }

    $installData = @{
        package = @{
            PackageFamilyName = $PackageFamilyName
        }
    }
    $installData | ConvertTo-Json | Out-File -FilePath "$dir\scoop-install-A-Add-AppxPackage.jsonc" -Force -Encoding utf8

    if ($ShowCN) {
        Write-Host "$app 的程序安装目录不在 Scoop 中。`nScoop 只管理数据的 persist，应用的安装、更新以及卸载操作。" -ForegroundColor Yellow
    }
    else {
        Write-Host "The installation directory of $app is not in Scoop.`nScoop only manages the persistence of data and operations for installing, updating, and uninstalling." -ForegroundColor Yellow
    }
}

function A-Remove-AppxPackage {
    <#
    .SYNOPSIS
        移除 AppX/Msix 包

    .DESCRIPTION
        该函数使用 Remove-AppxPackage 命令移除应用程序包 (.appx 或 .msixbundle)
    #>

    $OutFile = "$dir\scoop-install-A-Add-AppxPackage.jsonc"

    if (Test-Path $OutFile) {
        $PackageFamilyName = (Get-Content $OutFile -Raw | ConvertFrom-Json | Select-Object -ExpandProperty "package").PackageFamilyName
        Get-AppxPackage | Where-Object { $_.PackageFamilyName -eq $PackageFamilyName } | Select-Object -First 1 | Remove-AppxPackage
    }
}

#endregion



#region 重写 scoop 内置函数

if ($ShowCN) {

    # function success: https://github.com/ScoopInstaller/Scoop/blob/master/lib/core.ps1#L367
    Set-Item -Path Function:\success -Value {
        param($msg)

        function Translate-Message {
            param([string]$msg)

            if ($msgMap.ContainsKey($msg)) {
                return $msgMap[$msg]
            }

            foreach ($pattern in $msgMap.Keys | Where-Object { $_ -match '\{\d+\}' }) {
                $escapedPattern = [regex]::Escape($pattern)
                $regexPattern = $escapedPattern -replace '\\\{\d+\}', '(.*)'

                $match = [regex]::Match($msg, $regexPattern)
                if ($match.Success) {
                    $translation = $msgMap[$pattern]
                    $translation = [regex]::Replace($translation, '\{(\d+)\}', {
                            param($m)
                            $index = [int]$m.Groups[1].Value
                            return $match.Groups[$index + 1].Value.Trim()
                        })
                    return $translation
                }
            }

            return $msg
        }

        $msgMap = @{
            "'$app' ($version) was installed successfully!" = "已成功安装 $app ($version)!"
            "'{0}' was uninstalled."                        = "已成功卸载 {0}!"
        }

        $translated = Translate-Message $msg

        Write-Host $translated -ForegroundColor darkgreen
    }

    # function abort: https://github.com/ScoopInstaller/Scoop/blob/master/lib/core.ps1#L334
    Set-Item -Path Function:\abort -Value {
        param($msg, [int] $exit_code = 1)

        function Translate-Message {
            param([string]$msg)

            if ($msgMap.ContainsKey($msg)) {
                return $msgMap[$msg]
            }

            foreach ($pattern in $msgMap.Keys | Where-Object { $_ -match '\{\d+\}' }) {
                $escapedPattern = [regex]::Escape($pattern)
                $regexPattern = $escapedPattern -replace '\\\{\d+\}', '(.*)'

                $match = [regex]::Match($msg, $regexPattern)
                if ($match.Success) {
                    $translation = $msgMap[$pattern]
                    $translation = [regex]::Replace($translation, '\{(\d+)\}', {
                            param($m)
                            $index = [int]$m.Groups[1].Value
                            return $match.Groups[$index + 1].Value.Trim()
                        })
                    return $translation
                }
            }

            return $msg
        }

        $msgMap = @{
            "Error: Version 'current' is not allowed!" = "错误：不允许使用 current 作为版本!"
        }

        $translated = Translate-Message $msg

        Write-Host $msg -f red; exit $exit_code
    }

    # function show_notes: https://github.com/ScoopInstaller/Scoop/blob/master/lib/install.ps1#L923
    Set-Item -Path Function:\show_notes -Value {
        param($manifest, $dir, $original_dir, $persist_dir)

        $note = $manifest.notes
        $noteCN = $manifest.'notes-cn'

        if ($noteCN) {
            $note = $noteCN
        }

        if ($note) {
            Write-Output 'Notes'
            Write-Output '-----'
            Write-Output (wraptext (substitute $note @{ '$dir' = $dir; '$original_dir' = $original_dir; '$persist_dir' = $persist_dir }))
        }
    }
}
#endregion
