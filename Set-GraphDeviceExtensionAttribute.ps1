<#
.SYNOPSIS
Update one selected device extension attribute in the connected Graph tenant.
.DESCRIPTION
Connect-MgGraph first. Delegated use requires Directory.AccessAsUser.All and a
supported role; application use requires Device.ReadWrite.All. See Graph's update
device documentation for OS and identity restrictions. DeviceObjectId is the
Graph directory object id, not the device registration id. Requires read access
for verification. No permissions are requested automatically.
.EXAMPLE
.\Set-GraphDeviceExtensionAttribute.ps1 -TenantId TENANT-GUID -DeviceObjectId OBJECT-GUID -AttributeNumber 6 -Value 'Finance' -WhatIf
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][string]$TenantId,
    [Parameter(Mandatory)][guid]$DeviceObjectId,
    [Parameter(Mandatory)][ValidateRange(1,15)][int]$AttributeNumber,
    [Parameter(Mandatory)][AllowEmptyString()][string]$Value
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Private/Common.ps1"
Assert-ToolkitGraphContext -TenantId $TenantId
$attribute = "extensionAttribute$AttributeNumber"
$device = Get-MgDevice -DeviceId $DeviceObjectId -Property id,displayName,extensionAttributes -ErrorAction Stop
$before = $device.ExtensionAttributes.$attribute
if ($before -eq $Value) {
    [pscustomobject]@{ DeviceId = $DeviceObjectId; Attribute = $attribute; Previous = $before; Value = $Value; Status = 'Unchanged' }
} elseif ($PSCmdlet.ShouldProcess("$($device.DisplayName) ($DeviceObjectId) in $TenantId", "Set $attribute to '$Value' (previous '$before')")) {
    Update-MgDevice -DeviceId $DeviceObjectId -BodyParameter @{ extensionAttributes = @{ $attribute = $Value } } -ErrorAction Stop
    $after = Get-MgDevice -DeviceId $DeviceObjectId -Property extensionAttributes -ErrorAction Stop
    if ($after.ExtensionAttributes.$attribute -ne $Value) { throw 'Attribute verification failed.' }
    [pscustomobject]@{ DeviceId = $DeviceObjectId; Attribute = $attribute; Previous = $before; Value = $Value; Status = 'Updated' }
}
