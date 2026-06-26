$RawInput = Get-Clipboard -Raw
if ([string]::IsNullOrWhiteSpace($RawInput)) {
    Write-Error 'Clipboard is empty!'
    return
}

$CleanInput = $RawInput.Trim().TrimEnd(',')

# JSON string => Markdown
if ($CleanInput -match '^".*"$') {
    try {
        $Result = $CleanInput | ConvertFrom-Json
        if ($Result -is [string]) {
            $Result | Set-Clipboard
            Write-Host 'Action: Unescaped JSON string to Markdown.' -ForegroundColor Cyan
            return
        }
    }
    catch {
        # 解析失败，继续走正向转义
    }
}

# Markdown => JSON string
$Result = $RawInput.TrimEnd() -replace "`r`n", "`n" | ConvertTo-Json
$Result + ',' | Set-Clipboard
Write-Host 'Action: Escaped text to JSON string.' -ForegroundColor Green
