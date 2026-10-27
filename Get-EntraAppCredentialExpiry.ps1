<#
.SYNOPSIS
Report expiring application secrets and certificates without emitting secret values.
.DESCRIPTION
Connect-MgGraph to the requested tenant first. Requires Microsoft.Graph.Applications,
Application.Read.All and a supported directory role for delegated access. Reads
application registrations, not service-principal credentials. Explicit output
projection excludes SecretText, Hint, certificate bytes and other credential data.
Default output includes expired, expiring, missing-expiry and not-yet-valid metadata.
Use -IncludeAll for credentials outside the threshold too.
.EXAMPLE
.\Get-EntraAppCredentialExpiry.ps1 -TenantId TENANT-GUID -WithinDays 30 -OutputPath .\expiry.csv
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$TenantId,
    [ValidateRange(0,36500)][int]$WithinDays = 30,
    [datetimeoffset]$AsOf = [datetimeoffset]::UtcNow,
    [switch]$IncludeAll,
    [string]$OutputPath,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Private/Common.ps1"
Assert-ToolkitGraphContext -TenantId $TenantId
$applications = @(Get-MgApplication -All -Property id,appId,displayName,passwordCredentials,keyCredentials -ErrorAction Stop)
$rows = @(foreach ($application in $applications) {
    foreach ($kind in 'Secret','Certificate') {
        $credentials = if ($kind -eq 'Secret') { @($application.PasswordCredentials) } else { @($application.KeyCredentials) }
        foreach ($metadata in $credentials) {
            if ($null -eq $metadata) { continue }
            $start = if ($metadata.StartDateTime) { [datetimeoffset]$metadata.StartDateTime } else { $null }
            $end = if ($metadata.EndDateTime) { [datetimeoffset]$metadata.EndDateTime } else { $null }
            $status = if ($null -eq $end) { 'MissingExpiry' }
                elseif ($end -le $AsOf) { 'Expired' }
                elseif ($null -ne $start -and $start -gt $AsOf) { 'NotYetValid' }
                elseif ($end -le $AsOf.AddDays($WithinDays)) { 'Expiring' }
                else { 'Valid' }
            if ($status -eq 'Valid' -and -not $IncludeAll) { continue }
            [pscustomobject]@{
                TenantId = $TenantId
                ApplicationObjectId = $application.Id
                AppId = $application.AppId
                ApplicationName = $application.DisplayName
                CredentialType = $kind
                CredentialId = $metadata.KeyId
                CredentialName = $metadata.DisplayName
                StartUtc = if ($null -ne $start) { $start.UtcDateTime.ToString('o') } else { $null }
                EndUtc = if ($null -ne $end) { $end.UtcDateTime.ToString('o') } else { $null }
                DaysRemaining = if ($null -ne $end) { [math]::Floor(($end - $AsOf).TotalDays) } else { $null }
                Status = $status
            }
        }
    }
})
if ($OutputPath) { Export-ToolkitReport -InputObject $rows -Path $OutputPath -Force:$Force }
$rows
