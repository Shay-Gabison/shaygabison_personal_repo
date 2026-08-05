---
name: pr-review-template
description: "STRICT immutable template for posting PR review requests to the MDA Platform Axon → PR Review Teams channel. Use whenever the user says 'send a PR review message', 'post to PR review', 'announce the PR', 'request review for PR X', or whenever a PR has just been published and needs broader review attention. Supports an OPT-IN cc mention folded into the greeting line (NOT a separate line above Thanks) when the user explicitly says 'cc {Name}', 'ping {Name}', or 'mention {Name}' — cc target must have a real Entra userId resolved via teams-GetUserPresence or teams-ListChannelMembers, never invented. Format is fixed — see the BLESSED EXAMPLES — and must not vary across messages. Local personal skill, not part of the upstream MDA.Platform.Squad.Skills repo."
domain: "communication, teams-messaging, personal"
confidence: "high"
source: "earned (May 2026 — pushed back on after I freelanced a 🤖 PR Ready for Review banner that lacked the Hi/@mention greeting)"
scope: "local-only — do NOT push into the upstream skills repo; the upstream pull-request-process skill is the team-shared one"
---

# PR Review Request Message — Strict Template (local)

## When to Use This Skill

- Just published a PR (out of draft) and need broader review attention.
- User says "send a PR review message", "post to PR review", "announce the PR", "request review for PR X".
- After internal lead approval, when external review is needed.

This is the **personal** template for the **MDA Platform Axon → PR Review** Teams channel. Do not invent a new shape per task — the channel's regulars expect this exact format.

## Channel mapping

- **Team:** MDA Platform Axon (id `829a2297-f598-45a6-bcaa-66a9d8ac3302`)
- **Channel:** PR Review (id `19:27a43689b9694916b088c63503925e9b@thread.tacv2`)
- **Tool:** `teams-SendMessageToChannel`

## The blessed template (do not deviate)

### Tool call shape (`teams-SendMessageToChannel`)

```json
{
  "teamId":      "829a2297-f598-45a6-bcaa-66a9d8ac3302",
  "channelId":   "19:27a43689b9694916b088c63503925e9b@thread.tacv2",
  "subject":     "{EMOJI} {Repo} PR {Number}",
  "contentType": "html",
  "content":     "{SEE BODY BELOW — HTML, NOT PLAIN TEXT}",
  "mentions":    "[{\"displayName\":\"PR Review\",\"id\":\"19:27a43689b9694916b088c63503925e9b@thread.tacv2\",\"type\":\"channel\"}]"
}
```

### Subject (rendered as bold header by Teams)

Format: `{Emoji} {Repo} PR {Number}`

**Emoji by PR type:**
- 🛡️ security / CVE bumps
- 📦 content / skills / docs
- ⬆️ dependency bump (non-security)
- 🐛 bug fix
- 🚀 feature
- 🔧 maintenance / cleanup / refactor

**Repo:** short repo name (segment after `_git/` in the PR URL — e.g. `TenantService`, `MDA.Prodstats`, `MDA.Platform.Squad.Skills`).

**Number:** numeric PR ID.

- ❌ Do NOT include the channel name ("PR Review", "Review request") in the subject — redundant with the channel.
- ❌ Do NOT bake the full PR title into the subject — it's already on the first body line as a link.

### Body (HTML — exact lines, exact order)

```html
Hi <at id="0">PR Review</at>,<br/>
🔗 <b>PR:</b> <a href="{PR_URL}">{PR_TITLE}</a><br/>
📝 <b>Summary:</b> {one-line description}<br/>
✅ <b>Status:</b> {short evidence line}<br/>
Thanks! 🙏
```

**Substitutions:**
- `{PR_URL}` = full `https://msazure.visualstudio.com/MCAS/_git/{repo}/pullrequest/{id}` URL
- `{PR_TITLE}` = the PR title as it appears in ADO (don't truncate — the link rendering handles it)
- `{one-line description}` = one sentence describing the change. Don't paste the whole PR description.
- `{short evidence line}` = the reviewer's quick-credibility cue. Pick the most relevant ONE:
  - `tested in STG`
  - `buddy build green — buildId {id}`
  - `content-only — no runtime impact`
  - `unit tests passing`
  - `Qualys + Docker Scout clean against rebuilt image`

### Default audience tag — "Tenant Management Champions" (Teams tag)

The MDA Platform Axon team has a Teams tag called **`Tenant Management Champions`** that maps to the on-call PR reviewers for tenant-management code. Posts about TenantService / TenantOperations / migration / TGCompress / TenantSync should target this tag in addition to the channel mention.

**Important Graph API limitation:** Teams tags can NOT be mentioned via the `teams-SendMessageToChannel` MCP tool. The supported mention types are `user`, `team`, `channel`, and `app` only — no `tag`. Looking up the tag id via Graph (`/teams/{id}/tags`) requires the `TeamworkTag.Read` scope which is also not granted to our CLI. So a real @-tag-mention can not be created from the API.

**Workflow for tag-targeted posts:**
1. Send the main message via `teams-SendMessageToChannel` with the standard `Hi <at id="0">PR Review</at>,` greeting — exactly as the BLESSED EXAMPLE below. Do NOT type "Tenant Management Champions" inline in the main message — that ends up as dead plain text that doesn't ping anyone and clutters the greeting.
2. Immediately follow up with `teams-ReplyToChannelMessage` to the message you just sent, body: `cc Tenant Management Champions 🙏`. The reply lands directly under the original post so reviewers see both as one thread.
3. Tell the user the reply was posted as plain text and that they can click the "Tenant Management Champions" text in the Teams web/desktop client to convert it to a real tag mention (one click — Teams auto-suggests the tag). Until they do that, the tag will NOT actually ping its members.

This two-step pattern (main message → reply with `cc Tag` text) is the established workflow for Shay's tenant-management PR posts. Use it whenever the PR touches tenant-management code OR whenever the user says "tag tenant management champions" / "ping the champions" / similar.

### Optional cc-mention in the greeting line (opt-in only)

When — and ONLY when — the user explicitly says "cc {Name}", "ping {Name}", or "mention {Name}" for a specific person (NOT for the Tenant Management Champions tag — that goes in a reply per the section above), **fold the cc mention into the greeting line itself**, separated by ` · `. Do NOT add a separate cc line above `Thanks! 🙏` — see hard rule #13 for why.

```html
Hi <at id="0">PR Review</at> · cc <at id="1">{Display Name}</at>,<br/>
🔗 <b>PR:</b> <a href="{PR_URL}">{PR_TITLE}</a><br/>
📝 <b>Summary:</b> {one-line description}<br/>
✅ <b>Status:</b> {short evidence line}<br/>
Thanks! 🙏
```

**Rules for the cc mention:**
- **Single greeting line.** All mentions live on line 1; everything below is content, and the body ends cleanly at `Thanks! 🙏`.
- Multiple cc'd people → multiple `<at>` tags on the same greeting line separated by spaces: `Hi <at id="0">PR Review</at> · cc <at id="1">A</at> <at id="2">B</at>,<br/>`.
- `id` indexes start at `0` for the channel mention; increment per user.
- Each cc'd user MUST have a matching entry in the `mentions` JSON array with `"type":"user"` and their resolved Entra userId (GUID). Resolve via `teams-GetUserPresence` or `teams-ListChannelMembers` first — never invent a userId. If multiple people match a first name, narrow via the PR Review channel member list before sending.
- Do NOT add a cc unprompted. This template's default is **no cc**. Never inferred from reviewer lists, code owners, or git blame.
- Channel mention is always first — cc is additive, never replaces `Hi @PR Review`.

**Example `mentions` JSON when cc'ing one user:**

```json
[
  {"displayName":"PR Review","id":"19:27a43689b9694916b088c63503925e9b@thread.tacv2","type":"channel"},
  {"displayName":"{Display Name}","id":"{userId-guid}","type":"user"}
]
```

## Hard rules

- `contentType` MUST be `"html"`. Plain text loses the labeled links and bold field names.
- Greeting + mention is the FIRST body line: `Hi <at id="0">PR Review</at>,` — paired with the `mentions` parameter that has the matching `id` (= the channelId for channel mentions).
- Links MUST be `<a href="…">DisplayText</a>`. Never paste raw URLs into the body — the PR link's display text is the PR title.
- Field labels are `<b>PR:</b>`, `<b>Summary:</b>`, `<b>Status:</b>` — bold tags required.
- Each line ends with `<br/>` except the last (`Thanks! 🙏`).
- Emoji prefix on each field line — 🔗, 📝, ✅ in that exact order. The greeting line has NO emoji prefix (the @mention is the visual anchor).
- NEVER include a `Build:` line or a `Work Item:` line as separate fields — fold either into `Status:` if relevant, or omit.
- NEVER use a 🤖 banner / "PR Ready for Review" headline. The channel context + the subject already convey that. The greeting is `Hi`, not a robot announcement.
- `subject` parameter MUST be set — never bake the title into the body.
- Always proofread before sending — esp. typos in PR title (copy-paste from ADO; do not retype).
- One PR per message. Don't batch multiple PRs into one message — Teams renders them as a single block and reviewers miss links.
- **Always preview to the user before sending.** Show the rendered HTML + the destination (MDA Platform Axon → PR Review) and wait for explicit go-ahead. Teams channel posts cannot be silently un-sent — `teams-DeleteChatMessage` returns "Requested API is not supported" for chatMessage. The only recovery is `teams-UpdateChatMessage` (edit visible as "edited" marker).
- **cc is OPT-IN ONLY and goes in the GREETING LINE** — include only when the user explicitly says "cc {Name}", "ping {Name}", or "mention {Name}". Fold the cc mention into the greeting line as `Hi <at id="0">PR Review</at> · cc <at id="1">{Name}</at>,<br/>` — never as a separate `cc` line above `Thanks! 🙏`. Each cc'd user's Entra userId MUST be resolved via `teams-GetUserPresence` or `teams-ListChannelMembers` — never invent a GUID, never send a bare display-name mention (it won't ping).
- **Aware of Teams' trailing mention-name suffix.** When a message has `<at>` mentions, the Teams renderer (notification view, activity feed, some preview surfaces) auto-appends the display name of every mentioned entity to the end of the message body. This is a Teams UX choice — you cannot suppress it via HTML payload. Concrete consequences: a body that ends `... Thanks! 🙏` will appear in some surfaces as `... Thanks! 🙏 PR Review` (channel mention) or `... Thanks! 🙏 PR Review Sivan Oddes` (channel + cc mention). Minimise the surprise by (a) keeping mentions concentrated in the greeting line, and (b) keeping the count low — one channel + at most a small number of users. Never add a mention "just to be safe" — every extra mention adds another name to the trailing suffix.

## BLESSED EXAMPLE

PR: https://msazure.visualstudio.com/MCAS/_git/MDA.Platform.Squad.Skills/pullrequest/15725006
Title: `feat: add vulnerability remediation skills + release-approval-template (CVE-bump end-to-end loop)`
Type: content-only skills PR

**Subject:** `📦 MDA.Platform.Squad.Skills PR 15725006`

**Body:**

```html
Hi <at id="0">PR Review</at>,<br/>
🔗 <b>PR:</b> <a href="https://msazure.visualstudio.com/MCAS/_git/MDA.Platform.Squad.Skills/pullrequest/15725006">feat: add vulnerability remediation skills + release-approval-template (CVE-bump end-to-end loop)</a><br/>
📝 <b>Summary:</b> 5 new skills covering the full container-image CVE remediation lifecycle (k8s/Helm loop, chef loop, scanner mechanics + scan-failure handling, pre-PR hygiene gate, prod approval-gate Teams template).<br/>
✅ <b>Status:</b> content-only — no runtime impact · inherited downstream via <code>squad upstream sync</code>.<br/>
Thanks! 🙏
```

**How it renders in Teams:**

> **📦 MDA.Platform.Squad.Skills PR 15725006**
>
> Hi @PR Review,
> 🔗 **PR:** [feat: add vulnerability remediation skills + release-approval-template (CVE-bump end-to-end loop)](https://msazure.visualstudio.com/MCAS/_git/MDA.Platform.Squad.Skills/pullrequest/15725006)
> 📝 **Summary:** 5 new skills covering the full container-image CVE remediation lifecycle (k8s/Helm loop, chef loop, scanner mechanics + scan-failure handling, pre-PR hygiene gate, prod approval-gate Teams template).
> ✅ **Status:** content-only — no runtime impact · inherited downstream via `squad upstream sync`.
> Thanks! 🙏

## BLESSED EXAMPLE — with Tenant Management Champions tag follow-up

PR: https://msazure.visualstudio.com/MCAS/_git/TenantService/pullrequest/15880356
Title: `[Migration] Unique helm release name per migration run`
Type: bug fix (concurrent-migration helm collision)
User asked: "tag tenant management champions"

**Subject:** `🐛 TenantService PR 15880356`

**Step 1 — main message body (via `teams-SendMessageToChannel`):**

```html
Hi <at id="0">PR Review</at>,<br/>
🔗 <b>PR:</b> <a href="https://msazure.visualstudio.com/MCAS/_git/TenantService/pullrequest/15880356">[Migration] Unique helm release name per migration run</a><br/>
📝 <b>Summary:</b> Make the helm release name + chart nameOverride unique per migration (<code>${serviceName}-${contextId[:8]}</code>) so two concurrent migrations stop colliding on the immutable K8s <code>Job.spec.template</code> — root cause of incident #38103109.<br/>
✅ <b>Status:</b> YAML-only · root cause from <a href="{TEAMS_INCIDENT_POST_URL}">Dror's incident post</a> · ready for review.<br/>
Thanks! 🙏
```

**Step 2 — reply via `teams-ReplyToChannelMessage` (`messageId` = the id returned from step 1):**

```html
cc Tenant Management Champions 🙏
```

**Why two messages instead of inline:** Teams tags can not be mentioned via the Graph API (only user/team/channel/app mentions are supported, and the tag-lookup endpoint requires a scope we don't hold). Posting the tag-name as plain text inside the main greeting (`Hi @PR Review · cc Tenant Management Champions,`) makes the greeting line look mentioned but doesn't actually ping the tag's members — worst of both worlds. Keeping the cc as a reply (a) keeps the main message clean and matches the BLESSED EXAMPLE shape, and (b) gives the user a single, easy place to click the words "Tenant Management Champions" in the Teams web/desktop client and convert them to a real tag mention (one click — Teams auto-suggests). After the user does that, the tag's members get pinged.

## BLESSED EXAMPLE — with cc-mention (opt-in)

PR: https://msazure.visualstudio.com/MCAS/_git/TenantService/pullrequest/15774719
Title: `TenantOperations: bump delete CLI HTTP timeout to 120s`
Type: maintenance / cleanup
User asked: "cc Sivan"

**Subject:** `🔧 TenantService PR 15774719`

**Body:**

```html
Hi <at id="0">PR Review</at> · cc <at id="1">Sivan Oddes</at>,<br/>
🔗 <b>PR:</b> <a href="https://msazure.visualstudio.com/MCAS/_git/TenantService/pullrequest/15774719">TenantOperations: bump delete CLI HTTP timeout to 120s</a><br/>
📝 <b>Summary:</b> Bump TenantServiceClient timeout from 30s → 120s in the delete CLI only — observed ReadTimeouts on the contextId-resolution GET burned all 4 Job retries against the consistent 30s ceiling.<br/>
✅ <b>Status:</b> unit tests passing — scope limited to delete.py, shared client default unchanged.<br/>
Thanks! 🙏
```

**Mentions JSON:**

```json
[
  {"displayName":"PR Review","id":"19:27a43689b9694916b088c63503925e9b@thread.tacv2","type":"channel"},
  {"displayName":"Sivan Oddes","id":"6e726dcc-0ef2-4242-ab3f-5f08450d8053","type":"user"}
]
```

> **Note:** even in this canonical shape, Teams' renderer will append `PR Review Sivan Oddes` after `Thanks! 🙏` in some surfaces (notification view, activity feed) — that's the trailing mention-name suffix described in hard rule #14 and is unavoidable. Keeping all mentions in the greeting line at least prevents the standalone cc line from rendering as a separate broken-up paragraph mid-body.

## CAUTIONARY EXAMPLE (what NOT to do)

```html
🤖 <b>PR Ready for Review</b><br/><br/>
<a href="https://msazure.visualstudio.com/MCAS/_git/MDA.Platform.Squad.Skills/pullrequest/15725006">feat: add vulnerability remediation skills</a><br/><br/>
<b>Summary:</b> 5 new skills.<br/>
<b>Build:</b> ✅ Passing<br/><br/>
Please review when you get a chance.
```

**What was wrong:**
- ❌ 🤖 `PR Ready for Review` banner — channel + subject already convey this; no robot greeting
- ❌ Missing `Hi <at id="0">PR Review</at>` greeting + mention as the first body line
- ❌ Missing emoji prefixes on the field lines (🔗 📝 ✅)
- ❌ Extra `Build:` field as its own line — fold into `Status:` if useful, else drop
- ❌ Ends with "Please review when you get a chance." instead of the canonical `Thanks! 🙏`
- ❌ No `subject` parameter set — Teams shows no bold header, just an inline title that competes with the channel banner

## Pre-flight check before sending

Run through this list mentally — if any answer is "no", DO NOT SEND:
- [ ] `contentType` is `"html"`?
- [ ] Subject is `{emoji} {repo} PR {number}`, no channel-name redundancy, no full title duplication?
- [ ] Body line 1 is `Hi <at id="0">PR Review</at>,<br/>`?
- [ ] Body lines 2–4 use the 🔗 / 📝 / ✅ emoji + `<b>label:</b>` + (optionally) `<a>display text</a>` shape?
- [ ] Last body line is exactly `Thanks! 🙏` (no `<br/>` after)?
- [ ] No 🤖 banner, no `Build:` line, no `Work Item:` line as separate fields?
- [ ] PR title copy-pasted from ADO (not retyped — typos here look unprofessional)?
- [ ] `mentions` param set with the PR Review channel id?
- [ ] If a cc is requested: it lives in the greeting line as `Hi <at id="0">PR Review</at> · cc <at id="1">{Name}</at>,<br/>`, NOT as a separate `cc` line above `Thanks! 🙏`?
- [ ] If a cc is present: user EXPLICITLY asked for it AND every cc'd user has a resolved Entra userId (GUID) in the mentions array?
- [ ] If the PR touches tenant-management code OR the user said "tag tenant management champions" / similar: queued a separate `teams-ReplyToChannelMessage` with body `cc Tenant Management Champions 🙏` to fire immediately after the main message — and noted to the user that they must click the tag text in Teams to convert it to a real tag mention?
- [ ] User has explicitly confirmed send (channel posts cannot be silently un-sent)?

## Related (local) skills

- `notify-to-self` — Teams self-DM (no preview gate needed) for personal-record copy of the same announcement
- `consolidated-infra-vuln-remediation` — vuln-remediation loop sends a PR review message via this template
- `container-vuln-loop` — chef-managed PRs that go to PR Review channel use this template
- `curated-lists` — local copy with channel/team mappings

## Notes

- This template is the personal/local refinement of what `pull-request-process` (upstream) Step 5 should look like. The upstream skill's inline template is older and uses the 🤖 banner — when working in the squad-skills repo, treat THIS skill as the source of truth for the actual outgoing message, regardless of what the upstream skill says.
- Peer to the (separately tracked) `release-approval-template` style for the Release approvals channel — same DNA, different destination + different opening (no `Hi` greeting for release approvals).
