#Requires -Version 7.0

$RequestTimeout = @{ ConnectionTimeoutSeconds = 30; OperationTimeoutSeconds = 60 }

function A-Invoke-GitHubAPI {
    param (
        [string]$Uri,
        [hashtable]$Headers
    )
    if (!$Uri) {
        Write-Error '$Uri is invalid'
        return
    }
    if (!$Headers) {
        $Headers = @{
            'User-Agent'           = A-Get-UserAgent
            'X-GitHub-Api-Version' = '2022-11-28'
            'Accept'               = 'application/vnd.github.v3+json'
        }
    }
    $tokenPool = @()
    if ($env:GITHUB_ACTIONS) {
        $env:TOKEN_POOL -split ',' | ForEach-Object { if ($_) { $tokenPool += $_ } }
        if (!$tokenPool) {
            Write-Error '$env:TOKEN_POOL is invalid'
            return
        }
    }
    else {
        try {
            $localToken = scoop config gh_token
            if ($localToken) { $tokenPool += $localToken }
        }
        catch {}
    }

    [int]$currentIndex = [System.Environment]::GetEnvironmentVariable('TOKEN_POOL_ORDER', 'User')
    if ($null -eq $currentIndex -or $currentIndex -ge $tokenPool.Count) { $currentIndex = 0 }

    $maxGlobalRetries = 5
    $attemptCount = 0

    while ($attemptCount -lt $maxGlobalRetries) {
        $token = $tokenPool[$currentIndex]
        if ($token) {
            $Headers['Authorization'] = "Bearer $token"
        }
        else {
            $Headers.Remove('Authorization')
        }
        try {
            return Invoke-RestMethod -Uri $Uri -Headers $Headers @RequestTimeout -ErrorAction Stop
        }
        catch {
            $response = $_.Exception.Response
            if (!$response) {
                Write-Error $_
                return
            }
            $statusCode = [int]$response.StatusCode
            $remaining = $response.Headers['x-ratelimit-remaining']
            $retryAfter = $response.Headers['retry-after']

            if ($statusCode -in 403, 429 -and ($null -ne $remaining -or $null -ne $retryAfter)) {
                if ($remaining -eq '0') {
                    if ($env:GITHUB_ACTIONS) {
                        Write-Warning "Token [$currentIndex] is exhausted. Switching..."
                        $currentIndex = ($currentIndex + 1) % $tokenPool.Count
                        [Environment]::SetEnvironmentVariable('TOKEN_POOL_ORDER', $currentIndex, 'User')
                    }
                    else {
                        Write-Warning 'Token (scoop config gh_token) is exhausted'
                    }
                    $attemptCount++
                    continue
                }

                $waitSec = if ($retryAfter) { [int]$retryAfter } else { 3 }

                Write-Warning "(GitHub API) Secondary Rate Limit hit. Max Attempts: $maxGlobalRetries. Current Attempt: $($attemptCount + 1). Waiting ${waitSec}s..."
                Start-Sleep -Seconds $waitSec
                if ($env:GITHUB_ACTIONS) {
                    $currentIndex = ($currentIndex + 1) % $tokenPool.Count
                    [Environment]::SetEnvironmentVariable('TOKEN_POOL_ORDER', $currentIndex, 'User')
                }
                $attemptCount++
            }
            else {
                Write-Error $_
                return
            }
        }
    }
}
function A-Get-VersionFromGitHub {
    param (
        [string]$Channel = 'latest'
    )
    $checkver = $json.checkver
    $regex = $checkver.regex, '(.+)' | Select-Object -First 1
    $repo = A-Get-GitRepo
    if (!$repo) { return }
    $baseApiUrl = "https://api.github.com/repos/$repo/releases"

    if ($Channel -eq 'latest' -and !$checkver.max) {
        $res = A-Invoke-GitHubAPI -Uri "$baseApiUrl/latest"
        if (!$res) { return }
        $v = $res.tag_name -replace '[vV](?=\d+\.)', ''
        if ($v -match $regex) {
            return $v
        }
        return
    }
    if ($checkver.max) { $baseApiUrl += '?per_page=100' }
    $res = A-Invoke-GitHubAPI -Uri $baseApiUrl
    if (!$res) { return }

    switch ($Channel) {
        'newest' { $releaseInfo = $res }
        'preview' { $releaseInfo = $res.Where({ $_.prerelease }) }
        { $_ -in 'stable', 'latest' } { $releaseInfo = $res.Where({ !$_.draft -and !$_.prerelease }) }
        default { return }
    }
    $versions = [System.Collections.Generic.List[string]]::new()
    foreach ($item in $releaseInfo) {
        $v = $item.tag_name -replace '[vV](?=\d+\.)', ''
        if ($v -match $regex) {
            $versions.Add($v)
        }
    }
    return $versions
}
function A-Get-GitRepo {
    $repo = $checkver.github.repo, $checkver.commit.repo | Select-Object -First 1
    if ($repo) { return $repo }
    $arch = $json.autoupdate.architecture
    $candidates = @(
        $json.autoupdate.url,
        $arch.'64bit'.url,
        $arch.arm64.url,
        $arch.'32bit'.url,
        $json.homepage
    ) | Where-Object { $_ } | ForEach-Object { if ($_ -is [array]) { $_[0] } else { $_ } }
    foreach ($u in $candidates) {
        if ($u -match '^(?:https?://)?(?:[^/]+\.)?(?:github|gitee|gitlab|gitcode)\.com/(?:repos/)?([^/]+)/([^/]+)') {
            return "$($Matches[1])/$($Matches[2])"
        }
    }
}
function A-Get-VersionFromCommit {
    param (
        [string]$Branch = $checkver.commit.branch,
        [string]$Format = $checkver.commit.format
    )
    $repo = A-Get-GitRepo
    if (!$repo) { return }
    $perPage = if ($checkver.max) { 100 } else { 1 }
    $baseApiUrl = "https://api.github.com/repos/$repo/commits?per_page=$perPage"
    if ($Branch) { $baseApiUrl += "&sha=$Branch" }
    if ($checkver.commit.path) { $baseApiUrl += "&path=$([uri]::EscapeDataString($checkver.commit.path))" }
    $res = A-Invoke-GitHubAPI -Uri $baseApiUrl
    if (!$res -or $res.Count -eq 0) {
        if ($Branch) {
            Write-Error "No commits found for branch '$Branch'"
        }
        return
    }

    $parseCommit = {
        param($c)
        $shortSha = $c.sha.Substring(0, 6)
        $dto = [System.DateTimeOffset]::Parse($c.commit.committer.date, [System.Globalization.CultureInfo]::InvariantCulture)
        $formattedDate = $dto.ToString('yyyy.MM.dd.HHmmss')

        $matchesHashtable['sha'] = $c.sha
        $matchesHashtable['shortSha'] = $shortSha
        $matchesHashtable['date'] = $formattedDate

        if ($Format -eq 'date-sha') {
            return "${formattedDate}-${shortSha}"
        }
        return $formattedDate
    }
    if ($checkver.max) {
        $versions = foreach ($item in $res) { &$parseCommit $item }
        return $versions
    }
    return (&$parseCommit $res[0])
}
function A-Get-VersionFromPowerShellGallery {
    $moduleName = $json.psmodule.name
    if (!$moduleName) {
        Write-Error '$json.psmodule.name is invalid'
        return
    }
    $channel = $json.checkver.psgallery.channel
    $params = @{
        Name        = $moduleName
        Repository  = 'PSGallery'
        Version     = '*'
        ErrorAction = 'SilentlyContinue'
    }
    if ($channel -in 'newest', 'preview') {
        $params['Prerelease'] = $true
    }
    $res = Find-PSResource @params
    if (!$res) { return }
    $sorted = $res | Sort-Object { $_.Version } -Descending
    if ($channel -eq 'preview') {
        return @($sorted | Where-Object { $_.IsPrerelease } | ForEach-Object {
                if ($_.Prerelease) { "$($_.Version)-$($_.Prerelease)" } else { $_.Version.ToString() }
            })
    }
    return @($sorted | ForEach-Object {
            if ($_.Prerelease) { "$($_.Version)-$($_.Prerelease)" } else { $_.Version.ToString() }
        })
}
function A-Get-VersionFromInstaller {
    $arch = $json.autoupdate.architecture
    $url = $arch.'64bit'.url, $arch.arm64.url, $arch.'32bit'.url, $json.autoupdate.url | Select-Object -First 1
    if (!$url) {
        Write-Error "${app}: No installer url found"
        return
    }
    $versionPattern = '^\d+(\.\d+){1,}'

    $totalSize = A-Get-RemoteFileSize $url
    $sizeTiers = @(512KB, 2MB, 5MB, 20MB, $null)
    if ($totalSize) {
        $effectiveTiers = New-Object System.Collections.Generic.List[object]
        foreach ($size in $sizeTiers) {
            if ($null -eq $size) {
                $effectiveTiers.Add($size)
                break
            }
            $effectiveTiers.Add($size)
            if ([int64]$size -ge $totalSize) {
                break
            }
        }
        $sizeTiers = $effectiveTiers
    }
    $tempFile = Join-Path $env:TEMP "$([guid]::NewGuid().ToString()).exe"
    $rawVersion = $null
    try {
        foreach ($size in $sizeTiers) {
            try {
                if ($null -eq $size) {
                    Invoke-WebRequest -Uri $url -OutFile $tempFile -UseBasicParsing
                }
                else {
                    $rangeEnd = [int64]$size - 1
                    $headers = @{ 'Range' = "bytes=0-$rangeEnd" }
                    Invoke-WebRequest -Uri $url -Headers $headers -OutFile $tempFile -UseBasicParsing @RequestTimeout
                }
                $vi = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($tempFile)
                $candidate = if ($vi.FileVersion) { $vi.FileVersion.Trim() } else { $vi.ProductVersion.Trim() }
                if ($candidate -match $versionPattern) {
                    $rawVersion = $candidate
                    break
                }
            }
            catch {
                continue
            }
        }
    }
    finally {
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
    if (!$rawVersion) {
        Write-Error "${app}: Could not extract a valid version from installer"
        return
    }
    if ($json.checkver.regex) {
        if ($rawVersion -match $json.checkver.regex) {
            if ($json.checkver.replace) {
                $re = New-Object System.Text.RegularExpressions.Regex($json.checkver.regex)
                return $re.Replace($Matches[0], $json.checkver.replace)
            }
            elseif ($Matches[1]) {
                return $Matches[1]
            }
            else {
                Write-Error "${app}: regex '$($json.checkver.regex)' does not contain a capture group"
                return
            }
        }
        else {
            Write-Error "${app}: Version '$rawVersion' does not match regex '$($json.checkver.regex)'"
            return
        }
    }
    return $rawVersion
}
function A-Get-DynamicPageFromUrl {
    if (!$json.checkver.url) {
        Write-Error "${app}: Requires 'checkver.url'"
        return
    }
    $edgePath = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
    if (!(Test-Path $edgePath)) {
        $edgePath = 'msedge.exe'
    }
    try {
        $args = @('--headless=new', '--disable-gpu', '--dump-dom', '--no-sandbox', '--virtual-time-budget=10000', $json.checkver.url)

        $html = & $edgePath $args 2>$null | Out-String

        if ([string]::IsNullOrWhiteSpace($html)) {
            Write-Error "Failed to retrieve content from $($json.checkver.url)"
            return
        }
        $html
    }
    catch {
        Write-Error "Edge execution failed: $($_.Exception.Message)"
        return
    }
}
function A-Get-InstallerInfoFromWinGet {
    param(
        [string]$PackageIdentifier = $checkver.winget.id,
        [string]$InstallerExt = $checkver.winget.ext
    )
    if ([string]::IsNullOrWhiteSpace($PackageIdentifier)) {
        Write-Error '$checkver.winget.id is invalid'
        return
    }
    if (!(Get-Command 'ConvertFrom-Yaml' -ErrorAction SilentlyContinue)) {
        try {
            Import-Module powershell-yaml -ErrorAction Stop
        }
        catch {
            Write-Error 'Please install yaml module: scoop install abyss/cloudbase.powershell-yaml'
            return
        }
    }

    $tempFile = "$PSScriptRoot\..\_.json"
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

    $headers = @{
        'User-Agent'           = A-Get-UserAgent
        'X-GitHub-Api-Version' = '2022-11-28'
    }

    $rootDir = $PackageIdentifier.ToLower()[0]
    $PackagePath = $PackageIdentifier -replace '\.', '/'

    $url = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/$rootDir/$PackagePath"

    $res = A-Invoke-GitHubAPI -Uri $url
    if (!$res) { return }

    $versions = $res | ForEach-Object { if ($_.Name -notmatch '^\.') { $_.Name } } | Where-Object { $_ -match '^\d' }
    if ($checkver.max) {
        $maxStr = $checkver.max
        $filteredVersions = $versions | Where-Object {
            try { [semver]$_ -le [semver]$maxStr }
            catch {
                try {
                    $cleanV = $_ -replace '-.*$', ''
                    $cleanM = $maxStr -replace '-.*$', ''
                    [version]$cleanV -le [version]$cleanM
                }
                catch { $false }
            }
        }
        if (!$filteredVersions -or $filteredVersions.Count -eq 0) {
            $latestVersion = $json.version
        }
        else {
            $versions = $filteredVersions
        }
    }
    if (!$latestVersion) {
        foreach ($v in $versions) {
            $compare = Compare-Version -ReferenceVersion $latestVersion -DifferenceVersion $v
            if ($compare -gt 0) {
                $latestVersion = $v
            }
        }
    }
    if (!$latestVersion) { return }

    $headers.Add('Accept', 'application/vnd.github.v3.raw')

    $url = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/$rootDir/$PackagePath/$latestVersion/$PackageIdentifier.installer.yaml"

    $installerYaml = A-Invoke-GitHubAPI -Uri $url -Headers $headers
    if (!$installerYaml) { return }

    $installerInfo = ConvertFrom-Yaml $installerYaml
    if (!$installerInfo) { return }

    $scope = $installerInfo.Scope
    $InstallerLocale = $installerInfo.InstallerLocale

    $matchedAny = $false
    foreach ($_ in $installerInfo.Installers) {
        $arch = $_.Architecture

        $fileName = [System.IO.Path]::GetFileName($_.InstallerUrl.Split('?')[0].Split('#')[0])
        $extension = [System.IO.Path]::GetExtension($fileName).TrimStart('.')
        $type = $extension.ToLower()

        $matchType = $true
        if ($InstallerExt) {
            $matchType = $type -eq $InstallerExt
        }

        if ($arch -and $matchType) {
            $matchedAny = $true
            $key = $arch
            $installerInfo.$key = $_

            if ($scope) {
                $key += '_' + $scope.ToLower()
            }
            elseif ($_.Scope) {
                $key += '_' + $_.Scope.ToLower()
            }
            else {
                $key += '_machine'
            }
            $installerInfo.$key = $_

            if ($InstallerLocale) {
                $key += '_' + $InstallerLocale
            }
            elseif ($_.InstallerLocale) {
                $key += '_' + $_.InstallerLocale
            }
            $installerInfo.$key = $_
        }
    }
    if (!$matchedAny) {
        if ($InstallerExt) {
            Write-Error "${app}: No installer matches ext '$InstallerExt' in winget manifest '$PackageIdentifier'"
        }
        else {
            Write-Error "${app}: No matching installer found in winget manifest '$PackageIdentifier'"
        }
        return
    }

    $installerInfo.PackageVersion = $installerInfo.PackageVersion -replace '^(v|V)', ''
    $installerInfo | ConvertTo-Json -Depth 100 | Out-File -FilePath $tempFile -Force -Encoding utf8

    $out = @("ver:$($installerInfo.PackageVersion);")
    $out_neutral_machine = @(
        "x64:$($installerInfo.neutral_machine.InstallerUrl);",
        "x86:$($installerInfo.neutral_machine.InstallerUrl);",
        "arm64:$($installerInfo.neutral_machine.InstallerUrl);"
    )
    $out_neutral_user = @(
        "x64:$($installerInfo.neutral_user.InstallerUrl);",
        "x86:$($installerInfo.neutral_user.InstallerUrl);",
        "arm64:$($installerInfo.neutral_user.InstallerUrl);"
    )
    $out_machine = @(
        "x64:$($installerInfo.x64_machine.InstallerUrl);",
        "x86:$($installerInfo.x86_machine.InstallerUrl);",
        "arm64:$($installerInfo.arm64_machine.InstallerUrl);"
    )
    $out_user = @(
        "x64:$($installerInfo.x64_user.InstallerUrl);",
        "x86:$($installerInfo.x86_user.InstallerUrl);",
        "arm64:$($installerInfo.arm64_user.InstallerUrl);"
    )

    if ($jsonpath) {
        if ($jsonpath -like '$.*_machine.InstallerSha256') {
            $out += $out_neutral_machine
            $out += $out_machine
        }
        elseif ($jsonpath -like '$.*_user.InstallerSha256') {
            $out += $out_neutral_user
            $out += $out_user
        }
    }
    else {
        $out += $out_neutral_machine
        $out += $out_neutral_user
        $out += $out_machine
        $out += $out_user
    }
    return $out -join ''
}
function A-Get-UserAgent {
    "Scoop/1.0 (+http://scoop.sh/) PowerShell/$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor) (Windows NT $([System.Environment]::OSVersion.Version.Major).$([System.Environment]::OSVersion.Version.Minor); $(if(${env:ProgramFiles(Arm)}){'ARM64; '}elseif($env:PROCESSOR_ARCHITECTURE -eq 'AMD64'){'Win64; x64; '})$(if($env:PROCESSOR_ARCHITEW6432 -in 'AMD64','ARM64'){'WOW64; '})$PSEdition)"
}
function A-Resolve-DownloadUrl {
    param(
        [string]$Url
    )
    if (!$PSBoundParameters.ContainsKey('Url')) {
        return
    }
    try {
        $res = [System.Net.HttpWebRequest]::Create($Url).GetResponse()
        $res.ResponseUri.AbsoluteUri
        $res.Close()
    }
    catch {
        Write-Error "Failed to resolve download URL '$Url': $($_.Exception.Message)"
    }
}
function A-Get-RemoteFileSize {
    param(
        [string]$Url
    )
    $Url = A-Resolve-DownloadUrl $Url
    try {
        $headers = @{ 'Range' = 'bytes=0-0' }
        $resp = Invoke-WebRequest -Uri $Url -Headers $headers -UseBasicParsing @RequestTimeout
        $contentRange = $resp.Headers['Content-Range']
        if ($contentRange -and $contentRange -match '/(\d+)$') {
            return [int64]$Matches[1]
        }
        if ($resp.Headers['Content-Length']) {
            return [int64]$resp.Headers['Content-Length']
        }
    }
    catch {}
    try {
        $head = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing @RequestTimeout
        if ($head.Headers['Content-Length']) {
            return [int64]$head.Headers['Content-Length']
        }
    }
    catch {}
}
