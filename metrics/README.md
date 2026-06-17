# Metrics

This directory documents the repository convention for local operational metrics.

Tenant-specific metrics snapshots belong in ignored subdirectories such as
`metrics/ratio1/`. Those files may contain private operational context including
tenant names, hostnames, IP addresses, exact fleet counts, provider results, and
host-level observations, so they must stay out of git.

Use tracked files in this directory only for public-safe conventions. Do not copy
live fleet details, raw provider output, SSH paths, tokens, or remediation notes
into tracked documentation.

Recommended snapshot contents:

- collection timestamp and operator context
- commands/tests run, with pass/fail status
- per-provider inventory smoke-test counts when needed for local continuity
- measurement method and limitations
- raw or summarized host metrics needed for future comparisons
- follow-up actions that are safe to keep private
