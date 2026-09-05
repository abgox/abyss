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
    return [bool](Get-ChildItem -LiteralPath $Path -Force | Select-Object -First 1)
}

function A-Remove-EmptyDirectory {
    param(
        [string]$Path,
        [string]$StopAt
    )
    $pp = [System.IO.Path]::GetDirectoryName($Path)
    $last = $null
    while ($pp -and $pp.StartsWith($StopAt, [System.StringComparison]::OrdinalIgnoreCase) -and $pp.Length -gt $StopAt.Length) {
        if (A-Test-DirectoryNotEmpty $pp) { break }
        try { Remove-Item -LiteralPath $pp -Force -ErrorAction Stop; $last = $pp } catch { break }
        $pp = [System.IO.Path]::GetDirectoryName($pp)
    }
    if ($last) { Write-Host "Removing $last" }
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
            Remove-Item -LiteralPath $Destination -Recurse -Force -ErrorAction SilentlyContinue
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
    [System.IO.Path]::Combine($parent, 'abgox.abyss')
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
        $isDirLink = $expandPath -like "$dir\*"
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
            if ((A-Test-Path $privatePath) -and !(A-Test-Path $sharedPath)) {
                try {
                    A-Ensure-Directory ([System.IO.Path]::GetDirectoryName($sharedPath))
                    Write-Host "Migrating $privatePath => $sharedPath"
                    Move-Item -LiteralPath $privatePath -Destination $sharedPath -Force -ErrorAction Stop
                    A-Remove-EmptyDirectory $privatePath ([System.IO.Path]::GetDirectoryName($persist_dir))
                }
                catch { error $_.Exception.Message }
            }
            $target = A-Replace-SpecialFolderPrefix $expandPath $sharedRoot
            if ($target -notlike "$sharedRoot\*") { $target = $target -replace '^[a-zA-Z]:', $sharedRoot }
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
    # 建链按深度浅→深：父链接先就位，子路径行为确定
    $order = @()
    if ($LinkPaths.Count -gt 0) { $order = 0..($LinkPaths.Count - 1) | Sort-Object { A-Get-LinkDepth $LinkPaths[$_] } }
    foreach ($i in $order) {
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
                $linkTarget = A-Replace-SpecialFolderPrefix $LinkPath $sharedRoot
                # 如果不在 $home 目录下，则去掉盘符
                if ($linkTarget -notlike "$sharedRoot\*") {
                    $linkTarget = $linkTarget -replace '^[a-zA-Z]:', $sharedRoot
                }
            }
        }
        $installData.LinkPaths += $linkPath
        $installData.LinkTargets += $linkTarget
        $installData | ConvertTo-Json | Out-File -LiteralPath $OutFile -Force -Encoding utf8

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
            Remove-Item -LiteralPath $linkTarget -Recurse -Force -ErrorAction SilentlyContinue
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
    # 由于字段可能包含可展开的环境变量，应该使用安装时储存的值而不是通过字段展开，以避免环境变量变化导致的不一致性
    $linksInUse = $null
    $abgox_abyss.path.LinkFile, $abgox_abyss.path.LinkDirectory | ForEach-Object {
        if (A-Test-Path $_) {
            $data = Get-Content -LiteralPath $_ -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
            if (!$data) { return }
            $LinkPaths = $data.LinkPaths
            $LinkTargets = $data.LinkTargets
            # 删链按深度深→浅：子链接先断，避免父断开后子路径无法解析
            $order = @()
            if ($LinkPaths.Count -gt 0) { $order = 0..($LinkPaths.Count - 1) | Sort-Object { A-Get-LinkDepth $LinkPaths[$_] } -Descending }
            foreach ($i in $order) {
                $p = $LinkPaths[$i]
                $overlap = $false
                if ($p -notlike "$dir\*") {
                    if ($null -eq $linksInUse) { $linksInUse = A-Get-LinksInUse }
                    if ($linksInUse -and $linksInUse.Contains($p)) { continue } # 他家正用：链和数据都留
                    $overlap = A-Test-LinkOverlap $p $linksInUse
                }
                $t = if ($LinkTargets -and $i -lt $LinkTargets.Count) { $LinkTargets[$i] } else { $null }
                if (A-Test-Link $p) {
                    try {
                        Write-Host "Unlinking $p"
                        Remove-Item -LiteralPath $p -Force -Recurse -ErrorAction Stop
                        A-Remove-EmptyDirectory $p ([System.IO.Path]::GetPathRoot($p))
                    }
                    catch {
                        error $_.Exception.Message
                    }
                }
                # 嵌套占用只断自己的链，目标数据可能属于他家，不删
                if ($purge -and !$overlap -and $t -and (A-Test-Path $t)) {
                    try {
                        Write-Host "Removing $t"
                        Remove-Item -LiteralPath $t -Force -Recurse -ErrorAction Stop
                        A-Remove-EmptyDirectory $t ([System.IO.Path]::GetPathRoot($t))
                    }
                    catch {
                        error $_.Exception.Message
                    }
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
            if ([System.String]::Equals([System.IO.Path]::GetFileName($appDir), $app, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
            $currentDir = [System.IO.Path]::Combine($appDir, 'current')
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
                Remove-Item -LiteralPath $p -Force -Recurse -ErrorAction Stop
                $parent = Split-Path $p -Parent
                if (!(A-Test-DirectoryNotEmpty $parent)) {
                    Write-Host "Removing $parent"
                    Remove-Item -LiteralPath $parent -Force -Recurse -ErrorAction Stop
                }
            }
            catch {
                error $_.Exception.Message
            }
        }
    }
}
