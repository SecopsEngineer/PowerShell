<#
.SYNOPSIS
Read one AD user's password and replicated logon metadata.
.DESCRIPTION
LastLogonDate is replicated and approximate; it is not an exact latest logon across DCs.
.EXAMPLE
.\Get-ADUserLoginData.ps1 -Server dc.example.com -Identity alice
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Server, [Parameter(Mandatory)][string]$Identity)
$ErrorActionPreference = 'Stop'
Get-ADUser -Identity $Identity -Server $Server -Properties PasswordLastSet, LastLogonDate, PasswordNeverExpires -ErrorAction Stop |
    Select-Object Name, SamAccountName, Enabled, PasswordLastSet, LastLogonDate, PasswordNeverExpires
