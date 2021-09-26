<#
.SYNOPSIS
 Get Windows events for a particular computer

.DESCRIPTION
I needed a quick way to pull the event logs from a remote computer, for a selected date range
This oneliner script is that solution... I have tested the script and seems to work as expected
but the script is in its infancy and could possibly be tweaked if we need to. 
    
.INPUTS
Prompts for the computer name or IP address - self explanatory, what computer are you interested in

The "-Credential" value will need to be modified to your admin account
Important to note that you will need to use your admin account on the right domain for the host that 
you are investigating. (bbc or bbcgrp)

Takes inputs for the start and end date [StartTime="date";"EndTime="date"]
Will need to change the dates as necessary depended on the range you are interested in
Keep in mind this is a lot of events... try to limit to one day
This allow us to pull the logs for between a specific date

The -FilterHashtable command allows us to select the logname (eg. Application, System, Security...)
This will need to be modified as needed depending on what you are looking for

.EXAMPLE
-Pull system events for Investments PC for a specific time and date ranged. Then export to CSV

Get-WinEvent -ComputerName $Computer -Credential bbcgp\x-jwskinner -FilterHashtable @{logname='System';StartTime="09/12/21";EndTime="09/13/21"} | Out-GridView
    
.OUTPUTS
This script outputs to the Grid on the screen which allows you to easily view the results and sort those results
You could change this if needed to Export to a CSV 
    
.NOTES
Script created by John Skinner. 
    
#>

#Prompt for the computer name
$Computer = Read-Host "Enter the Computer Name or IP Address"

#Run the magic and grab the logs
Get-WinEvent -ComputerName $Computer -Credential bbcgrp\x-jwskinner -FilterHashtable @{logname='Application';StartTime="09/12/21 6:00";EndTime="09/12/21 10:00"} | Export-Csv c:\temp\10.12.170.51_Application.csv