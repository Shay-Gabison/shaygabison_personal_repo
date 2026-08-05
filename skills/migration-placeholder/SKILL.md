# Migration Placeholder Skill

Generate and send DBSet Operator migration placeholder notifications for any environment (STG, Prod3, Gov, etc.).

## Trigger Phrases
- "send migration placeholder for Prod3"
- "create migration event for Gov"
- "migration placeholder for <env>"
- "send placeholder for next environment"

## Workflow

1. **Ask the user** for:
   - Environment name (e.g., Prod3, Gov, Fairfax)
   - Migration window dates (start date + end date)
   - Any additional attendees beyond the default list

2. **Create a calendar event** via the Outlook MCP (`calendar-CreateEvent`) with:
   - Subject: `📢 [PLACEHOLDER] DBSet Operator Migration To Consolidated Infra — <ENV> Environment`
   - Show as: **Free**
   - Attendees: `shakura@microsoft.com` (Shmuel Akura) + any extras the user specifies
   - Body: the full HTML template below (with environment-specific values substituted)
   - Importance: high
   - No online meeting

3. **Ask the user for confirmation** before posting to Teams.

4. **If confirmed**, post the same content to the **Ops channel** using the teams-sender skill:
   ```bash
   bash /Users/shaygabison/.copilot/skills/teams-sender/send-message.sh \
     "https://teams.microsoft.com/l/channel/19%3A85bb72bb25164f04b8bd07bd25335647%40thread.skype/Ops?groupId=7544b4bb-29df-48d3-a90d-eb835f1124a6&tenantId=72f988bf-86f1-41af-91ab-2d7cd011db47" \
     "$MESSAGE"
   ```

## Template

Replace `{{ENV}}`, `{{DATE_RANGE}}`, and `{{PHASE_NOTE}}` with environment-specific values.

### Phase Notes per Environment
- **STG**: "STG is the full rehearsal before we proceed to Prod3."
- **Prod3**: "Prod3 is the primary production rollout. STG rehearsal completed successfully."
- **Gov / Fairfax**: "Gov rollout follows successful Prod3 stabilization."
- **Other rings**: "This ring follows successful Prod3 stabilization and expansion decision."

### HTML Body Template

```html
📢 <b>DBSet Operator Migration To Consolidated Infra — {{ENV}} Environment</b>
<br/><br/>
<table>
<tr><td><b>Status:</b></td><td>🟡 Planned</td></tr>
<tr><td><b>Environment:</b></td><td>{{ENV}}</td></tr>
<tr><td><b>Migration Window:</b></td><td>{{DATE_RANGE}}</td></tr>
<tr><td><b>Owners:</b></td><td>Shay Gabison, Shmuel Akura, Amit Cohen</td></tr>
<tr><td><b>Approver:</b></td><td>Yossi Matatov, Ohad Malinovsky</td></tr>
</table>
<br/>

<b>What is happening?</b><br/>
We are migrating the <b>DBSet operator</b> from the <b>DataFlux</b> deployment pipeline to the <b>Consolidated-Infra (EV2)</b> pipeline. This is a <b>lift-and-shift</b> of the operator binary — no schema changes, no data changes, no new functionality.<br/>
<b>{{PHASE_NOTE}}</b>
<br/><br/>

<b>What will be affected?</b><br/>
During the migration window, the following CRD types will temporarily have <b>no active operator</b> managing them until handed over:<br/>
<table>
<tr><th>CRD Type</th><th>Impact</th></tr>
<tr><td>MongoUser</td><td>Mongo user management paused</td></tr>
<tr><td>MongoDBSetEntry</td><td>DB secret reconciliation paused</td></tr>
<tr><td>CosmosTargetEntry</td><td>Cosmos target reconciliation paused</td></tr>
<tr><td>CollectionMappingEntry</td><td>Collection mapping reconciliation paused</td></tr>
<tr><td>CpanelDBSetEntry</td><td>Console Kusto configs unmanaged</td></tr>
<tr><td>RedisEntry</td><td>Redis secret reconciliation paused</td></tr>
<tr><td>MongoDBTagEntry</td><td>Ops Manager host tagging paused</td></tr>
</table>
<br/>
ℹ️ <b>No data loss or corruption is expected.</b> Existing secrets, mappings, and configurations remain in place.
<br/><br/>

<b>Migration approach</b><br/>
1. <b>Scale down</b> the old DataFlux operator to 0<br/>
2. <b>Clean up</b> any malformed/orphaned CRs in the namespace<br/>
3. <b>Deploy test CRs</b> — validate the new operator reconciles correctly<br/>
4. <b>Hand over components</b> in strict dependency order:<br/>
A0: Users (Mongo) → A: CRDs → B: Secrets → C: Console bundle → D: Mappings → E: Redis + Tags<br/>
5. <b>Validate</b> at every step before proceeding<br/>
6. <b>Stabilize</b> for ~1 week before proceeding to next environment
<br/><br/>

⚠️ <b>Rollback strategy</b><br/>
<b>Recovery ≤ 5 minutes</b> — at any point, we can scale the new operator to 0 and scale DataFlux back to 1. DataFlux deployment and configuration are kept fully intact throughout the migration window.
<br/><br/>

<b>Expected timeline</b><br/>
<table>
<tr><th>Time</th><th>Activity</th></tr>
<tr><td><b>Day 1 AM</b></td><td>Lock legacy/main, announce consolidated/main as SoT</td></tr>
<tr><td><b>Day 1 AM</b></td><td>Scale DataFlux to 0, clean up CRs, deploy new operator</td></tr>
<tr><td><b>Day 1</b></td><td>Test CRs → validate → begin component hand-over (A0 → A → B)</td></tr>
<tr><td><b>Day 1–2</b></td><td>Continue hand-over (C → D → E), validate at each step</td></tr>
<tr><td><b>Day 2–3</b></td><td>Final validation, stabilization monitoring begins</td></tr>
<tr><td><b>Day 3 EOD</b></td><td>Migration window closes; ~1 week soak period begins</td></tr>
</table>
<br/>

<b>What do we need from you?</b><br/>
• <b>Be aware</b> of the migration window — avoid scheduling deployments or changes to {{ENV}} CRD instances during this period<br/>
• <b>Report</b> any unexpected behavior in {{ENV}} services that depend on DB operator-managed resources<br/>
• <b>Escalation contact:</b> Shay Gabison (Teams / email)
<br/><br/>

<b>Links</b><br/>
• 📋 <a href="https://dev.azure.com/msazure/MCAS/_wiki/wikis/MCAS.wiki/985719/Infrastructure-and-Ops">Full Migration Plan (Wiki)</a>
<br/><br/>

<i>This is a placeholder notification. A final confirmation with exact times will be sent before the migration begins.</i>
```

### Calendar Event Parameters

| Parameter | Value |
|-----------|-------|
| subject | `📢 [PLACEHOLDER] DBSet Operator Migration To Consolidated Infra — {{ENV}} Environment` |
| startDateTime | User-provided start date, 09:00 |
| endDateTime | User-provided end date, 18:00 |
| timeZone | `Israel Standard Time` |
| showAs | `free` |
| importance | `high` |
| isOnlineMeeting | `false` |
| bodyContentType | `HTML` |
| attendeeEmails | `["shakura@microsoft.com"]` + any extras |

### Teams Channel Target

Ops channel: `https://teams.microsoft.com/l/channel/19%3A85bb72bb25164f04b8bd07bd25335647%40thread.skype/Ops?groupId=7544b4bb-29df-48d3-a90d-eb835f1124a6&tenantId=72f988bf-86f1-41af-91ab-2d7cd011db47`

Use the teams-sender skill script:
```bash
bash /Users/shaygabison/.copilot/skills/teams-sender/send-message.sh "<channel_url>" "<html_message>"
```
