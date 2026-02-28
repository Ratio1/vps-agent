# AGENTS.md

## Mission

Use Codex CLI plus the official `hostinger-api-mcp` package to manage Hostinger VPS fleets from this repository.

## Hard Architecture Constraints

- Do **not** build a custom MCP server in this repo.
- Do **not** add Node/TypeScript API wrappers for Hostinger endpoints here.
- Always use globally installed `hostinger-api-mcp` as the MCP provider.
- Keep this repository focused on bootstrap, configuration, operations, and guardrails.

## Mandatory Delivery Workflow

For non-trivial changes, use:

1. BUILDER-1
2. CRITIC-1
3. BUILDER-2
4. CRITIC-2
5. BUILDER-3

Record meaningful iterations in `docs/ITERATIONS.md`.

## Required Operational Behavior

- Validate environment first (`doctor` scripts) before agent execution.
- Ensure Hostinger token is loaded from `.env` and never logged.
- Prefer read/list operations before any mutating/billable action.
- Ask for explicit user confirmation intent before destructive actions.

## Security Rules

- Never commit `.env`.
- Never commit `.codex/config.toml` with local secrets.
- Never print or echo token values.
- Keep wrapper scripts minimal and auditable.

## Cross-Platform Rules

- Keep Linux/macOS and Windows paths/scripts both maintained.
- If behavior differs by OS, document it in `README.md`.
- Keep optional devcontainer config functional for Windows users.

## Definition of Done

A change is complete when:

1. Scripts referenced in docs actually exist and execute.
2. Linux/macOS and Windows bootstrap paths are documented.
3. `.env.template` and `.codex` templates are up to date.
4. `docs/RESEARCH.md`, `docs/IMPLEMENTATION_PLAN.md`, and `docs/ITERATIONS.md` reflect the current architecture.
5. No custom local MCP server code is introduced.
