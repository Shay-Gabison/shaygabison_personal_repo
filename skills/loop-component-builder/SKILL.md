---
name: loop-component-builder
description: "Create a real Microsoft Loop page/component from supplied content. Prefer an official connected Loop or Loop Web Service operation and avoid browser automation. Use Playwright only as an explicitly approved fallback when no native creation operation is exposed. Do not build a Teams app, Adaptive Card project, SDK scaffold, or source-code prototype unless the user explicitly asks for developer integration."
domain: productivity
confidence: high
---

# One-Minute Loop Component Builder

Create a **real, visible Microsoft Loop artifact** in the user's Microsoft 365
tenant. Prefer a native service or MCP operation over browser automation. The
normal outcome is a working Loop page with the requested table, checklist,
tracker, notes, or structured content plus its private page link.

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

## Backend Selection

Target completion in about one minute.

1. Extract the title, content, rows, columns, and desired format from the user's
   request or attachment.
2. If the content is sufficient, do not ask questions.
3. Check connected tools for an officially exposed Loop creation operation.
4. Prefer operations equivalent to:
   - `create-page-in-workspace`
   - `modify-page`
5. If both operations are available, create and populate the page directly,
   verify the returned content, and return the page URL.
6. If no native operation is available, do not silently start Playwright. Use
   `ask_user` once for approval to use the signed-in Loop web app as a fallback.
7. If browser fallback is declined, stop with the exact missing capability.

Use `references/non-browser-options.md` for capability detection.

### Non-Browser Guardrails

- Microsoft Graph does not currently expose supported Loop page/component
  creation in the connected toolset.
- WorkIQ entity-path discovery must return an actual writable Loop path before
  using `create_entity`; do not invent one.
- Teams messaging can embed an existing `.loop` URL but cannot create the
  underlying Loop file.
- SharePoint Embedded and Fluid Framework create application-owned
  collaboration experiences, not a page in the user's Loop workspace.
- Do not call undocumented internal REST endpoints, scrape browser tokens,
  reconstruct policy-restricted documentation, or upload fabricated `.loop`
  file contents.

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

Use real Loop structures, not visual imitations:

- Insert **Checklist** from Loop's `/` menu instead of typing checkbox glyphs.
- Insert **Table** from Loop's `/` menu instead of pasting pipe-delimited text.
- Insert **Bulleted list** or **Numbered list** instead of typing bullet
  characters.
- Verify the accessibility snapshot exposes checkboxes, list items, or table
  cells matching the requested structure.

## Browser Fallback Workflow

Use this only after the user explicitly approves browser automation. Follow
`references/browser-playbook.md`. Prefer semantic UI operations and snapshots
over brittle coordinates. Do not use `browser_run_code_unsafe` as the default:
Loop's dynamic insert menu can make a single large script slower and less
reliable than a few targeted operations.

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
- Loop reports the page saved, or the content remains after a reload.
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
