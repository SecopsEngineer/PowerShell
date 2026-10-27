<#
.SYNOPSIS
Inventory Azure public IPs and NSG rules potentially allowing management access.
.DESCRIPTION
Connect-AzAccount first. Requires Az.Accounts, Az.Network and Reader access in each
requested subscription. Includes assigned/unassigned public IPs and standalone NSG
candidate rules (including plural fields, Internet/IPv4/IPv6 any-source and ranges).
These are configured-rule findings, NOT proof of reachability. Does not evaluate
deny precedence, effective NIC/subnet policy, routes, firewalls, JIT, load-balancer
NAT, application gateways or guest listeners, and does not correlate IPs to rules.
The caller's Azure context is restored even on errors. No network probing occurs.
.EXAMPLE
.\Get-AzurePublicExposure.ps1 -TenantId TENANT-GUID -SubscriptionId SUB-GUID -OutputPath .\exposure.csv
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$TenantId,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string[]]$SubscriptionId,
    [ValidateRange(1,65535)][int[]]$ManagementPort = @(22,3389,5985,5986),
    [string]$OutputPath,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Private/Common.ps1"
function Test-ManagementPortRange {
    param([string[]]$Ranges, [int]$Port)
    foreach ($range in $Ranges) {
        if ($range -eq '*') { return $true }
        if ($range -match '^\d+$' -and [int]$range -eq $Port) { return $true }
        if ($range -match '^(\d+)-(\d+)$' -and $Port -ge [int]$Matches[1] -and $Port -le [int]$Matches[2]) { return $true }
    }
    $false
}
$original = Get-AzContext -ErrorAction Stop
if (-not $original -or $original.Tenant.Id -ne $TenantId) { throw 'Connect-AzAccount to the requested tenant first.' }
$subscriptions = @(Get-AzSubscription -TenantId $TenantId -ErrorAction Stop | Where-Object { $_.Id -in $SubscriptionId })
foreach ($id in $SubscriptionId) { if ($id -notin $subscriptions.Id) { throw "Subscription not accessible in requested tenant: $id" } }
$rows = @(foreach ($subscription in $subscriptions) {
    try {
        $context = Set-AzContext -Tenant $TenantId -SubscriptionId $subscription.Id -Scope Process -ErrorAction Stop
        foreach ($ip in @(Get-AzPublicIpAddress -DefaultProfile $context -ErrorAction Stop)) {
            [pscustomobject]@{
                FindingType = 'PublicIpInventory'; TenantId = $TenantId; SubscriptionId = $subscription.Id
                ResourceId = $ip.Id; ResourceName = $ip.Name; ResourceGroup = $ip.ResourceGroupName; Location = $ip.Location
                PublicIpAddress = $ip.IpAddress; AssociatedResourceIds = (@($ip.IpConfiguration.Id) + @($ip.NatGateway.Id) | Where-Object { $_ }) -join ';'
                RuleName = $null; Priority = $null; Protocol = $null; SourceAddresses = $null
                DestinationAddresses = $null; DestinationPorts = $null; MatchedManagementPorts = $null
                DestinationASGs = $null; Assessment = 'InventoryOnlyNotReachabilityProof'
            }
        }
        foreach ($nsg in @(Get-AzNetworkSecurityGroup -DefaultProfile $context -ErrorAction Stop)) {
            foreach ($rule in @($nsg.SecurityRules) + @($nsg.DefaultSecurityRules)) {
                if (-not $rule -or $rule.Direction -ne 'Inbound' -or $rule.Access -ne 'Allow' -or $rule.Protocol -notin 'Tcp','Udp','*') { continue }
                $sources = @(@($rule.SourceAddressPrefix) + @($rule.SourceAddressPrefixes) | Where-Object { $_ })
                if (-not @($sources | Where-Object { $_ -in '*','Internet','0.0.0.0/0','::/0' }).Count) { continue }
                $ports = @(@($rule.DestinationPortRange) + @($rule.DestinationPortRanges) | Where-Object { $_ })
                $matched = @($ManagementPort | Sort-Object -Unique | Where-Object { Test-ManagementPortRange -Ranges $ports -Port $_ })
                if (-not $matched.Count) { continue }
                [pscustomobject]@{
                    FindingType = 'PotentialManagementExposure'; TenantId = $TenantId; SubscriptionId = $subscription.Id
                    ResourceId = $nsg.Id; ResourceName = $nsg.Name; ResourceGroup = $nsg.ResourceGroupName; Location = $nsg.Location
                    PublicIpAddress = $null; AssociatedResourceIds = (@($nsg.NetworkInterfaces.Id) + @($nsg.Subnets.Id) | Where-Object { $_ }) -join ';'
                    RuleName = $rule.Name; Priority = $rule.Priority; Protocol = $rule.Protocol; SourceAddresses = $sources -join ';'
                    DestinationAddresses = (@($rule.DestinationAddressPrefix) + @($rule.DestinationAddressPrefixes) | Where-Object { $_ }) -join ';'
                    DestinationPorts = $ports -join ';'; MatchedManagementPorts = $matched -join ';'
                    DestinationASGs = @($rule.DestinationApplicationSecurityGroups | ForEach-Object { $_.Id }) -join ';'
                    Assessment = 'CandidateRuleNotEffectiveAccess'
                }
            }
        }
    } finally { $null = Set-AzContext -Context $original -Scope Process -ErrorAction Stop }
})
if ($OutputPath) { Export-ToolkitReport -InputObject $rows -Path $OutputPath -Force:$Force }
$rows
