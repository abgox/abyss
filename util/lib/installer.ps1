function A-Get-InstallDir {
    if ($manifest.location) {
        return A-Resolve-SpecialPath $manifest.location
    }
    return "$dir\app"
}

function A-Invoke-InstallerProcess {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        [array]$ArgumentList,
        [int]$TimeoutSec = 600,
        [switch]$Hidden
    )
    if (!(A-Test-File $FilePath)) {
        error "'$FilePath' not found."
        A-Show-IssueCreationPrompt
        A-Exit
    }

    Write-Host "Running the installer: $(Split-Path $FilePath -Leaf)"

    $startParams = @{
        FilePath     = $FilePath
        ArgumentList = $ArgumentList
        PassThru     = $true
    }
    if ($Hidden) { $startParams.WindowStyle = 'Hidden' }

    $process = $null
    try {
        $process = Start-Process @startParams
        if (!$process.WaitForExit($TimeoutSec * 1000)) {
            error "Installer timed out after $TimeoutSec seconds: $FilePath"
            $process | Stop-Process -Force -ErrorAction SilentlyContinue
            A-Show-IssueCreationPrompt
            A-Exit
        }
        $allowedCodes = @(0, 1641, 3010)
        if ($process.ExitCode -notin $allowedCodes) {
            error "Installer exited with code $($process.ExitCode): $FilePath"
            A-Show-IssueCreationPrompt
            A-Exit
        }
    }
    catch {
        error $_.Exception.Message
        A-Show-IssueCreationPrompt
        if ($process) { $process | Stop-Process -Force -ErrorAction SilentlyContinue }
        A-Exit
    }
}

function A-Get-UninstallEntryByAppName {
    param (
        [string]$AppNamePattern
    )
    # 搜索注册表位置
    $registryPaths = @(
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach ($path in $registryPaths) {
        # 获取所有卸载项
        $uninstallItems = Get-ChildItem -LiteralPath $path -ErrorAction SilentlyContinue | Get-ItemProperty -ErrorAction SilentlyContinue
        foreach ($item in $uninstallItems) {
            if ($null -ne $item.DisplayName -and $item.DisplayName -match $AppNamePattern) {
                return $item
            }
        }
    }
}

function A-Wait-Uninstaller {
    param(
        [string]$Path,
        [int]$TimeoutMs = 5000
    )
    if (!$Path) { return }
    $elapsed = 0
    while (!(A-Test-File $Path) -and $elapsed -lt $TimeoutMs) {
        Start-Sleep -Milliseconds 200
        $elapsed += 200
    }
    if (!(A-Test-File $Path)) {
        error "'$Path' not found."
        A-Show-IssueCreationPrompt
        A-Exit
    }
}

function A-Wait-ForUnlock {
    param(
        [string]$Path = $dir,
        [int]$TimeoutMs = 5000
    )
    if (!(A-Test-Path $Path)) { return }
    $elapsed = 0
    while ($elapsed -lt $TimeoutMs) {
        $locked = (Get-Process).Where({ $_.Path -and $_.Path.StartsWith($Path + '\', [System.StringComparison]::OrdinalIgnoreCase) })
        if (-not $locked) {
            try {
                $testFile = [System.IO.Path]::Combine($Path, '.abyss-lock-test')
                $stream = [System.IO.File]::Create($testFile, 1, [System.IO.FileOptions]::DeleteOnClose)
                $stream.Dispose()
                Remove-Item -LiteralPath $testFile -Force -ErrorAction SilentlyContinue
                break
            }
            catch {}
        }
        Start-Sleep -Milliseconds 300
        $elapsed += 300
    }
    if ($elapsed -ge $TimeoutMs) {
        Write-Host "Files still in use. You can run 'scoop uninstall $app' again to complete removal." -ForegroundColor Yellow
    }
}

function A-Install-App {
    param(
        [string]$Uninstaller, # 当指定它后，A-Uninstall-App 会默认使用它作为卸载程序路径
        [array]$ArgumentList,
        [string]$Installer = (Join-Path $dir ($fname | Select-Object -First 1)),
        [int]$TimeoutSec = 600
    )
    $installDir = A-Get-InstallDir
    if (!$PSBoundParameters.ContainsKey('ArgumentList')) {
        $ArgumentList = @('/S')
        if (!$manifest.admin) {
            $ArgumentList += '/CurrentUser'
        }
        $ArgumentList += "/D=$installDir"
    }

    A-Invoke-InstallerProcess -FilePath $Installer -ArgumentList $ArgumentList -TimeoutSec $TimeoutSec -Hidden

    $Uninstaller = if ($manifest.location) { A-Get-AbsolutePath $Uninstaller $installDir } else { A-Get-AbsolutePath $Uninstaller }

    @{
        Installer    = $Installer
        ArgumentList = $ArgumentList
        Uninstaller  = $Uninstaller
    } | ConvertTo-Json | Out-File -LiteralPath $abgox_abyss.path.InstallApp -Force -Encoding utf8

    A-Wait-Uninstaller -Path $Uninstaller

    try {
        if ($Installer -and (A-Test-File $Installer)) {
            Remove-Item -LiteralPath $Installer -Force -ErrorAction Stop
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
        [array]$ArgumentList = @('/S')
    )
    $InstallerInfoPath = $abgox_abyss.path.InstallApp
    if (A-Test-File $InstallerInfoPath) {
        try {
            $InstallerInfo = Get-Content -LiteralPath $InstallerInfoPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
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
    if (!(A-Test-File $Uninstaller)) {
        $_Uninstaller = Get-ChildItem -LiteralPath $dir -Filter $UninstallerFileName -Recurse -File -Force -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
        if ($null -eq $_Uninstaller) {
            return
        }
        if (!(A-Test-File $_Uninstaller)) {
            warn "'$Uninstaller' not found."
            return
        }
        $Uninstaller = $_Uninstaller
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
    A-Wait-ForUnlock -Path $dir
}

function A-Install-Inno {
    param(
        [string]$Uninstaller,
        [array]$ArgumentList,
        [string]$Installer = (Join-Path $dir ($fname | Select-Object -First 1)),
        [int]$TimeoutSec = 600
    )
    $installDir = A-Get-InstallDir
    $logPath = "$env:TEMP\scoop_$($app)_$($version)_install_inno.log"
    if (!$PSBoundParameters.ContainsKey('ArgumentList')) {
        $ArgumentList = @(
            '/CurrentUser',
            '/VerySilent',
            '/SuppressMsgBoxes',
            '/NoRestart',
            '/SP-',
            "/Log=$logPath",
            "/Dir=`"$installDir`""
        )
    }
    A-Invoke-InstallerProcess -FilePath $Installer -ArgumentList $ArgumentList -TimeoutSec $TimeoutSec
    if ($PSBoundParameters.ContainsKey('Uninstaller')) {
        $Uninstaller = A-Get-AbsolutePath $Uninstaller
    }
    else {
        $Uninstaller = Get-ChildItem -LiteralPath $installDir -Filter unins*.exe -Recurse -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
    }
    @{
        Installer    = $Installer
        ArgumentList = $ArgumentList
        Uninstaller  = $Uninstaller
    } | ConvertTo-Json | Out-File -LiteralPath $abgox_abyss.path.InstallInno -Force -Encoding utf8
    A-Wait-Uninstaller -Path $Uninstaller
    try {
        if ($Installer -and (A-Test-File $Installer)) {
            Remove-Item -LiteralPath $Installer -Force -ErrorAction Stop
        }
    }
    catch {
        error $_.Exception.Message
    }
    Remove-Item -LiteralPath $logPath -Force -ErrorAction SilentlyContinue

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
    $Uninstaller = Get-ChildItem -LiteralPath $dir -Filter unins000.exe -Recurse -File -Force -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
    if (!$Uninstaller) {
        warn "'unins000.exe' not found."
        return
    }

    Write-Host "Running the uninstaller: $(Split-Path $Uninstaller -Leaf)"

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
        [string]$Installer = (Join-Path $dir ($fname | Select-Object -First 1)),
        [int]$TimeoutSec = 600
    )
    $logPath = "$env:TEMP\scoop_$($app)_$($version)_install_burn.log"
    if (!$PSBoundParameters.ContainsKey('ArgumentList')) {
        $ArgumentList = @('/quiet', '/norestart', '/log', $logPath)
    }

    A-Invoke-InstallerProcess -FilePath $Installer -ArgumentList $ArgumentList -TimeoutSec $TimeoutSec

    $log = Get-Content -LiteralPath $logPath -ErrorAction SilentlyContinue
    $guid = $log | Select-String 'WixBundleProviderKey = ([0-9A-Fa-f\-]{36})' | ForEach-Object { $_.Matches.Groups[1].Value } | Select-Object -First 1
    if (!$guid) {
        $guid = $log | Select-String 'SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\\{([0-9A-Fa-f\-]{36})\}' | ForEach-Object { $_.Matches.Groups[1].Value } | Select-Object -First 1
    }
    $Uninstaller = Get-ChildItem -LiteralPath "$env:ProgramData\Package Cache\{$guid}" -File -Filter *.exe -Force -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
    if (!$Uninstaller) {
        $Uninstaller = $Installer
    }
    @{
        Installer    = $Installer
        ArgumentList = $ArgumentList
        Uninstaller  = $Uninstaller
    } | ConvertTo-Json | Out-File -LiteralPath $abgox_abyss.path.InstallBurn -Force -Encoding utf8

    A-Wait-Uninstaller -Path $Uninstaller

    Remove-Item -LiteralPath $logPath -Force -ErrorAction SilentlyContinue

    A-Repair-Link
}

function A-Uninstall-Burn {
    param(
        [array]$ArgumentList = @('/uninstall', '/quiet')
    )
    $InstallerInfoPath = $abgox_abyss.path.InstallBurn
    if (A-Test-File $InstallerInfoPath) {
        try {
            $InstallerInfo = Get-Content -LiteralPath $InstallerInfoPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
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
        [string]$MsiPath,
        [int]$TimeoutSec = 600
    )
    if (!$Installer) {
        $Installer = 'C:\Windows\SysWOW64\msiexec.exe', 'C:\Windows\System32\msiexec.exe' | Where-Object { [System.IO.File]::Exists($_) } | Select-Object -First 1
    }
    if (!$MsiPath) {
        $MsiPath = Join-Path $dir ($fname | Select-Object -First 1)
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

    A-Invoke-InstallerProcess -FilePath $Installer -ArgumentList $ArgumentList -TimeoutSec $TimeoutSec

    try {
        if ($MsiPath -and (A-Test-File $MsiPath)) {
            Remove-Item -LiteralPath $MsiPath -Force -ErrorAction Stop
        }
    }
    catch {
        error $_.Exception.Message
    }

    $log = Get-Content -LiteralPath $logPath -ErrorAction SilentlyContinue
    @{
        Installer      = $Installer
        Uninstaller    = $Installer
        ProductCode    = ($log | Select-String 'ProductCode = (.+)' | ForEach-Object { $_.Matches.Groups[1].Value.Trim() } | Select-Object -First 1)
        ProductName    = ($log | Select-String 'ProductName = (.+)' | ForEach-Object { $_.Matches.Groups[1].Value.Trim() } | Select-Object -First 1)
        ProductVersion = ($log | Select-String 'ProductVersion = (.+)' | ForEach-Object { $_.Matches.Groups[1].Value.Trim() } | Select-Object -First 1)
        Manufacturer   = ($log | Select-String 'Manufacturer = (.+)' | ForEach-Object { $_.Matches.Groups[1].Value.Trim() } | Select-Object -First 1)
        ArgumentList   = $ArgumentList
    } | ConvertTo-Json | Out-File -LiteralPath $abgox_abyss.path.InstallMsi -Force -Encoding utf8

    Remove-Item -LiteralPath $logPath -Force -ErrorAction SilentlyContinue

    A-Repair-Link
}

function A-Uninstall-Msi {
    param(
        [array]$ArgumentList
    )
    # msi 直接覆盖安装，无需卸载
    if ($cmd -eq 'update') { return }
    $InstallerInfoPath = $abgox_abyss.path.InstallMsi
    if (A-Test-File $InstallerInfoPath) {
        try {
            $InstallerInfo = Get-Content -LiteralPath $InstallerInfoPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
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
    if (!(A-Test-File $Uninstaller)) {
        warn "'$Uninstaller' not found."
        return
    }
    $ProductCode = $null
    $registryPaths = @(
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    :outerLoop foreach ($path in $registryPaths) {
        $uninstallKeys = Get-ChildItem -LiteralPath $path -ErrorAction SilentlyContinue
        foreach ($key in $uninstallKeys) {
            $item = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction SilentlyContinue
            if (!$item) { continue }
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
        if (A-Test-Path $p) {
            if (!(A-Test-DirectoryNotEmpty $p)) {
                try {
                    Remove-Item -LiteralPath $p -Force -Recurse -ErrorAction Stop
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
        $fontFile = Get-ChildItem -LiteralPath $dir -Recurse -File -Force -ErrorAction SilentlyContinue
        foreach ($file in $fontFile) {
            if ($file.Extension -in $ExtMap.Keys) {
                $FontType = $file.Extension.TrimStart('.')
                break
            }
        }
    }
    $filter = "*.$FontType"
    $currentBuildNumber = [int] (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue).CurrentBuildNumber
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
    $allFonts = Get-ChildItem -LiteralPath $dir -Filter $filter -Recurse -File -Force -ErrorAction SilentlyContinue
    if (!$allFonts) {
        error "No font file found in '$dir' with extension '$filter'"
        A-Show-IssueCreationPrompt
        A-Exit
    }
    $allFonts | ForEach-Object {
        $value = if ($global) { $_.Name } else { "$fontInstallDir\$($_.Name)" }
        try {
            New-ItemProperty -LiteralPath $registryKey -Name $_.Name.Replace($_.Extension, " ($($ExtMap[$_.Extension]))") -Value $value -Force -ErrorAction Stop | Out-Null
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
    } | ConvertTo-Json | Out-File -LiteralPath $abgox_abyss.path.Font -Force -Encoding utf8
    $fonts.Dispose()
}

function A-Uninstall-Font {
    $OutFile = $abgox_abyss.path.Font
    if (!(A-Test-File $OutFile)) { return }
    try { $FontType = Get-Content -LiteralPath $OutFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop | Select-Object -ExpandProperty FontType } catch { return }
    $filter = "*.$FontType"
    $ExtMap = @{
        '.ttf' = 'TrueType'
        '.otf' = 'OpenType'
        '.ttc' = 'TrueType'
    }
    $fontInstallDir = if ($global) { "$env:windir\Fonts" } else { "$env:LocalAppData\Microsoft\Windows\Fonts" }
    Get-ChildItem -LiteralPath $dir -Filter $filter -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
        Get-ChildItem -LiteralPath $fontInstallDir -Filter $_.Name -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                Rename-Item -LiteralPath $_.FullName -NewName $_.Name -ErrorVariable LockError -ErrorAction Stop
            }
            catch {
                error "Cannot uninstall '$app' font.`nIt is currently being used by another application.`nPlease close all applications that are using it (e.g. vscode) and try again."
                A-Exit
            }
        }
    }
    $registryRoot = if ($global) { 'HKLM' } else { 'HKCU' }
    $registryKey = "${registryRoot}:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    Get-ChildItem -LiteralPath $dir -Filter $filter -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-ItemProperty -LiteralPath $registryKey -Name $_.Name.Replace($_.Extension, " ($($ExtMap[$_.Extension]))") -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath "$fontInstallDir\$($_.Name)" -Force -ErrorAction SilentlyContinue
    }
    if ($cmd -eq 'uninstall') {
        warn "The '$app' Font family has been uninstalled successfully, but there may be system cache that needs to be restarted to fully remove."
    }
    Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
}

function A-Install-PowerToysRunPlugin {
    param(
        [string]$PluginName
    )
    $PluginsDir = "$env:LocalAppData\Microsoft\PowerToys\PowerToys Run\Plugins"
    $PluginPath = "$PluginsDir\$PluginName"
    try {
        if (A-Test-Path $PluginPath) {
            Write-Host "Removing $PluginPath"
            A-Remove-ToRecycleBin $PluginPath -ErrorAction Stop
        }
        $CopyingPath = if (A-Test-Directory "$dir\$PluginName") { "$dir\$PluginName" } else { $dir }
        A-Ensure-Directory (Split-Path $PluginPath -Parent)
        Write-Host "Copying $CopyingPath => $PluginPath"
        A-Copy-Item $CopyingPath $PluginPath

        @{ PluginName = $PluginName } | ConvertTo-Json | Out-File -LiteralPath $abgox_abyss.path.PowerToysRunPlugin -Force -Encoding utf8
    }
    catch {
        error $_.Exception.Message
        A-Show-IssueCreationPrompt
        A-Exit
    }
}

function A-Uninstall-PowerToysRunPlugin {
    $OutFile = $abgox_abyss.path.PowerToysRunPlugin
    if (!(A-Test-File $OutFile)) { return }
    $PluginsDir = "$env:LocalAppData\Microsoft\PowerToys\PowerToys Run\Plugins"
    try {
        $PluginName = Get-Content -LiteralPath $OutFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop | Select-Object -ExpandProperty PluginName
        $PluginPath = "$PluginsDir\$PluginName"
        if (A-Test-Path $PluginPath) {
            Write-Host "Removing $PluginPath"
            Remove-Item -LiteralPath $PluginPath -Recurse -Force -ErrorAction Stop
            Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        error $_.Exception.Message
        A-Show-IssueCreationPrompt
        A-Exit
    }
}
