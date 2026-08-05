---
name: icm-oncall
description: >
  Use this skill when the user wants the current on-call Primary Engineers (PE list) for the
  configured teams — triggered by phrases like "on-call list", "PE list", "who's on call", "IcM
  on-call", "on-call engineers", or "weekly on-call". It scrapes the IcM portal's current
  on-call view for each configured team (via Playwright browser automation, with an IcM MCP
  fallback), stores results in a local table, and prints a clean per-team Primary (and optional
  Backup) PE table. Do not use for creating IcM incidents, paging, or editing on-call schedules.
---

# IcM On-Call PE List Skill

Scrape the current on-call Primary Engineers for your configured teams from the IcM portal using Playwright browser automation.

## When to use

Trigger phrases: "on-call list", "PE list", "who's on call", "IcM on-call", "on-call engineers", "weekly on-call"

## Prerequisites

- Playwright MCP browser must be available
- User must be authenticated to Entra ID (SSO will handle IcM login automatically)
- A filled-in team registry config (see below)

## Team registry

This skill is **team-agnostic**: the list of teams to scrape is loaded from a config file, not
hardcoded. Before running, load `templates/icm-oncall-config.md` and read:

- **Default serviceId** — used for every team unless the team overrides it.
- **Team registry table** — one row per team (`Team ID`, `Team Name`, `IcM Queue`, optional
  `serviceId override`).

If the config file is missing or still contains `{{PLACEHOLDER}}` values, ask the user to fill
it in (copy the template and replace the placeholders) before continuing. Use each team's
`serviceId override` when present, otherwise the default serviceId.

## Workflow

### Step 1 — Create and reset the SQL tracking table

Create the table if it does not exist, then **clear any rows from a previous run** so the final
output never contains stale or duplicate on-call entries:

```sql
CREATE TABLE IF NOT EXISTS oncall (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  team_id INTEGER,
  team_name TEXT,
  role TEXT,
  alias TEXT,
  name TEXT
);

DELETE FROM oncall;
```

> If you need to keep history across runs, add a `run_id TEXT` column instead of deleting, set
> a unique `run_id` for this run, and filter every query below by it. Otherwise, the `DELETE`
> above is the simplest way to guarantee a clean snapshot.

### Step 2 — Scrape each team

Decide which **role** you are collecting for this pass — `Primary` (default) or `Backup` (see
Step 3). Use the same `ROLE` value in the JS filter, the SQL insert, and the final query.

For each team in the registry, do:

1. **Navigate** Playwright to (substitute the team's `serviceId` and `Team ID` from the config):
   ```
   https://portal.microsofticm.com/imp/v3/oncall/current?serviceId={SERVICE_ID}&teamIds={TEAM_ID}&scheduleType=current&shiftType=current&viewType=1
   ```
   - `{SERVICE_ID}` is the team's `serviceId override` if set, otherwise the default serviceId.
   - **Important**: Only ONE teamId per request. Comma-separated IDs cause `teamIds=NaN`.

2. **Evaluate** the scraping function in the page DOM (the `ROLE` literal below matches the
   role you are collecting this pass — `Primary` or `Backup`):
   ```javascript
   () => {
     const ROLE = 'Primary'; // or 'Backup'
     const rows = document.querySelectorAll('[role="rowgroup"] [role="row"]');
     const r = [];
     rows.forEach(row => {
       const c = row.querySelectorAll('[role="gridcell"]');
       if (c.length >= 3) {
         const role = c[0].textContent.replace(/Role\s*/, '').trim();
         const alias = c[1].textContent.replace(/Alias\s*/, '').trim();
         const name = c[2].textContent.replace(/LastName\s*/, '').trim();
         if (role === ROLE) r.push(alias + '|' + name);
       }
     });
     return r.join(';');
   }
   ```

3. **Handle empty results**: If the evaluate returns `""`, the team may have no on-call schedule
   configured. Take a snapshot to confirm — look for "No Results Were Found" in the page. If
   confirmed, insert an explicit `N/A` row so the team still appears in the final table:
   ```sql
   INSERT INTO oncall (team_id, team_name, role, alias, name)
   VALUES ({TEAM_ID}, '{TEAM_NAME}', '{ROLE}', 'N/A', 'N/A');
   ```

4. **Insert** results into SQL. Use the `{ROLE}` you are collecting (not a hardcoded `Primary`),
   and **escape single quotes by doubling them** (`'` → `''`) in `team_name`, `alias`, and
   `name` so values containing an apostrophe (e.g. `O'Brien`) produce valid SQL and cannot alter
   the statement:
   ```sql
   INSERT INTO oncall (team_id, team_name, role, alias, name)
   VALUES ({TEAM_ID}, '{TEAM_NAME}', '{ROLE}', '{ALIAS}', '{NAME}');
   ```
   Insert one row per engineer returned for the team.

### Step 3 — Also scrape Backup role (optional)

To also get backup PEs, run Step 2 a second time with `ROLE = 'Backup'`: set `ROLE` to
`'Backup'` in the JS filter **and** use `'Backup'` in the SQL insert (Step 2.4) **and** in the
final query (Step 4). Backup rows are stored alongside Primary rows in the same table,
distinguished by the `role` column.

### Step 4 — Present results

Query the table for the role(s) you collected and format as a clean ASCII table. For a
Primary-only run:

```sql
SELECT team_name, name, alias FROM oncall WHERE role = 'Primary' ORDER BY team_id;
```

When you also collected Backup, query both roles (or drop the `WHERE` clause) and group/label by
`role` in the output:

```sql
SELECT team_name, role, name, alias FROM oncall ORDER BY team_id, role;
```

Output format:
```
┌──────────────────────────────┬─────────────────────┬────────────────┐
│ Team                         │ Primary PE          │ Alias          │
├──────────────────────────────┼─────────────────────┼────────────────┤
│ Incident Manager             │ Jane Doe            │ janedoe        │
│ ...                          │ ...                 │ ...            │
└──────────────────────────────┴─────────────────────┴────────────────┘
```

Flag any teams with no schedule as `⚠️ No schedule`.

## Troubleshooting

- **SSO redirect**: First navigation may redirect to `login.microsoftonline.com`. Playwright handles this automatically if the user has an active Entra session.
- **IcM MCP alternative**: If the `icm` or `icm-mcp` MCP servers are working, prefer them over browser scraping. They have historically been unreliable (timeouts, scope errors).
- **Stale DOM**: If evaluate returns empty for a team that should have data, wait 2-3 seconds and retry, or navigate again.
- **Rate limiting**: IcM portal doesn't rate-limit page navigations, but keep a reasonable pace (no artificial delays needed between teams).
