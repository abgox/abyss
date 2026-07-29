<#
.SYNOPSIS
    Check manifest for a newer version.
.DESCRIPTION
    Checks websites for newer versions using an (optional) regular expression defined in the manifest.
.PARAMETER App
    Manifest name to search.
    Placeholders are supported.
.PARAMETER Dir
    Where to search for manifest(s).
.PARAMETER Update
    Update given manifest
.PARAMETER ForceUpdate
    Update given manifest(s) even when there is no new version.
    Useful for hash updates.
.PARAMETER SkipUpdated
    Updated manifests will not be shown.
.PARAMETER Version
    Update manifest to specific version.
.PARAMETER ThrowError
    Throw error as exception instead of just printing it.
.PARAMETER MaxConcurrency
    Maximum number of concurrent downloads.
.PARAMETER TimeoutSec
    Per-request timeout, in seconds.
.EXAMPLE
    PS BUCKETROOT > .\bin\checkver.ps1
    Check all manifest inside default directory.
.EXAMPLE
    PS BUCKETROOT > .\bin\checkver.ps1 -SkipUpdated
    Check all manifest inside default directory (list only outdated manifests).
.EXAMPLE
    PS BUCKETROOT > .\bin\checkver.ps1 -Update
    Check all manifests and update All outdated manifests.
.EXAMPLE
    PS BUCKETROOT > .\bin\checkver.ps1 APP
    Check manifest APP.json inside default directory.
.EXAMPLE
    PS BUCKETROOT > .\bin\checkver.ps1 APP -Update
    Check manifest APP.json and update, if there is newer version.
.EXAMPLE
    PS BUCKETROOT > .\bin\checkver.ps1 APP -ForceUpdate
    Check manifest APP.json and update, even if there is no new version.
.EXAMPLE
    PS BUCKETROOT > .\bin\checkver.ps1 APP -Update -Version VER
    Check manifest APP.json and update, using version VER
.EXAMPLE
    PS BUCKETROOT > .\bin\checkver.ps1 APP DIR
    Check manifest APP.json inside ./DIR directory.
.EXAMPLE
    PS BUCKETROOT > .\bin\checkver.ps1 -Dir DIR
    Check all manifests inside ./DIR directory.
.EXAMPLE
    PS BUCKETROOT > .\bin\checkver.ps1 APP DIR -Update
    Check manifest APP.json inside ./DIR directory and update if there is newer version.
#>
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

# get apps to check
$Queue = @()
$json = ''

foreach ($f in $files) {
    $file = $f.FullName
    $json = parse_json $file
    if ($json.checkver) {
        $Queue += , @($f.BaseName, $json, $file)
    }
}

# clear any existing events
Get-Event | Remove-Event
Get-EventSubscriber | Unregister-Event

$queueIndex = 0
$in_progress = 0
# key: subscription identifier (string) -> @{ wc; state; subscription; startTime }
$activeRequests = @{}

function Invoke-ManifestResult($state, $result, $err, $cancelled) {
    $app = $state.app
    $file = $state.file
    $json = $state.json
    $url = $state.url
    $regexp = $state.regex
    $jsonpath = $state.jsonpath
    $xpath = $state.xpath
    $script_code = $json.checkver.script
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
        if (!$regexp -and $replace) {
            next $app "'replace' requires 're' or 'regex'"
            return
        }

        if ($cancelled) {
            if (!$script_code) {
                next $app "timed out after ${TimeoutSec}s`r`nURL $url is not valid"
                return
            }
            else {
                Write-Host "${app}: Request timed out after ${TimeoutSec}s. Falling back to checkver.script ..." -ForegroundColor DarkYellow
            }
        }

        if ($err) {
            if (!$script_code) {
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

        if ($script_code) {
            $page = Invoke-Command ([scriptblock]::Create($script_code -join "`r`n"))
            $source = 'the output of script'
        }

        if ($null -eq $page) {
            next $app "couldn't retrieve content from $source"
            return
        }

        if ($jsonpath) {
            $noregex = [String]::IsNullOrEmpty($regexp)
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

        if ($jsonpath -and $regexp) { $page = $ver; $ver = '' }
        if ($xpath -and $regexp) { $page = $ver; $ver = '' }

        if ($regexp) {
            $re = New-Object System.Text.RegularExpressions.Regex($regexp)
            $match = if ($reverse) { $re.Matches($page) | Select-Object -Last 1 } else { $re.Matches($page) | Select-Object -First 1 }

            if ($match -and $match.Success) {
                $re.GetGroupNames() | ForEach-Object { $matchesHashtable[$_] = $match.Groups[$_].Value }
                $ver = $matchesHashtable['1']
                if ($replace) { $ver = $re.Replace($match.Value, $replace) }
                if (!$ver) { $ver = $matchesHashtable['version'] }
            }
            else {
                next $app "couldn't match '$regexp' in $source"
                return
            }
        }

        if (!$ver) {
            next $app "couldn't find new version in $source"
            return
        }
    }

    if ($json.checkver.max -and (Compare-Version -ReferenceVersion $ver -DifferenceVersion $json.checkver.max) -eq -1) {
        $ver = $expected_ver
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
            Invoke-AutoUpdate $app $file $json $ver $matchesHashtable
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

        if (-not $json.checkver.url) {
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
    if (-not $entry) { continue }

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
