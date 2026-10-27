<#
.SYNOPSIS
Report Exchange Online mailbox hold flags without changing hold configuration.
.DESCRIPTION
Connect-ExchangeOnline first with mailbox read RBAC. Unattended runs should use
certificate or managed-identity authentication supported by that module. This script
does not accept passwords, install modules, open UI, or disconnect caller sessions.
RetentionHoldEnabled pauses MRM processing; it is NOT an evidence-preservation hold.
This report does not resolve organization-wide retention/eDiscovery policy coverage.
The previous version was credited to O365Reports Team:
https://o365reports.com/2021/06/29/export-office-365-mailbox-holds-report-using-powershell/
This replacement retains provenance; see THIRD_PARTY.md.
.EXAMPLE
.\Export-O365MailboxHolds.ps1 -HoldType All -OutputPath .\holds.csv
#>
[CmdletBinding()]
param(
    [ValidateSet('All','Litigation','InPlace','RetentionPause')][string]$HoldType = 'All',
    [string]$OutputPath,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Private/Common.ps1"
if (-not @(Get-ConnectionInformation -ErrorAction Stop | Where-Object { $_.State -eq 'Connected' }).Count) { throw 'Connect-ExchangeOnline first.' }
$rows = @(foreach ($mailbox in (Get-Mailbox -IncludeInactiveMailbox -ResultSize Unlimited -ErrorAction Stop)) {
    $inPlace = @($mailbox.InPlaceHolds | Where-Object { $_ })
    $include = switch ($HoldType) {
        'Litigation' { $mailbox.LitigationHoldEnabled -eq $true }
        'InPlace' { $inPlace.Count -gt 0 }
        'RetentionPause' { $mailbox.RetentionHoldEnabled -eq $true }
        'All' { $mailbox.LitigationHoldEnabled -eq $true -or $inPlace.Count -gt 0 -or $mailbox.RetentionHoldEnabled -eq $true -or $mailbox.ComplianceTagHoldApplied -eq $true }
    }
    if ($include) {
        [pscustomobject]@{
            MailboxName = $mailbox.Name
            UPN = $mailbox.UserPrincipalName
            ExchangeGuid = $mailbox.ExchangeGuid
            RecipientTypeDetails = $mailbox.RecipientTypeDetails
            IsInactiveMailbox = $mailbox.IsInactiveMailbox
            LitigationHoldEnabled = $mailbox.LitigationHoldEnabled
            LitigationHoldOwner = $mailbox.LitigationHoldOwner
            LitigationHoldDate = $mailbox.LitigationHoldDate
            LitigationHoldDuration = [string]$mailbox.LitigationHoldDuration
            InPlaceHoldIdentifiers = $inPlace -join ';'
            InPlaceHoldIdentifierCount = $inPlace.Count
            RetentionProcessingPaused = $mailbox.RetentionHoldEnabled
            RetentionPauseStart = $mailbox.StartDateForRetentionHold
            RetentionPauseEnd = $mailbox.EndDateForRetentionHold
            RetentionPolicy = $mailbox.RetentionPolicy
            ComplianceTagHoldApplied = $mailbox.ComplianceTagHoldApplied
        }
    }
})
if ($OutputPath) { Export-ToolkitReport -InputObject $rows -Path $OutputPath -Force:$Force }
$rows
