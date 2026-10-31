# PowerShell SecOps scripts

A collection of scripts written and accumulated by John Skinner for Active
Directory, Azure, Microsoft Graph, Exchange Online and Windows administration.

## Start here

Download or clone the **whole repository**: scripts share `Private/Common.ps1`.
Run a script explicitly; do not run every file as a batch. Read its help first:

```powershell
Get-Help .\Copy_AD_UserGroups.ps1 -Full
.\Copy_AD_UserGroups.ps1 -SourceUser alice -TargetUser bob -Server dc.example.com -WhatIf
```

Windows PowerShell 5.1 and PowerShell 7 on Windows are validation targets. Install
only the administrative modules needed for your task; the scripts never install
modules automatically. ActiveDirectory requires RSAT/domain connectivity. Defender,
the date picker, credential validation and browser collection require Windows.
The date picker additionally requires an interactive STA session.

Authenticate to cloud services yourself before running reports. Verify the tenant,
subscription and account. Graph scripts require `-TenantId` and reject a different
connected tenant. Exchange policy changes require exactly one connected session.

```powershell
# Install from your organization's approved source and authenticate interactively.
Connect-MgGraph -TenantId 'YOUR-TENANT-ID' -Scopes 'Device.Read.All'
.\Export-GraphDevices.ps1 -TenantId 'YOUR-TENANT-ID' -OutputPath .\devices.csv
```

For unattended jobs use the service's supported certificate or managed-identity
flow with the documented permissions and roles. Do not embed passwords or tokens.
Scripts reuse the caller's session and do not disconnect it.

## Full script catalog

All 35 runnable scripts are listed below. See [security audit examples](docs/SecurityAudits.md) for the seven new reports and their limits.

| Area / script | Purpose | Prerequisites / access | Changes systems? |
|---|---|---|---|
| [Export-ADGroupMembers.ps1](Export-ADGroupMembers.ps1) | Direct/recursive members, including object type | ActiveDirectory; directory read | No |
| [Export-ADGroupMemberCreationDates.ps1](Export-ADGroupMemberCreationDates.ps1) | Creation dates of user members | ActiveDirectory; directory read | No |
| [GrabAD-GroupMembers.ps1](GrabAD-GroupMembers.ps1) | Compatibility entry point for group report | Same as group report | No |
| [Get-ADUserEnabledStatus.ps1](Get-ADUserEnabledStatus.ps1) | Enabled/disabled status from an identity list | ActiveDirectory; directory read | No |
| [Get-ADPasswordNeverExpires.ps1](Get-ADPasswordNeverExpires.ps1) | Non-expiring password configuration | ActiveDirectory; directory read | No |
| [Get-ADExpiredAccounts.ps1](Get-ADExpiredAccounts.ps1) | Enabled expired accounts; optional no-expiration report | ActiveDirectory; directory read | No |
| [Get-ADMissingPhoneNumbers.ps1](Get-ADMissingPhoneNumbers.ps1) | Enabled users missing all phone fields | ActiveDirectory; directory read | No |
| [Get-ADRecentlyCreatedUsers.ps1](Get-ADRecentlyCreatedUsers.ps1) | Recently created users | ActiveDirectory; directory read | No |
| [Get-ADUserCreationAudit.ps1](Get-ADUserCreationAudit.ps1) | Match creator evidence in DC event 4720 by target SID | AD read; DC Security-log read; retained account-management auditing | No |
| [Get-ADUserLoginData.ps1](Get-ADUserLoginData.ps1) | Password/logon metadata | ActiveDirectory; directory read | No |
| [Copy_AD_UserGroups.ps1](Copy_AD_UserGroups.ps1) | Copy reviewed direct memberships | ActiveDirectory; delegated group management | **Yes** |
| [verify-credentials.ps1](verify-credentials.ps1) | Validate one credential against a domain | DirectoryServices; domain connectivity | Authentication attempt; can affect lockout counters |
| [ExportNSG_All_BySubscription.ps1](ExportNSG_All_BySubscription.ps1) | NSG rule audit with subscription identity and plural fields | Az.Accounts, Az.Network; Reader in selected subscriptions | Session context temporarily switched and restored |
| [Export-GraphDevices.ps1](Export-GraphDevices.ps1) | Directory-device report with optional filters | Graph Authentication + Identity.DirectoryManagement; Device.Read.All | No |
| [Get-GraphDeviceCompliance.ps1](Get-GraphDeviceCompliance.ps1) | Directory compliance flags | Same as device report | No |
| [Find-GraphDevice.ps1](Find-GraphDevice.ps1) | Device display-name prefix search | Same as device report | No |
| [Get-GraphWindowsDevices.ps1](Get-GraphWindowsDevices.ps1) | Windows directory devices | Same as device report | No |
| [GraphAPI-GuestUserStatus.ps1](GraphAPI-GuestUserStatus.ps1) | Latest available interactive guest sign-in | Graph Users + Reports; User.Read.All, AuditLog.Read.All; supported role/license | No |
| [Set-GraphDeviceExtensionAttribute.ps1](Set-GraphDeviceExtensionAttribute.ps1) | Set one selected attribute, then read it back | Graph device update/read; see permission notes below | **Yes** |
| [Export-O365MailboxHolds.ps1](Export-O365MailboxHolds.ps1) | Mailbox hold flags and retention-processing pauses | ExchangeOnlineManagement; mailbox-read RBAC | No |
| [Export-O365BlockedSendersAndDomains.ps1](Export-O365BlockedSendersAndDomains.ps1) | Selected anti-spam policy's blocked entries | ExchangeOnlineManagement; policy-read RBAC | No |
| [BlockLegacyAuthentication.ps1](BlockLegacyAuthentication.ps1) | Apply a blocking policy or restore saved assignments | ExchangeOnlineManagement; policy/user-management RBAC | **Yes** |
| [DefenderToolkit.ps1](DefenderToolkit.ps1) | Explicit Defender status, scans and configuration actions | Defender module; elevation for changes | **Yes**, except Status/Preferences/Detections |
| [Get-BrowserHistory.ps1](Get-BrowserHistory.ps1) | Chrome/Edge/Firefox SQLite history with UTC timestamps | Windows; sqlite3 >= 3.33 on targets; profile-read rights; WinRM for remote collection | Temporary snapshot/job files only |
| [Get-ComputerInfo.ps1](Get-ComputerInfo.ps1) | OS, logged-on user and hotfix inventory | CIM/WinRM; target permissions | Temporary CIM session only |
| [Get-RemoteSerialNumber.ps1](Get-RemoteSerialNumber.ps1) | BIOS/serial inventory | CIM/WinRM; target permissions | Temporary CIM session only |
| [Get-WindowsEvents.ps1](Get-WindowsEvents.ps1) | Selected log and time range | Windows Event Log remote access; log-read rights | No |
| [Date_Selector.ps1](Date_Selector.ps1) | Return selected date or no value on cancel | Interactive Windows desktop; STA | No |
| [Get-ADPrivilegedGroupMembers.ps1](Get-ADPrivilegedGroupMembers.ps1) | Privileged-group membership paths with cycle/depth reporting | ActiveDirectory; directory read in selected domain | No |
| [Get-ADStaleAccounts.ps1](Get-ADStaleAccounts.ps1) | User/computer inactivity candidates with explicit evidence | ActiveDirectory; directory read; optional credentials/OU scope | No |
| [Get-EntraAppCredentialExpiry.ps1](Get-EntraAppCredentialExpiry.ps1) | Secret/certificate expiry metadata, without credential values | Graph Applications; Application.Read.All and supported role | No |
| [Get-O365MailboxForwarding.ps1](Get-O365MailboxForwarding.ps1) | Mailbox and hidden inbox-rule forwarding destinations | ExchangeOnlineManagement; mailbox/inbox-rule/recipient/accepted-domain RBAC | No |
| [Get-AzurePublicExposure.ps1](Get-AzurePublicExposure.ps1) | Public-IP inventory and broad management-port NSG candidates | Az.Accounts, Az.Network; Reader in selected subscriptions | Session context temporarily switched and restored |
| [Get-WindowsPersistence.ps1](Get-WindowsPersistence.ps1) | Services, task actions, Run/RunOnce values and Startup files | Windows CIM/ScheduledTasks/registry/filesystem read; WinRM for remote | No |
| [Compare-SecurityReports.ps1](Compare-SecurityReports.ps1) | Added, removed and changed CSV entries using explicit unique keys | Local CSV files; no service modules | No |

Azure Firewall commands are now [reference examples](docs/AzureFirewallExamples.md),
not an executable sequence of placeholder changes.

### Supporting scripts

These support the runnable scripts and validation; do not run the test files as administration tools.

| File | Purpose |
|---|---|
| [Private/Common.ps1](Private/Common.ps1) | Shared CSV export, identity-list and Graph context helpers |
| [tools/Test-Repository.ps1](tools/Test-Repository.ps1) | Parse, analyze and run the complete regression suite |
| [tests/Toolkit.Tests.ps1](tests/Toolkit.Tests.ps1) | Existing administrative safety and reporting regressions |
| [tests/BrowserHistory.Tests.ps1](tests/BrowserHistory.Tests.ps1) | Synthetic SQLite/browser collection tests |
| [tests/SecurityAudits.Tests.ps1](tests/SecurityAudits.Tests.ps1) | New audit reports, report comparisons and catalog coverage |

## Change safety and recovery

Mutating scripts support `-WhatIf` and high-impact confirmation. Preview first.
`-Confirm:$false` deliberately bypasses prompts; use it only after reviewing targets.
Protected AD groups are skipped unless explicitly included. This check does not
identify every custom or nested privilege path; use `-GroupIdentity` to allow only
reviewed source groups. Primary-group membership is not copied. A failed operation
stops the script; previous successful operations are not automatically rolled back.
Record returned `Added` rows if you need to reverse a membership change.

Exchange policy apply and restore are separate invocations:

```powershell
.\BlockLegacyAuthentication.ps1 -Mode Apply -UserListPath .\users.txt -BackupPath .\before.csv -WhatIf
# Apply without -WhatIf only after reviewing its targets. Keep the backup secure.
.\BlockLegacyAuthentication.ps1 -Mode Restore -RestoreSavedAssignments -BackupPath .\before.csv -WhatIf
```

Apply refuses to overwrite an existing backup and validates an existing policy's
Basic-authentication flags. Backups include organization identity; restore refuses a
wrong organization. Restore affects every user in the supplied backup. Review
partial failures before restoring. Restoring user assignments does not delete the
created policy or undo other administrators' later changes. Authentication changes
can take time to propagate; this does not validate a client's actual sign-in path.

Defender protection reductions require `-AllowProtectionReduction` plus
confirmation. The old passive-mode registry action was removed because OS,
onboarding and tamper-protection requirements make a generic registry toggle
unsafe. Use [Microsoft's supported configuration](https://learn.microsoft.com/en-us/defender-endpoint/microsoft-defender-antivirus-windows-server-configure).
Remove an exclusion with `-Action RemoveExclusion -Path ...`; restore real-time
monitoring with `-Action EnableRealtime`. Managed policy can reject local changes.

Device extension updates require an explicit object ID, attribute number, value
and tenant. Output includes the previous value; retain it securely for recovery.
Delegated Graph device updates currently require `Directory.AccessAsUser.All` and a
supported role, while application updates use `Device.ReadWrite.All`; read-back
also needs read access. Do not substitute a guessed narrower delegated scope.
See the [API's OS and permission restrictions](https://learn.microsoft.com/en-us/graph/api/device-update?view=graph-rest-1.0).

## Report handling and limitations

Reports return objects; use `-OutputPath` where supported for UTF-8 CSV. The output
directory must exist. Existing reports require `-Force`; runs never append to old
results. An empty result warns and writes no file. Reports are audit data, not
restorable configuration backups. A directory, permission or service failure is
reported as an error rather than silently treated as "no users" or "no activity".

- Treat report contents as untrusted text when importing into a spreadsheet;
  source values may begin with formula characters. CSV output preserves evidence.
- Protect reports, backups and browser URLs with appropriate filesystem access
  and retention. Do not commit them; common report/database formats are ignored.
- No retained sign-in or event record does not prove an account was never used or
  has no creator. Specify all relevant DCs/collectors for creation audits.
- AD `LastLogonDate` is replicated and approximate. Stale-account results are
  candidates for investigation; absence of a replicated timestamp is not proof
  that an account has never been used.
- Privileged-group reports default to `adminCount=1` groups in the selected domain.
  Include custom groups explicitly; primary groups, ACL delegation and unresolved
  foreign group expansion are outside this report's coverage.
- Application expiry reports cover app registrations, not enterprise application
  service-principal credentials. Output contains credential metadata only.
- Forwarding reports describe configuration, including disabled rules. Accepted
  domains classify addresses; groups/unresolved targets remain `Unknown`. Delivery
  policies, transitive forwarding and group expansion are not evaluated.
- Azure public-exposure findings are potential configured-rule exposure, not proof
  that a host is reachable. IP inventory and NSG findings are independent.
- Windows persistence snapshots are evidence, not malware verdicts. Unloaded user
  registry hives, WMI subscriptions and shortcut targets are not inspected.
- CSV comparisons require explicit unique, nonblank keys. Values are compared as
  case-sensitive strings; use `-CompareProperty` to omit volatile timestamps.
- Graph `IsCompliant` is nullable directory metadata, not full Intune compliance.
- Mailbox `RetentionHoldEnabled` pauses MRM; it is not a preservation hold. The
  mailbox report does not resolve organization-wide retention/eDiscovery coverage.
- Browser collection uses read-only SQLite backups including WAL data. It does
  not close browsers. Locked/inaccessible/corrupt databases fail visibly. It does
  not recover deleted records or collect legacy IE TypedURLs.
- `-AsJob` returns job objects. Retrieve results and errors with
  `Receive-Job -Wait -AutoRemoveJob`. Remote hosts need sqlite3 installed themselves.

## Security reporting and licensing

Report vulnerabilities through the private route described in [SECURITY.md](SECURITY.md).
Do not disclose vulnerability details or private exports in public issues. The
GitHub reporting feature must be enabled separately by the repository owner;
[maintainer setup](docs/Maintenance.md) explains how to verify it.

The root [LICENSE](LICENSE) remains the Unlicense. Consult
[third-party provenance and notices](THIRD_PARTY.md) and [preserved license texts](LICENSES/)
for identified upstream material. The historical O365Reports permission question
is still open; the review does not claim all historical code has been cleared.

## Validation and contribution

Use Pester **5.7.1**, PSScriptAnalyzer **1.24.0**, and sqlite3 **>=3.33** on Windows.
Install dependencies from your approved source, then run:

```powershell
.\tools\Test-Repository.ps1
```

GitHub Actions runs parsing, default analyzer error/warning checks, mock-based
regressions and synthetic SQLite integration tests in Windows PowerShell and pwsh.
It has read-only repository permissions and no production credentials. SQLite and
Actions dependencies are pinned; Dependabot proposes Actions updates. Module and
SQLite version/hash updates require deliberate review.

Offline validation cannot certify tenant roles, policy propagation, remoting,
Defender policy or every browser version. Validate those in a non-production
environment before operational use. See [migration notes](docs/Migration.md),
[contribution guidance](CONTRIBUTING.md), and [third-party provenance](THIRD_PARTY.md).
