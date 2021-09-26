<#
Verify credentials against Active directory

This script will allow you to verify the credentials for a user
Prompts you for a user name and prompts for a secure password entry

#>
param (
   [Parameter(Mandatory=$true)] [string] $user
)

Function Test-UserCredentials
{ 
    param(
        [Parameter(Mandatory=$True)]
        [string] $LoginName,

        [Parameter(Mandatory=$True)]
        [string] $Password
    )

    Add-Type -AssemblyName System.DirectoryServices.AccountManagement
    $DS = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('domain')
    $result = $DS.ValidateCredentials($LoginName, $Password)

    If ($result)
    {
        Write-Host "$LoginName - The account successfully authenticated, the password is correct." -ForegroundColor green
    }
    Else
    {
        Write-Host "$LoginName - Authentication failed with the provided password." -ForegroundColor red
    }
    
    return $result
}

Write-Host "(BEFORE) Account Status:`n"
net user $user /domain

$securePassword = Read-Host -Prompt "Enter password" -AsSecureString
$BSTR = `
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
$plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

Test-UserCredentials "$user" "$plainPassword"

pause

Write-Host "`n(AFTER) Account Status:"
net user $user /domain

