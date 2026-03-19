# Prompt Templates

## Actor-Critic Change

Use the bounded workflow in `AGENTS.md`.
Start with the relevant doctor script.
Map the affected files first, then run BUILDER-1, CRITIC-1, BUILDER-2, CRITIC-2, BUILDER-3, and a final verifier pass.
Prefer read/list operations before mutations.
Ask before any destructive or billable provider action.
Implement: <task>

## Read-Only Review

Use read-only mode and review this repository change with an owner mindset.
Prioritize correctness, security, operational regressions, cross-platform parity, and missing validation.
Lead with concrete findings and file references.
Task: <branch, diff, or directory>

## OpenAI/Codex Docs Lookup

Use the `openaiDeveloperDocs` MCP server first.
Verify the latest Codex or OpenAI configuration behavior before answering.
Return concise guidance with links or exact config keys.
Task: <question>

## Explicit Parallel-Agent Prompt

Use the custom agents in `.codex/agents/` if parallel agent work is enabled for this session.
Have `ops_explorer` map the code paths, `ops_builder` own the implementation, `ops_critic` do the read-only critique, `ops_verifier` run validation, and `docs_researcher` verify Codex or OpenAI documentation when needed.
Task: <task>
