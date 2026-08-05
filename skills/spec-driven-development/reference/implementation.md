# Work Item Implementation Process

<!-- 
PURPOSE: Implementation phase for ADO work items including coding, testing, PR creation, and monitoring.

WHEN TO USE:
- After design is approved
- After ADO subtasks are created (if applicable)
- Ready to start implementation

EXPECTED OUTPUTS:
- All subtasks (or single task) implemented and tested
- PRs created and linked to work items
- Progress documented and attached to ADO
- Work items updated with PR status
-->

Part of: [Spec-Driven Development](../SKILL.md)

**Phases Covered:** Phase 5 (Implementation Loop)  
**Prerequisites:** Approved design + ADO subtasks created (if applicable)  
**Deliverables:** All subtasks (or single task) implemented, tested, PR'd, and merged

---

## Phase 5: Implementation Loop

For each subtask or single task (respecting dependencies):

### 5.1 Task Preparation

1. **Load Context**
   <!-- Use read_file to load context from progress files -->
   - Load context from `.spec-driven-progress/{workItemId}/subtasks.md` (if subtasks exist)
   - Check prerequisites completed
   - Review design decisions from `.spec-driven-progress/{workItemId}/design.md`

2. **Update ADO**
   
   Use [Update Work Item](ado-operations.md#update-work-item) to set state to "Active" and assign to user

3. **Create Progress File**
   
   - For subtasks: `.spec-driven-progress/{workItemId}/subtask-{subtaskId}.md`
   - For single task: `.spec-driven-progress/{workItemId}/implementation.md`
   - Track implementation decisions
   - Note blockers and resolutions
   - Record time spent

### 5.2 Branch Creation with PR Dependency Check

**Step 1: Check Previous PR Status (If Applicable)**

If current subtask has a predecessor subtask, use [Get Pull Requests](ado-operations.md#get-pull-requests) to check status with source branch `feature/{workItemId}/{previousSubtaskId}/*` and status "Active"

**Step 2: Determine Base Branch**

Based on PR status:

**Case A: Previous PR Not Yet Merged**

```bash
# Inform user
echo "Previous subtask PR #{prId} is still open."
echo "Will base current branch on previous subtask branch to maintain dependency chain."

# Ask user confirmation
read -p "Proceed with branching from feature/{workItemId}/{previousSubtaskId}/{previousTitle}? (y/n) "

# If confirmed, checkout previous subtask branch
git checkout main
git pull origin main
git checkout feature/{workItemId}/{previousSubtaskId}/{previousTitle}
git pull origin feature/{workItemId}/{previousSubtaskId}/{previousTitle}

# Create new branch based on previous
git checkout -b feature/{workItemId}/{currentSubtaskId}/{currentTitle}
```

**Benefits:**
- Builds on previous changes
- Cleaner diff in current PR
- Avoids merge conflicts
- Maintains dependency chain

**Case B: Previous PR Merged**
```bash
# Branch from main as normal
git checkout main
git pull origin main
git checkout -b feature/{workItemId}/{currentSubtaskId}/{currentTitle}
```

**Case C: No Previous Subtask (First Subtask or Single Task)**
```bash
# Branch from main
git checkout main
git pull origin main
# For single task without subtasks:
git checkout -b feature/{workItemId}/{title}
# For first subtask:
git checkout -b feature/{workItemId}/{subtaskId}/{title}
```

**Step 3: Document Branch Strategy**


Update progress file:
```markdown
## Branch Information
- Branch: feature/{workItemId}/{subtaskId}/{title} (or feature/{workItemId}/{title} for single task)
- Based on: {main OR feature/{workItemId}/{previousSubtaskId}/{previousTitle}}
- Reason: {Previous PR #{prId} still open OR Previous PR merged OR First subtask/single task}
- Created: {timestamp}
```

### 5.3 Implementation

Follow your project's development standards and guidelines for:
- Development best practices and coding standards
- Configuration management patterns (if applicable)
- Logging, metrics, testing, and tracing requirements

**Continuous Progress Tracking:**

Update progress file with:
- Implementation decisions
- Patterns used
- Files modified
- Blockers encountered
- Solutions applied
- Time spent vs. estimated

### 5.4 Build & Test Verification


Run build and test commands as configured in your [spec-driven-config.md](../templates/spec-driven-config.md):
- **Build Command**: Run your project's configured build command
- **Test Command**: Run your project's configured test command
- **Coverage** (optional): Run coverage command if configured

Fix all warnings and errors before proceeding.

**If Build or Tests Fail:**

1. **Analyze the error** - Read error messages carefully
2. **Fix only the specific issue** - Do not reformat unrelated code
3. **Re-run build/tests** - Verify the fix works
4. **Document the issue** - Add to progress file for future reference
5. **If stuck, ask user for guidance** - Ask the user for guidance

**Rollback Options** (if changes cause problems):

```bash
# Undo all uncommitted changes
git checkout -- .

# Undo specific file
git checkout -- path/to/file

# Undo last commit (keep changes staged)
git reset --soft HEAD~1

# Undo last commit (discard changes) - USE WITH CAUTION
git reset --hard HEAD~1
```

**IMPORTANT**: Always ask user before executing any rollback command.

### 5.5 User Review

1. Present implementation
2. Demonstrate changes
3. Show test results
4. Explain decisions
5. Get approval to proceed

Address feedback if needed.

### 5.6 Pull Request Creation

**Pre-PR Checklist:**

Before creating PR, verify all quality gates from your project's development standards:

#### Code Quality
- [ ] Follows established patterns from project standards
- [ ] No hardcoded values (use configuration)
- [ ] Proper error handling implemented
- [ ] Logging added for key operations
- [ ] Metrics/monitoring added (if applicable)

#### Testing
- [ ] Unit tests written and passing
- [ ] Integration tests passing (if applicable)
- [ ] Test coverage meets project requirements
- [ ] Edge cases and error scenarios covered

#### Build & Configuration
- [ ] Builds successfully (no errors)
- [ ] No compiler/linter warnings
- [ ] Configuration updated (if needed)

#### Documentation
- [ ] Code comments for complex logic
- [ ] API documentation updated (if applicable)
- [ ] README updated (if needed)
- [ ] Progress files complete

#### Standards Compliance
- [ ] Project coding standards followed
- [ ] Code formatting matches project style
- [ ] Security best practices followed

#### Additional Checks
- [ ] Previous subtask PR status checked (if applicable)
- [ ] Branch strategy documented

**Commit Changes:**

**IMPORTANT: Present changes to user before committing!**


1. Show user what will be committed:
   ```bash
   git status
   git diff --stat
   ```

2. Present summary of changes to user

3. **Wait for user approval** (wait for explicit user confirmation)
   - **DO NOT commit without explicit user approval**

4. Once approved, commit:
   ```bash
   git add .
   # For subtasks:
   git commit -m "feat: {subtaskTitle} - #{workItemId}"
   # For single work item:
   git commit -m "feat: {workItemTitle} - #{workItemId}"
   ```

**Push Branch:**

**IMPORTANT: Get user approval before pushing to remote!**


1. Show commit that will be pushed:
   ```bash
   git log -1 --stat
   ```

2. Ask the user: "May I push this commit to the remote branch?"

3. Wait for explicit "yes" or "proceed" confirmation

4. Once approved, push:
   ```bash
   # For subtasks:
   git push origin feature/{workItemId}/{subtaskId}/{title}
   # For single task:
   git push origin feature/{workItemId}/{title}
   ```

**Determine PR Dependencies:**


Check if based on another feature branch:
```bash
git log --oneline --graph --decorate | head -20
```

**Create PR:**

**IMPORTANT: Get user approval before creating PR!**

1. **Prepare PR Details**: Generate PR title and description based on:
   - Git diff analysis
   - Work item requirements
   - Implementation summary from progress file

2. **Present PR to User** (wait for explicit user confirmation):
   - Show proposed PR title
   - Show proposed PR description (or summary)
   - List work items to be linked
   - **Ask: "May I create this PR?"**
   - **Wait for explicit "yes" or "proceed" confirmation**
   - **DO NOT create PR without explicit user approval**

3. **Create PR**: Once approved, use the PR creation method configured in `spec-driven-config.md`:
   - **Option A (Recommended)**: Read and follow your PR creation prompt (e.g., `pr-generator skill`)
   - **Option B**: Use the configured PR creation script 
   - **Option C**: Use MCP tool / Azure CLI as fallback

4. **Send Teams Notification** (optional): After PR creation, use the notification method configured in `spec-driven-config.md`:
   - **Option A**: Read and follow your Teams notification prompt (e.g., `teams-notifications skill`)
   - **Option B**: Use the configured notification script 

**Update Work Item with PR Link:**

After PR creation succeeds, use [Update Work Item](ado-operations.md#update-work-item) to:
- Set **Microsoft.VSTS.Scheduling.RemainingWork** to 0
- Set **System.State** to "Resolved"
- Add **System.History** comment with PR link

**Attach Progress to Work Item:**

After PR creation, use [Attach File to Work Item](ado-operations.md#attach-file-to-work-item) to attach `.spec-driven-progress/{workItemId}/subtask-{subtaskId}.md` (or `implementation.md` for single task) with comment "Implementation progress and documentation"

This preserves the context and decisions with the work item for future reference.

### 5.7 Monitor PR Review Status

After creating the PR, periodically check its status using [Get Single Pull Request](ado-operations.md#get-single-pull-request)

**Track Review Progress:**


Update progress file with:
```markdown
## PR Review Status
- PR ID: #{prId}
- Status: {Draft/Active/Completed}
- Created: {timestamp}
- Reviewers: {list}
- Approvals: {count}/{required}
- Comments: {count}
- Merge Status: {Pending/Approved/Blocked}
- Last Updated: {timestamp}
```

**Monitor Review Comments:**

If PR has review comments:
1. Review feedback in ADO
2. Document required changes
3. Address comments locally
4. Push updates to same branch
5. Re-request review if needed

**PR Merge Detection:**

When PR is merged:
1. Use [Update Work Item](ado-operations.md#update-work-item) to set state to "Closed" with history comment
2. Archive progress
3. Update dependency tracking
4. Notify that next subtask can begin (if applicable)

### 5.8 Move to Next Subtask (If Applicable)

**Pre-Transition Checks:**

Before moving to next subtask, verify:
- [ ] Current PR merged or explicitly approved to proceed
- [ ] No blocking review comments
- [ ] Work item marked as Closed in ADO
- [ ] Progress archived

**Transition Steps:**

1. Archive progress:
   
   ```bash
   mv .spec-driven-progress/{workItemId}/subtask-{subtaskId}.md \
      .spec-driven-progress/{workItemId}/completed/
   ```

2. Update `.spec-driven-progress/{workItemId}/subtasks.md` with completion status 

3. Check if next subtask has dependencies on current PR using [Get Work Item](ado-operations.md#get-work-item) with `expand: "relations"`

4. If next subtask depends on current subtask:
   - Wait for PR merge confirmation
   - Update base branch for next subtask
   - Inform user of dependency status

5. **Ask user approval to proceed** (wait for explicit user confirmation)
   - Present next subtask details
   - Confirm dependencies are satisfied
   - **Wait for explicit "yes" or "proceed" confirmation**
   - **DO NOT start next subtask without user approval**

6. Proceed to next subtask in dependency order

**For Single Task (No Subtasks):**

Skip to Phase 6 (Completion Process) once PR is merged.

---

## Phase 5 Completion Checkpoint

**Before proceeding to Phase 6 (or next subtask), verify ALL of the following:**

<!-- AI ASSISTANT: You MUST verify each item before proceeding -->

### For Each Subtask/Task:
- [ ] ✅ Context loaded from progress files (5.1)
- [ ] ✅ ADO work item state updated to "Active" (5.1)
- [ ] ✅ Branch created with correct base (5.2)
- [ ] ✅ Implementation complete per design (5.3)
- [ ] ✅ Build passes without errors (5.4)
- [ ] ✅ Tests pass (5.4)
- [ ] ✅ User approved implementation (5.5)
- [ ] ✅ **User approved commit** (5.6)
- [ ] ✅ **User approved push** (5.6)
- [ ] ✅ **User approved PR creation** (5.6)
- [ ] ✅ PR created and linked to work item (5.6)
- [ ] ✅ Progress file attached to work item (5.6)

### For Work Item Completion:
- [ ] ✅ All subtasks completed (or single task done)
- [ ] ✅ All PRs created
- [ ] ✅ **User approved moving to Phase 6**

**If any checkbox is NOT completed, DO NOT proceed. Go back and complete the missing step.**

---

**Workflow Navigation:**
← [Planning](planning.md) | ↑ [Skill Overview](../SKILL.md) | → [Completion](completion.md) | [ADO Operations](ado-operations.md)
