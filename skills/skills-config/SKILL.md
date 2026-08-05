---
name: skills-config
description: >
  Use this skill when the user needs to configure MDA AI Tools skills — even if they say
  "set up my config", "configure ai tools", "I just installed skills", or "help me set up the skills".
  Use it after a fresh install of mda-ai-tools (submodule or Copilot CLI plugin) or whenever
  a skill's configuration needs to be created or updated.
  Do not use for installing skills, and do not use for skills from other packages.
---

# Skills Config

Guides the user through the setup of all installed **MDA AI Tools** skills by following each skill's own `docs/setup.md`.

## When to Run

- Immediately after installing skills via `install.sh` or the Copilot CLI plugin
- When a skill fails because its config is missing or incomplete
- When the user wants to update an existing config (e.g. new MCP server name, new repo)

## Steps

### Step 1 — Detect Installed Skills

If the prompt specifies where skills were installed, search those directories. If no path is provided or no skills are found, follow the discovery instructions in [`reference/skill-discovery.md`](reference/skill-discovery.md). Skip `skills-config` itself.

### Step 1b — Check Template State

For each installed skill, check the state of each file in its `templates/` directory:

- **Has `{{` patterns** → needs configuration (proceed to Step 2)
- **No `{{` patterns, but a newer version exists in the submodule/plugin source** → offer to merge or override (see Step 2, item 2)
- **No `{{` patterns, matches source** → already configured and up to date; skip

If **all templates across all skills are up to date**: report this to the user and stop — this is the normal state after cloning a teammate's already-configured repo.

### Step 2 — Configure Each Skill

For each installed skill:

1. Read the skill's `docs/setup.md` — this is the authoritative guide for what the templates are, what each value means, and where the final configured files should be placed.

2. Find the skill's `templates/` directory inside the installed skill path (e.g. `.agents/skills/<skill>/templates/`, `.github/skills/<skill>/templates/`). List all files in it.

   For each template file that is **already configured** (no `{{` patterns), compare it against the source template from the submodule or plugin:
   - If the source template has **new fields or sections** not present in the configured file, ask the user:
     > "A newer version of `<filename>` is available. Would you like to **merge** new fields into your existing config, or **override** it entirely (your current values will be lost)?"
   - **Merge**: add only the new/missing fields from the source template, preserving all existing values. Show the diff to the user and ask for approval before writing.
   - **Override**: replace the file with the source template and proceed to fill in all placeholders from scratch (using auto-resolve + user input as normal).
   - If no new fields exist, the file is up to date — skip it.

3. **Kusto-specific bootstrap flow (required for `kusto` only).**
   Follow this order before filling placeholders for `kusto`:
   - **Step A — Scan workspace first**: search the current workspace recursively for `.kql` / `.csl` files, ` ```kusto ` fenced blocks in markdown, and cluster URIs in common config files (e.g. `appsettings*.json`, Helm values). Propose a draft from findings.
     Exclude the following paths from the scan to avoid false positives from skill files:
     - `**/skills/kusto/library/**`
     - `**/skills/kusto/templates/**`
     - `**/skills/kusto/docs/**`
     - `**/skills/*/templates/**`
     - `**/node_modules/**`
   - **Step B — If scan is empty or partial, switch to Paste queries**: ask the user to paste raw KQL (for example copied from Azure Data Explorer) and/or Kusto "Share query" URLs.
   - **Step C — Manual last**: use manual placeholder-by-placeholder questions only for values still missing after scan + paste.

   **For every pasted query**, ask only one extra question:
   - **"When should this query be used?"** (brief trigger/intent description)

   Keep user friction low:
   - do **not** ask separate title/definition questions,
   - auto-generate a short query title from the query shape + intent when needed.

   After saving each pasted query into `kusto-queries.md`, ask:
   - **"Add another query or done?"**
   Continue this loop until the user says done.

   If scan/paste yields partial data, continue by asking only for missing values.

4. For each file in `templates/`, fill in all `{{PLACEHOLDER}}` values:

   - **Auto-resolve first** — try to find the value before asking the user. Each source may fail; treat failures as "not found" and continue silently:
     - **From workspace context**: scan other config files in the project root (`*config.md`, `*.config.ps1`), `git remote -v`, `.git/config`, `package.json`, `*.csproj`, etc.
     - **From MCP tools**: if an ADO MCP server is connected, query it — e.g. `repo_list`, `project_list` to resolve org URL, project name, repository ID. If no ADO MCP server is available, fall back to Azure CLI: `az devops configure --list`, `az devops project list`, `az repos list`.
     - **From environment**: `$AZURE_DEVOPS_ORG`, `$SYSTEM_TEAMFOUNDATIONCOLLECTIONURI`, or other well-known env vars.
     - **From other skills**: reuse matching values already filled in other config files (e.g. `MCP_SERVER_NAME` or `ORGANIZATION_URL`).
   - For any placeholder that **could not be resolved automatically**, ask the user. Show the placeholder name and its inline comment so the user knows what to provide.

5. Ask the user for explicit approval before writing.

6. If the user requests changes, apply them and ask again. Do not save until approved.

7. Save the configured file **back to its original location** in the skill's `templates/` directory, overwriting the template with the fully configured values. Do not show the file diff in chat — notify the user that changes were made and can be reviewed in git.

8. After saving, scan for any remaining `{{` patterns as a safety check. If any are found, repeat from step 4.

Complete all steps for one skill before moving to the next.

### Step 3 — Summary

After all skills are configured, report:
- Which skills were set up successfully
- Which were skipped (already configured)
- Any remaining manual steps noted in the setup guides
