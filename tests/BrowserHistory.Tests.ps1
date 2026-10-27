BeforeAll {
    $repo = Split-Path $PSScriptRoot -Parent
    $sqliteCommand = Get-Command sqlite3 -CommandType Application -ErrorAction SilentlyContinue
    $sqlite = if ($env:TOOLKIT_TEST_SQLITE) { $env:TOOLKIT_TEST_SQLITE } elseif ($sqliteCommand) { $sqliteCommand.Source } else { $null }
}
Describe 'Browser history SQLite integration' -Skip:($env:OS -ne 'Windows_NT') {
    BeforeEach {
        if (-not $sqlite) { throw 'SQLite >= 3.33 is required for the browser integration tests. Set TOOLKIT_TEST_SQLITE or install sqlite3 in PATH.' }
        $profileRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $chrome = Join-Path $profileRoot 'alice/AppData/Local/Google/Chrome/User Data/Profile 1'
        $firefox = Join-Path $profileRoot 'alice/AppData/Roaming/Mozilla/Firefox/Profiles/example.default-release'
        $null = New-Item -ItemType Directory -Path $chrome,$firefox -Force
        $chromeDb = Join-Path $chrome History
        $firefoxDb = Join-Path $firefox places.sqlite
        & $sqlite $chromeDb "CREATE TABLE urls (url TEXT,title TEXT,visit_count INTEGER,last_visit_time INTEGER); INSERT INTO urls VALUES ('https://example.com/a?x=1','Éxample',3,13380163200000000),('https://other.test','Other',1,13380163200000000);"
        if ($LASTEXITCODE) { throw 'Chrome fixture creation failed.' }
        & $sqlite $firefoxDb "CREATE TABLE moz_places (url TEXT,title TEXT,visit_count INTEGER,last_visit_date INTEGER); INSERT INTO moz_places VALUES ('https://example.com/firefox','Firefox',2,1735689600000000);"
        if ($LASTEXITCODE) { throw 'Firefox fixture creation failed.' }
    }
    It 'queries non-default Chromium and modern Firefox profiles with correct UTC epochs' {
        $rows = @(& "$repo/Get-BrowserHistory.ps1" -ComputerName localhost -ProfileRoot $profileRoot -SqlitePath $sqlite -UserName alice -SearchTerm example.com)
        $rows.Count | Should -Be 2
        ($rows | Where-Object Browser -eq Chrome).LastVisitUtc | Should -Be '2025-01-01T00:00:00.000Z'
        ($rows | Where-Object Browser -eq Firefox).LastVisitUtc | Should -Be '2025-01-01T00:00:00.000Z'
        ($rows | Where-Object Browser -eq Chrome).VisitCount | Should -Be 3
        $rows[0].DomainName | Should -Be 'example.com'
        $rows[0].UserName | Should -Be alice
        ($rows | Where-Object Browser -eq Chrome).Title | Should -Be 'Éxample'
    }
    It 'runs a complete collector in the local job without missing helper functions' {
        $job = & "$repo/Get-BrowserHistory.ps1" -ComputerName localhost -ProfileRoot $profileRoot -SqlitePath $sqlite -AsJob -SearchTerm firefox
        try {
            $rows = @($job | Receive-Job -Wait -ErrorAction Stop)
            $job.State | Should -Be Completed
            $rows.Count | Should -Be 1
            $rows[0].Browser | Should -Be Firefox
        } finally { $job | Remove-Job -Force }
    }
    It 'treats the search term literally rather than as a regular expression' {
        $rows = @(& "$repo/Get-BrowserHistory.ps1" -ComputerName localhost -ProfileRoot $profileRoot -SqlitePath $sqlite -SearchTerm '?x=1')
        $rows.Count | Should -Be 1
        $rows[0].Url | Should -Be 'https://example.com/a?x=1'
    }
    It 'reports SQLite/schema errors rather than returning a clean empty history' {
        & $sqlite $chromeDb 'DROP TABLE urls;'
        { & "$repo/Get-BrowserHistory.ps1" -ComputerName localhost -ProfileRoot $profileRoot -SqlitePath $sqlite } | Should -Throw '*SQLite query failed*'
    }
}
