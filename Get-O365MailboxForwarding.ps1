<#
.SYNOPSIS
Report mailbox forwarding and hidden/visible inbox forwarding rules.
.DESCRIPTION
Connect exactly one Exchange Online session first. Requires ExchangeOnlineManagement
and RBAC permitting Get-Mailbox, Get-InboxRule, Get-Recipient and Get-AcceptedDomain.
Get-InboxRule is not supported for View-Only Organization Management/Global Reader.
All configured destinations are returned by default, including disabled rules.
-ExternalOnly retains external and unresolved targets for review. Mail contacts are
resolved to ExternalEmailAddress; groups are labelled Unknown, not expanded. Does
not follow forwarding chains or determine whether outbound policies allow delivery.
Resolution/permission/service failures are not silently treated as safe destinations.
.EXAMPLE
.\Get-O365MailboxForwarding.ps1 -ExternalOnly -OutputPath .\forwarding.csv
.EXAMPLE
.\Get-O365MailboxForwarding.ps1 -MailboxIdentity alice@example.com
#>
[CmdletBinding()]
param([string[]]$MailboxIdentity, [switch]$ExternalOnly, [string]$OutputPath, [switch]$Force)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Private/Common.ps1"
if (@(Get-ConnectionInformation -ErrorAction Stop | Where-Object { $_.State -eq 'Connected' }).Count -ne 1) {
    throw 'Connect exactly one Exchange Online session before running.'
}
$acceptedDomains = @(Get-AcceptedDomain -ErrorAction Stop)
if (-not $acceptedDomains.Count) { throw 'No accepted domains returned; cannot classify forwarding destinations.' }
function Get-ForwardingScope {
    param([string]$Address)
    if (-not $Address) { return 'Unknown' }
    $domain = ($Address -split '@')[-1]
    foreach ($accepted in $acceptedDomains) {
        $name = [string]$accepted.DomainName
        if ($name.StartsWith('*.') -and $domain.EndsWith($name.Substring(1), [StringComparison]::OrdinalIgnoreCase)) { return 'InternalDomain' }
        if ($domain -eq $name -or ($accepted.MatchSubDomains -and $domain.EndsWith('.' + $name, [StringComparison]::OrdinalIgnoreCase))) { return 'InternalDomain' }
    }
    'External'
}
function ConvertTo-ForwardingSmtpAddress {
    param([object]$Value)
    $text = ([string]$Value).Trim()
    if (-not $text) { return $null }
    if ($text -match '(?i)\[SMTP:([^\]]+)\]') { $text = $Matches[1] }
    $text = $text -replace '(?i)^smtp:', ''
    try {
        $address = [System.Net.Mail.MailAddress]::new($text).Address
        if ($address -notmatch '@') { return $null }
        $address
    } catch [FormatException] { return $null }
}
$cache = @{}
function Resolve-ForwardingDestination {
    param([object]$Destination)
    $raw = [string]$Destination
    if ($cache.ContainsKey($raw)) { return $cache[$raw] }
    $smtp = $null
    foreach ($value in @($Destination.ExternalEmailAddress, $Destination.PrimarySmtpAddress, $Destination.Address, $Destination.SmtpAddress, $raw)) {
        $smtp = ConvertTo-ForwardingSmtpAddress $value
        if ($smtp) { break }
    }
    $scope = Get-ForwardingScope $smtp
    $resolution = 'SmtpAddress'
    if ($scope -ne 'External') {
        $identity = if ($smtp) { $smtp } elseif ($Destination.DistinguishedName) { [string]$Destination.DistinguishedName } else { $raw }
        try {
            $recipient = Get-Recipient -Identity $identity -ErrorAction Stop
            if ($recipient.ExternalEmailAddress) {
                $smtp = ConvertTo-ForwardingSmtpAddress $recipient.ExternalEmailAddress
                $scope = Get-ForwardingScope $smtp
                $resolution = 'ExternalRecipientAddress'
            } elseif ([string]$recipient.RecipientType -match 'Group') {
                $smtp = ConvertTo-ForwardingSmtpAddress $recipient.PrimarySmtpAddress
                $scope = 'Unknown'
                $resolution = 'GroupNotExpanded'
            } else {
                $smtp = ConvertTo-ForwardingSmtpAddress $recipient.PrimarySmtpAddress
                $scope = Get-ForwardingScope $smtp
                $resolution = 'RecipientResolved'
            }
        } catch {
            if ($_.FullyQualifiedErrorId -notmatch 'ManagementObjectNotFound|ManagementObjectAmbiguous') { throw }
            $scope = 'Unknown'
            $resolution = 'UnresolvedRecipient'
            Write-Warning "Unable to resolve forwarding recipient: $raw"
        }
    }
    $result = [pscustomobject]@{ RawTarget = $raw; TargetAddress = $smtp; Scope = $scope; Resolution = $resolution }
    $cache[$raw] = $result
    $result
}
$mailboxes = if ($MailboxIdentity) {
    @($MailboxIdentity | Sort-Object -Unique | ForEach-Object { Get-Mailbox -Identity $_ -ErrorAction Stop })
} else {
    @(Get-Mailbox -RecipientTypeDetails UserMailbox,SharedMailbox -ResultSize Unlimited -ErrorAction Stop)
}
$rows = @(foreach ($mailbox in $mailboxes) {
    $identity = [string]$mailbox.PrimarySmtpAddress
    if (-not $identity) { throw 'A mailbox has no primary SMTP address; cannot query its inbox rules.' }
    $settings = [Collections.Generic.List[object]]::new()
    foreach ($field in 'ForwardingAddress','ForwardingSmtpAddress') {
        if ($mailbox.$field) { $settings.Add(@{ Type = 'Mailbox'; Name = $null; Id = $null; Enabled = $null; Action = $field; Target = $mailbox.$field }) }
    }
    foreach ($rule in @(Get-InboxRule -Mailbox $identity -IncludeHidden -ResultSize Unlimited -ErrorAction Stop)) {
        foreach ($action in 'ForwardTo','RedirectTo','ForwardAsAttachmentTo') {
            foreach ($target in @($rule.$action)) {
                if ($null -ne $target) { $settings.Add(@{ Type = 'InboxRule'; Name = $rule.Name; Id = $rule.Identity; Enabled = $rule.Enabled; Action = $action; Target = $target }) }
            }
        }
    }
    foreach ($setting in $settings) {
        $destination = Resolve-ForwardingDestination $setting.Target
        if ($ExternalOnly -and $destination.Scope -eq 'InternalDomain') { continue }
        [pscustomobject]@{
            Mailbox = $identity
            SourceType = $setting.Type
            RuleName = $setting.Name
            RuleIdentity = [string]$setting.Id
            RuleEnabled = $setting.Enabled
            Action = $setting.Action
            RawTarget = $destination.RawTarget
            TargetAddress = $destination.TargetAddress
            TargetScope = $destination.Scope
            Resolution = $destination.Resolution
            DeliverToMailboxAndForward = $mailbox.DeliverToMailboxAndForward
        }
    }
})
if ($OutputPath) { Export-ToolkitReport -InputObject $rows -Path $OutputPath -Force:$Force }
$rows
