# Loop Browser Fallback Playbook

Use this only after the user explicitly approves browser automation and no
official connected Loop creation operation is available.

The Loop UI changes over time. Use current accessibility snapshots and visible
labels instead of coordinates or a single brittle automation script.

## Efficient Creation Sequence

1. Navigate to `https://loop.cloud.microsoft/`.
2. Reuse the signed-in session.
3. Select **My workspace**.
4. Click **Create new** and select **Page**.
5. Enter the title:
   - Click the title textbox.
   - Select the existing `Untitled` text.
   - Use direct text insertion.
   - Fall back to sequential typing only if direct insertion does not persist.
6. Click the canvas and type `/`.
7. Select the real semantic structure:
   - Checklist
   - Table
   - Bulleted list
   - Numbered list
8. Insert all content with direct text insertion and Enter between items.
9. Wait briefly for autosave.
10. Reload once.
11. Verify the title, first and last content items, and semantic roles.
12. Return the current private `loop.cloud.microsoft/p/...` URL.

Do not take a full snapshot after every action. Use `browser_find` for the next
known label and use a full snapshot only when the expected control is missing.

Do not open **Share** or **Copy as Loop component** to obtain a URL. Those dialogs
can produce a broader organization-edit link.

## Fast Table Input

Prepare data as tab-separated values:

```text
Name	Owner	Status
Service A	alice	Ready
Service B	bob	In progress
```

Insert a Loop table, focus the first cell, and paste the TSV block. Verify the
editor expanded the table and retained the final row. If bulk paste fails, undo
once and populate rows through semantic controls.

## Verification

- Title matches exactly.
- First and last rows/items are present.
- Item count matches when practical.
- Checklists expose checkbox roles.
- Tables expose row and cell roles.
- Content remains after one reload.
- Current private Loop page URL is captured.

## Common Blockers

- **Sign-in required:** pause for the user to sign in, then resume.
- **No create permission:** switch to a writable personal workspace.
- **Direct insertion ignored:** use sequential typing for that field only.
- **Dynamic insert menu timeout:** use targeted `/` typing, `browser_find`, then
  click the current semantic menu item.
- **Share dialog opened accidentally:** close it without copying or changing
  permissions.

