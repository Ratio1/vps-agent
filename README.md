# VPS Agent

Zero-setup bootstrap for a Codex agent that manages multi-tenant VPS fleets from this repository.

The primary supported path is Hostinger via the official global MCP server: `hostinger-api-mcp`.

This repository also supports direct read/list Contabo operations via the official REST API, plus an optional remote Contabo MCP connector via `mcp-remote` (no custom MCP server code in this repo).

It now also ships project-scoped Codex artefacts for bounded actor-critic work: `AGENTS.md`, `.codex/config.toml`, reusable custom agents under `.codex/agents/`, and prompt templates in `PROMPT.md`.

This repository does **not** implement a custom MCP server.

## What happens automatically in Dev Container

When you open this repo in a VS Code Dev Container:

1. Tools are already installed in the container:
   - `codex`
   - `hostinger-api-mcp`
2. A guided onboarding script runs automatically.
3. The script guides you through:
   - Codex login (ChatGPT or API key)
   - Creating or updating `profiles.json`
   - Entering a Hostinger tenant/provider token
   - Final health check
4. Codex starts automatically and sends an intro that includes:
   - Agent purpose
   - Repository version from `ver.yaml`

After that, you can immediately chat with the agent.

## Super Simple Setup (recommended)

## 1. Install required apps on your computer

- Docker Desktop
- Visual Studio Code
- VS Code extension: `Dev Containers` (by Microsoft)

## 2. Clone and open this repository

```bash
git clone <your-repo-url>
cd "VPS Agent"
code .
```

## 3. Open inside Dev Container

In VS Code:

1. Press `F1`
2. Run `Dev Containers: Reopen in Container`
3. Wait until container build finishes

## 4. Follow the guided onboarding terminal

The script runs automatically and asks for:

1. Codex authentication:
   - `ChatGPT login` (recommended), or
   - `OPENAI_API_KEY`
2. A tenant name and a `HOSTINGER_API_TOKEN` (from Hostinger hPanel -> Profile -> API)

The script writes `profiles.json` for you and runs checks.

If the prompt window does not appear, run manually in the container terminal:

```bash
bash scripts/devcontainer-onboarding.sh
```

## 5. Codex starts automatically

After onboarding finishes, Codex auto-launches.

If VS Code runs `postAttachCommand` in a non-interactive context, auto-start is deferred to your first interactive terminal in the workspace and runs automatically there.

If it does not launch (rare terminal issue), run:

```bash
bash scripts/devcontainer-onboarding.sh
```

Now ask things like:

- `How many VPS do I have?`
- `Give me the name of each VPS`
- `Create a new VPS in Phoenix`
- `Add this SSH key to VPS smart14.domain.tld`

## Important safety

- Creating/deleting/upgrading VPS can cost money.
- Ask the agent to list/show details first before mutating anything.
- Never commit `profiles.json`.

## Public Documentation Boundary

This repository is intended to be safe to publish. Tracked documentation should describe architecture, bootstrap, guardrails, provider requirements, placeholder examples, and validation commands.

Do not put live operational inventory in tracked docs: tenant names, hostnames, IP addresses, exact fleet counts, SSH key names, private key paths, CVE rollout targets, or provider action history. Keep those notes in ignored local paths such as `_reports/`, `private/`, `ops-private/`, or `docs/*.local.md`.

`docs/ITERATIONS.md` is tracked, so entries there must stay public-safe and summarize workflow-level changes only.

## Codex Workflow Profiles

The repository now includes a bounded actor-critic workflow and reusable project-scoped Codex profiles.

Common entry points:

```bash
codex -p vps_actor_critic
codex -p vps_review "Review this branch and list real risks first."
codex -p vps_docs "Look up the latest Codex config keys for custom agents."
```

When you explicitly ask for parallel agent work, Codex can use these custom agents from `.codex/agents/`:

- `ops_explorer`
- `ops_builder`
- `ops_critic`
- `ops_verifier`
- `docs_researcher`

The default repository workflow is still doctor-first, read-first, and confirmation-gated for destructive or billable provider actions.

## Multi-Tenant Profiles

Repository credentials now live in `profiles.json`, not `.env`.

- Tracked example: `profiles.json.template`
- Real local file: `profiles.json`
- Shape:

```json
{
  "tenants": [
    {
      "tenant": "customer-a",
      "accounts": [
        {
          "provider": "hostinger",
          "credentials": {
            "API_TOKEN": "..."
          }
        },
        {
          "provider": "contabo",
          "credentials": {
            "CLIENT_ID": "...",
            "CLIENT_SECRET": "...",
            "API_USER": "...",
            "API_PASSWORD": "..."
          },
          "ssh": {
            "ssh_user": "root",
            "ssh_pem": "ssh-key.pem",
            "hosts": {
              "vps-01": "203.0.113.10",
              "vps-02": "203.0.113.11"
            }
          }
        }
      ]
    },
    {
      "tenant": "customer-b",
      "accounts": [
        {
          "provider": "hostinger",
          "credentials": {
            "API_TOKEN": "..."
          }
        }
      ]
    }
  ]
}
```

The repository startup flow does not assume a default tenant or provider. In the normal model, each `tenant/provider` pair is unique. Start neutral, then pass `--tenant` when you want a provider-specific session. The shared resolver still honors explicit selector flags, environment overrides, and optional defaults if you choose to maintain them yourself.

`credentials` and `settings` remain flat env-style key/value maps. Optional structured SSH inventory metadata belongs under the account-level `ssh` object and is preserved in `profiles.json`, but it is not exported by `scripts/profiles.js resolve`.

- Inspect configured provider entries:

```bash
node scripts/profiles.js list --format text
```

- Run the standard cross-tenant VPS inventory smoke test:

```bash
node scripts/vps-inventory-smoke.js
```

- Start a neutral session with no tenant or provider preselected:

```bash
bash scripts/start-agent.sh
```

Select a tenant explicitly when you want to work in a single tenant context:

```bash
bash scripts/start-agent.sh --tenant customer-a
```

- Validate a non-secret example without creating a real `profiles.json` yet:

```bash
VPS_PROFILES_PATH=profiles.json.template bash scripts/doctor-unix.sh
```

The resolver uses this precedence:

1. Explicit CLI selector flags on `start-agent`
2. Process environment overrides such as `VPS_TENANT`
3. Optional `defaults` in `profiles.json`
4. Auto-select only when there is exactly one matching tenant/provider entry

## Provider Requirements

Usable now with the current repository mechanics:

- `hostinger`
  - Canonical credential key in `profiles.json`: `API_TOKEN`
  - Also accepted: `HOSTINGER_API_TOKEN`
  - Source: create a token in Hostinger hPanel API settings
  - Current repo path: official `hostinger-api-mcp`, enabled only when you opt into a provider-specific MCP session for a specific tenant/provider

- `contabo`
  - Direct official API credentials: `CLIENT_ID`, `CLIENT_SECRET`, `API_USER`, `API_PASSWORD`
  - Optional pre-minted token: `CONTABO_ACCESS_TOKEN`
  - Optional settings: `CONTABO_AUTH_URL`, `CONTABO_API_BASE_URL`
  - Direct repo path: `node scripts/contabo-api.js list-instances --tenant customer-a --format summary`
  - Optional remote MCP connector key: `CONTABO_MCP_API_KEY`
  - Optional remote MCP settings: `CONTABO_MCP_URL`, `CONTABO_MCP_TRANSPORT`

Can be connected immediately for validation with the current regression scripts, but are not yet wired into agent-management MCP wrappers here:

- `aws`
  - `AWS_PROFILE` or `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY`
  - Optional: `AWS_SESSION_TOKEN`, `AWS_REGION`

- `gcp`
  - `GOOGLE_APPLICATION_CREDENTIALS` or an already active `gcloud` session
  - Required for non-interactive project-scoped checks: `GOOGLE_CLOUD_PROJECT`
  - Optional: `GOOGLE_CLOUD_REGION`

- `azure`
  - `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_CLIENT_SECRET`
  - Optional but recommended: `AZURE_SUBSCRIPTION_ID`

- `ovh`
  - `OVH_APPLICATION_KEY`, `OVH_APPLICATION_SECRET`, `OVH_CONSUMER_KEY`
  - Optional: `OVH_ENDPOINT`

## Optional: Contabo MCP Connector

This repo ships wrappers for the remote Contabo connector endpoint:

- `https://contabo.run.mcp.com.ai/mcp`
- Transport: `Streamable HTTP`

Setup:

1. Put a `contabo` provider entry in `profiles.json`.
2. Set `CONTABO_MCP_API_KEY` for the remote connector path.
3. Optional endpoint overrides go in that provider entry's `settings`:
   - `CONTABO_MCP_URL`
   - `CONTABO_MCP_TRANSPORT`
4. Provider MCP entries are disabled by default in `.codex/config*.toml` so agent startup stays neutral across tenants and providers.
5. Enable `contabo_api` only after adding the connector key and selecting an explicit tenant/provider context for that session.
6. Enable `hostinger_api` only when you intentionally want a Hostinger MCP session for a specific tenant/provider.
7. Use the updated `.codex/config*.toml` template(s), which include:
   - `hostinger_api` (official Hostinger MCP wrapper)
   - `contabo_api` (remote Contabo MCP wrapper)

The wrapper runs `mcp-remote` in silent mode to avoid leaking credential headers in logs.

Official Contabo REST API credentials are not reused as the remote connector key.

Recommended operational path for Contabo with the current repo:

- Primary: use the official Contabo REST API for direct scripted read/list operations from this repo.
- Secondary: use the optional remote MCP connector when you specifically need Contabo tool exposure inside Codex and have a connector key.
- Fallback: use the official `cntb` CLI when you want a fully official non-MCP path from a shell session.
- Caveat: Contabo's official API/CLI documentation states Storage VPS are not supported through the API/CLI path.

## Automated regression checks

Run read-only regression checks (instance count + status distribution) for providers whose selected account is present in `profiles.json` or whose local CLI session is already active:

Linux/macOS:

```bash
./scripts/regression-tests.sh
```

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/regression-tests.ps1
```

By default, AWS/GCP/Azure checks run only when the selected profile provides credentials. To also include already logged-in local CLI sessions, set `REGRESSION_USE_LOCAL_SESSIONS=true` before running the script.

## Files you may care about

- Devcontainer config: `.devcontainer/devcontainer.json`
- Onboarding script: `scripts/devcontainer-onboarding.sh`
- Agent launcher with intro prompt: `scripts/start-agent.sh`
- MCP wrapper (Linux): `scripts/hostinger-mcp.sh`
- Contabo direct API helper: `scripts/contabo-api.js`
- MCP wrapper (Linux, Contabo): `scripts/contabo-mcp.sh`
- MCP wrapper (Windows, Contabo): `scripts/contabo-mcp.ps1`
- Shared profile resolver: `scripts/profiles.js`
- Multi-tenant credentials template: `profiles.json.template`
- Linux Codex MCP template: `.codex/config.toml.example`
- Windows Codex MCP template: `.codex/config.windows.toml.example`
- Custom Codex agents: `.codex/agents/*.toml`
- Prompt templates: `PROMPT.md`
- Agent rules: `AGENTS.md`

## Manual setup outside Dev Container (optional)

Linux/macOS:

```bash
./scripts/bootstrap-unix.sh
node scripts/profiles.js list --format text
./scripts/doctor-unix.sh
bash scripts/start-agent.sh --tenant customer-a
```

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/bootstrap-windows.ps1
node scripts/profiles.js list --format text
powershell -ExecutionPolicy Bypass -File scripts/doctor-windows.ps1
powershell -ExecutionPolicy Bypass -File scripts/start-agent.ps1 -Tenant customer-a
```

## Disable auto-start (optional)

Set `AUTO_START_CODEX` to `false` in `.devcontainer/devcontainer.json` if you do not want Codex to auto-open on the first interactive terminal after each container start.

## License

This repository is licensed under the Apache License, Version 2.0.

- Origin: Ratio1 open-source project.
- License grant: Apache-2.0 permits use, reproduction, modification, distribution, sublicensing, and use in commercial products and services, subject to the license terms.
- Express permission: Any person or entity may clone this repository and create, distribute, or sell commercial products derived from it, provided Apache-2.0 obligations are met.
- No additional field-of-use or commercial restrictions are imposed by this repository beyond Apache-2.0.
- Full license text: `LICENSE` (and `LICENSE.md` mirror)
- Attribution notice: `NOTICE`
