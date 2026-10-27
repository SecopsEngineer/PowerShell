BeforeAll {
    $repo = Split-Path $PSScriptRoot -Parent
    $asOf = [datetimeoffset]'2026-10-27T12:00:00Z'
    $testComputer = 'fixture-host.example.test'
    function Get-ADGroup { [CmdletBinding()] param($Identity,$Filter,$Server) throw 'Unmocked AD query' }
    function Get-ADGroupMember { [CmdletBinding()] param($Identity,$Server) throw 'Unmocked AD query' }
    function Get-ADUser { [CmdletBinding()] param($Filter,$Server,$Properties,$SearchBase,[pscredential]$Credential) throw 'Unmocked AD query' }
    function Get-ADComputer { [CmdletBinding()] param($Filter,$Server,$Properties,$SearchBase,[pscredential]$Credential) throw 'Unmocked AD query' }
    function Get-MgContext { [CmdletBinding()] param() throw 'Unmocked Graph query' }
    function Get-MgApplication { [CmdletBinding()] param([switch]$All,$Property) throw 'Unmocked Graph query' }
    function Get-ConnectionInformation { [CmdletBinding()] param() throw 'Unmocked Exchange query' }
    function Get-AcceptedDomain { [CmdletBinding()] param() throw 'Unmocked Exchange query' }
    function Get-Mailbox { [CmdletBinding()] param($Identity,$ResultSize,$RecipientTypeDetails) throw 'Unmocked Exchange query' }
    function Get-InboxRule { [CmdletBinding()] param($Mailbox,[switch]$IncludeHidden,$ResultSize) throw 'Unmocked Exchange query' }
    function Get-Recipient { [CmdletBinding()] param($Identity) throw 'Unmocked Exchange query' }
    function Get-AzContext { [CmdletBinding()] param() throw 'Unmocked Azure query' }
    function Get-AzSubscription { [CmdletBinding()] param($TenantId) throw 'Unmocked Azure query' }
    function Set-AzContext { [CmdletBinding()] param($Context,$Tenant,$SubscriptionId,$Scope) throw 'Unmocked Azure context change' }
    function Get-AzPublicIpAddress { [CmdletBinding()] param($DefaultProfile) throw 'Unmocked Azure query' }
    function Get-AzNetworkSecurityGroup { [CmdletBinding()] param($DefaultProfile) throw 'Unmocked Azure query' }
    function Get-ScheduledTask { [CmdletBinding()] param() throw 'Unmocked scheduled-task query' }
}

Describe 'Privileged AD group paths' {
    BeforeEach {
        Mock Get-ADGroup { [pscustomobject]@{Name='Root';DistinguishedName='CN=Root';ObjectClass='group'} }
        Mock Get-ADGroupMember {
            if ($Identity -eq 'CN=Root') { [pscustomobject]@{Name='Nested';DistinguishedName='CN=Nested';ObjectClass='group'} }
            else { [pscustomobject]@{Name='Alice';SamAccountName='alice';DistinguishedName='CN=Alice';ObjectClass='user';SID='S-1-5-21-1-1000'} }
        }
    }
    It 'uses the requested server and preserves indirect membership paths' {
        $rows = @(& "$repo/Get-ADPrivilegedGroupMembers.ps1" -Server selected.dc)
        $rows.Count | Should -Be 2
        ($rows | Where-Object MemberName -eq Alice).MembershipPath | Should -Be 'Root -> Nested -> Alice'
        ($rows | Where-Object MemberName -eq Alice).Depth | Should -Be 2
        ($rows | Where-Object MemberName -eq Alice).DistinguishedNamePath | Should -Be 'CN=Root -> CN=Nested -> CN=Alice'
        Should -Invoke Get-ADGroup -Times 1 -ParameterFilter { $Server -eq 'selected.dc' -and $Filter -eq 'adminCount -eq 1' }
        Should -Invoke Get-ADGroupMember -Times 2 -ParameterFilter { $Server -eq 'selected.dc' }
    }
    It 'emits a group cycle rather than recursing forever' {
        Mock Get-ADGroupMember {
            if ($Identity -eq 'CN=Root') { [pscustomobject]@{Name='Nested';DistinguishedName='CN=Nested';ObjectClass='group'} }
            else { [pscustomobject]@{Name='Root';DistinguishedName='CN=Root';ObjectClass='group'} }
        }
        $rows = @(& "$repo/Get-ADPrivilegedGroupMembers.ps1" -Server dc)
        ($rows | Where-Object Status -eq Cycle).MembershipPath | Should -Be 'Root -> Nested -> Root'
        Should -Invoke Get-ADGroupMember -Times 2
    }
    It 'reports a depth limit instead of silently truncating the path' {
        $rows = @(& "$repo/Get-ADPrivilegedGroupMembers.ps1" -Server dc -MaxDepth 1)
        $rows[0].Status | Should -Be DepthLimit
        Should -Invoke Get-ADGroupMember -Times 1
    }
    It 'accepts custom group identities without relying on localized group names' {
        & "$repo/Get-ADPrivilegedGroupMembers.ps1" -Server dc -GroupIdentity custom-review-group
        Should -Invoke Get-ADGroup -Times 1 -ParameterFilter { $Identity -eq 'custom-review-group' }
    }
    It 'propagates access failures rather than returning a clean empty membership report' {
        Mock Get-ADGroupMember { throw 'Access denied' }
        { & "$repo/Get-ADPrivilegedGroupMembers.ps1" -Server dc } | Should -Throw '*Access denied*'
    }
}

Describe 'Stale AD accounts' {
    BeforeEach {
        Mock Get-ADUser {
            [pscustomobject]@{Name='Old';Enabled=$true;LastLogonDate=[datetime]'2026-01-01T00:00:00Z';whenCreated=[datetime]'2025-01-01T00:00:00Z'}
            [pscustomobject]@{Name='Recent';Enabled=$true;LastLogonDate=[datetime]'2026-10-25T00:00:00Z';whenCreated=[datetime]'2025-01-01T00:00:00Z'}
            [pscustomobject]@{Name='NewNoLogon';Enabled=$true;LastLogonDate=$null;whenCreated=[datetime]'2026-10-26T00:00:00Z'}
            [pscustomobject]@{Name='OldNoLogon';Enabled=$true;LastLogonDate=$null;whenCreated=[datetime]'2025-01-01T00:00:00Z'}
            [pscustomobject]@{Name='Unknown';Enabled=$true;LastLogonDate=$null;whenCreated=$null}
        }
        Mock Get-ADComputer { [pscustomobject]@{Name='OldComputer';Enabled=$true;LastLogonDate=[datetime]'2026-01-01T00:00:00Z';whenCreated=[datetime]'2025-01-01T00:00:00Z'} }
    }
    It 'excludes recent accounts and separates missing-logon and missing-timestamp evidence' {
        $rows = @(& "$repo/Get-ADStaleAccounts.ps1" -Server dc -AsOf $asOf)
        $rows.Count | Should -Be 4
        $rows.Name | Should -Not -Contain Recent
        $rows.Name | Should -Not -Contain NewNoLogon
        ($rows | Where-Object Name -eq OldNoLogon).Evidence | Should -Be NoReplicatedLogonCreationFallback
        ($rows | Where-Object Name -eq Unknown).IsInactivityCandidate | Should -BeNullOrEmpty
        Should -Invoke Get-ADComputer -Times 1
    }
    It 'honors account type, OU, credentials and explicit disabled-account inclusion' {
        $credential = [pscredential]::new('fixture-reader', [Security.SecureString]::new())
        & "$repo/Get-ADStaleAccounts.ps1" -Server selected.dc -AccountType Computer -IncludeDisabled -SearchBase 'OU=Test,DC=example,DC=test' -Credential $credential -AsOf $asOf
        Should -Invoke Get-ADUser -Times 0
        Should -Invoke Get-ADComputer -Times 1 -ParameterFilter { $Server -eq 'selected.dc' -and $Filter -eq '*' -and $SearchBase -eq 'OU=Test,DC=example,DC=test' -and $null -ne $Credential }
    }
}

Describe 'Application credential metadata' {
    BeforeEach {
        Mock Get-MgContext { [pscustomobject]@{TenantId='tenant'} }
        Mock Get-MgApplication {
            [pscustomobject]@{
                Id='object';AppId='app';DisplayName='Example'
                PasswordCredentials=@(
                    [pscustomobject]@{KeyId='expired';EndDateTime=$asOf.AddDays(-1);SecretText='DO-NOT-EMIT';Hint='DO-NOT-EMIT'},
                    [pscustomobject]@{KeyId='soon';EndDateTime=$asOf.AddDays(5)},
                    [pscustomobject]@{KeyId='valid';EndDateTime=$asOf.AddDays(100)},
                    [pscustomobject]@{KeyId='missing';EndDateTime=$null}
                )
                KeyCredentials=@([pscustomobject]@{KeyId='future';StartDateTime=$asOf.AddDays(2);EndDateTime=$asOf.AddDays(100);Key='DO-NOT-EMIT'})
            }
        }
    }
    It 'includes expired, expiring, missing and not-yet-valid metadata, excluding healthy credentials by default' {
        $rows = @(& "$repo/Get-EntraAppCredentialExpiry.ps1" -TenantId tenant -AsOf $asOf)
        $rows.Count | Should -Be 4
        $rows.Status | Should -Contain Expired
        $rows.Status | Should -Contain Expiring
        $rows.Status | Should -Contain MissingExpiry
        $rows.Status | Should -Contain NotYetValid
        Should -Invoke Get-MgApplication -Times 1 -ParameterFilter { $All -and 'passwordCredentials' -in $Property -and 'keyCredentials' -in $Property }
    }
    It 'never emits secret, hint or certificate-byte properties' {
        $rows = @(& "$repo/Get-EntraAppCredentialExpiry.ps1" -TenantId tenant -AsOf $asOf -IncludeAll)
        $rows.Count | Should -Be 5
        ($rows | ConvertTo-Json -Depth 5) | Should -Not -Match 'DO-NOT-EMIT|SecretText|Hint'
        $rows[0].PSObject.Properties.Name | Should -Not -Contain 'Key'
    }
    It 'rejects a wrong tenant before listing applications' {
        { & "$repo/Get-EntraAppCredentialExpiry.ps1" -TenantId wrong } | Should -Throw '*Connect-MgGraph*'
        Should -Invoke Get-MgApplication -Times 0
    }
}

Describe 'Mailbox forwarding' {
    BeforeEach {
        Mock Get-ConnectionInformation { [pscustomobject]@{State='Connected'} }
        Mock Get-AcceptedDomain { [pscustomobject]@{DomainName='example.test';MatchSubDomains=$false} }
        Mock Get-Mailbox { [pscustomobject]@{PrimarySmtpAddress='alice@example.test';ForwardingSmtpAddress='smtp:archive@outside.test';ForwardingAddress=$null;DeliverToMailboxAndForward=$true} }
        Mock Get-InboxRule {
            [pscustomobject]@{Name='Hidden redirect';Identity='rule1';Enabled=$false;RedirectTo=@('"External" [SMTP:redirect@outside.test]');ForwardTo=@();ForwardAsAttachmentTo=@()}
            [pscustomobject]@{Name='Internal';Identity='rule2';Enabled=$true;ForwardTo=@('bob@example.test')}
        }
        Mock Get-Recipient { [pscustomobject]@{PrimarySmtpAddress='bob@example.test';RecipientType='UserMailbox';ExternalEmailAddress=$null} }
    }
    It 'includes mailbox forwarding and disabled hidden rules, preserving their enabled state' {
        $rows = @(& "$repo/Get-O365MailboxForwarding.ps1")
        $rows.Count | Should -Be 3
        ($rows | Where-Object RuleName -eq 'Hidden redirect').RuleEnabled | Should -BeFalse
        ($rows | Where-Object RuleName -eq 'Hidden redirect').TargetAddress | Should -Be 'redirect@outside.test'
        Should -Invoke Get-InboxRule -Times 1 -ParameterFilter { $IncludeHidden -and $ResultSize -eq 'Unlimited' }
    }
    It 'filters internal destinations but keeps external ones' {
        $rows = @(& "$repo/Get-O365MailboxForwarding.ps1" -ExternalOnly)
        $rows.Count | Should -Be 2
        $rows.TargetScope | Should -Not -Contain InternalDomain
    }
    It 'resolves internal mail contacts to their external routing addresses' {
        Mock Get-Recipient { [pscustomobject]@{PrimarySmtpAddress='contact@example.test';RecipientType='MailContact';ExternalEmailAddress='SMTP:contact@outside.test'} }
        $rows = @(& "$repo/Get-O365MailboxForwarding.ps1" -ExternalOnly)
        $rows.Count | Should -Be 3
        ($rows | Where-Object RuleName -eq Internal).TargetAddress | Should -Be 'contact@outside.test'
    }
    It 'keeps groups as unresolved review targets rather than calling them safe' {
        Mock Get-Recipient { [pscustomobject]@{PrimarySmtpAddress='group@example.test';RecipientType='MailUniversalDistributionGroup'} }
        $rows = @(& "$repo/Get-O365MailboxForwarding.ps1" -ExternalOnly)
        ($rows | Where-Object RuleName -eq Internal).Resolution | Should -Be GroupNotExpanded
        ($rows | Where-Object RuleName -eq Internal).TargetScope | Should -Be Unknown
    }
    It 'stops on permission failures instead of silently dropping destinations' {
        Mock Get-Recipient { throw 'Access denied' }
        { & "$repo/Get-O365MailboxForwarding.ps1" } | Should -Throw '*Access denied*'
    }
}

Describe 'Azure exposure candidates' {
    BeforeEach {
        Mock Get-AzContext { [pscustomobject]@{Tenant=[pscustomobject]@{Id='tenant'};Name='original'} }
        Mock Get-AzSubscription { [pscustomobject]@{Id='sub';Name='Subscription'} }
        Mock Set-AzContext { [pscustomobject]@{Name='isolated'} }
        Mock Get-AzPublicIpAddress { [pscustomobject]@{Id='/public/ip';Name='public';IpAddress='203.0.113.10';IpConfiguration=[pscustomobject]@{Id='/nic/ipconfig'}} }
        Mock Get-AzNetworkSecurityGroup {
            [pscustomobject]@{
                Id='/nsg';Name='nsg';NetworkInterfaces=@();Subnets=@();DefaultSecurityRules=@()
                SecurityRules=@(
                    [pscustomobject]@{Name='BroadRange';Direction='Inbound';Access='Allow';Protocol='Tcp';Priority=100;SourceAddressPrefixes=@('::/0');DestinationPortRanges=@('3300-3400','5986');DestinationAddressPrefix='*'},
                    [pscustomobject]@{Name='PrivateSsh';Direction='Inbound';Access='Allow';Protocol='Tcp';Priority=110;SourceAddressPrefix='10.0.0.0/8';DestinationPortRange='22'},
                    [pscustomobject]@{Name='Deny';Direction='Inbound';Access='Deny';Protocol='Tcp';Priority=90;SourceAddressPrefix='*';DestinationPortRange='22'},
                    [pscustomobject]@{Name='Web';Direction='Inbound';Access='Allow';Protocol='Tcp';Priority=120;SourceAddressPrefix='Internet';DestinationPortRange='443'}
                )
            }
        }
    }
    It 'reports public IP inventory separately from broad IPv6/ranged management-rule candidates' {
        $rows = @(& "$repo/Get-AzurePublicExposure.ps1" -TenantId tenant -SubscriptionId sub)
        $rows.Count | Should -Be 2
        ($rows | Where-Object FindingType -eq PublicIpInventory).PublicIpAddress | Should -Be '203.0.113.10'
        $finding = $rows | Where-Object FindingType -eq PotentialManagementExposure
        $finding.MatchedManagementPorts | Should -Be '3389;5986'
        $finding.Assessment | Should -Be CandidateRuleNotEffectiveAccess
        Should -Invoke Set-AzContext -Times 1 -ParameterFilter { $Context.Name -eq 'original' }
    }
    It 'handles Internet source tags and wildcard protocols/ports' {
        Mock Get-AzNetworkSecurityGroup { [pscustomobject]@{Name='nsg';SecurityRules=@([pscustomobject]@{Name='All';Direction='Inbound';Access='Allow';Protocol='*';SourceAddressPrefix='Internet';DestinationPortRange='*'});DefaultSecurityRules=@()} }
        $rows = @(& "$repo/Get-AzurePublicExposure.ps1" -TenantId tenant -SubscriptionId sub)
        ($rows | Where-Object FindingType -eq PotentialManagementExposure).MatchedManagementPorts | Should -Be '22;3389;5985;5986'
    }
    It 'restores context when an Azure query fails' {
        Mock Get-AzPublicIpAddress { throw 'Subscription access failed' }
        { & "$repo/Get-AzurePublicExposure.ps1" -TenantId tenant -SubscriptionId sub } | Should -Throw '*Subscription access failed*'
        Should -Invoke Set-AzContext -Times 1 -ParameterFilter { $Context.Name -eq 'original' }
    }
    It 'refuses inaccessible subscriptions before changing context' {
        { & "$repo/Get-AzurePublicExposure.ps1" -TenantId tenant -SubscriptionId wrong } | Should -Throw '*not accessible*'
        Should -Invoke Set-AzContext -Times 0
    }
}

Describe 'Windows persistence snapshots' {
    BeforeEach {
        Mock Get-CimInstance { [pscustomobject]@{Name='FixtureSvc';PathName='C:\fixture.exe --service';StartName='SYSTEM';State='Running';StartMode='Auto'} }
        Mock Get-ScheduledTask { [pscustomobject]@{TaskName='FixtureTask';TaskPath='\';State='Disabled';Principal=[pscustomobject]@{UserId='SYSTEM'};Actions=@([pscustomobject]@{Execute='C:\task.exe';Arguments='--fixture'})} }
        Mock Get-ChildItem { @() }
        Mock Test-Path { $false }
        Mock Invoke-Command { & $ScriptBlock }
    }
    It 'collects service command lines and disabled task actions without executing them' {
        $rows = @(& "$repo/Get-WindowsPersistence.ps1" -ComputerName localhost)
        $rows.Count | Should -Be 2
        ($rows | Where-Object Type -eq Service).Command | Should -Be 'C:\fixture.exe --service'
        ($rows | Where-Object Type -eq ScheduledTask).State | Should -Be Disabled
        ($rows | Where-Object Type -eq ScheduledTask).Id | Should -Be 'Task:\FixtureTask:1'
        Should -Invoke Invoke-Command -Times 0
    }
    It 'sends a self-contained collector and credentials to the requested remote host' {
        $credential = [pscredential]::new('fixture-reader', [Security.SecureString]::new())
        $rows = @(& "$repo/Get-WindowsPersistence.ps1" -ComputerName $testComputer -Credential $credential)
        $rows.Count | Should -Be 2
        Should -Invoke Invoke-Command -Times 1 -ParameterFilter { $ComputerName -eq $testComputer -and $null -ne $Credential -and $ScriptBlock.ToString() -match 'Get-ScheduledTask' }
    }
    It 'includes loaded-user Run values and Startup files while excluding registry provider metadata' {
        $sid = 'S-1-5-21-1-2-3-1000'
        $runKey = "Registry::HKEY_USERS\$sid\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
        $startup = 'C:\Users\fixture\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup'
        Mock Get-ChildItem {
            if ($LiteralPath -eq 'Registry::HKEY_USERS') { [pscustomobject]@{PSChildName=$sid} }
            elseif ($LiteralPath -eq (Join-Path $env:SystemDrive Users)) { [pscustomobject]@{FullName='C:\Users\fixture'} }
            elseif ($LiteralPath -eq $startup) { [pscustomobject]@{Name='fixture.lnk';FullName="$startup\fixture.lnk"} }
        }
        Mock Test-Path { $LiteralPath -eq $runKey -or $LiteralPath -eq $startup }
        Mock Get-ItemProperty { [pscustomobject]@{PSPath='provider-metadata';FixtureRun='C:\autorun.exe --fixture'} }
        $rows = @(& "$repo/Get-WindowsPersistence.ps1" -ComputerName localhost)
        ($rows | Where-Object Type -eq RegistryAutorun).User | Should -Be $sid
        ($rows | Where-Object Type -eq RegistryAutorun).Command | Should -Be 'C:\autorun.exe --fixture'
        $rows.Name | Should -Not -Contain PSPath
        ($rows | Where-Object Type -eq StartupFile).Name | Should -Be fixture.lnk
    }
    It 'fails visibly if scheduled-task collection is denied' {
        Mock Get-ScheduledTask { throw 'Scheduled task access denied' }
        { & "$repo/Get-WindowsPersistence.ps1" -ComputerName localhost } | Should -Throw '*access denied*'
    }
}

Describe 'CSV security report comparisons' {
    BeforeEach {
        $beforePath = Join-Path $TestDrive 'before.csv'
        $afterPath = Join-Path $TestDrive 'after.csv'
    }
    It 'reports additions, removals and case-sensitive property changes' {
        @([pscustomobject]@{Id='a';Value='Enabled'},[pscustomobject]@{Id='removed';Value='X'}) | Export-Csv $beforePath -NoTypeInformation
        @([pscustomobject]@{Id='a';Value='enabled'},[pscustomobject]@{Id='added';Value='Y'}) | Export-Csv $afterPath -NoTypeInformation
        $rows = @(& "$repo/Compare-SecurityReports.ps1" -BeforePath $beforePath -AfterPath $afterPath -Key Id)
        $rows.Count | Should -Be 3
        $rows.ChangeType | Should -Contain Added
        $rows.ChangeType | Should -Contain Removed
        ($rows | Where-Object ChangeType -eq Changed).Before | Should -Be 'Enabled'
        ($rows | Where-Object ChangeType -eq Changed).After | Should -Be 'enabled'
    }
    It 'supports header-only input reports' {
        '"Id","Value"' | Set-Content $beforePath
        [pscustomobject]@{Id='a';Value='new'} | Export-Csv $afterPath -NoTypeInformation
        $rows = @(& "$repo/Compare-SecurityReports.ps1" -BeforePath $beforePath -AfterPath $afterPath -Key Id)
        $rows.Count | Should -Be 1
        $rows[0].ChangeType | Should -Be Added
    }
    It 'does not collide composite keys containing delimiter characters' {
        @([pscustomobject]@{A='a|b';B='c';Value='1'},[pscustomobject]@{A='a';B='b|c';Value='2'}) | Export-Csv $beforePath -NoTypeInformation
        Copy-Item $beforePath $afterPath
        @(& "$repo/Compare-SecurityReports.ps1" -BeforePath $beforePath -AfterPath $afterPath -Key A,B).Count | Should -Be 0
    }
    It 'rejects duplicate keys rather than overwriting earlier rows' {
        @([pscustomobject]@{Id='a';Value='1'},[pscustomobject]@{Id='a';Value='2'}) | Export-Csv $beforePath -NoTypeInformation
        Copy-Item $beforePath $afterPath
        { & "$repo/Compare-SecurityReports.ps1" -BeforePath $beforePath -AfterPath $afterPath -Key Id } | Should -Throw '*Duplicate key*'
    }
    It 'rejects blank keys' {
        [pscustomobject]@{Id='';Value='1'} | Export-Csv $beforePath -NoTypeInformation
        Copy-Item $beforePath $afterPath
        { & "$repo/Compare-SecurityReports.ps1" -BeforePath $beforePath -AfterPath $afterPath -Key Id } | Should -Throw '*Blank key*'
    }
    It 'rejects schema drift unless comparison properties are explicit' {
        [pscustomobject]@{Id='a';Value='1'} | Export-Csv $beforePath -NoTypeInformation
        [pscustomobject]@{Id='a';Value='1';Extra='x'} | Export-Csv $afterPath -NoTypeInformation
        { & "$repo/Compare-SecurityReports.ps1" -BeforePath $beforePath -AfterPath $afterPath -Key Id } | Should -Throw '*schemas differ*'
        @(& "$repo/Compare-SecurityReports.ps1" -BeforePath $beforePath -AfterPath $afterPath -Key Id -CompareProperty Value).Count | Should -Be 0
    }
    It 'prevents overwriting an input even with Force' {
        [pscustomobject]@{Id='a';Value='1'} | Export-Csv $beforePath -NoTypeInformation
        Copy-Item $beforePath $afterPath
        { & "$repo/Compare-SecurityReports.ps1" -BeforePath $beforePath -AfterPath $afterPath -Key Id -OutputPath $beforePath -Force } | Should -Throw '*cannot overwrite*'
    }
}

Describe 'Complete README catalog' {
    It 'links every runnable root script and every new audit script' {
        $readme = Get-Content "$repo/README.md" -Raw
        foreach ($scriptFile in Get-ChildItem $repo -Filter *.ps1 -File) {
            $readme | Should -Match ([regex]::Escape('](' + $scriptFile.Name + ')'))
        }
    }
    It 'keeps the catalog count and supporting-file links current' {
        $readme = Get-Content "$repo/README.md" -Raw
        $count = @(Get-ChildItem $repo -Filter *.ps1 -File).Count
        $readme | Should -Match "All $count runnable scripts"
        foreach ($support in @('Private/Common.ps1','tools/Test-Repository.ps1') + @(Get-ChildItem "$repo/tests" -Filter *.ps1 -File | ForEach-Object { 'tests/' + $_.Name })) {
            $readme | Should -Match ([regex]::Escape('](' + $support + ')'))
        }
    }
}
