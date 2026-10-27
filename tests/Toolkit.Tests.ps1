BeforeAll {
    $repo = Split-Path $PSScriptRoot -Parent
    $testComputer = 'fixture-host.example.test'
    . "$repo/Private/Common.ps1"
    # Fail-closed stubs allow mocks without installing or authenticating admin modules.
    function Get-ADUser { [CmdletBinding()] param($Identity,$Server,$Properties,$Filter,[pscredential]$Credential) throw 'Unmocked AD call' }
    function Get-ADGroup { [CmdletBinding()] param($Identity,$Server,$Properties) throw 'Unmocked AD call' }
    function Add-ADGroupMember { [CmdletBinding(SupportsShouldProcess)] param($Identity,$Members,$Server) throw 'Unmocked AD mutation' }
    function Get-ConnectionInformation { [CmdletBinding()] param() throw 'Unmocked Exchange call' }
    function Get-OrganizationConfig { [CmdletBinding()] param() throw 'Unmocked Exchange call' }
    function Get-AuthenticationPolicy { [CmdletBinding()] param($Identity) throw 'Unmocked Exchange call' }
    function New-AuthenticationPolicy { [CmdletBinding(SupportsShouldProcess)] param($Name) throw 'Unmocked Exchange mutation' }
    function Get-User { [CmdletBinding()] param($Identity) throw 'Unmocked Exchange call' }
    function Set-User { [CmdletBinding(SupportsShouldProcess)] param($Identity,$AuthenticationPolicy) throw 'Unmocked Exchange mutation' }
    function Get-AzContext { [CmdletBinding()] param() throw 'Unmocked Azure call' }
    function Set-AzContext { [CmdletBinding()] param($SubscriptionId,$Tenant,$Scope,$Context) throw 'Unmocked Azure call' }
    function Get-AzSubscription { [CmdletBinding()] param($TenantId) throw 'Unmocked Azure call' }
    function Get-AzNetworkSecurityGroup { [CmdletBinding()] param($DefaultProfile) throw 'Unmocked Azure call' }
    function Get-MgContext { [CmdletBinding()] param() throw 'Unmocked Graph call' }
    function Get-MgUser { [CmdletBinding()] param([switch]$All,$Filter,$Property) throw 'Unmocked Graph call' }
    function Get-MgAuditLogSignIn { [CmdletBinding()] param($Filter,$Top) throw 'Unmocked Graph call' }
    function Get-MgDevice { [CmdletBinding()] param([switch]$All,$Filter,$Property,$DeviceId) throw 'Unmocked Graph call' }
    function Update-MgDevice { [CmdletBinding()] param($DeviceId,$BodyParameter) throw 'Unmocked Graph mutation' }
    function Get-Mailbox { [CmdletBinding()] param([switch]$IncludeInactiveMailbox,$ResultSize) throw 'Unmocked Exchange call' }
}

Describe 'Report files' {
    It 'preserves Unicode and refuses to overwrite or append existing results' {
        $path = Join-Path $TestDrive 'report.csv'
        Export-ToolkitReport -InputObject @([pscustomobject]@{ Name = 'Ålice' }) -Path $path
        (Import-Csv $path).Name | Should -Be 'Ålice'
        { Export-ToolkitReport -InputObject @([pscustomobject]@{Name='Bob'}) -Path $path } | Should -Throw '*already exists*'
        (Import-Csv $path).Name | Should -Be 'Ålice'
        Export-ToolkitReport -InputObject @([pscustomobject]@{Name='Bob'}) -Path $path -Force
        @(Import-Csv $path).Count | Should -Be 1
        (Import-Csv $path).Name | Should -Be 'Bob'
    }
    It 'writes no file for an empty result and rejects a missing directory' {
        $path = Join-Path $TestDrive 'empty.csv'
        Export-ToolkitReport -InputObject @() -Path $path -WarningAction SilentlyContinue
        Test-Path $path | Should -BeFalse
        { Export-ToolkitReport -InputObject @([pscustomobject]@{Name='A'}) -Path (Join-Path $TestDrive 'missing/report.csv') } | Should -Throw '*directory*'
    }
    It 'normalizes and deduplicates identity lists' {
        $path = Join-Path $TestDrive 'users.txt'
        @(' alice ', '# comment', '', 'alice', 'bob') | Set-Content $path
        @(Read-ToolkitIdentityList $path).Count | Should -Be 2
    }
}

Describe 'AD membership safeguards' {
    BeforeEach {
        Mock Get-ADUser {
            if ($Identity -eq 'alice') { [pscustomobject]@{ DistinguishedName='CN=alice'; memberOf=@('CN=Finance','CN=Admins') } }
            else { [pscustomobject]@{ DistinguishedName='CN=bob'; memberOf=@() } }
        }
        Mock Get-ADGroup {
            if ($Identity -eq 'CN=Admins') { [pscustomobject]@{Name='Admins';DistinguishedName='CN=Admins';adminCount=1;SID='S-1-5-21-100-512'} }
            else { [pscustomobject]@{Name='Finance';DistinguishedName='CN=Finance';adminCount=0;SID='S-1-5-21-100-1001'} }
        }
        Mock Add-ADGroupMember {}
    }
    It 'previews changes without writing and skips protected groups' {
        $rows = @(& "$repo/Copy_AD_UserGroups.ps1" -SourceUser alice -TargetUser bob -Server dc.example.com -WhatIf)
        ($rows | Where-Object Group -eq Admins).Status | Should -Be 'SkippedProtectedGroup'
        ($rows | Where-Object Group -eq Finance).Status | Should -Be 'Preview'
        Should -Invoke Add-ADGroupMember -Times 0
        Should -Invoke Get-ADUser -Times 2 -ParameterFilter { $Server -eq 'dc.example.com' }
    }
    It 'does not add memberships that already exist' {
        Mock Get-ADUser { [pscustomobject]@{DistinguishedName="CN=$Identity";memberOf=@('CN=Finance')} }
        $rows = @(& "$repo/Copy_AD_UserGroups.ps1" -SourceUser alice -TargetUser bob -Server dc -Confirm:$false)
        $rows[0].Status | Should -Be 'AlreadyMember'
        Should -Invoke Add-ADGroupMember -Times 0
    }
    It 'stops on a failed addition instead of claiming success' {
        Mock Add-ADGroupMember { throw 'Access denied' }
        { & "$repo/Copy_AD_UserGroups.ps1" -SourceUser alice -TargetUser bob -Server dc -Confirm:$false } | Should -Throw '*Access denied*'
    }
    It 'fails if read-back does not confirm the addition' {
        { & "$repo/Copy_AD_UserGroups.ps1" -SourceUser alice -TargetUser bob -Server dc -Confirm:$false } | Should -Throw '*verification failed*'
    }
}

Describe 'Exchange authentication policy safety' {
    BeforeEach {
        Mock Get-ConnectionInformation { [pscustomobject]@{State='Connected'} }
        Mock Get-OrganizationConfig { [pscustomobject]@{Guid='tenant-one'} }
        Mock Get-AuthenticationPolicy { [pscustomobject]@{Name='BlockBasicAuth';AllowBasicAuthImap=$false;AllowBasicAuthSmtp=$false} }
        Mock Get-User { [pscustomobject]@{UserPrincipalName='alice@example.com';AuthenticationPolicy='PreviousPolicy'} }
        Mock New-AuthenticationPolicy {}
        Mock Set-User {}
        $usersPath = Join-Path $TestDrive 'auth-users.txt'
        'alice@example.com' | Set-Content $usersPath
        $backupPath = Join-Path $TestDrive ([guid]::NewGuid().ToString()+'.csv')
    }
    It 'WhatIf neither writes a backup nor changes or creates policies' {
        & "$repo/BlockLegacyAuthentication.ps1" -Mode Apply -UserListPath $usersPath -BackupPath $backupPath -WhatIf
        Test-Path $backupPath | Should -BeFalse
        Should -Invoke Set-User -Times 0
        Should -Invoke New-AuthenticationPolicy -Times 0
    }
    It 'saves the previous policy before setting and never runs rollback on Apply' {
        Mock Set-User {
            Test-Path $backupPath | Should -BeTrue
            (Import-Csv $backupPath).AuthenticationPolicy | Should -Be 'PreviousPolicy'
        }
        Mock Get-User {
            if (Test-Path $backupPath) { [pscustomobject]@{UserPrincipalName='alice@example.com';AuthenticationPolicy='BlockBasicAuth'} }
            else { [pscustomobject]@{UserPrincipalName='alice@example.com';AuthenticationPolicy='PreviousPolicy'} }
        }
        & "$repo/BlockLegacyAuthentication.ps1" -Mode Apply -UserListPath $usersPath -BackupPath $backupPath -Confirm:$false
        Should -Invoke Set-User -Times 1 -Exactly -ParameterFilter { $AuthenticationPolicy -eq 'BlockBasicAuth' }
    }
    It 'does not overwrite a recovery file or mutate users when backup fails' {
        'existing recovery data' | Set-Content $backupPath
        { & "$repo/BlockLegacyAuthentication.ps1" -Mode Apply -UserListPath $usersPath -BackupPath $backupPath -Confirm:$false } | Should -Throw '*already exists*'
        Should -Invoke Set-User -Times 0
    }
    It 'rejects an existing policy that allows Basic authentication' {
        Mock Get-AuthenticationPolicy { [pscustomobject]@{Name='BlockBasicAuth';AllowBasicAuthImap=$true} }
        { & "$repo/BlockLegacyAuthentication.ps1" -Mode Apply -UserListPath $usersPath -BackupPath $backupPath -Confirm:$false } | Should -Throw '*does not verifiably block*'
        Should -Invoke Set-User -Times 0
    }
    It 'restores a null assignment as null rather than an empty string' {
        [pscustomobject]@{OrganizationId='tenant-one';Identity='alice@example.com';AuthenticationPolicy=''} | Export-Csv $backupPath
        Mock Get-User { [pscustomobject]@{UserPrincipalName='alice@example.com';AuthenticationPolicy=$null} }
        & "$repo/BlockLegacyAuthentication.ps1" -Mode Restore -RestoreSavedAssignments -BackupPath $backupPath -Confirm:$false
        Should -Invoke Set-User -Times 1 -ParameterFilter { $null -eq $AuthenticationPolicy }
        Should -Invoke New-AuthenticationPolicy -Times 0
    }
    It 'refuses a backup from another organization before restoring anyone' {
        [pscustomobject]@{OrganizationId='wrong-tenant';Identity='alice@example.com';AuthenticationPolicy='Old'} | Export-Csv $backupPath
        { & "$repo/BlockLegacyAuthentication.ps1" -Mode Restore -RestoreSavedAssignments -BackupPath $backupPath -Confirm:$false } | Should -Throw '*wrong organization*'
        Should -Invoke Set-User -Times 0
    }
}

Describe 'AD domain selection and failures' {
    It 'uses the requested domain and propagates directory outages' {
        $path = Join-Path $TestDrive 'ad-users.txt'
        'alice' | Set-Content $path
        Mock Get-ADUser { throw 'Directory unavailable' }
        { & "$repo/Get-ADUserEnabledStatus.ps1" -Server selected.dc -UserListPath $path } | Should -Throw '*Directory unavailable*'
        Should -Invoke Get-ADUser -Times 1 -ParameterFilter { $Server -eq 'selected.dc' }
    }
    It 'reports enabled status without changing accounts' {
        $path = Join-Path $TestDrive 'ad-users-ok.txt'
        'alice' | Set-Content $path
        Mock Get-ADUser { [pscustomobject]@{Name='Alice';Enabled=$false} }
        $row = & "$repo/Get-ADUserEnabledStatus.ps1" -Server selected.dc -UserListPath $path
        $row.Status | Should -Be Found
        $row.Enabled | Should -BeFalse
    }
}

Describe 'Azure NSG reporting' {
    BeforeEach {
        Mock Get-AzContext { [pscustomobject]@{Tenant=[pscustomobject]@{Id='tenant'};Name='original'} }
        Mock Get-AzSubscription { [pscustomobject]@{Id='sub1';Name='Production'} }
        Mock Set-AzContext { [pscustomobject]@{Name='selected'} }
        Mock Get-AzNetworkSecurityGroup {
            [pscustomobject]@{
                Id='/subscriptions/sub1/nsg/nsg1';Name='nsg1';Location='eastus';ResourceGroupName='rg'
                DefaultSecurityRules=@()
                SecurityRules=@([pscustomobject]@{
                    Name='multi';Priority=100;Direction='Inbound';Access='Allow';Protocol='Tcp';Description='Åudit'
                    SourceAddressPrefixes=@('10.0.0.0/24','10.0.1.0/24');SourceAddressPrefix=$null
                    SourcePortRanges=@('80','443');SourcePortRange=$null
                    DestinationAddressPrefixes=@('10.1.0.0/24');DestinationAddressPrefix=$null
                    DestinationPortRanges=@('8080','8443');DestinationPortRange=$null
                    SourceApplicationSecurityGroups=@([pscustomobject]@{Id='/asg/source'})
                    DestinationApplicationSecurityGroups=@()
                })
            }
        }
    }
    It 'includes plural fields, ASGs and subscription identity without appending across runs' {
        $path = Join-Path $TestDrive 'nsg.csv'
        $row = & "$repo/ExportNSG_All_BySubscription.ps1" -TenantId tenant -SubscriptionId sub1 -OutputPath $path
        $row.SubscriptionId | Should -Be sub1
        $row.SourceAddresses | Should -Be '10.0.0.0/24;10.0.1.0/24'
        $row.SourcePorts | Should -Be '80;443'
        $row.DestinationPorts | Should -Be '8080;8443'
        $row.SourceApplicationSecurityGroups | Should -Be '/asg/source'
        (Import-Csv $path).Description | Should -Be 'Åudit'
        Should -Invoke Set-AzContext -Times 1 -ParameterFilter { $null -ne $Context -and $Context.Name -eq 'original' }
    }
    It 'restores the active context even when collection fails' {
        Mock Get-AzNetworkSecurityGroup { throw 'Azure unavailable' }
        { & "$repo/ExportNSG_All_BySubscription.ps1" -TenantId tenant -SubscriptionId sub1 -OutputPath (Join-Path $TestDrive 'bad.csv') } | Should -Throw '*Azure unavailable*'
        Should -Invoke Set-AzContext -Times 1 -ParameterFilter { $null -ne $Context -and $Context.Name -eq 'original' }
    }
    It 'rejects unknown subscriptions without changing context' {
        { & "$repo/ExportNSG_All_BySubscription.ps1" -TenantId tenant -SubscriptionId other -OutputPath (Join-Path $TestDrive 'bad.csv') } | Should -Throw '*not accessible*'
        Should -Invoke Set-AzContext -Times 0
    }
}

Describe 'Graph reporting' {
    BeforeEach {
        Mock Get-MgContext { [pscustomobject]@{TenantId='tenant'} }
        Mock Get-MgUser { [pscustomobject]@{Id='guest-id';DisplayName='Guest';UserPrincipalName='guest@example.com';UserType='Guest'} }
        Mock Get-MgAuditLogSignIn { @() }
        Mock Get-MgDevice { @() }
        Mock Update-MgDevice {}
    }
    It 'distinguishes absent retained sign-ins from a never-used account' {
        $row = & "$repo/GraphAPI-GuestUserStatus.ps1" -TenantId tenant
        $row.Name | Should -Be Guest
        $row.RecordStatus | Should -Be NoAvailableRecord
        $row.SignInDate | Should -BeNullOrEmpty
        Should -Invoke Get-MgUser -Times 1 -ParameterFilter { $All -and 'createdDateTime' -in $Property }
    }
    It 'does not turn API failures into an empty sign-in history' {
        Mock Get-MgAuditLogSignIn { throw 'Forbidden' }
        { & "$repo/GraphAPI-GuestUserStatus.ps1" -TenantId tenant } | Should -Throw '*Forbidden*'
    }
    It 'refuses the wrong tenant before querying data' {
        { & "$repo/Export-GraphDevices.ps1" -TenantId wrong } | Should -Throw '*Connect-MgGraph*'
        Should -Invoke Get-MgDevice -Times 0
    }
    It 'escapes apostrophes in OData prefix input and follows all pages' {
        & "$repo/Find-GraphDevice.ps1" -TenantId tenant -DisplayNamePrefix "O'Brien"
        Should -Invoke Get-MgDevice -Times 1 -ParameterFilter { $All -and $Filter -eq "startsWith(displayName,'O''Brien')" }
    }
    It 'does not write a device attribute during WhatIf' {
        Mock Get-MgDevice { [pscustomobject]@{Id='d';DisplayName='Device';ExtensionAttributes=@{extensionAttribute6='Before'}} }
        & "$repo/Set-GraphDeviceExtensionAttribute.ps1" -TenantId tenant -DeviceObjectId '11111111-1111-1111-1111-111111111111' -AttributeNumber 6 -Value After -WhatIf
        Should -Invoke Update-MgDevice -Times 0
    }
}

Describe 'Mailbox hold semantics' {
    It 'keeps retention processing pauses distinct and reports each mailbox once' {
        Mock Get-ConnectionInformation { [pscustomobject]@{State='Connected'} }
        Mock Get-Mailbox {
            [pscustomobject]@{Name='A';UserPrincipalName='a@example.com';InPlaceHolds=@();RetentionHoldEnabled=$true;LitigationHoldEnabled=$false;ComplianceTagHoldApplied=$false}
            [pscustomobject]@{Name='B';UserPrincipalName='b@example.com';InPlaceHolds=@('mbx1','UniH2');RetentionHoldEnabled=$false;LitigationHoldEnabled=$true;ComplianceTagHoldApplied=$true}
        }
        $rows = @(& "$repo/Export-O365MailboxHolds.ps1")
        $rows.Count | Should -Be 2
        $rows[0].RetentionProcessingPaused | Should -BeTrue
        $rows[1].InPlaceHoldIdentifierCount | Should -Be 2
        $rows[1].InPlaceHoldIdentifiers | Should -Be 'mbx1;UniH2'
    }
}

Describe 'Additional report regressions' {
    BeforeAll {
        function Get-MpComputerStatus { [CmdletBinding()] param() throw 'Unmocked Defender call' }
    }
    It 'filters expired accounts and keeps no-expiration reporting explicit' {
        Mock Get-ADUser {
            [pscustomobject]@{Name='Expired';AccountExpirationDate=(Get-Date).AddDays(-1)}
            [pscustomobject]@{Name='Future';AccountExpirationDate=(Get-Date).AddDays(1)}
            [pscustomobject]@{Name='None';AccountExpirationDate=$null}
        }
        $expired = @(& "$repo/Get-ADExpiredAccounts.ps1" -Server dc)
        $expired.Count | Should -Be 1
        $expired[0].Name | Should -Be Expired
        $none = @(& "$repo/Get-ADExpiredAccounts.ps1" -Server dc -WithoutExpiration)
        $none.Count | Should -Be 1
        $none[0].Name | Should -Be None
    }
    It 'uses event 4720 target SID evidence rather than a CreatedBy property' {
        Mock Get-ADUser { [pscustomobject]@{SamAccountName='Alice';whenCreated=[datetime]'2025-01-01';SID='S-1-5-21-100-1000'} }
        Mock Get-WinEvent {
            $entry = [pscustomobject]@{TimeCreated=[datetime]'2025-01-01';RecordId=42}
            $entry | Add-Member -MemberType ScriptMethod -Name ToXml -Value {
                '<Event><EventData><Data Name="TargetSid">S-1-5-21-100-1000</Data><Data Name="SubjectDomainName">EXAMPLE</Data><Data Name="SubjectUserName">Operator</Data></EventData></Event>'
            }
            $entry
        }
        $row = & "$repo/Get-ADUserCreationAudit.ps1" -Server dc -Identity alice -DomainController dc1
        $row.Creator | Should -Be 'EXAMPLE\Operator'
        $row.Evidence | Should -Be Event4720
        $row.RecordId | Should -Be 42
        Should -Invoke Get-WinEvent -Times 1 -ParameterFilter { $FilterHashtable.Id -eq 4720 -and $ComputerName -eq 'dc1' }
    }
    It 'does not attribute another SID creation event to the selected user' {
        Mock Get-ADUser { [pscustomobject]@{SamAccountName='Alice';whenCreated=[datetime]'2025-01-01';SID='S-1-5-21-100-1000'} }
        Mock Get-WinEvent {
            $entry = [pscustomobject]@{TimeCreated=[datetime]'2025-01-01';RecordId=43}
            $entry | Add-Member -MemberType ScriptMethod -Name ToXml -Value {
                '<Event><EventData><Data Name="TargetSid">S-1-5-21-100-1001</Data><Data Name="SubjectDomainName">EXAMPLE</Data><Data Name="SubjectUserName">Operator</Data></EventData></Event>'
            }
            $entry
        }
        $row = & "$repo/Get-ADUserCreationAudit.ps1" -Server dc -Identity alice -DomainController dc1
        $row.Creator | Should -BeNullOrEmpty
        $row.Evidence | Should -Be NoAvailableRecord
    }
    It 'rejects invalid event ranges before contacting a remote computer' {
        Mock Get-WinEvent {}
        { & "$repo/Get-WindowsEvents.ps1" -ComputerName $testComputer -StartTime '2025-01-02' -EndTime '2025-01-01' } | Should -Throw '*StartTime must precede*'
        Should -Invoke Get-WinEvent -Times 0
    }
    It 'passes selected log, dates and credentials to event collection' {
        Mock Get-WinEvent { [pscustomobject]@{MachineName='host1';Id=7;Message='sample'} }
        $credential = [pscredential]::new('EXAMPLE\reader', [Security.SecureString]::new())
        $row = & "$repo/Get-WindowsEvents.ps1" -ComputerName $testComputer -StartTime '2025-01-01' -EndTime '2025-01-02' -LogName Application -Credential $credential
        $row.Id | Should -Be 7
        Should -Invoke Get-WinEvent -Times 1 -ParameterFilter { $ComputerName -eq $testComputer -and $FilterHashtable.LogName -eq 'Application' -and $null -ne $Credential }
    }
    It 'removes the CIM session even if inventory collection fails' {
        Mock New-CimSession { New-MockObject -Type Microsoft.Management.Infrastructure.CimSession }
        Mock Get-CimInstance { throw 'Remote inventory failed' }
        Mock Remove-CimSession {}
        { & "$repo/Get-ComputerInfo.ps1" -ComputerName $testComputer } | Should -Throw '*Remote inventory failed*'
        Should -Invoke Remove-CimSession -Times 1
    }
    It 'defaults Defender toolkit to reading status without a mutation' {
        Mock Get-MpComputerStatus { [pscustomobject]@{RealTimeProtectionEnabled=$true} }
        $row = & "$repo/DefenderToolkit.ps1"
        $row.RealTimeProtectionEnabled | Should -BeTrue
        Should -Invoke Get-MpComputerStatus -Times 1
    }
}
