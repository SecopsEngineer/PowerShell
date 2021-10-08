#For this screipt to work you will need to change lines 18 and 23 
#the "-server domainname" should be the name of the domain tha tyou want to search

Function Get-ADGroupMemberJohn {
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [string[]]
        $Identity
    )
    process {
        foreach ($GroupIdentity in $Identity) {
            $Group = $null
            $Group = Get-ADGroup -Identity $GroupIdentity -Properties Member -server domainname
            if (-not $Group) {
                continue
            }
            Foreach ($Member in $Group.Member) {
                Get-ADUser $Member -server domainname |Select-object -ExpandProperty name
            }
        }
    }
}
Write-Host "***************************************************************" -ForegroundColor cyan
Write-Host "Welcome to your Friendly Nieghborhood AD Group Member Extractor" -ForegroundColor cyan
Write-Host "***************************************************************" -ForegroundColor cyan

$x = "go"
do {
    $group = read-host "What group do you want?"
    Get-ADGroupMemberJohn $group | Out-File C:\temp\MFAUsers.csv
    Write-Host "Your Group Member list is stored in c:\Temp\MFAUsers.csv" -ForgroundColor green
    $answer = Read-host "another one?"
    if ($answer -eq "no" -or $answer -eq "n"){$x = "stop"}
    cls
    }
    while ($x -ne "stop")
