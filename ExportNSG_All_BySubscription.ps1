##############################################################################################
## This script was created in response to a need to export all NSG details for Audit        ##
##                                                                                          ##
##                                                                                          ##  
## Created by John Skinner                                                                  ##
##############################################################################################

<#
.Synopsis
   Export NSG's to CSV Files for Audit Review

.DESCRIPTION
   This script will login to Azure and pull the NSGs from all Subscriptions, exporting them to CSV's

.INPUTS
   Inputs from this script are as follows

   .NSG details from Azure

.OUTPUTS
   Outputs from this script are as follows
   
   .Individual CSV files for each NSG
   .This CSV is formatted to show all the inbound and outbound rules

.NOTES
   This script could also be used to backup NSG's to CSV, if new Subscriptions are added, 
   the #sub_names variable will need to be modified belo 

.ROLE
   The role this cmdlet belongs to Secops

.REVISION
    June 25, 2020 - Initial Script creation and testing
    
#>

Import-Module AZ

#Connect-AzureRmAccount <---- OLD Command
connect-azaccount
$exportPath = 'UNC Path to a server location (e.g. \\server\folder)'

#get all subscriptions
$sub_names = "subscriptionname1","subscriptionname2","subscriptionname3","subscriptionname4"
$subs = get-azsubscription | where {$sub_Names -contains $_.name}

#new array to hold results
$nsgs = new-object system.collections.arraylist

#cycle through each Subscription
foreach ($subscription in $subs){
    write-host "Working on the"$subscription.name "Subscription.." -ForegroundColor cyan
    Select-AzSubscription $subscription

    #$nsgs = Get-AzureRmNetworkSecurityGroup <---- OLD Command (using new "Get-AzNetworkSecurityGroup")
    $Temp_nsgs = Get-AzNetworkSecurityGroup
    foreach ($nsg in $Temp_nsgs) {$nsgs.Add($nsg)|out-null}
    }

write-host "Found"$nsgs.count "NSG's..." -ForegroundColor cyan

Foreach ($nsg in $nsgs) {
   $nsgRules = $nsg.SecurityRules + $nsg.DefaultSecurityRules
   $nsgrules = $nsgRules |Sort-Object direction,Priority
   
  foreach ($nsgRule in $nsgRules) {
   [string]$source_address = $nsgrule.SourceAddressPrefix
   [string]$source_port = $nsgrule.SourcePortRange
   [string]$dest_address = $nsgrule.DestinationAddressPrefix
   [string]$destport = $nsgrule.DestinationPortRange
   $NSG_Obj = [PSCustomObject]@{
      "NSG Name" = $nsg.Name
      "NSG location" = $nsg.Location
      "NSG Resource Group" = $nsg.ResourceGroupName
      "Rule Name" = $nsgrule.Name
      "Rule Description" = $nsgrule.Description
      "Rule Priority" = $nsgrule.Priority
      "Rule Source Address" = $source_address
      "Rule Source Port Range" = $source_port
      "Rule Destination Address" = $dest_address
      "Rule Destination Port Range" = $destport
      "Rule Protocol" = $nsgrule.Protocol
      "Rule Access" = $nsgrule.Access
      "Rule Direction" = $nsgrule.Direction  
   }
   $NSG_Obj | Export-Csv "$exportPath\all_rules.csv" -NoTypeInformation -Encoding ASCII -Append
   } #end rule
} #end NSG