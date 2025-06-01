Write-Host

# 一个临时文件，用于保存安装时的一些数据，以便在卸载时使用这些数据
$scoop_temp_config_path = "$dir\scoop-script-temp-data.jsonc"

# 卸载时的操作等级。
# Github: https://github.com/abgox/abyss#config
# Gitee: https://gitee.com/abgox/abyss#config
$uninstallActionLevel = (scoop config).'app_uninstall_action_level'
if ($uninstallActionLevel -eq $null) {
    $uninstallActionLevel = "1"
}

if ($PSUICulture -like "zh*") {
    $cmdMap_zh = @{
        "install"   = "安装"
        "uninstall" = "卸载"
        "update"    = "更新"
    }

    $words = @{
        "Creating directory:"                                                                           = "正在创建目录："
        "The script in this manifest is incorrectly defined."                                           = "这个清单中的脚本定义有误。"
        "Copying"                                                                                       = "正在复制"
        "Removing"                                                                                      = "正在删除"
        "Failed to $cmd $app."                                                                          = "无法$($cmdMap_zh[$cmd]) $app"
        "Please stop the relevant processes and try to $cmd $app again."                                = "请停止相关进程并再次尝试$($cmdMap_zh[$cmd]) $app。"
        "Failed to remove the directory:"                                                               = "无法删除目录:"
        "Linking"                                                                                       = "正在链接"
        "Successfully terminated the process:"                                                          = "成功终止进程:"
        "Failed to terminate the process:"                                                              = "无法终止进程:"
        "You may need to try $cmd $app again or use administrator permissions."                         = "可能需要再次尝试$($cmdMap_zh[$cmd]) $app 或者使用管理员权限。"
        "No running processes found."                                                                   = "未找到正在运行的相关进程。"
        "If failed to uninstall, You may need to try $cmd $app again or use administrator permissions." = "如果卸载失败，可能需要再次尝试$($cmdMap_zh[$cmd]) $app 或者使用管理员权限。"
        "Successfully terminated the service:"                                                          = "成功终止服务:"
        "Failed to terminate the service:"                                                              = "无法终止服务:"
        "Failed to remove the service:"                                                                 = "无法删除服务:"
        "Removing link directory:"                                                                      = "正在删除链接目录:"
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
        "Failed to remove the directory:"                                                               = "Failed to remove the directory:"
        "Linking"                                                                                       = "Linking"
        "Successfully terminated the process:"                                                          = "Successfully terminated the process:"
        "Failed to terminate the process:"                                                              = "Failed to terminate the process:"
        "You may need to try $cmd $app again or use administrator permissions."                         = "You may need to try $cmd $app again or use administrator permissions."
        "No running processes found."                                                                   = "No running processes found."
        "If failed to uninstall, You may need to try $cmd $app again or use administrator permissions." = "If failed to uninstall, You may need to try $cmd $app again or use administrator permissions."
        "Successfully terminated the service:"                                                          = "Successfully terminated the service:"
        "Failed to terminate the service:"                                                              = "Failed to terminate the service:"
        "Failed to remove the service:"                                                                 = "Failed to remove the service:"
        "Removing link directory:"                                                                      = "Removing link directory:"
        "Removing Temp data:"                                                                           = "Removing Temp data:"
    }
}


function A-Ensure-Directory {
    <#
    .SYNOPSIS
        确保指定目录路径存在

    .DESCRIPTION
        确保指定目录路径存在

    .PARAMETER path
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

function A-New-LinkDirectory {
    <#
    .SYNOPSIS
        创建目录链接

    .DESCRIPTION
        该函数用于将现有目录替换为指向目标目录的符号链接（junction point）。
        如果源目录存在且不是链接，会先将其内容复制到目标目录，然后删除源目录并创建链接。

    .PARAMETER linkPaths
        要创建链接的路径数组

    .PARAMETER linkTargets
        链接指向的目标路径数组

    .EXAMPLE
        A-New-LinkDirectory -LinkPaths @("$env:LocalAppData\nvim","$env:LocalAppData\nvim-data") -LinkTargets @("$persist_dir\nvim","$persist_dir\nvim-data")
        创建链接目录: "$env:LocalAppData\nvim" => "$persist_dir\nvim"
        创建链接目录: "$env:LocalAppData\nvim-data" => "$persist_dir\nvim-data"

    .LINK
        https://github.com/abgox/abyss#link
        https://gitee.com/abgox/abyss#link
    #>
    param (
        [array]$LinkPaths, # 源路径数组（将被替换为链接）

        [array]$LinkTargets # 目标路径数组（链接指向的位置）
    )

    if ($LinkPaths.Count -ne $LinkTargets.Count) {
        Write-Host $words["The script in this manifest is incorrectly defined."] -ForegroundColor Red
        exit 1
    }

    $scoopInstallTempData = @{
        "LinkPaths" = @()
    }

    for ($i = 0; $i -lt $LinkPaths.Count; $i++) {
        $linkPath = $LinkPaths[$i]
        $linkTarget = $LinkTargets[$i]
        $scoopInstallTempData.LinkPaths += $linkPath
        if ($cmd -ne "update" -and (Test-Path $linkPath) -and !(Get-Item $linkPath).LinkType) {
            if (!(Test-Path $linkTarget)) {
                Write-Host "$($words["Copying"]) $linkPath => $linkTarget" -ForegroundColor Yellow
                Copy-Item -Path $linkPath -Destination $linkTarget -Recurse -Force
            }
            Write-Host "$($words["Removing"]) $linkPath" -ForegroundColor Yellow
            try {
                Remove-Item $linkPath -Recurse -Force -ErrorAction Stop
            }
            catch {
                Write-Host $words["Failed to $cmd $app."] -ForegroundColor Red
                Write-Host $words["Please stop the relevant processes and try to $cmd $app again."] -ForegroundColor Red
                Write-Host
                Write-Host "$($words["Failed to remove the directory:"]) $linkPath" -ForegroundColor Red
                exit 1
            }
        }
        A-Ensure-Directory $linkTarget
        New-Item -ItemType Junction -Path $linkPath -Target $linkTarget -Force | Out-Null
        Write-Host "$($words["Linking"]) $linkPath => $linkTarget" -ForegroundColor Yellow
    }
    if ($LinkPaths.Count) {
        $scoopInstallTempData | ConvertTo-Json | Out-File -FilePath $scoop_temp_config_path -Force -Encoding utf8
    }
}

function A-New-PersistFile {
    <#
    .SYNOPSIS
        创建文件并确保其存在，可选择设置内容

    .DESCRIPTION
        创建指定路径的文件，如果指定了 -content 参数，则写入内容，否则创建空文件

    .PARAMETER path
        要创建的文件路径

    .PARAMETER content
        文件内容。如果指定了此参数，则写入文件内容，否则创建空文件

    .PARAMETER encoding
        文件编码（默认: utf8），此参数仅在指定了 -content 参数时有效

    .EXAMPLE
        A-New-PersistFile -path "$persist_dir\data.json" -content "{}"
        创建文件并指定内容

    .EXAMPLE
        A-New-PersistFile -path "$persist_dir\data.ini"
        创建空文件（不指定内容）
    #>
    param (
        [Parameter(Position = 0, ValueFromPipeline)]
        [string]$Path,

        [string]$Content,

        [ValidateSet("utf8", "utf8Bom", "utf8NoBom", "unicode", "ansi", "ascii", "bigendianunicode", "bigendianutf32", "oem", "utf7", "utf32")]
        [string]$Encoding = "utf8"
    )

    if (Test-Path $Path) {
        return
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

function A-Stop-Process {
    <#
    .SYNOPSIS
        停止从指定目录运行的所有进程

    .DESCRIPTION
        该函数用于查找并终止从指定目录路径加载模块的所有进程。

    .PARAMETER path
        要搜索运行中可执行文件的目录路径数组。

    .EXAMPLE
        A-Stop-Process -path @("C:\Program Files\MyApp", "D:\Services")
        停止从这两个目录运行的所有进程

    .EXAMPLE
        Get-ChildItem "C:\Apps" -Directory | A-Stop-Process
        通过管道传入目录路径来停止相关进程
    #>
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [string[]]$ExtraPaths = @()
    )

    $Paths = @($dir, (Split-Path $dir -Parent) + '\current')
    $Paths += $ExtraPaths

    if ($uninstallActionLevel -notlike "*1*") {
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

    $serviceExists = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if (!$serviceExists) {
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

function A-Remove-LinkDirectory {
    <#
    .SYNOPSIS
        删除符号链接目录或指定目录

    .DESCRIPTION
        该函数用于删除通过符号链接创建的目录或指定的物理目录。

    .PARAMETER LinkPaths
        要删除的目录路径数组，支持通过管道传入。
        若未指定参数且存在配置文件 $scoop_temp_config_path，则自动从配置文件读取路径。

    .EXAMPLE
        A-Remove-LinkDirectory -LinkPaths @("C:\LinkDir1", "D:\LinkDir2")
        直接删除指定的两个链接目录
    #>
    param (
        [Parameter(Position = 0, ValueFromPipeline)]
        [array]
        $LinkPaths
    )

    if ($cmd -eq "update" -or $uninstallActionLevel -notlike "*2*") {
        return
    }
    if (!$PSBoundParameters.ContainsKey('LinkPaths') -and (Test-Path $scoop_temp_config_path)) {
        $LinkPaths = Get-Content $scoop_temp_config_path | ConvertFrom-Json | Select-Object -ExpandProperty "LinkPaths"
    }
    foreach ($_ in $LinkPaths) {
        if (Test-Path $_ ) {
            Write-Host "$($words["Removing link directory:"]) $_" -ForegroundColor Yellow
        }
        Remove-Item $_ -Force -Recurse -ErrorAction SilentlyContinue
    }
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
        [array]
        $Paths
    )

    if ($cmd -eq "update" -or $uninstallActionLevel -notlike "*3*") {
        return
    }
    foreach ($_ in $Paths) {
        if (Test-Path $_ ) {
            Write-Host "$($words["Removing Temp data:" ]) $_" -ForegroundColor Yellow
        }
        Remove-Item $_ -Force -Recurse -ErrorAction SilentlyContinue
    }
}

function A-Install-Font {
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
        [string]
        $FontType = "ttf"
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

        if ($PSUICulture -like "zh*") {
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

function A-Uninstall-Font {
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
        [string]
        $FontType = "ttf"
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
                if ($PSUICulture -like "zh*") {
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
        if ($PSUICulture -like "zh*") {
            Write-Host "$app 字体已经成功卸载，重启电脑后将不会再显示。" -Foreground Magenta
        }
        else {
            Write-Host "The '$app' Font family has been uninstalled and will not be present after restarting your computer." -Foreground Magenta
        }
    }
}
