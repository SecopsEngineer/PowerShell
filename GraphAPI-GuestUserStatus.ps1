<#
.SYNOPSIS
Report each guest's latest available interactive sign-in from Microsoft Graph v1.0.
.DESCRIPTION
Connect-MgGraph first with User.Read.All and AuditLog.Read.All. Sign-in API access
requires appropriate licensing and roles. NoAvailableRecord does NOT mean never
signed in: data is limited by retention. API failures terminate the report.
.EXAMPLE
.\GraphAPI-GuestUserStatus.ps1 -TenantId TENANT-GUID -OutputPath .\guests.csv
.NOTES
Historical report source: Tony Redmond, Office365itpros,
ReportLastAccountSignIn-Mg.PS1. Upstream copyright (c) 2023 Tony Redmond, MIT.
This replacement changes connection handling, properties, output and error behavior.
See THIRD_PARTY.md and LICENSES/Office365itpros-MIT.txt for source and notice.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$TenantId, [string]$OutputPath, [switch]$Force)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Private/Common.ps1"
Assert-ToolkitGraphContext -TenantId $TenantId
$properties = 'id','displayName','userPrincipalName','userType','createdDateTime','creationType','externalUserState'
$users = @(Get-MgUser -All -Filter "userType eq 'Guest'" -Property $properties -ErrorAction Stop)
$rows = @(foreach ($user in $users) {
    # The signIns endpoint returns descending createdDateTime order by default.
    $latest = @(Get-MgAuditLogSignIn -Filter "userId eq '$($user.Id)'" -Top 1 -ErrorAction Stop)
    $signIn = if ($latest.Count) { $latest[0] } else { $null }
    [pscustomobject]@{
        Name = $user.DisplayName
        UPN = $user.UserPrincipalName
        Id = $user.Id
        UserType = $user.UserType
        AccountCreated = $user.CreatedDateTime
        CreationType = $user.CreationType
        InvitationState = $user.ExternalUserState
        RecordStatus = if ($signIn) { 'Available' } else { 'NoAvailableRecord' }
        SignInDate = if ($signIn) { $signIn.CreatedDateTime } else { $null }
        DaysSince = if ($signIn) { [math]::Floor(([datetimeoffset]::UtcNow - [datetimeoffset]$signIn.CreatedDateTime).TotalDays) } else { $null }
        Location = if ($signIn) { $signIn.Location.City } else { $null }
        App = if ($signIn) { $signIn.AppDisplayName } else { $null }
        Client = if ($signIn) { $signIn.ClientAppUsed } else { $null }
        IPAddress = if ($signIn) { $signIn.IPAddress } else { $null }
        IsInteractive = if ($signIn) { $signIn.IsInteractive } else { $null }
        ConditionalAccessStatus = if ($signIn) { $signIn.ConditionalAccessStatus } else { $null }
        RiskState = if ($signIn) { $signIn.RiskState } else { $null }
        SignInErrorCode = if ($signIn) { $signIn.Status.ErrorCode } else { $null }
    }
})
if ($OutputPath) { Export-ToolkitReport -InputObject $rows -Path $OutputPath -Force:$Force }
$rows
