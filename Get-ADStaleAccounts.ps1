<#
.SYNOPSIS
Report user and computer inactivity candidates without disabling or deleting them.
.DESCRIPTION
Requires ActiveDirectory and directory-read access. LastLogonDate is replicated
and approximate (commonly delayed up to 14 days); this is not exact last-logon
evidence. Accounts without that value use creation date and are labelled separately.
Unknown timestamps are included as insufficient evidence, never labelled stale.
Enabled accounts only by default. Review service accounts and other activity before
any remediation. PasswordLastSet is included as an additional review signal.
.EXAMPLE
.\Get-ADStaleAccounts.ps1 -Server dc.example.com -InactiveDays 90 -OutputPath .\stale.csv
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Server,
    [ValidateSet('All','User','Computer')][string]$AccountType = 'All',
    [ValidateRange(1,36500)][int]$InactiveDays = 90,
    [string]$SearchBase,
    [pscredential]$Credential,
    [switch]$IncludeDisabled,
    [datetimeoffset]$AsOf = [datetimeoffset]::UtcNow,
    [string]$OutputPath,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Private/Common.ps1"
if ($InactiveDays -lt 15) { Write-Warning 'Short thresholds can misclassify activity because LastLogonDate is replicated with delay.' }
$query = @{ Server = $Server; Filter = 'Enabled -eq $true'; Properties = 'LastLogonDate','whenCreated','PasswordLastSet','Enabled'; ErrorAction = 'Stop' }
if ($IncludeDisabled) { $query.Filter = '*' }
if ($SearchBase) { $query.SearchBase = $SearchBase }
if ($Credential) { $query.Credential = $Credential }
$cutoff = $AsOf.UtcDateTime.AddDays(-$InactiveDays)
$rows = @(foreach ($type in @('User','Computer')) {
    if ($AccountType -ne 'All' -and $AccountType -ne $type) { continue }
    $accounts = if ($type -eq 'User') { @(Get-ADUser @query) } else { @(Get-ADComputer @query) }
    foreach ($account in $accounts) {
        $reference = $null
        $reason = 'InsufficientTimestamps'
        if ($null -ne $account.LastLogonDate) {
            $reference = ([datetime]$account.LastLogonDate).ToUniversalTime()
            $reason = 'ApproximateLastLogon'
        } elseif ($null -ne $account.whenCreated) {
            $reference = ([datetime]$account.whenCreated).ToUniversalTime()
            $reason = 'NoReplicatedLogonCreationFallback'
        }
        if ($null -ne $reference -and $reference -gt $cutoff) { continue }
        [pscustomobject]@{
            Server = $Server
            AccountType = $type
            Name = $account.Name
            SamAccountName = $account.SamAccountName
            DistinguishedName = $account.DistinguishedName
            Enabled = $account.Enabled
            LastLogonDate = $account.LastLogonDate
            Created = $account.whenCreated
            PasswordLastSet = $account.PasswordLastSet
            DaysSinceReference = if ($null -ne $reference) { [math]::Floor(($AsOf.UtcDateTime - $reference).TotalDays) } else { $null }
            IsInactivityCandidate = if ($null -ne $reference) { $true } else { $null }
            Evidence = $reason
            CutoffUtc = $cutoff.ToString('o')
        }
    }
})
if ($OutputPath) { Export-ToolkitReport -InputObject $rows -Path $OutputPath -Force:$Force }
$rows
