# Maintainer setup and release readiness

## Enable the private reporting channel

`SECURITY.md` documents GitHub private vulnerability reporting. Adding a policy
or merging a pull request does not enable the feature.

1. Sign in as the repository owner and open
   [repository security settings](https://github.com/SecopsEngineer/PowerShell/settings/security_analysis).
2. In **Advanced Security**, find **Private vulnerability reporting** and select
   **Enable**. If the settings layout differs, follow
   [GitHub's current instructions](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/configure-vulnerability-reporting/configure-for-a-repository).
3. Open [Security -> Advisories](https://github.com/SecopsEngineer/PowerShell/security/advisories)
   and confirm that **Report a vulnerability** is offered to a signed-in reporter.
   Do not submit a real or test vulnerability simply to check the button.
4. Check your repository security-alert and account notification preferences.

The connected GitHub integration used for the documentation work does not have
repository-administration access. Feature enablement must be performed by an
authenticated owner/admin, then verified in GitHub. Do not label it enabled based
only on the presence of this document. The policy provides a details-free public
fallback if the private button is missing.

## Outstanding source-permission question

The old `O365 Holds Enabled Mailboxes` file credited O365Reports Team. Matching
upstream code was located, but no explicit redistribution grant was found in the
inspected script, directory README or root file listing. This is a bounded
review finding, not a determination that permission does or does not exist.

Before distributing historical source as part of a release, locate and retain
the applicable permission/license or obtain written permission from the rights
holder. Do not assume that free downloads or a publicly visible repository grant
redistribution rights. If permission cannot be established, determine the proper
distribution/remediation approach with the rights holder or qualified advice.
The current replacement does not remove historical copies from Git history.
No upstream contact, history rewrite or new relicensing was performed here.

See [THIRD_PARTY.md](../THIRD_PARTY.md) for pinned evidence and notices. That file
also distinguishes confirmed matching source from unverified authorship claims.

## Before the first tagged release

- Validate the administrative and report workflows in a controlled environment,
  recording PowerShell/module versions and the tested commit. Mock tests alone
  do not validate live roles, API behavior or policy propagation.
- Complete the private-channel setup and remaining source-permission work.
- Run the existing repository checks and require both protected-branch jobs.
- Prepare a changelog and release notes describing compatibility changes, known
  limits and included license/notice files, then choose a version deliberately.

No tag or release is created by this documentation change.
