<#
.SYNOPSIS
Report enabled AD users with no telephone, mobile, or home phone value.
.EXAMPLE
.\Get-ADMissingPhoneNumbers.ps1 -Server dc.example.com -Credential (Get-Credential)
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Server, [pscredential]$Credential, [string]$OutputPath, [switch]$Force)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Private/Common.ps1"
$query = @{ Server = $Server; Filter = 'Enabled -eq $true'; Properties = 'telephoneNumber','MobilePhone','HomePhone' }
if ($Credential) { $query.Credential = $Credential }
$rows = @(Get-ADUser @query -ErrorAction Stop | Where-Object {
    [string]::IsNullOrWhiteSpace($_.telephoneNumber) -and [string]::IsNullOrWhiteSpace($_.MobilePhone) -and [string]::IsNullOrWhiteSpace($_.HomePhone)
} | Select-Object Name, SamAccountName, telephoneNumber, MobilePhone, HomePhone)
if ($OutputPath) { Export-ToolkitReport -InputObject $rows -Path $OutputPath -Force:$Force }
$rows
