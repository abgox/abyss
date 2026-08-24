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
            if (A-Test-Path $e) { $ExtraPaths += $e }
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
    if (A-Test-File $abgox_abyss.path.EnvPath) {
        $general_path = "$home\.local\bin", "$env:AppData\local\bin", "$env:LocalAppData\bin", "$env:LocalAppData\Microsoft\WindowsApps"
        $Paths += Get-Content $abgox_abyss.path.EnvPath -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json | Select-Object -ExpandProperty Paths | Where-Object { $_ -notin $general_path }
    }
    if (A-Test-File $abgox_abyss.path.Info) {
        $info = Get-Content $abgox_abyss.path.Info -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
        if ($info.location) {
            $Paths += $info.location
        }
    }
    $Paths = $Paths | Sort-Object -Unique
    foreach ($app_dir in $Paths) {
        if (!$app_dir) { continue }
        # 转义路径中的通配符字符(如 '['、']')，避免进程匹配失效
        $pattern = [System.Management.Automation.WildcardPattern]::Escape($app_dir) + '\*'
        $matched = (Get-Process).Where({ $_.Path -like $pattern })
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
        if (!$app_dir) { continue }
        $pattern = [System.Management.Automation.WildcardPattern]::Escape($app_dir) + '\*'
        $running_processes = (Get-Process).Where({ $_.Path -like $pattern }) | Out-String
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
    if (!$service) { return }
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

function A-Add-Path {
    param(
        [string[]]$Paths
    )
    if (get_config USE_ISOLATED_PATH) {
        Add-Path -Path ('%' + $scoopPathEnvVar + '%') -Global:$global
    }
    $oldPath = (Get-EnvVar -Name $scoopPathEnvVar -Global:$Global).Split(';')
    $Paths = $Paths | ForEach-Object { A-Resolve-SpecialPath $_ } | Where-Object { $_ -notin $oldPath }
    if (!$Paths) { return }
    Add-Path -Path $Paths -TargetEnvVar $scoopPathEnvVar -Global:$global
    @{ Paths = $Paths } | ConvertTo-Json | Out-File -FilePath $abgox_abyss.path.EnvPath -Force -Encoding utf8
}

function A-Remove-Path {
    $OutFile = $abgox_abyss.path.EnvPath
    if (!(A-Test-File $OutFile)) { return }
    $general_path = "$home\.local\bin", "$env:AppData\local\bin", "$env:LocalAppData\bin", "$env:LocalAppData\Microsoft\WindowsApps"
    $Path = Get-Content $OutFile -Raw | ConvertFrom-Json | Select-Object -ExpandProperty Paths | Where-Object { $_ -notin $general_path }
    if (!$Path) { return }
    Remove-Path -Path $Path -Global:$global
    Remove-Path -Path $Path -TargetEnvVar $scoopPathEnvVar -Global:$global
    Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
}

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
            if ($has_other_owner) { return }
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
