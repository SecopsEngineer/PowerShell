<#
.SYNOPSIS
Report nullable Graph directory compliance flags; this is not a full Intune assessment.
.EXAMPLE
.\Get-GraphDeviceCompliance.ps1 -TenantId TENANT-GUID
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$TenantId, [string]$OutputPath, [switch]$Force)
& "$PSScriptRoot/Export-GraphDevices.ps1" @PSBoundParameters
