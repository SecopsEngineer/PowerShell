# Azure Firewall examples

The former `AzureFirewallCommands.ps1` was a sequence of examples rather than a
runnable script. It used placeholder resources, reused collection names and
priorities, and included an allow-all UDP rule. It has been replaced with this
reference so executing the script collection cannot accidentally apply examples.
The original remains available in Git history.

Use an authenticated Az session with Reader access to inspect a specific firewall:

```powershell
$context = Get-AzContext
if (-not $context) { throw 'Connect-AzAccount to the intended tenant first.' }
# Supply actual names. Check $context.Tenant and $context.Subscription first.
$firewall = Get-AzFirewall -ResourceGroupName 'YOUR-RESOURCE-GROUP' -Name 'YOUR-FIREWALL' -DefaultProfile $context -ErrorAction Stop
$firewall.ApplicationRuleCollections
$firewall.NetworkRuleCollections
```

Before writing a change, determine whether the firewall uses classic rule
collections or Azure Firewall Policy. Use the matching management commands.
Select exact source ranges, destinations, protocols and ports; avoid wildcard
allow rules. Export the current configuration, review priorities and existing
collection names, and preview the write with `-WhatIf`. Use the supported write
command only after reviewing the complete resulting configuration. An in-memory
`AddNetworkRuleCollection()` call alone does not persist an Azure firewall change.

See [Azure Firewall PowerShell documentation](https://learn.microsoft.com/en-us/azure/firewall/deploy-ps).
