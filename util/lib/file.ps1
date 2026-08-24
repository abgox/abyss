function A-Test-File {
    param (
        [string]$Path
    )
    [System.IO.File]::Exists($Path)
}
function A-Test-Directory {
    param (
        [string]$Path
    )
    [System.IO.Directory]::Exists($Path)
}
function A-Test-Path {
    param (
        [string]$Path
    )
    [System.IO.Path]::Exists($Path)
}

function A-Ensure-Directory {
    param (
        [string]$Path = $persist_dir
    )
    if (A-Test-Directory $Path) { return }
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function A-Test-DirectoryNotEmpty {
    param(
        [string]$Path
    )
    if (!A-Test-Directory $Path) {
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
        return $item.LinkType
    }
    catch {
        return $false
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
    if (!(A-Test-Path $Path)) {
        error "Source path does not exist: $Path"
        A-Show-IssueCreationPrompt
        A-Exit
    }
    $sourceItem = Get-Item -LiteralPath $Path
    $targetDir = Split-Path $Destination -Parent

    A-Ensure-Directory $targetDir

    $needCopy = $true
    if (A-Test-Path $Destination) {
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
    if (!(A-Test-Path $Path)) {
        return
    }
    $shell = New-Object -ComObject Shell.Application
    $shell.Namespace(0).ParseName($Path).InvokeVerb('delete')
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
    $installData = @{
        LinkPaths   = @()
        LinkTargets = @()
    }
    $_persistDir = $abgox_abyss.persist_dir, $persist_dir | Select-Object -First 1
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
        $installData | ConvertTo-Json | Out-File -FilePath $OutFile -Force -Encoding utf8

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
            if (A-Test-Path $linkPath) {
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
        文件编码，默认为 utf8 (统一为不带 BOM，与 PowerShell 7 的行为一致)
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
    if (A-Test-File $Path) {
        return
    }
    elseif (A-Test-Directory $Path) {
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
    # 兼容不同 PowerShell 版本的编码差异:
    # utf8 在 Windows PowerShell 5.1 中会写入 BOM，而 PowerShell 7 不会，这里统一为不带 BOM
    $useUtf8NoBom = $PSEdition -eq 'Desktop' -and $Encoding -in 'utf8', 'utf8NoBom'
    $encodingName = $Encoding
    if ($PSBoundParameters.ContainsKey('Content')) {
        # 当明确传递了 Content 参数时（包括空字符串或 $null）
        if ($useUtf8NoBom) {
            # Windows PowerShell 5.1 没有 utf8NoBom 编码名称，使用 .NET API 写入不带 BOM 的 UTF-8
            $text = if ($null -eq $Content) { '' } else { (@($Content) -join "`r`n") + "`r`n" }
            [System.IO.File]::WriteAllText($Path, $text, [System.Text.UTF8Encoding]::new($false))
            return
        }
        elseif ($PSEdition -eq 'Desktop') {
            # Windows PowerShell 5.1 不支持部分编码名称，映射为等效的编码名称
            switch ($encodingName) {
                'utf8Bom' { $encodingName = 'utf8' }
                'ansi' { $encodingName = 'Default' }
            }
        }
        Set-Content -Path $Path -Value $Content -Encoding $encodingName -Force
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
        if (A-Test-Path $expandPath) {
            if (A-Test-File $expandPath) {
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
            if (A-Test-File $extraPath) {
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
    if ($manifest.link -and !$abgox_abyss.skipLink) { A-New-Link }
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
        if (A-Test-Path $_) {
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
        if (A-Test-Path $p) {
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
