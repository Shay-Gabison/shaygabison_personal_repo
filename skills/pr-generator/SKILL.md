---
name: pr-generator
description: >
  Use this skill when the user is ready to submit code changes for review — even if they say
  "I'm done", "open a PR", "write a pull request description", or "summarize my changes".
  Use it to generate a PR title and description from the git diff, extract linked work item IDs
  from the branch name or commits, and create the PR in Azure DevOps. Do not use for code review
  or merging — only for creating new pull requests.
---

# PR Generator

## Setup
For first-time configuration, follow [docs/setup.md](docs/setup.md).

## Configuration
Look for any file ending with `*config.md` in the current or parent directory. It provides the MCP server name, repository ID, and component area names.

For reference, see [templates/pr-generator-config.md](templates/pr-generator-config.md).
PR structure template: [templates/pull_request_template.md](templates/pull_request_template.md).

## Steps to Execute

1. Read the config file (`*config.md`)
2. Get current git diff
3. Extract work item ID(s) from branch name or commits — look for `#1234` (literal `#` followed by digits); if multiple IDs appear, include all of them
4. Determine change type: `feature`, `bugfix`, `enhance`, `perf`
5. Generate PR title: `<change-type>(area): one-liner description`
6. Generate PR description (under 4000 chars, bullet points, facts only)
7. Create PR via MCP tool `repo_create_pull_request`
8. Report PR URL

## PR Description Structure
- **What Changed** — files, scope, key components (2–4 sentences)
- **Why** — problem solved, business context (2–3 sentences)
- **Impact Analysis** — performance, security, dependencies (if applicable)
- **Quality Gates** — tests added/updated, docs status
- **Deployment Considerations** — migration steps, config changes (if applicable)

## Create PR
```json
{
  "repositoryId": "<from-config>",
  "sourceRefName": "refs/heads/<current-branch>",
  "targetRefName": "refs/heads/<target-branch-from-config>",
  "title": "<generated-title>",
  "description": "<generated-description>",
  "workItems": "<extracted-work-item-ids>"
}
```

> Use the `Base Branch` value from your `pr-generator-config.md` as the target branch (e.g. `main`, `develop`).
