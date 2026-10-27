<#
.SYNOPSIS
Report AD users configured with non-expiring passwords.
.EXAMPLE
.\Get-ADPasswordNeverExpires.ps1 -Server dc.example.com -OutputPath .\passwords.csv
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Server, [string]$OutputPath, [switch]$Force)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Private/Common.ps1"
$rows = @(Get-ADUser -Server $Server -Filter 'PasswordNeverExpires -eq $true' -Properties PasswordNeverExpires -ErrorAction Stop |
    Select-Object Name, SamAccountName, DistinguishedName, Enabled, PasswordNeverExpires)
if ($OutputPath) { Export-ToolkitReport -InputObject $rows -Path $OutputPath -Force:$Force }
$rows
