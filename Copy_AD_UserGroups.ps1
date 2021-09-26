<#
.SYNOPSIS
    Simple script to produce a listing of user's group memberships

.DESCRIPTION
    Script will create a simple listing of a user's group memberships.
    Output is in object format so you can use other Powershell cmdlet's
    with the output, such as Export-CSV, Out-File, ConvertTo-HTML, etc.
    
    Groups are presented using the friendly name, and are sorted
    alphabetically.

.PARAMETER User
    Name of the user you want to copy from ($copy)
    Name of the user you want to copy to ($paste)

.INPUTS
    Pipeline
    Get-ADUser
        
.OUTPUTS
    PSObject    User Name
                Group Name
.EXAMPLE
    .\Get-UserGroupMembership.ps1 -User username
    List all of the groups for "username"

.NOTES

#>

# import the Active Directory module in order to be able to use get-ADuser and Add-AdGroupMember cmdlet
import-Module ActiveDirectory

# enter login name of the first user
$copy = Read-host -Prompt 'Enter username to copy from: ' 

# enter login name of the second user
$paste  = Read-host -Prompt 'Enter username to copy to: ' 

Write-host "Adding User Group Memberships..." -ForegroundColor cyan

# copy-paste process. Get-ADuser membership     | then selecting membership                       | and add it to the second user
get-ADuser -identity $copy -properties memberof | select-object memberof -expandproperty memberof | Add-AdGroupMember -Members $paste

Write-host "Successfully copied AD Group Memberships from username $copy to username $paste" -ForegroundColor green