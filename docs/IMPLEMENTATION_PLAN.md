# Implementation Plan - Profiles Refactor and Provider Readiness

Date: 2026-03-19

## Constraints

- Do not add custom MCP server code in this repository.
- Keep `hostinger-api-mcp` as the official Hostinger provider.
- Keep the optional remote Contabo connector path intact for Codex usage, but do not depend on it for direct Contabo API operations.
- Maintain Linux/macOS and Windows support.
- Keep credentials out of logs, prompts, and tracked config.
- Ask for explicit confirmation before destructive or billable provider actions.

## Design

1. Replace `.env` as the repository-local credential source with `profiles.json`.
2. Track `profiles.json.template` and ignore real `profiles.json`.
3. Add a shared resolver script:
   - parses and validates `profiles.json`
   - resolves the selected tenant/provider entry
   - supports defaults and per-session overrides
   - supports both Unix shell and PowerShell output
   - preserves optional structured account metadata like `ssh` without flattening it into env vars
4. Refactor these scripts to use the shared resolver:
   - bootstrap
   - devcontainer onboarding
   - Hostinger MCP wrappers
   - Contabo MCP wrappers
   - doctor scripts
   - regression scripts
   - start-agent scripts
5. Add a minimal Contabo official API helper that:
   - accepts `CLIENT_ID`, `CLIENT_SECRET`, `API_USER`, `API_PASSWORD`
   - can reuse `CONTABO_ACCESS_TOKEN` when already minted
   - performs read/list operations without introducing a local MCP server
6. Keep direct process environment credentials working as an override path.
7. Document provider requirements and readiness tiers:
   - MCP-backed now: Hostinger
   - official direct API read/list now: Contabo
   - validation-only with current scripts: AWS, GCP, Azure, OVH
8. Update architecture docs to record the multi-tenant shift and the Contabo recommendation:
   - official REST API first for direct repo operations
   - optional remote MCP connector for Codex tool exposure
   - official `cntb` CLI fallback
9. Add a standard direct smoke test that iterates every configured tenant/provider entry and performs a read-only VPS listing.
10. Keep provider MCP servers disabled by default in `.codex/config*.toml` so Codex startup stays neutral and does not assume tenant/provider context.

## Validation

- Parse `profiles.json.template` and `.codex` TOML files.
- Run `node scripts/profiles.js validate --file profiles.json.template`.
- Run `VPS_PROFILES_PATH=profiles.json.template bash scripts/doctor-unix.sh`.
- Run `scripts/doctor-windows.ps1` with `VPS_PROFILES_PATH=profiles.json.template` when PowerShell is available.
- Run `node scripts/profiles.js list --file profiles.json.template --format text`.
- Run `node scripts/vps-inventory-smoke.js --file profiles.json.template` only as a structure check when the template contains placeholder credentials; run it against a real local `profiles.json` for live provider validation.
- Review the final diff to confirm:
  - `profiles.json` is ignored
  - `profiles.json.template` is tracked
  - no custom MCP server code was introduced
