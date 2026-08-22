#Requires -Version 5.1

$abgox_abyss = @{
    path         = @{
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
    knownFolders = @(
        @{ Name = 'Documents'; DefaultPrefix = Join-Path $home 'Documents'; Folder = [Environment]::GetFolderPath('MyDocuments') }
        @{ Name = 'Desktop'; DefaultPrefix = Join-Path $home 'Desktop'; Folder = [Environment]::GetFolderPath('Desktop') }
        @{ Name = 'Pictures'; DefaultPrefix = Join-Path $home 'Pictures'; Folder = [Environment]::GetFolderPath('MyPictures') }
        @{ Name = 'Music'; DefaultPrefix = Join-Path $home 'Music'; Folder = [Environment]::GetFolderPath('MyMusic') }
        @{ Name = 'Videos'; DefaultPrefix = Join-Path $home 'Videos'; Folder = [Environment]::GetFolderPath('MyVideos') }
    )
}

if ($env:GITHUB_ACTIONS) { $VerbosePreference = 'SilentlyContinue' } else { Microsoft.PowerShell.Utility\Write-Host }
if ($bucket) {
    if ($scoopdir -and $scoopdir -ne $scoopConfig.root_path) { scoop config root_path $scoopdir }
    if ($global -and $globaldir -and $globaldir -ne $scoopConfig.global_path) { scoop config global_path $globaldir }
}

# https://abyss.abgox.com/docs/features/extra-features#abgox-abyss-app-uninstall-action
$_ = $scoopConfig.'abgox-abyss-app-uninstall-action'
$abgox_abyss.uninstallActionLevel = if ($_ -match '[123]+') { $_ } else { '123' }

function A-Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $admin = [Security.Principal.WindowsBuiltInRole]::Administrator
    [Security.Principal.WindowsPrincipal]::new($identity).IsInRole($admin)
}

function A-Test-DeveloperMode {
    # 检查开发者模式是否启用 https://learn.microsoft.com/windows/apps/get-started/developer-mode-features-and-debugging
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
            if (Test-Path $from) {
                A-Copy-Item $from $to
            }
            $from = "$bucketsdir\$bucket\extra\$app\$target"
            if (Test-Path $from) {
                A-Copy-Item $from $to
            }
            if ($target -match 'AppData\\(Roaming|Local)\\.*') {
                $from = Join-Path $home $target
                $exists = Test-Path $from -PathType Container
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
    # https://abyss.abgox.com/docs/shared-data
    if ($manifest.data_shared) {
        A-Set-DataShared
    }
    # https://abyss.abgox.com/docs/features/data-persistence/link
    if ($manifest.link -and !$abgox_abyss.skipLink) {
        foreach ($item in $manifest.link) {
            $expandPath = A-Resolve-SpecialPath $item
            if (Test-Path $expandPath) {
                if ($expandPath -like "$dir\*") {
                    $to = $expandPath.Replace("$dir\app\", "$persist_dir\").Replace("$dir\", "$persist_dir\")
                }
                else {
                    $to = A-Replace-SpecialFolderPrefix $expandPath $persist_dir
                }
                A-Copy-Item $expandPath $to
            }
            else {
                if ($expandPath -like "$dir\*") {
                    $leaf = $expandPath.Replace("$dir\app\", '').Replace("$dir\", '')
                }
                else {
                    $leaf = A-Replace-SpecialFolderPrefix $expandPath
                }
                $extraPath = "$bucketsdir\$bucket\extra\$app\$leaf"
                if (Test-Path $extraPath) {
                    A-Copy-Item $extraPath "$persist_dir\$leaf"
                }
            }
        }
        if (!($manifest.pre_install -match '^\s*A-New-Link$')) {
            A-New-Link
        }
    }
    if ($manifest.msix -and !($manifest.pre_install -match '^\s*A-Install-MsixPackage$')) {
        A-Install-MsixPackage
    }
    if ($manifest.extract_to -and !$manifest.innosetup) {
        $fileNameList = @($fname)
        $extract_tos = @($manifest.extract_to)
        for ($i = 0; $i -lt $fileNameList.Count; $i++) {
            $file = Join-Path $dir $fileNameList[$i]
            if (!(Test-Path $file)) {
                continue
            }
            $ext = [System.IO.Path]::GetExtension($file)
            if ($ext -in '.exe', '.ps1', '.bat', '.cmd') {
                $dest_dir = if ($i -lt $extract_tos.Count) { $extract_tos[$i] }else { $extract_tos[-1] }
                $dest_dir = Join-Path $dir $dest_dir
                $dest_file = Join-Path $dest_dir $fileNameList[$i]
                A-Ensure-Directory $dest_dir
                Write-Host "Moving $file => $dest_file"
                Move-Item -Path $file -Destination $dest_file -Force
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
        if (!(Test-Path $location)) {
            A-Show-IssueCreationPrompt
            A-Exit
        }
        $info.location = $location
        A-Show-Notes @(
            "The installation directory: $($manifest.location)",
            'Refer to: https://abyss.abgox.com/docs/external-installation-directory'
        )
    }
    if ($manifest.data_shared) {
        $remaining = $manifest.data_shared | Where-Object { $_ -ne $app } | Where-Object { A-Test-DirectoryNotEmpty "$scoopdir\apps\$_" }
        if ($remaining -and !(A-Test-DirectoryNotEmpty $persist_dir)) {
            A-Show-Notes @(
                "'$app' does not require the data persistence.",
                "They share data: $($remaining -join '|').",
                'Refer to: https://abyss.abgox.com/docs/shared-data'
            )
        }
    }
    if ($info.Count) {
        $info | ConvertTo-Json | Out-File -FilePath $abgox_abyss.path.Info -Force -Encoding utf8
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
                $new = Get-Content $jsonFile -Raw -Encoding utf8 -ErrorAction Stop | ConvertFrom-Json | Select-Object -ExpandProperty renamed | Select-Object -ExpandProperty new
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
    # https://abyss.abgox.com/docs/shared-data
    if ($manifest.data_shared) {
        A-Set-DataShared -Uninstall
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
    param (
        [string]$Path = $persist_dir
    )
    if ([System.IO.Directory]::Exists($Path)) { return }
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
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

    if ([System.IO.File]::Exists($Path)) {
        return
    }
    elseif ([System.IO.Directory]::Exists($Path)) {
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
        A-Ensure-Directory (Split-Path $Path -Parent)
    }
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
        if (!$item) {
            continue
        }
        $expandPath = A-Resolve-SpecialPath $item
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
                $leaf = A-Replace-SpecialFolderPrefix $expandPath
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
        https://abyss.abgox.com/docs/features/data-persistence/link
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
            error "'$app' requires admin permission or developer mode to create SymbolicLink."
            error 'Refer to: https://abyss.abgox.com/docs/require-admin-or-dev-mode'
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
        https://abyss.abgox.com/docs/features/data-persistence/link
    #>
    param (
        [array]$LinkPaths,
        [array]$LinkTargets = @()
    )

    A-New-LinkBase -LinkPaths $LinkPaths -LinkTargets $LinkTargets -ItemType Junction -OutFile $abgox_abyss.path.LinkDirectory
}

function A-Repair-Link {
    <#
    .SYNOPSIS
        检测并修复被破坏的链接: SymbolicLink、Junction

    .DESCRIPTION
        应用的安装程序(如 Inno Setup)可能在安装过程中删除或覆盖已创建的链接，
        导致应用更新后数据持久化失效。
        该函数会重新检测 manifest.link 中定义的所有路径，并修复失效的链接。
        它应该在安装函数(A-Install-*)执行完成之后调用。
    #>

    if ($manifest.link -and !$abgox_abyss.skipLink) {
        A-New-Link
    }
}

function A-Remove-Link {
    <#
    .SYNOPSIS
        删除链接: SymbolicLink、Junction

    .DESCRIPTION
        该函数用于删除在应用安装过程中创建的 SymbolicLink 和 Junction
    #>

    if ($abgox_abyss.skipRemoveLink) {
        return
    }
    $abgox_abyss.path.LinkFile, $abgox_abyss.path.LinkDirectory | ForEach-Object {
        if (Test-Path -LiteralPath $_) {
            $LinkPaths = Get-Content $_ -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json | Select-Object -ExpandProperty LinkPaths
            foreach ($p in $LinkPaths) {
                if (A-Test-Link $p) {
                    try {
                        Write-Host "Unlinking $p"
                        Remove-Item $p -Force -Recurse -ErrorAction Stop

                        $parent = Split-Path $p -Parent
                        if (!(A-Test-DirectoryNotEmpty $parent)) {
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
    if (!$abgox_abyss.uninstallActionLevel.Contains('1') -or ($manifest.msix -and !$ExtraPaths)) {
        return
    }

    if ($manifest.location -or $version -eq 'virtual') {
        $Paths = @((A-Resolve-SpecialPath $manifest.location))
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

    Start-Sleep -Milliseconds 50

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
    if (!$service) {
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
        if (!$service) { return }

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
        [string]$Installer = (Join-Path $dir ($fname | Select-Object -First 1)),
        [string]$SleepSec = 3
    )

    if (!(Test-Path -LiteralPath $Installer)) {
        error "'$Installer' not found."
        A-Show-IssueCreationPrompt
        A-Exit
    }

    if (!$PSBoundParameters.ContainsKey('ArgumentList')) {
        $ArgumentList = @('/S')
        if (!$manifest.admin) {
            $ArgumentList += '/CurrentUser'
        }
        if (!$manifest.location) {
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
        A-Get-AbsolutePath $Uninstaller (A-Resolve-SpecialPath $manifest.location)
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

    A-Repair-Link
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
        [array]$ArgumentList,
        [string]$Installer = (Join-Path $dir ($fname | Select-Object -First 1))
    )

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

    A-Repair-Link
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

    $Uninstaller = Get-ChildItem $dir unins000.exe -Recurse -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if (!$Uninstaller) {
        warn "'unins000.exe' not found."
        return
    }

    Write-Host "Running the uninstaller: $($Uninstaller.Name)"

    try {
        $process = Start-Process -FilePath $Uninstaller -ArgumentList $ArgumentList -PassThru
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
        [array]$ArgumentList,
        [string]$Installer = (Join-Path $dir ($fname | Select-Object -First 1))
    )

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
    if (!$guid) {
        $guid = $log | Select-String 'SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\\{([0-9A-Fa-f\-]{36})\}' | ForEach-Object { $_.Matches.Groups[1].Value } | Select-Object -First 1
    }
    $Uninstaller = Get-ChildItem "C:\ProgramData\Package Cache\{$guid}" -File -Filter *.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName

    if (!$Uninstaller) {
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

    A-Repair-Link
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

    if (!$Uninstaller) {
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
        [array]$ArgumentList,
        [string]$Installer,
        [string]$MsiPath
    )

    if (!$Installer) {
        $Installer = 'C:\Windows\SysWOW64\msiexec.exe', 'C:\Windows\System32\msiexec.exe' | Where-Object { [System.IO.File]::Exists($_) } | Select-Object -First 1
    }
    if (!$MsiPath) {
        $MsiPath = Join-Path $dir ($fname | Select-Object -First 1)
    }
    if (!(Test-Path -LiteralPath $Installer)) {
        error "'$Installer' not found."
        A-Show-IssueCreationPrompt
        A-Exit
    }

    $logPath = "$env:TEMP\scoop_$($app)_$($version)_install_msi.log"

    if (!$PSBoundParameters.ContainsKey('ArgumentList')) {
        $ArgumentList = @(
            '/i',
            "`"$MsiPath`"",
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
        if ($MsiPath) {
            Remove-Item $MsiPath -Force -ErrorAction Stop
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

    A-Repair-Link
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
        $Paths += A-Resolve-SpecialPath $manifest.location
    }

    foreach ($p in $Paths) {
        $p = A-Get-AbsolutePath $p
        if (Test-Path -LiteralPath $p) {
            if (!(Get-ChildItem -LiteralPath $p -File -Recurse | Select-Object -First 1)) {
                try {
                    Remove-Item $p -Force -Recurse -ErrorAction Stop
                    continue
                }
                catch {}
            }
            error 'It requires you to uninstall it manually.'
            error $p
            error 'Refer to: https://abyss.abgox.com/docs/uninstall-manually'
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
        [string]$PackageFamilyName = $manifest.msix,
        [string]$Installer = (Join-Path $dir ($fname | Select-Object -First 1))
    )
    A-Add-AppxPackage -PackageFamilyName $PackageFamilyName -Path $Installer
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

function A-Require-Admin {
    <#
    .SYNOPSIS
        要求以管理员权限运行
    #>

    if (!$abgox_abyss.isAdmin) {
        error 'It requires admin permission. Please try again with admin permission.'
        error 'Refer to: https://abyss.abgox.com/docs/require-admin'
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
        error 'Refer to: https://abyss.abgox.com/docs/deny-update'
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



#region 以下的函数不应该在外部调用

function A-Test-BucketName {
    if ($bucket -ne 'abyss') {
        error "You should use 'abyss' as the bucket name, but the current name is '$bucket'."
        error 'Refer to: https://abyss.abgox.com/docs/bucket-name'
        A-Exit
    }
}

function A-Show-Notes {
    param(
        [string[]]$Content
    )
    if ($Content) {
        $note = $Content | ForEach-Object { A-Resolve-SpecialPath $_ }
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
        substitute $note @{
            '$cmd'                     = $cmd
            '$bucket'                  = $bucket, 'abyss' | Select-Object -First 1
            '$app'                     = $app
            '$version'                 = $manifest.version
            '$architecture'            = $architecture
            '$dir'                     = $dir
            '$original_dir'            = $original_dir
            '$scoopdir'                = $scoopdir
            '$persist_dir'             = $persist_dir
            '$env:ProgramFiles'        = $env:ProgramFiles
            '${env:ProgramFiles(x86)}' = ${env:ProgramFiles(x86)}
            '$env:ProgramData'         = $env:ProgramData
            '$env:AppData'             = $env:AppData
            '$env:LocalAppData'        = $env:LocalAppData
        } | ForEach-Object { Write-Output $_ }
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
        error 'Refer to: https://abyss.abgox.com/docs/deny-manifest'
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
            error 'Refer to: https://abyss.abgox.com/docs/deny-if-app-conflict'
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
    if (!($abgox_abyss.uninstallActionLevel.Contains('3') -or $purge)) {
        # 如果使用了 -p 或 --purge 参数，或者 uninstallActionLevel 包含 3，则需要执行删除操作
        return
    }
    foreach ($p in $Paths) {
        if (Test-Path -LiteralPath $p) {
            try {
                Write-Host "Removing $p"
                Remove-Item $p -Force -Recurse -ErrorAction Stop

                $parent = Split-Path $p -Parent
                if (!(A-Test-DirectoryNotEmpty $parent)) {
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
    if (!$old) {
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

function A-Set-DataShared {
    <#
    .SYNOPSIS
        处理 data_shared 字段，管理共享数据目录

    .DESCRIPTION
        只维护一个实际数据目录。安装时不做任何处理；卸载时如果持有数据则迁移给其他应用并更新 symlink
    #>
    param(
        [switch]$Uninstall
    )

    $parent = Split-Path $persist_dir -Parent
    $remaining = $manifest.data_shared | Where-Object { $_ -ne $app } | Where-Object { A-Test-DirectoryNotEmpty "$scoopdir\apps\$_" }

    if ($Uninstall) {
        if (!$remaining) {
            return
        }
        if ($cmd -ne 'update' -and (A-Test-DirectoryNotEmpty $persist_dir)) {
            $target = $remaining | Select-Object -First 1
            $targetPersist = Join-Path $parent $target
            if (!(A-Test-DirectoryNotEmpty $targetPersist)) {
                Write-Host "Migrating $persist_dir => $targetPersist"
                try {
                    Rename-Item -LiteralPath $persist_dir -NewName $target -Force -ErrorAction Stop
                }
                catch {
                    error $_.Exception.Message
                    A-Show-IssueCreationPrompt
                    A-Exit
                }
            }
            $abgox_abyss.persist_dir = $targetPersist
            A-New-Link
        }
        $abgox_abyss.skipRemoveLink = $true
    }
    else {
        if ($remaining) {
            if (!(A-Test-DirectoryNotEmpty $persist_dir)) {
                $abgox_abyss.skipLink = $true
            }
        }
        else {
            foreach ($name in $manifest.data_shared) {
                if ($name -eq $app) { continue }
                $orphanedPersist = Join-Path $parent $name
                if (A-Test-DirectoryNotEmpty $orphanedPersist) {
                    Write-Host "Migrating $orphanedPersist => $persist_dir"
                    try {
                        Rename-Item -LiteralPath $orphanedPersist -NewName $app -Force -ErrorAction Stop
                    }
                    catch {
                        error $_.Exception.Message
                        A-Show-IssueCreationPrompt
                        A-Exit
                    }
                    break
                }
            }
        }
    }
}

function A-Resolve-SpecialPath {
    param([string]$Path)
    $result = $ExecutionContext.InvokeCommand.ExpandString($Path)
    foreach ($entry in $abgox_abyss.knownFolders ) {
        if ($result.StartsWith($entry.DefaultPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $entry.Folder + $result.Substring($entry.DefaultPrefix.Length)
        }
    }
    return $result
}

function A-Replace-SpecialFolderPrefix {
    param(
        [string]$Path,
        [string]$Replacement = ''
    )
    foreach ($entry in $abgox_abyss.knownFolders) {
        if ($Path.StartsWith($entry.Folder, [System.StringComparison]::OrdinalIgnoreCase)) {
            $relative = $entry.Name + $Path.Substring($entry.Folder.Length)
            if (!$Replacement) { return $relative }
            return Join-Path $Replacement $relative
        }
    }
    $relative = $Path.Replace("$home\", '') -replace '^[a-zA-Z]:', ''
    if (!$Replacement) { return $relative }
    return Join-Path $Replacement $relative
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

    if (!(Test-Path -LiteralPath $Path)) {
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
            $needCopy = $targetItem.PSIsContainer -and !(A-Test-DirectoryNotEmpty $Destination)
        }
    }

    if ($needCopy) {
        A-Remove-ToRecycleBin $Destination -ErrorAction SilentlyContinue
        try {
            if ($sourceItem.PSIsContainer -and !$sourceItem.LinkType) {
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
    if (!(Test-Path -LiteralPath $Path)) {
        return
    }
    $shell = New-Object -ComObject Shell.Application
    $shell.Namespace(0).ParseName($Path).InvokeVerb('delete')
}

function A-Test-DirectoryNotEmpty {
    param(
        [string]$Path
    )
    if (!(Test-Path -LiteralPath $Path -PathType Container)) {
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
        生成规则: https://abyss.abgox.com/docs/features/data-persistence/link-rule

    .PARAMETER ItemType
        链接类型，可选值为 SymbolicLink/Junction

    .PARAMETER OutFile
        相关链接路径信息会写入到该文件中

    .LINK
        https://abyss.abgox.com/docs/features/data-persistence/link
    #>
    param (
        [array]$LinkPaths, # 源路径数组（将被替换为链接）
        [array]$LinkTargets, # 目标路径数组（链接指向的位置）
        [ValidateSet('SymbolicLink', 'Junction')]
        [string]$ItemType,
        [string]$OutFile
    )

    if ($abgox_abyss.skipLink) {
        return
    }

    if ($LinkPaths.Where({ -not [System.IO.Path]::IsPathRooted($_) })) {
        A-Show-IssueCreationPrompt
        A-Exit
    }

    $_persistDir = $abgox_abyss.persist_dir, $persist_dir | Select-Object -First 1

    $installData = @{
        LinkPaths   = @()
        LinkTargets = @()
    }

    for ($i = 0; $i -lt $LinkPaths.Count; $i++) {
        $linkPath = $LinkPaths[$i]
        if ($LinkTargets[$i]) {
            $linkTarget = A-Get-AbsolutePath $LinkTargets[$i] $_persistDir
        }
        else {
            if ($LinkPath -like "$dir\*") {
                # 只有无法使用 persist 字段的特殊情况才能使用它，例如: liule.Snipaste
                $linkTarget = $LinkPath.replace("$dir\app\", "$_persistDir\").replace("$dir\", "$_persistDir\")
            }
            else {
                $linkTarget = A-Replace-SpecialFolderPrefix $LinkPath $_persistDir
                # 如果不在 $home 目录下，则去掉盘符
                if ($linkTarget -notlike "$_persistDir\*") {
                    $linkTarget = $linkTarget -replace '^[a-zA-Z]:', $_persistDir
                }
            }
        }
        $installData.LinkPaths += $linkPath
        $installData.LinkTargets += $linkTarget

        $type = if ($OutFile -eq $abgox_abyss.path.LinkFile) { 'Leaf' } else { 'Container' }

        # 如果链接已存在且指向正确的目标位置，则无需重复创建(避免每次安装/更新时都删除并重建链接)
        # 注意: 需要同时确认目标位置仍然存在，以处理链接目标丢失(悬空链接)的情况
        $linkItem = Get-Item -LiteralPath $linkPath -Force -ErrorAction SilentlyContinue
        if ($linkItem -and $linkItem.LinkType -and (Test-Path -LiteralPath $linkTarget -PathType $type)) {
            try {
                $linkItemTarget = @($linkItem.Target)[0]
                if ($linkItemTarget) {
                    $existingTarget = [System.IO.Path]::GetFullPath([string]$linkItemTarget).TrimEnd('\')
                    $expectedTarget = [System.IO.Path]::GetFullPath($linkTarget).TrimEnd('\')
                    if ($existingTarget -ieq $expectedTarget) {
                        continue
                    }
                }
            }
            catch {}
        }

        A-Ensure-Directory (Split-Path $linkPath -Parent)
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
    if (!(Test-Path -LiteralPath $OutFile)) {
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
    $Paths = $Paths | ForEach-Object { A-Resolve-SpecialPath $_ } | Where-Object { $_ -notin $oldPath }
    if (!$Paths) {
        return
    }

    Add-Path -Path $Paths -TargetEnvVar $scoopPathEnvVar -Global:$global

    @{ Paths = $Paths } | ConvertTo-Json | Out-File -FilePath $abgox_abyss.path.EnvPath -Force -Encoding utf8
}

function A-Remove-Path {
    $OutFile = $abgox_abyss.path.EnvPath
    if (!(Test-Path -LiteralPath $OutFile)) {
        return
    }

    $general_path = "$home\.local\bin", "$env:AppData\local\bin", "$env:LocalAppData\bin", "$env:LocalAppData\Microsoft\WindowsApps"

    $Path = Get-Content $OutFile -Raw | ConvertFrom-Json | Select-Object -ExpandProperty Paths | Where-Object { $_ -notin $general_path }
    if (!$Path) {
        return
    }

    Remove-Path -Path $Path -Global:$global
    Remove-Path -Path $Path -TargetEnvVar $scoopPathEnvVar -Global:$global
    Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
}

function A-Uninstall-PowerToysRunPlugin {
    $OutFile = $abgox_abyss.path.PowerToysRunPlugin
    if (!(Test-Path -LiteralPath $OutFile)) {
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

    if (!$Path) {
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
    # Write-Host "Please contact the bucket maintainer!" -ForegroundColor DarkRed -NoNewline
    Write-Host 'Something went wrong here.' -ForegroundColor DarkRed -NoNewline
    Write-Host "`nPlease try again or create a new issue by using the following link and paste your console output:`nhttps://github.com/abgox/abyss/issues/new?template=bug-report.yml" -ForegroundColor DarkRed
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
            $val = A-Resolve-SpecialPath $env_set_shared.$name.value
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

#endregion
