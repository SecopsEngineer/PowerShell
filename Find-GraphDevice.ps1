<#
.SYNOPSIS
Find directory devices by display-name prefix, returning every matching page.
.EXAMPLE
.\Find-GraphDevice.ps1 -TenantId TENANT-GUID -DisplayNamePrefix Android
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$TenantId, [Parameter(Mandatory)][string]$DisplayNamePrefix, [string]$OutputPath, [switch]$Force)
& "$PSScriptRoot/Export-GraphDevices.ps1" @PSBoundParameters
