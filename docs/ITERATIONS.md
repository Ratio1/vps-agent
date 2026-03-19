# Iterations

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
