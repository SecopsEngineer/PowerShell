<#
.SYNOPSIS
Report AD users created within a configurable number of days (default 30).
.DESCRIPTION
Creator attribution requires retained DC security audit event 4720. It is not a
standard CreatedBy user property; use Get-ADUserCreationAudit.ps1 for that evidence.
.EXAMPLE
.\Get-ADRecentlyCreatedUsers.ps1 -Server dc.example.com -Days 30
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Server, [ValidateRange(1,36500)][int]$Days = 30, [string]$OutputPath, [switch]$Force)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Private/Common.ps1"
$since = (Get-Date).AddDays(-$Days)
$rows = @(Get-ADUser -Server $Server -Filter { whenCreated -ge $since } -Properties whenCreated -ErrorAction Stop |
    Select-Object Name, SamAccountName, DistinguishedName, whenCreated)
if ($OutputPath) { Export-ToolkitReport -InputObject $rows -Path $OutputPath -Force:$Force }
$rows
