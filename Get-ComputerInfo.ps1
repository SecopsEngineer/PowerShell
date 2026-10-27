<#
.SYNOPSIS
Read OS, logged-on user and installed hotfix inventory through a CIM session.
.DESCRIPTION
Requires remote CIM/WinRM access. Credentials are optional; the current identity is
used otherwise. The session is always removed. Output remains structured.
.EXAMPLE
.\Get-ComputerInfo.ps1 -ComputerName server01 -Credential (Get-Credential)
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ComputerName, [pscredential]$Credential)
$ErrorActionPreference = 'Stop'
$query = @{ ComputerName = $ComputerName }
if ($Credential) { $query.Credential = $Credential }
$session = New-CimSession @query -ErrorAction Stop
try {
    $os = Get-CimInstance -CimSession $session -ClassName Win32_OperatingSystem -ErrorAction Stop
    $computer = Get-CimInstance -CimSession $session -ClassName Win32_ComputerSystem -ErrorAction Stop
    [pscustomobject]@{
        ComputerName = $ComputerName
        Caption = $os.Caption
        OSArchitecture = $os.OSArchitecture
        Version = $os.Version
        BuildNumber = $os.BuildNumber
        LoggedOnUser = $computer.UserName
        HotFixes = @(Get-CimInstance -CimSession $session -ClassName Win32_QuickFixEngineering -ErrorAction Stop |
            Select-Object HotFixID, Description, InstalledOn)
    }
} finally { Remove-CimSession -CimSession $session -ErrorAction Stop }
