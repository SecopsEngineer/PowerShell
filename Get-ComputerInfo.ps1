<#
.SYNOPSIS
    Get Computer info
.DESCRIPTION
    This tool returns a variety of information about an AD user and prompts for the user name

.EXAMPLE
    No examples at this time. 
    
.INPUTS
    $cred - This prompts the user for credentials
        Note - Be sure to use the credentials in the right domain
        for which the target system resides. (e.g. bbcgrp\username or bbc\username)
    $comp - This prompts the suer for the computer name or target that we are searching for
        Note - This will accept a computer name or an IP address
.OUTPUTS
    - OS version of the remote computer to the screen
    - Current Logged on user of the remote computer
    - All hotfix installs on the remote computer
    
.NOTES
    Created by John Skinner

    When prompted for your credentials, be sure to loggin to the domain where the target computer exists
    Or this script will not be able to find the target computer. 
    
.LINK
    
#>

# Get and store credentials and Prompte for Computer name or IP Address
# When prompted for your credentials, be sure to loggin to the domain where the target computer exists
$cred = Get-Credential
$comp = Read-Host -Prompt 'Enter the Computer Name or IP address'

    Write-host "Getting Basic Computer Info..." -ForegroundColor cyan

#Get OS version on remote system
Get-WmiObject Win32_OperatingSystem -ComputerName $comp -Credential $cred |
Select PSComputerName, Caption, OSArchitecture, Version, BuildNumber | FL

    Write-host "Getting Current Logged in User..." -ForegroundColor cyan

# Get Current logged on user
Get-WmiObject -ComputerName $comp -Credential $cred -Class Win32_ComputerSystem | Select-Object UserName

    Write-host "Getting all installed Hotfix's..." -ForegroundColor cyan

#Get hotfix installed on remote computer
Get-HotFix -ComputerName $comp -Credential $cred

    Write-host "Script Complete!" -ForegroundColor green
