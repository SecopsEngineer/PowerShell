<#
.SYNOPSIS
Report direct and nested membership paths in selected privileged AD groups.
.DESCRIPTION
Requires ActiveDirectory and directory-read access. Defaults to groups marked
adminCount=1 in the selected domain; this is a review set, not a complete privilege
model. Specify -GroupIdentity for custom groups. Does not include primary-group
membership, ACL delegation, unresolvable foreign principals, or other domains'
groups automatically. Group cycles and depth limits are emitted explicitly.
.EXAMPLE
.\Get-ADPrivilegedGroupMembers.ps1 -Server dc.example.com -OutputPath .\privileged.csv
.EXAMPLE
.\Get-ADPrivilegedGroupMembers.ps1 -Server dc.example.com -GroupIdentity 'Domain Admins','Helpdesk Tier 1'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Server,
    [string[]]$GroupIdentity,
    [ValidateRange(1,100)][int]$MaxDepth = 32,
    [string]$OutputPath,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Private/Common.ps1"
$roots = if ($GroupIdentity) {
    @($GroupIdentity | Sort-Object -Unique | ForEach-Object { Get-ADGroup -Identity $_ -Server $Server -ErrorAction Stop })
} else {
    @(Get-ADGroup -Filter 'adminCount -eq 1' -Server $Server -ErrorAction Stop)
}
$cache = @{}
$rows = @(foreach ($rootGroup in $roots) {
    $stack = [Collections.Generic.Stack[object]]::new()
    $stack.Push(@{ Group = $rootGroup; Names = @($rootGroup.Name); DNs = @($rootGroup.DistinguishedName); Depth = 0 })
    while ($stack.Count) {
        $current = $stack.Pop()
        $dn = $current.Group.DistinguishedName
        if (-not $cache.ContainsKey($dn)) {
            $cache[$dn] = @(Get-ADGroupMember -Identity $dn -Server $Server -ErrorAction Stop)
        }
        foreach ($member in $cache[$dn]) {
            $depth = $current.Depth + 1
            $status = 'Member'
            if ($member.ObjectClass -eq 'group') {
                if ($member.DistinguishedName -in $current.DNs) { $status = 'Cycle' }
                elseif ($depth -ge $MaxDepth) { $status = 'DepthLimit' }
                else { $status = 'NestedGroup' }
            } elseif ($member.ObjectClass -eq 'foreignSecurityPrincipal') { $status = 'ForeignPrincipalNotExpanded' }
            [pscustomobject]@{
                Server = $Server
                RootGroup = $rootGroup.Name
                RootGroupDN = $rootGroup.DistinguishedName
                MemberName = $member.Name
                SamAccountName = $member.SamAccountName
                ObjectClass = $member.ObjectClass
                MemberDN = $member.DistinguishedName
                SID = [string]$member.SID
                Depth = $depth
                MembershipPath = (@($current.Names) + @($member.Name)) -join ' -> '
                DistinguishedNamePath = (@($current.DNs) + @($member.DistinguishedName)) -join ' -> '
                Status = $status
            }
            if ($status -eq 'NestedGroup') {
                $stack.Push(@{ Group = $member; Names = @($current.Names) + @($member.Name); DNs = @($current.DNs) + @($member.DistinguishedName); Depth = $depth })
            }
        }
    }
})
if ($OutputPath) { Export-ToolkitReport -InputObject $rows -Path $OutputPath -Force:$Force }
$rows
