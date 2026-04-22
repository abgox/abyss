$RawInput = Get-Clipboard -Raw
if ([string]::IsNullOrWhiteSpace($RawInput)) {
    Write-Error 'Clipboard is empty!'
    return
}

$CleanInput = $RawInput.Trim().TrimEnd(',')

$IsWrappedInQuotes = $CleanInput -match '^".*"$'
$ContainsEscapedChars = $CleanInput -match '\\"'

if ($IsWrappedInQuotes -or $ContainsEscapedChars) {
    try {
        $Normalized = if ($CleanInput.StartsWith('"')) { $CleanInput } else { "`"$($CleanInput)`"" }
        $Result = $Normalized | ConvertFrom-Json
        if ($Result -is [string]) {
            $Result | Set-Clipboard
            Write-Host 'Action: Unescaped JSON string to Markdown.' -ForegroundColor Cyan
            return
        }
    }
    catch {
        Write-Error 'Failed to parse JSON string.'
        return
    }
}

$Result = $RawInput.TrimEnd() -replace "`r`n", "`n" | ConvertTo-Json
$Result | Set-Clipboard
Write-Host 'Action: Escaped text to JSON string.' -ForegroundColor Green
