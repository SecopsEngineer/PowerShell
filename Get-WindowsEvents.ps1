<#
.SYNOPSIS
Read Windows events for an explicit host and time window; optionally export CSV.
.DESCRIPTION
Requires Windows Event Log remote access and appropriate log-read permissions.
Times are interpreted by PowerShell as supplied; include an offset for portability.
.EXAMPLE
.\Get-WindowsEvents.ps1 -ComputerName server01 -LogName System -StartTime '2026-10-01T00:00:00-05:00' -EndTime '2026-10-02T00:00:00-05:00'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ComputerName,
    [Parameter(Mandatory)][datetime]$StartTime,
    [Parameter(Mandatory)][datetime]$EndTime,
    [string]$LogName = 'System',
    [int[]]$Id,
    [pscredential]$Credential,
    [string]$OutputPath,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Private/Common.ps1"
if ($StartTime -ge $EndTime) { throw 'StartTime must precede EndTime.' }
$filter = @{ LogName = $LogName; StartTime = $StartTime; EndTime = $EndTime }
if ($Id) { $filter.Id = $Id }
$query = @{ ComputerName = $ComputerName; FilterHashtable = $filter }
if ($Credential) { $query.Credential = $Credential }
try {
    $rows = @(Get-WinEvent @query -ErrorAction Stop | Select-Object MachineName, LogName, TimeCreated, Id, LevelDisplayName, ProviderName, RecordId, Message)
} catch {
    if ($_.FullyQualifiedErrorId -notlike 'NoMatchingEventsFound*') { throw }
    $rows = @()
}
if ($OutputPath) { Export-ToolkitReport -InputObject $rows -Path $OutputPath -Force:$Force }
$rows
