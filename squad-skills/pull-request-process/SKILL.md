---
name: pull-request-process
description: "Pull request lifecycle and conventions for the MDA Platform. Use when opening a PR, preparing a PR for review, sending PR notifications, or managing the PR approval workflow. Covers work item linking, title/description standards, build validation, and review gates."
domain: "pull-request"
confidence: "high"
---

# Pull Request Process Skill

End-to-end PR lifecycle for MDA Platform teams: from opening a PR through internal review, build validation, and external review request.

## When to Use This Skill

- Opening a new pull request
- Preparing a PR description and title
- Sending PR review notifications
- Checking if a PR is ready for merge
- Managing the PR approval pipeline (internal → external)

## PR Lifecycle

```
┌──────────┐    ┌─────────────┐    ┌──────────────┐    ┌───────────────┐    ┌─────────┐
│ Open PR  │───►│ Internal    │───►│ Lead Reviews │───►│ External      │───►│  Merge  │
│ (draft)  │    │ Notification│    │ & Approves   │    │ Review Request│    │         │
└──────────┘    └─────────────┘    └──────────────┘    └───────────────┘    └─────────┘
     │                                    │                    │
     ├─ Link work item                    ├─ Lead must approve ├─ PR build must pass
     ├─ Meaningful title                  └─ Address feedback   └─ External review
     └─ Clear description
```

## PR Requirements Checklist

Before a PR can be sent for review, ALL of these must be satisfied:

| # | Requirement | How |
|---|------------|-----|
| 1 | **Work item linked** | Link an ADO work item to the PR. Use `az repos pr update --id {id} --work-items {work-item-id}` or link via the ADO UI |
| 2 | **Meaningful title** | Title should describe WHAT changed and WHY, not just a file name or ticket number. Example: `"Add retry logic for auth endpoint timeout (#42)"` |
| 3 | **Clear description** | Describe the change, motivation, and any testing done. Include context a reviewer needs |
| 4 | **Lead review and approval** | Team lead is a required reviewer. PR cannot proceed without lead approval |
| 5 | **PR build must pass** | The PR pipeline build must succeed. If it fails, fix the failures before requesting review |
| 6 | **Internal notification** | Send a Teams message to your team's PR channel for initial validation |
| 7 | **External review** | After internal approval, post to the broader review channel requesting external review |

## Step-by-Step Workflow

### Step 1: Open the PR

Create the PR with a meaningful title and description. Link the work item.

```bash
# Create PR via az CLI
az repos pr create \
  --title "Add retry logic for auth endpoint timeout" \
  --description "Adds exponential backoff retry for auth endpoint calls that timeout after 30s. Fixes intermittent 504 errors in production." \
  --work-items 12345 \
  --reviewers {LEAD_ALIAS}
```

### Step 2: Monitor the PR Build

The PR build pipeline must pass. Monitor it:

```bash
# Check PR build status
az repos pr show --id {pr-id} --query "status"
```

If the build fails, fix the failures before proceeding. A failing PR build blocks the entire review process.

### Step 3: Send Internal Notification

Once the PR is open and the build is green, send a Teams message to your team's **PR notification channel** for internal validation.

**Message format (HTML, 🤖 prefixed):**

```html
🤖 <b>PR Ready for Review</b><br/><br/>
<a href="{pr-url}">{pr-title}</a><br/><br/>
<b>Summary:</b> {short-description-of-change}<br/>
<b>Work Item:</b> <a href="{work-item-url}">#{work-item-id}</a><br/>
<b>Build:</b> ✅ Passing<br/><br/>
Please review when you get a chance.
```

Use `teams-PostChannelMessage` with `contentType: "html"`.

### Step 4: Wait for Lead Approval

The team lead reviews the PR. Address any feedback. This is a gate — do not proceed to external review until the lead explicitly approves.

### Step 5: Send External Review Request

After internal approval, post to the **external review channel** requesting broader review.

**Message format (HTML, 🤖 prefixed):**

```html
🤖 <b>PR Review Request</b><br/><br/>
<a href="{pr-url}">{pr-title}</a><br/><br/>
<b>Summary:</b> {short-description-of-change}<br/>
<b>Author:</b> {author}<br/>
<b>Work Item:</b> <a href="{work-item-url}">#{work-item-id}</a><br/><br/>
Ready for review. Thanks! 🙏
```

### Step 6: Merge

Once the PR has external approval and the build is green, merge:

```bash
gh pr merge {pr-number} --squash --delete-branch
# or
az repos pr update --id {pr-id} --status completed
```

## Teams Message Guidelines

- **Always use `contentType: "html"`** — plain text URLs won't render as clickable links
- **Use raw HTML tags** (`<b>`, `<br/>`, `<a href>`) — NOT escaped entities (`&lt;b&gt;`)
- **Prefix with 🤖** — bot messages are always emoji-prefixed
- **Include a hyperlink to the PR** — never paste a raw URL without an `<a href>` tag
- **Keep it concise** — reviewers should understand the change in 10 seconds

## Anti-Patterns

- **❌ NEVER open a PR without a linked work item** — all PRs must trace back to a work item
- **❌ NEVER skip internal notification** — lead reviews first, always
- **❌ NEVER post external review before lead approves** — internal gate before external review
- **❌ NEVER merge with a failing PR build** — fix failures first
- **❌ NEVER send Teams messages as plain text** — use HTML content type with proper `<a href>` hyperlinks
- **❌ NEVER use escaped HTML entities in Teams messages** — `&lt;b&gt;` renders as literal text, use `<b>` instead
- **❌ NEVER use a generic PR title** like "fix" or "update" — be descriptive
