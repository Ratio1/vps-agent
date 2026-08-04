# Iterations

This file is tracked and must remain public-safe. Record workflow-level changes, validation commands, and architectural decisions. Do not record live tenant names, hostnames, IP addresses, exact fleet counts, SSH key names, private key paths, CVE rollout targets, or provider action history here.

Private operational notes belong only in ignored local paths such as `_reports/`, `metrics/<tenant-slug>/`, `private/`, `ops-private/`, or `docs/*.local.md`.

## 2026-07-29 - Existing r1setup Configuration Recovery

### PRECHECK

- Ran the repository doctor and read-only provider inventory before local
  configuration changes.
- Reviewed the current upstream r1setup discovery/import implementation and
  verified its test suite before using it with existing services.

### BUILDER-1

- Reconstructed a local mainnet configuration by registering existing
  machines and importing discovered services without deployment.
- Preserved discovered logical names, runtime names, volume paths, image
  variants, and applied service-file versions.
- Ran the baseline fleet inventory smoke test after the modification pass.

### CRITIC-1

- Checked schema-v2 machine and instance mappings, SSH metadata, file
  permissions, and the absence of stored password fields or private-key
  material.
- Compared pre- and post-import container identities and start times to verify
  that configuration recovery did not restart remote services.

### BUILDER-2

- Repeated the bounded recovery for a second local configuration and created
  private portable exports with restricted permissions.
- Kept endpoints, aliases, fleet counts, SSH paths, and runtime evidence only
  in ignored private artifacts.
- Ran the baseline fleet inventory smoke test after the modification pass.

### CRITIC-2

- Verified both configurations against provider inventory and live discovery,
  checked cross-configuration integrity, and restored the intended active
  configuration pointer.

### VERIFIER

- Re-ran read-only connectivity, service-status, and bounded log checks.
- Re-ran repository regression tests and the baseline fleet inventory smoke
  test; live provider counts were reported only in the operator response.

## 2026-06-17 - Private Fleet Metrics Snapshots

### PRECHECK

- Ran `scripts/doctor-unix.sh` before private metrics work.
- Confirmed tenant-specific metrics paths are ignored and suitable for live
  operational notes.

### BUILDER-1

- Added an ignored private bandwidth snapshot for selected fleet nodes and
  dates.
- Ran the baseline fleet inventory smoke test after the edit pass.

### BUILDER-2

- Added an ignored private provider hardware comparison snapshot using static
  host probes, a short compute probe, and short contention samples.
- Kept live node details and measurements out of tracked documentation.

### VERIFIER

- Re-ran the baseline fleet inventory smoke test after each edit-producing
  pass.

## 2026-06-08 - Private Metrics Convention

### PRECHECK

- Ran `scripts/doctor-unix.sh` before editing.
- Reviewed ignore rules, repository guidance, and the existing private-report convention.

### BUILDER-1

- Added a tracked metrics README for the public-safe convention.
- Added ignore coverage for tenant-specific metrics snapshots.
- Updated repository guidance so future private operational metrics are kept under ignored tenant-specific metrics paths.

## 2026-05-07 - Public Documentation Hygiene

### PRECHECK

- Ran `scripts/doctor-unix.sh` before editing.
- Reviewed tracked docs and found that the iteration ledger was the main public-repository risk because it mixed architecture history with live operational detail.

### EXPLORER

- Identified affected public surfaces: repository guidance, README safety guidance, Contabo docs, research notes, ignored private-note paths, and the tracked iteration ledger.
- Confirmed this change is documentation-only and does not touch destructive or billable provider actions.

### BUILDER-1

- Added explicit public-documentation rules to repository guidance and README.
- Replaced fixed Contabo request ID example usage with generated request IDs.
- Sanitized this tracked iteration ledger so it preserves workflow history without live fleet intelligence.

## 2026-04-30 - Operational Fleet Work Sanitized

- Removed detailed live fleet operation records from the tracked ledger.
- Keep future host-level remediation evidence, exact provider counts, SSH rollout details, and provider action history in ignored local notes only.
- Public summaries may state that doctor checks, read-first inventory checks, and required smoke tests were used, without copying live infrastructure details.

## 2026-04-21 - Structured SSH Metadata Support In Profiles

### BUILDER-1

- Added regression coverage proving that nested account-level SSH metadata validates cleanly and is ignored by environment resolution.
- Updated the profiles resolver to preserve structured SSH metadata in the profile file without flattening it into exported environment values.
- Updated tracked docs so the supported profile contract is explicit: flat `credentials` and `settings` maps for environment export, optional structured SSH metadata preserved in-file only.

## 2026-03-20 - Local SSH Login Helper Layout

### BUILDER-1

- Documented the ignored local login-helper layout and provider-prefixed script naming convention.
- Generated local untracked login helpers from provider inventory.

### BUILDER-2

- Updated the helper convention and generated scripts to use a consistent default SSH user.
- Added live spot-check validation through a small sample of generated scripts instead of treating file generation as sufficient proof.

## 2026-03-20 - Contabo Inventory Pagination Fix

### BUILDER-1

- Traced an incorrect Contabo smoke-test count to first-page-only pagination in `scripts/contabo-api.js`.
- Updated the Contabo helper to request and aggregate all pages before returning JSON or summary output.

### CRITIC-1

- Main regression risk: silently undercounting Contabo fleets would make the repo-standard smoke test unreliable even when provider credentials were valid.
- Validation requirement: rerun `node scripts/vps-inventory-smoke.js` and confirm Contabo counts match provider totals rather than the first page size.

## 2026-03-20 - Mandatory Fleet Smoke Test After Each Edit Pass

### BUILDER-1

- Updated `AGENTS.md` so the repo-level baseline test is explicit: run `node scripts/vps-inventory-smoke.js` after each edit-producing prompt and after each builder pass that modifies files.
- Added the same expectation to the Definition of Done so verification reporting stays consistent.
- Tightened the reporting rule so smoke-test results must include VPS counts for each tenant/provider in Codex responses, not only pass/fail totals.

## 2026-03-20 - Tenant Plus Provider Is The Unique Identifier

### BUILDER-1

- Updated the resolver and onboarding flow so the normal repository model is one provider entry per tenant/provider pair.
- Removed account suffixes from smoke-test labels and counts output so verification reports are keyed by tenant and provider.

### CRITIC-1

- Main regression risk: leaving account labels visible in user-facing flows would keep suggesting a multi-account model that the repository no longer intends to support.
- Compatibility choice: keep legacy account parsing tolerant internally where possible, but stop surfacing it in normal startup, onboarding, and smoke-test reporting.

### CRITIC-2

- Main risk: leaving the smoke test as a convention instead of a hard rule would keep verification inconsistent across turns.
- Main operational constraint: the smoke test must stay read-only and cross-tenant so it fits the neutral multi-tenant startup model.

## 2026-03-20 - Neutral Startup With No Default Tenant Or Provider

### BUILDER-1

- Reworked the startup model so the repository no longer sets or documents a default tenant/provider context.
- Removed default-tenant guidance from tracked templates and docs.

### CRITIC-1

- Main regression risk: any startup path or doctor check that still treated missing defaults as a problem would keep fighting the intended multi-tenant model.
- Main operational risk: keeping provider MCPs auto-enabled would still force a provider assumption at startup.

### BUILDER-2

- Switched `start-agent` prompts to an explicit neutral context unless selectors are passed.
- Disabled provider MCP entries by default in local and example Codex configs.
- Removed the no-default warning from `scripts/profiles.js`.
- Updated onboarding so it saves tenant/provider credentials without creating defaults.

### CRITIC-2

- Checked that the direct inventory smoke test still works without any default tenant.
- Checked that provider-specific MCP use remains available, but only as an explicit opt-in session.

## 2026-03-20 - MCP Startup Triage and Cross-Tenant Inventory Smoke Test

### BUILDER-1

- Reproduced provider MCP startup failures directly through the wrapper scripts.
- Confirmed profile ambiguity as the primary startup failure mode when no explicit tenant is selected.
- Confirmed the optional remote Contabo connector requires its own connector key.

### CRITIC-1

- Main risk: leaving the optional Contabo MCP server enabled by default keeps producing noisy startup failures unrelated to direct provider operations.
- Main safety constraint: keep Hostinger on the official MCP package path and do not replace it with a custom wrapper or local MCP implementation.

### BUILDER-2

- Added `scripts/vps-inventory-smoke.js` as a direct read-only smoke test that iterates configured tenant/provider accounts and lists VPS instances where usable credentials exist.
- Updated tracked Codex config templates to disable the optional Contabo MCP server by default.
- Updated the template and docs for the new standard smoke test.

### CRITIC-2

- Checked that the new smoke test stays read-only and keeps secrets out of logs.
- Checked that the Contabo direct path remains the preferred scripted path and the optional remote connector remains available when explicitly enabled later.

### BUILDER-3

- Updated the local ignored Codex config to match the optional-provider defaults.
- Prepared local profile changes for additional tenant coverage without introducing a default tenant.

## 2026-03-19 - Simplified Profiles and Contabo Official API Flow

### BUILDER-1

- Inspected the live `profiles.json` shape and confirmed the repo needed to tolerate tenant-only files with no `defaults` block.
- Identified that Contabo mechanics needed to separate official REST API credentials from optional MCP connector credentials.

### CRITIC-1

- Main risk: keeping the old Contabo aliasing would silently misuse official API credentials in the optional remote MCP wrapper.
- Decision: separate the official REST API path from the optional remote MCP connector path and document each one explicitly.

### BUILDER-2

- Refactored `scripts/profiles.js` so the simplified `profiles.json` shape remains valid and writable.
- Reworked Contabo credential normalization around official API values, optional access tokens, and optional connector keys.
- Added `scripts/contabo-api.js` for token minting and direct read/list access against the official Contabo API.
- Updated regression scripts to include a read-only Contabo instance listing check through the official API helper.

### CRITIC-2

- Checked that the new direct Contabo path still honors repository constraints: no local MCP server, no secret values logged, Hostinger remains on the official MCP package, optional Contabo MCP usage requires its own connector key, and Linux/macOS plus Windows behavior stay aligned.

### BUILDER-3

- Simplified `profiles.json.template` to match the tenant-first shape.
- Rewrote README and architecture docs so Contabo direct API mechanics, optional MCP usage, and provider readiness are described accurately.

## 2026-03-19 - Profiles.json Multi-Tenant Refactor

### BUILDER-1

- Traced `.env` dependencies through bootstrap, onboarding, MCP wrappers, doctor scripts, and regression scripts.
- Identified that a rename alone would not work because Unix and Windows each duplicated local credential loading logic.

### CRITIC-1

- Main risk: silently picking the wrong customer when multiple tenants or provider accounts exist.
- Decision: introduce explicit tenant/account selection with defaults plus `VPS_*` override variables, and fail clearly on ambiguity.

### BUILDER-2

- Added `scripts/profiles.js` as the shared profiles resolver and writer.
- Added `profiles.json.template`.
- Refactored bootstrap, onboarding, MCP wrappers, doctor scripts, regression scripts, and start-agent scripts around `profiles.json`.

### CRITIC-2

- Checked that the refactor still honors repository constraints: no custom MCP server code, Hostinger stays on the official MCP package, Contabo remains remote-MCP-first at that point, credentials stay out of tracked runtime config and logs, and Linux/macOS plus Windows paths remain aligned.

### BUILDER-3

- Rewrote README and architecture docs for the multi-tenant model.
- Recorded the then-current Contabo recommendation and provider requirements.
- Aligned doctor scripts with `VPS_PROFILES_PATH` so template and alternate-profile validation use the same selector path as the wrappers.

## 2026-03-19 - Codex Actor-Critic Workflow Refresh

### BUILDER-1

- Audited repository guidance, Codex config files, startup scripts, and architecture docs.
- Verified the installed Codex CLI version and current project-scoped config shape.
- Checked official Codex documentation for `AGENTS.md`, Docs MCP, config profiles, and custom subagents.

### CRITIC-1

- Identified missing bounded-loop semantics, custom subagent definitions, Docs MCP config, reusable Codex profiles, and updated architecture docs.

### BUILDER-2

- Rewrote `AGENTS.md` around a bounded precheck, explorer, builder, critic, and verifier workflow.
- Added project-scoped Codex profiles and the `openaiDeveloperDocs` MCP server to repo config templates.
- Added custom agents for exploration, implementation, critique, verification, and docs research.
- Filled `PROMPT.md` with workflow-oriented prompt templates.

### CRITIC-2

- Checked that the new workflow still honors repository constraints: no custom MCP server code, official Hostinger MCP primary path, destructive and billable actions confirmation-gated, read-only critic/docs roles, and Linux/macOS plus Windows guidance alignment.

### BUILDER-3

- Updated README and architecture docs to match the new Codex artifacts.
- Extended doctor scripts to check the new `.codex` artifacts and Docs MCP configuration.
- Prepared validation commands to confirm the config still parses and doctor scripts still run.

## 2026-03-17 - TODO Plan Refactor for Provider Sequencing

### BUILDER-1

- Reviewed the existing work plan and current architecture notes.
- Identified that the plan was broad and provider-agnostic, but did not make Hostinger gating and Contabo prioritization explicit.

### CRITIC-1

- Risk: the old backlog allowed provider expansion to look parallel or interchangeable.
- Decision: rewrite the work plan as sequential provider tracks with hard entry and exit criteria.

### BUILDER-2

- Replaced the work plan with a provider-by-provider rollout plan.
- Made Hostinger baseline verification the gate and Contabo productization the immediate next focus.

### CRITIC-2

- Checked that the new plan still preserves repo constraints: no custom MCP server, doctor-first validation, read-first guardrails, secret safety, and cross-platform parity.

### BUILDER-3

- Finalized the plan wording so it is clearly a planning document only and not an execution checklist.

## 2026-03-05 - Contabo MCP Enablement

### BUILDER-1

- Searched for an existing Contabo MCP implementation.
- Located an optional remote connector with Streamable HTTP transport.
- Confirmed no obvious official standalone Contabo MCP package.

### CRITIC-1

- Risk: building a custom MCP server here would violate repository architecture rules.
- Decision: integrate remote connector only; no local MCP server implementation.

### BUILDER-2

- Added Unix and Windows Contabo MCP wrapper scripts.
- Added optional Contabo MCP server entries in Codex config templates.
- Added Contabo environment hints to the environment template used at that time.
- Updated doctor scripts for optional Contabo readiness checks.

### CRITIC-2

- Risk: `mcp-remote` can log custom headers to stderr by default.
- Fix: wrapper uses an environment placeholder header and silent mode to prevent credential leakage.

### BUILDER-3

- Updated README with optional Contabo connector usage and files.
- Added research and implementation plan docs.
- Re-ran doctor checks and validated the remote connector connectivity pattern.
