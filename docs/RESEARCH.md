# Research - Multi-Tenant Profiles and Contabo Path

Date: 2026-03-19

## Scope

Replace repository-local `.env` usage with a multi-tenant `profiles.json`, and determine the best current path for interacting with Contabo VPS resources from this repository without introducing local MCP server code.

## Findings

1. The repository previously assumed one local credential set in `.env`, which does not scale to:
   - multiple tenants
   - multiple providers
2. A JSON profiles file with:
   - tenant entries
   - provider entries
   - provider-specific credential and setting maps
   - optional defaults only when needed
   fits the repository's bootstrap and guardrail role better than provider-specific `.env` variables.
3. Current Hostinger usage in this repo still maps cleanly to a single canonical key:
   - `API_TOKEN` for the official `hostinger-api-mcp`
4. For Contabo, official sources currently document two official interaction paths:
   - the REST API at `https://api.contabo.com`
   - the official `cntb` CLI
5. Official Contabo API access currently requires four values from the Customer Control Panel:
   - client ID
   - client secret
   - API user
   - API password
6. Official Contabo documentation currently states that API/CLI compute management does not support Storage VPS.
7. I did not find an official Contabo MCP server in official Contabo sources.
8. The current repo already has a usable optional MCP path for Contabo:
   - Glama lists the `ai.com.mcp/contabo` remote connector
   - status shown on the listing: `Healthy`
   - last tested: `2026-01-30 21:31`
   - transport: `Streamable HTTP`
   - tool count listed: `123`
   - backing repository: `la-rebelion/hapimcp`
9. The same Glama page also shows an ownership verification failure at `2026-03-19 06:00`.
   - I infer this is separate from runtime availability because the listing still reports the connector as healthy and recently tested.
10. Therefore, the best current Contabo path for this repository is:
   - primary: use Contabo's official REST API for direct scripted operations in this repository, because it is the official path and now fits cleanly into a minimal local helper flow without introducing any local MCP server code
   - secondary: keep the remote MCP connector available when MCP tool exposure inside Codex is specifically needed and a connector key is available
   - fallback: use Contabo's official `cntb` CLI for direct shell-based access
11. Other providers that can be connected immediately with current repo functionality are limited to validation paths, not full MCP management paths:
   - AWS
   - GCP
   - Azure
   - OVH
12. With multiple tenants in `profiles.json`, any auto-started MCP wrapper that resolves profiles without an explicit tenant will exit before the MCP handshake begins.
13. Therefore neutral startup across all tenants/providers requires provider MCP entries to stay opt-in and disabled by default in the shipped Codex config.
14. When a Hostinger MCP session is explicitly requested, it should still use the official `hostinger-api-mcp` package path.
15. A repo-standard smoke test is better grounded on direct provider list calls than on MCP startup because it exercises the underlying credentials and read/list paths for every configured tenant/provider entry.

## Decision

Refactor the repository so that `profiles.json` is the canonical local credentials file.

Implementation decisions:

- Track `profiles.json.template`; ignore `profiles.json`.
- Support a simplified `profiles.json` shape by default, with optional `defaults` only when needed.
- Use `VPS_TENANT` and provider-specific selectors like `VPS_HOSTINGER_ACCOUNT` and `VPS_CONTABO_ACCOUNT` for per-session overrides.
- Keep direct environment variable overrides working for advanced users and CI-style runs.
- Keep Hostinger on the official `hostinger-api-mcp` package path.
- Use Contabo's official REST API credentials directly for scripted repo operations.
- Keep provider MCP paths optional for agentic use and disabled by default in shipped Codex config templates so startup does not assume tenant/provider context.
- Add a direct cross-tenant VPS inventory smoke test that enumerates every configured tenant/provider entry without depending on MCP startup.

## Sources

- Contabo API docs: https://api.contabo.com/
- Contabo help: How Can I Access the Contabo API?: https://help.contabo.com/en/support/solutions/articles/103000270527-how-can-i-access-the-contabo-api-
- Contabo help: What is the cntb Tool?: https://help.contabo.com/en/support/solutions/articles/103000283067-what-is-the-cntb-tool-
- Glama Contabo connector listing: https://glama.ai/mcp/connectors/ai.com.mcp/contabo
- Hostinger API token guidance: https://www.hostinger.com/support/11145020-how-to-use-the-hostinger-api-n8n-community-node/
- Hostinger API CLI article: https://www.hostinger.com/support/11679133-how-to-use-hostinger-api-cli/
