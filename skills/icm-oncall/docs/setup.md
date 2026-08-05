# Setup: icm-oncall

This skill reads the IcM portal's current on-call view through a browser. It needs a
Playwright browser tool and an authenticated Entra session.

## Prerequisites

- **Playwright MCP browser** available to your agent. For Copilot CLI, add a `playwright` entry
  under `mcpServers` in `~/.copilot/mcp-config.json`.

  **Default (public npm):**

  ```json
  {
    "mcpServers": {
      "playwright": {
        "command": "npx",
        "args": ["-y", "@playwright/mcp@latest"],
        "disabled": false,
        "autoApprove": []
      }
    }
  }
  ```

  **Internal `agency` registry:** if your org installs MCP packages from an internal feed such as
  `agency`, point npx at that registry instead (replace the URL with your feed):

  ```json
  {
    "mcpServers": {
      "playwright": {
        "command": "npx",
        "args": [
          "-y",
          "--registry",
          "https://pkgs.dev.azure.com/msazure/_packaging/agency/npm/registry/",
          "@playwright/mcp@latest"
        ],
        "disabled": false,
        "autoApprove": []
      }
    }
  }
  ```

  For Claude/Cline/Cursor register the equivalent Playwright MCP in their settings.
- **`icm` / `icm-mcp` MCP server (optional, preferred).** If an `icm` / `icm-mcp` MCP server is
  available and reliable, the skill prefers it over browser scraping. Add an `icm-mcp` entry under
  `mcpServers` in `~/.copilot/mcp-config.json`:

  ```json
  {
    "mcpServers": {
      "icm-mcp": {
        "type": "http",
        "url": "https://icm-mcp-prod.azure-api.net/v1/",
        "disabled": false
      }
    }
  }
  ```

  For Claude/Cline/Cursor register the equivalent IcM MCP server in their settings.
- **Entra ID session.** You must be signed in to Microsoft Entra in the browser profile the
  MCP uses — IcM uses SSO, so an active session lets the portal load without an interactive
  login. The first navigation may redirect through `login.microsoftonline.com`.
- **IcM access** to your teams' on-call schedules.
- **Team registry config.** Copy `templates/icm-oncall-config.md` and fill in every
  `{{PLACEHOLDER}}` (see [Configuration](#configuration) below) before the first run.

## Verify

Ask your agent to "open the IcM on-call list" — if Playwright and your Entra session are
working, the portal loads the current on-call view without prompting for credentials.

## Configuration

The skill is team-agnostic; the teams it scrapes are defined in
`templates/icm-oncall-config.md`, not hardcoded in `SKILL.md`. To configure it:

1. Open `templates/icm-oncall-config.md` (it ships with `{{PLACEHOLDER}}` values).
2. Set the **Default serviceId** — the IcM serviceId used for every team unless overridden.
   Find it in the IcM portal URL when viewing your service's on-call.
3. In the **Team registry** table, add one row per team with:
   - `Team ID` (required) — the IcM team id. One id per row; comma-separated ids are not
     supported.
   - `Team Name` (required) — display name shown in the output table.
   - `IcM Queue` (optional) — for reference.
   - `serviceId override` (optional) — only for teams under a different service than the default
     (e.g. a Gov/Fairfax service id); leave blank to inherit the default.
4. Replace every remaining `{{PLACEHOLDER}}` and remove unused example rows.

`skills-config` writes back to this same file, so re-running configuration updates it in place.

## Notes

- Teams with no configured schedule are flagged rather than failing the run.
