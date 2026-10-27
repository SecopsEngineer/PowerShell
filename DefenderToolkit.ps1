<#
.SYNOPSIS
Run a specific Microsoft Defender operation. Defaults to status only.
.DESCRIPTION
Windows with the Defender module. Mutating actions require elevation. Reducing
protection requires -AllowProtectionReduction and confirmation. Tamper protection
and central policy may reject settings; verify actual state. Passive-mode registry
editing is intentionally omitted: configure supported policy for the target OS.
.EXAMPLE
.\DefenderToolkit.ps1 -Action AddExclusion -Path C:\TrustedBuild -AllowProtectionReduction -WhatIf
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [ValidateSet('Status','Preferences','Detections','Update','QuickScan','FullScan','CustomScan','RemoveThreats','AddExclusion','RemoveExclusion','DisableRealtime','EnableRealtime')]
    [string]$Action = 'Status',
    [string]$Path,
    [switch]$AllowProtectionReduction
)
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'Microsoft Defender operations require Windows.' }
switch ($Action) {
    'Status' { Get-MpComputerStatus -ErrorAction Stop; return }
    'Preferences' { Get-MpPreference -ErrorAction Stop; return }
    'Detections' { Get-MpThreatDetection -ErrorAction Stop; return }
}
$principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Open an elevated PowerShell session.' }
if ($Action -in 'AddExclusion','DisableRealtime' -and -not $AllowProtectionReduction) { throw 'This action reduces protection. Supply -AllowProtectionReduction after reviewing the risk.' }
if ($Action -in 'CustomScan','AddExclusion') {
    if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Container)) { throw 'Supply an existing folder with -Path.' }
    $Path = (Resolve-Path -LiteralPath $Path).ProviderPath
    if ($Action -eq 'AddExclusion' -and $Path.TrimEnd('\') -eq [IO.Path]::GetPathRoot($Path).TrimEnd('\')) { throw 'Excluding a drive root is not supported.' }
}
if ($Action -eq 'RemoveExclusion' -and -not $Path) { throw 'Supply the exact exclusion path to remove.' }
if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "$Action $Path")) {
    switch ($Action) {
        'Update' { Update-MpSignature -ErrorAction Stop }
        'QuickScan' { Start-MpScan -ScanType QuickScan -ErrorAction Stop }
        'FullScan' { Start-MpScan -ScanType FullScan -ErrorAction Stop }
        'CustomScan' { Start-MpScan -ScanType CustomScan -ScanPath $Path -ErrorAction Stop }
        'RemoveThreats' { Remove-MpThreat -ErrorAction Stop }
        'AddExclusion' {
            Add-MpPreference -ExclusionPath $Path -ErrorAction Stop
            if ($Path -notin (Get-MpPreference -ErrorAction Stop).ExclusionPath) { throw 'Exclusion was not applied.' }
        }
        'RemoveExclusion' {
            Remove-MpPreference -ExclusionPath $Path -ErrorAction Stop
            if ($Path -in (Get-MpPreference -ErrorAction Stop).ExclusionPath) { throw 'Exclusion is still present.' }
        }
        'DisableRealtime' {
            Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction Stop
            if ((Get-MpComputerStatus -ErrorAction Stop).RealTimeProtectionEnabled) { throw 'Real-time protection remains enabled; check managed policy and tamper protection.' }
        }
        'EnableRealtime' {
            Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction Stop
            if (-not (Get-MpComputerStatus -ErrorAction Stop).RealTimeProtectionEnabled) { throw 'Real-time protection is not active; check managed policy and Defender mode.' }
        }
    }
    Get-MpComputerStatus -ErrorAction Stop
}
