#Requires -Version 5.1

<#
一些能在清单中使用的函数:

    1. 在 pre_install 和 post_install 中

        - A-Start-PreInstall: 此函数运行之后，开始执行 pre_install
        - A-Start-PostInstall: 此函数运行之后，开始执行 post_install
        - A-Expand-SetupExe: 展开 Setup.exe 类型的安装包，优先使用 A-Install-Exe
        - A-Ensure-Directory: 确保指定目录路径存在
        - A-New-PersistFile: 创建文件，可选择设置内容(不能在 post_install 中使用)
        - A-New-LinkFile: 为文件创建 SymbolicLink
        - A-New-LinkDirectory: 为目录创建 Junction
        - A-Add-Font: 安装字体
        - A-Add-MsixPackage: 安装 AppX/Msix 包
        - A-Add-PowerToysRunPlugin: 添加 PowerToys Run 插件
        - A-Install-Exe: 运行安装程序

    2. 在 pre_uninstall 和 post_uninstall 中

        - A-Start-PreUninstall: 此函数运行之后，开始执行 pre_uninstall
        - A-Start-PostUninstall: 此函数运行之后，开始执行 post_uninstall
        - A-Stop-Process: 尝试暂停安装目录下的应用进程，以确保能正常卸载
        - A-Stop-Service: 尝试停止并移除指定的应用服务，以确保能正常卸载
        - A-Remove-Link: 移除 A-New-LinkFile 和 A-New-LinkDirectory 创建的 SymbolicLink 或 Junction
        - A-Remove-Font: 移除字体
        - A-Remove-MsixPackage: 卸载 AppX/Msix 包
        - A-Remove-PowerToysRunPlugin: 移除 PowerToys Run 插件
        - A-Uninstall-Exe: 运行卸载程序
        - A-Remove-TempData: 移除指定的一些临时数据文件，常见的在 $env:LocalAppData 目录中，它们不涉及应用配置数据，会自动生成

    3. 其他:
        - A-Require-Admin: 要求以管理员权限运行
        - A-Test-Admin: 检查是否以管理员权限运行
        - A-Get-InstallerInfoFromWinget: 从 winget 数据库中获取安装信息，用于清单文件的 checkver 和 autoupdate

    4. TODO:
        - A-Rename-Manifest: 重命名清单文件，用于迁移旧的清单名到新的清单名(只能在 pre_install 中使用)
            - 当清单文件更名后，需要使用它，并传入旧的清单名称
            - 当用新的清单名称安装时，它会将 persist 中的旧目录用新的清单名称重命名，以实现 persist 的迁移
#>

# -------------------------------------------------

Write-Host

# 卸载时的操作行为。
# Github: https://github.com/abgox/abyss#config
# Gitee: https://gitee.com/abgox/abyss#config
$uninstallActionLevel = (scoop config).'app-uninstall-action-level'
if ($uninstallActionLevel -eq $null) {
    $uninstallActionLevel = "1"
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

$isAdmin = A-Test-Admin

# 如果没有 $cmd，表示在自动化执行更新检查，此时中文内容可能导致错误。
$ShowCN = $PSUICulture -like "zh*" -and $cmd

if ($ShowCN) {
    $cmdMap_zh = @{
        "install"   = "安装"
        "uninstall" = "卸载"
        "update"    = "更新"
    }

    $adminText = if ($isAdmin) { "。" } else { " 或使用管理员权限。" }

    $words = @{
        "Creating directory:"                                            = "正在创建目录:"
        "The number of links is wrong"                                   = "这个清单中的脚本定义有误。`n定义的链接数量不一致。"
        "Copying"                                                        = "正在复制:"
        "Moving"                                                         = "正在移动:"
        "Removing"                                                       = "正在删除:"
        "Failed to $cmd $app."                                           = "无法$($cmdMap_zh[$cmd]) $app"
        "Please stop the relevant processes and try to $cmd $app again." = "请停止相关进程并再次尝试$($cmdMap_zh[$cmd]) $app。"
        "Failed to remove:"                                              = "无法删除:"
        "Linking"                                                        = "正在创建链接:"
        "Successfully terminated the process:"                           = "成功终止进程:"
        "Failed to terminate the process:"                               = "无法终止进程:"
        "Maybe try again"                                                = "可能需要再次尝试$($cmdMap_zh[$cmd]) $app$adminText"
        "No running processes found."                                    = "未找到正在运行的相关进程。"
        "If failed to uninstall, You may need to try again"              = "如果卸载失败，可能需要再次尝试$($cmdMap_zh[$cmd]) $app$adminText"
        "Successfully terminated the service:"                           = "成功终止服务:"
        "Failed to terminate the service:"                               = "无法终止服务:"
        "Failed to remove the service:"                                  = "无法删除服务:"
        "Removing link:"                                                 = "正在删除链接:"
        "Removing Temp data:"                                            = "正在删除临时数据:"
    }
}
else {
    $adminText = if ($isAdmin) { "." } else { " or use administrator permissions." }

    $words = @{
        "Creating directory:"                                            = "Creating directory:"
        "The number of links is wrong"                                   = "The script in this manifest is incorrectly defined.`nThe number of links defined in the manifest is inconsistent."
        "Copying"                                                        = "Copying"
        "Moving"                                                         = "Moving"
        "Removing"                                                       = "Removing"
        "Failed to $cmd $app."                                           = "Failed to $cmd $app."
        "Please stop the relevant processes and try to $cmd $app again." = "Please stop the relevant processes and try to $cmd $app again."
        "Failed to remove:"                                              = "Failed to remove:"
        "Linking"                                                        = "Linking"
        "Successfully terminated the process:"                           = "Successfully terminated the process:"
        "Failed to terminate the process:"                               = "Failed to terminate the process:"
        "Maybe try again"                                                = "You may need to try $cmd $app again$adminText"
        "No running processes found."                                    = "No running processes found. "
        "If failed to uninstall, You may need to try again"              = "If failed to uninstall, You may need to try $cmd $app again$adminText"
        "Successfully terminated the service:"                           = "Successfully terminated the service:"
        "Failed to terminate the service:"                               = "Failed to terminate the service:"
        "Failed to remove the service:"                                  = "Failed to remove the service:"
        "Removing link:"                                                 = "Removing link:"
        "Removing Temp data:"                                            = "Removing Temp data:"
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
        [string]$Path = $persist_dir
    )
    if (!(Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function A-Copy-Item {
    <#
    .SYNOPSIS
        复制文件或目录

    .DESCRIPTION
        通常用来将 bucket/scripts 中提前准备好的配置文件复制到 persist 目录下，以便 Scoop 进行 persist
        因为部分配置文件，如果直接使用 New-Item 或 Set-Content，会出现编码错误

    .EXAMPLE
        A-Copy-Item "$bucketsdir\$bucket\scripts\$app\InputTip.ini" "$persist_dir\InputTip.ini"
    #>
    param (
        [string]$From,

        [string]$To
    )

    A-Ensure-Directory (Split-Path $To -Parent)

    if (Test-Path $To) {
        # 如果是错误的文件类型，需要删除重建
        if ((Get-Item $From).PSIsContainer -ne (Get-Item $To).PSIsContainer) {
            Remove-Item $To -Recurse -Force
            Copy-Item -Path $From -Destination $To -Recurse -Force
        }
    }
    else {
        Copy-Item -Path $From -Destination $To -Recurse -Force
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
        A-New-PersistFile -path "$persist_dir\data.ini" -content @('[Settings]', 'AutoUpdate=0')
        创建文件并指定内容，传入数组会被写入多行

    .EXAMPLE
        A-New-PersistFile -path "$persist_dir\data.ini"
        创建空文件
    #>
    param (
        [string]$Path,

        [string]$Copy,

        [array]$Content,

        [ValidateSet("utf8", "utf8Bom", "utf8NoBom", "unicode", "ansi", "ascii", "bigendianunicode", "bigendianutf32", "oem", "utf7", "utf32")]
        [string]$Encoding = "utf8",

        [switch]$Force
    )

    if (Test-Path $Path) {
        # 如果是一个错误的目录，也要删除重建
        $isDir = (Get-Item $Path).PSIsContainer
        if ($Force -or $isDir) {
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
        为文件创建 SymbolicLink

    .PARAMETER LinkPaths
        要创建链接的路径数组 (将被替换为链接)

    .PARAMETER LinkTargets
        链接指向的目标路径数组 (链接指向的位置)
        可忽略，将根据 LinkPaths 自动生成

    .EXAMPLE
        A-New-LinkFile -LinkPaths @("$env:UserProfile\.config\starship.toml")

    .LINK
        https://github.com/abgox/abyss#link
        https://gitee.com/abgox/abyss#link
    #>
    param (
        [array]$LinkPaths,

        [System.Collections.Generic.List[string]]$LinkTargets = @()
    )

    for ($i = 0; $i -lt $LinkPaths.Count; $i++) {
        $LinkPath = $LinkPaths[$i]
        $LinkTarget = $LinkTargets[$i]

        if (!$LinkTargets[$i]) {
            if ($LinkPath -notlike "*$env:UserProfile*") {
                Write-Host $words["The number of links is wrong"] -ForegroundColor Red
                A-Exit
            }
            $LinkTargets.Add($LinkPath.replace($env:UserProfile, $persist_dir))
        }
    }

    if (!$isAdmin) {
        if ($ShowCN) {
            Write-Host "$app 需要为以下文件创建 SymbolicLink:" -ForegroundColor Yellow
        }
        else {
            Write-Host "$app needs to create symbolic links the following data file:"
        }

        Write-Host "-----"
        for ($i = 0; $i -lt $LinkPaths.Count; $i++) {
            Write-Host $LinkPaths[$i] -ForegroundColor Cyan -NoNewline
            Write-Host " => " -NoNewline
            Write-Host $LinkTargets[$i] -ForegroundColor Cyan
        }
        Write-Host "-----"

        if ($ShowCN) {
            Write-Host "创建 SymbolicLink 需要管理员权限。请使用管理员权限再次尝试。" -ForegroundColor Red
        }
        else {
            Write-Host "It requires administrator permission. Please Try again with administrator permission." -ForegroundColor Red
        }
        A-Exit
    }

    A-New-Link -LinkPaths $LinkPaths -LinkTargets $LinkTargets -ItemType SymbolicLink -OutFile "$dir\scoop-install-A-New-LinkFile.jsonc"
}

function A-New-LinkDirectory {
    <#
    .SYNOPSIS
        为目录创建 Junction

    .PARAMETER LinkPaths
        要创建链接的路径数组 (将被替换为链接)

    .PARAMETER LinkTargets
        链接指向的目标路径数组 (链接指向的位置)
        可忽略，将根据 LinkPaths 自动生成

    .EXAMPLE
        A-New-LinkDirectory -LinkPaths @("$env:LocalAppData\nvim","$env:LocalAppData\nvim-data")

    .LINK
        https://github.com/abgox/abyss#link
        https://gitee.com/abgox/abyss#link
    #>
    param (
        [array]$LinkPaths,

        [System.Collections.Generic.List[string]]$LinkTargets = @()
    )

    for ($i = 0; $i -lt $LinkPaths.Count; $i++) {
        $LinkPath = $LinkPaths[$i]
        $LinkTarget = $LinkTargets[$i]

        if (!$LinkTarget) {
            if ($LinkPath -notlike "*$env:UserProfile*") {
                Write-Host $words["The number of links is wrong"] -ForegroundColor Red
                A-Exit
            }
            $LinkTargets.Add($LinkPath.replace($env:UserProfile, $persist_dir))
        }
    }

    A-New-Link -LinkPaths $LinkPaths -LinkTargets $LinkTargets -ItemType Junction -OutFile "$dir\scoop-install-A-New-LinkDirectory.jsonc"
}

function A-Remove-Link {
    <#
    .SYNOPSIS
        删除链接: SymbolicLink、Junction

    .DESCRIPTION
        该函数用于删除在应用安装过程中创建的 SymbolicLink 和 Junction
    #>

    if ((Test-Path "$dir\scoop-install-A-Add-AppxPackage.jsonc") -or (Test-Path "$dir\scoop-install-A-Install-Exe.jsonc")) {
        # 通过 Msix 打包的程序或安装程序安装的应用，在卸载时会删除所有数据文件，因此必须先删除链接目录以保留数据
    }
    elseif ($cmd -eq "update" -or $uninstallActionLevel -notlike "*2*") {
        return
    }

    @("$dir\scoop-install-A-New-LinkFile.jsonc", "$dir\scoop-install-A-New-LinkDirectory.jsonc") | ForEach-Object {
        if (Test-Path $_) {
            $LinkPaths = Get-Content $_ -Raw | ConvertFrom-Json | Select-Object -ExpandProperty "LinkPaths"

            if ($LinkPaths) {
                Write-Host "`n$($words["Removing link:"])" -ForegroundColor Yellow
                Write-Host "-----"
                foreach ($p in $LinkPaths) {
                    if (Test-Path $p) {
                        Write-Host $p -ForegroundColor Cyan
                        Remove-Item $p -Force -Recurse -ErrorAction SilentlyContinue
                    }
                }
                Write-Host "-----`n"
            }
        }
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
    #>
    param (
        [array]$Paths
    )

    if ($cmd -eq "update" -or $uninstallActionLevel -notlike "*3*") {
        return
    }
    if ($Paths) {
        Write-Host "`n$($words["Removing Temp data:" ])" -ForegroundColor Yellow
        Write-Host "-----"
        foreach ($_ in $Paths) {
            if (Test-Path $_ ) {
                Write-Host $_ -ForegroundColor Cyan
                Remove-Item $_ -Force -Recurse -ErrorAction SilentlyContinue
            }
        }
        Write-Host "-----`n"
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

    .PARAMETER ExtraProcessNames
        要搜索的额外进程名称数组。

    .NOTES
        Msix/Appx 在移除包时会自动终止进程，不需要手动终止，除非显示指定 ExtraPaths
    #>
    param(
        [string[]]$ExtraPaths,

        [string[]]$ExtraProcessNames
    )

    $Paths = @($dir, (Split-Path $dir -Parent) + '\current')
    $Paths += $ExtraPaths

    if ($ExtraProcessNames) {
        foreach ($processName in $ExtraProcessNames) {
            $p = Get-Process -Name $processName -ErrorAction SilentlyContinue
            if ($p) {
                try {
                    Stop-Process -Id $p.Id -Force -ErrorAction Stop
                    Write-Host "$($words["Successfully terminated the process:"]) $($p.Id) $($p.Name) ($($p.MainModule.FileName))" -ForegroundColor Green
                }
                catch {
                    Write-Host "$($words["Failed to terminate the process:"]) $($p.Id) $($p.Name)`n$($words["Maybe try again"])" -ForegroundColor Red
                }
            }
        }
    }

    # Msix/Appx 在移除包时会自动终止进程，不需要手动终止，除非显示指定 ExtraPaths
    if ($uninstallActionLevel -notlike "*1*" -or ((Test-Path "$dir\scoop-install-A-Add-AppxPackage.jsonc") -and !$PSBoundParameters.ContainsKey('ExtraPaths'))) {
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
                Write-Host "$($words["Failed to terminate the process:"]) $($m.Id) $($m.Name)`n$($words["Maybe try again"])" -ForegroundColor Red
                exit 1
            }
        }
    }

    if ($NoFound) {
        Write-Host "$($words["No running processes found."])$($words["If failed to uninstall, You may need to try again"])" -ForegroundColor Yellow
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
    #>
    param(
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
        Write-Host "$($words["Failed to terminate the service:"]) $ServiceName `n$($words["Maybe try again"])" -ForegroundColor Red
        exit 1
    }

    try {
        Remove-Service -Name $ServiceName -ErrorAction Stop
    }
    catch {
        Write-Host "$($words["Failed to remove the service:" ]) $ServiceName `n$($words["Maybe try again"])" -ForegroundColor Red
        exit 1
    }
}

function A-Start-PreInstall {
    <#
    .SYNOPSIS
        此函数运行之后，开始执行 pre_install
    #>
}

function A-Start-PostInstall {
    <#
    .SYNOPSIS
        此函数运行之后，开始执行 post_install
    #>
}

Function A-Start-PreUninstall {
    <#
    .SYNOPSIS
        此函数运行之后，开始执行 pre_uninstall
    #>
}

Function A-Start-PostUninstall {
    <#
    .SYNOPSIS
        此函数运行之后，开始执行 post_uninstall
    #>
}

function A-Install-Exe {
    param(
        [string]$Installer,
        [array]$ArgumentList,
        # 表示安装成功的标志文件，如果此路径或文件存在，则认为安装成功
        [string]$SuccessFile,
        # 仅用于标识，如果可能需要用户交互，则 $NoSilent 为 $true
        [switch]$NoSilent,
        # 超时时间（秒）
        [string]$Timeout = 300
    )

    # 如果没有传递安装参数，则使用默认参数
    if (!$PSBoundParameters.ContainsKey('ArgumentList')) {
        $ArgumentList = @('/S', "/D=$dir")
    }

    if ($PSBoundParameters.ContainsKey('Installer')) {
        $path = "$dir\$Installer"
    }
    else {
        # $fname 由 Scoop 提供，即下载的文件名
        $path = if ($fname -is [array]) { "$dir\$($fname[0])" }else { "$dir\$fname" }
    }
    $fileName = Split-Path $path -Leaf


    $OutFile = "$dir\scoop-install-A-Install-Exe.jsonc"
    @{
        Installer    = $path
        ArgumentList = $ArgumentList
        SuccessFile  = $SuccessFile
    } | ConvertTo-Json | Out-File -FilePath $OutFile -Force -Encoding utf8

    if (Test-Path $path) {
        try {
            if ($ShowCN) {
                Write-Host "正在运行安装程序 ($fileName) 安装 $app，请耐心等待..." -ForegroundColor Yellow
                # if ($ArgumentList) {
                #     Write-Host "安装程序携带参数: $ArgumentList" -ForegroundColor Yellow
                # }
                if ($NoSilent) {
                    Write-Host "安装程序可能需要你手动进行一些交互操作，如果安装超时($Timeout 秒)，将强行终止安装进程" -ForegroundColor Yellow
                }
            }
            else {
                Write-Host "Installing '$app' using installer ($fileName), please wait..." -ForegroundColor Yellow
                # if ($ArgumentList) {
                #     Write-Host "Installer with arguments: $ArgumentList" -ForegroundColor Yellow
                # }
                if ($NoSilent) {
                    Write-Host "The installer may require you to perform some manual operations, if installation timeout ($Timeout seconds), the process will be terminated." -ForegroundColor Yellow
                }
            }

            if (!$SuccessFile) {
                $SuccessFile = try { $manifest.shortcuts[0][0] }catch { $manifest.architecture.$architecture.shortcuts[0][0] }
                if (!$SuccessFile) {
                    if ($ShowCN) {
                        Write-Host "清单中需要定义 shortcuts 字段，或在 A-Install-Exe 中指定 SuccessFile 参数。" -ForegroundColor Red
                    }
                    else {
                        Write-Host "Manifest needs to define shortcuts field, or SuccessFile parameter needs to be specified in A-Install-Exe." -ForegroundColor Red
                    }
                    A-Exit
                }
            }

            if (![System.IO.Path]::IsPathRooted($SuccessFile)) {
                $SuccessFile = Join-Path $dir $SuccessFile
            }

            # 在后台作业中运行安装程序，强制停止进程的时机更晚
            $job = Start-Job -ScriptBlock {
                param($path, $ArgumentList)

                Start-Process $path -ArgumentList $ArgumentList -WindowStyle Hidden -PassThru

            } -ArgumentList $path, $ArgumentList

            $startTime = Get-Date
            $fileExists = $false

            while ((New-TimeSpan -Start $startTime -End (Get-Date)).TotalSeconds -lt $Timeout) {
                if (Test-Path $SuccessFile) {
                    $fileExists = $true
                    break
                }
                Start-Sleep -Seconds 5
            }

            $null = Start-Job -ScriptBlock {
                param($path, $job)
                Start-Sleep -Seconds 30

                $job | Stop-Job -ErrorAction SilentlyContinue

                Get-Process | Where-Object { $_.Path -eq $path } | Stop-Process -Force -ErrorAction SilentlyContinue

                Remove-Item $path -Force -ErrorAction SilentlyContinue

            } -ArgumentList $path, $job

            if ($fileExists) {
                if ($ShowCN) {
                    Write-Host "安装成功" -ForegroundColor Green
                }
                else {
                    Write-Host "Installation successful, process terminated." -ForegroundColor Green
                }
            }
            else {
                if ($ShowCN) {
                    Write-Host "安装超时($Timeout 秒)" -ForegroundColor Red
                }
                else {
                    Write-Host "Installation timeout ($Timeout seconds)." -ForegroundColor Red
                }
                A-Exit
            }
        }
        catch {
            Write-Host $_.Exception.Message -ForegroundColor Red
            A-Exit
        }
    }
    else {
        if ($ShowCN) {
            Write-Host "未找到安装程序: $path" -ForegroundColor Red
        }
        else {
            Write-Host "Installer not found: $path" -ForegroundColor Red
        }
        A-Exit
    }
}

function A-Uninstall-Exe {
    param(
        [string]$Uninstaller,
        [array]$ArgumentList,
        # 仅用于标识，如果可能需要用户交互，则 $NoSilent 为 $true
        [switch]$NoSilent,
        # 超时时间（秒）
        [string]$Timeout = 300,
        # 如果存在这个 FailureFile 指定的文件，则认定为卸载失败
        [string]$FailureFile
    )

    # 如果没有传递卸载参数，则使用默认参数
    if (!$PSBoundParameters.ContainsKey('ArgumentList')) {
        $ArgumentList = @('/S')
    }

    if ([System.IO.Path]::IsPathRooted($Uninstaller)) {
        $path = $Uninstaller
    }
    else {
        $path = "$dir\$Uninstaller"
    }
    $fileName = Split-Path $path -Leaf

    if ($ShowCN) {
        Write-Host "正在运行卸载程序 ($fileName) 卸载 $app，请耐心等待..." -ForegroundColor Yellow
        # if ($ArgumentList) {
        #     Write-Host "卸载程序携带参数: $ArgumentList" -ForegroundColor Yellow
        # }
        if ($NoSilent) {
            Write-Host "卸载程序可能需要你手动进行一些交互操作，如果卸载超时($Timeout 秒)，将强行终止卸载进程" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "Uninstalling '$app' using uninstaller ($fileName), please wait..." -ForegroundColor Yellow
        # if ($ArgumentList) {
        #     Write-Host "Uninstaller with arguments: $ArgumentList" -ForegroundColor Yellow
        # }
        if ($NoSilent) {
            Write-Host "The uninstaller may require you to perform some manual operations. If uninstallation timeout ($Timeout seconds), the process will be terminated." -ForegroundColor Yellow
        }
    }

    if (Test-Path $path) {
        try {
            if ($NoSilent) {
                $process = Start-Process $path -ArgumentList $ArgumentList -PassThru
            }
            else {
                $process = Start-Process $path -ArgumentList $ArgumentList -WindowStyle Hidden -Wait -PassThru
            }

            try {
                $process | Wait-Process -Timeout $Timeout -ErrorAction Stop
            }
            catch {
                $process | Stop-Process -Force -ErrorAction SilentlyContinue
                if ($ShowCN) {
                    Write-Host "卸载程序运行超时($Timeout 秒)，强行终止" -ForegroundColor Red
                }
                else {
                    Write-Host "Uninstaller timeout ($Timeout seconds), process terminated." -ForegroundColor Red
                }
                exit 1
            }

            if ($PSBoundParameters.ContainsKey('FailureFile') -and (Test-Path $FailureFile)) {
                if ($ShowCN) {
                    Write-Host "应用程序未被卸载程序移除: $FailureFile`n$app 卸载失败" -ForegroundColor Red
                }
                else {
                    Write-Host "The application not removed by uninstaller: $FailureFile`nFailed to uninstall $app." -ForegroundColor Red
                }
                exit 1
            }
        }
        catch {
            Write-Host $_.Exception.Message -ForegroundColor Red
            exit 1
        }
    }
}

function A-Add-MsixPackage {
    param(
        [string]$FileName
    )
    if ($PSBoundParameters.ContainsKey('FileName')) {
        $path = "$dir\$FileName"
    }
    else {
        # $fname 由 Scoop 提供，即下载的文件名
        $path = if ($fname -is [array]) { "$dir\$($fname[0])" }else { "$dir\$fname" }
    }

    A-Add-AppxPackage -Path $path
}

function A-Remove-MsixPackage {
    A-Remove-AppxPackage
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
            Write-Host "$app 字体已经成功卸载，但可能有系统缓存，需要重启系统后才能完全删除。" -Foreground Magenta
        }
        else {
            Write-Host "The '$app' Font family has been uninstalled successfully, but there may be system cache that needs to be restarted to fully remove." -Foreground Magenta
        }
    }
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
        A-Ensure-Directory (Split-Path $PluginPath -Parent)
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
        A-Exit
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

function A-Require-Admin {
    <#
    .SYNOPSIS
        要求以管理员权限运行
    #>

    if (!$isAdmin) {
        if ($ShowCN) {
            Write-Host "这个操作需要管理员权限。`n请使用管理员权限再次尝试。" -ForegroundColor Red
        }
        else {
            Write-Host "It requires administrator permission.`nPlease try again with administrator permission." -ForegroundColor Red
        }
        A-Exit
    }
}

function A-Get-InstallerInfoFromWinget {
    <#
    .SYNOPSIS
        从 winget 获取安装信息

    .DESCRIPTION
        该函数使用 winget 获取应用程序安装信息，并返回一个包含安装信息的对象。

    .PARAMETER Package
        软件包。
        格式: Publisher.PackageIdentifier
        比如: Microsoft.VisualStudioCode

    .PARAMETER InstallerType
        要获取的安装包的类型(后缀名)，如 zip/exe/msi/...
        可以指定为空，表示任意类型。
    #>
    param(
        [string]$Package,
        [string]$InstallerType
    )

    $hasCommand = Get-Command -Name ConvertFrom-Yaml -ErrorAction SilentlyContinue
    if (!$hasCommand) {
        try {
            Write-Host "正在安装并导入 powershell-yaml 模块" -ForegroundColor Green
            Install-Module powershell-yaml -Repository PSGallery -Force
            Import-Module -Name powershell-yaml -Force
            Write-Host "安装并导入 powershell-yaml 模块成功" -ForegroundColor Green
        }
        catch {
            Write-Host "::error::安装并导入 powershell-yaml 模块失败" -ForegroundColor Red
        }
    }

    Write-Host
    Write-Host "正在从 winget-pkgs 中获取 $Package 安装信息" -ForegroundColor Green

    $rootDir = $Package.ToLower()[0]

    $PackageIdentifier = $Package
    $PackagePath = $Package -replace '\.', '/'

    $url = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/$rootDir/$PackagePath"

    try {
        Write-Host "正在访问: $url" -ForegroundColor Green
        $parameters = @{
            'Uri'                      = $url
            'ConnectionTimeoutSeconds' = 10
            'OperationTimeoutSeconds'  = 15
        }
        if ($env:GITHUB_TOKEN) {
            $parameters.Add('Headers', @{ 'Authorization' = "token $env:GITHUB_TOKEN" })
        }
        $versionList = Invoke-WebRequest @parameters
    }
    catch {
        Write-Host "::error::访问 $url 失败" -ForegroundColor Red
        Write-Host
        return
    }

    $latestVersion = ""

    $versionList.Content | ConvertFrom-Json | ForEach-Object { if ($_.Name -notmatch '^\.') { $_.Name } } | ForEach-Object {
        $compare = A-Compare-Version $_ $latestVersion
        if ($compare -gt 0) {
            $latestVersion = $_
        }
    }

    Write-Host "$app 的最新版本: $latestVersion" -ForegroundColor Green

    $url = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/$rootDir/$PackagePath/$latestVersion/$PackageIdentifier.installer.yaml"

    try {
        Write-Host "正在访问: $url" -ForegroundColor Green
        $parameters = @{
            'Uri'                      = $url
            'ConnectionTimeoutSeconds' = 10
            'OperationTimeoutSeconds'  = 15
        }
        if ($env:GITHUB_TOKEN) {
            $parameters.Add('Headers', @{ 'Authorization' = "token $env:GITHUB_TOKEN" })
        }
        $installerYaml = Invoke-WebRequest @parameters
    }
    catch {
        Write-Host "::error::访问 $url 失败" -ForegroundColor Red
        Write-Host
        return
    }

    $installerInfo = ConvertFrom-Yaml $installerYaml.Content

    if (!$installerInfo) {
        return
    }

    $scope = $installerInfo.Scope
    $InstallerLocale = $installerInfo.InstallerLocale

    foreach ($_ in $installerInfo.Installers) {
        $arch = $_.Architecture

        $fileName = [System.IO.Path]::GetFileName($_.InstallerUrl.Split('?')[0].Split('#')[0])
        $extension = [System.IO.Path]::GetExtension($fileName).TrimStart('.')
        $type = $extension.ToLower()

        $matchType = $true
        if ($InstallerType) {
            $matchType = $type -eq $InstallerType
        }

        if ($arch -and $matchType) {
            $key = $arch
            $installerInfo.$key = $_

            if ($scope) {
                $key += '_' + $scope.ToLower()
            }
            elseif ($_.Scope) {
                $key += '_' + $_.Scope.ToLower()
            }
            else {
                $key += '_machine'
            }
            $installerInfo.$key = $_

            if ($InstallerLocale) {
                $key += '_' + $InstallerLocale
            }
            elseif ($_.InstallerLocale) {
                $key += '_' + $_.InstallerLocale
            }
            $installerInfo.$key = $_
        }
    }

    # 写入到 bin\scoop-auto-check-update-temp-data.jsonc，用于后续读取
    $installerInfo | ConvertTo-Json -Depth 100 | Out-File -FilePath "$PSScriptRoot\scoop-auto-check-update-temp-data.jsonc" -Force -Encoding utf8

    Write-Host "$Package 安装信息获取成功，进行版本比对" -ForegroundColor Green
    Write-Host

    $installerInfo
}

function A-Compare-Version {
    <#
    .SYNOPSIS
        比较两个版本号字符串的大小，支持多种格式混合排序。

    .DESCRIPTION
        比较两个版本号字符串的大小，并返回 1 / -1 / 0
        1 表示 v1 大于 v2
        -1 表示 v1 小于 v2
        0 表示 v1 等于 v2

    .PARAMETER v1
        第一个版本号字符串。

    .PARAMETER v2
        第二个版本号字符串。
    #>
    param (
        [string]$v1,
        [string]$v2
    )

    # 将版本号拆分成数组，支持 . 和 - 作为分隔符
    $parts1 = $v1 -split '[\.\-]'
    $parts2 = $v2 -split '[\.\-]'

    $maxLength = [Math]::Max($parts1.Length, $parts2.Length)

    for ($i = 0; $i -lt $maxLength; $i++) {
        $p1 = if ($i -lt $parts1.Length) { $parts1[$i] } else { '' }
        $p2 = if ($i -lt $parts2.Length) { $parts2[$i] } else { '' }

        # 尝试将部分转换为数字
        $num1 = 0
        $num2 = 0
        $isNum1 = [int]::TryParse($p1, [ref]$num1)
        $isNum2 = [int]::TryParse($p2, [ref]$num2)
        if ($isNum1 -and $isNum2) {
            if ($num1 -gt $num2) { return 1 }
            elseif ($num1 -lt $num2) { return -1 }
        }
        elseif ($isNum1 -and !$isNum2) {
            # 数字比字符串大
            return 1
        }
        elseif (!$isNum1 -and $isNum2) {
            return -1
        }
        else {
            # 都是字符串，直接比较
            $cmp = [string]::Compare($p1, $p2)
            if ($cmp -ne 0) { return $cmp }
        }
    }

    # 所有部分都相等
    return 0
}


#region 以下的函数不建议直接使用。在文件的开头有列出可用的函数。
function A-New-Link {
    <#
    .SYNOPSIS
        创建链接: SymbolicLink 或 Junction

    .DESCRIPTION
        该函数用于将现有文件替换为指向目标文件的链接。
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
        Write-Host $words["The number of links is wrong"] -ForegroundColor Red
        A-Exit
    }

    $installData = @{
        "LinkPaths" = @()
    }

    if ($LinkPaths.Count) {
        Write-Host

        for ($i = 0; $i -lt $LinkPaths.Count; $i++) {
            $linkPath = $LinkPaths[$i]
            $linkTarget = $LinkTargets[$i]
            $installData.LinkPaths += $linkPath
            if ((Test-Path $linkPath) -and !(Get-Item $linkPath).LinkType) {
                if (!(Test-Path $linkTarget)) {
                    A-Ensure-Directory (Split-Path $linkTarget -Parent)
                    Write-Host $words["Copying"] -ForegroundColor Yellow -NoNewline
                    Write-Host " $linkPath" -ForegroundColor Cyan -NoNewline
                    Write-Host " => " -NoNewline
                    Write-Host $linkTarget -ForegroundColor Cyan
                    try {
                        Copy-Item -Path $linkPath -Destination $linkTarget -Recurse -Force -ErrorAction Stop
                    }
                    catch {
                        Remove-Item $linkTarget -Recurse -Force -ErrorAction SilentlyContinue
                        Write-Host $_.Exception.Message -ForegroundColor Red
                        A-Exit
                    }
                }
                try {
                    Write-Host $words["Removing"] -ForegroundColor Yellow -NoNewline
                    Write-Host " $linkPath" -ForegroundColor Cyan
                    Remove-Item $linkPath -Recurse -Force -ErrorAction Stop
                }
                catch {
                    Write-Host "$($words["Failed to remove:"]) $linkPath" -ForegroundColor Red
                    Write-Host $words["Failed to $cmd $app."] -ForegroundColor Red
                    Write-Host $words["Please stop the relevant processes and try to $cmd $app again."] -ForegroundColor Red
                    A-Exit
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
            Write-Host $words["Linking"] -ForegroundColor Yellow -NoNewline
            Write-Host " $linkPath" -ForegroundColor Cyan -NoNewline
            Write-Host " => " -NoNewline
            Write-Host $linkTarget -ForegroundColor Cyan
        }
        Write-Host

        $installData | ConvertTo-Json | Out-File -FilePath $OutFile -Force -Encoding utf8
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
    #>
    param(
        [string]$Path
    )

    try {
        Add-AppxPackage -Path $Path -AllowUnsigned -ForceApplicationShutdown -ForceUpdateFromAnyVersion -ErrorAction Stop
    }
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        A-Exit
    }

    $installData = @{
        package = @{
            PackageFamilyName = $PackageFamilyName
        }
    }
    $installData | ConvertTo-Json | Out-File -FilePath "$dir\scoop-install-A-Add-AppxPackage.jsonc" -Force -Encoding utf8

    if ($ShowCN) {
        Write-Host "$app 的程序安装目录不在 Scoop 中。`nScoop 只管理可能的数据 persist，应用的安装、更新以及卸载操作。" -ForegroundColor Yellow
    }
    else {
        Write-Host "The installation directory of $app is not in Scoop.`nScoop only manages the possible persistence of data, and the installation, update, uninstallation." -ForegroundColor Yellow
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

function A-Exit {
    if ($cmd -eq 'install') {
        Write-Host
        scoop uninstall $app
    }
    exit 1
}
#endregion


#region 废弃函数，不要在清单中使用。你应该使用在文件的开头列出的可用的函数。
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
function A-Remove-LinkFile {
    <#
    .SYNOPSIS
        删除在应用安装过程中创建的链接文件
    #>

    A-Remove-Link
}

function A-Remove-LinkDirectory {
    <#
    .SYNOPSIS
        删除在应用安装过程中创建的链接目录
    #>

    A-Remove-Link
}
#endregion



# 重写的函数是基于这个 Scoop 版本的。
# 如果 Scoop 最新版本大于它，需要检查重写的函数，如果新版本中这些函数有变动，需要立即修正，然后更新此处的 Scoop 版本号
$ScoopVersion = "0.5.2"

#region 重写部分 Scoop 内置函数，添加本地化输出

#region function env_set: https://github.com/ScoopInstaller/Scoop/blob/master/lib/install.ps1#L901
Set-Item -Path Function:\env_set -Value {
    param($manifest, $global, $arch)
    $env_set = arch_specific 'env_set' $manifest $arch

    if ($env_set) {
        $env_set | Get-Member -MemberType NoteProperty | ForEach-Object {
            $name = $_.Name
            $val = $ExecutionContext.InvokeCommand.ExpandString($env_set.$($name))
            if ($PSUICulture -like "zh*" -and $cmd) {
                Write-Output "正在设置环境变量$(if($global){'(系统级)'}else{'(当前用户)'}): $name = $val"
            }
            else {
                Write-Output "Setting environment variable$(if($global){'(system)'}else{'(for current user)'}): $name = $val"
            }
            Set-EnvVar -Name $name -Value $val -Global:$global
            Set-Content env:\$name $val
        }
    }
}
#endregion

#region function env_rm: https://github.com/ScoopInstaller/Scoop/blob/master/lib/install.ps1#L912
Set-Item -Path Function:\env_rm -Value {
    param($manifest, $global, $arch)
    $env_set = arch_specific 'env_set' $manifest $arch
    if ($env_set) {
        $env_set | Get-Member -MemberType NoteProperty | ForEach-Object {
            $name = $_.Name
            if ($PSUICulture -like "zh*" -and $cmd) {
                Write-Output "正在移除环境变量$(if($global){'(系统级)'}else{'(当前用户)'}): $name"
            }
            else {
                Write-Output "Removing environment variable$(if($global){'(system)'}else{'(for current user)'}): $name"
            }
            Set-EnvVar -Name $name -Value $null -Global:$global
            if (Test-Path env:\$name) { Remove-Item env:\$name }
        }
    }
}
#endregion

if ($ShowCN) {

    #region 用于打印的函数

    #region function abort: https://github.com/ScoopInstaller/Scoop/blob/master/lib/core.ps1#L334
    # Set-Item -Path Function:\abort -Value {
    #     param($msg, [int] $exit_code = 1)

    #     function Translate-Message {
    #         param([string]$msg)

    #         if ($msgMap.ContainsKey($msg)) {
    #             return $msgMap[$msg]
    #         }

    #         foreach ($pattern in $msgMap.Keys | Where-Object { $_ -match '\{\d+\}' }) {
    #             $escapedPattern = [regex]::Escape($pattern)
    #             $regexPattern = $escapedPattern -replace '\\\{\d+\}', '(.*)'

    #             $match = [regex]::Match($msg, $regexPattern)
    #             if ($match.Success) {
    #                 $translation = $msgMap[$pattern]
    #                 $translation = [regex]::Replace($translation, '\{(\d+)\}', {
    #                         param($m)
    #                         $index = [int]$m.Groups[1].Value
    #                         return $match.Groups[$index + 1].Value.Trim()
    #                     })
    #                 return $translation
    #             }
    #         }

    #         return $msg
    #     }

    #     $msgMap = @{
    #         "Error: Version 'current' is not allowed!" = "错误：不允许使用 current 作为版本!"
    #     }

    #     $translated = Translate-Message $msg

    #     Write-Host $msg -f red; exit $exit_code
    # }
    #endregion

    #region function error: https://github.com/ScoopInstaller/Scoop/blob/master/lib/core.ps1#L335
    Set-Item -Path Function:\error -Value {
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
            "'$App' isn't installed correctly." = "$App 未正确安装。"
        }

        $translated = Translate-Message $msg
        Write-Host "错误: $translated" -f darkred
    }
    #endregion

    # function warn: https://github.com/ScoopInstaller/Scoop/blob/master/lib/core.ps1#L336

    # function info: https://github.com/ScoopInstaller/Scoop/blob/master/lib/core.ps1#L337

    #region function success: https://github.com/ScoopInstaller/Scoop/blob/master/lib/core.ps1#L367
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
            "'$app' ($version) was installed successfully!" = "$app ($version) 已成功安装!"
            "'{0}' was uninstalled."                        = "{0} 已成功卸载!"
        }

        $translated = Translate-Message $msg

        Write-Host $translated -ForegroundColor darkgreen
    }
    #endregion

    #endregion

    #region 安装前的准备，下载安装包

    #region function Invoke-HookScript: https://github.com/ScoopInstaller/Scoop/blob/master/lib/install.ps1#L713
    Set-Item -Path Function:\Invoke-HookScript -Value {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [ValidateSet('installer', 'pre_install', 'post_install', 'uninstaller', 'pre_uninstall', 'post_uninstall')]
            [String] $HookType,
            [Parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [PSCustomObject] $Manifest,
            [Parameter(Mandatory = $true)]
            [Alias('Arch', 'Architecture')]
            [ValidateSet('32bit', '64bit', 'arm64')]
            [string]
            $ProcessorArchitecture
        )

        $script = arch_specific $HookType $Manifest $ProcessorArchitecture
        if ($HookType -in @('installer', 'uninstaller')) {
            $script = $script.script
        }
        if ($script) {
            Write-Host "正在运行 $HookType 脚本..." -NoNewline
            Invoke-Command ([scriptblock]::Create($script -join "`r`n"))
            Write-Host '完成!' -ForegroundColor Green
        }
    }
    #endregion

    #region function ensure_install_dir_not_in_path: https://github.com/ScoopInstaller/Scoop/blob/master/lib/install.ps1#L849
    Set-Item -Path Function:\ensure_install_dir_not_in_path -Value {
        param($dir, $global)
        $path = (Get-EnvVar -Name 'PATH' -Global:$global)

        $fixed, $removed = find_dir_or_subdir $path "$dir"
        if ($removed) {
            $removed | ForEach-Object { "安装程序已将 '$(friendly_path $_)' 添加到环境变量 Path 中，正在删除。" }
            Set-EnvVar -Name 'PATH' -Value $fixed -Global:$global
        }

        if (!$global) {
            $fixed, $removed = find_dir_or_subdir (Get-EnvVar -Name 'PATH' -Global) "$dir"
            if ($removed) {
                $removed | ForEach-Object { warn "安装程序在系统环境变量 Path 中添加了 $_，你可能需要手动删除 (需要管理员权限)。" }
            }
        }
    }
    #endregion

    #region function Invoke-ScoopDownload: https://github.com/ScoopInstaller/Scoop/blob/master/lib/install.ps1#L539
    # Set-Item -Path Function:\Invoke-ScoopDownload -Value {
    #     param($app, $version, $manifest, $bucket, $architecture, $dir, $use_cache = $true, $check_hash = $true)
    #     # we only want to show this warning once
    #     if (!$use_cache) { warn '缓存被忽略。' }

    #     # can be multiple urls: if there are, then installer should go first to make 'installer.args' section work
    #     $urls = @(script:url $manifest $architecture)

    #     # can be multiple cookies: they will be used for all HTTP requests.
    #     $cookies = $manifest.cookie

    #     # download first
    #     if (Test-Aria2Enabled) {
    #         Invoke-CachedAria2Download $app $version $manifest $architecture $dir $cookies $use_cache $check_hash
    #     }
    #     else {
    #         foreach ($url in $urls) {
    #             $fname = url_filename $url

    #             try {
    #                 Invoke-CachedDownload $app $version $url "$dir\$fname" $cookies $use_cache
    #             }
    #             catch {
    #                 Write-Host -f darkred $_
    #                 abort "URL $url 是无效的。"
    #             }

    #             if ($check_hash) {
    #                 $manifest_hash = hash_for_url $manifest $url $architecture
    #                 $ok, $err = check_hash "$dir\$fname" $manifest_hash $(show_app $app $bucket)
    #                 if (!$ok) {
    #                     error $err
    #                     $cached = cache_path $app $version $url
    #                     if (Test-Path $cached) {
    #                         # rm cached file
    #                         Remove-Item -Force $cached
    #                     }
    #                     if ($url.Contains('sourceforge.net')) {
    #                         Write-Host -f yellow 'SourceForge.net 经常导致哈希验证失败。请在提交工单前重试。'
    #                     }
    #                     abort $(new_issue_msg $app $bucket 'hash 检查失败')
    #                 }
    #             }
    #         }
    #     }

    #     return $urls.ForEach({ url_filename $_ })
    # }
    #endregion

    #region function Invoke-CachedAria2Download: https://github.com/ScoopInstaller/Scoop/blob/master/lib/install.ps1#L186
    Set-Item -Path Function:\Invoke-CachedAria2Download -Value {
        param($app, $version, $manifest, $architecture, $dir, $cookies = $null, $use_cache = $true, $check_hash = $true)

        $data = @{}
        $urls = @(script:url $manifest $architecture)

        # aria2 input file
        $urlstxt = Join-Path $cachedir "$app.txt"
        $urlstxt_content = ''
        $download_finished = $true

        # aria2 options
        $options = @(
            "--input-file='$urlstxt'"
            "--user-agent='$(Get-UserAgent)'"
            '--allow-overwrite=true'
            '--auto-file-renaming=false'
            "--retry-wait=$(get_config 'aria2-retry-wait' 2)"
            "--split=$(get_config 'aria2-split' 5)"
            "--max-connection-per-server=$(get_config 'aria2-max-connection-per-server' 5)"
            "--min-split-size=$(get_config 'aria2-min-split-size' '5M')"
            '--console-log-level=warn'
            '--enable-color=false'
            '--no-conf=true'
            '--follow-metalink=true'
            '--metalink-preferred-protocol=https'
            '--min-tls-version=TLSv1.2'
            "--stop-with-process=$PID"
            '--continue'
            '--summary-interval=0'
            '--auto-save-interval=1'
        )

        if ($cookies) {
            $options += "--header='Cookie: $(cookie_header $cookies)'"
        }

        $proxy = get_config PROXY
        if ($proxy -ne 'none') {
            if ([Net.Webrequest]::DefaultWebProxy.Address) {
                $options += "--all-proxy='$([Net.Webrequest]::DefaultWebProxy.Address.Authority)'"
            }
            if ([Net.Webrequest]::DefaultWebProxy.Credentials.UserName) {
                $options += "--all-proxy-user='$([Net.Webrequest]::DefaultWebProxy.Credentials.UserName)'"
            }
            if ([Net.Webrequest]::DefaultWebProxy.Credentials.Password) {
                $options += "--all-proxy-passwd='$([Net.Webrequest]::DefaultWebProxy.Credentials.Password)'"
            }
        }

        $more_options = get_config 'aria2-options'
        if ($more_options) {
            $options += $more_options
        }

        foreach ($url in $urls) {
            $data.$url = @{
                'target'    = Join-Path $dir (url_filename $url)
                'cachename' = fname (cache_path $app $version $url)
                'source'    = cache_path $app $version $url
            }

            if ((Test-Path $data.$url.source) -and -not((Test-Path "$($data.$url.source).aria2") -or (Test-Path $urlstxt)) -and $use_cache) {
                Write-Host '从缓存中加载 ' -NoNewline
                Write-Host $(url_remote_filename $url) -f Cyan
            }
            else {
                $download_finished = $false
                # create aria2 input file content
                try {
                    $try_url = handle_special_urls $url
                }
                catch {
                    if ($_.Exception.Response.StatusCode -eq 'Unauthorized') {
                        warn '令牌可能会被错误配置。'
                    }
                }
                $urlstxt_content += "$try_url`n"
                if (!$url.Contains('sourceforge.net')) {
                    $urlstxt_content += "    referer=$(strip_filename $url)`n"
                }
                $urlstxt_content += "    dir=$cachedir`n"
                $urlstxt_content += "    out=$($data.$url.cachename)`n"
            }
        }

        if (-not($download_finished)) {
            # write aria2 input file
            if ($urlstxt_content -ne '') {
                ensure $cachedir | Out-Null
                # Write aria2 input-file with UTF8NoBOM encoding
                $urlstxt_content | Out-UTF8File -FilePath $urlstxt
            }

            # build aria2 command
            $aria2 = "& '$(Get-HelperPath -Helper Aria2)' $($options -join ' ')"

            # handle aria2 console output
            Write-Host '正在使用 aria2 下载...'

            # Set console output encoding to UTF8 for non-ASCII characters printing
            $oriConsoleEncoding = [Console]::OutputEncoding
            [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding

            Invoke-Command ([scriptblock]::Create($aria2)) | ForEach-Object {
                # Skip blank lines
                if ([String]::IsNullOrWhiteSpace($_)) { return }

                # Prevent potential overlaping of text when one line is shorter
                $len = $Host.UI.RawUI.WindowSize.Width - $_.Length - 20
                $blank = if ($len -gt 0) { ' ' * $len } else { '' }
                $color = 'Gray'

                if ($_.StartsWith('(OK):')) {
                    $noNewLine = $true
                    $color = 'Green'
                }
                elseif ($_.StartsWith('[') -and $_.EndsWith(']')) {
                    $noNewLine = $true
                    $color = 'Cyan'
                }
                elseif ($_.StartsWith('Download Results:')) {
                    $noNewLine = $false
                }

                Write-Host "`r下载: $_$blank" -ForegroundColor $color -NoNewline:$noNewLine
            }
            Write-Host ''

            if ($lastexitcode -gt 0) {
                error "下载失败! (Error $lastexitcode) $(aria_exit_code $lastexitcode)"
                error $urlstxt_content
                error $aria2
                abort $(new_issue_msg $app $bucket 'download via aria2 failed')
            }

            # remove aria2 input file when done
            if (Test-Path $urlstxt, "$($data.$url.source).aria2*") {
                Remove-Item $urlstxt -Force -ErrorAction SilentlyContinue
                Remove-Item "$($data.$url.source).aria2*" -Force -ErrorAction SilentlyContinue
            }

            # Revert console encoding
            [Console]::OutputEncoding = $oriConsoleEncoding
        }

        foreach ($url in $urls) {

            $metalink_filename = get_filename_from_metalink $data.$url.source
            if ($metalink_filename) {
                Remove-Item $data.$url.source -Force
                Rename-Item -Force (Join-Path -Path $cachedir -ChildPath $metalink_filename) $data.$url.source
            }

            # run hash checks
            if ($check_hash) {
                $manifest_hash = hash_for_url $manifest $url $architecture
                $ok, $err = check_hash $data.$url.source $manifest_hash $(show_app $app $bucket)
                if (!$ok) {
                    error $err
                    if (Test-Path $data.$url.source) {
                        # rm cached file
                        Remove-Item $data.$url.source -Force -ErrorAction SilentlyContinue
                        Remove-Item "$($data.$url.source).aria2*" -Force -ErrorAction SilentlyContinue
                    }
                    if ($url.Contains('sourceforge.net')) {
                        Write-Host -f yellow 'SourceForge.net 经常导致哈希验证失败。请在提交工单前重试。'
                    }
                    abort $(new_issue_msg $app $bucket 'hash 检查失败')
                }
            }

            # copy or move file to target location
            if (!(Test-Path $data.$url.source) ) {
                abort $(new_issue_msg $app $bucket '缓存文件不存在')
            }

            if (!($dir -eq $cachedir)) {
                if ($use_cache) {
                    Copy-Item $data.$url.source $data.$url.target
                }
                else {
                    Move-Item $data.$url.source $data.$url.target -Force
                }
            }
        }
    }
    #endregion

    #region function Invoke-CachedDownload: https://github.com/ScoopInstaller/Scoop/blob/master/lib/install.ps1#L84
    # Set-Item -Path Function:\Invoke-CachedDownload -Value {
    #     param($app, $version, $url, $to, $cookies = $null, $use_cache = $true)
    #     $cached = cache_path $app $version $url

    #     if (!(Test-Path $cached) -or !$use_cache) {
    #         ensure $cachedir | Out-Null
    #         Start-Download $url "$cached.download" $cookies
    #         Move-Item "$cached.download" $cached -Force
    #     }
    #     else { Write-Host "从缓存中加载 $(url_remote_filename $url)" }

    #     if (!($null -eq $to)) {
    #         if ($use_cache) {
    #             Copy-Item $cached $to
    #         }
    #         else {
    #             Move-Item $cached $to -Force
    #         }
    #     }
    # }
    #endregion

    #region function Invoke-Extraction: https://github.com/ScoopInstaller/Scoop/blob/master/lib/decompress.ps1#L3
    Set-Item -Path Function:\Invoke-Extraction -Value {
        param (
            [string]
            $Path,
            [string[]]
            $Name,
            [psobject]
            $Manifest,
            [Alias('Arch', 'Architecture')]
            [string]
            $ProcessorArchitecture
        )

        $uri = @(url $Manifest $ProcessorArchitecture)
        # 'extract_dir' and 'extract_to' are paired
        $extractDir = @(extract_dir $Manifest $ProcessorArchitecture)
        $extractTo = @(extract_to $Manifest $ProcessorArchitecture)
        $extracted = 0

        for ($i = 0; $i -lt $Name.Length; $i++) {
            # work out extraction method, if applicable
            $extractFn = $null
            switch -regex ($Name[$i]) {
                '\.zip$' {
                    if ((Test-HelperInstalled -Helper 7zip) -or ((get_config 7ZIPEXTRACT_USE_EXTERNAL) -and (Test-CommandAvailable 7z))) {
                        $extractFn = 'Expand-7zipArchive'
                    }
                    else {
                        $extractFn = 'Expand-ZipArchive'
                    }
                    continue
                }
                '\.msi$' {
                    $extractFn = 'Expand-MsiArchive'
                    continue
                }
                '\.exe$' {
                    if ($Manifest.innosetup) {
                        $extractFn = 'Expand-InnoArchive'
                    }
                    continue
                }
                { Test-7zipRequirement -Uri $_ } {
                    $extractFn = 'Expand-7zipArchive'
                    continue
                }
            }
            if ($extractFn) {
                $fnArgs = @{
                    Path            = Join-Path $Path $Name[$i]
                    DestinationPath = Join-Path $Path $extractTo[$extracted]
                    ExtractDir      = $extractDir[$extracted]
                }
                Write-Host '正在解压 ' -NoNewline
                Write-Host $(url_remote_filename $uri[$i]) -ForegroundColor Cyan -NoNewline
                Write-Host ' ... ' -NoNewline
                & $extractFn @fnArgs -Removal
                Write-Host '完成。' -ForegroundColor Green
                $extracted++
            }
        }
    }
    #endregion

    #endregion

    #region 安装和卸载: 创建/移除 Link、shim、快捷方式、环境变量、persist，安装/卸载 PowerShell 模块，显示 notes，显示 suggest

    #region function link_current: https://github.com/ScoopInstaller/Scoop/blob/master/lib/install.ps1#L804
    Set-Item -Path Function:\link_current -Value {
        param($versiondir)
        if (get_config NO_JUNCTION) { return $versiondir.ToString() }

        $currentdir = "$(Split-Path $versiondir)\current"

        Write-Host "正在创建链接: $(friendly_path $currentdir) => $(friendly_path $versiondir)"

        if ($currentdir -eq $versiondir) {
            abort "错误：不允许使用 current 作为版本！请联系 bucket 维护者。"
        }

        if (Test-Path $currentdir) {
            # remove the junction
            attrib -R /L $currentdir
            Remove-Item $currentdir -Recurse -Force -ErrorAction Stop
        }

        New-DirectoryJunction $currentdir $versiondir | Out-Null
        attrib $currentdir +R /L
        return $currentdir
    }
    #endregion

    #region function unlink_current: https://github.com/ScoopInstaller/Scoop/blob/master/lib/install.ps1#L831
    Set-Item -Path Function:\unlink_current -Value {
        param($versiondir)
        if (get_config NO_JUNCTION) { return $versiondir.ToString() }
        $currentdir = "$(Split-Path $versiondir)\current"

        if (Test-Path $currentdir) {
            Write-Host "正在解除链接: $(friendly_path $currentdir)"

            # remove read-only attribute on link
            attrib $currentdir -R /L

            # remove the junction
            Remove-Item $currentdir -Recurse -Force -ErrorAction Stop
            return $currentdir
        }
        return $versiondir
    }
    #endregion

    #region function create_shims: https://github.com/ScoopInstaller/Scoop/blob/master/lib/install.ps1#L746
    Set-Item -Path Function:\create_shims -Value {
        param($manifest, $dir, $global, $arch)
        $shims = @(arch_specific 'bin' $manifest $arch)
        $shims | Where-Object { $_ -ne $null } | ForEach-Object {
            $target, $name, $arg = shim_def $_
            Write-Output "正在为 $name 创建 shim"

            if (Test-Path "$dir\$target" -PathType leaf) {
                $bin = "$dir\$target"
            }
            elseif (Test-Path $target -PathType leaf) {
                $bin = $target
            }
            else {
                $bin = (Get-Command $target).Source
            }
            if (!$bin) { abort "不能创建 shim '$target': 文件不存在。" }

            shim $bin $global $name (substitute $arg @{ '$dir' = $dir; '$original_dir' = $original_dir; '$persist_dir' = $persist_dir })
        }
    }
    #endregion

    #region function rm_shim: https://github.com/ScoopInstaller/Scoop/blob/master/lib/install.ps1#L765
    Set-Item -Path Function:\rm_shim -Value {
        param($name, $shimdir, $app)
        '', '.shim', '.cmd', '.ps1' | ForEach-Object {
            $shimPath = "$shimdir\$name$_"
            $altShimPath = "$shimPath.$app"
            if ($app -and (Test-Path -Path $altShimPath -PathType Leaf)) {
                Write-Output "正在移除 shim: $name$_.$app"
                Remove-Item $altShimPath
            }
            elseif (Test-Path -Path $shimPath -PathType Leaf) {
                Write-Output "正在移除 shim: $name$_"
                Remove-Item $shimPath
                $oldShims = Get-Item -Path "$shimPath.*" -Exclude '*.shim', '*.cmd', '*.ps1'
                if ($null -eq $oldShims) {
                    if ($_ -eq '.shim') {
                        Write-Output "正在移除 shim: $name.exe"
                        Remove-Item -Path "$shimdir\$name.exe"
                    }
                }
                else {
                (@($oldShims) | Sort-Object -Property LastWriteTimeUtc)[-1] | Rename-Item -NewName { $_.Name -replace '\.[^.]*$', '' }
                }
            }
        }
    }
    #endregion

    #region function shim: https://github.com/ScoopInstaller/Scoop/blob/master/lib/core.ps1#L952
    Set-Item -Path Function:\shim -Value {
        param($path, $global, $name, $arg)
        if (!(Test-Path $path)) { abort "不能 shim '$(fname $path)': 不能找到 $path" }
        $abs_shimdir = ensure (shimdir $global)
        Add-Path -Path $abs_shimdir -Global:$global
        if (!$name) { $name = strip_ext (fname $path) }

        $shim = "$abs_shimdir\$($name.tolower())"

        # convert to relative path
        $resolved_path = Convert-Path $path
        Push-Location $abs_shimdir
        $relative_path = Resolve-Path -Relative $resolved_path
        Pop-Location

        if ($path -match '\.(exe|com)$') {
            # for programs with no awareness of any shell
            warn_on_overwrite "$shim.shim" $path
            Copy-Item (get_shim_path) "$shim.exe" -Force
            Write-Output "path = `"$resolved_path`"" | Out-UTF8File "$shim.shim"
            if ($arg) {
                Write-Output "args = $arg" | Out-UTF8File "$shim.shim" -Append
            }

            $target_subsystem = Get-PESubsystem $resolved_path
            if ($target_subsystem -eq 2) {
                # we only want to make shims GUI
                Write-Output "$shim.exe 是一个 GUI 二进制文件"
                Set-PESubsystem "$shim.exe" $target_subsystem | Out-Null
            }
        }
        elseif ($path -match '\.(bat|cmd)$') {
            # shim .bat, .cmd so they can be used by programs with no awareness of PSH
            warn_on_overwrite "$shim.cmd" $path
            @(
                "@rem $resolved_path",
                "@`"$resolved_path`" $arg %*"
            ) -join "`r`n" | Out-UTF8File "$shim.cmd"

            warn_on_overwrite $shim $path
            @(
                "#!/bin/sh",
                "# $resolved_path",
                "MSYS2_ARG_CONV_EXCL=/C cmd.exe /C `"$resolved_path`" $arg `"$@`""
            ) -join "`n" | Out-UTF8File $shim -NoNewLine
        }
        elseif ($path -match '\.ps1$') {
            # if $path points to another drive resolve-path prepends .\ which could break shims
            warn_on_overwrite "$shim.ps1" $path
            $ps1text = if ($relative_path -match '^(\.\\)?\w:.*$') {
                @(
                    "# $resolved_path",
                    "`$path = `"$path`"",
                    "if (`$MyInvocation.ExpectingInput) { `$input | & `$path $arg @args } else { & `$path $arg @args }",
                    "exit `$LASTEXITCODE"
                )
            }
            else {
                @(
                    "# $resolved_path",
                    "`$path = Join-Path `$PSScriptRoot `"$relative_path`"",
                    "if (`$MyInvocation.ExpectingInput) { `$input | & `$path $arg @args } else { & `$path $arg @args }",
                    "exit `$LASTEXITCODE"
                )
            }
            $ps1text -join "`r`n" | Out-UTF8File "$shim.ps1"

            # make ps1 accessible from cmd.exe
            warn_on_overwrite "$shim.cmd" $path
            @(
                "@rem $resolved_path",
                "@echo off",
                "where /q pwsh.exe",
                "if %errorlevel% equ 0 (",
                "    pwsh -noprofile -ex unrestricted -file `"$resolved_path`" $arg %*",
                ") else (",
                "    powershell -noprofile -ex unrestricted -file `"$resolved_path`" $arg %*",
                ")"
            ) -join "`r`n" | Out-UTF8File "$shim.cmd"

            warn_on_overwrite $shim $path
            @(
                "#!/bin/sh",
                "# $resolved_path",
                "if command -v pwsh.exe > /dev/null 2>&1; then",
                "    pwsh.exe -noprofile -ex unrestricted -file `"$resolved_path`" $arg `"$@`"",
                "else",
                "    powershell.exe -noprofile -ex unrestricted -file `"$resolved_path`" $arg `"$@`"",
                "fi"
            ) -join "`n" | Out-UTF8File $shim -NoNewLine
        }
        elseif ($path -match '\.jar$') {
            warn_on_overwrite "$shim.cmd" $path
            @(
                "@rem $resolved_path",
                "@pushd $(Split-Path $resolved_path -Parent)",
                "@java -jar `"$resolved_path`" $arg %*",
                "@popd"
            ) -join "`r`n" | Out-UTF8File "$shim.cmd"

            warn_on_overwrite $shim $path
            @(
                "#!/bin/sh",
                "# $resolved_path",
                "if [ `$WSL_INTEROP ]",
                'then',
                "  cd `$(wslpath -u '$(Split-Path $resolved_path -Parent)')",
                'else',
                "  cd `$(cygpath -u '$(Split-Path $resolved_path -Parent)')",
                'fi',
                "java.exe -jar `"$resolved_path`" $arg `"$@`""
            ) -join "`n" | Out-UTF8File $shim -NoNewLine
        }
        elseif ($path -match '\.py$') {
            warn_on_overwrite "$shim.cmd" $path
            @(
                "@rem $resolved_path",
                "@python `"$resolved_path`" $arg %*"
            ) -join "`r`n" | Out-UTF8File "$shim.cmd"

            warn_on_overwrite $shim $path
            @(
                '#!/bin/sh',
                "# $resolved_path",
                "python.exe `"$resolved_path`" $arg `"$@`""
            ) -join "`n" | Out-UTF8File $shim -NoNewLine
        }
        else {
            warn_on_overwrite "$shim.cmd" $path
            @(
                "@rem $resolved_path",
                "@bash `"`$(wslpath -u '$resolved_path')`" $arg %* 2>nul",
                '@if %errorlevel% neq 0 (',
                "  @bash `"`$(cygpath -u '$resolved_path')`" $arg %* 2>nul",
                ')'
            ) -join "`r`n" | Out-UTF8File "$shim.cmd"

            warn_on_overwrite $shim $path
            @(
                '#!/bin/sh',
                "# $resolved_path",
                "if [ `$WSL_INTEROP ]",
                'then',
                "  `"`$(wslpath -u '$resolved_path')`" $arg `"$@`"",
                'else',
                "  `"`$(cygpath -u '$resolved_path')`" $arg `"$@`"",
                'fi'
            ) -join "`n" | Out-UTF8File $shim -NoNewLine
        }
    }
    #endregion

    #region function warn_on_overwrite: https://github.com/ScoopInstaller/Scoop/blob/master/lib/core.ps1#L933
    Set-Item -Path Function:\warn_on_overwrite -Value {
        param($shim, $path)
        if (!(Test-Path $shim)) {
            return
        }
        $shim_app = get_app_name_from_shim $shim
        $path_app = get_app_name $path
        if ($shim_app -eq $path_app) {
            return
        }
        else {
            if (Test-Path -Path "$shim.$path_app" -PathType Leaf) {
                Remove-Item -Path "$shim.$path_app" -Force -ErrorAction SilentlyContinue
            }
            Rename-Item -Path $shim -NewName "$shim.$shim_app" -ErrorAction SilentlyContinue
        }
        $shimname = (fname $shim) -replace '\.shim$', '.exe'
        $filename = (fname $path) -replace '\.shim$', '.exe'
        warn "正在覆盖$(if ($shim_app) { "安装 $shim_app 时创建的" }) shim ('$shimname' -> '$filename')"
    }
    #endregion

    #region function startmenu_shortcut: https://github.com/ScoopInstaller/Scoop/blob/master/lib/shortcuts.ps1#L31
    Set-Item -Path Function:\startmenu_shortcut -Value {
        param([System.IO.FileInfo] $target, $shortcutName, $arguments, [System.IO.FileInfo]$icon, $global)
        if (!$target.Exists) {
            Write-Host -f DarkRed "为 $(fname $target) 创建快捷方式 $shortcutName 失败了: 没有找到 $target"
            return
        }
        if ($icon -and !$icon.Exists) {
            Write-Host -f DarkRed "为 $(fname $target) 创建快捷方式 $shortcutName 失败了: 没有找到 icon 图标 $icon"
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
        Write-Host "为 $(fname $target) 创建了快捷方式: $shortcutName"
    }
    #endregion

    #region function rm_startmenu_shortcuts: https://github.com/ScoopInstaller/Scoop/blob/master/lib/shortcuts.ps1#L62
    Set-Item -Path Function:\rm_startmenu_shortcuts -Value {
        param($manifest, $global, $arch)
        $shortcuts = @(arch_specific 'shortcuts' $manifest $arch)
        $shortcuts | Where-Object { $_ -ne $null } | ForEach-Object {
            $name = $_.item(1)
            $shortcut = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("$(shortcut_folder $global)\$name.lnk")
            Write-Host "正在移除快捷方式: $(friendly_path $shortcut)"
            if (Test-Path -Path $shortcut) {
                Remove-Item $shortcut
            }
        }
    }
    #endregion

    #region function Add-Path: https://github.com/ScoopInstaller/Scoop/blob/master/lib/system.ps1#L96
    Set-Item -Path Function:\Add-Path -Value {
        param(
            [string[]]$Path,
            [string]$TargetEnvVar = 'PATH',
            [switch]$Global,
            [switch]$Force,
            [switch]$Quiet
        )

        # future sessions
        $inPath, $strippedPath = Split-PathLikeEnvVar $Path (Get-EnvVar -Name $TargetEnvVar -Global:$Global)
        if (!$inPath -or $Force) {
            if (!$Quiet) {
                $Path | ForEach-Object {
                    Write-Host "正在添加 $(friendly_path $_) 到环境变量$(if($global){'(系统级)'}else{'(当前用户)'}) $TargetEnvVar 中。"
                }
            }
            Set-EnvVar -Name $TargetEnvVar -Value ((@($Path) + $strippedPath) -join ';') -Global:$Global
        }
        # current session
        $inPath, $strippedPath = Split-PathLikeEnvVar $Path $env:PATH
        if (!$inPath -or $Force) {
            $env:PATH = (@($Path) + $strippedPath) -join ';'
        }
    }
    #endregion

    #region function Remove-Path: https://github.com/ScoopInstaller/Scoop/blob/master/lib/system.ps1#L122
    Set-Item -Path Function:\Remove-Path -Value {
        param(
            [string[]]$Path,
            [string]$TargetEnvVar = 'PATH',
            [switch]$Global,
            [switch]$Quiet,
            [switch]$PassThru
        )

        # future sessions
        $inPath, $strippedPath = Split-PathLikeEnvVar $Path (Get-EnvVar -Name $TargetEnvVar -Global:$Global)
        if ($inPath) {
            if (!$Quiet) {
                $Path | ForEach-Object {
                    if ($PSCulture -like "zh*") {
                        Write-Host "正在从环境变量$(if ($Global) {'(系统级)'} else {'(当前用户)'}) $TargetEnvVar 中移除 $(friendly_path $_)"
                    }
                    else {
                        Write-Host "Removing $(friendly_path $_) from $(if ($Global) {'global'} else {'your'}) path."
                    }
                }
            }
            Set-EnvVar -Name $TargetEnvVar -Value $strippedPath -Global:$Global
        }
        # current session
        $inSessionPath, $strippedPath = Split-PathLikeEnvVar $Path $env:PATH
        if ($inSessionPath) {
            $env:PATH = $strippedPath
        }
        if ($PassThru) {
            return $inPath
        }
    }
    #endregion

    #region function install_psmodule: https://github.com/ScoopInstaller/Scoop/blob/master/lib/psmodules.ps1#L1
    Set-Item -Path Function:\install_psmodule -Value {
        param($manifest, $dir, $global)

        $psmodule = $manifest.psmodule
        if (!$psmodule) { return }

        $targetdir = ensure (modulesdir $global)

        ensure_in_psmodulepath $targetdir $global

        $module_name = $psmodule.name
        if (!$module_name) {
            abort “无效的应用清单(manifest)：psmodule 中缺少 name 属性。”
        }

        $linkfrom = "$targetdir\$module_name"
        Write-Host "正在安装 PowerShell 模块: $module_name"

        Write-Host "正在创建链接: $(friendly_path $linkfrom) => $(friendly_path $dir)"

        if (Test-Path $linkfrom) {
            warn "$(friendly_path $linkfrom) 已经存在，它将被替换。"
            Remove-Item -Path $linkfrom -Force -Recurse -ErrorAction SilentlyContinue
        }

        New-DirectoryJunction $linkfrom $dir | Out-Null
    }
    #endregion

    #region function uninstall_psmodule: https://github.com/ScoopInstaller/Scoop/blob/master/lib/psmodules.ps1#L27
    Set-Item -Path Function:\uninstall_psmodule -Value {
        param($manifest, $dir, $global)
        $psmodule = $manifest.psmodule
        if (!$psmodule) { return }

        $module_name = $psmodule.name
        Write-Host "正在卸载 PowerShell 模块: $module_name"

        $targetdir = modulesdir $global

        $linkfrom = "$targetdir\$module_name"
        if (Test-Path $linkfrom) {
            Write-Host "正在移除: $(friendly_path $linkfrom)"
            $linkfrom = Convert-Path $linkfrom
            Remove-Item -Path $linkfrom -Force -Recurse -ErrorAction SilentlyContinue
        }
    }
    #endregion

    #region function ensure_in_psmodulepath: https://github.com/ScoopInstaller/Scoop/blob/master/lib/psmodules.ps1#L44
    Set-Item -Path Function:\ensure_in_psmodulepath -Value {
        param($dir, $global)
        $path = Get-EnvVar -Name 'PSModulePath' -Global:$global
        if (!$global -and $null -eq $path) {
            $path = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules"
        }
        if ($path -notmatch [Regex]::Escape($dir)) {
            Write-Output "正在添加 $(friendly_path $dir) 到环境变量$(if($global){'(系统级)'}else{'(当前用户)'}) PSModulePath 中。"

            Set-EnvVar -Name 'PSModulePath' -Value "$dir;$path" -Global:$global
        }
    }
    #endregion

    #region function persist_data: https://github.com/ScoopInstaller/Scoop/blob/master/lib/install.ps1#L1011
    Set-Item -Path Function:\persist_data -Value {
        param($manifest, $original_dir, $persist_dir)
        $persist = $manifest.persist
        if ($persist) {
            $persist_dir = ensure $persist_dir

            if ($persist -is [String]) {
                $persist = @($persist)
            }

            $persist | ForEach-Object {
                $source, $target = persist_def $_

                $source = $source.TrimEnd('/').TrimEnd('\\')

                $source = "$dir\$source"
                $target = "$persist_dir\$target"

                Write-Host "正在持久化数据(Persist): $source => $target"

                # if we have had persist data in the store, just create link and go
                if (Test-Path $target) {
                    # if there is also a source data, rename it (to keep a original backup)
                    if (Test-Path $source) {
                        Move-Item -Force $source "$source.original"
                    }
                    # we don't have persist data in the store, move the source to target, then create link
                }
                elseif (Test-Path $source) {
                    # ensure target parent folder exist
                    ensure (Split-Path -Path $target) | Out-Null
                    Move-Item $source $target
                    # we don't have neither source nor target data! we need to create an empty target,
                    # but we can't make a judgement that the data should be a file or directory...
                    # so we create a directory by default. to avoid this, use pre_install
                    # to create the source file before persisting (DON'T use post_install)
                }
                else {
                    $target = New-Object System.IO.DirectoryInfo($target)
                    ensure $target | Out-Null
                }

                # create link
                if (is_directory $target) {
                    # target is a directory, create junction
                    New-DirectoryJunction $source $target | Out-Null
                    attrib $source +R /L
                }
                else {
                    # target is a file, create hard link
                    New-Item -Path $source -ItemType HardLink -Value $target | Out-Null
                }
            }
        }
    }
    #endregion

    #region function show_notes: https://github.com/ScoopInstaller/Scoop/blob/master/lib/install.ps1#L923
    Set-Item -Path Function:\show_notes -Value {
        param($manifest, $dir, $original_dir, $persist_dir)

        $label = 'Notes'
        $note = $manifest.notes
        $noteCN = $manifest.'notes-cn'

        if ($noteCN) {
            $label = '说明'
            $note = $noteCN
        }

        if ($note) {
            Write-Host
            Write-Output $label
            Write-Output '-----'
            Write-Output (wraptext (substitute $note @{ '$dir' = $dir; '$original_dir' = $original_dir; '$persist_dir' = $persist_dir }))
            Write-Output '-----'
        }
    }
    #endregion

    #region function show_suggestions: https://github.com/ScoopInstaller/Scoop/blob/master/lib/install.ps1#L969
    Set-Item -Path Function:\show_suggestions -Value {
        param($suggested)
        $installed_apps = (installed_apps $true) + (installed_apps $false)

        foreach ($app in $suggested.keys) {
            $features = $suggested[$app] | Get-Member -type noteproperty | ForEach-Object { $_.name }
            foreach ($feature in $features) {
                $feature_suggestions = $suggested[$app].$feature

                $fulfilled = $false
                foreach ($suggestion in $feature_suggestions) {
                    $suggested_app, $bucket, $null = parse_app $suggestion

                    if ($installed_apps -contains $suggested_app) {
                        $fulfilled = $true
                        break
                    }
                }

                if (!$fulfilled) {
                    Write-Host
                    Write-Host "$app 建议你安装 $([string]::join("，", $feature_suggestions))"
                }
            }
        }
    }
    #endregion

    #endregion

    #region 其他函数

    #region function test_running_process: https://github.com/ScoopInstaller/Scoop/blob/master/lib/install.ps1#L1100
    Set-Item -Path Function:\test_running_process -Value {
        param($app, $global)
        $processdir = appdir $app $global | Convert-Path
        $running_processes = Get-Process | Where-Object { $_.Path -like "$processdir\*" } | Out-String

        if ($running_processes) {
            if (get_config IGNORE_RUNNING_PROCESSES) {
                warn "$app 的以下实例仍在运行。Scoop 被配置为忽略此情况。"
                Write-Host $running_processes
                return $false
            }
            else {
                error "$app 的以下实例仍在运行。请关闭它们然后重试。"
                Write-Host $running_processes
                return $true
            }
        }
        else {
            return $false
        }
    }
    #endregion

    #region function ensure_none_failed: https://github.com/ScoopInstaller/Scoop/blob/master/lib/install.ps1#L947
    Set-Item -Path Function:\ensure_none_failed -Value {
        param($apps)
        foreach ($app in $apps) {
            $app = ($app -split '/|\\')[-1] -replace '\.json$', ''
            foreach ($global in $true, $false) {
                if ($global) {
                    $instArgs = @('--global')
                }
                else {
                    $instArgs = @()
                }
                if (failed $app $global) {
                    if (installed $app $global) {

                        info "修复 $app 先前失败的安装。"
                        & "$PSScriptRoot\..\libexec\scoop-reset.ps1" $app @instArgs
                    }
                    else {
                        warn "正在清除 $app 之前安装失败的残留。"
                        & "$PSScriptRoot\..\libexec\scoop-uninstall.ps1" $app @instArgs
                    }
                }
            }
        }
    }
    #endregion

    #region function Invoke-Installer: https://github.com/ScoopInstaller/Scoop/blob/master/lib/install.ps1#L654
    Set-Item -Path Function:\Invoke-Installer -Value {
        [CmdletBinding()]
        param (
            [string]
            $Path,
            [string[]]
            $Name,
            [psobject]
            $Manifest,
            [Alias('Arch', 'Architecture')]
            [ValidateSet('32bit', '64bit', 'arm64')]
            [string]
            $ProcessorArchitecture,
            [string]
            $AppName,
            [switch]
            $Global,
            [switch]
            $Uninstall
        )
        $type = if ($Uninstall) { 'uninstaller' } else { 'installer' }
        $installer = arch_specific $type $Manifest $ProcessorArchitecture
        if ($installer.file -or $installer.args) {
            # Installer filename is either explicit defined ('installer.file') or file name in the first URL
            if (!$Name) {
                $Name = url_filename @(url $manifest $architecture)
            }
            $progName = "$Path\$(coalesce $installer.file $Name[0])"
            if (!(is_in_dir $Path $progName)) {
                abort "应用清单(manifest)错误: $((Get-Culture).TextInfo.ToTitleCase($type)) $progName 在应用程序目录之外。"
            }
            elseif (!(Test-Path $progName)) {
                abort "$((Get-Culture).TextInfo.ToTitleCase($type)) $progName 不存在。"
            }
            $substitutions = @{
                '$dir'     = $Path
                '$global'  = $Global
                '$version' = $Manifest.version
            }
            $fnArgs = substitute $installer.args $substitutions
            if ($progName.EndsWith('.ps1')) {
                & $progName @fnArgs
            }
            else {
                $status = Invoke-ExternalCommand $progName -ArgumentList $fnArgs -Activity "正在运行 $type ..."
                if (!$status) {
                    if ($Uninstall) {
                        abort '卸载已中止。'
                    }
                    else {
                        abort "安装已中止。在再次尝试之前，你可能需要运行 scoop uninstall $appName"
                    }
                }
                # Don't remove installer if "keep" flag is set to true
                if (!$installer.keep) {
                    Remove-Item $progName
                }
            }
        }
        Invoke-HookScript -HookType $type -Manifest $Manifest -ProcessorArchitecture $ProcessorArchitecture
    }
    #endregion

    #region function Invoke-ExternalCommand: https://github.com/ScoopInstaller/Scoop/blob/master/lib/core.ps1#L720
    # Set-Item -Path Function:\Invoke-ExternalCommand -Value {
    #     [CmdletBinding(DefaultParameterSetName = "Default")]
    #     [OutputType([Boolean])]
    #     param (
    #         [Parameter(Mandatory = $true, Position = 0)]
    #         [Alias("Path")]
    #         [ValidateNotNullOrEmpty()]
    #         [String]
    #         $FilePath,
    #         [Parameter(Position = 1)]
    #         [Alias("Args")]
    #         [String[]]
    #         $ArgumentList,
    #         [Parameter(ParameterSetName = "UseShellExecute")]
    #         [Switch]
    #         $RunAs,
    #         [Parameter(ParameterSetName = "UseShellExecute")]
    #         [Switch]
    #         $Quiet,
    #         [Alias("Msg")]
    #         [String]
    #         $Activity,
    #         [Alias("cec")]
    #         [Hashtable]
    #         $ContinueExitCodes,
    #         [Parameter(ParameterSetName = "Default")]
    #         [Alias("Log")]
    #         [String]
    #         $LogPath
    #     )
    #     if ($Activity) {
    #         Write-Host "$Activity " -NoNewline
    #     }
    #     $Process = New-Object System.Diagnostics.Process
    #     $Process.StartInfo.FileName = $FilePath
    #     $Process.StartInfo.UseShellExecute = $false
    #     if ($LogPath) {
    #         if ($FilePath -match '^msiexec(.exe)?$') {
    #             $ArgumentList += "/lwe `"$LogPath`""
    #         }
    #         else {
    #             $redirectToLogFile = $true
    #             $Process.StartInfo.RedirectStandardOutput = $true
    #             $Process.StartInfo.RedirectStandardError = $true
    #         }
    #     }
    #     if ($RunAs) {
    #         $Process.StartInfo.UseShellExecute = $true
    #         $Process.StartInfo.Verb = 'RunAs'
    #     }
    #     if ($Quiet) {
    #         $Process.StartInfo.UseShellExecute = $true
    #         $Process.StartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    #     }
    #     if ($ArgumentList.Length -gt 0) {
    #         # Remove existing double quotes and split arguments
    #         # '(?<=(?<![:\w])[/-]\w+) ' matches a space after a command line switch starting with a slash ('/') or a hyphen ('-')
    #         # The inner item '(?<![:\w])[/-]' matches a slash ('/') or a hyphen ('-') not preceded by a colon (':') or a word character ('\w')
    #         # so that it must be a command line switch, otherwise, it would be a path (e.g. 'C:/Program Files') or other word (e.g. 'some-arg')
    #         # ' (?=[/-])' matches a space followed by a slash ('/') or a hyphen ('-'), i.e. the space before a command line switch
    #         $ArgumentList = $ArgumentList.ForEach({ $_ -replace '"' -split '(?<=(?<![:\w])[/-]\w+) | (?=[/-])' })
    #         # Use legacy argument escaping for commands having non-standard behavior with regard to argument passing.
    #         # `msiexec` requires some args like `TARGETDIR="C:\Program Files"`, which is non-standard, therefore we treat it as a legacy command.
    #         # NSIS installer's '/D' param may not work with the ArgumentList property, so we need to escape arguments manually.
    #         # ref-1: https://learn.microsoft.com/en-us/powershell/scripting/learn/experimental-features?view=powershell-7.4#psnativecommandargumentpassing
    #         # ref-2: https://nsis.sourceforge.io/Docs/Chapter3.html
    #         $LegacyCommand = $FilePath -match '^((cmd|cscript|find|sqlcmd|wscript|msiexec)(\.exe)?|.*\.(bat|cmd|js|vbs|wsf))$' -or
    #         ($ArgumentList -match '^/S$|^/D=[A-Z]:[\\/].*$').Length -eq 2
    #         $SupportArgumentList = $Process.StartInfo.PSObject.Properties.Name -contains 'ArgumentList'
    #         if ((-not $LegacyCommand) -and $SupportArgumentList) {
    #             # ArgumentList is supported in PowerShell 6.1 and later (built on .NET Core 2.1+)
    #             # ref-1: https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.processstartinfo.argumentlist?view=net-6.0
    #             # ref-2: https://docs.microsoft.com/en-us/powershell/scripting/whats-new/differences-from-windows-powershell?view=powershell-7.2#net-framework-vs-net-core
    #             $ArgumentList.ForEach({ $Process.StartInfo.ArgumentList.Add($_) })
    #         }
    #         else {
    #             # Escape arguments manually in lower versions
    #             $escapedArgs = switch -regex ($ArgumentList) {
    #                 # Quote paths starting with a drive letter
    #                 '(?<!/D=)[A-Z]:[\\/].*' { $_ -replace '([A-Z]:[\\/].*)', '"$1"'; continue }
    #                 # Do not quote paths if it is NSIS's '/D' argument
    #                 '/D=[A-Z]:[\\/].*' { $_; continue }
    #                 # Quote args with spaces
    #                 ' ' { "`"$_`""; continue }
    #                 default { $_; continue }
    #             }
    #             $Process.StartInfo.Arguments = $escapedArgs -join ' '
    #         }
    #     }
    #     try {
    #         [void]$Process.Start()
    #     }
    #     catch {
    #         if ($Activity) {
    #             Write-Host "错误。" -ForegroundColor DarkRed
    #         }
    #         error $_.Exception.Message
    #         return $false
    #     }
    #     if ($redirectToLogFile) {
    #         # we do this to remove a deadlock potential
    #         # ref: https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.process.standardoutput?view=netframework-4.5#remarks
    #         $stdoutTask = $Process.StandardOutput.ReadToEndAsync()
    #         $stderrTask = $Process.StandardError.ReadToEndAsync()
    #     }
    #     $Process.WaitForExit()
    #     if ($redirectToLogFile) {
    #         Out-UTF8File -FilePath $LogPath -Append -InputObject $stdoutTask.Result
    #         Out-UTF8File -FilePath $LogPath -Append -InputObject $stderrTask.Result
    #     }
    #     if ($Process.ExitCode -ne 0) {
    #         if ($ContinueExitCodes -and ($ContinueExitCodes.ContainsKey($Process.ExitCode))) {
    #             if ($Activity) {
    #                 Write-Host "完成。" -ForegroundColor DarkYellow
    #             }
    #             warn $ContinueExitCodes[$Process.ExitCode]
    #             return $true
    #         }
    #         else {
    #             if ($Activity) {
    #                 Write-Host "错误" -ForegroundColor DarkRed
    #             }
    #             error "退出代码为: $($Process.ExitCode)!"
    #             return $false
    #         }
    #     }
    #     if ($Activity) {
    #         Write-Host "完成。" -ForegroundColor Green
    #     }
    #     return $true
    # }
    #endregion

    #region function install_app: https://github.com/ScoopInstaller/Scoop/blob/master/lib/install.ps1#L8
    Set-Item -Path Function:\install_app -Value {
        param($app, $architecture, $global, $suggested, $use_cache = $true, $check_hash = $true)
        $app, $manifest, $bucket, $url = Get-Manifest $app

        if (!$manifest) {
            abort "无法从 $(if ($bucket) { "$bucket (bucket)" } elseif ($url) { $url }) 中找到应用 $app 的清单(manifest)"
        }

        $version = $manifest.version
        if (!$version) { abort "清单(manifest) 中没有指定一个版本号。" }
        if ($version -match '[^\w\.\-\+_]') {
            abort "清单(manifest) 中的版本具有不支持的字符: $($matches[0])"
        }

        $is_nightly = $version -eq 'nightly'
        if ($is_nightly) {
            $version = nightly_version
            $check_hash = $false
        }

        $architecture = Get-SupportedArchitecture $manifest $architecture
        if ($null -eq $architecture) {
            error "$app 不支持当前的架构!"
            return
        }

        if ((get_config SHOW_MANIFEST $false) -and ($MyInvocation.ScriptName -notlike '*scoop-update*')) {
            Write-Host "清单(manifest): $app.json"
            $style = get_config CAT_STYLE
            if ($style) {
                $manifest | ConvertToPrettyJson | bat --no-paging --style $style --language json
            }
            else {
                $manifest | ConvertToPrettyJson
            }
            $answer = Read-Host -Prompt '继续安装? [Y/n]'
            if (($answer -eq 'n') -or ($answer -eq 'N')) {
                return
            }
        }
        Write-Output "正在从 $(if ($bucket) { "$bucket (bucket)" } else { $url }) 中安装 $app ($version) [$architecture]"

        $dir = ensure (versiondir $app $version $global)
        $original_dir = $dir # keep reference to real (not linked) directory
        $persist_dir = persistdir $app $global

        $fname = Invoke-ScoopDownload $app $version $manifest $bucket $architecture $dir $use_cache $check_hash
        Invoke-Extraction -Path $dir -Name $fname -Manifest $manifest -ProcessorArchitecture $architecture
        Invoke-HookScript -HookType 'pre_install' -Manifest $manifest -ProcessorArchitecture $architecture

        Invoke-Installer -Path $dir -Name $fname -Manifest $manifest -ProcessorArchitecture $architecture -AppName $app -Global:$global
        ensure_install_dir_not_in_path $dir $global
        $dir = link_current $dir
        create_shims $manifest $dir $global $architecture
        create_startmenu_shortcuts $manifest $dir $global $architecture
        install_psmodule $manifest $dir $global
        env_add_path $manifest $dir $global $architecture
        env_set $manifest $global $architecture

        # persist data
        persist_data $manifest $original_dir $persist_dir
        persist_permission $manifest $global

        Invoke-HookScript -HookType 'post_install' -Manifest $manifest -ProcessorArchitecture $architecture

        # save info for uninstall
        save_installed_manifest $app $bucket $dir $url
        save_install_info @{ 'architecture' = $architecture; 'url' = $url; 'bucket' = $bucket } $dir

        if ($manifest.suggest) {
            $suggested[$app] = $manifest.suggest
        }

        success "$app ($version) 已成功安装!"

        show_notes $manifest $dir $original_dir $persist_dir
    }
    #endregion

    #region function Confirm-InstallationStatus: https://github.com/ScoopInstaller/Scoop/blob/master/lib/core.ps1#L1142
    # Set-Item -Path Function:\Confirm-InstallationStatus -Value {
    #     [CmdletBinding()]
    #     [OutputType([Object[]])]
    #     param(
    #         [Parameter(Mandatory = $true)]
    #         [String[]]
    #         $Apps,
    #         [Switch]
    #         $Global
    #     )
    #     $Installed = @()
    #     $Apps | Select-Object -Unique | Where-Object { $_ -ne 'scoop' } | ForEach-Object {
    #         $App, $null, $null = parse_app $_
    #         if ($Global) {
    #             if (Test-Path (appdir $App $true)) {
    #                 $Installed += , @($App, $true)
    #             }
    #             elseif (Test-Path (appdir $App $false)) {
    #                 error "$App 不是在全局(--global/-g)安装的，但可能是在本地安装的。"
    #                 warn "请重新尝试一下，不要使用 --global 或 -g 。"
    #             }
    #             else {
    #                 error "$App 还未安装。"
    #             }
    #         }
    #         else {
    #             if (Test-Path (appdir $App $false)) {
    #                 $Installed += , @($App, $false)
    #             }
    #             elseif (Test-Path (appdir $App $true)) {
    #                 error "$App 不是在本地安装的，但可能是在全局(--global/-g)安装的。"
    #                 warn "请重新尝试一下，使用 --global 或 -g 。"
    #             }
    #             else {
    #                 error "$App 还未安装。"
    #             }
    #         }
    #         if (failed $App $Global) {
    #             error "$App 未正确安装。"
    #         }
    #     }
    #     return , $Installed
    # }
    #endregion

    #endregion
}
#endregion
