#Requires -PSEdition Core

function Compare-Version {
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

$headers = @{}

if ($env:GITHUB_TOKEN) {
    $headers['Authorization'] = "Bearer $env:GITHUB_TOKEN"
}

$version = Get-Content -Path "$PSScriptRoot\..\scoop.json" | ConvertFrom-Json | Select-Object -ExpandProperty version

try {
    $latestVersionTag = Invoke-RestMethod -Uri 'https://api.github.com/repos/scoopinstaller/scoop/releases/latest' -Headers $headers | Select-Object -ExpandProperty tag_name

    if ($latestVersionTag) {
        $newVersion = $latestVersionTag.TrimStart('v')
    }
    Write-Host "OldVersion: $version"
    Write-Host "NewVersion: $newVersion"
    if ((Compare-Version $newVersion $version) -gt 0) {
        "ScoopNewVersion=$newVersion" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
    }
}
catch {}
