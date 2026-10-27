# Security audit reports

All seven additions are read-only. They return structured objects and accept
`-OutputPath` and `-Force` under the repository's existing CSV handling rules.
Authenticate explicitly before running cloud reports. No script requests new
permissions, installs software, disables accounts or changes service configuration.
Read `Get-Help .\SCRIPT.ps1 -Full` for parameters and limits.

## Privileged AD group members

```powershell
.\Get-ADPrivilegedGroupMembers.ps1 -Server dc.example.com -OutputPath .\privileged.csv
.\Get-ADPrivilegedGroupMembers.ps1 -Server dc.example.com -GroupIdentity 'Domain Admins','Custom Helpdesk' -MaxDepth 20
```

Defaults to groups marked `adminCount=1` in the selected domain. That attribute
can include previously protected groups and does not identify all custom privilege
paths. Select additional groups explicitly. Each membership path is preserved;
`Cycle`, `DepthLimit` and `ForeignPrincipalNotExpanded` identify incomplete paths.
Primary-group membership and ACL-based rights are not included. Repeat the query
for relevant domains with a suitable server. Requires directory-read access.
Both friendly-name and distinguished-name paths are included so groups with the
same display name in different OUs remain distinguishable.

## Stale AD accounts

```powershell
.\Get-ADStaleAccounts.ps1 -Server dc.example.com -InactiveDays 90 -OutputPath .\stale.csv
.\Get-ADStaleAccounts.ps1 -Server dc.example.com -AccountType Computer -IncludeDisabled -SearchBase 'OU=Servers,DC=example,DC=com'
```

Reports enabled users and computers by default. Replicated `LastLogonDate` can lag
activity; the report is not evidence for automatic deletion. Missing logon dates
use creation age and a separate evidence label. Newly created accounts without
logon data are excluded until old enough. Missing both timestamps yields an
`InsufficientTimestamps` row with a null inactivity flag. `PasswordLastSet` provides
an extra signal for review; service accounts may have other activity sources.
`-AsOf` allows a repeatable comparison cutoff. Optional credentials are passed to
all selected AD queries.

## Entra application credential expiry

```powershell
Connect-MgGraph -TenantId 'YOUR-TENANT-ID' -Scopes 'Application.Read.All'
.\Get-EntraAppCredentialExpiry.ps1 -TenantId 'YOUR-TENANT-ID' -WithinDays 30 -OutputPath .\expiry.csv
```

Requires `Microsoft.Graph.Applications`, `Application.Read.All` and a supported
role for delegated access. Explicitly selects application registration credential
metadata and follows all pages. Statuses are `Expired`, `Expiring`, `MissingExpiry`,
`NotYetValid` and (with `-IncludeAll`) `Valid`. Applications with no credentials
produce no credential rows. Does not output secret text, hints, key bytes, or full
credential objects, and does not inspect service-principal credentials. Credential
IDs, app names and expiration dates still warrant appropriate report access.

## Microsoft 365 mailbox forwarding

```powershell
Connect-ExchangeOnline
.\Get-O365MailboxForwarding.ps1 -ExternalOnly -OutputPath .\forwarding.csv
.\Get-O365MailboxForwarding.ps1 -MailboxIdentity alice@example.com
```

Requires exactly one connected Exchange Online session with RBAC for mailbox,
inbox-rule, recipient and accepted-domain reads. `Get-InboxRule` does not support
View-Only Organization Management or Entra Global Reader; assign a role that
actually permits these reads rather than assuming that any read role suffices.
Default mailbox scope is user/shared mailboxes; explicit identities can select
others. Includes hidden and disabled rules and reports their configured state.

Resolves internal mail contacts to external routing addresses. Accepted domains
classify addresses only: they do not establish delivery safety. Distribution
groups and missing/ambiguous recipients are `Unknown`; `-ExternalOnly` retains them
for investigation. Unexpected permission/service failures stop collection. Does
not expand distribution groups, follow chained forwarding, or determine whether
outbound spam policies, transport rules or competing forwarding settings permit
actual delivery. No mailbox rules are modified.

## Azure public exposure

```powershell
Connect-AzAccount -Tenant 'YOUR-TENANT-ID'
.\Get-AzurePublicExposure.ps1 -TenantId 'YOUR-TENANT-ID' -SubscriptionId 'YOUR-SUBSCRIPTION-ID' -OutputPath .\exposure.csv
```

Requires Az.Accounts/Az.Network and Reader access. `PublicIpInventory` includes
assigned and unassigned public IP resources. `PotentialManagementExposure` flags
inbound allow rules with broad sources (`*`, `Internet`, `0.0.0.0/0`, `::/0`) and
TCP/UDP/wildcard rules matching default management ports 22, 3389, 5985 or 5986.
Customize with `-ManagementPort`. Handles plural ranges and IPv6 any-source rules.
Associated resource IDs and destination ASGs are included when available.

Public IPs and NSG candidates are separate observations, not a correlation or
reachability test. Deny precedence, effective NIC/subnet rules, guest firewalls,
routes, listeners, JIT and NAT are not evaluated. A candidate can be unattached or
blocked elsewhere; a service can also be exposed through mechanisms this report
does not inventory. Collection temporarily switches the process Azure context and
restores it in `finally`, including failures. No network probes are sent.

## Windows persistence inventory

```powershell
.\Get-WindowsPersistence.ps1 -OutputPath .\persistence-before.csv
.\Get-WindowsPersistence.ps1 -ComputerName server.example.com -Credential (Get-Credential) -OutputPath .\persistence-remote.csv
```

Requires Windows and read access to CIM services, ScheduledTasks, the registry and
Startup directories; remote runs need WinRM. Enumerates services, every task action,
machine 64/32-bit Run/RunOnce values, equivalent values in loaded user hives, and
common/per-profile Startup files. Captures disabled tasks too. Does not execute
configured command lines, resolve shortcuts, load hives, enable tasks, or modify
services. WMI subscriptions, browser extensions and other persistence mechanisms
are outside scope. Any unreadable selected source produces an error; do not treat
an error as a clean host. Command lines can contain sensitive data.

## Compare report snapshots

```powershell
.\Compare-SecurityReports.ps1 -BeforePath .\persistence-before.csv -AfterPath .\persistence-after.csv -Key ComputerName,Id -OutputPath .\changes.csv
.\Compare-SecurityReports.ps1 -BeforePath .\old-devices.csv -AfterPath .\new-devices.csv -Key id -CompareProperty displayName,accountEnabled
```

Choose stable keys unique within each report. Composite keys are encoded so values
containing punctuation cannot collide. Duplicate or blank keys cause an error.
Default comparison requires matching schemas and compares every non-key column.
With `-CompareProperty`, explicitly select shared fields to tolerate schema changes
or omit volatile timestamps. Values and keys are case-sensitive CSV strings, not
locale-dependent date/number interpretations; null and empty CSV fields are
indistinguishable. Header-only files support empty snapshots; files without headers
do not. Reports with no findings normally write no CSV under the shared export
rules, so provide a header-only snapshot if you need to compare an empty result.

`Changed` rows identify individual properties and their previous/current values.
`Added` and `Removed` rows store the entire respective CSV record as JSON. Identical
reports return no rows. Neither input can be overwritten through `-OutputPath`,
even when `-Force` is supplied. File content changes to a Startup shortcut are not
visible in persistence comparisons unless its reported metadata changes.

## Source references

- [Graph: list applications and permissions](https://learn.microsoft.com/en-us/graph/api/application-list?view=graph-rest-1.0)
- [Exchange: Get-InboxRule, hidden rules and role limitations](https://learn.microsoft.com/en-us/powershell/module/exchangepowershell/get-inboxrule?view=exchange-ps)
- [Exchange: Get-Recipient](https://learn.microsoft.com/en-us/powershell/module/exchangepowershell/get-recipient?view=exchange-ps)
- [Azure: NSG priority, address, protocol and port semantics](https://learn.microsoft.com/en-us/azure/virtual-network/network-security-groups-overview)
- [Microsoft: replicated logon timestamp limitations](https://devblogs.microsoft.com/scripting/dandelions-vcr-clocks-and-last-logon-times-these-are-a-few-of-our-least-favorite-things/)
