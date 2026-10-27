# Shared helpers. Dot-source from scripts; no administrative side effects.
function Export-ToolkitReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$InputObject,
        [Parameter(Mandatory)][string]$Path,
        [switch]$Force
    )
    $fullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $parent = Split-Path -Parent $fullPath
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { throw "Output directory does not exist: $parent" }
    if ((Test-Path -LiteralPath $fullPath) -and -not $Force) { throw "Report already exists: $fullPath. Choose another path or use -Force." }
    if ($InputObject.Count -eq 0) { Write-Warning 'No rows returned. No report was written.'; return }
    $temporary = Join-Path $parent ([guid]::NewGuid().ToString() + '.tmp')
    try {
        $InputObject | Export-Csv -LiteralPath $temporary -NoTypeInformation -Encoding utf8 -ErrorAction Stop
        Move-Item -LiteralPath $temporary -Destination $fullPath -Force:$Force -ErrorAction Stop
    } finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -ErrorAction Stop }
    }
}
function Assert-ToolkitGraphContext {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$TenantId)
    $context = Get-MgContext -ErrorAction Stop
    if (-not $context -or $context.TenantId -ne $TenantId) { throw "Connect-MgGraph to tenant '$TenantId' with the documented permissions first." }
}
function Read-ToolkitIdentityList {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][string]$Path)
    $items = @(Get-Content -LiteralPath $Path -ErrorAction Stop | ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith('#') } | Sort-Object -Unique)
    if ($items.Count -eq 0) { throw 'The identity list is empty.' }
    $items | ForEach-Object { [string]$_ }
}
