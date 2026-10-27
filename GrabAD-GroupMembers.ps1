<#
.SYNOPSIS
Compatibility entry point for the consolidated AD group-member report.
.EXAMPLE
.\GrabAD-GroupMembers.ps1 -Server dc.example.com -Group Finance -OutputPath .\members.csv
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Server, [Parameter(Mandatory)][string]$Group, [switch]$Recursive, [string]$OutputPath, [switch]$Force)
& "$PSScriptRoot/Export-ADGroupMembers.ps1" @PSBoundParameters
