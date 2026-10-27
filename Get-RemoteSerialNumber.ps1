<#
.SYNOPSIS
Retrieve remote BIOS serial and version information through CIM.
.EXAMPLE
.\Get-RemoteSerialNumber.ps1 -ComputerName server01
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ComputerName, [pscredential]$Credential)
$ErrorActionPreference = 'Stop'
$query = @{ ComputerName = $ComputerName }
if ($Credential) { $query.Credential = $Credential }
$session = New-CimSession @query -ErrorAction Stop
try {
    Get-CimInstance -CimSession $session -ClassName Win32_BIOS -ErrorAction Stop |
        Select-Object PSComputerName, SerialNumber, Manufacturer, SMBIOSBIOSVersion, Name, Version
} finally { Remove-CimSession -CimSession $session -ErrorAction Stop }
