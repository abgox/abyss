. $PSScriptRoot\utils.ps1

$parameters = @{
    'Uri'                      = "https://api.github.com/repos/scoopinstaller/scoop/releases/latest"
    'ConnectionTimeoutSeconds' = 10
    'OperationTimeoutSeconds'  = 15
}
if ($env:GITHUB_TOKEN) {
    $parameters.Add('Headers', @{ 'Authorization' = "token $env:GITHUB_TOKEN" })
}
try {
    $latestVersionTag = Invoke-RestMethod @parameters | Select-Object -ExpandProperty tag_name

    if ($latestVersionTag) {
        $lastestVersion = $latestVersionTag.TrimStart("v")
    }

    if ((A-Compare-Version $lastestVersion $ScoopVersion) -gt 0) {
        "ScoopNewVersion=$lastestVersion" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
    }
}
catch {}
