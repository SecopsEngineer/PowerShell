<#
.SYNOPSIS
Parse, lint and test the collection without importing administrative modules.
.DESCRIPTION
Install Pester 5.7.1 and PSScriptAnalyzer 1.24.0 first. Windows browser tests also
require sqlite3 >= 3.33; supply TOOLKIT_TEST_SQLITE or install it in PATH.
.EXAMPLE
.\tools\Test-Repository.ps1
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Import-Module PSScriptAnalyzer -RequiredVersion 1.24.0
Import-Module Pester -RequiredVersion 5.7.1
$parseErrors = @(foreach ($file in (Get-ChildItem $root -Filter *.ps1 -Recurse)) {
    $tokens = $null
    $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    $errors
})
if ($parseErrors.Count) { $parseErrors | Format-List | Out-String | Write-Output; throw 'PowerShell parsing failed.' }
$findings = @(foreach ($file in (Get-ChildItem $root -Recurse -Filter *.ps1)) {
    $analyzer = @{ Path = $file.FullName; Severity = 'Error','Warning' }
    if ($file.Name -like '*.Tests.ps1') {
        # Pester discovers variables across blocks; fail-closed mock stubs deliberately
        # declare SDK signatures but never invoke real ShouldProcess operations.
        $analyzer.ExcludeRule = 'PSUseDeclaredVarsMoreThanAssignments','PSReviewUnusedParameter','PSUseShouldProcessForStateChangingFunctions','PSShouldProcess','PSAvoidOverwritingBuiltInCmdlets'
    }
    Invoke-ScriptAnalyzer @analyzer
})
if ($findings.Count) { $findings | Format-Table -AutoSize | Out-String | Write-Output; throw 'PSScriptAnalyzer found errors or warnings.' }
$result = Invoke-Pester -Path (Join-Path $root tests) -PassThru -Output Detailed
if ($result.FailedCount -gt 0 -or $result.TotalCount -eq 0) { throw 'Regression tests failed or no tests ran.' }
