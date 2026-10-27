# Contributing

Keep each script's purpose, prerequisites, access requirements and examples in
comment-based help. Return structured objects; keep display formatting out of
report pipelines. Use explicit domain/tenant/subscription targets, terminating
errors and parameter validation. Do not add hardcoded accounts, credentials,
organization identifiers, machine addresses or paths.

Changes to accounts and security settings must support ShouldProcess (`-WhatIf`
and confirmation), show targets, and document recovery. Do not install modules
or connect/disconnect a caller's cloud session implicitly. Avoid broad permissions
unless required by the service API and explain them when they are required.

Run `tools/Test-Repository.ps1` using the README's pinned dependencies. Add focused
regression tests using fail-closed mocks or synthetic data. CI must never use a
production tenant or change a workstation's actual protection settings. Describe
any additional non-production integration validation and its limits in the PR.

Preserve author/source attribution. Confirm redistribution terms before adding
third-party code. Never include real report exports, browser history or secrets.
