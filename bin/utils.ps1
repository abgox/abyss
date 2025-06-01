Write-Host


# 一个临时文件，用于保存安装时的一些数据，以便在卸载时使用这些数据
$scoop_temp_config_path = "$dir\scoop-script-temp-data.jsonc"

# 卸载时的操作等级。如果未设置，则默认为 1。它们可以随意组合，如 12 表示 1 和 2 都要执行。
#   0: 无额外操作
#   1: 卸载之前尝试暂停进程
#   2: 如果有 Link Directory，则删除 Link Directory
#   3: 如果有临时数据，则删除临时数据
$actionLevel = (scoop config).'action-level-when-uninstall'
if ($actionLevel -eq $null) {
    $actionLevel = 1
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
        A-Ensure-Directory "C:\a\b\c\d"
    #>
    param (
        [Parameter(Position = 0, ValueFromPipeline, HelpMessage = "Directory path to be ensured")]
        [string]
        $Path = $persist_dir
    )
    if (!(Test-Path $Path)) {
        Write-Host "Creating directory: $Path" -ForegroundColor Yellow
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
        A-New-LinkDirectory -linkPaths @("C:\dir1", "C:\dir2") -linkTargets @("D:\target1", "D:\target2")
        将 C:\dir1 和 C:\dir2 替换为指向 D:\target1 和 D:\target2 的符号链接

    .LINK
        https://github.com/abgox/abyss#link
        https://gitee.com/abgox/abyss#link
    #>
    param (
        [Parameter(Position = 0, HelpMessage = "Array of source paths to be replaced with links")]
        [array]
        $LinkPaths, # 源路径数组（将被替换为链接）

        [Parameter(Position = 1, HelpMessage = "Array of target paths that the links will point to")]
        [array]
        $LinkTargets # 目标路径数组（链接指向的位置）
    )

    # 检查参数数量是否匹配
    if ($LinkPaths.Count -ne $LinkTargets.Count) {
        throw "The script in this manifest is incorrectly defined."
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
                Write-Host "Copying $linkPath => $linkTarget" -ForegroundColor Yellow
                Copy-Item -Path $linkPath -Destination $linkTarget -Recurse -Force
            }
            Write-Host "Removing $linkPath" -ForegroundColor Yellow
            try {
                Remove-Item $linkPath -Recurse -Force -ErrorAction Stop
            }
            catch {
                Write-Host "Failed to $cmd $app." -ForegroundColor Red
                Write-Host "Please stop the relevant processes and try to $cmd $app again." -ForegroundColor Red
                Write-Host
                throw "Failed to remove the directory: $linkPath"
            }
        }
        A-Ensure-Directory $linkTarget
        New-Item -ItemType Junction -Path $linkPath -Target $linkTarget -Force | Out-Null
        Write-Host "Linking $linkPath => $linkTarget" -ForegroundColor Yellow
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
        A-New-PersistFile -path "C:\test\file.json" -content "{}"
        创建文件并指定内容

    .EXAMPLE
        A-New-PersistFile -path "C:\test\file.txt"
        创建空文件（不指定内容）
    #>
    param (
        [Parameter(Position = 0, ValueFromPipeline, HelpMessage = "Files to be created")]
        [string]$Path,

        [Parameter(HelpMessage = "Content of the file to be created")]
        [string]$Content,

        [Parameter(HelpMessage = "Encoding of the file to be created")]
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
        Stop-App -path @("C:\Program Files\MyApp", "D:\Services")
        停止从这两个目录运行的所有进程

    .EXAMPLE
        Get-ChildItem "C:\Apps" -Directory | Stop-App
        通过管道传入目录路径来停止相关进程
    #>
    param(
        [Parameter(Position = 0, ValueFromPipeline, HelpMessage = "Array of extra paths to search for executables")]
        [string[]]
        $ExtraPaths = @()
    )

    $Path = @($dir, (Split-Path $dir -Parent) + '\current')
    $Path += $ExtraPaths

    if ($actionLevel -notlike "*1*") {
        return
    }

    $processes = Get-Process

    foreach ($app_dir in $Path) {
        $matched = $processes.where({ $_.Modules.FileName -like "$app_dir\*" })
        foreach ($_ in $matched) {
            try {
                Stop-Process -Id $_.Id -Force -ErrorAction Stop
                Wait-Process -Id $_.Id -ErrorAction Stop -Timeout 30
            }
            catch {
                # TODO: 是否因为没有管理员权限无法禁止进程？
                Write-Debug "Cannot stop process $($_.Id): $_"
            }
        }
    }
    Start-Sleep -Seconds 1
}

function A-Remove-LinkDirectory {
    param (
        [Parameter(Position = 0, HelpMessage = "Array of paths to remove")]
        [array]
        $LinkPaths
    )

    if ($cmd -eq "update" -or $actionLevel -notlike "*2*") {
        return
    }
    if (!$PSBoundParameters.ContainsKey('LinkPaths') -and (Test-Path $scoop_temp_config_path)) {
        $LinkPaths = Get-Content $scoop_temp_config_path | ConvertFrom-Json | Select-Object -ExpandProperty "LinkPaths"
    }
    foreach ($_ in $LinkPaths) {
        if (Test-Path $_ ) {
            Write-Host "Removing link directory: $_" -ForegroundColor Yellow
        }
        Remove-Item $_ -Force -Recurse -ErrorAction SilentlyContinue
    }
}

function A-Remove-TempData {
    param (
        [Parameter(Position = 0, HelpMessage = "Array of paths to remove")]
        [array]
        $Paths
    )

    if ($cmd -eq "update" -or $actionLevel -notlike "*3*") {
        return
    }
    foreach ($_ in $Paths) {
        if (Test-Path $_ ) {
            Write-Host "Removing Temp data: $_" -ForegroundColor Yellow
        }
        Remove-Item $_ -Force -Recurse -ErrorAction SilentlyContinue
    }
}
