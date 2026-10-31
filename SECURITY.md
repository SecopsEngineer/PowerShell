# Security policy

## Reporting a vulnerability

Use GitHub private vulnerability reporting for this repository. Sign in, open
[Security -> Advisories](https://github.com/SecopsEngineer/PowerShell/security/advisories)
and select **Report a vulnerability** when that button is available. The form
sends a private report to the repository maintainers; submitting this file does
not itself enable the GitHub reporting feature.

If the button is unavailable, do not put vulnerability details in an issue,
discussion, pull request, or commit. You may open a public issue titled
**Private reporting channel unavailable** containing only a request for the
maintainer to enable private reporting. Do not include affected script names,
impact, reproduction steps, exploit code, screenshots, or attachments in that
public request. Wait for a private reporting channel before sharing details.
No security email address is published by this policy.

In the private report, include:

- Affected script and commit SHA, and whether the issue reproduces on `main`.
- PowerShell, operating system and relevant module versions.
- Expected behavior, observed behavior and security impact.
- Minimal reproduction steps using synthetic accounts, tenant names and data.
- A proposed fix or workaround, if known.

Do not attach real passwords, tokens, private keys, unredacted report exports,
browser histories or personal data. Redact sensitive command-line arguments and
identifiers. Test only in environments you own or are authorized to assess.

## Maintained versions

Security fixes target the latest `main` branch. Older commits, copied scripts,
forks and any future release branches are not automatically maintained or
backported. Include the exact commit in reports so maintainers can identify the
affected code. A passing test suite is not certification of a live environment.

## Scope and handling

Report vulnerabilities in this repository's scripts or documentation, including
unintended administrative changes, credential disclosure and unsafe handling of
untrusted input. Ordinary functional bugs with no security impact can use the
public bug-report template, with synthetic and redacted examples.

Maintainers will assess reports and discuss mitigation and disclosure through
the private report. Response and remediation are best effort; this project does
not publish a service-level commitment or bug-bounty promise. Coordinate any
public disclosure with the maintainer rather than publishing a working exploit
in a public issue while a report is being assessed.

## For the repository owner

Enable **Private vulnerability reporting** under **Settings -> Advanced Security**
and confirm that **Report a vulnerability** appears on the Advisories page.
Keep security-alert notifications enabled for your account. See the
[maintenance guide](docs/Maintenance.md) for setup verification and the remaining
provenance work before a release.
