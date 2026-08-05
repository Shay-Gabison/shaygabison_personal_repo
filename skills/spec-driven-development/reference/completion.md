# Work Item Completion Process

<!-- 
PURPOSE: Verify completion, update ADO, and clean up progress tracking

WHEN TO USE:
- All subtasks implemented and PRs created
- Ready to mark work item as complete
- Need to verify all PRs merged

EXPECTED OUTPUTS:
- Work item closed in ADO
- Documentation attached to work items
- Progress files cleaned up (optional)
-->

Part of: [Spec-Driven Development](../SKILL.md)

**Phases Covered:** Phase 6 (Work Item Completion)  
**Prerequisites:** All subtasks implemented and PRs created  
**Deliverables:** Work item verified, documented, and closed in ADO

---

## Phase 6: Work Item Completion

### 6.1 PR Merge Status Check

Before marking work item complete, verify all PRs are merged.

Use [Get Pull Requests](ado-operations.md#get-pull-requests) to list all PRs with source branch `feature/{workItemId}/*` and status "All"

**Review Results:**
- Count total PRs for work item
- Verify all are merged to main
- Check for any abandoned PRs
- Confirm no open draft PRs

**Handle Unmerged PRs:**

If any PRs not merged:
1. List unmerged PRs with status
2. Identify blocking issues
3. Ask user how to proceed:
   - Wait for merge approval
   - Abandon PR and rework
   - Continue with partial completion


Update progress file with merge status:
```markdown
## PR Merge Summary
- Total PRs: {count}
- Merged: {count}
- Pending Review: {count}
- Abandoned: {count}
- Blocking Issues: {list}
```

### 6.2 Verification

Checklist:
- [ ] All subtasks completed
- [ ] All PRs created and linked
- [ ] **All PRs merged to main**
- [ ] All tests passing
- [ ] Documentation updated
- [ ] Configuration generated (if applicable)
- [ ] No build warnings/errors

### 6.3 Update Work Item

Generate completion summary with PR links.

Use [Update Work Item](ado-operations.md#update-work-item) to:
- Set **System.State** to "Resolved" (or as user instructs)
- Add **System.History** comment with completion summary including:
  - Subtasks completed with PR links
  - Summary statistics (total subtasks, PRs, merge status)
  - Timeline (start date, completion date, duration)

### 6.4 Attach Work Item-Level Documentation

Attach remaining work item-level progress files to the work item.

Use [Attach File to Work Item](ado-operations.md#attach-file-to-work-item) to attach:
- `.spec-driven-progress/{workItemId}.md` - Work item progress summary
- `.spec-driven-progress/{workItemId}/discovery.md` - Discovery notes and codebase analysis
- `.spec-driven-progress/{workItemId}/subtasks.md` - Subtask breakdown and dependency map (if applicable)

**Note**: Design document was already attached in Phase 2.4, and subtask progress files were attached to their respective work items in Phase 5.6.

### 6.5 Local Progress Cleanup

Ask user if they want to delete local progress files. Present these options and wait for their choice:

- **Yes, delete all progress files** (`.spec-driven-progress/`)
- **No, keep the progress files** for local reference
- **Delete only this work item's files**

**If user chooses to delete all:**

```bash
# Remove entire progress directory
rm -rf .spec-driven-progress/

echo "✓ Deleted all local progress tracking files"
echo "✓ All documentation is preserved in ADO work items"
```

**If user chooses to delete only this work item:**
```bash
# Remove only this work item's files
rm -rf .spec-driven-progress/{workItemId}/

echo "✓ Deleted progress files for work item {workItemId}"
echo "✓ Documentation is preserved in ADO work item #{workItemId}"
```

**If user chooses to keep:**
```bash
echo "✓ Progress files retained in .spec-driven-progress/"
echo "  - Local files: .spec-driven-progress/{workItemId}/"
echo "  - ADO backup: All files attached to work items"
echo "  - These files are gitignored and won't be committed"
```

---

## Phase 6 Completion Checkpoint

**Before marking work item as complete, verify ALL of the following:**

<!-- AI ASSISTANT: You MUST verify each item before completing -->

### PR Verification:
- [ ] ✅ All PRs listed for work item (6.1)
- [ ] ✅ All PRs merged to main (6.1)
- [ ] ✅ No abandoned PRs requiring attention (6.1)

### Checklist Verification:
- [ ] ✅ All subtasks completed (or single task done) (6.2)
- [ ] ✅ All tests passing (6.2)
- [ ] ✅ Documentation updated (6.2)
- [ ] ✅ No build warnings/errors (6.2)

### ADO Updates:
- [ ] ✅ Work item state updated (6.3)
- [ ] ✅ Completion summary added to history (6.3)
- [ ] ✅ Progress documentation attached (6.4)

### Cleanup:
- [ ] ✅ **User chose cleanup option** (6.5)
- [ ] ✅ Cleanup executed per user choice (6.5)

### Final Confirmation:
- [ ] ✅ Work item is complete and properly documented in ADO

**If any checkbox is NOT completed, DO NOT mark work item as complete. Go back and complete the missing step.**

---

**Workflow Navigation:**
← [Implementation](implementation.md) | ↑ [Skill Overview](../SKILL.md) | [ADO Operations](ado-operations.md)
