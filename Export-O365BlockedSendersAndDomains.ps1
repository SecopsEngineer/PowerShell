<#
.SYNOPSIS
Report blocked senders/domains from a selected Exchange Online anti-spam policy.
.DESCRIPTION
Connect-ExchangeOnline first with RBAC to read hosted content filter policies.
Produces a single CSV with Policy, Type and Value columns; does not change policy.
.EXAMPLE
.\Export-O365BlockedSendersAndDomains.ps1 -PolicyName Default -OutputPath .\blocked.csv
#>
[CmdletBinding()]
param([string]$PolicyName = 'Default', [string]$OutputPath, [switch]$Force)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Private/Common.ps1"
$policy = Get-HostedContentFilterPolicy -Identity $PolicyName -ErrorAction Stop
$rows = @(
    foreach ($domain in $policy.BlockedSenderDomains) { [pscustomobject]@{ Policy = $policy.Name; Type = 'Domain'; Value = [string]$domain } }
    foreach ($blockedSender in $policy.BlockedSenders) { [pscustomobject]@{ Policy = $policy.Name; Type = 'Sender'; Value = [string]$blockedSender } }
)
if ($OutputPath) { Export-ToolkitReport -InputObject $rows -Path $OutputPath -Force:$Force }
$rows
