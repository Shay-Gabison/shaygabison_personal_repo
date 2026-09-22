# Loop Web Creation Playbook

Use this only as an operational checklist. The Loop UI changes over time, so use
current accessibility snapshots and visible labels rather than fixed selectors.

## Minimal Creation Sequence

1. Open `https://loop.cloud.microsoft/`.
2. Confirm the expected Microsoft 365 account is signed in.
3. Select **Create new** or the current equivalent.
4. Create a page in the personal/default workspace.
5. Enter the title.
6. Insert content by pasting a prepared block.
7. Wait for autosave.
8. Verify content.
9. Copy the page link.

## Fast Table Input

Prepare data as tab-separated values:

```text
Name	Owner	Status
Service A	alice	Ready
Service B	bob	In progress
```

When supported by the current editor:

1. Insert a table with the required column count.
2. Focus the first cell.
3. Paste the full TSV block.
4. Verify the editor expanded the table and retained the final row.

If bulk paste does not expand correctly, undo once and populate rows through the
editor's semantic controls. Do not abandon the Loop artifact.

## Verification

- Confirm title text.
- Confirm expected column headers.
- Confirm first and last rows/items.
- Confirm total count when practical.
- Reload only if needed to verify autosave.
- Capture the canonical `loop.cloud.microsoft` link.

## Common Blockers

- **Sign-in required:** pause for the user to sign in, then resume.
- **No create permission:** switch to a writable personal workspace.
- **Clipboard permission:** use direct browser typing/fill operations.
- **Editor changed:** inspect a fresh browser snapshot and target visible labels.
- **Share dialog defaults to broad access:** cancel sharing and copy the private
  page link without changing permissions.

