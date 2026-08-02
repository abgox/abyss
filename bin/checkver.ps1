param(
    [String] $App = '*',
    [String] $Dir = "$PSScriptRoot/../bucket",
    [String] $Segment,
    [Switch] $Update,
    [Switch] $ForceUpdate,
    [Switch] $SkipUpdated,
    [String] $Version = '',
    [Switch] $ThrowError,
    [int] $MaxConcurrency = 100,
    [int] $TimeoutSec = 30
)

if (-not $env:SCOOP_HOME) { $env:SCOOP_HOME = Convert-Path (scoop prefix scoop) }

. "$env:SCOOP_HOME\lib\core.ps1"
. "$env:SCOOP_HOME\lib\autoupdate.ps1"
. "$env:SCOOP_HOME\lib\manifest.ps1"
. "$env:SCOOP_HOME\lib\buckets.ps1"
. "$env:SCOOP_HOME\lib\json.ps1"
. "$env:SCOOP_HOME\lib\versions.ps1"
. "$env:SCOOP_HOME\lib\download.ps1"

. "$PSScriptRoot\..\script\checkver.ps1"

if ($App -ne '*' -and (Test-Path $App -PathType Leaf)) {
    $Dir = Split-Path $App
    $files = Get-ChildItem $Dir -File -Filter (Split-Path $App -Leaf)
}
elseif ($Dir) {
    $Dir = Convert-Path $Dir
    $files = Get-ChildItem $Dir -File -Filter "$App.json" -Recurse
}
else {
    throw "'-Dir' parameter required if '-App' is not a filepath!"
}

if ($Segment) {
    $start, $end = $Segment.Split('-')
    $files = $files.Where({
            $letter = $_.BaseName.ToLower()[0]
            $letter -ge $start -and $letter -le $end
        })
}

$GitHubToken = Get-GitHubToken

if ($App -eq '*' -and $Version -ne '') {
    throw "Don't use '-Version' with '-App *'!"
}

function next($appName, $er) {
    Write-Host
    Write-Host "${appName}: " -NoNewline
    Write-Host $er -ForegroundColor DarkRed
}

$Queue = @()
$json = ''

foreach ($f in $files) {
    $file = $f.FullName
    $json = parse_json $file
    if ($json.checkver) {
        $Queue += , @($f.BaseName, $json, $file)
    }
}

$queueIndex = 0
$in_progress = 0
# key: subscription identifier (string) -> @{ wc; state; subscription; startTime }
$activeRequests = @{}

function Invoke-ManifestResult($state, $result, $err, $cancelled) {
    $app = $state.app
    $file = $state.file
    $json = $state.json
    $url = $state.url
    $checkver = $json.checkver
    $regexp = $state.regex, '(.+)' | Select-Object -First 1
    $jsonpath = $state.jsonpath
    $xpath = $state.xpath
    $script = $checkver.script
    $reverse = $state.reverse
    $replace = $state.replace
    $expected_ver = $json.version
    $ver = $Version

    if ($json.version -in 'nightly', 'pending', 'renamed', 'deprecated', 'virtual') {
        if (!$script:SkipUpdated) {
            Write-Host
            Write-Host "${app}: " -NoNewline
            Write-Host $json.version -ForegroundColor DarkGreen
        }
        return
    }

    $matchesHashtable = @{}

    if (!$ver) {
        if ($cancelled) {
            if (!$script) {
                next $app "timed out after ${TimeoutSec}s`r`nURL $url is not valid"
                return
            }
            else {
                Write-Host "${app}: Request timed out after ${TimeoutSec}s. Falling back to checkver.script ..." -ForegroundColor DarkYellow
            }
        }

        if ($err) {
            if (!$script) {
                next $app "$($err.message)`r`nURL $url is not valid"
                return
            }
            else {
                Write-Host "$($err.message)`r`nURL $url is not valid. Falling back to checkver.script ..." -ForegroundColor DarkYellow
            }
        }

        $page = $null
        $source = $url

        if ($url -and !$err -and !$cancelled) {
            $ms = [System.IO.MemoryStream]::new($result)
            $ms.Position = 0
            try {
                $encoding = if ($state.encoding) { $state.encoding } else { [System.Text.Encoding]::UTF8 }
                if ($result.Length -ge 2 -and $result[0] -eq 0x1F -and $result[1] -eq 0x8B) {
                    $gz = [System.IO.Compression.GZipStream]::new($ms, [System.IO.Compression.CompressionMode]::Decompress)
                    $sr = [System.IO.StreamReader]::new($gz, $encoding)
                    $page = $sr.ReadToEnd()
                    $sr.Dispose()
                    $gz.Dispose()
                }
                else {
                    $sr = [System.IO.StreamReader]::new($ms, $encoding)
                    $page = $sr.ReadToEnd()
                    $sr.Dispose()
                }
            }
            finally {
                $ms.Dispose()
            }
        }

        if ($script) {
            $page = Invoke-Command ([scriptblock]::Create($script -join "`r`n"))
            $source = 'the output of script'
            if ($null -eq $page) {
                next $app "couldn't retrieve content from $source"
                return
            }
            if ($page -is [array]) {
                $page = $page -join ''
            }
        }

        if (!$ver) {
            $candidateVersions = @()
            if ($checkver.github) {
                $candidateVersions = A-Get-VersionFromGitHub -Channel $checkver.github.channel
                $source = 'github'
            }
            elseif ($checkver.commit) {
                $vCandidate = A-Get-VersionFromCommit
                if ($vCandidate) { $candidateVersions = @($vCandidate) }
                $source = 'commit'
            }
            elseif ($checkver.winget) {
                $page = A-Get-InstallerInfoFromWinGet
                $regexp = '(?:.*ver:(?<version>[^;]+))(?:.*x64:(?<x64>[^;]+))?(?:.*x86:(?<x86>[^;]+))?(?:.*arm64:(?<arm64>[^;]+))?'
                $source = "winget $($checkver.winget)"
            }
            elseif ($checkver.psgallery) {
                $candidateVersions = A-Get-VersionFromPowerShellGallery
                $source = 'psgallery'
            }
            elseif ($checkver.from_installer) {
                $vCandidate = A-Get-VersionFromInstaller
                if ($vCandidate) { $candidateVersions = @($vCandidate) }
                $source = 'from_installer'
            }
            elseif ($checkver.dynamic) {
                $page = A-Get-DynamicPageFromUrl
                $source = "dynamic page $($checkver.url)"
            }
            elseif ($checkver.redirect) {
                $page = A-Resolve-DownloadUrl $checkver.url
                $source = "redirect $($checkver.url)"
            }
            if ($candidateVersions -and $candidateVersions.Count -gt 0) {
                if ($checkver.max) {
                    $maxStr = $checkver.max
                    $filteredVersions = $candidateVersions | Where-Object {
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
                        $ver = $expected_ver
                    }
                    else {
                        $candidateVersions = $filteredVersions
                    }
                }
                if (!$ver) {
                    $ver = $candidateVersions | Select-Object -First 1
                    if ($ver -and $checkver.regex) {
                        $re = New-Object System.Text.RegularExpressions.Regex($regexp)
                        $m = $re.Match("$ver")
                        if ($m.Success) {
                            $re.GetGroupNames() | ForEach-Object { $matchesHashtable[$_] = $m.Groups[$_].Value }
                            if ($replace) {
                                $ver = $re.Replace($m.Value, $replace)
                            }
                            elseif ($m.Groups['version'].Success) {
                                $ver = $m.Groups['version'].Value
                            }
                            elseif ($m.Groups.Count -gt 1) {
                                $ver = $m.Groups[1].Value
                            }
                            else {
                                next $app "regex '$regexp' does not contain a capture group"
                                return
                            }
                        }
                    }
                }
            }
            if (!$ver -and $page) {
                if ($jsonpath) {
                    $noregex = !$checkver.regex
                    $ver = json_path $page $jsonpath $null ($reverse -and $noregex) $noregex
                    if (!$ver) { $ver = json_path_legacy $page $jsonpath }
                    if (!$ver) {
                        next $app "couldn't find '$jsonpath' in $source"
                        return
                    }
                }
                if ($xpath) {
                    $xml = [xml]$page
                    $nsList = $xml.SelectNodes('//namespace::*[not(. = ../../namespace::*)]')
                    $nsmgr = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
                    $nsList | ForEach-Object {
                        if ($_.LocalName -eq 'xmlns') {
                            $nsmgr.AddNamespace('ns', $_.Value)
                            $xpath = $xpath -replace '/([^:/]+)((?=/)|(?=$))', '/ns:$1'
                        }
                        else {
                            $nsmgr.AddNamespace($_.LocalName, $_.Value)
                        }
                    }
                    $ver = $xml.SelectSingleNode($xpath, $nsmgr).'#text'
                    if (!$ver) {
                        next $app "couldn't find '$($xpath -replace 'ns:', '')' in $source"
                        return
                    }
                }
                if ($ver -and $checkver.max -and -not $checkver.regex) {
                    $maxStr = $checkver.max
                    $isLessOrEqual = try { [semver]$ver -le [semver]$maxStr } catch {
                        try {
                            $cleanV = $ver -replace '-.*$', ''
                            $cleanM = $maxStr -replace '-.*$', ''
                            [version]$cleanV -le [version]$cleanM
                        }
                        catch { $false }
                    }
                    if (-not $isLessOrEqual) {
                        $ver = $expected_ver
                    }
                }
                if (($jsonpath -or $xpath) -and $checkver.regex) {
                    $page = $ver
                    $ver = ''
                }
                if (!$ver -and $regexp) {
                    $re = New-Object System.Text.RegularExpressions.Regex($regexp)
                    $allMatches = $re.Matches($page)
                    if ($allMatches -and $allMatches.Count -gt 0) {
                        if ($checkver.max) {
                            $maxStr = $checkver.max
                            $validMatches = [System.Collections.Generic.List[psobject]]::new()
                            foreach ($m in $allMatches) {
                                $candidateVer = $null
                                if ($replace) {
                                    $candidateVer = $re.Replace($m.Value, $replace)
                                }
                                else {
                                    $candidateVer = if ($m.Groups['version'].Success) { $m.Groups['version'].Value }
                                    elseif ($m.Groups.Count -gt 1) { $m.Groups[1].Value }
                                    else {
                                        next $app "regex '$regexp' does not contain a capture group"
                                        return
                                    }
                                }
                                if ($candidateVer) {
                                    $isLessOrEqual = try { [semver]$candidateVer -le [semver]$maxStr } catch {
                                        try {
                                            $cleanV = $candidateVer -replace '-.*$', ''
                                            $cleanM = $maxStr -replace '-.*$', ''
                                            [version]$cleanV -le [version]$cleanM
                                        }
                                        catch { $false }
                                    }
                                    if ($isLessOrEqual) {
                                        $validMatches.Add(@{ Match = $m; Version = $candidateVer })
                                    }
                                }
                            }
                            if ($validMatches.Count -gt 0) {
                                $targetMatch = if ($reverse) { $validMatches[-1] } else { $validMatches[0] }
                                $targetMatch.Match.Groups | ForEach-Object { $matchesHashtable[$_.Name] = $_.Value }
                                $ver = $targetMatch.Version
                            }
                            else {
                                $ver = $expected_ver
                            }
                        }
                        else {
                            $match = if ($reverse) { $allMatches[$allMatches.Count - 1] } else { $allMatches[0] }
                            if ($match -and $match.Success) {
                                $re.GetGroupNames() | ForEach-Object { $matchesHashtable[$_] = $match.Groups[$_].Value }
                                if ($replace) {
                                    $ver = $re.Replace($match.Value, $replace)
                                }
                                elseif ($match.Groups['version'].Success) {
                                    $ver = $match.Groups['version'].Value
                                }
                                elseif ($match.Groups.Count -gt 1) {
                                    $ver = $match.Groups[1].Value
                                }
                                else {
                                    next $app "regex '$regexp' does not contain a capture group"
                                    return
                                }
                            }
                        }
                    }
                    else {
                        if ($checkver.max) {
                            $ver = $expected_ver
                        }
                        else {
                            next $app "couldn't match '$regexp' in $source"
                            return
                        }
                    }
                }
            }

            if (!$ver) {
                next $app "couldn't find new version in $source"
                return
            }
        }
    }

    if (($ver -eq $expected_ver) -and !$script:ForceUpdate -and $script:SkipUpdated) { return }

    Write-Host
    Write-Host "${app}: " -NoNewline

    if ($ver -eq $expected_ver -and !$script:ForceUpdate) {
        Write-Host $ver -ForegroundColor DarkGreen
        return
    }

    Write-Host $ver -ForegroundColor DarkRed -NoNewline
    Write-Host " (scoop version is $expected_ver)" -NoNewline
    $update_available = (Compare-Version -ReferenceVersion $ver -DifferenceVersion $expected_ver) -ne 0

    if ($json.autoupdate -and $update_available) {
        Write-Host ' autoupdate available' -ForegroundColor Cyan
    }
    else {
        Write-Host ''
    }

    $shouldUpdate = $script:Update -or $script:ForceUpdate
    if ($shouldUpdate -and $json.autoupdate) {
        if ($script:ForceUpdate) {
            Write-Host 'Forcing autoupdate!' -ForegroundColor DarkMagenta
        }
        try {
            $ver = Resolve-UrlVersion $json $ver $matchesHashtable
            Invoke-AutoUpdate $app $file $json $ver $matchesHashtable
        }
        catch {
            if ($script:ThrowError) { throw $_ } else { error $_.Exception.Message }
        }
    }
}

function Get-VersionVariants {
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

function Test-UrlAvailable {
    param([string]$Url)
    if ([string]::IsNullOrEmpty($Url)) { return $false }
    try {
        $req = [System.Net.HttpWebRequest]::Create($Url)
        $req.Method = 'HEAD'
        $req.Timeout = 15000
        $req.UserAgent = (Get-UserAgent)
        $res = $req.GetResponse()
        $code = [int]$res.StatusCode
        $res.Close()
        return ($code -ge 200 -and $code -lt 400)
    }
    catch { return $false }
}

function Resolve-UrlVersion {
    param($Json, [string]$Version, $MatchesHashtable)
    $au = $Json.autoupdate
    if (-not $au) { return $Version }
    $arch = $au.architecture
    $template = $au.url
    if ($arch.'64bit'.url) { $template = $arch.'64bit'.url }
    elseif ($arch.arm64.url) { $template = $arch.arm64.url }
    elseif ($arch.'32bit'.url) { $template = $arch.'32bit'.url }
    if ([string]::IsNullOrEmpty($template)) { return $Version }
    foreach ($v in (Get-VersionVariants -Version $Version)) {
        try {
            $substitutions = Get-VersionSubstitution $v $MatchesHashtable
            $url = substitute $template $substitutions
            if (Test-UrlAvailable $url) {
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

function Start-NextDownload {
    while ($script:queueIndex -lt $script:Queue.Count) {
        $name, $json, $file = $script:Queue[$script:queueIndex]
        $script:queueIndex++

        if (-not $json.checkver.url -or $json.checkver.dynamic -or $json.checkver.redirect) {
            $state = [psobject]@{
                app      = $name
                file     = $file
                url      = $null
                regex    = $json.checkver.regex
                json     = $json
                jsonpath = $json.checkver.jsonpath
                xpath    = $json.checkver.xpath
                reverse  = ($json.checkver.reverse -eq 'true')
                replace  = if ($json.checkver.replace -is [string]) { $json.checkver.replace } else { '' }
                encoding = $null
            }

            Invoke-ManifestResult -state $state -result $null -err $null -cancelled $false
            continue
        }

        $substitutions = Get-VersionSubstitution $json.version
        $wc = [System.Net.WebClient]::new()
        if ($json.checkver.useragent) {
            $wc.Headers.Add('User-Agent', (substitute $json.checkver.useragent $substitutions))
        }
        else {
            $wc.Headers.Add('User-Agent', (Get-UserAgent))
        }

        $url = substitute $json.checkver.url $substitutions
        if ($url -like '*api.github.com/*') {
            $wc.Headers.Add('Authorization', "Bearer $script:GitHubToken")
        }

        $state = [psobject]@{
            app      = $name
            file     = $file
            url      = $url
            regex    = $json.checkver.regex
            json     = $json
            jsonpath = $json.checkver.jsonpath
            xpath    = $json.checkver.xpath
            reverse  = ($json.checkver.reverse -eq 'true')
            replace  = if ($json.checkver.replace -is [string]) { $json.checkver.replace } else { '' }
            encoding = $null
        }

        # get_config PRIVATE_HOSTS | Where-Object { $_ -ne $null -and $url -match $_.match } | ForEach-Object {
        #     (ConvertFrom-StringData -StringData $_.Headers).GetEnumerator() | ForEach-Object {
        #         $wc.Headers[$_.Key] = $_.Value
        #     }
        # }

        $wc.Headers.Add('Referer', (strip_filename $url))
        $sourceId = [guid]::NewGuid().ToString()
        Register-ObjectEvent -InputObject $wc -EventName downloadDataCompleted -SourceIdentifier $sourceId -ErrorAction Stop | Out-Null

        $script:activeRequests[$sourceId] = [psobject]@{
            wc           = $wc
            state        = $state
            subscription = $sourceId
            startTime    = Get-Date
            cancelling   = $false
        }

        $wc.DownloadDataAsync($url, $state)
        $script:in_progress++
        break
    }
}

function Complete-Download([string] $subscriptionName) {
    if ($script:activeRequests.ContainsKey($subscriptionName)) {
        $entry = $script:activeRequests[$subscriptionName]
        Unregister-Event -SourceIdentifier $subscriptionName -ErrorAction SilentlyContinue
        Remove-Event -SourceIdentifier $subscriptionName -ErrorAction SilentlyContinue
        if ($entry.wc) {
            $entry.wc.Dispose()
        }
        $script:activeRequests.Remove($subscriptionName)
    }
    $script:in_progress--
}

for ($i = 0; $i -lt $MaxConcurrency -and $i -lt $Queue.Count; $i++) {
    Start-NextDownload
}

while ($in_progress -gt 0) {
    $ev = Wait-Event -Timeout 1
    if (-not $ev) {
        $now = Get-Date
        foreach ($key in @($activeRequests.Keys)) {
            $entry = $activeRequests[$key]
            if (($now - $entry.startTime).TotalSeconds -ge $TimeoutSec) {
                if (-not $entry.cancelling) {
                    $entry.cancelling = $true
                    $entry.wc.CancelAsync()
                }
            }
        }
        continue
    }

    Remove-Event $ev.SourceIdentifier

    $entry = $activeRequests[$ev.SourceIdentifier]
    if (-not $entry) {
        $script:in_progress--
        Start-NextDownload
        continue
    }

    $state = $entry.state
    $reqWc = $entry.wc

    $cancelled = $ev.SourceEventArgs.Cancelled
    $err = $ev.SourceEventArgs.Error
    $result = $null

    if ($reqWc -and !$err -and !$cancelled) {
        $result = $ev.SourceEventArgs.Result
        try {
            $state.encoding = Get-Encoding $reqWc
        }
        catch {
            $state.encoding = [System.Text.Encoding]::UTF8
        }
    }
    try {
        Invoke-ManifestResult -state $state -result $result -err $err -cancelled $cancelled
    }
    finally {
        Complete-Download $ev.SourceIdentifier
        Start-NextDownload
    }
}
