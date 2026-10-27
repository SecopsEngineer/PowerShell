# Migration notes

The safety update changes command-line interfaces. Read `Get-Help SCRIPT -Full`
before using an existing scheduled task. Prompts and hardcoded values have been
replaced with explicit parameters. The complete checkout is required for helpers.

| Previous path | Current path |
|---|---|
| `!CODE_OF_CONDUCT.md` | `CODE_OF_CONDUCT.md` |
| `!LICENSE` | `LICENSE` |
| `!README.md` | `README.md` |
| `AD Group Member Extractor` | `Export-ADGroupMembers.ps1` |
| `AD GroupMember_AccountCreationDate` | `Export-ADGroupMemberCreationDates.ps1` |
| `AD-PasswordNeverExpires` | `Get-ADPasswordNeverExpires.ps1` |
| `ADEnable-DisabledUsers-fromList` | `Get-ADUserEnabledStatus.ps1` |
| `ADUsers - Last 30 days` | `Get-ADRecentlyCreatedUsers.ps1` |
| `ADUserSearch - ForCreator` | `Get-ADUserCreationAudit.ps1` |
| `AzureAD-GraphAPI ExtensionAttributeUpdate` | `Set-GraphDeviceExtensionAttribute.ps1` |
| `DefenderToolkit` | `DefenderToolkit.ps1` |
| `Export-0365 Blocked Senders and Domains` | `Export-O365BlockedSendersAndDomains.ps1` |
| `Get-ADExpired_Accounts` | `Get-ADExpiredAccounts.ps1` |
| `Get-ADMissingPhoneNumbers` | `Get-ADMissingPhoneNumbers.ps1` |
| `GrabAD-UserLoginData` | `Get-ADUserLoginData.ps1` |
| `MSGraph API Get all Devices` | `Export-GraphDevices.ps1` |
| `MSGraph API Get All Devices & Compliant` | `Get-GraphDeviceCompliance.ps1` |
| `MSGraph API Search for Device` | `Find-GraphDevice.ps1` |
| `MSGraphAPI Get all devices with various info` | `Get-GraphWindowsDevices.ps1` |
| `O365 Holds Enabled Mailboxes` | `Export-O365MailboxHolds.ps1` |
| `AzureFirewallCommands.ps1` | `docs/AzureFirewallExamples.md` (reference only) |

Behavior changes:

- The enabled-status report never enables accounts.
- Expired-account reporting now filters expiration dates; use `-WithoutExpiration` for the no-expiration report described by the old help.
- Creator reporting uses Security event 4720 evidence rather than a nonexistent generic CreatedBy property.
- Graph device search now accepts a display-name prefix, and Windows filtering uses an OS filter.
- Reports no longer append to old CSVs. Use a fresh path or explicit `-Force`.
- Exchange apply never automatically restores policy assignments. Restore requires its own invocation and the saved backup.
- Defender uses explicit actions instead of an interactive menu. Passive-mode registry editing was removed.
- Browser search terms are literal substrings; user selection is a wildcard pattern. SQLite is required on each target.
- The mailbox hold report accepts `-HoldType` instead of three overlapping switches; it no longer accepts usernames or plaintext passwords.
- The date picker returns a DateTime rather than setting a caller variable.

Original author credit and the pre-update files remain available in Git history.
