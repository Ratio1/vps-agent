# Implementation Plan - Optional Contabo MCP Connector

Date: 2026-03-05

## Constraints

- Do not add custom MCP server code in this repository.
- Keep Hostinger official MCP flow unchanged.
- Maintain Linux/macOS and Windows support.
- Keep credentials out of logs.

## Design

1. Add wrapper scripts:
   - Linux/macOS: `scripts/contabo-mcp.sh`
   - Windows: `scripts/contabo-mcp.ps1`
2. Use `mcp-remote` to bridge Codex stdio to remote Streamable HTTP endpoint.
3. Load credentials from `.env` and map to MCP header:
   - Prefer `CONTABO_MCP_API_KEY`, then `CONTABO_ACCESS_TOKEN`, then `CONTABO_CLIENT_SECRET`.
4. Keep secret out of command arguments by:
   - Exporting `CONTABO_RUNTIME_API_KEY`
   - Passing header as literal placeholder: `X-API-Key: ${CONTABO_RUNTIME_API_KEY}`
5. Run `mcp-remote` with `--silent` to avoid accidental header/value logs.
6. Update Codex config templates to include optional `contabo_api` server.
7. Update doctor scripts and docs.

## Validation

- Run Unix doctor script.
- Verify remote connector reachability with `mcp-remote-client` + header placeholder.
- Confirm no token values are printed in script output.
