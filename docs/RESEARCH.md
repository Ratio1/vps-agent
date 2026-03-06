# Research - Contabo MCP Integration

Date: 2026-03-05

## Scope

Find an existing Contabo MCP server/connector first. Only if unavailable, consider constructing one.

## Findings

1. No clear official Contabo MCP package was found on npm or GitHub as a standalone maintained project.
2. A public Contabo MCP connector exists on Glama under `ai.com.mcp/contabo`, marked healthy and exposing:
   - URL: `https://contabo.run.mcp.com.ai/mcp`
   - Transport: `Streamable HTTP`
   - Repository reference: `la-rebelion/hapimcp`
3. Contabo official API docs confirm:
   - API base: `https://api.contabo.com`
   - OAuth token endpoint: `https://auth.contabo.com/auth/realms/contabo/protocol/openid-connect/token`
4. `mcp-remote` supports remote Streamable HTTP MCP and custom headers, including env-placeholder substitution in headers.

## Decision

Use the existing remote Contabo connector via `mcp-remote` wrappers (Linux + Windows) and keep this repo free of custom MCP server code.

## Sources

- Contabo API docs: https://api.contabo.com/
- Glama connector page (`ai.com.mcp/contabo`): https://glama.ai/mcp/connectors/ai.com.mcp/contabo
- HAPI MCP repository: https://github.com/la-rebelion/hapimcp
- `mcp-remote` README: https://github.com/geelen/mcp-remote
