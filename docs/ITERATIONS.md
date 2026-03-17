# Iterations

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
