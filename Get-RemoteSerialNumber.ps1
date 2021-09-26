<#
.SYNOPSIS
This script solves a need to retrieve serial numbers for inventory tracking
    
.DESCRIPTION
The utilizes  the "Get-CIMInstance" module to reach into the bios of a remote computer 
and return the following bits of information

-SMBIOSBIOSVersion
-Manufacturer
-Name
-SerialNumber
-Version
-PSComputerName
    
.EXAMPLE
The below example shows the expected response, if you do not get this response,
then most likely the computer is offline. 

C:\scripts\Get-RemoteSerialNumber.ps1
Enter the computer name you want to search: ATLLMorrow

SMBIOSBIOSVersion : T76 Ver. 01.04.01
Manufacturer      : HP
Name              : T76 Ver. 01.04.01
SerialNumber      : 5CG1131XLR
Version           : HPQOEM - 0
PSComputerName    : ATLLMorrow

Script Complete!

.INPUTS
Prompts the Admin to type the computer name

This script declares a variable "$compname" and uses the "Read-Host:
command to take the name of the computer from the admin that is running
the search. 
    
.OUTPUTS
This script outputs the following information to the screen

-SMBIOSBIOSVersion
-Manufacturer
-Name
-SerialNumber
-Version
-PSComputerName

.NOTES
Created by John Skinner, please let me know if you have questions
about this script

***This script will require admin credentials, so launch the PowerShell ISE as another user
Type in your admin creds, and then browse to this script and run it.***
   
#>

#Declare the Compname variable - Accept input from the Admin
$compname = Read-Host "Enter the computer name you want to search" 

#Run the magic, grab the information from the remote computer - Output to the screen
get-ciminstance -classname win32_bios -computername $compname

#Tell the admin the script is finished
Write-Host "Script Complete!" -ForegroundColor Green