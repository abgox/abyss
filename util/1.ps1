#Requires -Version 5.1

Set-StrictMode -Off

# 存储 abyss 相关的变量
$abgox_abyss = @{
    path = @{
        LinkFile           = "$dir\abgox-abyss-A-New-LinkFile.json"
        LinkDirectory      = "$dir\abgox-abyss-A-New-LinkDirectory.json"
        InstallApp         = "$dir\abgox-abyss-A-Install-App.json"
        InstallInno        = "$dir\abgox-abyss-A-Install-Inno.json"
        InstallBurn        = "$dir\abgox-abyss-A-Install-Burn.json"
        InstallMsi         = "$dir\abgox-abyss-A-Install-Msi.json"
        Font               = "$dir\abgox-abyss-A-Install-Font.json"
        PowerToysRunPlugin = "$dir\abgox-abyss-A-Install-PowerToysRunPlugin.json"
        EnvPath            = "$dir\abgox-abyss-A-Add-Path.json"
        Info               = "$dir\abgox-abyss-Info.json"
    }
}

if ($PSEdition -eq 'Desktop') {
    $abgox_abyss.requestTimeout = @{
        TimeoutSec = 60
    }
}
else {
    $abgox_abyss.requestTimeout = @{
        ConnectionTimeoutSeconds = 30
        OperationTimeoutSeconds  = 60
    }
}

if ($env:GITHUB_ACTIONS) {
    $VerbosePreference = 'SilentlyContinue'
}
else {
    Microsoft.PowerShell.Utility\Write-Host
}

if ($scoopdir -and $scoopConfig.root_path -and $scoopdir -ne $scoopConfig.root_path) {
    scoop config 'root_path' $scoopdir
}

# https://abyss.abgox.com/features/extra-features#abgox-abyss-bucket-name
if ($bucket) {
    if ($scoopConfig.'abgox-abyss-bucket-name' -ne $bucket) {
        scoop config 'abgox-abyss-bucket-name' $bucket
    }
    if ($bucket -ne 'abyss') {
        error "You should use 'abyss' as the bucket name, but the current name is '$bucket'."
        error 'Refer to: https://abyss.abgox.com/faq/bucket-name'
    }
}

# https://abyss.abgox.com/features/extra-features#abgox-abyss-app-uninstall-action
$_ = $scoopConfig.'abgox-abyss-app-uninstall-action'
$abgox_abyss.uninstallActionLevel = if ($_) { $_ }else { '123' }

function A-Test-Admin {
    <#
    .SYNOPSIS
        检查当前用户是否具有管理员权限
    #>
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $admin = [Security.Principal.WindowsBuiltInRole]::Administrator
    [Security.Principal.WindowsPrincipal]::new($identity).IsInRole($admin)
}

function A-Test-DeveloperMode {
    <#
    .SYNOPSIS
        检查开发者模式是否启用

    .LINK
        https://learn.microsoft.com/windows/apps/get-started/developer-mode-features-and-debugging
    #>
    $path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
    try {
        $value = Get-ItemProperty -LiteralPath $path -Name 'AllowDevelopmentWithoutDevLicense' -ErrorAction Stop
        return $value.AllowDevelopmentWithoutDevLicense -eq 1
    }
    catch {
        return $false
    }
}

$abgox_abyss.isAdmin = A-Test-Admin
$abgox_abyss.isDevMode = A-Test-DeveloperMode

function A-Start-Install {
    # https://abyss.abgox.com/features/manifest-status-control
    if ($manifest.version -in 'pending', 'renamed', 'deprecated') {
        A-Deny-Manifest
    }
    # https://abyss.abgox.com/faq/require-admin
    if ($manifest.admin) {
        A-Require-Admin
    }
    # https://abyss.abgox.com/faq/deny-if-app-conflict
    if ($manifest.conflicts) {
        A-Deny-IfAppConflict $manifest.conflicts
    }
    if ($manifest.renamed) {
        A-Deny-IfAppConflict $manifest.renamed.old
        A-Move-Persistence
    }
    # https://abyss.abgox.com/features/data-persistence/persist
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
            if (Test-Path $from) {
                A-Copy-Item $from $to
            }
            $from = "$bucketsdir\$bucket\extra\$app\$target"
            if (Test-Path $from) {
                A-Copy-Item $from $to
            }
            $standardPath = $target -match 'AppData\\(Roaming|Local)\\.*'
            if ($standardPath) {
                $from = Join-Path $home $target
                $exists = Test-Path $from -PathType Container
                $isLink = A-Test-Link $from
                if ($exists -and -not $isLink) {
                    A-Copy-Item $from $to
                }
            }
        }
    }
    if ($manifest.env_set) {
        $manifest.env_set.PSObject.Properties | ForEach-Object {
            [System.Environment]::SetEnvironmentVariable($_.Name, $ExecutionContext.InvokeCommand.ExpandString($_.Value), [System.EnvironmentVariableTarget]::Process)
        }
    }
    if ($manifest.env_set_shared) {
        A-Set-EnvVarShared
    }
    if ($manifest.env_add_path_expand) {
        A-Add-Path $manifest.env_add_path_expand
    }
    # https://abyss.abgox.com/features/data-persistence/link
    if ($manifest.link) {
        foreach ($item in $manifest.link) {
            $expandPath = $ExecutionContext.InvokeCommand.ExpandString($item)
            if (Test-Path $expandPath) {
                if ($expandPath -like "$dir\*") {
                    $to = $expandPath.Replace("$dir\app\", "$persist_dir\").Replace("$dir\", "$persist_dir\")
                }
                else {
                    $to = $expandPath.Replace("$home\", "$persist_dir\")
                }
                A-Copy-Item $expandPath $to
            }
            else {
                if ($expandPath -like "$dir\*") {
                    $leaf = $expandPath.Replace("$dir\app\", '').Replace("$dir\", '')
                }
                else {
                    $leaf = $expandPath.Replace("$home\", '')
                }
                $extraPath = "$bucketsdir\$bucket\extra\$app\$leaf"
                if (Test-Path $extraPath) {
                    A-Copy-Item $extraPath "$persist_dir\$leaf"
                }
            }
        }
        if (-not ($manifest.pre_install -match '^\s*A-New-Link$')) {
            A-New-Link
        }
    }
    if ($manifest.msix -and -not ($manifest.pre_install -match '^\s*A-Install-MsixPackage$')) {
        A-Install-MsixPackage
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
        $location = $ExecutionContext.InvokeCommand.ExpandString($manifest.location)
        if (-not (Test-Path $location)) {
            A-Show-IssueCreationPrompt
            A-Exit
        }

        $info.location = $location

        $note = if ($PSUICulture -like 'zh*') {
            @(
                "安装目录: $($manifest.location)",
                '参考: https://abyss.abgox.com/faq/external-installation-directory'
            )
        }
        else {
            @(
                "The installation directory: $($manifest.location)",
                'Refer to: https://abyss.abgox.com/faq/external-installation-directory'
            )
        }
        A-Show-Notes $note
    }

    if ($info.Count) {
        $info | ConvertTo-Json | Out-File -FilePath $abgox_abyss.path.Info -Force -Encoding utf8
    }
}

function A-Start-Uninstall {
    # https://abyss.abgox.com/features/manifest-status-control
    if ($version -in 'pending', 'deprecated') {
        A-Deny-Update
    }
    if ($version -eq 'renamed') {
        $new = $manifest.renamed.new
        if (-not $new) {
            try {
                $new = Get-Content "$bucketsdir\$bucket\bucket\$($app[0])\$($app.Split('.', 2)[0])\$app.json" -Raw -Encoding utf8 -ErrorAction Stop | ConvertFrom-Json | Select-Object -ExpandProperty renamed | Select-Object -ExpandProperty new
            }
            catch {
                error $_.Exception.Message
                A-Exit
            }
        }
        if ($cmd -eq 'update') {
            error "'$app' is renamed to '$new'."
            error 'Refer to: https://abyss.abgox.com/faq/deny-manifest'
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
    if ($manifest.msix -and -not ($manifest.pre_uninstall -match '^\s*A-Uninstall-MsixPackage$')) {
        A-Uninstall-MsixPackage
    }
    A-Remove-Path
    A-Uninstall-Font
    A-Uninstall-PowerToysRunPlugin
}

function A-Complete-Uninstall {
    $tempPath = @()
    if ($manifest.location) {
        $tempPath += $ExecutionContext.InvokeCommand.ExpandString($manifest.location)
    }
    foreach ($c in $manifest.cleanup) {
        $tempPath += $ExecutionContext.InvokeCommand.ExpandString($c)
    }
    A-Remove-TempData $tempPath

    # 由于字段可能包含可展开的环境变量，应该使用安装时储存的值而不是通过字段展开，以避免环境变量变化导致的不一致性
    $abgox_abyss.path.LinkFile, $abgox_abyss.path.LinkDirectory | ForEach-Object {
        if (Test-Path -LiteralPath $_) {
            $LinkPaths = Get-Content $_ -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json | Select-Object -ExpandProperty LinkPaths
            foreach ($p in $LinkPaths) {
                A-Remove-ToRecycleBin $p
            }
        }
    }
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

function A-New-File {
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
        A-New-File "$persist_dir\data.json" -Content "{}"
        创建文件并指定内容

    .EXAMPLE
        A-New-File "$persist_dir\data.ini" -Content '[Settings]', 'AutoUpdate=0'
        创建文件并指定内容，传入数组会被写入多行

    .EXAMPLE
        A-New-File "$persist_dir\data.ini"
        创建空文件
    #>
    param (
        [string]$Path,
        [array]$Content,
        [ValidateSet('utf8', 'utf8Bom', 'utf8NoBom', 'unicode', 'ansi', 'ascii', 'bigendianunicode', 'bigendianutf32', 'oem', 'utf7', 'utf32')]
        [string]$Encoding = 'utf8'
    )

    if (Test-Path -LiteralPath $Path) {
        $item = Get-Item -LiteralPath $Path
        # 如果是一个目录，就删除它
        if ($item.PSIsContainer) {
            try {
                A-Remove-ToRecycleBin $Path -ErrorAction Stop
            }
            catch {
                error $_.Exception.Message
                A-Show-IssueCreationPrompt
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

function A-New-Link {
    $filePaths = @()
    $dirPaths = @()
    foreach ($item in $manifest.link) {
        if (-not $item) {
            continue
        }
        $expandPath = $ExecutionContext.InvokeCommand.ExpandString($item)
        if (Test-Path $expandPath) {
            if (Test-Path $expandPath -PathType Leaf) {
                $filePaths += $expandPath
            }
            else {
                $dirPaths += $expandPath
            }
        }
        else {
            if ($expandPath -like "$dir\*") {
                $leaf = $expandPath.Replace("$dir\app\", '').Replace("$dir\", '')
            }
            else {
                $leaf = $expandPath.Replace("$home\", '')
            }
            $extraPath = "$bucketsdir\$bucket\extra\$app\$leaf"
            if (Test-Path $extraPath -PathType Leaf) {
                $filePaths += $expandPath
            }
            else {
                $dirPaths += $expandPath
            }
        }
    }
    if ($filePaths) {
        A-New-LinkFile -LinkPaths $filePaths
    }
    if ($dirPaths) {
        A-New-LinkDirectory -LinkPaths $dirPaths
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
        通常忽略它，让它根据 LinkPaths 自动生成

    .EXAMPLE
        A-New-LinkFile "$home\xxx", "$env:AppData\xxx"

    .LINK
        https://abyss.abgox.com/features/data-persistence/link
    #>
    param (
        [array]$LinkPaths,
        [array]$LinkTargets = @()
    )

    if (!$abgox_abyss.isAdmin) {
        if ($PSEdition -eq 'Desktop') {
            # Windows PowerShell 5.1 需要管理员权限才能创建 SymbolicLink
            A-Require-Admin
        }
        if (!$abgox_abyss.isDevMode) {
            error "$app requires admin permission or developer mode to create SymbolicLink."
            error 'Refer to: https://abyss.abgox.com/faq/require-admin-or-dev-mode'
            A-Exit
        }
    }

    A-New-LinkBase -LinkPaths $LinkPaths -LinkTargets $LinkTargets -ItemType SymbolicLink -OutFile $abgox_abyss.path.LinkFile
}

function A-New-LinkDirectory {
    <#
    .SYNOPSIS
        为目录创建 Junction

    .PARAMETER LinkPaths
        要创建链接的路径数组 (将被替换为链接)

    .PARAMETER LinkTargets
        链接指向的目标路径数组 (链接指向的位置)
        通常忽略它，让它根据 LinkPaths 自动生成

    .EXAMPLE
        A-New-LinkDirectory "$env:AppData\Code", "$home\.vscode"

    .LINK
        https://abyss.abgox.com/features/data-persistence/link
    #>
    param (
        [array]$LinkPaths,
        [array]$LinkTargets = @()
    )

    A-New-LinkBase -LinkPaths $LinkPaths -LinkTargets $LinkTargets -ItemType Junction -OutFile $abgox_abyss.path.LinkDirectory
}

function A-Remove-Link {
    <#
    .SYNOPSIS
        删除链接: SymbolicLink、Junction

    .DESCRIPTION
        该函数用于删除在应用安装过程中创建的 SymbolicLink 和 Junction
        根据全局变量 $cmd 和 $abgox_abyss.uninstallActionLevel 的值决定是否执行删除操作。
    #>

    # $byMsix = $manifest.msix
    # $byApp = (Test-Path -LiteralPath $abgox_abyss.path.InstallApp) -or (Test-Path -LiteralPath $abgox_abyss.path.InstallInno)
    # $byMsi = Test-Path -LiteralPath $abgox_abyss.path.InstallMsi

    # if (-not ($byMsix -or $byApp -or $byMsi)) {
    #     # 它们在卸载时可能会删除所有数据文件，因此必须先删除链接目录以保留数据
    #     return
    # }

    # if (-not ($abgox_abyss.uninstallActionLevel.Contains('2') -or $purge)) {
    #     # 如果使用了 -p 或 --purge 参数，或者 uninstallActionLevel 包含 2，则需要执行删除操作
    #     return
    # }

    $abgox_abyss.path.LinkFile, $abgox_abyss.path.LinkDirectory | ForEach-Object {
        if (Test-Path -LiteralPath $_) {
            $LinkPaths = Get-Content $_ -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json | Select-Object -ExpandProperty LinkPaths

            foreach ($p in $LinkPaths) {
                if (A-Test-Link $p) {
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

function A-Stop-Process {
    <#
    .SYNOPSIS
        停止从指定目录运行的所有进程

    .DESCRIPTION
        该函数用于查找并终止从指定目录路径加载模块的所有进程。
        函数默认会搜索 $dir 和 $dir\current 目录。

    .PARAMETER Extra
        要搜索运行中可执行文件的额外目录路径(绝对路径)或进程名称。

    .NOTES
        Msix/Appx 在移除包时会自动终止进程，不需要手动终止，除非指定绝对路径
    #>
    param(
        [string[]]$Extra
    )

    $ExtraPaths = @()
    $ExtraProcessNames = @()
    foreach ($e in $Extra) {
        if ([System.IO.Path]::IsPathRooted($e)) {
            if (Test-Path -LiteralPath $e) {
                $ExtraPaths += $e
            }
        }
        else {
            $ExtraProcessNames += $e
        }
    }

    # Msix/Appx 在移除包时会自动终止进程，不需要手动终止，除非指定绝对路径
    if (-not $abgox_abyss.uninstallActionLevel.Contains('1') -or ($manifest.msix -and !$ExtraPaths)) {
        return
    }

    if ($manifest.location -or $version -eq 'virtual') {
        $Paths = @($ExecutionContext.InvokeCommand.ExpandString($manifest.location))
    }
    else {
        $Paths = @($dir, ((Split-Path $dir -Parent) + '\current'))
    }
    $Paths += $ExtraPaths

    # 由于字段可能包含可展开的变量，应该使用安装时展开的值，以避免安装和卸载期间环境变量变化导致的不一致性
    if (Test-Path -LiteralPath $abgox_abyss.path.EnvPath) {
        $general_path = "$home\.local\bin", "$env:AppData\local\bin", "$env:LocalAppData\bin", "$env:LocalAppData\Microsoft\WindowsApps"
        $Paths += Get-Content $abgox_abyss.path.EnvPath -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json | Select-Object -ExpandProperty Paths | Where-Object { $_ -notin $general_path }
    }
    if (Test-Path -LiteralPath $abgox_abyss.path.Info) {
        $info = Get-Content $abgox_abyss.path.Info -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
        if ($info.location) {
            $Paths += $info.location
        }
    }

    $Paths = $Paths | Sort-Object -Unique

    foreach ($app_dir in $Paths) {
        $matched = (Get-Process).Where({ $_.Path -like "$app_dir\*" })
        foreach ($p in $matched) {
            try {
                if (Get-Process -Id $p.Id -ErrorAction SilentlyContinue) {
                    Write-Host "Stopping the process: $($p.Id) $($p.Name) ($($p.Path))"
                    Stop-Process -Id $p.Id -Force -ErrorAction Stop
                }
            }
            catch {
                if ($_.FullyQualifiedErrorId -like 'NoProcessFoundForGivenId*') {
                    # 进程已经不存在，无需处理
                    continue
                }
                error $_.Exception.Message
                A-Show-IssueCreationPrompt
                A-Exit
            }
        }
    }

    foreach ($processName in $ExtraProcessNames) {
        $p = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if ($p) {
            try {
                Write-Host "Stopping the process: $($p.Id) $($p.Name) ($($p.Path))"
                Stop-Process -Id $p.Id -Force -ErrorAction Stop
            }
            catch {
                if ($_.FullyQualifiedErrorId -like 'NoProcessFoundForGivenId*') {
                    # 进程已经不存在，无需处理
                    continue
                }
                error $_.Exception.Message
                A-Show-IssueCreationPrompt
                A-Exit
            }
        }
    }

    Start-Sleep -Milliseconds 500

    # 再次检查是否存在未终止的相关进程
    # 这里参考了 Scoop 的官方检查逻辑，以确保一致性
    # https://github.com/ScoopInstaller/Scoop/blob/ebd8c036fa0d2e1dc93bca44c10eeee36c0d233e/lib/install.ps1#L534
    foreach ($app_dir in $Paths) {
        $running_processes = (Get-Process).Where({ $_.Path -like "$app_dir\*" }) | Out-String
        if ($running_processes) {
            error "The following instances of `"$app`" are still running. Close them and try again."
            Write-Host $running_processes
            A-Exit
        }
    }
}

function A-Stop-Service {
    param(
        [string]$ServiceName
    )

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
        A-Show-IssueCreationPrompt
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
            A-Show-IssueCreationPrompt
            A-Exit
        }
    }
}

function A-Install-App {
    param(
        [string]$Uninstaller, # 当指定它后，A-Uninstall-App 会默认使用它作为卸载程序路径
        [array]$ArgumentList,
        [string]$SleepSec = 3
    )

    # $fname 由 Scoop 提供，即下载的文件名
    $Installer = Join-Path $dir ($fname | Select-Object -First 1)

    if (!(Test-Path -LiteralPath $Installer)) {
        error "'$Installer' not found."
        A-Show-IssueCreationPrompt
        A-Exit
    }

    if (!$PSBoundParameters.ContainsKey('ArgumentList')) {
        $ArgumentList = @('/S')
        if (-not $manifest.admin) {
            $ArgumentList += '/CurrentUser'
        }
        if (-not $manifest.location) {
            $ArgumentList += "/D=$dir\app"
        }
    }

    $InstallerFileName = Split-Path $Installer -Leaf

    Write-Host "Running the installer: $InstallerFileName"

    try {
        $process = Start-Process $Installer -ArgumentList $ArgumentList -PassThru -WindowStyle Hidden
        $process | Wait-Process -ErrorAction Stop
    }
    catch {
        error $_.Exception.Message
        A-Show-IssueCreationPrompt
        $process | Stop-Process -Force -ErrorAction SilentlyContinue
        A-Exit
    }

    $Uninstaller = if ($manifest.location) {
        A-Get-AbsolutePath $Uninstaller $ExecutionContext.InvokeCommand.ExpandString($manifest.location)
    }
    else {
        A-Get-AbsolutePath $Uninstaller
    }

    @{
        Installer    = $Installer
        ArgumentList = $ArgumentList
        Uninstaller  = $Uninstaller
    } | ConvertTo-Json | Out-File -FilePath $abgox_abyss.path.InstallApp -Force -Encoding utf8

    Start-Sleep -Seconds $SleepSec

    if ($Uninstaller -and !(Test-Path -LiteralPath $Uninstaller)) {
        error "'$Uninstaller' not found."
        A-Show-IssueCreationPrompt
        A-Exit
    }

    try {
        if ($Installer) {
            Remove-Item $Installer -Force -ErrorAction Stop
        }
    }
    catch {
        error $_.Exception.Message
    }
}

function A-Uninstall-App {
    param(
        [string]$Uninstaller,
        [array]$ArgumentList = @('/S'),
        [string]$SleepSec = 3
    )

    $InstallerInfoPath = $abgox_abyss.path.InstallApp

    if (Test-Path -LiteralPath $InstallerInfoPath) {
        try {
            $InstallerInfo = Get-Content $InstallerInfoPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            error $_.Exception.Message
            return
        }
    }
    else {
        return
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
        $_Uninstaller = Get-ChildItem $dir $UninstallerFileName -Recurse | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($null -eq $_Uninstaller) {
            return
        }
        if (!(Test-Path -LiteralPath $_Uninstaller)) {
            warn "'$Uninstaller' not found."
            return
        }
        $Uninstaller = $_Uninstaller.FullName
    }

    Write-Host "Running the uninstaller: $UninstallerFileName"

    $paramList = @{
        FilePath     = $Uninstaller
        ArgumentList = $ArgumentList
        WindowStyle  = 'Hidden'
        PassThru     = $true
    }
    $process = Start-Process @paramList

    try {
        $process | Wait-Process -ErrorAction Stop
    }
    catch {
        error $_.Exception.Message
        A-Show-IssueCreationPrompt
        $process | Stop-Process -Force -ErrorAction SilentlyContinue
        A-Exit
    }

    Start-Sleep -Seconds $SleepSec
}

function A-Install-Inno {
    param(
        [string]$Uninstaller,
        [array]$ArgumentList
    )

    # $fname 由 Scoop 提供，即下载的文件名
    $Installer = Join-Path $dir ($fname | Select-Object -First 1)

    if (!(Test-Path -LiteralPath $Installer)) {
        error "'$Installer' not found."
        A-Show-IssueCreationPrompt
        A-Exit
    }

    $logPath = "$env:TEMP\scoop_$($app)_$($version)_install_inno.log"

    if (!$PSBoundParameters.ContainsKey('ArgumentList')) {
        $ArgumentList = @(
            '/CurrentUser',
            '/VerySilent',
            '/SuppressMsgBoxes',
            '/NoRestart',
            '/SP-',
            "/Log=$logPath",
            "/Dir=`"$dir\app`""
        )
    }
    $InstallerFileName = Split-Path $Installer -Leaf

    Write-Host "Running the installer: $InstallerFileName"

    try {
        $process = Start-Process $Installer -ArgumentList $ArgumentList -PassThru
        $process | Wait-Process -ErrorAction Stop
    }
    catch {
        error $_.Exception.Message
        A-Show-IssueCreationPrompt
        $process | Stop-Process -Force -ErrorAction SilentlyContinue
        A-Exit
    }

    if ($PSBoundParameters.ContainsKey('Uninstaller')) {
        $Uninstaller = A-Get-AbsolutePath $Uninstaller
    }
    else {
        $Uninstaller = "$dir\app\unins000.exe", "$dir\app\uninstall\unins000.exe" | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    }

    # $log = Get-Content $logPath -ErrorAction SilentlyContinue

    @{
        Installer    = $Installer
        ArgumentList = $ArgumentList
        Uninstaller  = $Uninstaller
    } | ConvertTo-Json | Out-File -FilePath $abgox_abyss.path.InstallInno -Force -Encoding utf8

    if ($Uninstaller -and !(Test-Path -LiteralPath $Uninstaller)) {
        error "'$Uninstaller' not found."
        A-Show-IssueCreationPrompt
        A-Exit
    }

    try {
        if ($Installer) {
            Remove-Item $Installer -Force -ErrorAction Stop
        }
    }
    catch {
        error $_.Exception.Message
    }
}

function A-Uninstall-Inno {
    param(
        [array]$ArgumentList = @(
            '/VerySilent',
            '/SuppressMsgBoxes',
            '/NoRestart',
            '/Force'
        )
    )

    $Uninstaller = Get-ChildItem $dir unins000.exe -Recurse | Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if (!$Uninstaller) {
        warn "'unins000.exe' not found."
        return
    }

    Write-Host "Running the uninstaller: $($Uninstaller.Name)"

    $process = Start-Process -FilePath $Uninstaller -ArgumentList $ArgumentList -PassThru

    try {
        $process | Wait-Process -ErrorAction Stop
    }
    catch {
        error $_.Exception.Message
        A-Show-IssueCreationPrompt
        $process | Stop-Process -Force -ErrorAction SilentlyContinue
        A-Exit
    }
}

function A-Install-Burn {
    param(
        [array]$ArgumentList
    )

    # $fname 由 Scoop 提供，即下载的文件名
    $Installer = Join-Path $dir ($fname | Select-Object -First 1)

    if (!(Test-Path -LiteralPath $Installer)) {
        error "'$Installer' not found."
        A-Show-IssueCreationPrompt
        A-Exit
    }

    $logPath = "$env:TEMP\scoop_$($app)_$($version)_install_burn.log"

    if (!$PSBoundParameters.ContainsKey('ArgumentList')) {
        $ArgumentList = @('/quiet', '/norestart', '/log', $logPath)
    }

    $InstallerFileName = Split-Path $Installer -Leaf

    Write-Host "Running the installer: $InstallerFileName"

    try {
        $process = Start-Process $Installer -ArgumentList $ArgumentList -PassThru
        $process | Wait-Process -ErrorAction Stop
    }
    catch {
        error $_.Exception.Message
        A-Show-IssueCreationPrompt
        $process | Stop-Process -Force -ErrorAction SilentlyContinue
        A-Exit
    }

    $log = Get-Content $logPath -ErrorAction SilentlyContinue
    $guid = $log | Select-String 'WixBundleProviderKey = ([0-9A-Fa-f\-]{36})' | ForEach-Object { $_.Matches.Groups[1].Value } | Select-Object -First 1
    if (-not $guid) {
        $guid = $log | Select-String 'SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\\{([0-9A-Fa-f\-]{36})\}' | ForEach-Object { $_.Matches.Groups[1].Value } | Select-Object -First 1
    }
    $Uninstaller = Get-ChildItem "C:\ProgramData\Package Cache\{$guid}" -File -Filter *.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName

    if (-not $Uninstaller) {
        $Uninstaller = $Installer
    }

    @{
        Installer    = $Installer
        ArgumentList = $ArgumentList
        Uninstaller  = $Uninstaller
    } | ConvertTo-Json | Out-File -FilePath $abgox_abyss.path.InstallBurn -Force -Encoding utf8

    if ($Uninstaller -and !(Test-Path -LiteralPath $Uninstaller)) {
        error "'$Uninstaller' not found."
        A-Show-IssueCreationPrompt
        A-Exit
    }
}

function A-Uninstall-Burn {
    param(
        [array]$ArgumentList = @('/uninstall', '/quiet')
    )

    $InstallerInfoPath = $abgox_abyss.path.InstallBurn

    if (Test-Path -LiteralPath $InstallerInfoPath) {
        try {
            $InstallerInfo = Get-Content $InstallerInfoPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            error $_.Exception.Message
            return
        }
    }
    else {
        return
    }

    $Uninstaller = $InstallerInfo.Uninstaller
    $UninstallerName = Split-Path $Uninstaller -Leaf

    if (-not $Uninstaller) {
        warn "'$UninstallerName' not found."
        return
    }

    Write-Host "Running the uninstaller: $UninstallerName"

    $process = Start-Process -FilePath $Uninstaller -ArgumentList $ArgumentList -PassThru

    try {
        $process | Wait-Process -ErrorAction Stop
    }
    catch {
        error $_.Exception.Message
        A-Show-IssueCreationPrompt
        $process | Stop-Process -Force -ErrorAction SilentlyContinue
        A-Exit
    }
}

function A-Install-Msi {
    param(
        [array]$ArgumentList
    )

    $Installer = if ([Environment]::Is64BitOperatingSystem) {
        'C:\Windows\SysWOW64\msiexec.exe'
    }
    else {
        'C:\Windows\System32\msiexec.exe'
    }

    if (!(Test-Path -LiteralPath $Installer)) {
        error "'$Installer' not found."
        A-Show-IssueCreationPrompt
        A-Exit
    }

    $logPath = "$env:TEMP\scoop_$($app)_$($version)_install_msi.log"

    if (!$PSBoundParameters.ContainsKey('ArgumentList')) {
        $msiFile = Join-Path $dir ($fname | Select-Object -First 1)
        $ArgumentList = @(
            '/i',
            "`"$msiFile`"",
            # '/passive',
            '/quiet',
            '/norestart',
            '/lvx*',
            $logPath
        )
    }

    $InstallerFileName = Split-Path $Installer -Leaf

    Write-Host "Running the installer: $InstallerFileName"

    try {
        $process = Start-Process $Installer -ArgumentList $ArgumentList -PassThru
        $process | Wait-Process -ErrorAction Stop
    }
    catch {
        error $_.Exception.Message
        A-Show-IssueCreationPrompt
        $process | Stop-Process -Force -ErrorAction SilentlyContinue
        A-Exit
    }

    try {
        if ($msiFile) {
            Remove-Item $msiFile -Force -ErrorAction Stop
        }
    }
    catch {
        error $_.Exception.Message
    }

    $log = Get-Content $logPath -ErrorAction SilentlyContinue

    @{
        Installer      = $Installer
        Uninstaller    = $Installer
        ProductCode    = $log | Select-String 'ProductCode = (.+)' | ForEach-Object { $_.Matches.Groups[1].Value } | Select-Object -First 1
        ProductName    = $log | Select-String 'ProductName = (.+)' | ForEach-Object { $_.Matches.Groups[1].Value } | Select-Object -First 1
        ProductVersion = $log | Select-String 'ProductVersion = (.+)' | ForEach-Object { $_.Matches.Groups[1].Value } | Select-Object -First 1
        Manufacturer   = $log | Select-String 'Manufacturer = (.+)' | ForEach-Object { $_.Matches.Groups[1].Value } | Select-Object -First 1
        ArgumentList   = $ArgumentList
    } | ConvertTo-Json | Out-File -FilePath $abgox_abyss.path.InstallMsi -Force -Encoding utf8
}

function A-Uninstall-Msi {
    param(
        [array]$ArgumentList
    )

    # msi 直接覆盖安装，无需卸载
    if ($cmd -eq 'update') { return }

    $InstallerInfoPath = $abgox_abyss.path.InstallMsi

    if (Test-Path -LiteralPath $InstallerInfoPath) {
        try {
            $InstallerInfo = Get-Content $InstallerInfoPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            error $_.Exception.Message
            return
        }
    }
    else {
        return
    }

    $Uninstaller = $InstallerInfo.Uninstaller

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

    $ProductCode = $null
    $registryPaths = @(
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    :outerLoop foreach ($path in $registryPaths) {
        $uninstallKeys = Get-ChildItem $path -ErrorAction SilentlyContinue
        foreach ($key in $uninstallKeys) {
            $item = Get-ItemProperty $key.PSPath

            if ($item.ProductCode -eq $InstallerInfo.ProductCode) {
                $ProductCode = $item.ProductCode
                break outerLoop
            }

            if ($item.DisplayName -eq $InstallerInfo.ProductName) {
                $ProductCode = $key.PSChildName  # 使用子项 GUID 作为 ProductCode
                break outerLoop
            }

            if ($item.UninstallString -and $item.UninstallString -match [regex]::Escape($InstallerInfo.ProductCode)) {
                $ProductCode = $InstallerInfo.ProductCode
                break outerLoop
            }
        }
    }

    if (!$ProductCode) {
        error "Cannot find product code of '$app'"
        return
    }

    Write-Host "Running the uninstaller: $UninstallerFileName /X$ProductCode"

    if (!$PSBoundParameters.ContainsKey('ArgumentList')) {
        $ArgumentList = @(
            '/x',
            "$ProductCode",
            '/quiet',
            '/norestart'
        )
    }

    $process = Start-Process -FilePath $Uninstaller -ArgumentList $ArgumentList -PassThru

    try {
        $process | Wait-Process -ErrorAction Stop
    }
    catch {
        error $_.Exception.Message
        A-Show-IssueCreationPrompt
        $process | Stop-Process -Force -ErrorAction SilentlyContinue
        A-Exit
    }
}

function A-Uninstall-Manually {
    param(
        [array]$Paths
    )
    if ($manifest.location) {
        $Paths += $ExecutionContext.InvokeCommand.ExpandString($manifest.location)
    }

    foreach ($p in $Paths) {
        $p = A-Get-AbsolutePath $p
        if (Test-Path -LiteralPath $p) {
            if (-not (Get-ChildItem -LiteralPath $p -File -Recurse | Select-Object -First 1)) {
                try {
                    Remove-Item $p -Force -Recurse -ErrorAction Stop
                    continue
                }
                catch {}
            }
            error 'It requires you to uninstall it manually.'
            error $p
            error 'Refer to: https://abyss.abgox.com/faq/uninstall-manually'
            A-Exit
        }
    }
}

function A-Install-MsixPackage {
    <#
    .SYNOPSIS
        安装 AppX/Msix 包
    #>
    param(
        # 包名，例如：Microsoft.PowerShellPreview_8wekyb3d8bbwe
        [string]$PackageFamilyName = $manifest.msix
    )
    # $fname 由 Scoop 提供，即下载的文件名
    $path = Join-Path $dir ($fname | Select-Object -First 1)
    A-Add-AppxPackage -PackageFamilyName $PackageFamilyName -Path $path
}

function A-Uninstall-MsixPackage {
    param(
        [string]$PackageFamilyName = $manifest.msix
    )
    A-Remove-AppxPackage -PackageFamilyName $PackageFamilyName
}

function A-Install-PowerToysRunPlugin {
    param(
        [string]$PluginName
    )

    $PluginsDir = "$env:LocalAppData\Microsoft\PowerToys\PowerToys Run\Plugins"
    $PluginPath = "$PluginsDir\$PluginName"

    try {
        if (Test-Path -LiteralPath $PluginPath) {
            Write-Host "Removing $PluginPath"
            A-Remove-ToRecycleBin $PluginPath -ErrorAction Stop
        }
        $CopyingPath = if (Test-Path -LiteralPath "$dir\$PluginName") { "$dir\$PluginName" } else { $dir }
        A-Ensure-Directory (Split-Path $PluginPath -Parent)
        Write-Host "Copying $CopyingPath => $PluginPath"
        A-Copy-Item $CopyingPath $PluginPath

        @{ PluginName = $PluginName } | ConvertTo-Json | Out-File -FilePath $abgox_abyss.path.PowerToysRunPlugin -Force -Encoding utf8
    }
    catch {
        error $_.Exception.Message
        A-Show-IssueCreationPrompt
        A-Exit
    }
}

function A-Expand-SetupExe {
    $archMap = @{
        '64bit' = '64'
        '32bit' = '32'
        'arm64' = 'arm64'
    }

    $all7z = Get-ChildItem "$dir\`$PLUGINSDIR" -Filter 'app*.7z'
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

    if (!$abgox_abyss.isAdmin) {
        error 'It requires admin permission. Please try again with admin permission.'
        error 'Refer to: https://abyss.abgox.com/faq/require-admin'
        A-Exit
    }
}

function A-Deny-Update {
    <#
    .SYNOPSIS
        禁止通过 scoop 更新
    #>
    if ($cmd -eq 'update') {
        error "'$app' does not allow update by Scoop."
        error 'Refer to: https://abyss.abgox.com/faq/deny-update'
        A-Show-Notes
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

        while ($true) {
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

function A-Get-UninstallEntryByAppName {
    param (
        [string]$AppNamePattern
    )

    # 搜索注册表位置
    $registryPaths = @(
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
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

function A-Get-VersionFromGithub {
    param (
        [switch]$Latest,
        [switch]$PreRelease,
        [switch]$Newest
    )
    if (-not $json) {
        Write-Host "::error::`$json is invalid." -ForegroundColor Red
        return
    }
    if (-not $json.checkver.regex) {
        Write-Error "${app}: Requires 'checkver.regex'."
        return
    }
    if ($json.version -in 'pending', 'renamed', 'deprecated', 'virtual') {
        return A-New-MatchedString -RegexPattern $json.checkver.regex -TargetValue $json.version
    }

    $arch = $json.autoupdate.architecture
    $url = $json.checkver.url, $arch.'64bit'.url, $arch.arm64.url, $arch.'32bit'.url, $json.autoupdate.url | Select-Object -First 1

    if ($url -is [array]) {
        $url = $url | Where-Object { $_ -like 'https://github.com/*/*' } | Select-Object -First 1
    }
    if (-not $url) {
        Write-Host "::error::`$url is invalid." -ForegroundColor Red
        return
    }
    if ($url -notlike 'https://github.com/*/*') {
        Write-Host "::error::'$url' is not a github url." -ForegroundColor Red
        return
    }

    $headers = @{
        'User-Agent'           = A-Get-UserAgent
        'X-GitHub-Api-Version' = '2022-11-28'
    }

    if ($env:GITHUB_ACTIONS) {
        $token = A-Get-GithubToken
        if (-not $token) {
            return
        }
        $headers['Authorization'] = "Bearer $token"
    }
    else {
        $token = $scoopConfig.gh_token
        if ($token) {
            $headers['Authorization'] = "Bearer $token"
        }
    }

    $url = $url -replace '^https://github.com/([^/]+)/([^/]+)(/.*)?', 'https://api.github.com/repos/$1/$2/releases'

    if ($Latest) {
        $url += '/latest'
    }

    try {
        $requestTimeout = $abgox_abyss.requestTimeout
        $res = Invoke-RestMethod -Uri $url -Headers $headers @requestTimeout
        if ($Latest) {
            return $res.tag_name -replace '[vV](?=\d+\.)', ''
        }
        elseif ($Newest) {
            $releaseInfo = $res
        }
        elseif ($PreRelease) {
            $releaseInfo = $res | Where-Object { $_.prerelease }
        }
        else {
            $releaseInfo = $res | Where-Object { -not $_.prerelease }
        }

        foreach ($item in $releaseInfo) {
            $v = $item.tag_name -replace '[vV](?=\d+\.)', ''
            if ($v -match $json.checkver.regex) {
                return $v
            }
        }
        return
    }
    catch {
        Write-Host "::warning::Failed to access '$url': $($_.Exception.Message)" -ForegroundColor Yellow

        if (-not $env:GITHUB_ACTIONS) {
            return
        }

        if ($_.Exception.Message -like '*rate limit*') {

            $token = A-Get-GithubToken -Next
            if (-not $token) {
                return
            }
            $headers['Authorization'] = "Bearer $token"

            Start-Sleep -Seconds 10

            $requestTimeout = $abgox_abyss.requestTimeout
            $res = Invoke-RestMethod -Uri $url -Headers $headers @requestTimeout
            if ($Latest) {
                return $res.tag_name -replace '[vV](?=\d+\.)', ''
            }
            elseif ($Newest) {
                $releaseInfo = $res
            }
            elseif ($PreRelease) {
                $releaseInfo = $res | Where-Object { $_.prerelease }
            }
            else {
                $releaseInfo = $res | Where-Object { -not $_.prerelease }
            }

            foreach ($item in $releaseInfo) {
                $v = $item.tag_name -replace '[vV](?=\d+\.)', ''
                if ($v -match $json.checkver.regex) {
                    return $v
                }
            }
            return
        }
    }
}

function A-Get-LatestVersionFromGithub {
    A-Get-VersionFromGithub -Latest
}

function A-Get-PreVersionFromGithub {
    A-Get-VersionFromGithub -PreRelease
}

function A-Get-NewestVersionFromGithub {
    A-Get-VersionFromGithub -Newest
}

function A-Get-VersionFromPowerShellGallery {
    if (-not $json) {
        Write-Host "::error::`$json is invalid." -ForegroundColor Red
        return
    }
    if (-not $json.checkver.regex) {
        Write-Error "${app}: Requires 'checkver.regex'."
        return
    }
    if ($json.version -in 'pending', 'renamed', 'deprecated', 'virtual') {
        return A-New-MatchedString -RegexPattern $json.checkver.regex -TargetValue $json.version
    }

    $module_name = $json.psmodule.name

    if (-not $module_name) {
        Write-Host "::error::`$json.psmodule.name is invalid." -ForegroundColor Red
        return
    }

    $requestTimeout = $abgox_abyss.requestTimeout
    Invoke-RestMethod "https://www.powershellgallery.com/packages/$($module_name.ToLower())" @requestTimeout |
    Select-String -Pattern '<h2>([\d.]+)</h2>' |
    ForEach-Object { $_.Matches.Groups[1].Value } |
    Select-Object -First 1
}

function A-Get-DynamicPageFromUrl {
    if (-not $json) {
        Write-Host "::error::`$json is invalid." -ForegroundColor Red
        return
    }
    if (-not $json.checkver.url) {
        Write-Error "${app}: Requires 'checkver.url'."
        return
    }
    if (-not $json.checkver.regex) {
        Write-Error "${app}: Requires 'checkver.regex'."
        return
    }
    if ($json.version -in 'pending', 'renamed', 'deprecated', 'virtual') {
        return $json.version
    }

    $edgePath = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
    if (-not (Test-Path $edgePath)) {
        $edgePath = 'msedge.exe'
    }

    try {
        $args = @('--headless=new', '--disable-gpu', '--dump-dom', '--no-sandbox', '--virtual-time-budget=10000', $json.checkver.url)

        $html = & $edgePath $args 2>$null | Out-String

        if ([string]::IsNullOrWhiteSpace($html)) {
            Write-Error "Failed to retrieve content from $($json.checkver.url)"
            return
        }
        $html
    }
    catch {
        Write-Error "Edge execution failed: $($_.Exception.Message)"
        return
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
        [string]$PackageIdentifier,
        [string]$InstallerType,
        [string]$MaxExclusiveVersion
    )

    if ($json.version -in 'pending', 'renamed', 'deprecated', 'virtual') {
        $out = @("ver:$($json.version);")
        return $installerInfo, $out
    }

    if (-not (Get-Command 'ConvertFrom-Yaml' -ErrorAction SilentlyContinue)) {
        error 'Please install yaml module: scoop install abyss/cloudbase.powershell-yaml'
        return
    }

    $tempFile = "$PSScriptRoot\..\temp-autoupdate.json"
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

    $headers = @{
        'User-Agent'           = A-Get-UserAgent
        'X-GitHub-Api-Version' = '2022-11-28'
    }

    if ($env:GITHUB_ACTIONS) {
        $token = A-Get-GithubToken
        if (-not $token) {
            return
        }
        $headers['Authorization'] = "Bearer $token"
    }
    else {
        $token = $scoopConfig.gh_token
        if ($token) {
            $headers['Authorization'] = "Bearer $token"
        }
    }

    $rootDir = $PackageIdentifier.ToLower()[0]
    $PackagePath = $PackageIdentifier -replace '\.', '/'

    $url = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/$rootDir/$PackagePath"

    try {
        $requestTimeout = $abgox_abyss.requestTimeout
        $versions = Invoke-RestMethod -Uri $url -Headers $headers @requestTimeout | ForEach-Object { if ($_.Name -notmatch '^\.') { $_.Name } }
    }
    catch {
        Write-Host "::warning::Failed to access '$url': $($_.Exception.Message)" -ForegroundColor Yellow

        if (-not $env:GITHUB_ACTIONS) {
            return
        }

        if ($_.Exception.Message -like '*rate limit*') {
            $token = A-Get-GithubToken -Next
            if (-not $token) {
                return
            }
            $headers['Authorization'] = "Bearer $token"

            Start-Sleep -Seconds 10

            $requestTimeout = $abgox_abyss.requestTimeout
            $versions = Invoke-RestMethod -Uri $url -Headers $headers @requestTimeout | ForEach-Object { if ($_.Name -notmatch '^\.') { $_.Name } }
        }
        else {
            return
        }
    }

    $latestVersion = ''

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


    $headers.Add('Accept', 'application/vnd.github.v3.raw')

    $url = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/$rootDir/$PackagePath/$latestVersion/$PackageIdentifier.installer.yaml"

    try {
        $requestTimeout = $abgox_abyss.requestTimeout
        $installerYaml = Invoke-RestMethod -Uri $url -Headers $headers @requestTimeout
    }
    catch {
        Write-Host "::warning::Failed to access '$url': $($_.Exception.Message)" -ForegroundColor Yellow

        if (-not $env:GITHUB_ACTIONS) {
            return
        }

        if ($_.Exception.Message -like '*rate limit*') {
            $token = A-Get-GithubToken -Next
            if (-not $token) {
                return
            }
            $headers['Authorization'] = "Bearer $token"

            Start-Sleep -Seconds 10

            $requestTimeout = $abgox_abyss.requestTimeout
            $installerYaml = Invoke-RestMethod -Uri $url -Headers $headers @requestTimeout
        }
        else {
            return
        }
    }

    $installerInfo = ConvertFrom-Yaml $installerYaml

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

    $installerInfo.PackageVersion = $installerInfo.PackageVersion -replace '^(v|V)', ''

    # 写入到 temp-autoupdate.json，用于后续读取
    $installerInfo | ConvertTo-Json -Depth 100 | Out-File -FilePath $tempFile -Force -Encoding utf8

    $out = @("ver:$($InstallerInfo.PackageVersion);")
    $out_neutral_machine = @(
        "x64:$($InstallerInfo.neutral_machine.InstallerUrl);",
        "x86:$($InstallerInfo.neutral_machine.InstallerUrl);",
        "arm64:$($InstallerInfo.neutral_machine.InstallerUrl);"
    )
    $out_neutral_user = @(
        "x64:$($InstallerInfo.neutral_user.InstallerUrl);",
        "x86:$($InstallerInfo.neutral_user.InstallerUrl);",
        "arm64:$($InstallerInfo.neutral_user.InstallerUrl);"
    )
    $out_machine = @(
        "x64:$($InstallerInfo.x64_machine.InstallerUrl);",
        "x86:$($InstallerInfo.x86_machine.InstallerUrl);",
        "arm64:$($InstallerInfo.arm64_machine.InstallerUrl);"
    )
    $out_user = @(
        "x64:$($InstallerInfo.x64_user.InstallerUrl);",
        "x86:$($InstallerInfo.x86_user.InstallerUrl);",
        "arm64:$($InstallerInfo.arm64_user.InstallerUrl);"
    )

    $_ = $json.autoupdate.architecture.'64bit'.hash.jsonpath
    $jsonpath = if ($_) { $_ }else { $json.autoupdate.architecture.'arm64'.hash.jsonpath }

    if ($jsonpath) {
        if ($jsonpath -like '$.*_machine.InstallerSha256') {
            $out += $out_neutral_machine
            $out += $out_machine
        }
        elseif ($jsonpath -like '$.*_user.InstallerSha256') {
            $out += $out_neutral_user
            $out += $out_user
        }
    }
    else {
        $out += $out_neutral_machine
        $out += $out_neutral_user
        $out += $out_machine
        $out += $out_user
    }

    return $installerInfo, $out
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

#region 以下的函数不应该在外部调用

function A-Show-Notes {
    param(
        [string[]]$Content
    )
    if ($Content) {
        $note = $Content | ForEach-Object { $ExecutionContext.InvokeCommand.ExpandString($_) }
    }
    else {
        $note = $manifest.notes
        if ($PSUICulture -like 'zh*') {
            $note = $manifest.notes_cn
        }
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
}

function A-Deny-Manifest {
    <#
    .SYNOPSIS
        拒绝清单文件，提示用户使用新的清单文件
    #>

    $msg = $null
    switch ($manifest.version) {
        deprecated {
            $msg = "'$app' is deprecated."
        }
        pending {
            $msg = "'$app' is pending."
        }
        renamed {
            $msg = "'$app' is renamed to '$($manifest.renamed.new)'."
        }
    }
    if ($msg) {
        error $msg
        error 'Refer to: https://abyss.abgox.com/faq/deny-manifest'
        A-Show-Notes
        A-Exit
    }
}

function A-Deny-IfAppConflict {
    <#
    .SYNOPSIS
        如果应用冲突，则拒绝安装
    #>
    param (
        [string[]]$Apps
    )
    $Apps | Where-Object { $_ -ne $app } | ForEach-Object {
        if (Test-Path (appdir $_)) {
            error "'$app' conflicts with '$_'."
            error 'Refer to: https://abyss.abgox.com/faq/deny-if-app-conflict'
            A-Exit
        }
    }
}

function A-Remove-TempData {
    <#
    .SYNOPSIS
        删除临时数据目录或文件

    .DESCRIPTION
        该函数用于删除指定的临时数据目录或文件。
        根据全局变量 $cmd 和 $abgox_abyss.uninstallActionLevel 的值决定是否执行删除操作。

    .PARAMETER Paths
        要删除的临时数据路径数组。
        可以包含文件或目录路径。

    .EXAMPLE
        A-Remove-TempData -Paths "C:\Temp\Logs", "D:\Cache"
        删除指定的两个临时数据目录
    #>
    param (
        [array]$Paths
    )

    if ($cmd -eq 'update') {
        return
    }
    if (-not ($abgox_abyss.uninstallActionLevel.Contains('3') -or $purge)) {
        # 如果使用了 -p 或 --purge 参数，或者 uninstallActionLevel 包含 3，则需要执行删除操作
        return
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

function A-Move-Persistence {
    $old = $manifest.renamed.old
    if (-not $old) {
        return
    }
    $parent = Split-Path $persist_dir -Parent
    foreach ($o in $old) {
        $old_path = Join-Path $parent $o
        if (A-Test-DirectoryNotEmpty $old_path) {
            $new_path = Join-Path $parent $app
            if (A-Test-DirectoryNotEmpty $new_path) {
                break
            }
            Write-Host "Migrating $old_path => $new_path"
            try {
                Rename-Item -Path $old_path -NewName $app -Force -ErrorAction Stop
            }
            catch {
                error $_.Exception.Message
                A-Show-IssueCreationPrompt
                A-Exit
            }
        }
    }
}

function A-Copy-Item {
    <#
    .SYNOPSIS
        复制文件或目录

    .DESCRIPTION
        通常用来将 bucket\extra 中提前准备好的配置文件复制到 persist 目录下，以便 Scoop 进行 persist
        因为部分配置文件，如果直接使用 New-Item 或 Set-Content，会出现编码错误

    .EXAMPLE
        A-Copy-Item "$bucketsdir\$bucket\extra\$app\InputTip.ini" "$persist_dir\InputTip.ini"

    .NOTES
        文件或目录名必须对应，以下是错误写法
        A-Copy-Item "$bucketsdir\$bucket\extra\$app\InputTip.ini" $persist_dir
    #>
    param (
        [string]$Path,
        [string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        error "Source path does not exist: $Path"
        A-Show-IssueCreationPrompt
        A-Exit
    }

    $sourceItem = Get-Item -LiteralPath $Path
    $targetDir = Split-Path $Destination -Parent

    A-Ensure-Directory $targetDir

    $needCopy = $true

    if (Test-Path -LiteralPath $Destination) {
        $targetItem = Get-Item -LiteralPath $Destination

        if ($sourceItem.PSIsContainer -eq $targetItem.PSIsContainer) {
            $needCopy = $targetItem.PSIsContainer -and -not (A-Test-DirectoryNotEmpty $Destination)
        }
    }

    if ($needCopy) {
        A-Remove-ToRecycleBin $Destination -ErrorAction SilentlyContinue
        try {
            if ($sourceItem.PSIsContainer) {
                $result = & robocopy "$Path" "$Destination" /E /MT:16 /R:1 /W:1 /NP /NFL /NDL /NJH /NJS 2>&1
                if ($LASTEXITCODE -ge 8) {
                    throw $result
                }
            }
            else {
                Copy-Item -LiteralPath $Path -Destination $Destination -Force -ErrorAction Stop
            }
            Write-Host "Copying $Path => $Destination"
        }
        catch {
            Remove-Item $Destination -Recurse -Force -ErrorAction SilentlyContinue
            error $_
            A-Show-IssueCreationPrompt
            A-Exit
        }
    }
}

function A-Remove-ToRecycleBin {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }
    $shell = New-Object -ComObject Shell.Application
    $shell.Namespace(0).ParseName($Path).InvokeVerb('delete')
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

function A-Test-Link {
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

function A-New-LinkBase {
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
        通常忽略它，让它根据 LinkPaths 自动生成
        生成规则: https://abyss.abgox.com/features/data-persistence/link-rule

    .PARAMETER ItemType
        链接类型，可选值为 SymbolicLink/Junction

    .PARAMETER OutFile
        相关链接路径信息会写入到该文件中

    .LINK
        https://abyss.abgox.com/features/data-persistence/link
    #>
    param (
        [array]$LinkPaths, # 源路径数组（将被替换为链接）
        [array]$LinkTargets, # 目标路径数组（链接指向的位置）
        [ValidateSet('SymbolicLink', 'Junction')]
        [string]$ItemType,
        [string]$OutFile
    )

    if ($LinkPaths.Where({ -not [System.IO.Path]::IsPathRooted($_) })) {
        A-Show-IssueCreationPrompt
        A-Exit
    }

    $installData = @{
        LinkPaths   = @()
        LinkTargets = @()
    }

    for ($i = 0; $i -lt $LinkPaths.Count; $i++) {
        $linkPath = $LinkPaths[$i]
        if ($LinkTargets[$i]) {
            $linkTarget = A-Get-AbsolutePath $LinkTargets[$i] $persist_dir
        }
        else {
            if ($LinkPath -like "$dir\*") {
                # 只有无法使用 persist 字段的特殊情况才能使用它，例如: liule.Snipaste
                $linkTarget = $LinkPath.replace("$dir\app\", "$persist_dir\").replace("$dir\", "$persist_dir\")
            }
            else {
                $linkTarget = $LinkPath.replace($home, $persist_dir)
                # 如果不在 $home 目录下，则去掉盘符
                if ($linkTarget -notlike "$persist_dir\*") {
                    $linkTarget = $linkTarget -replace '^[a-zA-Z]:', $persist_dir
                }
            }
        }
        $installData.LinkPaths += $linkPath
        $installData.LinkTargets += $linkTarget

        A-Ensure-Directory (Split-Path $linkPath -Parent)

        $type = if ($OutFile -eq $abgox_abyss.path.LinkFile) { 'Leaf' } else { 'Container' }
        if (Test-Path -LiteralPath $linkTarget -PathType $type) {
            if (Test-Path -LiteralPath $linkPath) {
                try {
                    Write-Host "Removing $linkPath"
                    A-Remove-ToRecycleBin $linkPath -ErrorAction Stop
                }
                catch {
                    error $_.Exception.Message
                    A-Show-IssueCreationPrompt
                    A-Exit
                }
            }
        }
        else {
            Remove-Item $linkTarget -Recurse -Force -ErrorAction SilentlyContinue
            if ((Test-Path -LiteralPath $linkPath -PathType $type) -and !(A-Test-Link $linkPath)) {
                A-Ensure-Directory (Split-Path $linkTarget -Parent)
                Write-Host "Copying $linkPath => $linkTarget"
                A-Copy-Item $linkPath $linkTarget
            }
            else {
                A-Remove-ToRecycleBin $linkPath -ErrorAction SilentlyContinue
                if ($type -eq 'Leaf') {
                    New-Item -ItemType File -Path $linkTarget -Force | Out-Null
                }
            }
        }

        if ($type -eq 'Leaf') {
            A-Ensure-Directory (Split-Path $linkTarget -Parent)
        }
        else {
            A-Ensure-Directory $linkTarget
        }
        A-Remove-ToRecycleBin $linkPath -ErrorAction SilentlyContinue
        New-Item -ItemType $ItemType -Path $linkPath -Target $linkTarget -Force | Out-Null
        Write-Host "Persisting (Link) $linkPath => $linkTarget"
    }
    $installData | ConvertTo-Json | Out-File -FilePath $OutFile -Force -Encoding utf8
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

    $params = @{
        Path        = $Path
        ErrorAction = 'Stop'
    }
    $advancedFeatures = @(
        'ForceApplicationShutdown',
        'ForceUpdateFromAnyVersion',
        'AllowUnsigned'
    )
    $supportedKeys = (Get-Command Add-AppxPackage).Parameters.Keys
    foreach ($key in $advancedFeatures) {
        if ($supportedKeys -contains $key) {
            $params[$key] = $true
        }
    }

    try {
        Add-AppxPackage @params
    }
    catch {
        error $_.Exception.Message
        A-Show-IssueCreationPrompt
        A-Exit
    }
}

function A-Remove-AppxPackage {
    <#
    .SYNOPSIS
        移除 AppX/Msix 包

    .DESCRIPTION
        该函数使用 Remove-AppxPackage 命令移除应用程序包 (.appx 或 .msixbundle)

    .PARAMETER PackageFamilyName
        应用程序包的 PackageFamilyName
    #>
    param(
        [string]$PackageFamilyName
    )
    $package = Get-AppxPackage | Where-Object { $_.PackageFamilyName -eq $PackageFamilyName } | Select-Object -First 1
    if ($package) {
        if ($package.InstallLocation) {
            Get-Process | Where-Object { $_.Path -and $_.Path -like "*$($package.InstallLocation)*" } | Stop-Process -Force -ErrorAction SilentlyContinue
        }
        $params = @{
            Package = $package
        }
        $supportedKeys = (Get-Command Remove-AppxPackage).Parameters.Keys
        if ($supportedKeys -contains 'PreserveRoamableApplicationData') {
            $params['PreserveRoamableApplicationData'] = $true
        }
        Remove-AppxPackage @params
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
        如果未指定字体类型，则根据字体文件扩展名自动判断
    #>
    param(
        [ValidateSet('ttf', 'otf', 'ttc')]
        [string]$FontType
    )

    $ExtMap = @{
        '.ttf' = 'TrueType'
        '.otf' = 'OpenType'
        '.ttc' = 'TrueType'
    }

    if (!$FontType) {
        $fontFile = Get-ChildItem -LiteralPath $dir -Recurse -File
        foreach ($file in $fontFile) {
            if ($file.Extension -in $ExtMap.Keys) {
                $FontType = $file.Extension.TrimStart('.')
                break
            }
        }
    }

    $filter = "*.$FontType"

    $currentBuildNumber = [int] (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuildNumber
    $windows10Version1809BuildNumber = 17763
    $isPerUserFontInstallationSupported = $currentBuildNumber -ge $windows10Version1809BuildNumber
    if (!$isPerUserFontInstallationSupported -and !$global) {
        Microsoft.PowerShell.Utility\Write-Host
        error "For Windows version before Windows 10 Version 1809 (OS Build 17763), Font can only be installed for all users.`nPlease use following commands to install '$app' Font for all users."
        Microsoft.PowerShell.Utility\Write-Host
        Microsoft.PowerShell.Utility\Write-Host '        scoop install sudo'
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
        $allApplicationPackagesAccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule([System.Security.Principal.SecurityIdentifier]::new('S-1-15-2-1'), 'ReadAndExecute', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
        $allRestrictedApplicationPackagesAccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule([System.Security.Principal.SecurityIdentifier]::new('S-1-15-2-2'), 'ReadAndExecute', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
        $accessControlList.SetAccessRule($allApplicationPackagesAccessRule)
        $accessControlList.SetAccessRule($allRestrictedApplicationPackagesAccessRule)
        Set-Acl -AclObject $accessControlList $fontInstallDir
    }
    $registryRoot = if ($global) { 'HKLM' } else { 'HKCU' }
    $registryKey = "${registryRoot}:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    $fonts = [System.Drawing.Text.PrivateFontCollection]::new()

    $allFonts = Get-ChildItem -LiteralPath $dir -Filter $filter -Recurse
    if (!$allFonts) {
        error "No font file found in '$dir' with extension '$filter'"
        A-Show-IssueCreationPrompt
        A-Exit
    }
    $allFonts | ForEach-Object {
        $value = if ($global) { $_.Name } else { "$fontInstallDir\$($_.Name)" }
        try {
            New-ItemProperty -Path $registryKey -Name $_.Name.Replace($_.Extension, " ($($ExtMap[$_.Extension]))") -Value $value -Force -ErrorAction Stop | Out-Null
            Copy-Item -LiteralPath $_.FullName -Destination $fontInstallDir -Force -ErrorAction Stop
            $fonts.AddFontFile($_.FullName)
        }
        catch {
            error $_.Exception.Message
            A-Exit
        }
    }

    @{
        FontType = $FontType
        FontName = $fonts.Families | Select-Object -ExpandProperty Name
    } | ConvertTo-Json | Out-File -FilePath $abgox_abyss.path.Font -Force -Encoding utf8
}

function A-Uninstall-Font {
    $OutFile = $abgox_abyss.path.Font
    if (-not (Test-Path -LiteralPath $OutFile)) {
        return
    }

    $FontType = Get-Content $OutFile -Raw | ConvertFrom-Json | Select-Object -ExpandProperty FontType
    $filter = "*.$FontType"

    $ExtMap = @{
        '.ttf' = 'TrueType'
        '.otf' = 'OpenType'
        '.ttc' = 'TrueType'
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
    $registryRoot = if ($global) { 'HKLM' } else { 'HKCU' }
    $registryKey = "${registryRoot}:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    Get-ChildItem -LiteralPath $dir -Filter $filter -Recurse | ForEach-Object {
        Remove-ItemProperty -Path $registryKey -Name $_.Name.Replace($_.Extension, " ($($ExtMap[$_.Extension]))") -Force -ErrorAction SilentlyContinue
        Remove-Item "$fontInstallDir\$($_.Name)" -Force -ErrorAction SilentlyContinue
    }
    if ($cmd -eq 'uninstall') {
        warn "The '$app' Font family has been uninstalled successfully, but there may be system cache that needs to be restarted to fully remove."
    }

    Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
}

function A-Add-Path {
    param(
        [string[]]$Paths
    )

    if (get_config USE_ISOLATED_PATH) {
        Add-Path -Path ('%' + $scoopPathEnvVar + '%') -Global:$global
    }

    $oldPath = (Get-EnvVar -Name $scoopPathEnvVar -Global:$Global).Split(';')
    $Paths = $Paths | ForEach-Object { $ExecutionContext.InvokeCommand.ExpandString($_) } | Where-Object { $_ -notin $oldPath }
    if (-not $Paths) {
        return
    }

    Add-Path -Path $Paths -TargetEnvVar $scoopPathEnvVar -Global:$global

    @{ Paths = $Paths } | ConvertTo-Json | Out-File -FilePath $abgox_abyss.path.EnvPath -Force -Encoding utf8
}

function A-Remove-Path {
    $OutFile = $abgox_abyss.path.EnvPath
    if (-not (Test-Path -LiteralPath $OutFile)) {
        return
    }

    $general_path = "$home\.local\bin", "$env:AppData\local\bin", "$env:LocalAppData\bin", "$env:LocalAppData\Microsoft\WindowsApps"

    $Path = Get-Content $OutFile -Raw | ConvertFrom-Json | Select-Object -ExpandProperty Paths | Where-Object { $_ -notin $general_path }
    if (-not $Path) {
        return
    }

    Remove-Path -Path $Path -Global:$global
    Remove-Path -Path $Path -TargetEnvVar $scoopPathEnvVar -Global:$global
    Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
}

function A-Uninstall-PowerToysRunPlugin {
    $OutFile = $abgox_abyss.path.PowerToysRunPlugin
    if (-not (Test-Path -LiteralPath $OutFile)) {
        return
    }

    $PluginsDir = "$env:LocalAppData\Microsoft\PowerToys\PowerToys Run\Plugins"

    try {
        $PluginName = Get-Content $OutFile -Raw | ConvertFrom-Json | Select-Object -ExpandProperty PluginName
        $PluginPath = "$PluginsDir\$PluginName"

        if (Test-Path -LiteralPath $PluginPath) {
            Write-Host "Removing $PluginPath"
            Remove-Item -Path $PluginPath -Recurse -Force -ErrorAction Stop
            Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        error $_.Exception.Message
        A-Show-IssueCreationPrompt
        A-Exit
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
        [string]$Path,
        [string]$Parent = $dir
    )

    if (-not $Path) {
        return ''
    }

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    $newPath = Join-Path $Parent $Path

    if ([System.IO.Path]::IsPathRooted($newPath)) {
        return $newPath
    }

    return Join-Path $dir $newPath
}

function A-Show-IssueCreationPrompt {
    # Write-Host "Please contact the bucket maintainer!" -ForegroundColor Red -NoNewline
    Write-Host 'Something went wrong here.' -ForegroundColor Red -NoNewline
    Write-Host "`nPlease try again or create a new issue by using the following link and paste your console output:`nhttps://github.com/abgox/abyss/issues/new?template=bug-report.yml" -ForegroundColor Red
}

function A-Get-UserAgent {
    return "Scoop/1.0 (+http://scoop.sh/) PowerShell/$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor) (Windows NT $([System.Environment]::OSVersion.Version.Major).$([System.Environment]::OSVersion.Version.Minor); $(if(${env:ProgramFiles(Arm)}){'ARM64; '}elseif($env:PROCESSOR_ARCHITECTURE -eq 'AMD64'){'Win64; x64; '})$(if($env:PROCESSOR_ARCHITEW6432 -in 'AMD64','ARM64'){'WOW64; '})$PSEdition)"
}

function A-Get-GithubToken {
    param(
        [switch]$Next
    )
    if ($null -eq $env:TOKEN_POOL -or -not $env:TOKEN_POOL.Trim()) {
        Write-Host "::error::'TOKEN_POOL' not set." -ForegroundColor Red
        exit 1
    }
    $order = [int]([System.Environment]::GetEnvironmentVariable('TOKEN_ORDER', 'User'))
    if (-not $order) {
        $order = 1
        [Environment]::SetEnvironmentVariable('TOKEN_ORDER', $order, 'User')
    }
    if ($Next) {
        $order++
        [Environment]::SetEnvironmentVariable('TOKEN_ORDER', $order, 'User')
    }
    $tokens = $env:TOKEN_POOL.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    if ($tokens) {
        return $tokens[$order - 1]
    }
}

function A-New-MatchedString {
    param (
        [string]$RegexPattern,
        [string]$TargetValue
    )

    $re = [regex]$RegexPattern
    $groupNames = $re.GetGroupNames()

    if ($groupNames -contains 'version') {
        $targetGroupName = 'version'
    }
    elseif ($re.GroupNumberFromName(1) -ne -1) {
        $targetGroupName = '1'
    }
    else {
        return $TargetValue
    }

    $groupPattern = "\((?:\?<${targetGroupName}>|).*?\)"
    $result = [regex]::Replace($RegexPattern, $groupPattern, $TargetValue)

    return $result -replace '^\^|\$$', '' -replace '\((?:\?<.*?>|).*?\)', '' -replace '[\(\)]', '' -replace '\\(.)', '$1'
}

#endregion



#region 扩展 Scoop 部分功能

# 它不属于 scoop core，但可能也需要跟进 Scoop 最新变动
function A-Set-EnvVarShared {
    param(
        [switch]$Remove
    )

    $env_set_shared = $manifest.env_set_shared

    if ($Remove) {
        $env_set_shared | Get-Member -MemberType NoteProperty | ForEach-Object {
            $name = $_.Name
            $owner = $env_set_shared.$name.owner
            $has_other_owner = $owner | Where-Object { $_ -ne $app } | ForEach-Object { Test-Path "$scoopdir\apps\$_\current\manifest.json" }
            if ($has_other_owner) {
                return
            }
            Write-Output "Removing $(if ($global) {'system'} else {'user'}) environment variable: $([char]0x1b)[34m$name$([char]0x1b)[0m"
            Set-EnvVar -Name $name -Value $null -Global:$global
            if (Test-Path env:\$name) { Remove-Item env:\$name }
        }
    }
    else {
        $env_set_shared | Get-Member -MemberType NoteProperty | ForEach-Object {
            $name = $_.Name
            $val = $ExecutionContext.InvokeCommand.ExpandString($env_set_shared.$name.value)
            # $owner = $env_set_shared.$name.owner
            Write-Output "Setting $(if ($global) {'system'} else {'user'}) environment variable: $([char]0x1b)[34m$name$([char]0x1b)[0m = $([char]0x1b)[35m$val$([char]0x1b)[0m"
            Set-EnvVar -Name $name -Value $val -Global:$global
            Set-Content env:\$name $val
        }
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

    $abgox_abyss = @{}

    # https://abyss.abgox.com/features/extra-features#abgox-abyss-app-shortcuts-action
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
            "$home\Desktop",
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
    $filename = $target.FullName
    if ($filename -match '^\$\{?(env:|home)') {
        $filename = $filename.Replace("$dir\", '')
        $target = [System.IO.FileInfo]::new($ExecutionContext.InvokeCommand.ExpandString($filename))
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
        $cmds += @($psd1.CmdletsToExport) + @($psd1.FunctionsToExport) + @($psd1.AliasesToExport) | Where-Object { $_ -ne '*' }
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

#endregion
