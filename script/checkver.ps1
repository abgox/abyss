#Requires -Version 7.0

$RequestTimeout = @{ ConnectionTimeoutSeconds = 30; OperationTimeoutSeconds = 60 }

$script:githubApiCache = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()
$script:githubHttpClient = $null
$script:githubHttpClientLock = [object]::new()

function A-Get-UserAgent {
    "Scoop/1.0 (+http://scoop.sh/) PowerShell/$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor) (Windows NT $([System.Environment]::OSVersion.Version.Major).$([System.Environment]::OSVersion.Version.Minor); $(if(${env:ProgramFiles(Arm)}){'ARM64; '}elseif($env:PROCESSOR_ARCHITECTURE -eq 'AMD64'){'Win64; x64; '})$(if($env:PROCESSOR_ARCHITEW6432 -in 'AMD64','ARM64'){'WOW64; '})$PSEdition)"
}
function A-Get-VersionRegex {
    param(
        [string]$SpecifiedRegex
    )
    if (-not [string]::IsNullOrWhiteSpace($SpecifiedRegex)) {
        return $SpecifiedRegex
    }
    return '(?:[vV]\.?)?([\w.+\-]+\d[\w.+\-]*)'
}
function A-Clear-Version {
    param([string]$v)
    if ([string]::IsNullOrEmpty($v)) { return $v }
    return $v -replace '[vV](?=\d+\.)', ''
}
function A-ConvertTo-VersionKey {
    param([string]$Version)
    if ([string]::IsNullOrEmpty($Version)) { return $null }
    $clean = A-Clear-Version -v $Version
    $m = [regex]::Match($clean, '^(\d+(?:[.\-+_]\d+)*)(.*)$')
    if (-not $m.Success) { return $null }
    $nums = $m.Groups[1].Value -split '[.\-+_]'
    $suffix = $m.Groups[2].Value
    $sb = [System.Text.StringBuilder]::new()
    for ($i = 0; $i -lt 4; $i++) {
        $num = 0
        if ($i -lt $nums.Count) {
            [void][int]::TryParse($nums[$i], [ref]$num)
        }
        [void]$sb.Append($num.ToString().PadLeft(10, '0'))
    }
    if ($suffix) {
        [void]$sb.Append('~')
        [void]$sb.Append($suffix)
    }
    else {
        [void]$sb.Append([char]0xFFFF)
    }
    return $sb.ToString()
}
function A-Test-VersionLessOrEqual {
    param(
        [string]$Version,
        [string]$MaxVersion
    )
    if ([string]::IsNullOrEmpty($MaxVersion)) { return $true }
    $cleanVer = A-Clear-Version -v $Version
    $cleanMax = A-Clear-Version -v $MaxVersion
    $maxSegments = ($cleanMax -split '\.').Count
    $compareVer = $cleanVer
    $verSegments = @($cleanVer -split '\.')
    if ($verSegments.Count -gt $maxSegments) {
        $compareVer = ($verSegments[0..($maxSegments - 1)] -join '.')
    }
    try {
        return [semver]$compareVer -le [semver]$cleanMax
    }
    catch {
        try {
            $cleanV = $compareVer -replace '-.*$', ''
            $cleanM = $cleanMax -replace '-.*$', ''
            if (($cleanV -split '\.').Count -lt 2) { $cleanV += '.0' }
            if (($cleanM -split '\.').Count -lt 2) { $cleanM += '.0' }
            return [version]$cleanV -le [version]$cleanM
        }
        catch { return $false }
    }
}
function A-Select-VersionLessOrEqual {
    param(
        [string[]]$Versions,
        [string]$MaxVersion
    )
    if ([string]::IsNullOrEmpty($MaxVersion)) { return $Versions }
    return @($Versions | Where-Object { A-Test-VersionLessOrEqual -Version $_ -MaxVersion $MaxVersion })
}
function A-Select-VersionFromList {
    param(
        [string[]]$Versions,
        [bool]$Reverse
    )
    if (-not $Versions -or $Versions.Count -eq 0) { return $null }
    $mapped = @($Versions | ForEach-Object {
            [pscustomobject]@{ Original = $_; Key = (A-ConvertTo-VersionKey -Version $_) }
        })
    $sorted = @($mapped | Where-Object { $null -ne $_.Key } | Sort-Object Key -Descending | ForEach-Object { $_.Original })
    $unparseable = @($mapped | Where-Object { $null -eq $_.Key } | ForEach-Object { $_.Original })
    $result = @($sorted) + $unparseable
    if ($result.Count -eq 0) { return $null }
    if ($Reverse) {
        return $result[-1]
    }
    return $result[0]
}
function A-Get-VersionVariants {
    param([string]$Version)
    if ([string]::IsNullOrEmpty($Version)) { return @() }
    $variants = [System.Collections.Generic.List[string]]::new()
    $variants.Add($Version)
    $base = $Version
    $suffix = ''
    if ($Version -match '^([\d\.]+)(.*)$') {
        $base = $Matches[1].TrimEnd('.')
        $suffix = $Matches[2]
    }
    $segments = @($base -split '\.')
    foreach ($t in 3, 4) {
        if ($segments.Count -lt $t) {
            $variants.Add(((($segments + @('0') * ($t - $segments.Count))) -join '.') + $suffix)
        }
    }
    if ($segments.Count -gt 2 -and $segments[-1] -eq '0') {
        for ($n = $segments.Count - 1; $n -ge 2; $n--) {
            if ($segments[$n] -eq '0') {
                $variants.Add(($segments[0..($n - 1)] -join '.') + $suffix)
            }
            else { break }
        }
    }
    $oneIdx = @()
    for ($i = 1; $i -lt $segments.Count; $i++) {
        if ($segments[$i] -match '^\d$') { $oneIdx += $i }
    }
    if ($oneIdx.Count -gt 0) {
        $total = [Math]::Pow(2, $oneIdx.Count)
        for ($mask = 1; $mask -lt $total; $mask++) {
            $copy = @($segments)
            for ($b = 0; $b -lt $oneIdx.Count; $b++) {
                if (($mask -band [Math]::Pow(2, $b)) -ne 0) { $copy[$oneIdx[$b]] = '0' + $copy[$oneIdx[$b]] }
            }
            $variants.Add(($copy -join '.') + $suffix)
        }
    }
    return @($variants | Select-Object -Unique)
}
function A-Convert-VersionWithRegex {
    param(
        [string]$Version,
        [string]$Regex,
        [string]$Replace,
        [ref]$MatchesHashtable
    )
    if ([string]::IsNullOrEmpty($Regex) -or -not $Version) { return $Version }
    $re = New-Object System.Text.RegularExpressions.Regex($Regex)
    $m = $re.Match($Version)
    if (-not $m.Success) { return $null }
    if ($MatchesHashtable) {
        $re.GetGroupNames() | ForEach-Object { $MatchesHashtable.Value[$_] = $m.Groups[$_].Value }
    }
    $result = if ($Replace) {
        $re.Replace($m.Value, $Replace)
    }
    elseif ($m.Groups['version'].Success) {
        $m.Groups['version'].Value
    }
    elseif ($m.Groups.Count -gt 1) {
        $m.Groups[1].Value
    }
    else {
        $Version
    }
    return A-Clear-Version -v $result
}

function A-Test-UrlAvailable {
    param([string]$Url)
    if ([string]::IsNullOrEmpty($Url)) { return $false }
    try {
        $req = [System.Net.HttpWebRequest]::Create($Url)
        $req.Method = 'HEAD'
        $req.Timeout = 15000
        $req.UserAgent = A-Get-UserAgent
        $req.AllowAutoRedirect = $true
        $res = $req.GetResponse()
        $code = [int]$res.StatusCode
        $res.Close()
        return ($code -ge 200 -and $code -lt 400)
    }
    catch {
        try {
            $req = [System.Net.HttpWebRequest]::Create($Url)
            $req.Method = 'GET'
            $req.Timeout = 15000
            $req.UserAgent = A-Get-UserAgent
            $req.AllowAutoRedirect = $true
            $req.AddRange(0, 0)
            $res = $req.GetResponse()
            $code = [int]$res.StatusCode
            $res.Close()
            return ($code -ge 200 -and $code -lt 400)
        }
        catch { return $false }
    }
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

function A-Get-GitHubHttpClient {
    if ($null -eq $script:githubHttpClient) {
        $acquired = $false
        try {
            [System.Threading.Monitor]::Enter($script:githubHttpClientLock, [ref]$acquired)
            if ($null -eq $script:githubHttpClient) {
                $handler = [System.Net.Http.HttpClientHandler]::new()
                $handler.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
                $client = [System.Net.Http.HttpClient]::new($handler)
                $client.Timeout = [TimeSpan]::FromSeconds(60)
                [void]$client.DefaultRequestHeaders.TryAddWithoutValidation('User-Agent', (A-Get-UserAgent))
                [void]$client.DefaultRequestHeaders.TryAddWithoutValidation('X-GitHub-Api-Version', '2022-11-28')
                $script:githubHttpClient = $client
            }
        }
        finally {
            if ($acquired) { [System.Threading.Monitor]::Exit($script:githubHttpClientLock) }
        }
    }
    return $script:githubHttpClient
}

function A-Invoke-GitHubAPI {
    param (
        [string]$Uri,
        [hashtable]$Headers,
        [switch]$Raw
    )
    if (!$Uri) {
        Write-Error '$Uri is invalid'
        return
    }
    $cacheKey = if ($Raw) { "$Uri#raw" } else { $Uri }
    if ($script:githubApiCache.ContainsKey($cacheKey)) {
        return $script:githubApiCache[$cacheKey]
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
            $localToken = scoop config | Select-Object -ExpandProperty gh_token -ErrorAction Ignore
            if ($localToken) { $tokenPool += $localToken }
        }
        catch {}
    }

    $env:SCOOP_GH_TOKEN, $env:GITHUB_TOKEN, $env:GH_TOKEN | Where-Object { $_ } | ForEach-Object { $tokenPool += $_ }

    $client = A-Get-GitHubHttpClient

    [int]$currentIndex = [System.Environment]::GetEnvironmentVariable('TOKEN_POOL_ORDER', 'User')
    if ($null -eq $currentIndex -or $currentIndex -ge $tokenPool.Count) { $currentIndex = 0 }

    $maxGlobalRetries = 5
    $attemptCount = 0

    while ($attemptCount -lt $maxGlobalRetries) {
        $token = $tokenPool[$currentIndex]
        $request = [System.Net.Http.HttpRequestMessage]::new('GET', $Uri)
        if ($token) {
            $request.Headers.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $token)
        }
        if ($Headers) {
            foreach ($h in $Headers.GetEnumerator()) {
                try { [void]$request.Headers.TryAddWithoutValidation($h.Key, [string]$h.Value) } catch {}
            }
        }
        else {
            [void]$request.Headers.TryAddWithoutValidation('Accept', 'application/vnd.github.v3+json')
        }
        try {
            $response = $client.SendAsync($request).GetAwaiter().GetResult()
            $statusCode = [int]$response.StatusCode
            if ($statusCode -in 403, 429) {
                $remaining = $null
                $retryAfter = $null
                [void]$response.Headers.TryGetValues('x-ratelimit-remaining', [ref]$remaining)
                [void]$response.Headers.TryGetValues('retry-after', [ref]$retryAfter)
                $remaining = @($remaining)[0]
                $retryAfter = @($retryAfter)[0]
                $response.Dispose()
                if ($null -ne $remaining -and $remaining -eq '0') {
                    if ($env:GITHUB_ACTIONS) {
                        Write-Warning "Token [$currentIndex] exhausted. Switching..."
                        $currentIndex = ($currentIndex + 1) % $tokenPool.Count
                        [Environment]::SetEnvironmentVariable('TOKEN_POOL_ORDER', $currentIndex, 'User')
                    }
                    else {
                        Write-Warning 'Token (scoop config gh_token) exhausted'
                    }
                    $attemptCount++
                    continue
                }
                $waitSec = if ($retryAfter) {
                    $retryAfterInt = 0
                    if ([int]::TryParse($retryAfter, [ref]$retryAfterInt)) {
                        [Math]::Min($retryAfterInt, 300)
                    }
                    else {
                        60
                    }
                }
                else {
                    [Math]::Min(30 * [Math]::Pow(2, $attemptCount), 300)
                }
                Write-Warning "Rate limit hit (Secondary/IP-based). Attempt $($attemptCount + 1)/$maxGlobalRetries. Waiting ${waitSec}s..."
                Start-Sleep -Seconds $waitSec
                $attemptCount++
                continue
            }
            if (!$response.IsSuccessStatusCode) {
                Write-Error "GitHub API returned HTTP $statusCode for $Uri"
                $response.Dispose()
                return
            }
            $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            $response.Dispose()

            $isRaw = $false
            if ($Headers) {
                foreach ($h in $Headers.GetEnumerator()) {
                    if ($h.Key -eq 'Accept' -and ([string]$h.Value) -match 'raw') {
                        $isRaw = $true
                        break
                    }
                }
            }
            $result = if ($isRaw -or $Raw) { $content } else { $content | ConvertFrom-Json }
            $script:githubApiCache.TryAdd($cacheKey, $result) | Out-Null
            return $result
        }
        catch {
            $request.Dispose()
            $response = $_.Exception.Response
            if (!$response) {
                Write-Error $_
                return
            }
            Write-Error "GitHub API returned HTTP $([int]$response.StatusCode) for $Uri"
            if ($_.Exception.Message) {
                Write-Error $_.Exception.Message
            }
            return
        }
    }
    Write-Error "Max retries ($maxGlobalRetries) exceeded for $Uri"
    return $null
}
function A-Get-VersionFromGitHub {
    param (
        [string]$Channel = 'latest'
    )
    $checkver = $json.checkver
    $regex = A-Get-VersionRegex -SpecifiedRegex $checkver.regex
    $repo = A-Get-GitRepo
    if (!$repo) { return }
    $baseApiUrl = "https://api.github.com/repos/$repo/releases"

    if ($Channel -eq 'latest' -and !$checkver.max) {
        $res = A-Invoke-GitHubAPI -Uri "$baseApiUrl/latest"
        if (!$res) { return }
        $v = A-Clear-Version -v $res.tag_name
        if ($v -match $regex) {
            return $v
        }
        return
    }
    if ($checkver.max) {
        $all = [System.Collections.Generic.List[psobject]]::new()
        $page = 1
        while ($page -le 10) {
            $res = A-Invoke-GitHubAPI -Uri "$($baseApiUrl)?per_page=100&page=$page"
            if (!$res -or $res.Count -eq 0) { break }
            $all.AddRange([psobject[]]$res)
            $oldestV = A-Clear-Version -v $res[-1].tag_name
            if ($oldestV -match $regex -and (A-Test-VersionLessOrEqual -Version $oldestV -MaxVersion $checkver.max)) {
                break
            }
            $page++
        }
        if ($all.Count -eq 0) { return }
        $res = $all
    }
    else {
        $res = A-Invoke-GitHubAPI -Uri $baseApiUrl
        if (!$res) { return }
    }

    switch ($Channel) {
        'newest' { $releaseInfo = $res }
        'preview' { $releaseInfo = $res.Where({ $_.prerelease }) }
        { $_ -in 'stable', 'latest' } { $releaseInfo = $res.Where({ !$_.draft -and !$_.prerelease }) }
        default { return }
    }
    $versions = [System.Collections.Generic.List[string]]::new()
    foreach ($item in $releaseInfo) {
        $v = A-Clear-Version -v $item.tag_name
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
    $paths = @($checkver.commit.path)
    if ($paths.Count -eq 0) { $paths = @($null) }

    $allRes = [System.Collections.Generic.List[psobject]]::new()
    foreach ($path in $paths) {
        $baseApiUrl = "https://api.github.com/repos/$repo/commits?per_page=$perPage"
        if ($Branch) { $baseApiUrl += "&sha=$Branch" }
        if ($path) { $baseApiUrl += "&path=$([uri]::EscapeDataString($path))" }
        $res = A-Invoke-GitHubAPI -Uri $baseApiUrl
        if ($res -and $res.Count -gt 0) {
            $allRes.AddRange([psobject[]]$res)
        }
    }

    if ($allRes.Count -eq 0) {
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
        $versions = foreach ($item in $allRes) { &$parseCommit $item }
        return $versions
    }
    $newest = $allRes | Sort-Object -Property @{ Expression = { [System.DateTimeOffset]::Parse($_.commit.committer.date, [System.Globalization.CultureInfo]::InvariantCulture) } } -Descending | Select-Object -First 1
    return (&$parseCommit $newest)
}

function A-Get-GitHubReleasePage {
    <#
    .SYNOPSIS
        获取 GitHub Release 的原始 API 响应文本

    .DESCRIPTION
        用于 checkver.github 的 raw 模式:
        不再返回版本号候选, 而是把 API 响应原文作为 $page 交给通用的 jsonpath/regex 提取管线。
        - 指定 tag: /repos/{repo}/releases/tags/{tag}
        - latest:   /repos/{repo}/releases/latest
        - 其他 channel (newest/stable/preview): /repos/{repo}/releases 列表(单页)

    .NOTES
        必须透传原始响应文本而非 ConvertTo-Json 往返,
        否则既有清单中针对 GitHub 原始响应格式编写的 regex 将全部失效。
    #>
    param (
        [string]$Channel = 'latest'
    )
    $checkver = $json.checkver
    $repo = A-Get-GitRepo
    if (!$repo) {
        Write-Error "${app}: Unable to determine GitHub repository"
        return
    }
    if ($checkver.github.tag) {
        return A-Invoke-GitHubAPI -Uri "https://api.github.com/repos/$repo/releases/tags/$($checkver.github.tag)" -Raw
    }
    if (!$Channel) { $Channel = 'latest' }
    if ($Channel -eq 'latest') {
        return A-Invoke-GitHubAPI -Uri "https://api.github.com/repos/$repo/releases/latest" -Raw
    }
    return A-Invoke-GitHubAPI -Uri "https://api.github.com/repos/$repo/releases?per_page=100" -Raw
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
        $filteredVersions = A-Select-VersionLessOrEqual -Versions $versions -MaxVersion $checkver.max
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
    $sorted = @($res | ForEach-Object {
            [pscustomobject]@{
                VersionStr = if ($_.Prerelease) { "$($_.Version)-$($_.Prerelease)" } else { $_.Version.ToString() }
                IsPreview  = [bool]$_.IsPrerelease
                Key        = (A-ConvertTo-VersionKey -Version $_.Version.ToString())
            }
        } | Where-Object { $_.Key } | Sort-Object Key -Descending)
    if ($channel -eq 'preview') {
        return @($sorted | Where-Object { $_.IsPreview } | ForEach-Object { $_.VersionStr })
    }
    return @($sorted | ForEach-Object { $_.VersionStr })
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

function A-Get-RegexMatchesWithMax {
    param(
        [string]$Page,
        [string]$Regex,
        [string]$Replace,
        [string]$MaxVersion,
        [bool]$Reverse,
        [ref]$MatchesHashtable
    )
    $re = New-Object System.Text.RegularExpressions.Regex($Regex)
    $allMatches = $re.Matches($Page)
    if (-not $allMatches -or $allMatches.Count -eq 0) { return $null }
    if ($MaxVersion) {
        $validMatches = [System.Collections.Generic.List[psobject]]::new()
        foreach ($m in $allMatches) {
            $candidateVer = A-Convert-VersionWithRegex -Version $m.Value -Regex $Regex -Replace $Replace -MatchesHashtable ([ref](@{}))
            if ($candidateVer) {
                $isLessOrEqual = A-Test-VersionLessOrEqual -Version $candidateVer -MaxVersion $MaxVersion
                if ($isLessOrEqual) {
                    $validMatches.Add(@{ Match = $m; Version = $candidateVer })
                }
            }
        }
        if ($validMatches.Count -eq 0) { return $null }
        $targetMatch = if ($Reverse) { $validMatches[-1] } else { $validMatches[0] }
        $targetMatch.Match.Groups | ForEach-Object { $MatchesHashtable.Value[$_.Name] = $_.Value }
        return $targetMatch.Version
    }
    else {
        $match = if ($Reverse) { $allMatches[$allMatches.Count - 1] } else { $allMatches[0] }
        if (-not $match -or -not $match.Success) { return $null }
        return A-Convert-VersionWithRegex -Version $match.Value -Regex $Regex -Replace $Replace -MatchesHashtable $MatchesHashtable
    }
}
function A-Resolve-CandidateVersion {
    param(
        [string[]]$CandidateVersions,
        $Checkver,
        [string]$Replace,
        [bool]$Reverse,
        [string]$ExpectedVer,
        [ref]$MatchesHashtable,
        [ref]$Version
    )
    if (-not $CandidateVersions -or $CandidateVersions.Count -eq 0) { return $false }
    $effectiveRegex = A-Get-VersionRegex -SpecifiedRegex $Checkver.regex
    $extracted = [System.Collections.Generic.List[psobject]]::new()
    foreach ($c in $CandidateVersions) {
        $e = A-Convert-VersionWithRegex -Version $c -Regex $effectiveRegex -Replace $Replace -MatchesHashtable ([ref](@{}))
        if ($e) {
            $extracted.Add([pscustomobject]@{ Version = $e; Source = $c })
        }
    }
    if ($extracted.Count -eq 0) {
        $Version.Value = $null
        return $false
    }
    $versions = @($extracted | ForEach-Object { $_.Version })
    if ($Checkver.max) {
        $versions = A-Select-VersionLessOrEqual -Versions $versions -MaxVersion $Checkver.max
        if (-not $versions -or $versions.Count -eq 0) {
            Write-Warning "No version <= max '$($Checkver.max)', keeping $ExpectedVer"
            $Version.Value = $ExpectedVer
            return $true
        }
    }
    $ver = A-Select-VersionFromList -Versions $versions -Reverse $Reverse
    if ($ver -and $MatchesHashtable) {
        $selected = $extracted | Where-Object { $_.Version -eq $ver } | Select-Object -First 1
        if ($selected) {
            A-Convert-VersionWithRegex -Version $selected.Source -Regex $effectiveRegex -Replace $Replace -MatchesHashtable $MatchesHashtable | Out-Null
        }
    }
    $Version.Value = $ver
    return $true
}
function A-Resolve-UrlVersion {
    param($Json, [string]$Version, $MatchesHashtable)
    $au = $Json.autoupdate
    if (-not $au) { return $Version }
    $arch = $au.architecture
    $template = $au.url
    if ($arch.'64bit'.url) { $template = $arch.'64bit'.url }
    elseif ($arch.arm64.url) { $template = $arch.arm64.url }
    elseif ($arch.'32bit'.url) { $template = $arch.'32bit'.url }
    if ([string]::IsNullOrEmpty($template)) { return $Version }
    foreach ($v in (A-Get-VersionVariants -Version $Version)) {
        try {
            $substitutions = Get-VersionSubstitution $v $MatchesHashtable
            $url = substitute $template $substitutions
            if (A-Test-UrlAvailable $url) {
                if ($v -ne $Version) {
                    Write-Host " (version adjusted to $v)" -ForegroundColor DarkGray
                }
                return $v
            }
        }
        catch { }
    }
    return $Version
}
