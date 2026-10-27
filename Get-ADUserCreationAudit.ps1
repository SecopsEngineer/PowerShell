<#
.SYNOPSIS
Find retained DC event 4720 evidence for an AD user's creation, matching the target SID.
.DESCRIPTION
Requires ActiveDirectory, Security-log read access and User Account Management
success auditing. Supply every relevant DC or a collector: events do not replicate.
NoAvailableRecord means evidence was not found in the selected logs/time window.
.EXAMPLE
.\Get-ADUserCreationAudit.ps1 -Server dc.example.com -Identity alice -DomainController dc1.example.com,dc2.example.com
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Server,
    [Parameter(Mandatory)][string]$Identity,
    [Parameter(Mandatory)][string[]]$DomainController,
    [datetime]$StartTime,
    [datetime]$EndTime,
    [pscredential]$Credential
)
$ErrorActionPreference = 'Stop'
$adQuery = @{ Identity = $Identity; Server = $Server; Properties = 'whenCreated' }
if ($Credential) { $adQuery.Credential = $Credential }
$user = Get-ADUser @adQuery -ErrorAction Stop
if (-not $PSBoundParameters.ContainsKey('StartTime')) { $StartTime = ([datetime]$user.whenCreated).AddDays(-1) }
if (-not $PSBoundParameters.ContainsKey('EndTime')) { $EndTime = ([datetime]$user.whenCreated).AddDays(1) }
if ($StartTime -ge $EndTime) { throw 'StartTime must precede EndTime.' }
$rows = @(foreach ($dc in $DomainController) {
    $query = @{ ComputerName = $dc; FilterHashtable = @{ LogName = 'Security'; Id = 4720; StartTime = $StartTime; EndTime = $EndTime } }
    if ($Credential) { $query.Credential = $Credential }
    try { $auditEvents = @(Get-WinEvent @query -ErrorAction Stop) } catch {
        if ($_.FullyQualifiedErrorId -notlike 'NoMatchingEventsFound*') { throw }
        $auditEvents = @()
    }
    foreach ($auditEvent in $auditEvents) {
        $xml = [xml]$auditEvent.ToXml()
        $data = @{}
        foreach ($item in $xml.Event.EventData.Data) { $data[$item.Name] = $item.'#text' }
        if ($data.TargetSid -eq [string]$user.SID) {
            [pscustomobject]@{ User = $user.SamAccountName; Created = $user.whenCreated; Creator = "$($data.SubjectDomainName)\$($data.SubjectUserName)"; DomainController = $dc; EventTime = $auditEvent.TimeCreated; RecordId = $auditEvent.RecordId; Evidence = 'Event4720' }
        }
    }
})
if ($rows.Count) { $rows } else {
    [pscustomobject]@{ User = $user.SamAccountName; Created = $user.whenCreated; Creator = $null; DomainController = $DomainController -join ';'; EventTime = $null; RecordId = $null; Evidence = 'NoAvailableRecord' }
}
