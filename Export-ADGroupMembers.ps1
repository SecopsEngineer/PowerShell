<#
.SYNOPSIS
Export direct or recursive AD group members, preserving user/group/computer type.
.EXAMPLE
.\Export-ADGroupMembers.ps1 -Server dc.example.com -Group Finance -Recursive -OutputPath .\members.csv
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Server, [Parameter(Mandatory)][string]$Group, [switch]$Recursive, [string]$OutputPath, [switch]$Force)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Private/Common.ps1"
$rows = @(Get-ADGroupMember -Identity $Group -Server $Server -Recursive:$Recursive -ErrorAction Stop |
    Select-Object Name, SamAccountName, ObjectClass, DistinguishedName, SID)
if ($OutputPath) { Export-ToolkitReport -InputObject $rows -Path $OutputPath -Force:$Force }
$rows
