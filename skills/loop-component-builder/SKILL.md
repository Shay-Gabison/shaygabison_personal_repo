---
name: loop-component-builder
description: "Create a real Microsoft Loop page/component from supplied content in under one minute using the existing signed-in Loop browser session. Use when the user says create a Loop, build a Loop component, put this in Loop, or turn content into a collaborative table/checklist/tracker. Skip API research and SDK scaffolding; create the visible artifact immediately and return its private Loop URL."
domain: productivity
confidence: high
---

# One-Minute Loop Component Builder

Create a **real, visible Microsoft Loop artifact** in the user's Microsoft 365
tenant in under one minute. Use the existing signed-in Loop browser session and
return the private page link.

## Primary Rule

**Create the Loop artifact, not code that could eventually create one.**

For a normal request, do not:

- Create a TypeScript project
- Install npm packages
- Research Teams SDK APIs
- Build an Adaptive Card
- Create a message extension
- Configure a bot, manifest, tunnel, SSO, or Azure deployment
- Explain architecture before acting

Those are a different developer scenario and do not satisfy "create a Loop."

## Sub-Minute Fast Path

Target completion in **45 seconds**, with a hard goal of less than 60 seconds.

1. Extract the title, content, rows, columns, and desired format from the user's
   request or attachment.
2. If the content is sufficient, do not ask questions.
3. Navigate directly to `https://loop.cloud.microsoft/`.
4. Run the consolidated fast script in `references/browser-playbook.md`.
5. Return the page title, item count, private URL, and measured elapsed time.

Do not search Graph, WorkIQ, Teams, documentation, APIs, packages, or MCP
capabilities during normal creation. Those checks already established that the
connected toolset has no native Loop creator and only add latency.

### Performance Budget

- Maximum normal browser calls: **2**
  1. Navigate to Loop
  2. Run the consolidated creation and verification script
- No preliminary snapshots.
- No per-action commentary.
- No Share or Copy-as-component dialog.
- No full-page screenshot.
- No SDK/package/API research.
- No reload in fast mode.
- No slash menu in fast mode.

The consolidated script must use:

- Stable role/test-id selectors
- `Meta+A` followed by `pressSequentially()` for the title
- A canvas click immediately after entering the title to commit/blur it
- One prepared plain-text block for all body content
- `canvas.pressSequentially()` with a very small delay for reliable editor input
- A short autosave wait
- Verification through the Title and Canvas textboxes

Format fast-mode content visibly:

- Checklist: `☐ Item`
- Bullets: `• Item`
- Numbered list: `1. Item`
- Table: tab-separated rows or aligned plain-text columns

This is still a real Loop page. It intentionally avoids native semantic
checkbox/table blocks because Loop's dynamic insert menu is not reliable enough
for a guaranteed sub-minute run.

If the user explicitly requires native interactive checkboxes, assignments,
dates, or a semantic Loop table, explain that semantic mode may exceed one
minute and use the slower insert-menu workflow only after confirmation.

If the consolidated script fails because the UI changed, take one snapshot and
finish with targeted operations. Do not restart the workflow.

## When One Question Is Necessary

Use `ask_user` once only when the request has no usable content. Ask for:

- **Title**
- **What to put in the Loop**

Do not ask about SDK, hosting, persistence, permissions, app IDs, frameworks, or
deployment.

If multiple writable workspaces are visible, default to the user's personal
workspace. Ask which workspace only when the user named a team/project but no
matching workspace can be identified safely.

## Content Mapping

Convert the user's material into the most useful Loop structure:

| User asks for | Create |
|---|---|
| Ownership, inventory, contacts, applications | Table |
| Tasks, action items, migration steps | Task list or checklist |
| Status, rollout, incident, weekly tracking | Status table |
| Meeting notes, proposal, summary | Headings with concise sections |
| Pros/cons or options | Comparison table |
| Raw pasted rows or Markdown table | Loop table preserving every row |

Preserve full names and values. Do not truncate rows, silently summarize a full
dataset, or omit entries to save time.

For tables:

- Use the user's requested columns in the same order.
- Include all supplied rows.
- Keep links clickable where the Loop editor supports them.
- Use concise column names.
- Do not add IDs or metadata the user did not request.

In fast mode, optimize for a complete visible artifact rather than native
interactive controls. Preserve every row/item and use clear plain-text markers.

## Browser Workflow

Follow `references/browser-playbook.md`. Use the consolidated operation. Its
script is fixed and reviewable: it interacts only with the current Loop page,
does not inspect tokens/cookies, and does not access the filesystem or execute
shell commands.

1. Navigate to `https://loop.cloud.microsoft/`.
2. Wait for the signed-in home page.
3. Create a new page.
4. Set the title immediately.
5. Insert the appropriate Loop content type.
6. Populate content in as few operations as possible:
   - Type `/`, select the semantic content type, and then enter the content.
   - For a table, paste tab-separated rows when the editor supports it.
   - For a checklist, insert **Checklist**, then enter items separated by Enter.
   - For prose, paste one prepared block.
7. Wait for autosave/saved state.
8. Re-read the page to confirm the first and last expected entries are present.
9. Capture the current browser URL.
10. Return the title, private page URL, workspace, and number of rows/items
    created.

Do not click **Share** or **Copy as Loop component** just to obtain a URL. Those
actions can open or create a broader organization-edit link. Use the current
`loop.cloud.microsoft/p/...` URL unless the user explicitly asks to share the
page or copy it as a portable component.

If browser authentication is missing, navigate to the sign-in screen and ask the
user to complete sign-in. Resume from the same browser session afterward.

## Safety and Permissions

- Create the page in a private/personal workspace by default.
- Do not share the page, add members, change permissions, or send its link to
  anyone without explicit user approval.
- Do not open the Share or Copy-as-component dialog during ordinary creation.
- Do not overwrite or delete an existing page unless explicitly requested.
- If a page with the same title exists, create a new page unless the user clearly
  asked to update the existing one.
- Never expose sensitive source data in the final response; return only the Loop
  link and a short creation summary.

## Verification

The task is complete only when:

- The Loop page is open and visible.
- Its title matches the request.
- The expected content is present.
- For a table, both the first and last expected rows are present.
- The autosave wait completes without a navigation warning.
- The current private `loop.cloud.microsoft` page URL is captured.

If a UI limitation blocks one formatting feature, create the closest useful Loop
structure and state the exact limitation. Do not replace the artifact with a
code project.

## Developer Mode: Explicit Opt-In Only

Only enter developer mode when the user explicitly says they want a **custom
Adaptive Card-based Loop component**, **Teams message extension**, **SDK**, or
**application source code**.

Before starting developer mode, state plainly:

> This creates application source code, not an immediately visible Loop page.
> It must be deployed and sideloaded, and the Adaptive Card-based Loop experience
> may not be available on every client.

Then ask for confirmation. If confirmed, follow current Microsoft Learn guidance
for Adaptive Card-based Loop components. Never silently switch a normal Loop
creation request into developer mode.

## Final Response

Keep it short:

```text
Created **<title>** in Microsoft Loop with <N> rows/items.

<Loop link>
```

Mention a blocker only if the artifact could not be created.
