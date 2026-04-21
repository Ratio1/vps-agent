# Iterations

## 2026-04-21 - Structured SSH Metadata Support In Profiles

### BUILDER-1

- Added a regression test for `scripts/profiles.js` proving that a nested account-level `ssh` block validates cleanly and is ignored by env resolution.
- Updated the profiles resolver to treat `ssh` as structured metadata instead of an env key, with a small shape check for `ssh` and `ssh.hosts`.
- Updated the tracked README and architecture notes so the supported profile contract is explicit: flat `credentials`/`settings` maps for env export, optional `ssh` metadata preserved in-file only.

## 2026-03-20 - Local SSH Login Helper Layout

### BUILDER-1

- Rewrote `LOGINS_README.md` so the local `logins/` directory has an explicit tenant-folder layout, provider-prefixed script naming convention, and a fixed SSH launcher template.
- Generated local untracked per-machine `.sh` login helpers under `logins/ratio1/` and `logins/aurelex/` from the current provider inventories.

### BUILDER-2

- Updated the helper convention and generated scripts to use `root` as the default SSH user for both Hostinger and Contabo.
- Added live spot-check validation through a small sample of generated scripts instead of treating file generation as sufficient proof.

## 2026-03-20 - Contabo Inventory Pagination Fix

### BUILDER-1

- Traced the incorrect Contabo smoke-test count to `scripts/contabo-api.js`, which only fetched the first `/v1/compute/instances` page.
- Updated the Contabo helper to request and aggregate all pages before returning JSON or summary output.

### CRITIC-1

- Main regression risk: silently undercounting Contabo fleets would make the repo-standard smoke test unreliable even when provider credentials were valid.
- Validation requirement: rerun `node scripts/vps-inventory-smoke.js` and confirm the Contabo counts match the provider totals rather than the first page size.

## 2026-03-20 - Mandatory Fleet Smoke Test After Each Edit Pass

### BUILDER-1

- Updated `AGENTS.md` so the repo-level baseline test is explicit: run `node scripts/vps-inventory-smoke.js` after each edit-producing prompt and after each builder pass that modifies files.
- Added the same expectation to the Definition of Done so verification reporting stays consistent.
- Tightened the reporting rule so smoke-test results must include VPS counts for each tenant/provider, not only pass/fail totals.

## 2026-03-20 - Tenant Plus Provider Is The Unique Identifier

### BUILDER-1

- Updated the resolver and onboarding flow so the normal repository model is one provider entry per tenant/provider pair.
- Removed `/primary` from the smoke-test labels and counts output so verification reports are keyed by `tenant/provider`.

### CRITIC-1

- Main regression risk: leaving account labels visible in user-facing flows would keep suggesting a multi-account model that the repository no longer intends to support.
- Compatibility choice: keep legacy account parsing tolerant internally where possible, but stop surfacing it in normal startup, onboarding, and smoke-test reporting.

### CRITIC-1

- Main risk: leaving the smoke test as a convention instead of a hard rule would keep verification inconsistent across turns.
- Main operational constraint: the smoke test must stay read-only and cross-tenant so it fits the neutral multi-tenant startup model.

## 2026-03-20 - Neutral Startup With No Default Tenant Or Provider

### BUILDER-1

- Reworked the startup model so the repository no longer sets or documents a default tenant/provider context.
- Removed the temporary default-tenant guidance from the tracked template/docs and from the local ignored `profiles.json`.

### CRITIC-1

- Main regression risk: any startup path or doctor check that still treated missing defaults as a problem would keep fighting the intended multi-tenant model.
- Main operational risk: keeping Hostinger MCP auto-enabled would still force a provider assumption at startup.

### BUILDER-2

- Switched `start-agent` prompts to an explicit neutral context (`none`) unless selectors are passed.
- Disabled both provider MCP entries by default in the local and example Codex configs.
- Removed the no-default warning from `scripts/profiles.js`.
- Updated onboarding so it saves tenant/provider credentials without creating defaults.

### CRITIC-2

- Checked that the direct inventory smoke test still works without any default tenant.
- Checked that provider-specific MCP use remains available, but only as an explicit opt-in session.

## 2026-03-20 - MCP Startup Triage and Cross-Tenant Inventory Smoke Test

### BUILDER-1

- Reproduced the MCP startup failures directly through `scripts/hostinger-mcp.sh` and `scripts/contabo-mcp.sh`.
- Confirmed the primary failure mode was profile ambiguity: multiple tenants in `profiles.json` with no explicit tenant selection, so the wrappers exited before MCP initialize completed.
- Confirmed the secondary failure mode on Contabo: the remote connector path still requires `CONTABO_MCP_API_KEY`, which was not configured.

### CRITIC-1

- Main risk: leaving the optional Contabo MCP server enabled by default keeps producing noisy startup failures that are unrelated to the direct provider operations the repo now prefers.
- Main safety constraint: keep Hostinger on the official MCP package path and do not replace it with a custom wrapper or local MCP implementation.

### BUILDER-2

- Added `scripts/vps-inventory-smoke.js` as a direct read-only smoke test that iterates all configured tenant/provider accounts and lists VPS instances where usable credentials exist.
- Updated the tracked Codex config templates to disable the optional `contabo_api` MCP server by default.
- Updated the template and docs for the new standard smoke test.

### CRITIC-2

- Checked that the new smoke test stays read-only and keeps secrets out of logs.
- Checked that the Contabo direct path remains the preferred scripted path and the optional remote connector remains available when explicitly enabled later.

### BUILDER-3

- Updated the local ignored `.codex/config.toml` to match the new optional-provider defaults.
- Prepared the local profile changes needed to add the `aurelex` tenant without introducing a default tenant.

## 2026-03-19 - Simplified Profiles and Contabo Official API Flow

### BUILDER-1

- Inspected the live `profiles.json` shape and confirmed the repo already needed to tolerate tenant-only files with no `defaults` block.
- Identified that Contabo mechanics were incomplete and, worse, treated client secrets and access tokens as interchangeable MCP connector keys.

### CRITIC-1

- Main risk: keeping the old Contabo aliasing would silently misuse official API credentials in the optional remote MCP wrapper.
- Decision: separate the official REST API path from the optional remote MCP connector path and document each one explicitly.

### BUILDER-2

- Refactored `scripts/profiles.js` so the simplified `profiles.json` shape remains valid and writable.
- Reworked Contabo credential normalization around `CLIENT_ID`, `CLIENT_SECRET`, `API_USER`, `API_PASSWORD`, `CONTABO_ACCESS_TOKEN`, and optional `CONTABO_MCP_API_KEY`.
- Added `scripts/contabo-api.js` for token minting and direct read/list access against the official Contabo API.
- Updated regression scripts to include a read-only Contabo instance listing check through the official API helper.

### CRITIC-2

- Checked that the new direct Contabo path still honors repository constraints:
  - no local MCP server
  - no secret values logged
  - Hostinger remains on the official MCP package
  - the optional remote Contabo MCP wrapper now requires its own connector key explicitly
  - Linux/macOS and Windows behavior stay aligned

### BUILDER-3

- Simplified `profiles.json.template` to match the live tenant-first shape.
- Rewrote README and architecture docs so Contabo direct API mechanics, optional MCP usage, and provider readiness are all described accurately.

## 2026-03-19 - Profiles.json Multi-Tenant Refactor

### BUILDER-1

- Traced every live `.env` dependency through bootstrap, onboarding, MCP wrappers, doctor scripts, and regression scripts.
- Identified that a rename alone would not work because Unix and Windows each duplicated local credential loading logic.

### CRITIC-1

- Main risk: silently picking the wrong customer when multiple tenants or provider accounts exist.
- Decision: introduce explicit tenant/account selection with defaults plus `VPS_*` override variables, and fail clearly on ambiguity.

### BUILDER-2

- Added `scripts/profiles.js` as the shared profiles resolver and writer.
- Added `profiles.json.template`.
- Refactored bootstrap, onboarding, MCP wrappers, doctor scripts, regression scripts, and start-agent scripts around `profiles.json`.

### CRITIC-2

- Checked that the refactor still honors repository constraints:
  - no custom MCP server code
  - Hostinger stays on the official MCP package
  - Contabo remains remote-MCP-first
  - credentials stay out of tracked runtime config and logs
  - Linux/macOS and Windows paths remain aligned

### BUILDER-3

- Rewrote README and architecture docs for the multi-tenant model.
- Recorded the current Contabo recommendation: remote MCP connector first, official API or `cntb` CLI fallback.
- Added provider requirement documentation for Hostinger, Contabo, AWS, GCP, Azure, and OVH.
- Aligned doctor scripts with `VPS_PROFILES_PATH` so template and alternate-profile validation use the same selector path as the wrappers.

## 2026-03-19 - Codex Actor-Critic Workflow Refresh

### BUILDER-1

- Audited the existing repository guidance, `.codex` config files, startup scripts, and architecture docs.
- Verified the installed Codex CLI version and current project-scoped config shape.
- Checked current official Codex documentation for `AGENTS.md`, Docs MCP, config profiles, and custom subagents.

### CRITIC-1

- Identified the main gaps:
  - `AGENTS.md` only described a simple builder/critic list with no bounded loop semantics.
  - The repository had no custom subagent definitions.
  - The project config had no Docs MCP entry, no `[agents]` settings, and no reusable Codex profiles.
  - The architecture docs still described only the earlier Contabo connector update.

### BUILDER-2

- Rewrote `AGENTS.md` around a bounded precheck, explorer, builder, critic, and verifier workflow.
- Added project-scoped Codex profiles and the `openaiDeveloperDocs` MCP server to the repo config and both templates.
- Added custom agents for exploration, implementation, critique, verification, and docs research.
- Filled `PROMPT.md` with workflow-oriented prompt templates.

### CRITIC-2

- Checked that the new workflow still honors repository constraints:
  - no custom MCP server code
  - Hostinger official MCP remains primary
  - destructive and billable actions stay confirmation-gated
  - critics and docs researchers remain read-only
  - Linux/macOS and Windows guidance stay aligned

### BUILDER-3

- Updated `README.md`, `docs/RESEARCH.md`, and `docs/IMPLEMENTATION_PLAN.md` to match the new Codex artefacts.
- Extended doctor scripts to check the new `.codex` artefacts and Docs MCP configuration.
- Prepared validation commands to confirm the config still parses and the doctor scripts still run.

## 2026-03-17 - TODO Plan Refactor for Provider Sequencing

### BUILDER-1

- Reviewed the existing `TODO.md` and current architecture notes.
- Identified that the plan was broad and provider-agnostic, but did not make Hostinger gating and Contabo prioritization explicit.

### CRITIC-1

- Risk: the old backlog allowed provider expansion to look parallel or interchangeable.
- Decision: rewrite the work plan as sequential provider tracks with hard entry and exit criteria.

### BUILDER-2

- Replaced `TODO.md` with a provider-by-provider rollout plan.
- Made Hostinger baseline verification the gate and Contabo productization the immediate next focus.

### CRITIC-2

- Checked that the new plan still preserves repo constraints: no custom MCP server, doctor-first validation, read-first guardrails, secret safety, and cross-platform parity.

### BUILDER-3

- Finalized the plan wording so it is clearly a planning document only and not an execution checklist.

## 2026-03-05 - Contabo MCP Enablement

### BUILDER-1

- Searched for an existing Contabo MCP implementation.
- Located remote connector `ai.com.mcp/contabo` with Streamable HTTP endpoint.
- Confirmed no obvious official standalone Contabo MCP package.

### CRITIC-1

- Risk: building a custom MCP server here would violate repository architecture rules.
- Decision: integrate remote connector only; no local MCP server implementation.

### BUILDER-2

- Added `scripts/contabo-mcp.sh` and `scripts/contabo-mcp.ps1`.
- Added optional `contabo_api` MCP server entries in `.codex` templates/config.
- Added Contabo env hints to `.env.template`.
- Updated doctor scripts for optional Contabo readiness checks.

### CRITIC-2

- Risk: `mcp-remote` can log custom headers to stderr by default.
- Fix: wrapper uses env placeholder header and `--silent` to prevent credential leakage.

### BUILDER-3

- Updated README with optional Contabo connector usage and files.
- Added `docs/RESEARCH.md` and `docs/IMPLEMENTATION_PLAN.md`.
- Re-ran doctor checks and validated remote connector connectivity pattern.
