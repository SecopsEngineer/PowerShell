<#
.SYNOPSIS
Copy approved direct AD group memberships, excluding protected groups by default.
.DESCRIPTION
Requires ActiveDirectory and delegated group-management rights. Does not copy the
primary group or nested memberships. Custom groups can confer privileges without
adminCount; review the preview and use -GroupIdentity as an allowlist.
.EXAMPLE
.\Copy_AD_UserGroups.ps1 -SourceUser alice -TargetUser bob -Server dc.example.com -WhatIf
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$SourceUser,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$TargetUser,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Server,
    [string[]]$GroupIdentity,
    [switch]$IncludePrivilegedGroups
)
$ErrorActionPreference = 'Stop'
$source = Get-ADUser -Identity $SourceUser -Server $Server -Properties memberOf -ErrorAction Stop
$target = Get-ADUser -Identity $TargetUser -Server $Server -Properties memberOf -ErrorAction Stop
if ($source.DistinguishedName -eq $target.DistinguishedName) { throw 'Source and target must differ.' }
$groups = @($source.memberOf | ForEach-Object { Get-ADGroup -Identity $_ -Server $Server -Properties adminCount, SID -ErrorAction Stop })
if ($GroupIdentity) {
    $allowed = @($GroupIdentity | ForEach-Object { (Get-ADGroup -Identity $_ -Server $Server -ErrorAction Stop).DistinguishedName })
    $groups = @($groups | Where-Object { $_.DistinguishedName -in $allowed })
}
foreach ($group in $groups) {
    $privileged = $group.adminCount -eq 1 -or [string]$group.SID -match '-(512|516|518|519|520|521|522|526|527|544|548|549|550|551|552)$'
    $status = 'Preview'
    if ($group.DistinguishedName -in $target.memberOf) { $status = 'AlreadyMember' }
    elseif ($privileged -and -not $IncludePrivilegedGroups) { $status = 'SkippedProtectedGroup' }
    elseif ($PSCmdlet.ShouldProcess("$TargetUser on $Server", "Add membership: $($group.Name)")) {
        Add-ADGroupMember -Identity $group.DistinguishedName -Members $target.DistinguishedName -Server $Server -Confirm:$false -ErrorAction Stop
        $verified = Get-ADUser -Identity $target.DistinguishedName -Server $Server -Properties memberOf -ErrorAction Stop
        if ($group.DistinguishedName -notin $verified.memberOf) { throw "Membership verification failed: $($group.Name)" }
        $status = 'Added'
    }
    [pscustomobject]@{ SourceUser = $SourceUser; TargetUser = $TargetUser; Group = $group.Name; Status = $status }
}
