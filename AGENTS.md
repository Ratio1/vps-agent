# AGENTS.md

## Mission

Use Codex CLI plus the official `hostinger-api-mcp` package to manage Hostinger VPS fleets from this repository.

This repository may also expose an optional remote Contabo MCP connector through minimal wrapper scripts, but it remains a Codex bootstrap and operations repository rather than an SDK or MCP implementation repository.

## Hard Architecture Constraints

- Do **not** build a custom MCP server in this repo.
- Do **not** add Node/TypeScript API wrappers for Hostinger endpoints here.
- Always use globally installed `hostinger-api-mcp` as the MCP provider.
- Keep this repository focused on bootstrap, configuration, operations, and guardrails.

## Codex Project Artefacts

- Root guidance lives in this `AGENTS.md`.
- Project-scoped Codex configuration lives in `.codex/config.toml` and the `*.example` templates.
- Custom agent definitions live in `.codex/agents/*.toml`.
- Prompt templates live in `PROMPT.md`.
- Always use the OpenAI developer documentation MCP server if you need to work with the OpenAI API, ChatGPT Apps SDK, Codex, or Codex configuration without me having to explicitly ask.

## Mandatory Delivery Workflow

For non-trivial changes, use a bounded actor-critic loop. These labels are required logical phases. If the user explicitly asks for parallel agent work, map them onto the custom agents under `.codex/agents/`. Otherwise run the same phases sequentially in one Codex session.

1. PRECHECK
2. EXPLORER
3. BUILDER-1
4. CRITIC-1
5. BUILDER-2
6. CRITIC-2
7. BUILDER-3
8. VERIFIER

### PRECHECK

- Run the relevant `doctor` script before agent execution or before a non-trivial edit session.
- Read the current worktree, relevant scripts, docs, and `.codex` artefacts before editing.
- Prefer read/list operations before any mutating or billable action.

### EXPLORER

- Map the real execution path before proposing edits.
- Identify affected files, Linux/macOS and Windows differences, validation commands, and operational risks.
- Call out whether a task touches destructive or billable provider actions.

### BUILDER-N

- Make the smallest defensible change set for the current iteration.
- Keep unrelated files untouched.
- Preserve repository constraints, secret handling, and cross-platform parity.
- Update docs when behavior, bootstrap, or guardrails change.

### CRITIC-N

- Critics stay read-only.
- Critiques must be evidence-first, file-anchored, and focused on correctness, security, regressions, operational safety, and missing validation.
- Do not spend critique bandwidth on style-only nits unless they hide a real operational risk.

### VERIFIER

- Re-run the narrowest useful validation after the final builder pass.
- Validate scripts, docs, and config artefacts that changed.
- Report pass/fail status and any remaining gaps explicitly.

### Stop Criteria

- Stop early if the current critic reports no material findings and the verifier passes.
- Do not exceed three builder passes and two critic passes without escalating the unresolved blocker to the user.
- Record meaningful iterations in `docs/ITERATIONS.md`.

## Actor-Critic Quality Bar

- Separate exploration, implementation, critique, and verification. Do not collapse them into one unstructured pass.
- Use asymmetric roles: lighter explorer/docs agents, stronger builder/critic agents, and an independent verifier.
- Keep critics and docs researchers read-only so they are not grading their own edits.
- Treat verification as a separate gate, not as builder self-reporting.
- Use external grounding when a task depends on current OpenAI or vendor behavior.
- Keep each iteration scoped to one coherent change cluster.
- Prefer bounded refinement loops over open-ended self-editing.
- When parallel agents are used, assign clear file or responsibility ownership.

## Required Operational Behavior

- Validate environment first (`doctor` scripts) before agent execution.
- Ensure provider credentials are loaded from `profiles.json` or explicit process environment overrides and never logged.
- Prefer read/list operations before any mutating or billable action.
- Ask for explicit user confirmation intent before destructive actions.
- Ask for explicit user confirmation intent before billable provider actions such as create, upgrade, resize, restore, or delete operations.
- Treat MCP-backed provider tools as unsandboxed from Codex's perspective; repository guardrails still apply even when shell sandboxing is enabled.
- When changing `.codex` artefacts or answering OpenAI/Codex questions, use `openaiDeveloperDocs` first.

## Security Rules

- Never commit `profiles.json`.
- Never commit `.codex/config.toml` with local secrets.
- Never print or echo token values.
- Keep wrapper scripts minimal and auditable.
- Never persist transient auth headers or copy secrets into docs, prompts, or example configs.
- Prefer repo-scoped instructions, config, and agent files over ad hoc prompt stuffing.

## Cross-Platform Rules

- Keep Linux/macOS and Windows paths/scripts both maintained.
- If behavior differs by OS, document it in `README.md`.
- Keep optional devcontainer config functional for Windows users.

## Definition of Done

A change is complete when:

1. Scripts referenced in docs actually exist and execute.
2. Linux/macOS and Windows bootstrap paths are documented.
3. `profiles.json.template`, `.codex/config*.example`, and `.codex/agents/*.toml` are up to date.
4. `docs/RESEARCH.md`, `docs/IMPLEMENTATION_PLAN.md`, and `docs/ITERATIONS.md` reflect the current architecture and workflow.
5. No custom local MCP server code is introduced.
6. The bounded actor-critic workflow, stop criteria, and verification path are explicit.
