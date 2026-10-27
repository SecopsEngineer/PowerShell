<#
.SYNOPSIS
Report enabled AD accounts whose expiration date has passed.
.DESCRIPTION
The original script did not filter expired accounts. Use -WithoutExpiration to
report enabled accounts with no expiration date instead, as its old help described.
.EXAMPLE
.\Get-ADExpiredAccounts.ps1 -Server dc.example.com
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Server, [pscredential]$Credential, [switch]$WithoutExpiration, [string]$OutputPath, [switch]$Force)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Private/Common.ps1"
$query = @{ Server = $Server; Filter = 'Enabled -eq $true'; Properties = 'AccountExpirationDate' }
if ($Credential) { $query.Credential = $Credential }
$now = Get-Date
$rows = @(Get-ADUser @query -ErrorAction Stop | Where-Object {
    if ($WithoutExpiration) { $null -eq $_.AccountExpirationDate }
    else { $null -ne $_.AccountExpirationDate -and $_.AccountExpirationDate -lt $now }
} | Select-Object Name, SamAccountName, DistinguishedName, AccountExpirationDate)
if ($OutputPath) { Export-ToolkitReport -InputObject $rows -Path $OutputPath -Force:$Force }
$rows
