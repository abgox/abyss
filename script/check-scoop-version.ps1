. $PSScriptRoot\utils.ps1

$headers = @{
    'User-Agent'           = A-Get-UserAgent
    'X-GitHub-Api-Version' = '2022-11-28'
}

if ($env:GITHUB_TOKEN) {
    $headers['Authorization'] = "Bearer $env:GITHUB_TOKEN"
}
try {
    $latestVersionTag = Invoke-RestMethod -Uri "https://api.github.com/repos/scoopinstaller/scoop/releases/latest" -Headers $headers | Select-Object -ExpandProperty tag_name

    if ($latestVersionTag) {
        $lastestVersion = $latestVersionTag.TrimStart("v")
    }
    Write-Host "LatestVersion: $lastestVersion"
    if ((A-Compare-Version $lastestVersion $abgox_abyss.ScoopVersion) -gt 0) {
        "ScoopNewVersion=$lastestVersion" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
    }
}
catch {}
