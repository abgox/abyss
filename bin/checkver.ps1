#Requires -Version 7.0

param(
    [String] $App = '*',
    [String] $Dir = "$PSScriptRoot/../bucket",
    [String] $Segment,
    [Switch] $Update,
    [Switch] $ForceUpdate,
    [Switch] $SkipUpdated,
    [String] $Version = '',
    [Switch] $ThrowError,
    [Switch] $Commit,
    [int] $MaxConcurrency = 100,
    [int] $TimeoutSec = 30
)

if (-not $env:SCOOP_HOME) { $env:SCOOP_HOME = Convert-Path (scoop prefix scoop) }

. "$env:SCOOP_HOME\lib\core.ps1"
. "$env:SCOOP_HOME\lib\autoupdate.ps1"

# TODO: https://github.com/ScoopInstaller/Scoop/pull/6772
function get_hash_for_app([String] $app, $config, [String] $version, [String] $url, [Hashtable] $substitutions) {
    $hash = $null

    $hashmode = $config.mode
    $originurl = strip_fragment $url
    $basename = [System.Web.HttpUtility]::UrlDecode((url_remote_filename($url)))

    $substitutions = $substitutions.Clone()
    $substitutions.Add('$url', $originurl)
    $substitutions.Add('$baseurl', (strip_filename $originurl).TrimEnd('/'))
    $substitutions.Add('$basename', $basename)
    $substitutions.Add('$urlNoExt', (strip_ext $originurl))
    $substitutions.Add('$basenameNoExt', (strip_ext $basename))

    debug $substitutions

    $hashfile_url = substitute $config.url $substitutions
    debug $hashfile_url
    if ($hashfile_url) {
        Write-Host 'Searching hash for ' -ForegroundColor DarkYellow -NoNewline
        Write-Host $basename -ForegroundColor Green -NoNewline
        Write-Host ' in ' -ForegroundColor DarkYellow -NoNewline
        Write-Host $hashfile_url -ForegroundColor Green
    }

    if ($hashmode.Length -eq 0 -and $config.url.Length -ne 0) {
        $hashmode = 'extract'
    }

    $jsonpath = ''
    if ($config.jp) {
        $jsonpath = $config.jp
        $hashmode = 'json'
    }
    if ($config.jsonpath) {
        $jsonpath = $config.jsonpath
        $hashmode = 'json'
    }
    $regex = ''
    if ($config.find) {
        $regex = $config.find
    }
    if ($config.regex) {
        $regex = $config.regex
    }

    $xpath = ''
    if ($config.xpath) {
        $xpath = $config.xpath
        $hashmode = 'xpath'
    }

    if (!$hashfile_url -and $url -match '^(?:.*fosshub.com\/).*(?:\/|\?dwl=)(?<filename>.*)$') {
        $hashmode = 'fosshub'
    }

    if (!$hashfile_url -and $url -match '(?:downloads\.)?sourceforge.net\/projects?\/(?<project>[^\/]+)\/(?:files\/)?(?<file>.*)') {
        $hashmode = 'sourceforge'
    }

    if (!$hashfile_url -and $url -match 'https:\/\/github\.com\/(?<owner>[^\/]+)\/(?<repo>[^\/]+)\/releases\/download\/[^\/]+\/[^\/]+') {
        $hashmode = 'github'
    }

    switch ($hashmode) {
        'extract' {
            $hash = find_hash_in_textfile $hashfile_url $substitutions $regex
        }
        'json' {
            $hash = find_hash_in_json $hashfile_url $substitutions $jsonpath
        }
        'xpath' {
            $hash = find_hash_in_xml $hashfile_url $substitutions $xpath
        }
        'rdf' {
            $hash = find_hash_in_rdf $hashfile_url $basename
        }
        'metalink' {
            $hash = find_hash_in_headers $url
            if (!$hash) {
                $hash = find_hash_in_textfile "$url.meta4" $substitutions
            }
        }
        'fosshub' {
            $hash = find_hash_in_textfile $url $substitutions ($matches.filename + '.*?"sha256":"([a-fA-F0-9]{64})"')
        }
        'sourceforge' {
            # change the URL because downloads.sourceforge.net doesn't have checksums
            $hashfile_url = (strip_filename (strip_fragment "https://sourceforge.net/projects/$($matches['project'])/files/$($matches['file'])")).TrimEnd('/')
            $hash = find_hash_in_textfile $hashfile_url $substitutions '"$basename":.*?"sha1":\s*"([a-fA-F0-9]{40})"'
        }
        'github' {
            $hashfile_url = "https://api.github.com/repos/$($matches['owner'])/$($matches['repo'])/releases"
            $hash = find_hash_in_json $hashfile_url $substitutions ("$..assets[?(@.browser_download_url == '" + $originurl + "')].digest")
            if (!$hash -and ($originurl -match '^(?<prefix>https?://[^/]+)(?<path>/.*)$')) {
                # GitHub percent-encodes special characters (e.g. '+', spaces) in browser_download_url,
                # while manifests often use the raw characters, so the exact match above misses.
                # Retry with the URL normalized to canonical percent-encoded form,
                # but only when normalization actually changes the URL.
                $encodedurl = $matches['prefix'] + (($matches['path'] -split '/' | ForEach-Object {
                            if ($_) { [System.Uri]::EscapeDataString([System.Uri]::UnescapeDataString($_)) } else { '' }
                        }) -join '/')
                if ($encodedurl -cne $originurl) {
                    $hash = find_hash_in_json $hashfile_url $substitutions ("$..assets[?(@.browser_download_url == '" + $encodedurl + "')].digest")
                }
            }
        }
    }

    if ($hash) {
        # got one!
        Write-Host 'Found: ' -ForegroundColor DarkYellow -NoNewline
        Write-Host $hash -ForegroundColor Green -NoNewline
        Write-Host ' using ' -ForegroundColor DarkYellow -NoNewline
        Write-Host "$((Get-Culture).TextInfo.ToTitleCase($hashmode)) Mode" -ForegroundColor Green
        return $hash
    }
    elseif ($hashfile_url) {
        Write-Host -f DarkYellow "Could not find hash in $hashfile_url"
    }

    Write-Host 'Downloading ' -ForegroundColor DarkYellow -NoNewline
    Write-Host $basename -ForegroundColor Green -NoNewline
    Write-Host ' to compute hashes!' -ForegroundColor DarkYellow
    try {
        Invoke-CachedDownload $app $version $url $null $null $true
    }
    catch [system.net.webexception] {
        Write-Host $_ -ForegroundColor DarkRed
        Write-Host "URL $url is not valid" -ForegroundColor DarkRed
        return $null
    }
    $file = cache_path $app $version $url
    $hash = (Get-FileHash -Path $file -Algorithm SHA256).Hash.ToLower()
    Write-Host 'Computed hash: ' -ForegroundColor DarkYellow -NoNewline
    Write-Host $hash -ForegroundColor Green
    return $hash
}

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
    Write-Host "${appName}: $($PSStyle.Foreground.Red)$er"
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
    $regexp = A-Get-VersionRegex -SpecifiedRegex $state.regex
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
    $versionResolved = $false

    if (!$ver) {
        if ($cancelled) {
            if ($script) {
                Write-Warning "${app}: Request timed out after ${TimeoutSec}s. Falling back to checkver.script ..."
            }
            else {
                next $app "timed out after ${TimeoutSec}s`r`nURL $url is not valid"
                return
            }
        }
        if ($err) {
            if ($script) {
                Write-Warning "$($err.message)`r`nURL $url is not valid. Falling back to checkver.script ..."
            }
            else {
                next $app "$($err.message)`r`nURL $url is not valid"
                return
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
            try {
                $page = Invoke-Command ([scriptblock]::Create($script -join "`r`n"))
            }
            catch {
                next $app "checkver.script failed: $($_.Exception.Message)"
                return
            }
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
                $channel = $checkver.github.channel, 'latest' | Select-Object -First 1
                if ($checkver.github.raw) {
                    $page = A-Get-GitHubReleasePage -Channel $channel
                    $source = if ($checkver.github.tag) { "github release '$($checkver.github.tag)'" } else { "github releases ($channel)" }
                }
                else {
                    $candidateVersions = A-Get-VersionFromGitHub -Channel $channel
                    $source = 'github'
                }
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
                $source = 'installer'
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
                $resolved = A-Resolve-CandidateVersion -CandidateVersions $candidateVersions -Checkver $checkver -Replace $replace -Reverse $reverse -ExpectedVer $expected_ver -MatchesHashtable ([ref]$matchesHashtable) -Version ([ref]$ver)
                if ($resolved -and $ver) {
                    $versionResolved = $true
                }
            }
            if (!$ver -and $page -and !$versionResolved) {
                if ($jsonpath) {
                    $noregex = !$checkver.regex
                    $single = $noregex -and -not $checkver.max
                    $ver = json_path $page $jsonpath $null ($reverse -and $noregex) $single
                    if (!$ver) { $ver = json_path_legacy $page $jsonpath }
                    if (!$ver) {
                        next $app "couldn't find '$jsonpath' in $source"
                        return
                    }
                    if ($checkver.max -and $ver -is [string] -and $ver -match '^\s*\[.*\]\s*$') {
                        try {
                            $array = $ver | ConvertFrom-Json
                            if ($array -is [array] -and $array.Count -gt 0) {
                                $arrayVersions = $array | ForEach-Object { $_.ToString() }
                                $resolved = A-Resolve-CandidateVersion -CandidateVersions $arrayVersions -Checkver $checkver -Replace $replace -Reverse $reverse -ExpectedVer $expected_ver -MatchesHashtable ([ref]$matchesHashtable) -Version ([ref]$ver)
                                if ($resolved -and $ver) {
                                    $versionResolved = $true
                                }
                            }
                        }
                        catch {}
                    }
                }
                if ($xpath -and !$versionResolved) {
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
                if ($ver -and $checkver.max -and -not $checkver.regex -and !$versionResolved) {
                    $filtered = A-Select-VersionLessOrEqual -Versions @($ver) -MaxVersion $checkver.max
                    if (-not $filtered -or $filtered.Count -eq 0) {
                        $ver = $expected_ver
                        Write-Warning "No version <= max '$($checkver.max)', keeping $expected_ver"
                    }
                    else {
                        $ver = A-Convert-VersionWithRegex -Version $ver -Regex $regexp -MatchesHashtable ([ref]$matchesHashtable)
                    }
                    $versionResolved = $true
                }
                if ($ver -and -not $checkver.regex -and !$versionResolved) {
                    $ver = A-Convert-VersionWithRegex -Version $ver -Regex $regexp -MatchesHashtable ([ref]$matchesHashtable)
                    $versionResolved = $true
                }
                if (($jsonpath -or $xpath) -and $checkver.regex -and !$versionResolved) {
                    $page = $ver
                    $ver = ''
                }
                if (!$ver -and $regexp -and !$versionResolved) {
                    $ver = A-Get-RegexMatchesWithMax -Page $page -Regex $regexp -Replace $replace -MaxVersion $checkver.max -Reverse $reverse -MatchesHashtable ([ref]$matchesHashtable)
                    if (-not $ver) {
                        if ($checkver.max) {
                            $ver = $expected_ver
                            Write-Warning "No version <= max '$($checkver.max)', keeping $expected_ver"
                        }
                        else {
                            next $app "couldn't match '$regexp' in $source"
                            return
                        }
                    }
                    $versionResolved = $true
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

    $commitMsg = $null
    if ($script:App -ne '*') {
        $commitMsg = if ($expected_ver -eq '0.0.0' -or (git status --short -- $file) -match '^\s*(A|\?\?)') {
            "${app}: add version $ver"
        }
        else {
            "${app}: update to version $ver"
        }
    }

    $shouldUpdate = $script:Update -or $script:ForceUpdate
    if ($shouldUpdate -and $json.autoupdate) {
        if ($script:ForceUpdate) {
            Write-Host 'Forcing autoupdate!' -ForegroundColor DarkMagenta
        }
        try {
            $ver = A-Resolve-UrlVersion $json $ver $matchesHashtable
            Invoke-AutoUpdate $app $file $json $ver $matchesHashtable
            if ($commitMsg) {
                Write-Host $commitMsg -ForegroundColor Yellow
                if ($script:Commit) {
                    git -c core.safecrlf=false add -- $file
                    git -c core.safecrlf=false commit -m $commitMsg -- $file
                }
            }
        }
        catch {
            if ($script:ThrowError) { throw $_ } else { error $_.Exception.Message }
        }
    }
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
        Unregister-Event -SourceIdentifier $subscriptionName -ErrorAction Ignore
        Remove-Event -SourceIdentifier $subscriptionName -ErrorAction Ignore
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
                elseif (($now - $entry.startTime).TotalSeconds -ge ($TimeoutSec + 30)) {
                    Write-Warning "'$($entry.state.app)': download did not complete after cancellation, forcing cleanup"
                    Unregister-Event -SourceIdentifier $key -ErrorAction SilentlyContinue
                    Remove-Event -SourceIdentifier $key -ErrorAction SilentlyContinue
                    try { $entry.wc.Dispose() } catch {}
                    $activeRequests.Remove($key)
                    if ($script:in_progress -gt 0) { $script:in_progress-- }
                    Start-NextDownload
                }
            }
        }
        continue
    }

    Remove-Event $ev.SourceIdentifier

    $entry = $activeRequests[$ev.SourceIdentifier]
    if (-not $entry) {
        if ($script:in_progress -gt 0) { $script:in_progress-- }
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
