# Configuration: aks-rightsizing

The install script copied [`templates/aks-rightsizing-config.md`](../templates/aks-rightsizing-config.md) into your installed skill directory. Follow the steps below to customize it for your team.

## Prerequisites

- A **Geneva MCP server** installed and registered with your agent host.
- **Access to `WCDProduction`** and the `WCDPRDInfraSystem` namespace.
- A service / cluster / namespace you can use for a quick verification query.

Optional but recommended:

- The [`pr-generator`](../../pr-generator/README.md) skill if you want the agent to open PRs from rightsizing recommendations.
- An **ADO MCP server** if you want the agent to create tracking User Stories for the follow-up work.

## 1. Configure the template

Run `skills-config` (or ask your agent to *"configure aks-rightsizing"*) to populate the template automatically.

If you prefer manual setup, open [`templates/aks-rightsizing-config.md`](../templates/aks-rightsizing-config.md) and replace every `{{PLACEHOLDER}}` with a real value. The most important placeholders are:

- `{{GENEVA_MCP_SERVER_NAME}}` — the MCP server key your agent host uses for Geneva.
- `{{ADO_MCP_SERVER_NAME}}` — the MCP server key for Azure DevOps work item operations.
- `{{ORGANIZATION_URL}}`, `{{PROJECT_NAME}}`, `{{AREA_PATH}}` — used only when the skill creates tracking work items.

## 2. Verify Geneva connectivity

After saving the config, run a small verification ask such as:

> "Using aks-rightsizing, discover the CPU usage metric in `WCDProduction` / `WCDPRDInfraSystem` and read the last hour of data for `<service>` in namespace `<namespace>` on cluster `<cluster>`."

The agent should:

1. Read `aks-rightsizing-config.md` first.
2. Use the configured Geneva MCP server name.
3. Discover or confirm the metric from the Geneva dashboard guide.
4. Query Geneva successfully with the required `container_name = wdatp-service` filter.

If this fails, fix Geneva MCP registration, authentication, or account access before relying on the skill for recommendations.

## 3. Dependencies

### Geneva MCP

This skill depends on Geneva Monitoring for utilization data. If the Geneva MCP server is not installed yet, [set that up first](https://eng.ms/docs/products/geneva/alerts/aiagentictools/genevamcpserver) and confirm it can read from `WCDProduction`.

### pr-generator skill

PR creation is delegated to `pr-generator`. Install that skill if you want the agent to turn a recommendation into a ready-to-review PR description and PR workflow.

### ADO MCP

ADO work item tracking is optional. If configured, the skill can create a User Story to track a rightsizing change using the ADO settings in the template.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Geneva tool calls fail before any data is returned | Geneva MCP server is not installed, not running, or the configured server name is wrong | Re-check the MCP registration and make sure the `MCP Server Name` in the template matches your host config exactly |
| Namespace or metric discovery returns nothing | Wrong account / namespace, or insufficient Geneva access | Confirm access to `WCDProduction` / `WCDPRDInfraSystem` and retry with the correct scope |
| PR generation stops after analysis | `pr-generator` is not installed | Install [`pr-generator`](../../pr-generator/README.md), then retry the PR request |
| Work item creation fails | ADO MCP not configured, or template placeholders are incomplete | Fill in the ADO section of the template and verify your ADO MCP connection |
