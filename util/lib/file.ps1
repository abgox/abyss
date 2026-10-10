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
    if ($PSEdition -eq 'Core') {
        return [System.IO.Path]::Exists($Path)
    }
    Test-Path -LiteralPath $Path
}

function A-Test-PathPrefix {
    <#
    .SYNOPSIS
        判断路径是否位于指定目录下
    .DESCRIPTION
        不能用 -like "$Prefix\*" 判断，因为路径中的通配符（[、]、?、*）会被 -like 解析，导致误判。
    #>
    param(
        [string]$Path,
        [string]$Prefix
    )
    if (!$Path -or !$Prefix) { return $false }
    return $Path.StartsWith($Prefix.TrimEnd('\', '/') + '\', [System.StringComparison]::OrdinalIgnoreCase)
}

function A-Get-AppCurrentDir {
    <#
    .SYNOPSIS
        解析应用的有效目录（兼容 scoop 的 no_junction 配置）
    .DESCRIPTION
        no_junction 关闭时直接返回 current 目录；开启时 scoop 不再创建 current 链接，
        此时按官方 Get-InstalledVersion 逻辑取最新版本目录，找不到则回退到 current。
    #>
    param(
        [string]$AppDir
    )
    $current = [System.IO.Path]::Combine($AppDir, 'current')
    if (!(get_config NO_JUNCTION)) { return $current }
    $latest = Get-ChildItem "$AppDir\*\scoop-install.json", "$AppDir\*\install.json" -ErrorAction SilentlyContinue |
    Where-Object { ($_.Directory.Name -ne 'current') -and ($_.Directory.Name -notlike '_*.old*') } |
    Sort-Object -Property LastWriteTimeUtc | Select-Object -Last 1
    if ($latest) { return $latest.Directory.FullName }
    return $current
}

function A-Ensure-Directory {
    param (
        [string]$Path = $persist_dir
    )
    if (!$Path) { return }
    if (A-Test-Directory $Path) { return }
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function A-Test-DirectoryNotEmpty {
    param(
        [string]$Path
    )
    if (!(A-Test-Directory $Path)) {
        return $false
    }
    return [bool](Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue | Select-Object -First 1)
}

function A-Remove-EmptyDirectory {
    param(
        [string]$Path,
        [string]$StopAt
    )
    $stop = $StopAt.TrimEnd('\', '/')
    $pp = [System.IO.Path]::GetDirectoryName($Path)
    $last = $null
    while ($pp) {
        if ($pp.TrimEnd('\', '/') -eq $stop) { break }
        if (!(A-Test-PathPrefix $pp $StopAt)) { break }
        if (A-Test-DirectoryNotEmpty $pp) { break }
        A-Remove-Tree $pp
        if (A-Test-Path $pp) { break }
        $last = $pp
        $pp = [System.IO.Path]::GetDirectoryName($pp)
    }
    if ($last) { Write-Host "Removing $last" }
}

function A-Test-Link {
    <#
    .SYNOPSIS
        返回链接类型：'SymbolicLink' / 'Junction' / 'HardLink'；非链接返回 $null
    #>
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

function A-Test-SoftLink {
    # 只认 SymbolicLink / Junction，排除 HardLink 和非链接
    param([string]$Path)
    (A-Test-Link $Path) -in @('SymbolicLink', 'Junction')
}

function A-Get-LinkTarget {
    <#
    .SYNOPSIS
        返回软链接指向的绝对路径；不是软链接或无目标时返回 $null
    .NOTES
        Junction 的目标恒为绝对路径；符号链接可能是相对路径，此时按链接所在目录解析
    #>
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if (!$item -or ($item.LinkType -notin @('SymbolicLink', 'Junction'))) { return $null }
    $target = @($item.Target)[0]
    if (!$target) { return $null }
    if ([System.IO.Path]::IsPathRooted($target)) { return $target }
    [System.IO.Path]::Combine((Split-Path $item.FullName -Parent), $target)
}

function A-Test-LinkPointsTo {
    # $Path 是链接，且直接指向 $Target 时返回 $true
    param([string]$Path, [string]$Target)
    # 注意：局部变量不能叫 $target，与参数 $Target 冲突（PS 变量名大小写不敏感），会覆盖参数
    $resolved = A-Get-LinkTarget $Path
    if (!$resolved -or !$Target) { return $false }
    try {
        $a = [System.IO.Path]::GetFullPath($resolved).TrimEnd('\', '/')
        $b = [System.IO.Path]::GetFullPath($Target).TrimEnd('\', '/')
        return $a -ieq $b
    }
    catch { return $false }
}

function A-Clear-ReadOnly {
    <#
    .SYNOPSIS
        去掉只读属性，使 .NET 的 Delete 能成功
    .NOTES
        对 Junction / 符号链接只影响链接本身，不会污染目标项
    #>
    param([string]$Path)
    try {
        $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
        $item.Attributes = [IO.FileAttributes]($item.Attributes -band (-bnot [IO.FileAttributes]::ReadOnly))
    }
    catch {}
}

function A-Remove-FileItem {
    param([string]$Path)
    try {
        A-Clear-ReadOnly $Path
        [System.IO.File]::Delete($Path)
    }
    catch { warn "Remove failed: $Path ($($_.Exception.Message))" }
}

function A-Remove-DirectoryItem {
    # 递归删除；遇到内部链接只摘链接，不穿透到目标内容
    param([string]$Path)
    try {
        $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            A-Clear-ReadOnly $Path
            [System.IO.Directory]::Delete($Path, $false)
            return
        }
        $dir = [System.IO.DirectoryInfo]::new($Path)
        try { $subs = @($dir.EnumerateDirectories()) } catch { $subs = @() }
        try { $files = @($dir.EnumerateFiles()) } catch { $files = @() }
        foreach ($sub in $subs) { A-Remove-DirectoryItem $sub.FullName }
        foreach ($file in $files) { A-Remove-FileItem $file.FullName }
        A-Clear-ReadOnly $Path
        [System.IO.Directory]::Delete($Path, $false)
    }
    catch { warn "Remove failed: $Path ($($_.Exception.Message))" }
}

function A-Remove-Tree {
    <#
    .SYNOPSIS
        递归删除，遇到内部链接只删链接，不穿透（替代 Remove-Item -Recurse）
    .NOTES
        纯 .NET 实现：删除前对只读项先清属性
    #>
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if (!$item) { return }
    if ($item.PSIsContainer) { A-Remove-DirectoryItem $item.FullName }
    else { A-Remove-FileItem $item.FullName }
}

function A-Remove-LinkItem {
    <#
    .SYNOPSIS
        只删除链接本身，绝不穿透到目标内容（含悬空链接）
    .NOTES
        不是 SymbolicLink/Junction 时什么都不做，避免误删真实目录；失败只告警不抛异常
    #>
    param([string]$Path)
    if (!(A-Test-SoftLink $Path)) { return }
    try {
        if ((Get-Item -LiteralPath $Path -Force -ErrorAction Stop).PSIsContainer) {
            A-Clear-ReadOnly $Path
            [System.IO.Directory]::Delete($Path, $false)
        }
        else {
            A-Remove-FileItem $Path
        }
    }
    catch { warn "Unlink failed: $Path ($($_.Exception.Message))" }
}

function A-Copy-Link {
    <#
    .SYNOPSIS
        在 Destination 重建与 Path 同类型、同指向的链接，成功返回 $true
    .NOTES
        指向不存在（悬空）或没有创建符号链接的权限时 New-Item 会失败，
        此时返回 $false，由调用方回退为直接改名
    #>
    param([string]$Path, [string]$Destination)
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if (!$item -or ($item.LinkType -notin @('SymbolicLink', 'Junction'))) { return $false }
    $target = A-Get-LinkTarget $Path
    if (!$target) { return $false }
    A-Ensure-Directory (Split-Path $Destination -Parent)
    try {
        New-Item -ItemType $item.LinkType -Path $Destination -Target $target -Force -ErrorAction Stop | Out-Null
        return $true
    }
    catch { return $false }
}

function A-Get-RobocopyLinkFlags {
    <#
    .SYNOPSIS
        返回目录内链接的处理开关；无开关时不输出任何内容
    .DESCRIPTION
        $Source 本身是链接时不输出——带 /SJ 会让 robocopy 把根链接当链接复制，
        而不跟随它取真实内容（实测 EXIT=0 且目标只剩一个链接）。
        否则有权限用 /SJ（按链接复制），无权限用 /XJ（跳过链接）。
    .NOTES
        根不是链接时必须带 /SJ 或 /XJ：robocopy 默认跟随链接，会把链接指向的外部数据
        一并复制，配合 /MOVE 则直接删掉外部数据。

        调用方必须写成 @(A-Get-RobocopyLinkFlags $X) 再 splat。实测 PowerShell 5.1 下
        把标量字符串 splat 在参数中间会让它之后的所有参数全部丢失（/XJ 与 /R:1 都被
        丢掉，重试次数退回默认 1000000），导致 /XJ 失效并跟随链接删掉外部数据
    #>
    param([string]$Source)
    if (A-Test-SoftLink $Source) { return }
    if ($abgox_abyss.isAdmin -or $abgox_abyss.isDevMode) { '/SJ' } else { '/XJ' }
}

function A-Test-RobocopyFailure {
    <#
    .SYNOPSIS
        判断 robocopy 退出码是否代表失败
    .NOTES
        0-3 成功（3 = 有额外文件）；4-7 是警告（部分文件跳过/不匹配），
        对"新者胜"的合并语义可以接受。
        >= 8 一律失败。实测（带 /R:1 /W:1 正确传参时）：
        - /XO 或 /XJ 把源内容全部跳过    -> 退出码 0，不是 16
        - 目标是已存在的文件             -> 退出码 16（ERROR 267 目录名无效）
        - 源是悬空链接/不可达            -> 退出码 16（ERROR 3 找不到路径）
        所以对 16 绝不能放行，否则 robocopy 之后那句 A-Remove-Tree $Path
        会把源数据删掉，而目标什么都没有
    #>
    param([int]$Code)
    $Code -ge 8
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
    if ((A-Test-LinkPointsTo $Path $Destination) -or (A-Test-LinkPointsTo $Destination $Path)) { return }
    $sourceItem = Get-Item -LiteralPath $Path -Force
    A-Ensure-Directory (Split-Path $Destination -Parent)

    # 源是指向不存在目标的链接时，robocopy 只会返回 16 和一个空目标
    if (A-Test-SoftLink $Path) {
        $sourceRoot = A-Get-LinkTarget $Path
        if (!$sourceRoot -or !(A-Test-Path $sourceRoot)) {
            error "Source link is dangling: $Path"
            A-Show-IssueCreationPrompt
            A-Exit
        }
    }

    $needCopy = $true
    if ((A-Test-Path $Destination) -or (A-Test-Link $Destination)) {
        $targetItem = Get-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
        if ($targetItem -and ($sourceItem.PSIsContainer -eq $targetItem.PSIsContainer)) {
            $needCopy = $targetItem.PSIsContainer -and !(A-Test-DirectoryNotEmpty $Destination)
        }
    }
    if ($needCopy) {
        try {
            # 先清旧数据再复制
            A-Remove-ToRecycleBin $Destination -ErrorAction SilentlyContinue
            if ($sourceItem.PSIsContainer) {
                # 源本身是目录链接：robocopy 以它为根取真实内容，所以根为链接时不能带 /SJ
                $flags = @(A-Get-RobocopyLinkFlags $Path)
                $result = & robocopy "$Path" "$Destination" /E @flags /MT:16 /R:1 /W:1 /NP /NFL /NDL /NJH /NJS 2>&1
                if (A-Test-RobocopyFailure $LASTEXITCODE) { throw $result }
            }
            else {
                # File.Copy 对文件链接的行为确定：复制目标内容
                [System.IO.File]::Copy($sourceItem.FullName, [System.IO.Path]::GetFullPath($Destination), $true)
            }
            Write-Host "Copying $Path => $Destination"
        }
        catch {
            A-Remove-Tree $Destination
            error $_
            A-Show-IssueCreationPrompt
            A-Exit
        }
    }
}

function A-Move-Item {
    <#
    .SYNOPSIS
        移动文件或目录：目标不存在则整个移动，已存在则合并（新者胜）

    .EXAMPLE
        A-Move-Item $old $new
    #>
    param (
        [string]$Path,
        [string]$Destination
    )
    if (!(A-Test-Path $Path)) {
        return
    }
    Write-Host "Moving $Path => $Destination"
    # 源与目标是同一个位置时，合并分支走完后 A-Remove-Tree $Path 会把目标一起删掉
    if ([System.IO.Path]::GetFullPath($Path) -eq [System.IO.Path]::GetFullPath($Destination)) { return }
    try {
        $srcIsLink = A-Test-SoftLink $Path
        # 源链接已指向目标时移动无意义，且会继续操作让目标自引用
        if ($srcIsLink -and (A-Test-LinkPointsTo $Path $Destination)) { return }
        $destExists = (A-Test-Path $Destination) -or (A-Test-Link $Destination)   # 含悬空链接
        if (!$destExists) {
            A-Ensure-Directory ([System.IO.Path]::GetDirectoryName($Destination))
            if ($srcIsLink -and !(A-Copy-Link $Path $Destination)) {
                # 无法重建链接（指向悬空/无权限）时直接改名：同卷改名只动重解析点，不碰目标内容
                Move-Item -LiteralPath $Path -Destination $Destination -Force -ErrorAction Stop
            }
            elseif ($srcIsLink) {
                A-Remove-LinkItem $Path
            }
            else {
                # 调用方都在同一卷内，这里是改名，内部链接原样保留
                Move-Item -LiteralPath $Path -Destination $Destination -Force -ErrorAction Stop
            }
        }
        elseif ($srcIsLink) {
            # 源是链接且目标已存在：把链接指向的真实内容合并进来（新者胜），然后只摘链接
            # 文件链接极少出现，保守处理：保留目标，丢弃链接
            # 从链接的真实目标发起 robocopy，这样 /SJ 只作用于内部链接，不会把根链接当链接复制
            $srcRoot = A-Get-LinkTarget $Path
            if ($srcRoot -and (A-Test-Directory $srcRoot) -and (A-Test-Directory $Destination)) {
                $flags = @(A-Get-RobocopyLinkFlags $srcRoot)
                $result = & robocopy "$srcRoot" "$Destination" /E /XO @flags /MT:16 /R:1 /W:1 /NP /NFL /NDL /NJH /NJS 2>&1
                if (A-Test-RobocopyFailure $LASTEXITCODE) { throw $result }
            }
            A-Remove-LinkItem $Path
        }
        elseif ((A-Test-File $Path) -and (A-Test-File $Destination)) {
            if ((Get-Item -LiteralPath $Path -Force).LastWriteTimeUtc -gt (Get-Item -LiteralPath $Destination -Force).LastWriteTimeUtc) {
                Move-Item -LiteralPath $Path -Destination $Destination -Force -ErrorAction Stop
            }
            else {
                Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
            }
        }
        else {
            $flags = @(A-Get-RobocopyLinkFlags $Path)
            $result = & robocopy "$Path" "$Destination" /E /MOVE /XO @flags /MT:16 /R:1 /W:1 /NP /NFL /NDL /NJH /NJS 2>&1
            if (A-Test-RobocopyFailure $LASTEXITCODE) { throw $result }
            A-Remove-Tree $Path
        }
    }
    catch {
        error $_.Exception.Message
        A-Show-IssueCreationPrompt
        A-Exit
    }
}

function A-Remove-ToRecycleBin {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    if (A-Test-SoftLink $Path) {
        A-Remove-LinkItem $Path
        return
    }
    if (!(A-Test-Path $Path)) {
        return
    }
    $shell = New-Object -ComObject Shell.Application
    $toDelete = $shell.Namespace(0).ParseName($Path)
    if ($toDelete) {
        $toDelete.InvokeVerb('delete')
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
        Set-Content -LiteralPath $Path -Value $Content -Encoding $encodingName -Force
    }
    else {
        # 当没有传递 Content 参数时
        New-Item -ItemType File -Path $Path -Force | Out-Null
    }
}

function A-Get-SharedPersistRoot {
    $parent = [System.IO.Path]::GetDirectoryName($persist_dir)
    if (!$parent) { $parent = $persist_dir }
    [System.IO.Path]::Combine($parent, '@abgox.abyss')
}

function A-Resolve-LinkTargets {
    <#
    .SYNOPSIS
        解析 link 条目：迁移、私有/共享、文件/目录分类
    #>
    param(
        [array]$LinkItems
    )
    $filePaths = @()
    $fileTargets = @()
    $dirPaths = @()
    $dirTargets = @()
    $sharedRoot = A-Get-SharedPersistRoot
    foreach ($item in $LinkItems) {
        if (!$item) { continue }
        $expandPath = A-Resolve-SpecialPath $item
        $isDirLink = A-Test-PathPrefix $expandPath $dir
        if ($isDirLink) {
            $leaf = $expandPath.Replace("$dir\app\", '').Replace("$dir\", '')
            $privatePath = [System.IO.Path]::Combine($persist_dir, $leaf)
            $sharedPath = $null
            $target = $expandPath.Replace("$dir\app\", "$persist_dir\").Replace("$dir\", "$persist_dir\")
        }
        else {
            $rel = A-Replace-SpecialFolderPrefix $expandPath
            $privatePath = [System.IO.Path]::Combine($persist_dir, $rel)
            $sharedPath = [System.IO.Path]::Combine($sharedRoot, $rel)
            if (A-Test-Path $privatePath) {
                A-Move-Item $privatePath $sharedPath
                A-Remove-EmptyDirectory $privatePath ([System.IO.Path]::GetDirectoryName($persist_dir))
            }
            else {
                $oldSharedPath = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($sharedRoot), 'abgox.abyss', $rel)
                if (A-Test-Path $oldSharedPath) {
                    A-Move-Item $oldSharedPath $sharedPath
                    A-Remove-EmptyDirectory $oldSharedPath ([System.IO.Path]::GetDirectoryName($persist_dir))
                }
            }
            $target = A-Replace-SpecialFolderPrefix $expandPath $sharedRoot
            if (!(A-Test-PathPrefix $target $sharedRoot)) { $target = $target -replace '^[a-zA-Z]:', $sharedRoot }
        }
        if (A-Test-Path $expandPath) {
            A-Copy-Item $expandPath $target
            if (A-Test-File $expandPath) {
                $filePaths += $expandPath
                $fileTargets += $target
            }
            else {
                $dirPaths += $expandPath
                $dirTargets += $target
            }
        }
        else {
            if ($isDirLink) {
                $leaf = $expandPath.Replace("$dir\app\", '').Replace("$dir\", '')
            }
            else {
                $leaf = A-Replace-SpecialFolderPrefix $expandPath
            }
            $extraPath = "$bucketsdir\$bucket\extra\$app\$leaf"
            if (A-Test-Path $extraPath) {
                $destLeaf = if ($isDirLink) { "$persist_dir\$leaf" } else { [System.IO.Path]::Combine($sharedRoot, $leaf) }
                A-Copy-Item $extraPath $destLeaf
            }
            if (A-Test-File $extraPath) {
                $filePaths += $expandPath
                $fileTargets += $target
            }
            else {
                $dirPaths += $expandPath
                $dirTargets += $target
            }
        }
    }
    return @{
        FilePaths   = $filePaths
        FileTargets = $fileTargets
        DirPaths    = $dirPaths
        DirTargets  = $dirTargets
    }
}

function A-Resolve-ViaLinks {
    <#
    .SYNOPSIS
        把路径沿已建立的链接逐段解析成物理路径（不依赖文件系统解析）
    .DESCRIPTION
        嵌套 link 场景（$dir\app\foo 与 $dir\app\foo\bar 同时是 link 条目）下，
        父链建好后子链的 linkPath 与 linkTarget 其实指向同一个目录。
        若仍按普通流程走，会先把该目录当旧数据回收，再建链失败。
    #>
    param(
        [string]$Path,
        [array]$Links
    )
    $p = [System.IO.Path]::GetFullPath($Path)
    if (!$Links -or $Links.Count -eq 0) { return $p }
    $changed = $true
    while ($changed) {
        $changed = $false
        foreach ($l in $Links) {
            $lp = [System.IO.Path]::GetFullPath($l.Path)
            $lt = [System.IO.Path]::GetFullPath($l.Target)
            if ($lp.Length -lt $p.Length -and $p.StartsWith($lp + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
                $p = $lt + $p.Substring($lp.Length)
                $changed = $true
            }
        }
    }
    return $p
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
    $sharedRoot = A-Get-SharedPersistRoot
    # 已处理的链接，用于把后续 linkPath 解析成物理路径
    $linked = @()
    # 建链按深度浅→深：父链接先就位，子路径行为确定
    $order = @()
    if ($LinkPaths.Count -gt 0) { $order = 0..($LinkPaths.Count - 1) | Sort-Object { A-Get-LinkDepth $LinkPaths[$_] } }
    foreach ($i in $order) {
        $linkPath = $LinkPaths[$i]
        if ($LinkTargets[$i]) {
            $linkTarget = A-Get-AbsolutePath $LinkTargets[$i] $_persistDir
        }
        else {
            if (A-Test-PathPrefix $LinkPath $dir) {
                # 只有无法使用 persist 字段的特殊情况才能使用它，例如: liule.Snipaste
                $linkTarget = $LinkPath.replace("$dir\app\", "$_persistDir\").replace("$dir\", "$_persistDir\")
            }
            else {
                $linkTarget = A-Replace-SpecialFolderPrefix $LinkPath $sharedRoot
                # 如果不在 $home 目录下，则去掉盘符
                if (!(A-Test-PathPrefix $linkTarget $sharedRoot)) {
                    $linkTarget = $linkTarget -replace '^[a-zA-Z]:', $sharedRoot
                }
            }
        }
        $installData.LinkPaths += $linkPath
        $installData.LinkTargets += $linkTarget
        $installData | ConvertTo-Json | Out-File -LiteralPath $OutFile -Force -Encoding utf8

        $type = if ($OutFile -eq $abgox_abyss.path.LinkFile) { 'Leaf' } else { 'Container' }

        # 链接已指向正确目标且目标仍然存在时跳过，避免每次安装/更新都删除重建
        $targetExists = Test-Path -LiteralPath $linkTarget -PathType $type
        if ((A-Test-LinkPointsTo $linkPath $linkTarget) -and $targetExists) {
            # 已就位的链接同样要登记：后续子 link 的 linkPath 会经它解析
            $linked += [pscustomobject]@{ Path = $linkPath; Target = $linkTarget }
            continue
        }
        # 嵌套链接：父链就位后，linkPath 经父链解析就是 linkTarget 本身（同一目录）。
        # 这时不能再按"替换旧数据"走，否则会先把该目录回收、再建链失败。
        $resolvedPath = A-Resolve-ViaLinks $linkPath $linked
        $expectedTarget = [System.IO.Path]::GetFullPath($linkTarget)
        if ($resolvedPath -eq $expectedTarget) {
            $linked += [pscustomobject]@{ Path = $linkPath; Target = $linkTarget }
            continue
        }
        A-Ensure-Directory (Split-Path $linkPath -Parent)
        if ($targetExists) {
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
            A-Remove-Tree $linkTarget
            if ((Test-Path -LiteralPath $linkPath -PathType $type) -and !(A-Test-SoftLink $linkPath)) {
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
        try {
            New-Item -ItemType $ItemType -Path $linkPath -Target $linkTarget -Force -ErrorAction Stop | Out-Null
        }
        catch {
            error "Failed to create link: $linkPath => $linkTarget"
            error $_.Exception.Message
            A-Show-IssueCreationPrompt
            A-Exit
        }
        # New-Item 对已存在的目标是是非终止性错误，不会进上面的 catch，必须再确认一次
        if (!(A-Test-SoftLink $linkPath)) {
            error "Failed to create link: $linkPath => $linkTarget"
            error "The target may already exist, or the link type '$ItemType' may be unavailable for the current user."
            A-Show-IssueCreationPrompt
            A-Exit
        }
        Write-Host "Persisting (Link) $linkPath => $linkTarget"
        $linked += [pscustomobject]@{ Path = $linkPath; Target = $linkTarget }
    }
}

function A-New-Link {
    $resolved = A-Resolve-LinkTargets $manifest.link
    if ($resolved.FilePaths) { A-New-LinkFile -LinkPaths $resolved.FilePaths -LinkTargets $resolved.FileTargets }
    if ($resolved.DirPaths) { A-New-LinkDirectory -LinkPaths $resolved.DirPaths -LinkTargets $resolved.DirTargets }
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
    if (!$manifest.link) {
        $null = A-Resolve-LinkTargets $LinkPaths
    }
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
    $newRoot = A-Get-SharedPersistRoot
    $oldRoot = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($newRoot), 'abgox.abyss')
    # 由于字段可能包含可展开的环境变量，应该使用安装时储存的值而不是通过字段展开，以避免环境变量变化导致的不一致性
    $linksInUse = $null
    $abgox_abyss.path.LinkFile, $abgox_abyss.path.LinkDirectory | ForEach-Object {
        if (A-Test-Path $_) {
            try {
                $data = Get-Content -LiteralPath $_ -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction Stop
            }
            catch {
                warn "Failed to read link snapshot: $_"
                return
            }
            if (!$data) { return }
            $LinkPaths = $data.LinkPaths
            $LinkTargets = $data.LinkTargets
            # 删链按深度深→浅：子链接先断，避免父断开后子路径无法解析
            $order = @()
            if ($LinkPaths.Count -gt 0) { $order = 0..($LinkPaths.Count - 1) | Sort-Object { A-Get-LinkDepth $LinkPaths[$_] } -Descending }
            foreach ($i in $order) {
                $p = $LinkPaths[$i]
                $overlap = $false
                if (!(A-Test-PathPrefix $p $dir)) {
                    if ($null -eq $linksInUse) { $linksInUse = A-Get-LinksInUse }
                    if ($linksInUse -and $linksInUse.Contains($p)) { continue } # 他家正用：链和数据都留
                    $overlap = A-Test-LinkOverlap $p $linksInUse
                }
                $t = if ($LinkTargets -and $i -lt $LinkTargets.Count) { $LinkTargets[$i] } else { $null }
                if (A-Test-SoftLink $p) {
                    try {
                        Write-Host "Unlinking $p"
                        A-Remove-LinkItem $p
                        A-Remove-EmptyDirectory $p ([System.IO.Path]::GetPathRoot($p))
                    }
                    catch {
                        error $_.Exception.Message
                    }
                }
                if (!$t -or $overlap -or !(A-Test-Path $t)) { continue }
                if ($purge) {
                    try {
                        Write-Host "Removing $t"
                        A-Remove-Tree $t
                        A-Remove-EmptyDirectory $t ([System.IO.Path]::GetPathRoot($t))
                    }
                    catch {
                        error $_.Exception.Message
                    }
                }
                elseif (A-Test-PathPrefix $t $oldRoot) {
                    A-Move-Item $t ($newRoot + $t.Substring($oldRoot.Length))
                    A-Remove-EmptyDirectory $t ([System.IO.Path]::GetPathRoot($t))
                }
            }
        }
    }
}

function A-Get-LinksInUse {
    <#
    .SYNOPSIS
        一次性收集其他应用占用的共享链接（绝对路径快照比对）
    #>
    $inUse = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $roots = @($scoopdir)
    if ($globaldir -and $globaldir -ne $scoopdir) { $roots += $globaldir }
    $selfDir = Split-Path $dir -Parent
    $snapNames = @(
        (Split-Path $abgox_abyss.path.LinkFile -Leaf),
        (Split-Path $abgox_abyss.path.LinkDirectory -Leaf)
    )
    foreach ($root in $roots) {
        if (!$root) { continue }
        $appsRoot = [System.IO.Path]::Combine($root, 'apps')
        if (![System.IO.Directory]::Exists($appsRoot)) { continue }
        try { $appDirs = [System.IO.Directory]::GetDirectories($appsRoot) } catch { continue }
        foreach ($appDir in $appDirs) {
            if ([System.String]::Equals($appDir, $selfDir, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
            $currentDir = A-Get-AppCurrentDir $appDir
            foreach ($snap in $snapNames) {
                $snapFile = [System.IO.Path]::Combine($currentDir, $snap)
                if (![System.IO.File]::Exists($snapFile)) { continue }
                try { $json = [System.IO.File]::ReadAllText($snapFile) } catch { continue }
                try { $data = $json | ConvertFrom-Json -ErrorAction Stop } catch { continue }
                foreach ($p in @($data.LinkPaths)) {
                    if ($p) { $null = $inUse.Add($p) }
                }
            }
        }
    }
    Write-Output -InputObject $inUse -NoEnumerate
}

function A-Test-LinkInUse {
    param([string]$LinkPath)
    $inUse = A-Get-LinksInUse
    if ($null -eq $inUse) { return $false }
    return $inUse.Contains($LinkPath)
}

function A-Test-LinkOverlap {
    <#
    .SYNOPSIS
        判断某路径是否与占用集合中的任一条存在嵌套（相等除外）

    .DESCRIPTION
        精确相等由 HashSet.Contains 判定；这里只判父子包含（双向），
        用于父目录被一家链接、子目录被另一家链接的场景。
        比较带分隔符边界，避免 `Foo` 误命中 `FooBar`。
    #>
    param(
        [string]$LinkPath,
        [System.Collections.Generic.HashSet[string]]$InUse
    )
    if (!$LinkPath -or $null -eq $InUse -or $InUse.Count -eq 0) { return $false }
    $mine = $LinkPath.TrimEnd('\', '/')
    foreach ($other in $InUse) {
        if (!$other) { continue }
        $o = $other.TrimEnd('\', '/')
        if ($o.Length -eq $mine.Length) { continue } # 相等走精确判定，这里跳过
        if ($mine.Length -gt $o.Length) {
            if ($mine.StartsWith($o + '\', [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
        }
        else {
            if ($o.StartsWith($mine + '\', [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
        }
    }
    return $false
}

function A-Get-LinkDepth {
    param([string]$Path)
    if (!$Path) { return 0 }
    return @($Path.TrimEnd('\', '/') -split '[\\/]').Count
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
                A-Remove-Tree $p
                $parent = Split-Path $p -Parent
                if ($parent -and !(A-Test-DirectoryNotEmpty $parent)) {
                    Write-Host "Removing $parent"
                    A-Remove-Tree $parent
                }
            }
            catch {
                error $_.Exception.Message
            }
        }
    }
}
