####################################################################
## General PowerShell commands for doing things in Azure Firewall ##
####################################################################

#Import AZ Module and Connect to Azure
Import-Module AZ

connect-azaccount

#Retrieve all firewalls in a resource group
Get-AzFirewall -ResourceGroupName rgName

#Retrieve a firewall by name
Get-AzFirewall -ResourceGroupName rgName -Name azFw

#Retrieve a firewall and then add a application rule collection to the firewall
$azFw=Get-AzFirewall -Name "azFw" -ResourceGroupName "rgName"
$appRule = New-AzFirewallApplicationRule -Name R1 -Protocol "http:80","https:443" -TargetFqdn "*google.com", "*microsoft.com" -SourceAddress "10.0.0.0"
$appRuleCollection = New-AzFirewallApplicationRuleCollection -Name "MyAppRuleCollection" -Priority 100 -Rule $appRule -ActionType "Allow"
$azFw.AddApplicationRuleCollection($appRuleCollection)

#Retrieve a firewall and then add a network rule collection to the firewall
$azFw=Get-AzFirewall -Name "azFw" -ResourceGroupName "rgName"
$netRule = New-AzFirewallNetworkRule -Name "all-udp-traffic" -Description "Rule for all UDP traffic" -Protocol "UDP" -SourceAddress "*" -DestinationAddress "*" -DestinationPort "*"
$netRuleCollection = New-AzFirewallNetworkRuleCollection -Name "MyNetworkRuleCollection" -Priority 100 -Rule $netRule -ActionType "Allow"
$azFw.AddNetworkRuleCollection($netRuleCollection)

#Add a new Network collection to the firewall, without a rule
$azFw=Get-AzFirewall -Name "azFw" -ResourceGroupName "rgName"
$netRuleCollection = New-AzFirewallNetworkRuleCollection -Name "MyNetworkRuleCollection" -Priority 100
$azFw.AddNetworkRuleCollection($netRuleCollection)

#Add a new Application collection to the firewall, without a rule
$azFw=Get-AzFirewall -Name "azFw" -ResourceGroupName "rgName"
$appRuleCollection = New-AzFirewallApplicationRuleCollection -Name "MyAppRuleCollection" -Priority 100
$azFw.AddApplicationRuleCollection($appRuleCollection)
