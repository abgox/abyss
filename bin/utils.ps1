﻿#Requires -Version 5.1

Set-StrictMode -Off

Microsoft.PowerShell.Utility\Write-Host

# Github: https://github.com/abgox/abyss#config
# Gitee: https://gitee.com/abgox/abyss#config
try {
    $ScoopConfig = scoop config

    if ($scoopdir -and $ScoopConfig.root_path -ne $scoopdir) {
        scoop config 'root_path' $scoopdir
    }

    # 卸载时的操作行为。
    $uninstallActionLevel = $ScoopConfig.'abgox-abyss-app-uninstall-action'

    # 本地添加的 abyss 的实际名称
    # https://github.com/abgox/abyss/issues/10
    if ($bucket) {
        if ($ScoopConfig.'abgox-abyss-bucket-name' -ne $bucket) {
            scoop config 'abgox-abyss-bucket-name' $bucket
        }
        if ($bucket -ne 'abyss') {
            error "You should use 'abyss' as the bucket name, but the current name is '$bucket'."
            error "Reference: https://abyss.abgox.com/faq/bucket-name"
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
    #>
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) -and ($identity.Groups -contains "S-1-5-32-544")
}

function A-Test-DeveloperMode {
    <#
    .SYNOPSIS
        检查开发者模式是否启用

    .LINK
        https://learn.microsoft.com/windows/apps/get-started/developer-mode-features-and-debugging
    #>
    $path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
    try {
        $value = Get-ItemProperty -LiteralPath $path -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction Stop
        return $value.AllowDevelopmentWithoutDevLicense -eq 1
    }
    catch {
        return $false
    }
}

$isAdmin = A-Test-Admin
$isDevMode = A-Test-DeveloperMode

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
    # 如果新版本为 pending 或 deprecated，拒绝更新
    if ($version -in @('pending', 'deprecated')) {
        A-Deny-Update
    }
}

function A-Complete-Uninstall {

}

function A-Ensure-Directory {
    <#
    .SYNOPSIS
        确保指定目录路径存在

    .PARAMETER Path
        目录路径，默认使用 $persist_dir
    #>
    param (
        [string]$Path = $persist_dir
    )
    if (-not (Test-Path -LiteralPath $Path)) {
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
        文件或目录名必须对应，以下是错误写法
        A-Copy-Item "$bucketsdir\$bucket\extras\$app\InputTip.ini" $persist_dir
    #>
    param (
        [string]$Path,
        [string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        error "Source path does not exist: $Path"
        error "Please contact the bucket maintainer!"
        A-Exit
    }

    $sourceItem = Get-Item -LiteralPath $Path
    $targetDir = Split-Path $Destination -Parent

    A-Ensure-Directory $targetDir

    $needCopy = $true

    if (Test-Path -LiteralPath $Destination) {
        $targetItem = Get-Item -LiteralPath $Destination

        if ($sourceItem.PSIsContainer -eq $targetItem.PSIsContainer) {
            $needCopy = $false
        }
        else {
            Remove-Item $Destination -Recurse -Force
            $needCopy = $true
        }
    }

    if ($needCopy) {
        try {
            Copy-Item -LiteralPath $Path -Destination $Destination -Recurse -Force
            Write-Host "Copying $Path => $Destination"
        }
        catch {
            error $_.Exception.Message
            error "Please contact the bucket maintainer!"
            A-Exit
        }
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
        文件编码，默认为 utf8
        此参数仅在指定了 -Content 参数时有效

    .EXAMPLE
        A-New-PersistFile "$persist_dir\data.json" -Content "{}"
        创建文件并指定内容

    .EXAMPLE
        A-New-PersistFile "$persist_dir\data.ini" -Content @('[Settings]', 'AutoUpdate=0')
        创建文件并指定内容，传入数组会被写入多行

    .EXAMPLE
        A-New-PersistFile "$persist_dir\data.ini"
        创建空文件
    #>
    param (
        [string]$Path,
        [array]$Content,
        [ValidateSet("utf8", "utf8Bom", "utf8NoBom", "unicode", "ansi", "ascii", "bigendianunicode", "bigendianutf32", "oem", "utf7", "utf32")]
        [string]$Encoding = "utf8"
    )

    $itemExists = Test-Path -LiteralPath $Path
    $item = if ($itemExists) { Get-Item -LiteralPath $Path } else { $null }

    if ($itemExists) {
        # 如果是一个目录，就删除它
        if ($item.PSIsContainer) {
            try {
                Remove-Item $Path -Recurse -Force
            }
            catch {
                error $_.Exception.Message
                error "Please contact the bucket maintainer!"
                A-Exit
            }
        }
        else {
            return
        }
    }

    $parentDir = Split-Path $Path -Parent
    A-Ensure-Directory $parentDir

    if ($PSBoundParameters.ContainsKey('Content')) {
        # 当明确传递了 Content 参数时（包括空字符串或 $null）
        Set-Content -Path $Path -Value $Content -Encoding $Encoding -Force
    }
    else {
        # 当没有传递 Content 参数时
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
        生成规则:
            如果 LinkPaths 包含 $env:UserProfile，则替换为 $persist_dir
            否则，去掉盘符

    .EXAMPLE
        A-New-LinkFile @("$env:UserProfile\.config\starship.toml")

    .LINK
        https://github.com/abgox/abyss#link
        https://gitee.com/abgox/abyss#link
    #>
    param (
        [array]$LinkPaths,
        [System.Collections.Generic.List[string]]$LinkTargets = @()
    )

    if (!$isAdmin -and !$isDevMode) {
        error "$app requires admin permission or developer mode to create SymbolicLink."
        error "Reference: https://abyss.abgox.com/faq/require-admin-or-dev-mode"
        A-Exit
    }

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
        生成规则:
            如果 LinkPaths 包含 $env:UserProfile，则替换为 $persist_dir
            否则，去掉盘符

    .EXAMPLE
        A-New-LinkDirectory @("$env:AppData\Code","$env:UserProfile\.vscode")

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
        根据全局变量 $cmd 和 $uninstallActionLevel 的值决定是否执行删除操作。
    #>

    if ((Test-Path -LiteralPath "$dir\scoop-install-A-Add-AppxPackage.jsonc") -or (Test-Path -LiteralPath "$dir\scoop-install-A-Install-Exe.jsonc")) {
        # 通过 Msix 打包的程序或安装程序安装的应用，在卸载时会删除所有数据文件，因此必须先删除链接目录以保留数据
    }
    elseif ($uninstallActionLevel -notlike "*2*") {
        # 如果使用了 -p 或 --purge 参数，则需要执行删除操作
        if (-not $purge) {
            return
        }
    }

    @("$dir\scoop-install-A-New-LinkFile.jsonc", "$dir\scoop-install-A-New-LinkDirectory.jsonc") | ForEach-Object {
        if (Test-Path -LiteralPath $_) {
            $LinkPaths = Get-Content $_ -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json | Select-Object -ExpandProperty "LinkPaths"

            foreach ($p in $LinkPaths) {
                if (A-Test-SymbolicLink $p) {
                    try {
                        Write-Host "Unlinking $p"
                        Remove-Item $p -Force -Recurse -ErrorAction Stop

                        $parent = Split-Path $p -Parent
                        if (-not (A-Test-DirectoryNotEmpty $parent)) {
                            Write-Host "Removing $parent"
                            Remove-Item $parent -Force -Recurse -ErrorAction Stop
                        }
                    }
                    catch {
                        error $_.Exception.Message
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
        该函数用于删除指定的临时数据目录或文件。
        根据全局变量 $cmd 和 $uninstallActionLevel 的值决定是否执行删除操作。

    .PARAMETER Paths
        要删除的临时数据路径数组。
        可以包含文件或目录路径。

    .EXAMPLE
        A-Remove-TempData -Paths @("C:\Temp\Logs", "D:\Cache")
        删除指定的两个临时数据目录
    #>
    param (
        [array]$Paths
    )

    if ($cmd -eq "update" -or $uninstallActionLevel -notlike "*3*") {
        # 如果使用了 -p 或 --purge 参数，则需要执行删除操作
        if (-not $purge) {
            return
        }
    }
    foreach ($p in $Paths) {
        if (Test-Path -LiteralPath $p) {
            try {
                Write-Host "Removing $p"
                Remove-Item $p -Force -Recurse -ErrorAction Stop

                $parent = Split-Path $p -Parent
                if (-not (A-Test-DirectoryNotEmpty $parent)) {
                    Write-Host "Removing $parent"
                    Remove-Item $parent -Force -Recurse -ErrorAction Stop
                }
            }
            catch {
                error $_.Exception.Message
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


    # Msix/Appx 在移除包时会自动终止进程，不需要手动终止，除非显示指定 ExtraPaths
    if ($uninstallActionLevel -notlike "*1*" -or ((Test-Path -LiteralPath "$dir\scoop-install-A-Add-AppxPackage.jsonc") -and !$PSBoundParameters.ContainsKey('ExtraPaths'))) {
        return
    }

    $Paths = @($dir, (Split-Path $dir -Parent) + '\current')
    $Paths += $ExtraPaths

    $processes = Get-Process

    foreach ($app_dir in $Paths) {
        # $matched = $processes.where({ $_.Modules.FileName -like "$app_dir\*" })
        $matched = $processes.where({ $_.MainModule.FileName -like "$app_dir\*" })
        foreach ($p in $matched) {
            try {
                if (Get-Process -Id $p.Id -ErrorAction SilentlyContinue) {
                    Write-Host "Stopping the process: $($p.Id) $($p.Name) ($($p.MainModule.FileName))"
                    Stop-Process -Id $p.Id -Force -ErrorAction Stop
                }
            }
            catch {
                if ($_.FullyQualifiedErrorId -like 'NoProcessFoundForGivenId*') {
                    # 进程已经不存在，无需处理
                    continue
                }
                error $_.Exception.Message
                error "Please contact the bucket maintainer!"
                A-Exit
            }
        }
    }

    foreach ($processName in $ExtraProcessNames) {
        $p = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if ($p) {
            try {
                Write-Host "Stopping the process: $($p.Id) $($p.Name) ($($p.MainModule.FileName))"
                Stop-Process -Id $p.Id -Force -ErrorAction Stop
            }
            catch {
                if ($_.FullyQualifiedErrorId -like 'NoProcessFoundForGivenId*') {
                    # 进程已经不存在，无需处理
                    continue
                }
                error $_.Exception.Message
                error "Please contact the bucket maintainer!"
                A-Exit
            }
        }
    }

    Start-Sleep -Seconds 1
}

function A-Stop-Service {
    param(
        [string]$ServiceName,
        [switch]$RequireAdmin
    )

    if (-not $isAdmin -and $RequireAdmin) {
        A-Require-Admin
    }

    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if (-not $service) {
        return
    }

    try {
        Write-Host "Stopping the service: $($service.Name)"
        $service | Stop-Service -ErrorAction Stop -Force
    }
    catch {
        error $_.Exception.Message
        error "Please contact the bucket maintainer!"
        A-Exit
    }

    return $service
}

function A-Remove-Service {
    param(
        [Parameter(ValueFromPipeline)]
        $InputObject
    )

    process {
        $service = $_
        if (-not $service) { return }

        try {
            Write-Host "Removing the service: $($service.Name)"
            $service | Remove-Service -ErrorAction Stop
        }
        catch {
            error $_.Exception.Message
            error "Please contact the bucket maintainer!"
            A-Exit
        }
    }
}

function A-Install-Exe {
    param(
        [ValidateSet("inno", "msi")]
        [string]$InstallerType,
        [string]$Installer,
        [array]$ArgumentList,

        # 当指定它后，A-Uninstall-Exe 会默认使用它作为卸载程序路径
        [string]$Uninstaller
    )

    if ($PSBoundParameters.ContainsKey('Installer')) {
        $Installer = A-Get-AbsolutePath $Installer
    }
    else {
        # $fname 由 Scoop 提供，即下载的文件名
        $Installer = Join-Path $dir ($fname | Select-Object -First 1)
    }

    if ($InstallerType -eq "inno") {
        if (!$PSBoundParameters.ContainsKey('ArgumentList')) {
            $ArgumentList = @(
                '/CurrentUser',
                '/VerySilent',
                '/SuppressMsgBoxes',
                '/NoRestart',
                '/SP-',
                "/Log=$dir\$app-install.log",
                "/Dir=`"$dir\app`""
            )
        }
        if (!$PSBoundParameters.ContainsKey('Uninstaller')) {
            $Uninstaller = 'app\unins000.exe'
        }
    }
    elseif ($InstallerType -eq "msi") {
        if (!$PSBoundParameters.ContainsKey('ArgumentList')) {
            $msiFile = Join-Path $dir ($fname | Select-Object -First 1)

            $ArgumentList = @(
                '/i',
                "`"$msiFile`"",
                # '/passive',
                '/quiet',
                '/norestart'
            )
        }
        if (!$PSBoundParameters.ContainsKey('Installer')) {
            $Installer = if ([Environment]::Is64BitOperatingSystem) {
                'C:\Windows\SysWOW64\msiexec.exe'
            }
            else {
                'C:\Windows\System32\msiexec.exe'
            }
        }
        if (!$PSBoundParameters.ContainsKey('Uninstaller')) {
            $Uninstaller = $Installer
        }
    }
    else {
        # 如果没有传递安装参数，则使用默认参数
        if (!$PSBoundParameters.ContainsKey('ArgumentList')) {
            $ArgumentList = @('/S', "/D=$dir\app")
        }
    }

    if (!$Installer) {
        error "Please contact the bucket maintainer!"
        A-Exit
    }

    if (!(Test-Path -LiteralPath $Installer)) {
        error "'$Installer' not found."
        error "Please contact the bucket maintainer!"
        A-Exit
    }

    $InstallerFileName = Split-Path $Installer -Leaf
    $Uninstaller = A-Get-AbsolutePath $Uninstaller

    $OutFile = "$dir\scoop-install-A-Install-Exe.jsonc"
    @{
        InstallerType = $InstallerType
        Installer     = $Installer
        ArgumentList  = $ArgumentList
        Uninstaller   = $Uninstaller
    } | ConvertTo-Json | Out-File -FilePath $OutFile -Force -Encoding utf8

    Write-Host "Running the installer: $InstallerFileName"

    try {
        $process = Start-Process $Installer -ArgumentList $ArgumentList -PassThru -WindowStyle Hidden
        $process | Wait-Process -ErrorAction Stop
    }
    catch {
        error $_.Exception.Message
        $process | Stop-Process -Force -ErrorAction SilentlyContinue
        A-Exit
    }

    Start-Sleep -Seconds 1

    if ($Uninstaller -and !(Test-Path -LiteralPath $Uninstaller)) {
        error "'$Uninstaller' not found."
        error "Please contact the bucket maintainer!"
        A-Exit
    }

    $removeFile = if ($InstallerType -eq "msi") { $msiFile } else { $Installer }

    try {
        if ($removeFile) {
            Remove-Item $removeFile -Force -ErrorAction Stop
        }
    }
    catch {
        error $_.Exception.Message
    }
}

function A-Uninstall-Exe {
    param(
        # 仅安装时的安装程序类型为 msi 时才需要
        [string]$ProductCode,
        [string]$Uninstaller,
        [array]$ArgumentList
    )

    $InstallerInfoPath = "$dir\scoop-install-A-Install-Exe.jsonc"

    if (Test-Path -LiteralPath $InstallerInfoPath) {
        $InstallerInfo = Get-Content $InstallerInfoPath -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
    }
    else {
        return
    }

    if ($InstallerInfo.InstallerType -eq "inno") {
        if (!$PSBoundParameters.ContainsKey('ArgumentList')) {
            $ArgumentList = @('/VerySilent')
        }
    }
    elseif ($InstallerInfo.InstallerType -eq "msi") {
        # msi 直接覆盖安装，无需卸载
        if ($cmd -eq "update") {
            return
        }

        if (!$PSBoundParameters.ContainsKey('ArgumentList')) {
            if (!$ProductCode) {
                return
            }
            $ArgumentList = @(
                '/x',
                "`"$ProductCode`"",
                '/quiet',
                '/norestart'
            )
        }
    }
    else {
        # 如果没有传递卸载参数，则使用默认参数
        if (!$PSBoundParameters.ContainsKey('ArgumentList')) {
            $ArgumentList = @('/S')
        }
    }

    if (!$PSBoundParameters.ContainsKey('Uninstaller')) {
        $Uninstaller = $InstallerInfo.Uninstaller
    }

    $Uninstaller = A-Get-AbsolutePath $Uninstaller

    if ($Uninstaller) {
        $UninstallerFileName = Split-Path $Uninstaller -Leaf
    }
    else {
        return
    }

    if (!(Test-Path -LiteralPath $Uninstaller)) {
        warn "'$Uninstaller' not found."
        return
    }

    Write-Host "Running the uninstaller: $UninstallerFileName"

    $paramList = @{
        FilePath     = $Uninstaller
        ArgumentList = $ArgumentList
        WindowStyle  = "Hidden"
        PassThru     = $true
    }
    $process = Start-Process @paramList

    try {
        $process | Wait-Process -ErrorAction Stop
    }
    catch {
        error $_.Exception.Message
        $process | Stop-Process -Force -ErrorAction SilentlyContinue
        A-Exit
    }

    Start-Sleep -Seconds 1
}

function A-Uninstall-ExeByHand {
    param(
        [array]$Path
    )

    foreach ($p in $Path) {
        $p = A-Get-AbsolutePath $p
        if (Test-Path -LiteralPath $p) {
            if ((Get-ChildItem -LiteralPath $p -File -Recurse).Count -eq 0) {
                try {
                    Remove-Item $p -Force -Recurse -ErrorAction Stop
                    return
                }
                catch {}
            }
            error "It requires you to uninstall it manually."
            error "Reference: https://abyss.abgox.com/faq/uninstall-manually"
            A-Exit
        }
    }
}

function A-Add-MsixPackage {
    <#
    .SYNOPSIS
        安装 AppX/Msix 包
    #>
    param(
        [string]$PackageFamilyName,
        [string]$FileName
    )
    if ($PSBoundParameters.ContainsKey('FileName')) {
        $path = A-Get-AbsolutePath $FileName
    }
    else {
        # $fname 由 Scoop 提供，即下载的文件名
        $path = Join-Path $dir ($fname | Select-Object -First 1)
    }

    if (!$path) {
        error "Please contact the bucket maintainer!"
        A-Exit
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
        如果未指定字体类型，则根据字体文件扩展名自动判断
    #>
    param(
        [ValidateSet("ttf", "otf", "ttc")]
        [string]$FontType
    )

    if (!$FontType) {
        $fontFile = Get-ChildItem -LiteralPath $dir -Recurse -Include *.ttf, *.otf, *.ttc -File | Select-Object -First 1
        $FontType = $fontFile.Extension.TrimStart(".")
    }

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
        Microsoft.PowerShell.Utility\Write-Host
        error "For Windows version before Windows 10 Version 1809 (OS Build 17763), Font can only be installed for all users.`nPlease use following commands to install '$app' Font for all users."
        Microsoft.PowerShell.Utility\Write-Host
        Microsoft.PowerShell.Utility\Write-Host "        scoop install sudo"
        Microsoft.PowerShell.Utility\Write-Host "        sudo scoop install -g $app"
        Microsoft.PowerShell.Utility\Write-Host
        A-Exit
    }
    $fontInstallDir = if ($global) { "$env:windir\Fonts" } else { "$env:LocalAppData\Microsoft\Windows\Fonts" }
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
    Get-ChildItem -LiteralPath $dir -Filter $filter -Recurse | ForEach-Object {
        $value = if ($global) { $_.Name } else { "$fontInstallDir\$($_.Name)" }
        New-ItemProperty -Path $registryKey -Name $_.Name.Replace($_.Extension, " ($($ExtMap[$_.Extension]))") -Value $value -Force | Out-Null
        Copy-Item -LiteralPath $_.FullName -Destination $fontInstallDir -Force
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
        如果未指定字体类型，则根据字体文件扩展名自动判断
    #>
    param(
        [ValidateSet("ttf", "otf", "ttc")]
        [string]$FontType
    )

    if (!$FontType) {
        $fontFile = Get-ChildItem -LiteralPath $dir -Recurse -Include *.ttf, *.otf, *.ttc -File | Select-Object -First 1
        $FontType = $fontFile.Extension.TrimStart(".")
    }

    $filter = "*.$($FontType)"

    $ExtMap = @{
        ".ttf" = "TrueType"
        ".otf" = "OpenType"
        ".ttc" = "TrueType"
    }

    $fontInstallDir = if ($global) { "$env:windir\Fonts" } else { "$env:LocalAppData\Microsoft\Windows\Fonts" }
    Get-ChildItem -LiteralPath $dir -Filter $filter -Recurse | ForEach-Object {
        Get-ChildItem -LiteralPath $fontInstallDir -Filter $_.Name | ForEach-Object {
            try {
                Rename-Item $_.FullName $_.FullName -ErrorVariable LockError -ErrorAction Stop
            }
            catch {
                error "Cannot uninstall '$app' font.`nIt is currently being used by another application.`nPlease close all applications that are using it (e.g. vscode) and try again."
                A-Exit
            }
        }
    }
    $registryRoot = if ($global) { "HKLM" } else { "HKCU" }
    $registryKey = "${registryRoot}:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    Get-ChildItem -LiteralPath $dir -Filter $filter -Recurse | ForEach-Object {
        Remove-ItemProperty -Path $registryKey -Name $_.Name.Replace($_.Extension, " ($($ExtMap[$_.Extension]))") -Force -ErrorAction SilentlyContinue
        Remove-Item "$fontInstallDir\$($_.Name)" -Force -ErrorAction SilentlyContinue
    }
    if ($cmd -eq "uninstall") {
        warn "The '$app' Font family has been uninstalled successfully, but there may be system cache that needs to be restarted to fully remove."
    }
}

function A-Add-PowerToysRunPlugin {
    param(
        [string]$PluginName
    )

    $PluginsDir = "$env:LocalAppData\Microsoft\PowerToys\PowerToys Run\Plugins"
    $PluginPath = "$PluginsDir\$PluginName"
    $OutFile = "$dir\scoop-Install-A-Add-PowerToysRunPlugin.jsonc"

    try {
        if (Test-Path -LiteralPath $PluginPath) {
            Write-Host "Removing $PluginPath"
            Remove-Item -Path $PluginPath -Recurse -Force -ErrorAction Stop
        }
        $CopyingPath = if (Test-Path -LiteralPath "$dir\$PluginName") { "$dir\$PluginName" } else { $dir }
        A-Ensure-Directory (Split-Path $PluginPath -Parent)
        Write-Host "Copying $CopyingPath => $PluginPath"
        Copy-Item -LiteralPath $CopyingPath -Destination $PluginPath -Recurse -Force

        @{ "PluginName" = $PluginName } | ConvertTo-Json | Out-File -FilePath $OutFile -Force -Encoding utf8
    }
    catch {
        error $_.Exception.Message
        error "Please contact the bucket maintainer!"
        A-Exit
    }
}

function A-Remove-PowerToysRunPlugin {
    $PluginsDir = "$env:LocalAppData\Microsoft\PowerToys\PowerToys Run\Plugins"

    $OutFile = "$dir\scoop-Install-A-Add-PowerToysRunPlugin.jsonc"

    try {
        if (Test-Path -LiteralPath $OutFile) {
            $PluginName = Get-Content $OutFile -Raw | ConvertFrom-Json | Select-Object -ExpandProperty "PluginName"
            $PluginPath = "$PluginsDir\$PluginName"
        }
        else {
            return
        }

        if (Test-Path -LiteralPath $PluginPath) {
            Write-Host "Removing $PluginPath"
            Remove-Item -Path $PluginPath -Recurse -Force -ErrorAction Stop
        }
    }
    catch {
        error $_.Exception.Message
        error "Please contact the bucket maintainer!"
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
    Expand-7zipArchive $7z (Join-Path $dir 'app')

    Remove-Item "$dir\app\`$*" -Recurse -Force -ErrorAction SilentlyContinue
}

function A-Require-Admin {
    <#
    .SYNOPSIS
        要求以管理员权限运行
    #>

    if (!$isAdmin) {
        error "It requires admin permission. Please try again with admin permission."
        A-Exit
    }
}

function A-Deny-Update {
    <#
    .SYNOPSIS
        禁止通过 scoop 更新
    #>
    if ($cmd -eq "update") {
        error "'$app' does not allow update by Scoop."
        error "Reference: https://abyss.abgox.com/faq/deny-update"
        A-Exit
    }
}

function A-Hold-App {
    <#
    .SYNOPSIS
        scoop hold <app>
        它应该在 pre_install 中使用，和 A-Deny-Update 搭配
    #>
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
            if ((scoop list $app).Name | Where-Object { $_ -eq $app }) {
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

function A-Deny-Manifest {
    <#
    .SYNOPSIS
        拒绝清单文件，提示用户使用新的清单文件
    #>
    param(
        [string]$NewManifestName
    )
    switch ($manifest.version) {
        deprecated {
            $msg = "'$app' is deprecated."
        }
        pending {
            $msg = "'$app' is pending."
        }
        renamed {
            $msg = "'$app' is renamed to '$NewManifestName'."
        }
        Default {
            $msg = "'$app' is deprecated."
        }
    }

    error $msg
    error "Reference: https://abyss.abgox.com/faq/deny-manifest"

    A-Exit
}

function A-Move-PersistDirectory {
    <#
    .SYNOPSIS
        用于迁移 persist 目录下的数据到其他位置(在 pre_install 中使用)

    .DESCRIPTION
        它用于未来可能存在的清单文件更名
        当清单文件更名后，需要使用它，并传入旧的清单名称
        当用新的清单名称安装时，它会将 persist 中的旧目录用新的清单名称重命名，以实现 persist 的迁移
        由于只有 abyss 使用了 Publisher.PackageIdentifier 这样的命名格式，迁移不会与官方或其他第三方仓库冲突
    #>
    param(
        # 旧的清单名称(不包含 .json 后缀)
        [array]$OldNames
    )

    if (A-Test-DirectoryNotEmpty $persist_dir) {
        return
    }

    $dir = Split-Path $persist_dir -Parent

    foreach ($oldName in $OldNames) {
        $old = "$dir\$oldName"

        if (A-Test-DirectoryNotEmpty $old) {
            try {
                Rename-Item -Path $old -NewName $app -Force -ErrorAction Stop
                break
            }
            catch {
                error $_.Exception.Message
            }
        }
    }
}

function A-Get-ProductCode {
    param (
        [string]$AppNamePattern
    )

    $code = A-Get-UninstallEntryByAppName $AppNamePattern | Select-Object -ExpandProperty "PSChildName"

    if ($code) {
        return $code
    }

    error "Cannot find product code of '$app'"

    return $null
}

function A-Get-UninstallEntryByAppName {
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
                return $item
            }
        }
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
            UseBasicParsing          = $true
            ErrorAction              = 'Stop'
        }
        if ($env:GITHUB_TOKEN) {
            $parameters.Add('Headers', @{ 'Authorization' = "token $env:GITHUB_TOKEN" })
        }
        $versionList = Invoke-WebRequest @parameters

        $versions = $versionList.Content | ConvertFrom-Json | ForEach-Object { if ($_.Name -notmatch '^\.') { $_.Name } }
    }
    catch {
        Write-Host "::warning::访问 $url 失败" -ForegroundColor Yellow
        Write-Host

        $url = "https://github.com/microsoft/winget-pkgs/tree/master/manifests/$rootDir/$PackagePath"
        try {
            $page = Invoke-WebRequest $url -UseBasicParsing -ErrorAction Stop
        }
        catch {
            Write-Host "::warning::访问 $url 失败" -ForegroundColor Yellow
            Write-Host
            return
        }

        $versions = [regex]::Matches($page.Content, "manifests/$rootDir/$PackagePath/([^`"]+)") | ForEach-Object {
            $v = $_.Groups[1].Value
            if ($v -notmatch '^\.') {
                $v
            }
        }
    }

    $latestVersion = ""

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
            UseBasicParsing          = $true
            ErrorAction              = 'Stop'
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

function A-Test-DirectoryNotEmpty {
    param(
        [string]$Path
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return $false
    }
    return [bool](Get-ChildItem -LiteralPath $Path -Force | Select-Object -First 1)
}

function A-Test-SymbolicLink {
    param(
        [string]$Path
    )
    try {
        $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
        return ($null -ne $item.LinkType)
    }
    catch {
        return $false
    }
}

#region 处理一些兼容性变更

if ($cmd) {
    switch ($app) {
        # 从 2025-10 开始，在未来合适的时机移除 astral-sh.uv，Yarn.Yarn，JohannesMillan.superProductivity
        'astral-sh.uv' {
            if (Test-Path -LiteralPath $persist_dir) {
                @(
                    @{
                        old = "data\python"
                        new = "AppData\Roaming\uv\python"
                    },
                    @{
                        old = "data\tools"
                        new = "AppData\Roaming\uv\tools"
                    },
                    @{
                        old = "data\cache"
                        new = "AppData\Local\uv\cache"
                    }
                ) | ForEach-Object {
                    $old_dir = Join-Path $persist_dir $_.old
                    $new_dir = Join-Path $persist_dir $_.new

                    if ((Test-Path -LiteralPath $old_dir) -and -not (Test-Path -LiteralPath $new_dir)) {
                        A-Ensure-Directory (Split-Path $new_dir -Parent)
                        Move-Item -Path $old_dir -Destination $new_dir -Force -ErrorAction SilentlyContinue
                    }
                }
                if ((Get-ChildItem "$persist_dir\data" -ErrorAction SilentlyContinue).Count -eq 0) {
                    Remove-Item "$persist_dir\data" -Force -Recurse -ErrorAction SilentlyContinue
                }
            }
        }
        'Yarn.Yarn' {
            if (Test-Path -LiteralPath $persist_dir) {
                @(
                    @{
                        old = "global"
                        new = "AppData\Local\Yarn\Data\global"
                    },
                    @{
                        old = "AppData\Local\Yarn\Data\global\bin"
                        new = "AppData\Local\Yarn\bin"
                    },
                    @{
                        old = "cache"
                        new = "AppData\Local\Yarn\cache"
                    },
                    @{
                        old = "mirror"
                        new = "AppData\Local\Yarn\mirror"
                    }
                ) | ForEach-Object {
                    $old_dir = Join-Path $persist_dir $_.old
                    $new_dir = Join-Path $persist_dir $_.new

                    if ((Test-Path -LiteralPath $old_dir) -and -not (Test-Path -LiteralPath $new_dir)) {
                        A-Ensure-Directory (Split-Path $new_dir -Parent)
                        Move-Item -Path $old_dir -Destination $new_dir -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        }
        'JohannesMillan.superProductivity' {
            $old_dir = Join-Path $persist_dir 'SuperProductivity'
            $new_dir = Join-Path $persist_dir 'AppData\Roaming\SuperProductivity'
            if ((Test-Path -LiteralPath $old_dir) -and -not (Test-Path -LiteralPath $new_dir)) {
                A-Ensure-Directory (Split-Path $new_dir -Parent)
                Move-Item -Path $old_dir -Destination $new_dir -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

#endregion

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

#region 以下的函数不应该被直接使用。
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
        error "Please contact the bucket maintainer!"
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
            if ((Test-Path -LiteralPath $linkPath) -and !(Get-Item -LiteralPath $linkPath -ErrorAction SilentlyContinue).LinkType) {
                if (!(Test-Path -LiteralPath $linkTarget)) {
                    A-Ensure-Directory (Split-Path $linkTarget -Parent)
                    Write-Host "Copying $linkPath => $linkTarget"
                    try {
                        Copy-Item -LiteralPath $linkPath -Destination $linkTarget -Recurse -Force -ErrorAction Stop
                    }
                    catch {
                        Remove-Item $linkTarget -Recurse -Force -ErrorAction SilentlyContinue
                        error $_.Exception.Message
                        error "Please contact the bucket maintainer!"
                        A-Exit
                    }
                }
                try {
                    Write-Host "Removing $linkPath"
                    Remove-Item $linkPath -Recurse -Force -ErrorAction Stop
                }
                catch {
                    error $_.Exception.Message
                    error "Please contact the bucket maintainer!"
                    A-Exit
                }
            }
            A-Ensure-Directory $linkTarget

            if ((Get-Service -Name cexecsvc -ErrorAction Ignore)) {
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
            Write-Host "Linking $linkPath => $linkTarget"
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
        要安装的 AppX/Msix 包的文件路径。

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
        error $_.Exception.Message
        error "Please contact the bucket maintainer!"
        A-Exit
    }

    $installData = @{
        package = @{
            PackageFamilyName = $PackageFamilyName
        }
    }
    $installData | ConvertTo-Json | Out-File -FilePath "$dir\scoop-install-A-Add-AppxPackage.jsonc" -Force -Encoding utf8
}

function A-Remove-AppxPackage {
    <#
    .SYNOPSIS
        移除 AppX/Msix 包

    .DESCRIPTION
        该函数使用 Remove-AppxPackage 命令移除应用程序包 (.appx 或 .msixbundle)
    #>

    $OutFile = "$dir\scoop-install-A-Add-AppxPackage.jsonc"

    if (Test-Path -LiteralPath $OutFile) {
        $PackageFamilyName = (Get-Content $OutFile -Raw | ConvertFrom-Json | Select-Object -ExpandProperty "package").PackageFamilyName

        $package = Get-AppxPackage | Where-Object { $_.PackageFamilyName -eq $PackageFamilyName } | Select-Object -First 1

        if ($package) {
            if ($package.InstallLocation) {
                Get-Process | Where-Object { $_.Path -and $_.Path -like "*$($package.InstallLocation)*" } | Stop-Process -Force -ErrorAction SilentlyContinue
            }
            $package | Remove-AppxPackage
        }
    }
}

function A-Exit {
    if ($cmd -eq 'install') {
        Microsoft.PowerShell.Utility\Write-Host
        scoop uninstall $app
    }
    exit 1
}

function A-Get-AbsolutePath {
    param(
        [string]$path
    )

    if (!$path) {
        return ""
    }

    if ([System.IO.Path]::IsPathRooted($path)) {
        return $path
    }

    return Join-Path $dir $path
}
#endregion



# 以下的扩展功能是基于这个 Scoop 版本的，如果 Scoop 最新版本大于它，需要重新检查并跟进
$ScoopVersion = "0.5.3"

#region 扩展 Scoop 部分功能


# TODO: 等待合并后移除此函数: https://github.com/ScoopInstaller/Scoop/pull/6460
function script:env_set($manifest, $global, $arch) {
    $env_set = arch_specific 'env_set' $manifest $arch
    if ($env_set) {
        $env_set | Get-Member -MemberType NoteProperty | ForEach-Object {
            $name = $_.Name
            $val = $ExecutionContext.InvokeCommand.ExpandString($env_set.$($name))
            #region 新增: 环境变量输出
            Write-Output "Setting $(if($global){'system'}else{'user'}) environment variable: $name = $val"
            #endregion
            Set-EnvVar -Name $name -Value $val -Global:$global
            Set-Content env:\$name $val
        }
    }
}

# TODO: 等待合并后移除此函数: https://github.com/ScoopInstaller/Scoop/pull/6460
function script:env_rm($manifest, $global, $arch) {
    $env_set = arch_specific 'env_set' $manifest $arch
    if ($env_set) {
        $env_set | Get-Member -MemberType NoteProperty | ForEach-Object {
            $name = $_.Name
            #region 新增: 环境变量输出
            Write-Output "Removing $(if($global){'system'}else{'user'}) environment variable: $name"
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
    #region 新增: 支持使用 $env:xxx 变量
    # XXX: 如果使用 scoop reset xxx 重置某个应用，会导致问题
    $Path = $Path | ForEach-Object {
        Invoke-Expression "`"$($_.Replace("$dir\`$env:", '$env:'))`""
    }
    #endregion

    # future sessions
    $inPath, $strippedPath = Split-PathLikeEnvVar $Path (Get-EnvVar -Name $TargetEnvVar -Global:$Global)

    if (!$inPath -or $Force) {
        if (!$Quiet) {
            #region 修改: 输出更友好
            $Path | ForEach-Object {
                Write-Host "Adding $(friendly_path $_) to $(if ($Global) {'system'} else {'user'}) environment variable $TargetEnvVar."
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
    #region 新增: 支持使用 $env:xxx 变量
    # XXX: 如果使用 scoop reset xxx 重置某个应用，会导致问题
    $Path = $Path | ForEach-Object {
        Invoke-Expression "`"$($_.Replace("$dir\`$env:", '$env:'))`""
    }
    #endregion

    # future sessions
    $inPath, $strippedPath = Split-PathLikeEnvVar $Path (Get-EnvVar -Name $TargetEnvVar -Global:$Global)
    if ($inPath) {
        if (!$Quiet) {
            #region 修改: 输出更友好
            $Path | ForEach-Object {
                Write-Host "Removing $(friendly_path $_) from $(if ($Global) {'system'} else {'user'}) environment variable $TargetEnvVar."
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

function script:create_shims($manifest, $dir, $global, $arch) {
    $shims = @(arch_specific 'bin' $manifest $arch)
    $shims | Where-Object { $_ -ne $null } | ForEach-Object {
        $target, $name, $arg = shim_def $_
        Write-Output "Creating shim for '$name'."

        #region 新增: 支持使用 $env:xxx 变量
        # XXX: 如果使用 scoop reset xxx 重置某个应用，会导致问题
        $target = Invoke-Expression "`"$target`""
        #endregion

        if (Test-Path "$dir\$target" -PathType leaf) {
            $bin = "$dir\$target"
        }
        elseif (Test-Path $target -PathType leaf) {
            $bin = $target
        }
        else {
            $bin = (Get-Command $target).Source
        }
        if (!$bin) { abort "Can't shim '$target': File doesn't exist." }

        shim $bin $global $name (substitute $arg @{ '$dir' = $dir; '$original_dir' = $original_dir; '$persist_dir' = $persist_dir })
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
        return
    }
    if ($shortcutsActionLevel -eq '2' -and (A-Test-ScriptPattern $manifest '(?<!#.*)A-Install-Exe.*')) {
        $locations = @(
            "$env:AppData\Microsoft\Windows\Start Menu\Programs",
            "$env:LocalAppData\Microsoft\Windows\Start Menu\Programs",
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs",
            "$env:UserProfile\Desktop",
            "$env:Public\Desktop"
        )

        if ($PSVersionTable.PSVersion.Major -ge 7) {
            $found = $locations | ForEach-Object -Parallel {
                $result = Get-ChildItem $_ -Filter "$using:shortcutName.lnk" -Recurse -Depth 5 -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($result) { $result.FullName }
            } | Select-Object -First 1
            if ($found) { return }
        }
        else {
            foreach ($location in $locations) {
                $found = Get-ChildItem $location -Filter "$shortcutName.lnk" -Recurse -Depth 5 -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($found) { return }
            }
        }
    }

    # 支持在 shortcuts 中使用以 $env:xxx 环境变量开头的路径
    # XXX: 如果使用 scoop reset xxx 重置某个应用，会导致问题
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
    $note = $manifest.notes

    if ($PSUICulture -like 'zh*') {
        $note = $manifest.'notes-cn'
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
}
#endregion
