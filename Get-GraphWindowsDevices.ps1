<#
.SYNOPSIS
Report Windows directory devices from the connected Microsoft Graph tenant.
.EXAMPLE
.\Get-GraphWindowsDevices.ps1 -TenantId TENANT-GUID
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$TenantId, [string]$OutputPath, [switch]$Force)
& "$PSScriptRoot/Export-GraphDevices.ps1" @PSBoundParameters -OperatingSystem Windows
