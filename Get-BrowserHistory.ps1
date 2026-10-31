<#
.SYNOPSIS
Collect Chrome, Edge and Firefox history using read-only SQLite snapshots.
.DESCRIPTION
Windows only. Install sqlite3 >= 3.33 on each target and make it available in PATH,
or pass -SqlitePath. No software is downloaded. Uses the SQLite backup API to
capture a consistent database including WAL data. Browsers are never terminated.
Requires permission to read selected profiles; outputs may contain sensitive URLs.
IE TypedURLs is not a complete history source and is no longer collected.
-AsJob returns jobs; use Receive-Job -Wait -AutoRemoveJob to retrieve results/errors.
.EXAMPLE
.\Get-BrowserHistory.ps1 -ComputerName workstation01 -UserName alice -SearchTerm example.com
.NOTES
Historical regex-based source: @oregon-national-guard/cyberspace-operations,
oregon-national-guard/powershell Get-BrowserHistory.ps1. The current implementation
replaces that collection logic with SQLite snapshots. Historical source and the
complete upstream notice are preserved in THIRD_PARTY.md and
LICENSES/Oregon-National-Guard-LICENCE.txt, including its specific-script exception.
#>
[CmdletBinding()]
param(
    [string[]]$ComputerName = @($env:COMPUTERNAME),
    [string]$UserName = '*',
    [string]$SearchTerm = '',
    [string]$SqlitePath = 'sqlite3',
    [string]$ProfileRoot,
    [pscredential]$Credential,
    [switch]$AsJob
)
$ErrorActionPreference = 'Stop'
# A self-contained block works in both local jobs and remote sessions.
$collector = {
    param($UserPattern, $Term, $SqliteExecutable, $Root)
    $ErrorActionPreference = 'Stop'
    if ($env:OS -ne 'Windows_NT') { throw 'This collector requires Windows browser profile paths.' }
    $sqlite = (Get-Command -Name $SqliteExecutable -CommandType Application -ErrorAction Stop).Source
    if (-not $Root) { $Root = Join-Path $env:SystemDrive 'Users' }
    function Invoke-HistorySqlite {
        [CmdletBinding()]
        param([string[]]$ArgumentList)
        # Process streams use explicit UTF-8, including in Windows PowerShell and
        # remote sessions without a console. Escape Windows argv, never a shell.
        $quoted = foreach ($argument in $ArgumentList) {
            $escaped = [regex]::Replace($argument, '(\*)"', '$1$1\"')
            $escaped = [regex]::Replace($escaped, '(\+)$', '$1$1')
            '"' + $escaped + '"'
        }
        $process = [Diagnostics.Process]::new()
        try {
            $process.StartInfo.FileName = $sqlite
            $process.StartInfo.Arguments = $quoted -join ' '
            $process.StartInfo.UseShellExecute = $false
            $process.StartInfo.CreateNoWindow = $true
            $process.StartInfo.RedirectStandardOutput = $true
            $process.StartInfo.RedirectStandardError = $true
            $process.StartInfo.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
            $process.StartInfo.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
            $null = $process.Start()
            $stdout = $process.StandardOutput.ReadToEndAsync()
            $stderr = $process.StandardError.ReadToEndAsync()
            if (-not $process.WaitForExit(120000)) {
                $process.Kill()
                $process.WaitForExit()
                throw 'SQLite command exceeded the two-minute timeout.'
            }
            $output = $stdout.GetAwaiter().GetResult()
            $errorText = $stderr.GetAwaiter().GetResult()
            if ($process.ExitCode -ne 0) { throw "SQLite exit code $($process.ExitCode): $errorText" }
            $output
        } finally { $process.Dispose() }
    }
    $sources = [System.Collections.Generic.List[object]]::new()
    foreach ($userProfile in (Get-ChildItem -LiteralPath $Root -Directory -Force)) {
        if ($userProfile.Name -notlike $UserPattern) { continue }
        foreach ($browser in 'Chrome','Edge') {
            $relative = if ($browser -eq 'Chrome') { 'AppData\Local\Google\Chrome\User Data' } else { 'AppData\Local\Microsoft\Edge\User Data' }
            $browserRoot = Join-Path $userProfile.FullName $relative
            if (-not (Test-Path -LiteralPath $browserRoot)) { continue }
            foreach ($browserProfile in (Get-ChildItem -LiteralPath $browserRoot -Directory)) {
                $database = Join-Path $browserProfile.FullName 'History'
                if (Test-Path -LiteralPath $database -PathType Leaf) {
                    $sources.Add([pscustomobject]@{ User = $userProfile.Name; Browser = $browser; Profile = $browserProfile.Name; Database = $database })
                }
            }
        }
        $browserRoot = Join-Path $userProfile.FullName 'AppData\Roaming\Mozilla\Firefox\Profiles'
        if (Test-Path -LiteralPath $browserRoot) {
            foreach ($browserProfile in (Get-ChildItem -LiteralPath $browserRoot -Directory)) {
                $database = Join-Path $browserProfile.FullName 'places.sqlite'
                if (Test-Path -LiteralPath $database -PathType Leaf) {
                    $sources.Add([pscustomobject]@{ User = $userProfile.Name; Browser = 'Firefox'; Profile = $browserProfile.Name; Database = $database })
                }
            }
        }
    }
    foreach ($source in $sources) {
        $snapshot = Join-Path ([IO.Path]::GetTempPath()) ("history-$([guid]::NewGuid()).sqlite")
        try {
            # The destination is generated by this script; escape the SQLite dot-command argument.
            $destination = $snapshot.Replace('\','/')
            try { $null = Invoke-HistorySqlite -ArgumentList @('-readonly', $source.Database, '.timeout 5000', ".backup `"$destination`"") }
            catch { throw "SQLite snapshot failed for $($source.Database): $_" }
            $sql = if ($source.Browser -eq 'Firefox') {
                "SELECT url, title, visit_count AS VisitCount, strftime('%Y-%m-%dT%H:%M:%fZ',last_visit_date/1000000.0,'unixepoch') AS LastVisitUtc FROM moz_places WHERE last_visit_date IS NOT NULL;"
            } else {
                "SELECT url, title, visit_count AS VisitCount, strftime('%Y-%m-%dT%H:%M:%fZ',(last_visit_time/1000000.0)-11644473600,'unixepoch') AS LastVisitUtc FROM urls WHERE last_visit_time > 0;"
            }
            try { $json = Invoke-HistorySqlite -ArgumentList @('-readonly','-json',$snapshot,$sql) }
            catch { throw "SQLite query failed for $($source.Database): $_" }
            if (-not $json) { continue }
            foreach ($record in (($json -join "`n") | ConvertFrom-Json)) {
                if ($Term -and $record.url.IndexOf($Term, [StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
                $uri = $null
                $domain = if ([uri]::TryCreate($record.url, [UriKind]::Absolute, [ref]$uri)) { $uri.Host } else { $null }
                [pscustomobject]@{
                    ComputerName = $env:COMPUTERNAME
                    UserName = $source.User
                    Browser = $source.Browser
                    Profile = $source.Profile
                    Url = $record.url
                    DomainName = $domain
                    Title = $record.title
                    VisitCount = $record.VisitCount
                    LastVisitUtc = ([datetimeoffset]$record.LastVisitUtc).UtcDateTime.ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'")
                }
            }
        } finally {
            if (Test-Path -LiteralPath $snapshot) { Remove-Item -LiteralPath $snapshot -Force }
        }
    }
}
foreach ($computer in $ComputerName) {
    $local = $computer -in @('.', 'localhost', $env:COMPUTERNAME)
    if ($local -and -not $Credential) {
        if ($AsJob) { Start-Job -ScriptBlock $collector -ArgumentList $UserName,$SearchTerm,$SqlitePath,$ProfileRoot }
        else { & $collector $UserName $SearchTerm $SqlitePath $ProfileRoot }
    } else {
        $invoke = @{ ComputerName = $computer; ScriptBlock = $collector; ArgumentList = $UserName,$SearchTerm,$SqlitePath,$ProfileRoot; AsJob = $AsJob }
        if ($Credential) { $invoke.Credential = $Credential }
        Invoke-Command @invoke
    }
}
