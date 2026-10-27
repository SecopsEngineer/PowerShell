<#
.SYNOPSIS
Apply an Exchange Online authentication policy or explicitly restore saved assignments.
.DESCRIPTION
Connect-ExchangeOnline first with Exchange RBAC policy/user management rights.
Apply saves previous assignments BEFORE changes. Restore is a separate invocation.
A null assignment inherits the tenant default. Changes may take time to propagate.
Authentication policies do not replace Conditional Access.
.EXAMPLE
.\BlockLegacyAuthentication.ps1 -Mode Apply -UserListPath .\users.txt -BackupPath .\before.csv -WhatIf
.EXAMPLE
.\BlockLegacyAuthentication.ps1 -Mode Restore -RestoreSavedAssignments -BackupPath .\before.csv
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'Apply')]
param(
    [Parameter(Mandatory)][ValidateSet('Apply', 'Restore')][string]$Mode,
    [Parameter(Mandatory, ParameterSetName = 'Apply')][string]$UserListPath,
    [Parameter(Mandatory)][string]$BackupPath,
    [Parameter(ParameterSetName = 'Apply')][ValidateNotNullOrEmpty()][string]$PolicyName = 'BlockBasicAuth',
    [Parameter(Mandatory, ParameterSetName = 'Restore')][switch]$RestoreSavedAssignments
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Private/Common.ps1"
if ($Mode -eq 'Restore' -and -not $RestoreSavedAssignments) { throw 'Explicitly select -RestoreSavedAssignments.' }
if ($Mode -ne $PSCmdlet.ParameterSetName) { throw 'Apply requires -UserListPath; Restore requires -RestoreSavedAssignments.' }
$connection = @(Get-ConnectionInformation -ErrorAction Stop | Where-Object { $_.State -eq 'Connected' })
if ($connection.Count -ne 1) { throw 'Connect exactly one Exchange Online session before running.' }
$organizationId = [string](Get-OrganizationConfig -ErrorAction Stop).Guid
if (-not $organizationId) { throw 'Unable to identify the Exchange organization.' }
if ($Mode -eq 'Apply') {
    $users = @(Read-ToolkitIdentityList -Path $UserListPath | ForEach-Object { Get-User -Identity $_ -ErrorAction Stop })
    $backup = @($users | ForEach-Object {
        [pscustomobject]@{ OrganizationId = $organizationId; Identity = [string]$_.UserPrincipalName; AuthenticationPolicy = [string]$_.AuthenticationPolicy }
    })
    if (@($backup | Where-Object { -not $_.Identity }).Count) { throw 'A user has no UPN; no changes made.' }
    $policy = @(Get-AuthenticationPolicy -ErrorAction Stop | Where-Object { $_.Name -eq $PolicyName })
    if ($policy.Count -gt 1) { throw 'Ambiguous authentication policy.' }
    if ($policy.Count -eq 1) {
        $flags = @($policy[0].PSObject.Properties | Where-Object { $_.Name -like 'AllowBasicAuth*' })
        if (-not $flags.Count -or @($flags | Where-Object { $_.Value -eq $true }).Count) { throw 'Existing policy does not verifiably block all Basic authentication protocols.' }
    }
    if ($PSCmdlet.ShouldProcess("$($users.Count) users in $organizationId", "Save $BackupPath and apply $PolicyName")) {
        Export-ToolkitReport -InputObject $backup -Path $BackupPath
        if (-not $policy.Count) {
            # No AllowBasicAuth switches: Exchange Online blocks all protocols.
            $null = New-AuthenticationPolicy -Name $PolicyName -Confirm:$false -ErrorAction Stop
        }
        foreach ($user in $users) {
            Set-User -Identity $user.UserPrincipalName -AuthenticationPolicy $PolicyName -Confirm:$false -ErrorAction Stop
            $actual = Get-User -Identity $user.UserPrincipalName -ErrorAction Stop
            if (-not $actual.AuthenticationPolicy -or (Get-AuthenticationPolicy -Identity $actual.AuthenticationPolicy -ErrorAction Stop).Name -ne $PolicyName) { throw "Policy verification failed: $($user.UserPrincipalName). Backup: $BackupPath" }
            [pscustomobject]@{ Identity = $user.UserPrincipalName; Status = 'Applied'; Policy = $PolicyName }
        }
    }
} else {
    $rows = @(Import-Csv -LiteralPath $BackupPath)
    if (-not $rows.Count) { throw 'Backup is empty.' }
    foreach ($row in $rows) {
        if (-not $row.Identity -or $row.OrganizationId -ne $organizationId -or 'AuthenticationPolicy' -notin $row.PSObject.Properties.Name) { throw 'Invalid backup or wrong organization.' }
        $null = Get-User -Identity $row.Identity -ErrorAction Stop
        if ($row.AuthenticationPolicy) { $null = Get-AuthenticationPolicy -Identity $row.AuthenticationPolicy -ErrorAction Stop }
    }
    foreach ($row in $rows) {
        if ($PSCmdlet.ShouldProcess($row.Identity, 'Restore saved authentication policy')) {
            $previous = if ($row.AuthenticationPolicy) { $row.AuthenticationPolicy } else { $null }
            Set-User -Identity $row.Identity -AuthenticationPolicy $previous -Confirm:$false -ErrorAction Stop
            $actual = Get-User -Identity $row.Identity -ErrorAction Stop
            if ([string]$actual.AuthenticationPolicy -ne [string]$previous) { throw "Restore verification failed: $($row.Identity)" }
            [pscustomobject]@{ Identity = $row.Identity; Status = 'Restored'; Policy = $previous }
        }
    }
}
