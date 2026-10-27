<#
.SYNOPSIS
Report creation dates of user members of an AD group; other object types are excluded.
.EXAMPLE
.\Export-ADGroupMemberCreationDates.ps1 -Server dc.example.com -Group Finance -OutputPath .\created.csv
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Server, [Parameter(Mandatory)][string]$Group, [switch]$Recursive, [string]$OutputPath, [switch]$Force)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Private/Common.ps1"
$rows = @(Get-ADGroupMember -Identity $Group -Server $Server -Recursive:$Recursive -ErrorAction Stop |
    Where-Object { $_.ObjectClass -eq 'user' } | ForEach-Object {
        Get-ADUser -Identity $_.DistinguishedName -Server $Server -Properties whenCreated -ErrorAction Stop |
            Select-Object Name, SamAccountName, DistinguishedName, whenCreated
    })
if ($OutputPath) { Export-ToolkitReport -InputObject $rows -Path $OutputPath -Force:$Force }
$rows
