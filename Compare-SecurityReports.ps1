<#
.SYNOPSIS
Compare two CSV reports by explicit unique keys, showing added/removed/changed entries.
.DESCRIPTION
No external modules or service connections required. Keys and values are compared
case-sensitively as CSV strings; null versus empty cannot be distinguished in CSV.
Composite keys are JSON-encoded to avoid delimiter collisions. Duplicate/blank keys
are rejected. By default schemas must match; use -CompareProperty for an explicit
shared subset. Header-only CSVs are supported; empty files without headers are not.
Added/Removed rows contain complete row JSON; Changed rows contain per-property
values. Output cannot overwrite either input, even with -Force.
.EXAMPLE
.\Compare-SecurityReports.ps1 -BeforePath .\before.csv -AfterPath .\after.csv -Key ComputerName,Id -OutputPath .\changes.csv
.EXAMPLE
.\Compare-SecurityReports.ps1 -BeforePath .\old.csv -AfterPath .\new.csv -Key Id -CompareProperty Enabled,Name
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BeforePath,
    [Parameter(Mandatory)][string]$AfterPath,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string[]]$Key,
    [string[]]$CompareProperty,
    [string]$OutputPath,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Private/Common.ps1"
function Read-SecurityReport {
    param([string]$Path)
    $records = @(Import-Csv -LiteralPath $Path -ErrorAction Stop -WarningAction Stop)
    $schema = if ($records.Count) { @($records[0].PSObject.Properties.Name) } else {
        # Duplicate a header-only CSV into a synthetic data row to parse its schema,
        # including quoted commas/newlines, without hand-splitting the CSV format.
        $text = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($text)) { throw "CSV has no header: $Path" }
        $headerRow = @(ConvertFrom-Csv -InputObject ($text.TrimEnd() + "`n" + $text) -ErrorAction Stop -WarningAction Stop)
        if (-not $headerRow.Count) { throw "CSV has no readable header: $Path" }
        @($headerRow[0].PSObject.Properties.Name)
    }
    [pscustomobject]@{ Records = $records; Schema = $schema }
}
function ConvertTo-ReportIndex {
    param([object[]]$Records, [string]$Label)
    $index = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach ($record in $Records) {
        $parts = [ordered]@{}
        foreach ($column in $Key) {
            $value = [string]$record.$column
            if ([string]::IsNullOrWhiteSpace($value)) { throw "Blank key '$column' in $Label." }
            $parts[$column] = $value
        }
        $encoded = ConvertTo-Json -InputObject $parts -Compress
        if ($index.ContainsKey($encoded)) { throw "Duplicate key in ${Label}: $encoded" }
        $index.Add($encoded, $record)
    }
    # Preserve an empty dictionary as one return value.
    ,$index
}
$before = Read-SecurityReport $BeforePath
$after = Read-SecurityReport $AfterPath
if (@($Key | Sort-Object -Unique).Count -ne $Key.Count) { throw 'Key columns must be unique.' }
foreach ($column in $Key) {
    if ($column -notin $before.Schema -or $column -notin $after.Schema) { throw "Key column not present in both reports: $column" }
}
if ($CompareProperty) {
    foreach ($column in $CompareProperty) {
        if ($column -notin $before.Schema -or $column -notin $after.Schema) { throw "Comparison column not present in both reports: $column" }
    }
    $columns = @($CompareProperty | Sort-Object -Unique | Where-Object { $_ -notin $Key })
} else {
    if (@($before.Schema | Where-Object { $_ -notin $after.Schema }).Count -or @($after.Schema | Where-Object { $_ -notin $before.Schema }).Count) {
        throw 'Report schemas differ. Use -CompareProperty to select a shared subset explicitly.'
    }
    $columns = @($before.Schema | Where-Object { $_ -notin $Key })
}
if ($OutputPath) {
    $destination = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
    foreach ($inputPath in $BeforePath,$AfterPath) {
        if ($destination -eq (Resolve-Path -LiteralPath $inputPath).ProviderPath) { throw 'OutputPath cannot overwrite an input report.' }
    }
}
$old = ConvertTo-ReportIndex -Records $before.Records -Label Before
$new = ConvertTo-ReportIndex -Records $after.Records -Label After
$allKeys = [Collections.Generic.SortedSet[string]]::new([StringComparer]::Ordinal)
foreach ($entryKey in $old.Keys) { $null = $allKeys.Add($entryKey) }
foreach ($entryKey in $new.Keys) { $null = $allKeys.Add($entryKey) }
$rows = @(foreach ($entryKey in $allKeys) {
    if (-not $old.ContainsKey($entryKey)) {
        [pscustomobject]@{ ChangeType = 'Added'; Key = $entryKey; Property = '*'; Before = $null; After = (ConvertTo-Json -InputObject $new[$entryKey] -Compress) }
    } elseif (-not $new.ContainsKey($entryKey)) {
        [pscustomobject]@{ ChangeType = 'Removed'; Key = $entryKey; Property = '*'; Before = (ConvertTo-Json -InputObject $old[$entryKey] -Compress); After = $null }
    } else {
        foreach ($column in $columns) {
            $previous = [string]$old[$entryKey].$column
            $current = [string]$new[$entryKey].$column
            if (-not [string]::Equals($previous, $current, [StringComparison]::Ordinal)) {
                [pscustomobject]@{ ChangeType = 'Changed'; Key = $entryKey; Property = $column; Before = $previous; After = $current }
            }
        }
    }
})
if ($OutputPath) { Export-ToolkitReport -InputObject $rows -Path $OutputPath -Force:$Force }
$rows
