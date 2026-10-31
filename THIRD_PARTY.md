# Third-party provenance and notices

Reviewed on **2026-10-30**, against repository `main` at
[`fd33296`](https://github.com/SecopsEngineer/PowerShell/commit/fd33296).
The repository's [LICENSE](LICENSE) remains the Unlicense. It does not erase
upstream authorship, replace third-party notices, or establish rights in code
owned by someone else. The existing license text has not been changed.

## Review scope and findings

The review scanned all 35 runnable root PowerShell scripts and repository
documentation for credits/source links, inspected Git history, and compared
identified historical sources with upstream examples. It was a focused provenance
review, not an exhaustive determination of every contributor's rights. A source
match is evidence of related code, not proof of an entire chain of ownership.

| Material | Evidence | Action / status |
|---|---|---|
| Historical `GraphAPI-GuestUserStatus.ps1` | Same original report filename and substantial matching report/Graph flow in Tony Redmond's Office365itpros sample; upstream publishes MIT terms | Restore historical-source credit in the current replacement; preserve the upstream MIT copyright/permission notice |
| Historical `Get-BrowserHistory.ps1` | Matching function, help, helper names and collection/remoting implementation in Oregon National Guard's script | Restore historical-source credit; preserve its complete published notice, including the stated exception for specific scripts |
| Historical `O365 Holds Enabled Mailboxes` | Original file explicitly credits O365Reports Team and matches the upstream mailbox report | Source confirmed; an applicable redistribution grant remains unverified in the inspected files |
| `CODE_OF_CONDUCT.md` | Contributor Covenant v2.0 adaptation, adopted in 2021; historical upstream license is CC BY 4.0 | Retain version/source and Mozilla credit; add license link and identify local enforcement-contact modification |
| Other repository-authored/accumulated material | Repository history and existing credits | Preserve attribution; no additional upstream ownership conclusions made |

## Office365itpros guest-sign-in report

- Local historical source: [GraphAPI-GuestUserStatus.ps1 at 3f9d705](https://github.com/SecopsEngineer/PowerShell/blob/3f9d705/GraphAPI-GuestUserStatus.ps1).
- Matching upstream: [ReportLastAccountSignIn-Mg.PS1 at ed927ed](https://github.com/12Knocksinna/Office365itpros/blob/ed927ed0120b5ca5f47e506c145be81954c5cdd8/ReportLastAccountSignIn-Mg.PS1).
- Upstream notice: [MIT license at the same revision](https://github.com/12Knocksinna/Office365itpros/blob/ed927ed0120b5ca5f47e506c145be81954c5cdd8/LICENSE), copyright (c) 2023 Tony Redmond.
- Preserved text: [LICENSES/Office365itpros-MIT.txt](LICENSES/Office365itpros-MIT.txt).

The current report was rewritten in the safety update. Historical source credit
and the MIT notice are retained conservatively rather than claiming that the
repository's Unlicense replaces upstream terms. Include the relevant notice when
redistributing related material.

## Oregon National Guard browser-history script

- Local historical source: [Get-BrowserHistory.ps1 at 7cdf449](https://github.com/SecopsEngineer/PowerShell/blob/7cdf449/Get-BrowserHistory.ps1).
- Matching upstream: [Get-BrowserHistory.ps1 at 4c75ca9](https://github.com/oregon-national-guard/powershell/blob/4c75ca914ba57b5e8b5ed6429fc91df7f26786fa/Get-BrowserHistory.ps1).
- Upstream author credit: `@oregon-national-guard/cyberspace-operations`.
- Upstream notice: [LICENCE at the same revision](https://github.com/oregon-national-guard/powershell/blob/4c75ca914ba57b5e8b5ed6429fc91df7f26786fa/LICENCE).
- Preserved text: [LICENSES/Oregon-National-Guard-LICENCE.txt](LICENSES/Oregon-National-Guard-LICENCE.txt).

The published notice states a US-government-work/CC0 basis and also says portions
of specific scripts are under Microsoft Limited Public License. That exception is
preserved; this review does not resolve the terms of every reference or component
listed by the historical script. The current SQLite-based collector replaced the
old regex/database-text implementation; credit here describes historical source,
not an endorsement by the upstream authors of this repository's replacement.

## O365Reports mailbox-hold script: unresolved permission

- Local historical source: [O365 Holds Enabled Mailboxes at 0bd3369](https://github.com/SecopsEngineer/PowerShell/blob/0bd3369/O365%20Holds%20Enabled%20Mailboxes).
- Original credit: **O365Reports Team**.
- Original article: [Export Office 365 Mailbox Hold Report Using PowerShell](https://o365reports.com/2021/06/29/export-office-365-mailbox-holds-report-using-powershell/).
- Matching upstream script: [MailboxHoldReport.ps1 at a0770ed](https://github.com/admindroid-community/powershell-scripts/blob/a0770ed26804f912653004ca9e7edcf9b10d35a1/Export%20Mailbox%20Hold%20Details/MailboxHoldReport.ps1).
- Inspected companion [README at the same revision](https://github.com/admindroid-community/powershell-scripts/blob/a0770ed26804f912653004ca9e7edcf9b10d35a1/Export%20Mailbox%20Hold%20Details/README.md) and repository root listing.

No explicit redistribution grant was found in that bounded inspection. This does
not prove that no permission exists. The maintainer must locate the applicable
terms or obtain written permission before claiming the historical code is cleared
for redistribution. Do not infer a grant from public visibility or free download.
The current `Export-O365MailboxHolds.ps1` is a replacement with the original credit
retained; historical copies remain in Git. No upstream contact, permission grant,
history rewrite, or retroactive relicensing is asserted by this review.

## Contributor Covenant v2.0

[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) is adapted from
[Contributor Covenant v2.0](https://www.contributor-covenant.org/version/2/0/code_of_conduct.html).
The [historical upstream license](https://github.com/EthicalSource/contributor_covenant/blob/519ee05a2a6c888129d5318db60893a8238f5c96/LICENSE.md)
that predates its adoption here is **Creative Commons Attribution 4.0
International**; see [the license text](https://creativecommons.org/licenses/by/4.0/legalcode).
The adaptation replaces the generic enforcement-contact placeholder with this
repository's maintainer contact guidance. Preserve the existing Contributor
Covenant and Mozilla enforcement-ladder attribution. Do not apply a newer
upstream website/software license to this older document without checking scope.

## External dependencies and references

Pester, PSScriptAnalyzer, SQLite, GitHub Actions and the administrative PowerShell
modules are external dependencies under their respective terms. Downloaded
binaries and administrative modules are not vendored in this checkout. Workflow
pins and hashes identify validation dependencies; they do not replace upstream
license terms. Links to Microsoft/API documentation are source references, not
claims that this repository owns the referenced documentation or services.

## Adding or redistributing material

For a third-party addition, record the original source, immutable revision,
author/rights-holder notice, applicable license or permission, local changes and
required accompanying notices. Add evidence here and preserve required text in
`LICENSES/` where appropriate. If the terms are unclear, resolve them before
copying the material. Do not label material public domain merely because the
repository root uses the Unlicense. See [maintenance follow-ups](docs/Maintenance.md).
