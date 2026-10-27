<#
.SYNOPSIS
Validate one supplied credential against the selected AD domain.
.DESCRIPTION
Windows only. Failed attempts can contribute to account lockout. The directory API
requires a transient managed plaintext string; it cannot be reliably zeroed by .NET.
The unmanaged BSTR is always zeroed and freed, and the directory context disposed.
.EXAMPLE
.\verify-credentials.ps1 -Domain example.com -Credential (Get-Credential)
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Domain,
    [Parameter(Mandatory)][pscredential]$Credential
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.DirectoryServices.AccountManagement
$context = $null
$pointer = [IntPtr]::Zero
$plainPassword = $null
try {
    $context = [System.DirectoryServices.AccountManagement.PrincipalContext]::new(
        [System.DirectoryServices.AccountManagement.ContextType]::Domain, $Domain)
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential.Password)
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    [pscustomobject]@{
        Domain = $Domain
        UserName = $Credential.UserName
        Authenticated = $context.ValidateCredentials($Credential.UserName, $plainPassword)
    }
} finally {
    if ($pointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
    $plainPassword = $null
    if ($null -ne $context) { $context.Dispose() }
}
