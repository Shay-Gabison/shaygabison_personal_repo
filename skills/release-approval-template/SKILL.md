---
name: release-approval-template
description: "STRICT template for posting an SDP release-approval ASK to the MDA Platform Axon → Release approvals Teams channel. Use whenever the user says 'send a release approval', 'post release approval', 'request release approval', 'ask for prod approval', 'SDP approval request', or whenever a build has reached an approval gate (e.g., PRD/STG/FAIRFAX/GOV) and needs an approver from the closed approvers list to sign off. The template is the SDP self-checklist the requester must answer in-thread: approvers, blast radius, testing, validation, rollback, deployment window, SDP compliance, and tooling. Format is fixed — see the BLESSED EXAMPLE — and must not vary across messages. Pairs with the release-monitor skill (which extracts the approval link) and teams-sender (release-approval alias). Local personal skill, not part of the upstream MDA.Platform.Squad.Skills repo."
domain: "communication, teams-messaging, release-management, sdp, personal"
confidence: "high"
source: "captured from the standard SDP release-approval checklist used by the MDA Platform Axon release approvers"
scope: "local-only — do NOT push into the upstream skills repo"
---

# Release Approval ASK Message — Strict Template (local)

## When to Use This Skill

- A pipeline has reached an approval gate (`*_APPROVAL` stage) and needs sign-off from the closed approvers list.
- User says: "send a release approval", "post release approval", "request release approval", "ask for prod approval", "SDP approval request".
- After running the `release-monitor` skill (which extracts the approval link), compose the ASK using THIS template.

This is the **personal** template for the **MDA Platform Axon → Release approvals** Teams channel. The channel's approvers expect this exact SDP checklist — do not invent a new shape per release.

## Channel mapping

- **Team:** MDA Platform Axon
- **Channel:** Release approvals
- **Alias (teams-sender):** `release-approval` (auto @mentions the channel)
- **Tool:** `~/.copilot/skills/teams-sender/send-message.sh release-approval "<message>"` OR direct `teams-SendMessageToChannel`

## The blessed template (do not deviate)

### Header block

```
🚀 <Service> <ENV> Release Approval — <one-line headline of the change>

Build: <buildNumber>
🔗 Build: <build_url>
👉 Approve Here: <approval.azengsys.com URL>
⏰ Approval expires: <date>
```

### SDP self-checklist (the ASK body)

The requester answers each question inline. Keep answers terse — one line each where possible. **Every section is required** — if a section truly does not apply, write `N/A — <one-sentence reason>`, never omit the heading.

```
**Approval service**

**Who is allowed to approve changes**
• Closed approvers list — <names or "see channel pinned approvers list">

**What is the approval process?**
• All approvals go into Axon Release Approvals channel only. No private approvals.

**What is exactly changing since last release**
• <bullet 1 — PR/commit + 1-line description>
• <bullet 2 …>
• Diff: <link to release diff / compare URL>

**What is the blast radius?**
• Scope: <1 tenant | 1 ring | 1 team | all teams | all prods>
• Communicated: <yes — link to comms thread | N/A — internal-only>

**How was it tested**
• <unit tests | integration tests | STG soak | buddy build | manual repro — pick the strongest evidence>
• Evidence: <buildId / test run link / STG validation link>

**How to validate deployment's success/failure**
• Success signal: <metric / dashboard / log query that proves the change works>
• Failure signal: <metric / alert that fires on regression>
• Dashboard: <link>

**What's the rollback strategy**
• <revert PR + redeploy | feature flag off | EV2 rollback to previous version | manifest pin to prior tag>
• ETA to rollback: <minutes>

**When can changes be made, and what kind of changes?**
• Window: Sunday–Wednesday, 08:00–15:00 ILDC ✅ (or ⚠️ outside window — M2 approval: <link/name>)
• Ring/Tenant migration: <N/A | discussed separately in <link>>

**How do you make sure no one deploys to production from their own private test environment?**
• SDP compliance:
  – RS: ≥ 1 day ✅
  – PROD-3: ≥ 1 day ✅
  – All public prods: ≥ 1 day ✅
  – GOV: <status>
• No manual changes in PROD ✅

**Which tools touched production for this change?**
• <Code changes (Service / ConfigGen) | Ev2 Shell Extension | Geneva Actions | Manual ops — outage only>
```

End the message with:

```
Requesting approval 🙏
```

## Hard rules

- **Every checklist heading is required** — never omit. If a question does not apply, write `N/A — <reason>`.
- **Headings use `**bold**` markdown** — they render as visual anchors in Teams; the approver scans top-to-bottom.
- **Window line MUST explicitly state ✅ in-window OR ⚠️ + M2 approval reference** — approvers reject silently-out-of-window asks.
- **SDP soak times MUST be answered with concrete ✅/❌/duration** — "yes" alone is not enough; the soak ladder (RS → PROD-3 → public prods → GOV) is the SDP load-bearing claim.
- **Blast radius MUST pick one of the canonical scopes** — `1 tenant`, `1 ring`, `1 team`, `all teams`, `all prods`. Do not invent new buckets.
- **Rollback strategy MUST state the mechanism AND an ETA in minutes** — "we'll revert" with no ETA is rejected.
- **Tools list MUST match the closed allowed-tools set**: Code (Service/ConfigGen), Ev2 Shell Extension, Geneva Actions, Manual ops (outage only). Anything outside this list is an SDP violation and must NOT be silently included — call it out explicitly with `⚠️ out-of-policy tool: <name>` and route to M2.
- **Header line MUST be `🚀 <Service> <ENV> Release Approval — <headline>`** — the env in caps (e.g., `STG`, `PRD`, `FF`, `GOV`).
- **Build + Approve links MUST be on their own lines** with the 🔗 / 👉 / ⏰ emoji prefixes for scannability.
- **`release-approval` alias is REQUIRED** — it auto-@mentions the channel; without it approvers miss the ping.
- **One release per message.** Don't batch multiple gates (e.g., STG + PRD) into one ASK — each gate needs its own auditable thread.
- **NEVER auto-approve, never request approval from a specific named person in the body** — the closed approvers list is the only authority; tagging individuals creates pressure and breaks the closed-list rule.
- **NEVER include secrets, customer tenant IDs, or PII** — these messages are persistent and searchable.
- **Always preview to the user before sending.** Teams channel posts cannot be silently un-sent — `teams-DeleteChatMessage` returns "Requested API is not supported". The only recovery is `teams-UpdateChatMessage` (edit visible as "edited" marker).

## BLESSED EXAMPLE

Scenario: TenantService PRD release, fixes cross-tenant auth trigger regression, deploying in-window on a Tuesday at 10:30 ILDC.

```
🚀 TenantService PRD Release Approval — Fix cross-tenant auth trigger regression

Build: 20260527.3
🔗 Build: https://msazure.visualstudio.com/MCAS/_build/results?buildId=160534110
👉 Approve Here: https://approval.azengsys.com/approvalRequest?id=a1b2c3d4-e5f6-7890-abcd-ef0123456789
⏰ Approval expires: 2026-05-27 18:00 UTC

**Approval service**

**Who is allowed to approve changes**
• Closed approvers list — see channel pinned approvers list

**What is the approval process?**
• All approvals go into Axon Release Approvals channel only. No private approvals.

**What is exactly changing since last release**
• PR 15774719 — TenantOperations: bump delete CLI HTTP timeout to 120s
• PR 15775022 — Fix cross-tenant auth trigger event filter
• Diff: https://msazure.visualstudio.com/MCAS/_git/TenantService/branchCompare?baseVersion=GTrelease/20260520&targetVersion=GTrelease/20260527

**What is the blast radius?**
• Scope: all prods
• Communicated: yes — https://teams.microsoft.com/l/message/19:...@thread.tacv2/1716800000000

**How was it tested**
• Unit tests + STG soak (24h, no regressions in auth-trigger dashboard)
• Evidence: buildId 160520044 (STG) — https://msazure.visualstudio.com/MCAS/_build/results?buildId=160520044

**How to validate deployment's success/failure**
• Success signal: auth-trigger success rate ≥ 99.95% on TenantService-Auth dashboard within 30 min
• Failure signal: AuthTriggerFailureRate alert (P2) fires on regression
• Dashboard: https://jarvis-west.dc.ad.msft.net/dashboard/MDA/TenantService/AuthTrigger

**What's the rollback strategy**
• EV2 rollback to previous version (build 20260520.5)
• ETA to rollback: 15 min

**When can changes be made, and what kind of changes?**
• Window: Sunday–Wednesday, 08:00–15:00 ILDC ✅ (Tuesday 10:30 ILDC)
• Ring/Tenant migration: N/A — code-only change

**How do you make sure no one deploys to production from their own private test environment?**
• SDP compliance:
  – RS: ≥ 1 day ✅ (deployed 2026-05-24)
  – PROD-3: ≥ 1 day ✅ (deployed 2026-05-25)
  – All public prods: ≥ 1 day ✅ (deployed 2026-05-26)
  – GOV: pending this approval
• No manual changes in PROD ✅

**Which tools touched production for this change?**
• Code changes (Service)

Requesting approval 🙏
```

## CAUTIONARY EXAMPLE (what NOT to do)

```
@channel Need approval for TenantService prod build please 🙏
Build: https://...
Link: https://approval.azengsys.com/...
Small fix, low risk. Tested in STG. Will rollback if anything breaks.
Thanks!
```

**What was wrong:**
- ❌ Skipped the SDP checklist entirely — approvers cannot audit blast radius, soak times, rollback ETA, or tool compliance
- ❌ "Small fix, low risk" is the requester's opinion — approvers need the evidence, not the conclusion
- ❌ "Will rollback if anything breaks" has no mechanism or ETA — unactionable
- ❌ No deployment-window claim — approver has to check the clock themselves
- ❌ Missing 🚀 header line + ENV — the channel scrolls fast; without the header line the ask is missed
- ❌ Used `@channel` instead of the `release-approval` alias auto-mention — risks no-ping if the channel mention doesn't resolve
- ❌ No expiration shown — approvers don't know if there's time pressure

## Pre-flight check before sending

Run through this list mentally — if any answer is "no", DO NOT SEND:

- [ ] Header line is `🚀 <Service> <ENV> Release Approval — <headline>`?
- [ ] Build + Approve link + Expiry all present with 🔗 / 👉 / ⏰ prefixes on their own lines?
- [ ] **All 9 SDP checklist headings present** (Approval service, Who-approves, Approval-process, What's-changing, Blast-radius, How-tested, How-to-validate, Rollback, Deployment-window, SDP-compliance, Tools)?
- [ ] Blast radius uses a canonical scope (1 tenant | 1 ring | 1 team | all teams | all prods)?
- [ ] Deployment window line has ✅ in-window OR ⚠️ + M2 approval reference?
- [ ] SDP soak ladder answered with concrete ✅/duration per ring (RS, PROD-3, public prods, GOV)?
- [ ] Rollback strategy states a mechanism AND an ETA in minutes?
- [ ] Tools list only contains entries from the closed allowed-tools set (Code / Ev2 Shell / Geneva Actions / Manual-during-outage)?
- [ ] No secrets, customer tenant IDs, or PII in the body?
- [ ] Sent via the `release-approval` alias (auto-mentions the channel)?
- [ ] User has explicitly confirmed send?

## End-to-end workflow (with companion skills)

```
1. release-monitor      → polls the build, extracts approval URL + expiry
2. release-approval-template (THIS skill)
                        → composes the SDP ASK using the extracted link
3. teams-sender         → sends to `release-approval` channel alias (auto-mention)
4. User awaits approval in the channel thread (no private DMs)
```

## Related (local) skills

- `release-monitor` — extracts the OneBranch approval link from the build timeline
- `teams-sender` — `release-approval` alias for the destination channel
- `pr-review-template` — peer template for the PR Review channel (same DNA, different destination + greeting)

## Notes

- The SDP checklist is the **load-bearing contract** between requester and approver. It exists so approvers can answer "should this go to prod?" in under 60 seconds without having to dig into PRs, dashboards, or Slack archives. Every shortcut here costs the approver minutes — and costs the requester re-asks.
- The closed approvers list lives in the channel pinned messages — never hardcode names in this template.
- If a release truly does not fit the SDP checklist (e.g., emergency hotfix during outage), call out `⚠️ Emergency / SDP exception` in the header line and tag M2 explicitly in the body — but this is the exception, not a different template.
