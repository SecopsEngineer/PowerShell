####################################################
##                                                ##
## Block Legacy Authentication in Office365       ##
## Date: 09/26/21                                 ##
## Create by: John Skinner                        ##
##                                                ##
####################################################
<#
.SYNOPSIS
    Block Basic Authentication in Office265
.DESCRIPTION
    As of Feb 2021, Microsoft has put on hold disabling legacy authentication protocols. However this disablement is still coming and therefore
    we have need to design a solution to disable legacy protocols

    Note: This script will need to be run from Exchange Online Powershell, there for you must run the following command first to connect

    "Connect-ExchangeOnline"
    Then Authenticate with your credentials. 

    This script works by creating an authentications policy to block legacy auth. 
    - Block Basic Auth - Blocks all legacy authentication protocols

    Note - Exchange Active Sync is blocked at the Tenant level and is not included in this solution at this time

    The Script below uses the "New-AuthenticationPolicy" cmdlet to create the policy and name it accordingly
    Once the policy is created, the "Get-AuthticationPolicy" cmdlet can be used to verify the policy and the settings

    At this point a text file of the users will need to be created. This information is in the "Inputs" section of the comments here
    It is important that the text file is formatted exactly as noted in these comments. 

    Once the text file is verified for all users that this policy needs to be applied to, we can then run the rest of the script
    to apply the authentication policy to those users. 

    The script runs a simply loop against users in the text file to apply the policy

    Reverting:
    If we need to revert the script, or set the users back to the way they were configured before, We can run the last 2 lines of this script
    to rest the users to the old auth policy that was originally configured. 
    
.INPUTS
    Use a list of specific user accounts: This method requires a text file to identify the user accounts. 
    Values that don't contain spaces (for example, the Office 365 or Microsoft 365 work or school account) work best. 
    The text file must contain one user account on each line like this:

    akol@contoso.com
    tjohnston@contoso.com
    kakers@contoso.com   

    The users variable below should point to the location of this text file
.OUTPUTS
    There are no specific outputs for this script other than making the configuration changes to the users Auth Policy

.NOTES
    
.LINK
    https://docs.microsoft.com/en-us/exchange/clients-and-mobile-in-exchange-online/disable-basic-authentication-in-exchange-online
    https://docs.microsoft.com/en-us/azure/active-directory/conditional-access/block-legacy-authentication
    https://docs.microsoft.com/en-us/powershell/module/exchange/new-authenticationpolicy?view=exchange-ps
    https://docs.microsoft.com/en-us/powershell/module/exchange/remove-authenticationpolicy?view=exchange-ps
#>

# Create Auth Policy to block basic authentication (Make sure this has all protocols listed)
New-AuthenticationPolicy -Name "BlockBasicAuth" -BlockLegacyAuthAutodiscover -BlockLegacyAuthImap -BlockLegacyAuthMapi -BlockLegacyAuthOfflineAddressBook -BlockLegacyAuthOutlookService -BlockLegacyAuthPop -BlockLegacyAuthRpc -BlockLegacyAuthWebServices

# Get All authtications policies list
Get-AuthenticationPolicy | Format-Table Name -Auto

# Verify the new authentication policy created successfully
Get-ADAuthenticationPolicy -Identity "BlockBasicAuth"

# Set users auth policy to block basic auth
$users = Get-Content "C:\temp\users.txt"
$users | ForEach-Object {Set-User -Identity $_ -AuthenticationPolicy "BlockBasicAuth" -STSRefreshTokensValidFrom $([System.DateTime]::UtcNow)}

# Revert the changes
# Set users auth policy to to $null, effectively removing the policy from the users assignment
$users = Get-Content "C:\temp\users.txt"
$users | ForEach-Object {Set-User -Identity $_ -AuthenticationPolicy "$null" -STSRefreshTokensValidFrom $([System.DateTime]::UtcNow)}

