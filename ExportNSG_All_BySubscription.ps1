<#
.SYNOPSIS
Export NSG rules for explicitly selected subscriptions in one tenant.
.DESCRIPTION
Connect-AzAccount first. Requires Reader access. Includes default rules, plural
address/port fields, ASGs and subscription/resource identity. Temporarily switches the
active Azure context and restores it in finally. The CSV is an audit report, not a restorable NSG backup.
.EXAMPLE
.\ExportNSG_All_BySubscription.ps1 -TenantId TENANT-GUID -SubscriptionId SUB-GUID -OutputPath .\rules.csv
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$TenantId,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string[]]$SubscriptionId,
    [Parameter(Mandatory)][string]$OutputPath,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Private/Common.ps1"
$initialContext = Get-AzContext -ErrorAction Stop
if (-not $initialContext -or $initialContext.Tenant.Id -ne $TenantId) { throw 'Connect-AzAccount to the requested tenant first.' }
$subscriptions = @(Get-AzSubscription -TenantId $TenantId -ErrorAction Stop | Where-Object { $_.Id -in $SubscriptionId })
foreach ($id in $SubscriptionId) {
    if ($id -notin $subscriptions.Id) { throw "Subscription not accessible in tenant: $id" }
}
$rows = @(foreach ($subscription in $subscriptions) {
    # Select each subscription explicitly and restore the caller context even if collection fails.
    try {
        $context = Set-AzContext -SubscriptionId $subscription.Id -Tenant $TenantId -Scope Process -ErrorAction Stop
        foreach ($nsg in (Get-AzNetworkSecurityGroup -DefaultProfile $context -ErrorAction Stop)) {
            foreach ($rule in (@($nsg.SecurityRules) + @($nsg.DefaultSecurityRules) | Where-Object { $null -ne $_ } | Sort-Object Direction, Priority)) {
                [pscustomobject]@{
                    SubscriptionId = $subscription.Id
                    SubscriptionName = $subscription.Name
                    ResourceId = $nsg.Id
                    NSGName = $nsg.Name
                    ResourceGroup = $nsg.ResourceGroupName
                    Location = $nsg.Location
                    RuleName = $rule.Name
                    Description = $rule.Description
                    Priority = $rule.Priority
                    Direction = $rule.Direction
                    Access = $rule.Access
                    Protocol = $rule.Protocol
                    SourceAddresses = (@($rule.SourceAddressPrefix) + @($rule.SourceAddressPrefixes) | Where-Object { $_ }) -join ';'
                    SourcePorts = (@($rule.SourcePortRange) + @($rule.SourcePortRanges) | Where-Object { $_ }) -join ';'
                    DestinationAddresses = (@($rule.DestinationAddressPrefix) + @($rule.DestinationAddressPrefixes) | Where-Object { $_ }) -join ';'
                    DestinationPorts = (@($rule.DestinationPortRange) + @($rule.DestinationPortRanges) | Where-Object { $_ }) -join ';'
                    SourceApplicationSecurityGroups = @($rule.SourceApplicationSecurityGroups | ForEach-Object { $_.Id }) -join ';'
                    DestinationApplicationSecurityGroups = @($rule.DestinationApplicationSecurityGroups | ForEach-Object { $_.Id }) -join ';'
                    IsDefault = $rule.Name -in @($nsg.DefaultSecurityRules | ForEach-Object { $_.Name })
                }
            }
        }
    } finally {
        $null = Set-AzContext -Context $initialContext -Scope Process -ErrorAction Stop
    }
})
Export-ToolkitReport -InputObject $rows -Path $OutputPath -Force:$Force
$rows
