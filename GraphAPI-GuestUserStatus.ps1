
# ReportLastAccountSignIn-Mg.PS1
# 
#
# Connect to the Graph, specifying the tenant and profile to use - Add your tenant identifier here
Connect-MgGraph -TenantId TENANTID -Scope Auditlog.Read.All
Select-MgProfile beta # Beta needed to get more informtion from the Graph
$Details = Get-MgContext
$Scopes = $Details | Select -ExpandProperty Scopes
$Scopes = $Scopes -Join ", "
$ProfileName = (Get-MgProfile).Name
$OrgName = (Get-MgOrganization).DisplayName
CLS
Write-Host "Microsoft Graph Connection Information" -ForegroundColor Cyan
Write-Host "--------------------------------------" -ForegroundColor Cyan
Write-Host " "
Write-Host ("Connected to Tenant {0} ({1}) as account {2}" -f $Details.TenantId, $OrgName, $Details.Account) -ForegroundColor Green
Write-Host "+-------------------------------------------------------------------------------------------------------------------+" -ForegroundColor Green
Write-Host ("Profile set as {0}. The following permission scope is defined: {1}" -f $ProfileName, $Scopes) -ForegroundColor Green
Write-Host ""
#$Username = Read-Host "What User would you like to look for ? (Include the full UPN) "
Write-Host "Finding Azure AD Users" -ForegroundColor Yellow
#This is the magic -Can change things here to do different stuff
#The below command searchs for a user name
# *********************************************
#[array]$Users = Get-MgUser -UserId $Username
# This command searches for all Guest users
# *********************************************
[array]$Users = Get-MgUser -All -Filter "UserType eq 'Guest'"

If ($Users.Count -eq 0) { Write-Host "Sorry, no Azure AD user info fetched"; break}
CLS
$ProgressDelta = 100/($Users.count); $PercentComplete = 0; $UserNumber = 0
Write-Host ("{0} accounts to process..." -f $Users.Count)
CLS;$Report = [System.Collections.Generic.List[Object]]::new();$CSVOutput = "C:\temp\LastAccountSignIn.CSV"
ForEach ($User in $Users) { # See if we can find the last sign in record for an account
   $UserNumber++
   $PercentComplete += $ProgressDelta
   $UserStatus = $User.DisplayName + " ["+ $UserNumber +"/" + $Users.Count + "]"
   Write-Progress -Activity "Processing user" -Status $UserStatus -PercentComplete $PercentComplete
   [array]$LastSignIn = Get-MgAuditLogSignIn -Filter "UserId eq '$($User.Id)'" -Top 1
   If ($LastSignIn) { # We found a sign in record, so report it
      $ReportLine  = [PSCustomObject][Ordered]@{ 
         Name           = $LastSignIn.UserDisplayName
         UPN            = $LastSignIn.UserPrincipalName
         Id             = $LastSignIn.UserId
         UserType       = $User.UserType
         AccountCreated = $User.CreatedDateTime
         CreationType   = $User.CreationType
         InvitationState = $User.externalUserState
         SignInDate     = $LastSignIn.CreatedDateTime
         DaysSince      = ($LastSignIn.CreatedDateTime | New-TimeSpan).Days
         Location       = $LastSignIn.Location.City
         App            = $LastSignIn.AppDisplayName
         Client         = $LastSignIn.ClientAppUsed
         IPAddress      = $LastSignIn.IPAddress
         IsInteractive  = $LastSignIn.IsInterActive
         CAAccess       = $LastSignIn.ConditionalAccessStatus 
         RiskState      = $LastSignIn.RiskState }
      $Report.Add($ReportLine) } #End if
    Else { # No sign in record found, so we report that"
       $ReportLine  = [PSCustomObject][Ordered]@{ 
         Name           = $User.UserDisplayName
         UPN            = $User.UserPrincipalName
         Id             = $User.Id
         UserType       = $User.UserType
         AccountCreated = $User.CreatedDateTime
         CreationType   = $User.CreationType
         InvitationState = $User.externalUserState
         SignInDate     = "No sign in data found"
         DaysSince      = "N/A"
         App            = "N/A"
         Client         = "N/A"
         IPAddress      = "N/A"
         IsInteractive  = "N/A"
         CAAccess       = "N/A" 
         RiskState      = "N/A" }
      $Report.Add($ReportLine) } #End Else
} #End ForEach
$Report | Sort {$_.SignInDate -as [datetime]} -descending | Out-GridView
$Report | Export-CSV -NoTypeInformation $CSVOutput
Write-Host "All done. Report is on the screen and available in" $CSVOutput -ForegroundColor Green
