<#
.SYNOPSIS
Collect common Windows persistence configuration without executing target commands.
.DESCRIPTION
Requires Windows, CIM, ScheduledTasks, registry and filesystem read access. Use
WinRM and appropriate credentials for remote hosts. Collects all services, task
actions (including disabled tasks), machine Run/RunOnce values, loaded user hives'
Run/RunOnce values and common/per-profile Startup files. Does not load user hives,
resolve shortcuts, start tasks, inspect WMI subscriptions, or declare entries
malicious. Registry and startup coverage is limited to readable/loaded profiles.
Failure to read a selected source terminates the report. Command lines may contain
sensitive information; protect exports. ComputerName + Id is a comparison key.
.EXAMPLE
.\Get-WindowsPersistence.ps1 -OutputPath .\persistence.csv
.EXAMPLE
.\Get-WindowsPersistence.ps1 -ComputerName server.example.com -Credential (Get-Credential)
#>
[CmdletBinding()]
param([string]$ComputerName = $env:COMPUTERNAME, [pscredential]$Credential, [string]$OutputPath, [switch]$Force)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Private/Common.ps1"
$collector = {
    $ErrorActionPreference = 'Stop'
    if ($env:OS -ne 'Windows_NT') { throw 'Persistence collection requires Windows.' }
    foreach ($service in @(Get-CimInstance -ClassName Win32_Service -ErrorAction Stop)) {
        [pscustomobject]@{
            ComputerName = $env:COMPUTERNAME; Id = 'Service:' + $service.Name; Type = 'Service'; Name = $service.Name
            Location = 'Win32_Service'; Command = $service.PathName; Arguments = $null
            User = $service.StartName; State = $service.State; StartMode = $service.StartMode
        }
    }
    foreach ($task in @(Get-ScheduledTask -ErrorAction Stop)) {
        $index = 0
        foreach ($action in @($task.Actions)) {
            $index++
            $command = if ($action.Execute) { $action.Execute } else { 'NonExecAction:' + [string]$action.ClassId }
            [pscustomobject]@{
                ComputerName = $env:COMPUTERNAME; Id = "Task:$($task.TaskPath)$($task.TaskName):$index"; Type = 'ScheduledTask'; Name = $task.TaskName
                Location = $task.TaskPath; Command = $command; Arguments = $action.Arguments
                User = $task.Principal.UserId; State = [string]$task.State; StartMode = $null
            }
        }
    }
    $keys = [Collections.Generic.List[string]]::new()
    foreach ($suffix in 'Run','RunOnce') {
        $keys.Add("Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\$suffix")
        $keys.Add("Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\$suffix")
    }
    foreach ($hive in @(Get-ChildItem -LiteralPath 'Registry::HKEY_USERS' -ErrorAction Stop)) {
        if ($hive.PSChildName -notmatch '^S-1-(5-21|12-1)-[\d-]+$') { continue }
        foreach ($suffix in 'Run','RunOnce') {
            $keys.Add("Registry::HKEY_USERS\$($hive.PSChildName)\SOFTWARE\Microsoft\Windows\CurrentVersion\$suffix")
            $keys.Add("Registry::HKEY_USERS\$($hive.PSChildName)\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\$suffix")
        }
    }
    foreach ($key in $keys) {
        if (-not (Test-Path -LiteralPath $key -ErrorAction Stop)) { continue }
        $values = Get-ItemProperty -LiteralPath $key -ErrorAction Stop
        foreach ($property in $values.PSObject.Properties) {
            if ($property.Name -in 'PSPath','PSParentPath','PSChildName','PSDrive','PSProvider') { continue }
            [pscustomobject]@{
                ComputerName = $env:COMPUTERNAME; Id = "Registry:${key}:$($property.Name)"; Type = 'RegistryAutorun'; Name = $property.Name
                Location = $key; Command = [string]$property.Value; Arguments = $null
                User = if ($key -like 'Registry::HKEY_USERS*') { ($key -split '\\')[1] } else { 'Machine' }
                State = 'Configured'; StartMode = $null
            }
        }
    }
    $startupPaths = [Collections.Generic.List[string]]::new()
    $common = [Environment]::GetFolderPath('CommonStartup')
    if ($common) { $startupPaths.Add($common) }
    foreach ($userFolder in @(Get-ChildItem -LiteralPath (Join-Path $env:SystemDrive Users) -Directory -Force -ErrorAction Stop)) {
        $startupPaths.Add((Join-Path $userFolder.FullName 'AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup'))
    }
    foreach ($startupPath in $startupPaths) {
        if (-not (Test-Path -LiteralPath $startupPath -PathType Container -ErrorAction Stop)) { continue }
        foreach ($file in @(Get-ChildItem -LiteralPath $startupPath -File -Force -ErrorAction Stop)) {
            [pscustomobject]@{
                ComputerName = $env:COMPUTERNAME; Id = 'Startup:' + $file.FullName; Type = 'StartupFile'; Name = $file.Name
                Location = $startupPath; Command = $file.FullName; Arguments = $null
                User = 'SeeProfilePath'; State = 'PresentTargetNotExecuted'; StartMode = $null
            }
        }
    }
}
$local = $ComputerName -in '.', 'localhost', $env:COMPUTERNAME
$rows = if ($local -and -not $Credential) { @(& $collector) } else {
    $query = @{ ComputerName = $ComputerName; ScriptBlock = $collector; ErrorAction = 'Stop' }
    if ($Credential) { $query.Credential = $Credential }
    @(Invoke-Command @query | Select-Object ComputerName,Id,Type,Name,Location,Command,Arguments,User,State,StartMode)
}
if ($OutputPath) { Export-ToolkitReport -InputObject $rows -Path $OutputPath -Force:$Force }
$rows
