#Requires -Version 5.1

Microsoft.PowerShell.Utility\Write-Host

if (!$env:SCOOP -and $scoopdir) {
    [Environment]::SetEnvironmentVariable('SCOOP', $scoopdir, 'User')
}
if (!$env:SCOOP_GLOBAL -and $globaldir) {
    [Environment]::SetEnvironmentVariable('SCOOP_GLOBAL', $globaldir, 'User')
}

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
            error "You should use 'abyss' as the bucket name, but the current name is '$bucket'."
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
    #>
    $path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
    try {
        $value = Get-ItemProperty -Path $path -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction Stop
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

    if (!$isAdmin -and !$isDevMode) {
        error "$app requires admin permission to create SymbolicLink."
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
                        Write-Host "Unlinking $p"
                        Remove-Item $p -Force -Recurse -ErrorAction Stop
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
                Write-Host "Removing $p"
                Remove-Item $p -Force -Recurse -ErrorAction Stop
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

    $Paths = @($dir, (Split-Path $dir -Parent) + '\current')
    $Paths += $ExtraPaths

    if ($ExtraProcessNames) {
        foreach ($processName in $ExtraProcessNames) {
            $p = Get-Process -Name $processName -ErrorAction SilentlyContinue
            if ($p) {
                try {
                    Write-Host "Stopping the process: $($p.Id) $($p.Name) ($($p.MainModule.FileName))"
                    Stop-Process -Id $p.Id -Force -ErrorAction Stop
                }
                catch {
                    error $_.Exception.Message
                    A-Exit
                }
            }
        }
    }

    # Msix/Appx 在移除包时会自动终止进程，不需要手动终止，除非显示指定 ExtraPaths
    if ($uninstallActionLevel -notlike "*1*" -or ((Test-Path "$dir\scoop-install-A-Add-AppxPackage.jsonc") -and !$PSBoundParameters.ContainsKey('ExtraPaths'))) {
        return
    }

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
                error $_.Exception.Message
                A-Exit
            }
        }
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
        Write-Host "Stopping the service: $ServiceName"
        Stop-Service -Name $ServiceName -ErrorAction Stop
    }
    catch {
        error $_.Exception.Message
        A-Exit
    }

    if ($NoRemove) {
        return
    }

    try {
        Remove-Service -Name $ServiceName -ErrorAction Stop
    }
    catch {
        error $_.Exception.Message
        A-Exit
    }
}

function A-Install-Exe {
    param(
        [ValidateSet("inno")]
        [string]$InstallerType,
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

    if ($InstallerType -eq "inno") {
        if (!$PSBoundParameters.ContainsKey('ArgumentList')) {
            $ArgumentList = @(
                '/CurrentUser',
                '/VerySilent',
                '/SuppressMsgBoxes',
                '/NoRestart',
                '/SP-',
                "/Log=$dir\$app-install.log",
                "/Dir=$dir"
            )
        }
        if (!$PSBoundParameters.ContainsKey('Uninstaller')) {
            $Uninstaller = 'unins000.exe'
        }
    }
    # elseif () {

    # }
    else {
        # 如果没有传递安装参数，则使用默认参数
        if (!$PSBoundParameters.ContainsKey('ArgumentList')) {
            $ArgumentList = @('/S', "/D=$dir")
        }
    }

    if ($PSBoundParameters.ContainsKey('Installer')) {
        $path = A-Get-AbsolutePath $Installer
    }
    else {
        # $fname 由 Scoop 提供，即下载的文件名
        $path = if ($fname -is [array]) { "$dir\$($fname[0])" }else { "$dir\$fname" }
    }

    if (!$path) {
        error "Please contact the bucket maintainer!"
        A-Exit
    }

    $fileName = Split-Path $path -Leaf

    if (!$PSBoundParameters.ContainsKey('SuccessFile')) {
        $SuccessFile = try { $manifest.shortcuts[0][0] }catch { $manifest.architecture.$architecture.shortcuts[0][0] }
        $SuccessFile = Invoke-Expression "`"$SuccessFile`""
    }
    $SuccessFile = A-Get-AbsolutePath $SuccessFile
    $Uninstaller = A-Get-AbsolutePath $Uninstaller

    $OutFile = "$dir\scoop-install-A-Install-Exe.jsonc"
    @{
        InstallerType = $InstallerType
        Installer     = $path
        ArgumentList  = $ArgumentList
        SuccessFile   = $SuccessFile
        Uninstaller   = $Uninstaller
    } | ConvertTo-Json | Out-File -FilePath $OutFile -Force -Encoding utf8

    if (Test-Path $path) {

        Write-Host "Running the installer: $fileName"
        if ($NoSilent) {
            warn "The installer may require some manual operations."
        }
        warn "It will be aborted if times out: $Timeout seconds"

        try {
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
                    Write-Host -NoNewline "`rWaiting: $seconds seconds" -ForegroundColor Yellow

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
                Microsoft.PowerShell.Utility\Write-Host

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
            }
            finally {
                if (!$fileExists) {
                    A-Exit
                }
            }
        }
        catch {
            error $_.Exception.Message
            A-Exit
        }
    }
    else {
        error "'$path' not found."
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

    $installerInfo = Get-Content "$dir\scoop-install-A-Install-Exe.jsonc" -Raw | ConvertFrom-Json

    if ($installerInfo.InstallerType -eq "inno") {
        if (!$PSBoundParameters.ContainsKey('ArgumentList')) {
            $ArgumentList = @('/VerySilent')
        }
    }
    # elseif () {

    # }
    else {
        # 如果没有传递卸载参数，则使用默认参数
        if (!$PSBoundParameters.ContainsKey('ArgumentList')) {
            $ArgumentList = @('/S')
        }
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

    if ($path) {
        $fileName = Split-Path $path -Leaf
    }

    if (Test-Path $path) {

        Write-Host "Running the uninstaller: $fileName"
        if ($NoSilent) {
            warn "The uninstaller may require some manual operations."
        }
        warn "It will be aborted if times out: $Timeout seconds"

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
                error $_.Exception.Message

                $process | Stop-Process -Force -ErrorAction SilentlyContinue

                A-Exit
            }

            $fileExists = Test-Path $FailureFile
            $seconds = 1
            try {
                while ((New-TimeSpan -Start $startTime -End (Get-Date)).TotalSeconds -lt $Timeout) {
                    Write-Host -NoNewline "`rWaiting: $seconds seconds" -ForegroundColor Yellow

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
                Microsoft.PowerShell.Utility\Write-Host
            }
            finally {
                if ($fileExists) {
                    A-Exit
                }
            }
        }
        catch {
            error $_.Exception.Message
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
        $path = if ($fname -is [array]) { "$dir\$($fname[0])" }else { "$dir\$fname" }
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
        Microsoft.PowerShell.Utility\Write-Host
        error "For Windows version before Windows 10 Version 1809 (OS Build 17763), Font can only be installed for all users.`nPlease use following commands to install '$app' Font for all users."
        Microsoft.PowerShell.Utility\Write-Host
        Microsoft.PowerShell.Utility\Write-Host "        scoop install sudo"
        Microsoft.PowerShell.Utility\Write-Host "        sudo scoop install -g $app"
        Microsoft.PowerShell.Utility\Write-Host
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
                error "Cannot uninstall '$app' font.`nIt is currently being used by another application.`nPlease close all applications that are using it (e.g. vscode) and try again."
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
        warn "The '$app' Font family has been uninstalled successfully, but there may be system cache that needs to be restarted to fully remove."
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
            Write-Host "Removing $PluginPath"
            Remove-Item -Path $PluginPath -Recurse -Force -ErrorAction Stop
        }
        $CopyingPath = if (Test-Path -Path "$dir\$PluginName") { "$dir\$PluginName" } else { $dir }
        A-Ensure-Directory (Split-Path $PluginPath -Parent)
        Write-Host "Copying $CopyingPath => $PluginPath"
        Copy-Item -Path $CopyingPath -Destination $PluginPath -Recurse -Force

        @{ "PluginName" = $PluginName } | ConvertTo-Json | Out-File -FilePath $OutFile -Force -Encoding utf8
    }
    catch {
        error $_.Exception.Message
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
            Write-Host "Removing $PluginPath"
            Remove-Item -Path $PluginPath -Recurse -Force -ErrorAction Stop
        }
    }
    catch {
        error $_.Exception.Message
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

function A-Deny-Manifest {
    <#
    .SYNOPSIS
        拒绝清单文件，提示用户使用新的清单文件
    #>
    param(
        [string]$NewManifestName
    )
    $msg = "'$app' is deprecated"

    $msg += if ($NewManifestName) { ", please use '$NewManifestName' instead." }else { "." }

    error $msg

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

    if (Test-Path $persist_dir) {
        return
    }

    $dir = Split-Path $persist_dir -Parent

    foreach ($oldName in $OldNames) {
        $old = "$dir\$oldName"

        if (Test-Path $old) {
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

    error "Cannot find product code of '$app'"

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
        Write-Host "::warn::访问 $url 失败" -ForegroundColor Yellow
        Write-Host

        $url = "https://github.com/microsoft/winget-pkgs/tree/master/manifests/$rootDir/$PackagePath"
        try {
            $page = Invoke-WebRequest $url -UseBasicParsing -ErrorAction Stop
        }
        catch {
            Write-Host "::warn::访问 $url 失败" -ForegroundColor Yellow
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
            if ((Test-Path $linkPath) -and !(Get-Item $linkPath -ErrorAction SilentlyContinue).LinkType) {
                if (!(Test-Path $linkTarget)) {
                    A-Ensure-Directory (Split-Path $linkTarget -Parent)
                    Write-Host "Copying $linkPath => $linkTarget"
                    try {
                        Copy-Item -Path $linkPath -Destination $linkTarget -Recurse -Force -ErrorAction Stop
                    }
                    catch {
                        Remove-Item $linkTarget -Recurse -Force -ErrorAction SilentlyContinue
                        error $_.Exception.Message
                        A-Exit
                    }
                }
                try {
                    Write-Host "Removing $linkPath"
                    Remove-Item $linkPath -Recurse -Force -ErrorAction Stop
                }
                catch {
                    error $_.Exception.Message
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
        error $_.Exception.Message
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

    if (Test-Path $OutFile) {
        $PackageFamilyName = (Get-Content $OutFile -Raw | ConvertFrom-Json | Select-Object -ExpandProperty "package").PackageFamilyName
        Get-AppxPackage | Where-Object { $_.PackageFamilyName -eq $PackageFamilyName } | Select-Object -First 1 | Remove-AppxPackage
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
    if ($shortcutsActionLevel -eq '2' -and (A-Test-ScriptPattern $manifest '.*A-Install-Exe.*')) {
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
