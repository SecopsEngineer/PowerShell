<#
.SYNOPSIS
Report Graph directory devices with optional OS and display-name prefix filters.
.DESCRIPTION
Connect-MgGraph first with Device.Read.All. IsCompliant is the directory's nullable
compliance flag, not a full Intune compliance assessment. No data is exported unless
-OutputPath is supplied. This is the shared implementation for the Graph device reports.
.EXAMPLE
.\Export-GraphDevices.ps1 -TenantId TENANT-GUID -OperatingSystem Windows -OutputPath .\devices.csv
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$TenantId,
    [string]$OperatingSystem,
    [string]$DisplayNamePrefix,
    [string]$OutputPath,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Private/Common.ps1"
Assert-ToolkitGraphContext -TenantId $TenantId
$properties = 'id','deviceId','displayName','operatingSystem','operatingSystemVersion','onPremisesLastSyncDateTime','isCompliant','isManaged','accountEnabled'
$query = @{ All = $true; Property = $properties }
$filters = @()
if ($OperatingSystem) { $filters += "operatingSystem eq '$($OperatingSystem.Replace("'", "''"))'" }
if ($DisplayNamePrefix) { $filters += "startsWith(displayName,'$($DisplayNamePrefix.Replace("'", "''"))')" }
if ($filters.Count) { $query.Filter = $filters -join ' and ' }
$rows = @(Get-MgDevice @query -ErrorAction Stop | Select-Object $properties)
if ($OutputPath) { Export-ToolkitReport -InputObject $rows -Path $OutputPath -Force:$Force }
$rows
