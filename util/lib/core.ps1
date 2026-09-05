#Requires -Version 5.1

function A-Exit {
    if ($cmd -eq 'install') {
        Microsoft.PowerShell.Utility\Write-Host
        scoop uninstall $app
    }
    exit 1
}

function A-Test-BucketName {
    if ($bucket -eq 'abyss') {
        return
    }
    error "You should use 'abyss' as the bucket name, but the current name is '$bucket'."
    error 'Refer to: https://abyss.abgox.com/docs/bucket-name'
    A-Exit
}

function A-Require-Admin {
    <#
    .SYNOPSIS
        要求以管理员权限运行
    #>
    if ($abgox_abyss.isAdmin) {
        return
    }
    error 'It requires admin permission. Please try again with admin permission.'
    error 'Refer to: https://abyss.abgox.com/docs/require-admin'
    A-Exit
}

function A-Deny-Manifest {
    <#
    .SYNOPSIS
        拒绝清单文件，提示用户使用新的清单文件
    #>
    $msg = $null
    switch ($manifest.version) {
        deprecated { $msg = "'$app' is deprecated." }
        pending { $msg = "'$app' is pending." }
        renamed { $msg = "'$app' is renamed to '$($manifest.renamed.new)'." }
        default { return }
    }
    error $msg
    error 'Refer to: https://abyss.abgox.com/docs/deny-manifest'
    A-Show-Notes
    A-Exit
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
        if (A-Test-Directory (appdir $_)) {
            error "'$app' conflicts with '$_'."
            error 'Refer to: https://abyss.abgox.com/docs/deny-if-app-conflict'
            A-Exit
        }
    }
}

function A-Deny-Update {
    <#
    .SYNOPSIS
        禁止通过 scoop 更新
    #>
    if ($cmd -ne 'update') {
        return
    }
    error "'$app' does not allow update by Scoop."
    error 'Refer to: https://abyss.abgox.com/docs/deny-update'
    A-Show-Notes
    A-Exit
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
        if ($can) { scoop hold $app }
    } -ArgumentList $AppName
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
    $newPath = [System.IO.Path]::Combine($Parent, $Path)
    if ([System.IO.Path]::IsPathRooted($newPath)) {
        return $newPath
    }
    return [System.IO.Path]::Combine($dir, $newPath)
}

function A-Resolve-SpecialPath {
    param([string]$Path)
    $result = $ExecutionContext.InvokeCommand.ExpandString($Path)
    foreach ($entry in $abgox_abyss.knownFolders ) {
        if ($result.StartsWith($entry.DefaultPrefix + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
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
        if ($Path.StartsWith($entry.Folder + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
            $relative = $entry.Name + $Path.Substring($entry.Folder.Length)
            $relative = $relative.TrimStart('\', '/')
            if (!$Replacement) { return $relative }
            return [System.IO.Path]::Combine($Replacement, $relative)
        }
    }
    $relative = $Path.Replace("$home\", '') -replace '^[a-zA-Z]:', ''
    $relative = $relative.TrimStart('\', '/')
    if (!$Replacement) { return $relative }
    return [System.IO.Path]::Combine($Replacement, $relative)
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

function A-Show-IssueCreationPrompt {
    # Write-Host "Please contact the bucket maintainer!" -ForegroundColor DarkRed -NoNewline
    Write-Host 'Something went wrong here.' -ForegroundColor DarkRed -NoNewline
    Write-Host "`nPlease try again or create a new issue by using the following link and paste your console output:`nhttps://github.com/abgox/abyss/issues/new?template=bug-report.yml" -ForegroundColor DarkRed
}
