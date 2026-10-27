<#
.SYNOPSIS
Export enabled/disabled status for a text list of AD identities; never enables accounts.
.EXAMPLE
.\Get-ADUserEnabledStatus.ps1 -Server dc.example.com -UserListPath .\users.txt -OutputPath .\status.csv
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Server,
    [Parameter(Mandatory)][string]$UserListPath,
    [string]$OutputPath,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Private/Common.ps1"
$rows = @(foreach ($identity in (Read-ToolkitIdentityList -Path $UserListPath)) {
    try {
        $user = Get-ADUser -Identity $identity -Server $Server -Properties Enabled -ErrorAction Stop
        [pscustomobject]@{ Identity = $identity; Name = $user.Name; Enabled = $user.Enabled; Status = 'Found'; Error = $null }
    } catch {
        # Only AD's identity-not-found exception is a missing user. Connection and access errors stop the report.
        if ($_.Exception.GetType().FullName -ne 'Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException') { throw }
        [pscustomobject]@{ Identity = $identity; Name = $null; Enabled = $null; Status = 'NotFound'; Error = $_.Exception.Message }
    }
})
if ($OutputPath) { Export-ToolkitReport -InputObject $rows -Path $OutputPath -Force:$Force }
$rows
