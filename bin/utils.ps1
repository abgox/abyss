#Requires -Version 5.1

<#
一些能在清单中使用的函数:

    1. 在 pre_install

        - A-Require-Admin: 要求以管理员权限运行
        - A-Ensure-Directory: 确保指定目录路径存在
        - A-Copy-Item: 复制文件或目录
        - A-New-PersistFile: 创建文件，可选择设置内容(不能在 post_install 中使用)
        - A-New-LinkDirectory: 为目录创建 Junction
        - A-New-LinkFile: 为文件创建 SymbolicLink
        - A-Add-Font: 安装字体
        - A-Add-MsixPackage: 安装 AppX/Msix 包
        - A-Add-PowerToysRunPlugin: 添加 PowerToys Run 插件
        - A-Install-Exe: 运行安装程序
        - A-Expand-SetupExe: 展开 Setup.exe 类型的安装包，非特殊情况不使用，优先使用 A-Install-Exe

    2. 在 pre_uninstall

        - A-Deny-Update: 禁止通过 Scoop 更新
        - A-Stop-Process: 尝试暂停安装目录下的应用进程，以确保能正常卸载
        - A-Stop-Service: 尝试停止并移除指定的应用服务，以确保能正常卸载
        - A-Remove-Link: 移除 A-New-LinkFile 和 A-New-LinkDirectory 创建的 SymbolicLink 或 Junction
        - A-Remove-Font: 移除字体
        - A-Remove-MsixPackage: 卸载 AppX/Msix 包
        - A-Remove-PowerToysRunPlugin: 移除 PowerToys Run 插件
        - A-Uninstall-Exe: 运行卸载程序
        - A-Remove-TempData: 移除指定的一些临时数据文件，常见的在 $env:LocalAppData 目录中，它们不涉及应用配置数据，会自动生成

    3. 其他:
        - A-Test-Admin: 检查是否以管理员权限运行
        - A-Hold-App: 它应该在 pre_install 中使用，和 A-Deny-Update 搭配
        - A-Get-ProductCode: 获取应用的产品代码
        - A-Get-InstallerInfoFromWinget: 从 winget 数据库中获取安装信息，用于清单文件的 checkver 和 autoupdate
        - A-Get-VersionFromPage: 获取最新的版本号，适用于动态加载的网页
        - A-Resolve-DownloadUrl: 解析跳转后的真实下载地址
        - A-Move-PersistDirectory: 用于迁移 persist 目录下的数据到其他位置(在 pre_install 中使用)
            - 它用于未来可能存在的清单文件更名
            - 当清单文件更名后，需要使用它，并传入旧的清单名称
            - 当用新的清单名称安装时，它会将 persist 中的旧目录用新的清单名称重命名，以实现 persist 的迁移
            - 由于只有 abyss 使用了 Publisher.PackageIdentifier 这样的命名格式，迁移不会与官方或其他第三方仓库冲突
#>

# -------------------------------------------------

Write-Host

# 结合 $cmd，避免自动化执行更新检查时中文内容导致错误
$ShowCN = $PSUICulture -like 'zh*' -and $cmd

# Github: https://github.com/abgox/abyss#config
# Gitee: https://gitee.com/abgox/abyss#config
try {
    $ScoopConfig = scoop config

    # 卸载时的操作行为。
    $uninstallActionLevel = $ScoopConfig.'abgox-abyss-app-uninstall-action'

    # 本地添加的 abyss 的实际名称
    # https://github.com/abgox/abyss/issues/10
    if ($bucket) {
        if ($ScoopConfig.'abgox-abyss-bucket-name' -ne $bucket) {
            scoop config 'abgox-abyss-bucket-name' $bucket
        }
        if ($bucket -ne 'abyss') {
            if ($ShowCN) {
                Write-Host "你应该使用 abyss 作为 bucket 名称，但是目前使用的名称是 $bucket`n当安装的应用存在 depends 时，它可能出现问题，建议尽快修改" -ForegroundColor Red
            }
            else {
                Write-Host "You should only use 'abyss' as the bucket name, but the current name is $bucket`nWhen installing applications with depends, it may cause problems, and modify it as soon as possible." -ForegroundColor Red
            }
        }
    }
}
catch {}

if ($null -eq $uninstallActionLevel) {
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

if ($ShowCN) {
    $cmdMap_zh = @{
        "install"   = "安装"
        "uninstall" = "卸载"
        "update"    = "更新"
    }

    $adminText = if ($isAdmin) { "" } else { " 或使用管理员权限。" }

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
        "If failed, You may need to try again"                           = "如果$($cmdMap_zh[$cmd])失败，可能需要再次尝试$($cmdMap_zh[$cmd]) $app$adminText"
        "Successfully terminated the service:"                           = "成功终止服务:"
        "Failed to terminate the service:"                               = "无法终止服务:"
        "Failed to remove the service:"                                  = "无法删除服务:"
        "Removing link:"                                                 = "正在删除链接:"
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
        "If failed, You may need to try again"                           = "If failed to $cmd, You may need to try $cmd $app again$adminText"
        "Successfully terminated the service:"                           = "Successfully terminated the service:"
        "Failed to terminate the service:"                               = "Failed to terminate the service:"
        "Failed to remove the service:"                                  = "Failed to remove the service:"
        "Removing link:"                                                 = "Removing link:"
    }
}


<#
应用的安装/卸载步骤 (xxx 表示其他自定义逻辑)

pre_install
   A-Start-Install
   xxx
post_install
   xxx
   A-Complete-Install
pre_uninstall
   A-Start-Uninstall
   xxx
post_uninstall
   xxx
   A-Complete-Uninstall

#>
function A-Start-Install {

}

function A-Complete-Install {

}

function A-Start-Uninstall {

}

function A-Complete-Uninstall {

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
        通常用来将 bucket\extras 中提前准备好的配置文件复制到 persist 目录下，以便 Scoop 进行 persist
        因为部分配置文件，如果直接使用 New-Item 或 Set-Content，会出现编码错误

    .EXAMPLE
        A-Copy-Item "$bucketsdir\$bucket\extras\$app\InputTip.ini" "$persist_dir\InputTip.ini"

    .NOTES
        文件名必须一一对应，不允许使用以下写法
        A-Copy-Item "$bucketsdir\$bucket\extras\$app\InputTip.ini" $persist_dir
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
            $path = $LinkPath.replace($env:UserProfile, $persist_dir)
            # 如果不在 $env:UserProfile 目录下，则去掉盘符
            if ($path -notlike "$persist_dir*") {
                $path = $path -replace '^[a-zA-Z]:', $persist_dir
            }
            $LinkTargets.Add($path)
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
            $path = $LinkPath.replace($env:UserProfile, $persist_dir)
            # 如果不在 $env:UserProfile 目录下，则去掉盘符
            if ($path -notlike "$persist_dir*") {
                $path = $path -replace '^[a-zA-Z]:', $persist_dir
            }
            $LinkTargets.Add($path)
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
            $LinkPaths = Get-Content $_ -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json | Select-Object -ExpandProperty "LinkPaths"

            foreach ($p in $LinkPaths) {
                if (Test-Path $p) {
                    try {
                        Write-Host $words["Removing link:"] -ForegroundColor Yellow -NoNewline
                        Write-Host " $p" -ForegroundColor Cyan
                        Remove-Item $p -Force -Recurse -ErrorAction Stop
                    }
                    catch {
                        Write-Host $words["Failed to remove:"] -ForegroundColor Red -NoNewline
                        Write-Host " $p" -ForegroundColor Cyan
                    }
                }
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
    foreach ($p in $Paths) {
        if (Test-Path $p) {
            try {
                Write-Host $words["Removing"] -ForegroundColor Yellow -NoNewline
                Write-Host " $p" -ForegroundColor Cyan
                Remove-Item $p -Force -Recurse -ErrorAction Stop
            }
            catch {
                Write-Host $words["Failed to remove:"] -ForegroundColor Red -NoNewline
                Write-Host " $p" -ForegroundColor Cyan
            }
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
                A-Exit
            }
        }
    }

    if ($NoFound) {
        Write-Host "$($words["No running processes found."])$($words["If failed, You may need to try again"])" -ForegroundColor Yellow
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

    .PARAMETER NoRemove
        不删除服务，仅停止服务。

    .EXAMPLE
        A-Stop-Service -ServiceName "Everything"
    #>
    param(
        [string]$ServiceName,
        [switch]$NoRemove
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
        A-Exit
    }

    if ($NoRemove) {
        return
    }

    try {
        Remove-Service -Name $ServiceName -ErrorAction Stop
    }
    catch {
        Write-Host "$($words["Failed to remove the service:" ]) $ServiceName `n$($words["Maybe try again"])" -ForegroundColor Red
        A-Exit
    }
}

function A-Install-Exe {
    param(
        [string]$Installer,
        [array]$ArgumentList,
        # 表示安装成功的标志文件，如果此路径或文件存在，则认为安装成功
        [string]$SuccessFile,
        # $Uninstaller 和 $SuccessFile 作用一致，不过它必须指定软件的卸载程序
        # 当指定它后，A-Uninstall-Exe 会默认使用它作为卸载程序路径
        [string]$Uninstaller,
        # 仅用于标识，表示可能需要用户交互
        [switch]$NoSilent,
        # 超时时间（秒）
        [string]$Timeout = 300
    )

    # 如果没有传递安装参数，则使用默认参数
    if (!$PSBoundParameters.ContainsKey('ArgumentList')) {
        $ArgumentList = @('/S', "/D=$dir")
    }

    if ($PSBoundParameters.ContainsKey('Installer')) {
        $path = A-Get-AbsolutePath $Installer
    }
    else {
        # $fname 由 Scoop 提供，即下载的文件名
        $path = if ($fname -is [array]) { "$dir\$($fname[0])" }else { "$dir\$fname" }
    }
    $fileName = Split-Path $path -Leaf

    if (!$PSBoundParameters.ContainsKey('SuccessFile')) {
        $SuccessFile = try { $manifest.shortcuts[0][0] }catch { $manifest.architecture.$architecture.shortcuts[0][0] }
        $SuccessFile = Invoke-Expression "`"$SuccessFile`""

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
    $SuccessFile = A-Get-AbsolutePath $SuccessFile
    $Uninstaller = A-Get-AbsolutePath $Uninstaller

    $OutFile = "$dir\scoop-install-A-Install-Exe.jsonc"
    @{
        Installer    = $path
        ArgumentList = $ArgumentList
        SuccessFile  = $SuccessFile
        Uninstaller  = $Uninstaller
    } | ConvertTo-Json | Out-File -FilePath $OutFile -Force -Encoding utf8

    if (Test-Path $path) {
        try {
            if ($ShowCN) {
                Write-Host "正在运行安装程序 ($fileName) 安装 $app" -ForegroundColor Yellow
                # if ($ArgumentList) {
                #     Write-Host "安装程序携带参数: $ArgumentList" -ForegroundColor Yellow
                # }
                $msg = "如果安装超时($Timeout 秒)，安装过程将被强行终止"
                if ($NoSilent) {
                    $msg = "安装程序可能需要你手动进行交互操作，" + $msg
                }
            }
            else {
                Write-Host "Installing '$app' using installer ($fileName)" -ForegroundColor Yellow
                # if ($ArgumentList) {
                #     Write-Host "Installer with arguments: $ArgumentList" -ForegroundColor Yellow
                # }
                $msg = "If installation timeout ($Timeout seconds), the process will be terminated."
                if ($NoSilent) {
                    $msg = "The installer may require you to perform some manual operations, " + $msg
                }
            }
            Write-Host $msg -ForegroundColor Yellow

            # 在后台作业中运行安装程序，强制停止进程的时机更晚
            $job = Start-Job -ScriptBlock {
                param($path, $ArgumentList)

                Start-Process $path -ArgumentList $ArgumentList -WindowStyle Hidden -PassThru

            } -ArgumentList $path, $ArgumentList

            $startTime = Get-Date
            $seconds = 1
            if ($Uninstaller) {
                $fileExists = (Test-Path $SuccessFile) -and (Test-Path $Uninstaller)
            }
            else {
                $fileExists = Test-Path $SuccessFile
            }

            try {
                while ((New-TimeSpan -Start $startTime -End (Get-Date)).TotalSeconds -lt $Timeout) {
                    if ($ShowCN) {
                        Write-Host -NoNewline "`r等待中: $seconds 秒" -ForegroundColor Yellow
                    }
                    else {
                        Write-Host -NoNewline "`rWaiting: $seconds seconds" -ForegroundColor Yellow
                    }

                    if ($Uninstaller) {
                        $fileExists = (Test-Path $SuccessFile) -and (Test-Path $Uninstaller)
                    }
                    else {
                        $fileExists = Test-Path $SuccessFile
                    }
                    if ($fileExists) {
                        break
                    }
                    Start-Sleep -Seconds 1
                    $seconds += 1
                }
                Write-Host

                if ($path -notmatch "^C:\\Windows\\System32\\") {
                    $null = Start-Job -ScriptBlock {
                        param($path, $job)
                        # 30 秒后再删除安装程序
                        Start-Sleep -Seconds 30

                        $job | Stop-Job -ErrorAction SilentlyContinue

                        Get-Process | Where-Object { $_.Path -eq $path } | Stop-Process -Force -ErrorAction SilentlyContinue

                        Remove-Item $path -Force -ErrorAction SilentlyContinue

                    } -ArgumentList $path, $job
                }

                if ($fileExists) {
                    if ($ShowCN) {
                        Write-Host "安装成功" -ForegroundColor Green
                    }
                    else {
                        Write-Host "Install successfully." -ForegroundColor Green
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
            finally {
                if (!$fileExists) {
                    Write-Host
                    if ($ShowCN) {
                        Write-Host "安装过程被终止" -ForegroundColor Red
                    }
                    else {
                        Write-Host "Installation process terminated." -ForegroundColor Red
                    }
                    A-Exit
                }
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
        # 仅用于标识，表示可能需要用户交互
        [switch]$NoSilent,
        # 超时时间（秒）
        [string]$Timeout = 300,
        # 如果存在这个 FailureFile 指定的文件或路径，则认定为卸载失败
        # 如果未指定，默认使用 $Uninstaller
        [string]$FailureFile,
        # 是否等待卸载程序完成
        # 它会忽略超时时间，一直等待卸载程序结束
        # 除非确定卸载程序会自动结束，否则不要使用
        [switch]$Wait,
        # 是否需要隐藏卸载程序窗口
        [switch]$Hidden
    )

    # 如果没有传递卸载参数，则使用默认参数
    if (!$PSBoundParameters.ContainsKey('ArgumentList')) {
        $ArgumentList = @('/S')
    }
    if (!$PSBoundParameters.ContainsKey('Uninstaller')) {
        if (Test-Path "$dir\scoop-install-A-Install-Exe.jsonc") {
            $Uninstaller = Get-Content "$dir\scoop-install-A-Install-Exe.jsonc" -Raw | ConvertFrom-Json | Select-Object -ExpandProperty "Uninstaller"
        }
        else {
            return
        }
    }

    $path = A-Get-AbsolutePath $Uninstaller
    $fileName = Split-Path $path -Leaf

    if (Test-Path $path) {
        if ($ShowCN) {
            Write-Host "正在运行卸载程序 ($fileName) 卸载 $app" -ForegroundColor Yellow
            # if ($ArgumentList) {
            #     Write-Host "卸载程序携带参数: $ArgumentList" -ForegroundColor Yellow
            # }
            $msg = "如果卸载超时($Timeout 秒)，卸载过程将被强行终止"
            if ($NoSilent) {
                if ($Wait) {
                    $msg = "卸载程序可能需要你手动进行交互操作，如果卸载程序不结束，卸载过程将一直陷入等待"
                }
                else {
                    $msg = "卸载程序可能需要你手动进行交互操作，" + $msg
                }
            }
        }
        else {
            Write-Host "Uninstalling '$app' using uninstaller ($fileName)" -ForegroundColor Yellow
            # if ($ArgumentList) {
            #     Write-Host "Uninstaller with arguments: $ArgumentList" -ForegroundColor Yellow
            # }
            $msg = "If the uninstallation times out ($Timeout seconds), the process will be terminated."
            if ($NoSilent) {
                if ($Wait) {
                    $msg = "The uninstaller may require you to perform some manual operations. If the uninstaller does not end, the uninstallation process will be indefinitely waiting."
                }
                else {
                    $msg = "The uninstaller may require you to perform some manual operations. " + $msg
                }
            }
        }
        Write-Host $msg -ForegroundColor Yellow

        if (!$PSBoundParameters.ContainsKey('FailureFile')) {
            $FailureFile = $path
        }

        try {
            $paramList = @{
                FilePath     = $path
                ArgumentList = $ArgumentList
                WindowStyle  = if ($Hidden) { "Hidden" }else { "Normal" }
                Wait         = $Wait
                PassThru     = $true
            }

            $startTime = Get-Date
            $process = Start-Process @paramList

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
                A-Exit
            }

            $fileExists = Test-Path $FailureFile
            $seconds = 1
            try {
                while ((New-TimeSpan -Start $startTime -End (Get-Date)).TotalSeconds -lt $Timeout) {
                    if ($ShowCN) {
                        Write-Host -NoNewline "`r等待中: $seconds 秒" -ForegroundColor Yellow
                    }
                    else {
                        Write-Host -NoNewline "`rWaiting: $seconds seconds" -ForegroundColor Yellow
                    }

                    $fileExists = Test-Path $FailureFile
                    if ($fileExists) {
                        try {
                            Remove-Item $FailureFile -Force -Recurse -ErrorAction SilentlyContinue
                        }
                        catch {}
                    }
                    else {
                        break
                    }
                    Start-Sleep -Seconds 1
                    $seconds += 1
                }
                Write-Host

                if ($fileExists) {
                    if ($ShowCN) {
                        Write-Host "$app 卸载失败，卸载过程被强行终止`n如果卸载程序还在运行，你可以继续和它交互，当卸载完成后，再次运行卸载命令即可" -ForegroundColor Red
                    }
                    else {
                        Write-Host "Failed to uninstall $app, process terminated.`nIf uninstaller is still running, you can continue to interact with it, and run the command again after the uninstallation is complete." -ForegroundColor Red
                    }
                    A-Exit
                }
                else {
                    if ($ShowCN) {
                        Write-Host "卸载成功" -ForegroundColor Green
                    }
                    else {
                        Write-Host "Uninstall successfully." -ForegroundColor Green
                    }
                }
            }
            finally {
                if ($fileExists) {
                    Write-Host
                    if ($ShowCN) {
                        Write-Host "卸载过程被终止" -ForegroundColor Red
                    }
                    else {
                        Write-Host "Uninstallation process terminated." -ForegroundColor Red
                    }
                    A-Exit
                }
            }
        }
        catch {
            Write-Host $_.Exception.Message -ForegroundColor Red
            A-Exit
        }
    }
}

function A-Add-MsixPackage {
    param(
        [string]$PackageFamilyName,
        [string]$FileName
    )
    if ($PSBoundParameters.ContainsKey('FileName')) {
        $path = A-Get-AbsolutePath $FileName
    }
    else {
        # $fname 由 Scoop 提供，即下载的文件名
        $path = if ($fname -is [array]) { "$dir\$($fname[0])" }else { "$dir\$fname" }
    }

    A-Add-AppxPackage -PackageFamilyName $PackageFamilyName -Path $path

    return $PackageFamilyName
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
        A-Exit
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
                A-Exit
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
            Write-Host $words["Removing"] -ForegroundColor Yellow -NoNewline
            Write-Host " $PluginPath" -ForegroundColor Cyan
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
        Write-Host $words["Failed to remove:"] -ForegroundColor Red -NoNewline
        Write-Host " $PluginPath" -ForegroundColor Cyan
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
            Write-Host $words["Removing"] -ForegroundColor Yellow -NoNewline
            Write-Host " $PluginPath" -ForegroundColor Cyan
            Remove-Item -Path $PluginPath -Recurse -Force -ErrorAction Stop
        }
    }
    catch {
        Write-Host $words["Failed to remove:"] -ForegroundColor Red -NoNewline
        Write-Host " $PluginPath" -ForegroundColor Cyan
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

function A-Deny-Update {
    if ($cmd -eq "update") {
        if ($ShowCN) {
            Write-Host "$app 不允许通过 Scoop 更新。" -ForegroundColor Red
        }
        else {
            Write-Host "$app does not allow update by Scoop." -ForegroundColor Red
        }
        A-Exit
    }
}

function A-Hold-App {
    param(
        [string]$AppName = $app
    )

    $null = Start-Job -ScriptBlock {
        param($app)

        $startTime = Get-Date
        $Timeout = 300
        $can = $false

        While ($true) {
            if ((New-TimeSpan -Start $startTime -End (Get-Date)).TotalSeconds -ge $Timeout) {
                break
            }
            if ((scoop list).Name | Where-Object { $_ -eq $app }) {
                $can = $true
                break
            }
            Start-Sleep -Milliseconds 100
        }

        if ($can) {
            scoop hold $app
        }
    } -ArgumentList $AppName
}

function A-Move-PersistDirectory {
    param(
        # 旧的清单名称(不包含 .json 后缀)
        [array]$OldNames
    )

    if (Test-Path $persist_dir) {
        return
    }

    $dir = Split-Path $persist_dir -Parent

    foreach ($oldName in $OldNames) {
        $old = "$dir\$oldName"

        if (Test-Path $old) {
            try {
                Rename-Item -Path $old -NewName $app -Force -ErrorAction Stop
                if ($ShowCN) {
                    Write-Host "persist 迁移成功: " -ForegroundColor Yellow -NoNewline
                }
                else {
                    Write-Host "Successfully migrate persist: " -ForegroundColor Yellow -NoNewline
                }
                Write-Host $old -ForegroundColor Cyan -NoNewline
                Write-Host " => " -NoNewline
                Write-Host "$dir\$app" -ForegroundColor Cyan
                break
            }
            catch {
                if ($ShowCN) {
                    Write-Host "persist 迁移失败: $old" -ForegroundColor Red
                }
                else {
                    Write-Host "Failed to migrate persist: $old" -ForegroundColor Red
                }
            }
        }
    }
}

function A-Get-ProductCode {
    param (
        [string]$AppNamePattern
    )

    # 搜索注册表位置
    $registryPaths = @(
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    foreach ($path in $registryPaths) {
        # 获取所有卸载项
        $uninstallItems = Get-ChildItem $path -ErrorAction SilentlyContinue | Get-ItemProperty

        foreach ($item in $uninstallItems) {
            if ($null -ne $item.DisplayName -and $item.DisplayName -match $AppNamePattern) {
                if ($item.UninstallString -match '\{[0-9A-Fa-f\-]{36}\}') {
                    # 返回匹配到的第一个 ProductCode GUID
                    return $Matches[0]
                }
            }
        }
    }

    if ($ShowCN) {
        Write-Host "没有找到 $app 的生产代码，可能在安装过程中存在问题" -ForegroundColor Red
    }
    else {
        Write-Host "Cannot find product code of $app，maybe there is a problem during installation" -ForegroundColor Red
    }

    return $null
}

function A-Get-VersionFromPage {
    <#
    .SYNOPSIS
        从指定的 Url 页面获取版本号。

    .DESCRIPTION
        从指定的 Url 页面获取版本号。
        它会等待页面的 js 加载完成，然后使用指定的 Regex 匹配页面内容获取版本号。
    #>
    param(
        [string]$Regex,
        [string]$Url
    )

    if (!$PSBoundParameters.ContainsKey('Regex')) {
        return $null
    }

    if (!$PSBoundParameters.ContainsKey('Url')) {
        return $null
    }

    try {
        if ((pip freeze) -notmatch "selenium") {
            Write-Host "Installing selenium..." -ForegroundColor Green
            $null = pip install selenium
        }
    }
    catch {
        return $null
    }

    $Page = python "$PSScriptRoot\get-page.py" $Url
    $Matches = [regex]::Matches($Page, $Regex)

    if ($Matches) {
        return $Matches[0].Groups[1].Value
    }
}

function A-Resolve-DownloadUrl {
    <#
    .SYNOPSIS
        从指定的 URL 中解析跳转后的真实下载地址
    #>
    param(
        [string]$Url
    )

    if (!$PSBoundParameters.ContainsKey('Url')) {
        return $null
    }

    $res = [System.Net.HttpWebRequest]::Create($Url).GetResponse()
    $res.ResponseUri.AbsoluteUri
    $res.Close()
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
    .PARAMETER MaxExclusiveVersion
        限制安装包的最新版本，不包含该版本。
        如: 25.0.0 表示获取到的最新版本不能高于 25.0.0
    #>
    param(
        [string]$Package,
        [string]$InstallerType,
        [string]$MaxExclusiveVersion
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

    $rootDir = $Package.ToLower()[0]

    $PackageIdentifier = $Package
    $PackagePath = $Package -replace '\.', '/'

    $url = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/$rootDir/$PackagePath"

    try {
        $parameters = @{
            Uri                      = $url
            ConnectionTimeoutSeconds = 10
            OperationTimeoutSeconds  = 15
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

    $versions = $versionList.Content | ConvertFrom-Json | ForEach-Object { if ($_.Name -notmatch '^\.') { $_.Name } }

    foreach ($v in $versions) {
        if ($MaxExclusiveVersion) {
            # 如果大于或等于最高版本限制，则跳过
            $isExclusive = A-Compare-Version $v $MaxExclusiveVersion
            if ($isExclusive -ge 0) {
                continue
            }
        }
        $compare = A-Compare-Version $v $latestVersion
        if ($compare -gt 0) {
            $latestVersion = $v
        }
    }

    $url = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/$rootDir/$PackagePath/$latestVersion/$PackageIdentifier.installer.yaml"

    try {
        $parameters = @{
            Uri                      = $url
            ConnectionTimeoutSeconds = 10
            OperationTimeoutSeconds  = 15
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

#region 废弃

function A-Start-PreUninstall {
    <#
    .SYNOPSIS
        由于 abyss 中的应用会在此函数运行后执行自定义卸载脚本，所以此函数可以当做安装阶段的开始
    #>
}

function A-Start-PostUninstall {
    <#
    .SYNOPSIS
        由于 abyss 中的应用会在 pre_uninstall 阶段完成自定义卸载脚本，所以此函数可以当做卸载阶段的结束
    #>
}

#endregion

#region 以下的函数不应该被直接使用。请使用文件开头列出的可用函数。
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
        LinkPaths   = @()
        LinkTargets = @()
    }

    if ($LinkPaths.Count) {
        for ($i = 0; $i -lt $LinkPaths.Count; $i++) {
            $linkPath = $LinkPaths[$i]
            $linkTarget = $LinkTargets[$i]
            $installData.LinkPaths += $linkPath
            $installData.LinkTargets += $linkTarget
            if ((Test-Path $linkPath) -and !(Get-Item $linkPath -ErrorAction SilentlyContinue).LinkType) {
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
                    Write-Host $words["Failed to remove:"] -ForegroundColor Red -NoNewline
                    Write-Host " $linkPath" -ForegroundColor Cyan
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

    .PARAMETER PackageFamilyName
        应用程序包的 PackageFamilyName

    .PARAMETER Path
        要安装的 AppX/Msix 包的文件路径。支持管道输入。

    .EXAMPLE
        A-Add-AppxPackage -Path "D:\dl.msixbundle"
    #>
    param(
        [string]$PackageFamilyName,
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
        Write-Host "$app 的程序安装目录不在 Scoop 中。`nScoop 只管理数据(如果存在)、安装、卸载、更新。" -ForegroundColor Yellow
    }
    else {
        Write-Host "The installation directory of $app is not in Scoop.`nScoop only manages the data that may exist and installation, uninstallation, and update." -ForegroundColor Yellow
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

function A-Get-AbsolutePath {
    param(
        [string]$path
    )

    if ([System.IO.Path]::IsPathRooted($path)) {
        return $path
    }

    return Join-Path $dir $path
}
#endregion



# 重写的函数是基于这个 Scoop 版本的。
# 如果 Scoop 最新版本大于它，需要检查重写的函数，如果新版本中这些函数有变动，需要立即修正，然后更新此处的 Scoop 版本号
$ScoopVersion = "0.5.3"

#region 重写部分 Scoop 内置函数及输出函数以添加本地化输出

function script:A-Translate-Message {
    param(
        [string]$msg,
        [System.Object]$msgMap
    )

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

function script:Write-Host {
    [CmdletBinding()]
    param(
        $Object,
        [switch]$NoNewline,
        [Alias('f')]
        [System.ConsoleColor]$ForegroundColor,
        [Alias('b')]
        [System.ConsoleColor]$BackgroundColor
    )

    if ($Object -is [string]) {
        $Object = A-Translate-Message $Object @{
            # "'$app' ($version) was installed successfully!" = "$app ($version) 已成功安装!"
            "'{0}' ({1}) was installed successfully!"                                                                                                        = "{0} ({1}) 已成功安装!"
            "'{0}' was uninstalled."                                                                                                                         = "{0} 已成功卸载!"
            "ERROR '{0}' isn't installed correctly."                                                                                                         = "错误: {0} 未正确安装。"
            "Running {0} script..."                                                                                                                          = "正在运行 {0} 脚本..."
            "done."                                                                                                                                          = "完成。"

            "Loading {0} from cache"                                                                                                                         = "正在加载 {0} 的缓存"
            "Loading "                                                                                                                                       = "正在加载 "
            " from cache."                                                                                                                                   = " 的缓存"
            "WARN  Token might be misconfigured."                                                                                                            = "警告: 令牌可能被错误配置。"

            "Starting download with aria2 ..."                                                                                                               = "正在使用 aria2 下载..."
            "`rDownload: {0}"                                                                                                                                = "`r下载: {0}"
            "WARN  Download failed! (Error {0}) {1}"                                                                                                         = "警告: 下载失败! (错误 {0}) {1}"
            "WARN  {0} download via aria2 failed"                                                                                                            = "警告: {0} 下载失败"
            "Fallback to default downloader ..."                                                                                                             = "回退到默认下载器..."
            "URL {0} is not valid"                                                                                                                           = "URL {0} 无效"
            "SourceForge.net is known for causing hash validation fails. Please try again before opening a ticket."                                          = "SourceForge.net 经常导致哈希验证失败。请在提交工单前重试。"
            "{0} hash check failed"                                                                                                                          = "{0} 哈希校验失败"
            "{0} cached file not found"                                                                                                                      = "{0} 缓存文件未找到"

            "Extracting "                                                                                                                                    = "正在解压 "

            "Linking {0} => {1}"                                                                                                                             = "正在创建链接: {0} => {1}"
            "Error: Version 'current' is not allowed!"                                                                                                       = "错误：不允许使用 current 作为版本！请联系 bucket 维护者。"

            "Unlinking {0}"                                                                                                                                  = "正在解除链接: {0}"

            "Can't shim '{0}': File doesn't exist."                                                                                                          = "不能为 {0} 创建 shim: 文件不存在。"

            "Can't shim '{0}': couldn't find '{1}'."                                                                                                         = "不能为 {0} 创建 shim: 不能找到 {1}"
            "WARN  Overwriting shim ('{0}' -> '{1}')"                                                                                                        = "警告: 正在覆盖 shim ('{0}' -> '{1}')"
            "WARN  Overwriting shim ('{0}' -> '{1}') installed from {2}"                                                                                     = "警告: 正在覆盖安装 {2} 时创建的 shim ('{0}' -> '{1}')"

            "Removing shortcut {0}"                                                                                                                          = "正在移除快捷方式: {0}"

            "Invalid manifest: The 'name' property is missing from 'psmodule'."                                                                              = "无效的应用清单(manifest)：psmodule 中缺少 name 属性。"
            "Installing PowerShell module '{0}'"                                                                                                             = "正在安装 PowerShell 模块: '{0}'"
            "WARN  {0} already exists. It will be replaced."                                                                                                 = "警告: {0} 已经存在，它将被替换。"

            "Uninstalling PowerShell module '{0}'."                                                                                                          = "正在卸载 PowerShell 模块: {0}"

            "Removing {0}"                                                                                                                                   = "正在移除: {0}"

            "Persisting {0}"                                                                                                                                 = "正在持久化数据: {0}"


            "WARN  The following instances of `"{0}`" are still running. Scoop is configured to ignore this condition."                                      = "警告: {0} 的以下实例仍在运行。Scoop 被配置为忽略此情况。"
            "ERROR The following instances of `"{0}`" are still running. Close them and try again."                                                          = "错误: {0} 的以下实例仍在运行。请关闭它们然后重试。"

            "INFO  Repair previous failed installation of {0}."                                                                                              = "提示: 修复 {0} 先前失败的安装。"

            "WARN  Purging previous failed installation of {0}."                                                                                             = "警告: 正在清除 {0} 之前安装失败的残留。"

            "Error in manifest: {0} is outside the app directory."                                                                                           = "应用清单(manifest)错误: {0} 在应用程序目录之外。"
            "{0} is missing."                                                                                                                                = "{0} 不存在。"
            "Uninstallation aborted."                                                                                                                        = "卸载已中止。"
            "Installation aborted. You might need to run 'scoop uninstall {0}' before trying again."                                                         = "安装已中止。在再次尝试之前，你可能需要运行 scoop uninstall {0}"

            "The config 'abgox-abyss-app-shortcuts-action' is set to 0, so the shortcuts defined in the manifest will not be created."                       = "配置 abgox-abyss-app-shortcuts-action 的值为 0，因此不会创建清单中定义的快捷方式。"
            "{0} uses an installer and config 'abgox-abyss-app-shortcuts-action' is set to 2, so the shortcuts defined in the manifest will not be created." = "{0} 使用安装程序进行安装，且配置 abgox-abyss-app-shortcuts-action 的值为 2，因此不会创建清单中定义的快捷方式。"

            "Creating shortcut for {0} ({1}) failed: Couldn't find {2}"                                                                                      = "为 {1} 创建快捷方式 {0} 失败了: 没有找到 {2}"
            "Creating shortcut for {0} ({1}) failed: Couldn't find icon {2}"                                                                                 = "为 {1} 创建快捷方式 {0} 失败了: 没有找到 icon 图标 {2}"
            "Creating shortcut for {0} ({1})"                                                                                                                = "为 {1} 创建了快捷方式: {0}"
        }
    }

    $splatParams = @{}

    if ($PSBoundParameters.ContainsKey('Object')) {
        $splatParams['Object'] = $Object
    }
    if ($PSBoundParameters.ContainsKey('NoNewline')) {
        $splatParams['NoNewline'] = $NoNewline
    }
    if ($PSBoundParameters.ContainsKey('ForegroundColor')) {
        $splatParams['ForegroundColor'] = $ForegroundColor
    }
    if ($PSBoundParameters.ContainsKey('BackgroundColor')) {
        $splatParams['BackgroundColor'] = $BackgroundColor
    }

    Microsoft.PowerShell.Utility\Write-Host @splatParams
}

function script:Write-Output {
    [CmdletBinding()]
    param(
        $InputObject
    )

    if ($InputObject -is [string]) {
        $InputObject = A-Translate-Message $InputObject @{
            "Uninstalling '{0}'"                           = "正在卸载 {0}"
            "Creating shim for '{0}'."                     = "正在为 {0} 创建 shim"
            "Removing shim '{0}'."                         = "正在移除 shim: {0}"
            "Removing shim '{0}.exe'."                     = "正在移除 shim: {0}.exe"
            "Making {0}.exe a GUI binary."                 = "{0}.exe 是一个 GUI 二进制文件"
            "Adding {0} to global PowerShell module path." = "正在添加 {0} 到环境变量(系统级) PSModulePath 中。"
            "Adding {0} to your PowerShell module path."   = "正在添加 {0} 到环境变量(当前用户) PSModulePath 中。"
        }
    }

    Microsoft.PowerShell.Utility\Write-Output $InputObject
}

function script:env_set($manifest, $global, $arch) {
    $env_set = arch_specific 'env_set' $manifest $arch
    if ($env_set) {
        $env_set | Get-Member -MemberType NoteProperty | ForEach-Object {
            $name = $_.Name
            $val = $ExecutionContext.InvokeCommand.ExpandString($env_set.$($name))
            #region 新增: 环境变量输出
            if ($PSUICulture -like "zh*" -and $cmd) {
                Microsoft.PowerShell.Utility\Write-Output "正在设置环境变量$(if($global){'(系统级)'}else{'(当前用户)'}): $name = $val"
            }
            else {
                Microsoft.PowerShell.Utility\Write-Output "Setting environment variable$(if($global){'(system)'}else{'(for current user)'}): $name = $val"
            }
            #endregion
            Set-EnvVar -Name $name -Value $val -Global:$global
            Set-Content env:\$name $val
        }
    }
}

function script:env_rm($manifest, $global, $arch) {
    $env_set = arch_specific 'env_set' $manifest $arch
    if ($env_set) {
        $env_set | Get-Member -MemberType NoteProperty | ForEach-Object {
            $name = $_.Name
            #region 新增: 环境变量输出
            if ($PSUICulture -like "zh*" -and $cmd) {
                Microsoft.PowerShell.Utility\Write-Output "正在移除环境变量$(if($global){'(系统级)'}else{'(当前用户)'}): $name"
            }
            else {
                Microsoft.PowerShell.Utility\Write-Output "Removing environment variable$(if($global){'(system)'}else{'(for current user)'}): $name"
            }
            #endregion
            Set-EnvVar -Name $name -Value $null -Global:$global
            if (Test-Path env:\$name) { Remove-Item env:\$name }
        }
    }
}

function script:Add-Path {
    param(
        [string[]]$Path,
        [string]$TargetEnvVar = 'PATH',
        [switch]$Global,
        [switch]$Force,
        [switch]$Quiet
    )
    #region 新增: $env:xxx 变量支持
    $Path = $Path | ForEach-Object {
        # 处理当 env_add_path 值为 $dir 的特殊情况
        if ($_ -eq "$dir\`$dir") {
            $dir
        }
        else {
            Invoke-Expression "`"$($_.Replace("$dir\`$env:", '$env:'))`""
        }
    }
    #endregion

    # future sessions
    $inPath, $strippedPath = Split-PathLikeEnvVar $Path (Get-EnvVar -Name $TargetEnvVar -Global:$Global)

    if (!$inPath -or $Force) {
        if (!$Quiet) {
            #region 修改: 本地化输出
            if ($PSUICulture -like "zh*" -and $cmd) {
                $Path | ForEach-Object {
                    Write-Host "正在添加 $(friendly_path $_) 到环境变量$(if($global){'(系统级)'}else{'(当前用户)'}) $TargetEnvVar 中。"
                }
            }
            else {
                $Path | ForEach-Object {
                    Write-Host "Adding $(friendly_path $_) to $(if ($Global) {'global'} else {'your'}) path."
                }
            }
            #endregion
        }
        Set-EnvVar -Name $TargetEnvVar -Value ((@($Path) + $strippedPath) -join ';') -Global:$Global
    }
    # current session
    $inPath, $strippedPath = Split-PathLikeEnvVar $Path $env:PATH
    if (!$inPath -or $Force) {
        $env:PATH = (@($Path) + $strippedPath) -join ';'
    }
}

function script:Remove-Path {
    param(
        [string[]]$Path,
        [string]$TargetEnvVar = 'PATH',
        [switch]$Global,
        [switch]$Quiet,
        [switch]$PassThru
    )
    #region 新增: $env:xxx 变量支持
    $Path = $Path | ForEach-Object {
        # 处理当 env_add_path 值为 $dir 的特殊情况
        if ($_ -eq "$dir\`$dir") {
            $dir
        }
        else {
            Invoke-Expression "`"$($_.Replace("$dir\`$env:", '$env:'))`""
        }
    }
    #endregion

    # future sessions
    $inPath, $strippedPath = Split-PathLikeEnvVar $Path (Get-EnvVar -Name $TargetEnvVar -Global:$Global)
    if ($inPath) {
        if (!$Quiet) {
            #region 修改: 本地化输出
            if ($PSUICulture -like "zh*" -and $cmd) {
                $Path | ForEach-Object {
                    Write-Host "正在从环境变量$(if ($Global) {'(系统级)'} else {'(当前用户)'}) $TargetEnvVar 中移除 $(friendly_path $_)"
                }
            }
            else {
                $Path | ForEach-Object {
                    Write-Host "Removing $(friendly_path $_) from $(if ($Global) {'global'} else {'your'}) path."
                }
            }
            #endregion
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

    try {
        $ScoopConfig = scoop config

        # 创建快捷方式的操作行为。
        # 0: 不创建清单中定义的快捷方式
        # 1: 创建清单中定义的快捷方式
        # 2: 如果应用使用安装程序进行安装，不创建清单中定义的快捷方式
        $shortcutsActionLevel = $ScoopConfig.'abgox-abyss-app-shortcuts-action'
    }
    catch {}

    if ($null -eq $shortcutsActionLevel) {
        $shortcutsActionLevel = "1"
    }

    if ($shortcutsActionLevel -eq '0') {
        Write-Host "The config 'abgox-abyss-app-shortcuts-action' is set to 0, so the shortcuts defined in the manifest will not be created." -ForegroundColor Yellow
        return
    }
    if ($shortcutsActionLevel -eq '2' -and (A-Test-ScriptPattern $manifest '.*A-Install-Exe.*')) {
        Write-Host "$app uses an installer and config 'abgox-abyss-app-shortcuts-action' is set to 2, so the shortcuts defined in the manifest will not be created." -ForegroundColor Yellow
        return
    }

    # 支持在 shortcuts 中使用以 $env:xxx 环境变量开头的路径
    $filename = $target.FullName
    if ($filename -match '\$env:[a-zA-Z_].*') {
        $filename = $filename.Replace("$dir\", '')
        $target = [System.IO.FileInfo]::new((Invoke-Expression "`"$filename`""))
    }

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
    $label = 'Notes'
    $note = $manifest.notes

    if ($PSUICulture -like 'zh*') {
        $label = '说明'
        $note = $manifest.'notes-cn'
    }

    if ($note) {
        Write-Host
        Write-Output $label
        Write-Output '-----'

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
        Write-Output '-----'
    }
    #endregion
}

function script:show_suggestions($suggested) {
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
                #region 修改: 本地化输出
                Microsoft.PowerShell.Utility\Write-Host
                if ($PSUICulture -like "zh*" -and $cmd) {
                    Microsoft.PowerShell.Utility\Write-Host "$app 建议你安装 $([string]::join("，", $feature_suggestions))" -ForegroundColor Yellow
                }
                else {
                    Microsoft.PowerShell.Utility\Write-Host "'$app' suggests installing '$([string]::join("' or '", $feature_suggestions))'." -ForegroundColor Yellow
                }
                #endregion
            }
        }
    }
}

if ($ShowCN) {
    function script:ensure_install_dir_not_in_path($dir, $global) {
        $path = (Get-EnvVar -Name 'PATH' -Global:$global)

        $fixed, $removed = find_dir_or_subdir $path "$dir"
        if ($removed) {
            # $removed | ForEach-Object { "Installer added '$(friendly_path $_)' to path. Removing." }
            $removed | ForEach-Object { "安装程序已将 '$(friendly_path $_)' 添加到环境变量 Path 中，正在删除。" }
            Set-EnvVar -Name 'PATH' -Value $fixed -Global:$global
        }

        if (!$global) {
            $fixed, $removed = find_dir_or_subdir (Get-EnvVar -Name 'PATH' -Global) "$dir"
            if ($removed) {
                # $removed | ForEach-Object { warn "Installer added '$_' to system path. You might want to remove this manually (requires admin permission)." }
                $removed | ForEach-Object { warn "安装程序在系统环境变量 Path 中添加了 $_，你可能需要手动删除 (需要管理员权限)。" }
            }
        }
    }

    function script:install_app($app, $architecture, $global, $suggested, $use_cache = $true, $check_hash = $true) {
        $app, $manifest, $bucket, $url = Get-Manifest $app

        if (!$manifest) {
            # abort "Couldn't find manifest for '$app'$(if ($bucket) { " from '$bucket' bucket" } elseif ($url) { " at '$url'" })."
            abort "无法从 $(if ($bucket) { "$bucket (bucket)" } elseif ($url) { $url }) 中找到应用 $app 的清单(manifest)"
        }

        $version = $manifest.version
        # if (!$version) { abort "Manifest doesn't specify a version." }
        if (!$version) { abort "清单(manifest) 中没有指定一个版本号。" }
        if ($version -match '[^\w\.\-\+_]') {
            # abort "Manifest version has unsupported character '$($matches[0])'."
            abort "清单(manifest) 中的版本具有不支持的字符: $($matches[0])"
        }

        $is_nightly = $version -eq 'nightly'
        if ($is_nightly) {
            $version = nightly_version
            $check_hash = $false
        }

        $architecture = Get-SupportedArchitecture $manifest $architecture
        if ($null -eq $architecture) {
            # error "'$app' doesn't support current architecture!"
            error "$app 不支持当前的架构!"
            return
        }

        if ((get_config SHOW_MANIFEST $false) -and ($MyInvocation.ScriptName -notlike '*scoop-update*')) {
            # Write-Host "Manifest: $app.json"
            Write-Host "清单(manifest): $app.json"
            $style = get_config CAT_STYLE
            if ($style) {
                $manifest | ConvertToPrettyJson | bat --no-paging --style $style --language json
            }
            else {
                $manifest | ConvertToPrettyJson
            }
            # $answer = Read-Host -Prompt 'Continue installation? [Y/n]'
            $answer = Read-Host -Prompt '继续安装? [Y/n]'
            if (($answer -eq 'n') -or ($answer -eq 'N')) {
                return
            }
        }
        # Write-Output "Installing '$app' ($version) [$architecture]$(if ($bucket) { " from '$bucket' bucket" } else { " from '$url'" })"
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

        success "'$app' ($version) was installed successfully!"

        show_notes $manifest $dir $original_dir $persist_dir
    }
}
#endregion
