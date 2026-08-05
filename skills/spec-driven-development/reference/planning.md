# Work Item Planning Process

<!-- 
PURPOSE: Planning phase for ADO work items including discovery, design, and subtask breakdown.

WHEN TO USE:
- Starting any new ADO work item (Story, Task, Bug, Feature, Epic)
- After user provides work item ID or requirements
- Before implementation begins

EXPECTED OUTPUTS:
- Work item initialized in ADO 
- Approved design document 
- Subtask breakdown if needed 
- Progress tracking initialized 
-->

Part of: [Spec-Driven Development](../SKILL.md)

**Phases Covered:** Phase 1-4 (Work Item Initialization through ADO Work Item Creation)  
**Prerequisites:** User provides work item ID or requirements for new work item  
**Deliverables:** Approved design + ADO subtasks created (if needed) with progress tracking initialized

---

## Phase 1: Work Item Initialization & Research

User can either:
1. **Provide a work item ID** for an existing work item
2. **Request creation of a new work item** based on requirements they'll provide

### 1.0 Determine ADO Integration Method (First Time Only)

**Before any ADO operations, determine how to interact with Azure DevOps:**

1. **Check for MCP ADO Server**:
   - Read `spec-driven-config.md` to get the configured MCP server name
   - Look for connected MCP servers matching the configured name
   - Check available MCP tools for ADO-related operations
   - **Note**: MCP tool names and schemas shown in this workflow are examples. Always verify actual tool names and arguments from the connected MCP server's documentation, as they may differ between implementations.

2. **If MCP server found**:
   - Store server name in progress tracking: Add to `.spec-driven-progress/{workItemId}.md`:
     ```markdown
     ## ADO Integration
     - Method: MCP
     - Server Name: {mcpServerName}
     ```
   - Use MCP tools throughout workflow (as shown in MCP examples)

3. **If no MCP server found**:
   - Ask user: "No MCP ADO server detected. Use Azure CLI for ADO operations?"
   - Store in progress tracking: Add to `.spec-driven-progress/{workItemId}.md`:
     ```markdown
     ## ADO Integration
     - Method: Azure CLI
     - Organization: {organizationUrl from config}
     - Project: {projectName from config}
     ```
   - Use Azure CLI commands throughout workflow (see [ado-operations.md](ado-operations.md))

4. **If unsure, ask user**: "Which method should I use for Azure DevOps operations: MCP server or Azure CLI?"

### 1.1 Query or Create Work Item

**If user provided a work item ID:**

Query work item details - see [Get Work Item](ado-operations.md#get-work-item) 

Extract:
- Work Item Type (User Story, Task, Bug, Feature, Epic)
- Title and Description
- Acceptance Criteria (if applicable)
- Current State
- Assignee
- Area Path
- Iteration Path
- Tags
- Parent/Related Work Items

**Verify Parent Hierarchy:**

The proper ADO hierarchy is: **Epic → Feature → User Story → Task/Bug**

1. Check if work item has a parent:
   - If parent exists, note the hierarchy chain
   - If no parent exists, determine if one should be set

2. **If work item lacks expected parent:**
   
   Present to user:
   "This {workItemType} doesn't have a parent work item. The standard hierarchy is:
   - Epic → Feature → User Story → Task/Bug
   
   Would you like to:
   1. Set up parent hierarchy (I can help create missing parent work items)
   2. Link to an existing parent work item (provide the parent ID)
   3. Skip parent setup (work item stands alone)
   
   Note: Proper hierarchy helps with:
   - Portfolio planning and tracking
   - Sprint planning and capacity
   - Progress rollup and reporting"

3. **If user chooses to set up hierarchy:**
   - Ask for parent work item details (type, title, description)
   - Create parent work item(s) as needed
   - Link current work item to parent
   - Update progress tracking with hierarchy information

4. **If user provides existing parent ID:**
   - Verify parent exists and is appropriate type
   - Link work items using MCP tool or Azure CLI
   - Update progress tracking with parent reference

5. **Document hierarchy in progress file:**
   ```markdown
   ## Work Item Hierarchy
   - Epic: #{epicId} - {epicTitle}
   - Feature: #{featureId} - {featureTitle}
   - Story: #{storyId} - {storyTitle}
   - Current: #{workItemId} - {title}
   ```

**If description is empty or unclear:**
1. Ask user to provide requirements or explain the work item in detail
2. Once you have a clear picture, write a comprehensive description
3. Present the description to user for approval
4. Update the ADO work item with the approved description

**If user wants to create a new work item:**
1. Ask what type of work item (User Story, Task, Bug, Feature, Epic)
2. Gather requirements from user
3. **REQUIRED: Gather metadata before creating the work item:**
   - **Tags**: Ask user which tags should be applied (required - don't proceed without tags)
   - **Iteration Path**: Ask user which sprint/iteration to assign (required - don't proceed without iteration)
   - **Priority/Urgency**: Any time constraints
   - **Related Work**: Dependencies on other work items
   - **Parent Work Item**: If this work item should have a parent, get the parent ID
4. Draft work item title, description, and acceptance criteria (if applicable)
5. Present to user for approval
6. **Validate Required Fields**: Confirm that tags and iteration path are provided before proceeding
7. Create work item in ADO with all gathered information
7. Use the returned work item ID for rest of workflow

### 1.2 Gather Additional Context from User (For Existing Work Items)

**Extract context from work item:**
- Tags (if already set)
- Iteration Path (if already set)
- Related work items

**Present extracted context to user and ask for confirmation:**
"Based on the work item, I found:
- Tags: {extracted tags or 'None'}
- Iteration Path: {extracted iteration or 'Not set'}
- Related Work: {related items or 'None'}

These values will be used for all subtasks (if needed). Would you like to:
1. Use these values as-is
2. Modify any of these values
3. Add missing values"

**If user chooses to modify or add:**
- Ask for specific changes needed
- **Tags**: Which tags should be applied
- **Iteration Path**: Which sprint/iteration
- **Priority/Urgency**: Any time constraints
- **Related Work**: Dependencies on other work items

### 1.3 Initialize Progress Tracking (MANDATORY)

**Progress tracking is required for ALL work items to maintain context across sessions.**

**Step 1: Create Progress Directory Structure**


```bash
# Create progress tracking directory
mkdir -p .spec-driven-progress/{workItemId}
mkdir -p .spec-driven-progress/{workItemId}/completed

echo "✓ Created progress tracking directories"
echo "✓ Progress files are gitignored and won't be committed"
```

**Step 2: Create Progress Files**


Create `.spec-driven-progress/{workItemId}.md`:
```markdown
# {WorkItemType}: {Title}

## Work Item Information
- **ID**: #{workItemId}
- **Type**: {workItemType}
- **Title**: {title}
- **State**: {state}
- **Iteration**: {iterationPath}
- **Tags**: {tags}
- **Created**: {timestamp}

## Description
{description from ADO}

## Acceptance Criteria
{acceptance criteria from ADO if applicable}

## Progress Status
- Research: Not Started
- Design: Not Started  
- Subtask Breakdown: Not Started (if needed)
- Implementation: Not Started
- Completion: Not Started

## Quick Links
- [ADO Work Item]({organizationUrl}/{projectName}/_workitems/edit/{workItemId})
- [Design Doc](./{workItemId}/design.md)
- [Subtask Breakdown](./{workItemId}/subtasks.md) (if applicable)
- [Research Notes](./{workItemId}/research.md)

## Timeline
- Initialized: {timestamp}
- Updated: {timestamp}
```

### 1.4 Gather Research Context from User

**Before starting research, ask user for additional context that may help:**

"Before I begin researching this work item, do you have any additional context that could help?

Please share any of the following if available:
- **Repository links**: Related repos, sample implementations, reference code
- **Documentation links**: Microsoft Learn articles, design docs, specs
- **Articles/Blog posts**: Relevant technical articles or blog posts
- **API documentation**: Swagger specs, SDK docs, API references
- **Similar work items**: Previous work items that are similar
- **Team guidance**: Slack threads, email discussions, meeting notes
- **External resources**: GitHub issues, Stack Overflow discussions

You can paste links or descriptions here, or type 'skip' to proceed with research."

**Store user-provided context:**

If user provides context, save to `.spec-driven-progress/{workItemId}/user-context.md`:
```markdown
# User-Provided Research Context

## Repository Links
- {link 1} - {description}
- {link 2} - {description}

## Documentation Links
- {link 1} - {description}

## Articles & Resources
- {link 1} - {description}

## Notes
{any additional notes from user}
```

### 1.5 Comprehensive Research & Analysis

<!-- IMPORTANT: Use specific tools for each research step -->

**Step 1: Review Existing Patterns**

- Read project rules and standards files for relevant domain patterns

**Step 2: Search for Similar Implementations**

Search the codebase for:
- Similar feature implementations
- Established patterns for the work item type
- Existing interfaces and abstractions
- Test patterns

**Step 3: Review Documentation**
<!-- Use read_file on documentation -->
- Read relevant files under `docs/` directory
- Read README files in project and component directories

**Step 4: Use MCP Tools for External Documentation (When Relevant)**

<!-- Use MCP tools for Microsoft/Azure documentation -->
**Microsoft Docs MCP** - Use when work item involves:
- Azure services (App Service, Functions, Storage, etc.)
- .NET/ASP.NET Core patterns and best practices
- Microsoft 365 APIs
- Azure DevOps APIs
- Any Microsoft technology stack

```
use_mcp_tool:
  server_name: microsoft-docs
  tool_name: microsoft_docs_search
  arguments:
    query: "{relevant search query based on work item}"
```

For code samples:
```
use_mcp_tool:
  server_name: microsoft-docs
  tool_name: microsoft_code_sample_search
  arguments:
    query: "{SDK or API name}"
    language: "csharp"  # or typescript, python, etc.
```

**ConfigGen MCP** - Use when work item involves:
- Azure resource configuration
- Configuration generation libraries
- Infrastructure as code patterns
- Deployment manifests

```
use_mcp_tool:
  server_name: configgen
  tool_name: configgen-search-classes
  arguments:
    className: "{class name to search}"
    partialMatch: true
```

For library documentation:
```
use_mcp_tool:
  server_name: configgen
  tool_name: configgen-get-azure-library-publicapi
  arguments:
    library: "{library name from PackageReference}"
```

**Step 5: Identify Affected Components**

Based on work item requirements, identify:
- Which components need changes 
- New files vs. modifications
- Shared libraries impact
- Configuration generation needs

**Step 6: Document Findings**

Save to `.spec-driven-progress/{workItemId}/research.md`:
```markdown
# Research: {Work Item Title}

## User-Provided Context
{Summary of links and resources provided by user}

## Codebase Analysis
### Similar Implementations Found
- {file/pattern 1} - {relevance}
- {file/pattern 2} - {relevance}

### Patterns to Follow
- {pattern 1} - {from source}
- {pattern 2} - {from source}

## External Documentation
### Microsoft Docs Findings
- {finding 1} - {source URL}
- {finding 2} - {source URL}

### ConfigGen Findings (if applicable)
- {class/library 1} - {usage notes}
- {class/library 2} - {usage notes}

## Files to Modify/Create
### New Files
- {path} - {purpose}

### Modified Files
- {path} - {changes needed}

## Dependencies Identified
- {dependency 1}
- {dependency 2}

## Potential Challenges
- {challenge 1} - {mitigation}
- {challenge 2} - {mitigation}

## Work Item Type-Specific Considerations
{considerations based on work item type}
```

---

## Phase 2: Design Proposal

### 2.1 Architecture Design

Create comprehensive design addressing:

**Technical Approach**
- High-level solution architecture
- Component interactions
- Data flow and state management
- Error handling strategy
- Logging and metrics approach

**Implementation Details**
- New files needed
- Existing files to modify
- Interface definitions
- Data models
- Configuration changes

**Follow Established Patterns**
- **Project Standards**: Follow your project's development standards and guidelines
- **Configuration Management**: Follow your project's configuration patterns (if applicable)
- **Testing Standards**: Follow established testing patterns in your codebase

**Quality Considerations**
- Performance implications
- Security requirements
- Observability needs
- Deployment strategy

**Work Item Type Specific Considerations:**

**For User Stories:**
- Focus on user value and acceptance criteria
- Plan incremental delivery approach
- Consider user experience implications

**For Tasks:**
- Clear scope and deliverables
- Dependencies on other work items
- Integration points

**For Bugs:**
- Root cause analysis
- Regression prevention strategy
- Impact assessment

**For Features (Backward Compatibility):**
- Regression tests to ensure backward compatibility
- Validation that existing functionality still works
- Testing of upgrade/migration paths

**For Features/Epics:**
- Breakdown into smaller work items
- Phased delivery approach
- Cross-component coordination

### 2.2 Create Design Document


Save to `.spec-driven-progress/{workItemId}/design.md`:
```markdown
# Design: {Work Item Title}

## Work Item Overview
- ID: {workItemId}
- Type: {workItemType}
- Description: ...
- Acceptance Criteria: ... (if applicable)

## Technical Approach
### Architecture
[Diagram/description]

### Components Affected
- Component A: [changes]
- Component B: [changes]

### Key Design Decisions
1. Decision: ...
   Rationale: ...
   
### Patterns Used
- Pattern 1: [from existing codebase pattern]
- Pattern 2: [from similar implementation Y]

### File Changes
#### New Files
- path/to/new/file.cs - Purpose

#### Modified Files  
- path/to/existing/file.cs - Changes

### Error Handling
[Strategy]

### Logging & Metrics
- Log events: ...
- Metrics: ...

### Testing Strategy
- Unit tests: ...
- Integration tests: ...
- Regression tests: ... (for bugs)

### Configuration Changes
[If applicable]

## Risks & Mitigation
- Risk 1: ... / Mitigation: ...

## Open Questions
- Question 1: ...
```

### 2.3 User Review & Iteration


<!-- IMPORTANT: User must approve before proceeding to Phase 2.4 -->
Present the following to the user:
1. Present design to user
2. Explain key decisions
3. Highlight trade-offs
4. Request feedback
5. Iterate until approved
6. **Get explicit "proceed" confirmation** (wait for explicit user confirmation)
7. **DO NOT proceed to Phase 2.4 without user approval**

### 2.3.1 Save Documents to Project (Optional)

After design approval, ask user if they want to save the research and design documents to the project for long-term reference:

"Would you like to save the research and design documents to the project's docs folder?

This will create:
- `docs/designs/{feature-name}-design.md` - Design document
- `docs/research/{feature-name}-research.md` - Discovery/research findings

Benefits:
- Documents will be version controlled with the code
- Future team members can reference the design decisions
- Creates institutional knowledge for the project

Options:
1. Yes, save both documents to docs/
2. Save only the design document
3. Save only the research document
4. No, keep only in progress tracking (not version controlled)"

**If user chooses to save:**

1. **Derive feature name** from work item title (convert to kebab-case):
   - Example: "Implement User Authentication" → `user-authentication`
   - Example: "Add Logging Middleware" → `logging-middleware`

2. **Create design document** (if selected):
   
   Save to `docs/designs/{feature-name}-design.md`:
   - Copy content from `.spec-driven-progress/{workItemId}/design.md`
   - Add header with work item reference:
     ```markdown
     # Design: {Work Item Title}
     
     > **Work Item**: [#{workItemId}]({organizationUrl}/{projectName}/_workitems/edit/{workItemId})  
     > **Created**: {date}  
     > **Status**: Approved
     
     ---
     
     {rest of design content}
     ```

3. **Create research document** (if selected):
   
   Save to `docs/research/{feature-name}-research.md`:
   - Copy content from `.spec-driven-progress/{workItemId}/discovery.md`
   - Add header with work item reference:
     ```markdown
     # Research: {Work Item Title}
     
     > **Work Item**: [#{workItemId}]({organizationUrl}/{projectName}/_workitems/edit/{workItemId})  
     > **Created**: {date}
     
     ---
     
     {rest of discovery content}
     ```

4. **Update progress tracking** to note documents were saved:
   ```markdown
   ## Saved Documents
   - Design: `docs/designs/{feature-name}-design.md`
   - Research: `docs/research/{feature-name}-research.md`
   ```

### 2.4 Update Work Item Description with Plan Summary

After design approval, update the work item with a clear summary of the plan and expected outcomes.

Use [Update Work Item](ado-operations.md#update-work-item) to set:
- **System.Description**: Summary, technical approach, components, and expected outcomes
- **Microsoft.VSTS.Scheduling.OriginalEstimate**: Total hours estimated

**Description Guidelines:**
- Keep it concise and clear (aim for 200-400 words)
- Focus on **what** will be done and **why**
- Highlight key technical decisions
- List measurable outcomes
- Use bullet points for readability

**Effort Tracking:**
- Effort estimate is set in the dedicated `Microsoft.VSTS.Scheduling.OriginalEstimate` field (in hours)
- This provides structured tracking in ADO dashboards and reports

### 2.5 Attach Design to Work Item

After updating the description, attach the full design document to the work item.

Use [Attach File to Work Item](ado-operations.md#attach-file-to-work-item) to attach `.spec-driven-progress/{workItemId}/design.md` with comment "Design document - approved and ready for implementation"

Confirm both description update and attachment successful before proceeding to subtask breakdown (if needed).

---

## Phase 2.6: Integration Testing Plan (If Needed)

**When integration testing is required**, create a formal test plan with test cases in ADO:

### Step 1: Determine Testing Requirements

Based on the work item type and scope, assess if formal integration testing is needed:
- **User Stories**: Usually require integration testing
- **Features**: Always require comprehensive testing
- **Bugs**: May need regression testing scenarios
- **Tasks**: Depends on scope and impact

### Step 2: Create Test Plan Document


Draft a test plan in `.spec-driven-progress/{workItemId}/test-plan.md`:

```markdown
# Test Plan: {Work Item Title}

## Test Objectives
- Validate {primary functionality}
- Ensure {integration points work correctly}
- Verify {acceptance criteria met}

## Test Scenarios

### Scenario 1: {Scenario Name}
**Purpose**: {What this scenario validates}

**Prerequisites**:
- {Setup requirement 1}
- {Setup requirement 2}

**Test Steps**:
1. {Step 1 description} | Expected: {Expected result 1}
2. {Step 2 description} | Expected: {Expected result 2}
3. {Step 3 description} | Expected: {Expected result 3}

**Expected Outcome**: {Overall expected result}

### Scenario 2: {Scenario Name}
**Purpose**: {What this scenario validates}

**Prerequisites**:
- {Setup requirement 1}

**Test Steps**:
1. {Step 1 description} | Expected: {Expected result 1}
2. {Step 2 description} | Expected: {Expected result 2}

**Expected Outcome**: {Overall expected result}

## Edge Cases & Error Scenarios
- {Edge case 1}: {Expected handling}
- {Edge case 2}: {Expected handling}

## Test Data Requirements
- {Data requirement 1}
- {Data requirement 2}

## Success Criteria
- [ ] All test scenarios pass
- [ ] Edge cases handled correctly
- [ ] No regression in existing functionality
```

### Step 3: Present Test Plan to User


Present the following to the user:
1. Present the test plan
2. Explain each scenario
3. Request feedback and approval
4. Iterate until approved (ask user if needed)

### Step 4: Create Test Plan in ADO

Once approved, create the test plan using [Create Test Plan](ado-operations.md#create-test-plan) with objectives and scenarios from your test plan document.

**IMPORTANT: Use Markdown Formatting for Test Plan Description**

ADO Test Plan descriptions support Markdown formatting. Use the following structure for a well-formatted test plan:

```markdown
## Overview
End-to-end test plan to verify **{Feature Name}** correctly {validates/implements/handles} {key functionality}.

## Background
This test plan validates {the enhancement/change/feature}. {Brief explanation of what changed and why testing is needed.}

## Test Suites

### Suite 1: {Suite Name}
{Description of what this suite validates}:
- **TC1**: {Scenario} → Should be **{expected outcome}**
- **TC2**: {Scenario} → Should be **{expected outcome}**

### Suite 2: {Suite Name}
{Description of what this suite validates}:
- **TC3**: {Scenario} → Should be **{expected outcome}** (NEW)
- **TC4**: {Scenario} → Should be **{expected outcome}**
- **TC5**: {Scenario} → Should be **{expected outcome}**

## Related Work Items
- User Story: #{workItemId}
- Testing Task: #{testingSubtaskId}

## Reference Data (Optional)
| Value | Name | Description |
|-------|------|-------------|
| 10 | Option1 | Description 1 |
| 20 | Option2 | Description 2 |
| 30 | Option3 | Description 3 |
```

**Markdown Formatting Tips:**
- Use `##` for main sections, `###` for subsections
- Use `**bold**` for emphasis on key terms
- Use `-` for bullet lists
- Use `|` for tables (header, separator row with `|---|`, then data rows)
- Use `#{id}` for work item references (ADO auto-links these)
- Use `→` (arrow) for expected outcomes for clarity
- Add `(NEW)` suffix to highlight new behavior being tested

### Step 5: Create Test Suites and Test Cases

**For each test scenario**, create a test suite and populate it with test cases:

#### Step 5.1: Create Test Suite for Scenario

Use [Create Test Suite](ado-operations.md#create-test-suite) for each scenario. This returns a `suiteId`.

#### Step 5.2: Create Test Cases for this Scenario

**For each test case within the scenario**, use [Create Test Case](ado-operations.md#create-test-case):
- Set `testsWorkItemId` to the **E2E Testing subtask** (not the main work item)
- Format steps with `|` delimiter: `action|expected result`
- Use `|` **only** as the delimiter between action and expected result, not within the action text or expected result text itself
- This automatically creates "Tested By" relationship

#### Step 5.3: Add Test Cases to Suite

Use [Add Test Cases to Suite](ado-operations.md#add-test-cases-to-suite) to add all test cases for this scenario.

**Repeat Steps 5.1-5.3 for each scenario** in your test plan.

**Structure Example**:
```
Test Plan: User Authentication
├── Suite: Happy Path Scenarios
│   ├── Test Case: Successful login with valid credentials
│   ├── Test Case: Successful logout
│   └── Test Case: Session persistence
├── Suite: Error Scenarios
│   ├── Test Case: Invalid username
│   ├── Test Case: Invalid password
│   └── Test Case: Account locked
└── Suite: Edge Cases
    ├── Test Case: Special characters in password
    └── Test Case: Concurrent login attempts
```

### Step 6: Link Test Plan to Testing Subtask

**IMPORTANT**: The test plan should be linked to the **E2E Testing subtask**, not the main work item.

After creating the test plan, you'll create a dedicated testing subtask in Phase 3 that references this test plan.

### Step 7: Update Progress Tracking


Document test plan details in `.spec-driven-progress/{workItemId}.md`:

```markdown
## Test Plan
- **Test Plan ID**: #{testPlanId}
- **Test Plan Name**: Test Plan: {Work Item Title}
- **Test Suites**: {count}
- **Test Cases**: {count}
- **Link**: [Test Plan]({organizationUrl}/{projectName}/_testPlans/execute?planId={testPlanId})

### Test Scenarios
1. Scenario 1: {name} - Test Case #{testCaseId1}
2. Scenario 2: {name} - Test Case #{testCaseId2}
```

---

## Phase 3: Subtask Breakdown & Estimation (If Needed)

**Note**: Design document and test plan (if applicable) are now attached to work item for future reference.

**Determine if subtasks are needed:**
- **Simple work items** (< 8 hours): Can implement directly, no subtasks needed
- **Medium work items** (8-20 hours): Consider subtasks for better tracking
- **Large work items** (> 20 hours): Must break into subtasks or multiple work items

### 3.1 Decompose into Logical Subtasks (If Needed)

Break work item into testable, reviewable units. Common subtask structure:

**For Feature Implementation or Feature Changes:**
- Data model updates
- Interface definitions
- Core implementation
- Service registration/configuration
- Logging message definitions
- Error handling
- Unit tests
- Integration tests
- **E2E Testing & Regression Testing** (MANDATORY - see below)
- Documentation updates

**For Infrastructure Changes:**
- Resource definition updates
- Service configuration
- Manifest generation
- Deployment verification
- **E2E Testing & Regression Testing** (if affects existing functionality)

**For Bug Fixes:**
- Root cause investigation
- Fix implementation
- Regression tests
- **E2E Testing** (to verify fix in full context)
- Related code review

**MANDATORY: E2E Testing & Regression Testing Subtask**

For any work item that implements a new feature or changes existing functionality, you MUST include a dedicated testing subtask:

**Title**: "E2E Testing & Regression Validation"

**Description Template**:
```markdown
## Purpose
Execute end-to-end testing and regression validation for {work item title}.

## Test Plan Reference
- Test Plan ID: #{testPlanId}
- Test Plan Link: [View Test Plan]({organizationUrl}/{projectName}/_testPlans/execute?planId={testPlanId})

## Scope
### E2E Testing
- Execute all test scenarios defined in the test plan
- Validate integration points work correctly
- Verify acceptance criteria are met

### Regression Testing
- Verify existing functionality remains intact
- Test related features that could be affected
- Validate backward compatibility

## Success Criteria
- [ ] All test plan scenarios pass
- [ ] No regressions detected in existing functionality
- [ ] All test results documented in ADO
- [ ] Any failures documented with bug work items

## Test Execution Notes
{To be filled during implementation}
```

**Timing**: 
- This subtask should be scheduled AFTER all implementation subtasks
- Estimate: 4-8 hours depending on complexity
- This subtask will be linked to all test cases via "Tested By" relationship

**Test Plan Integration**:
- Test plan created in Phase 2.6 should reference this subtask
- All test cases created should link to this subtask (via `testsWorkItemId`)
- Test execution results will be tracked against this subtask

### 3.2 Estimate Subtasks

Estimate in hours (4 hours = 1 day):

**Estimation Guidelines:**
- Simple CRUD: 2-4 hours
- New service integration: 6-8 hours
- Complex business logic: 8-12 hours
- Infrastructure changes: 4-6 hours
- Unit tests: 2-4 hours (per component)
- Integration tests: 3-6 hours
- Documentation: 1-2 hours
- Code review fixes: 1-2 hours (buffer)

**Consider:**
- Implementation complexity
- Testing requirements
- Documentation needs
- Code review and fixes
- Learning curve for new patterns

### 3.3 Define Subtask Dependencies (If Applicable)

Identify execution order:

**Predecessor Relationships:**
- Data models before implementation
- Interfaces before concrete classes
- Implementation before tests
- Core features before extensions

**Parallel Subtasks:**
- Independent components
- Documentation alongside implementation


Create dependency map in `.spec-driven-progress/{workItemId}/subtasks.md`

### 3.4 Evaluate Work Item Size

**Sprint Capacity Check:**
- One sprint = 2 weeks = 40 hours per person
- **Work item should be < 20 hours** (less than half sprint) to allow for:
  - Code review and feedback cycles
  - Unexpected issues and blockers
  - Other team commitments
  - Testing and documentation time

**If work item exceeds recommended size (20 hours):**
1. Present the size issue to user:
   "This work item is estimated at {total hours} hours, which exceeds the recommended size (20 hours = half sprint).
   
   Recommendation: Break this into {number} smaller work items, each under 20 hours."

2. Propose work item breakdown with naming convention:
   - Group related subtasks into logical work items
   - Each work item should be independently valuable
   - Maintain clear dependencies between work items
   - Each work item should be under 20 hours
   - **Naming Convention:**
     - **For Single Work Item** (no subtasks):
       - Branch: `feature/{workItemId}/{title}`
     - **For Work Item with Subtasks**:
       - Subtasks: `ST1: {title}`, `ST2: {title}`, ..., `ST[N]: {title}`
       - Branches: `feature/{workItemId}/{subtaskId}/{title}`
     - **For Multi-Work Item Breakdown**:
       - Work Items: `W1: {title}`, `W2: {title}`, ..., `W[N]: {title}`
       - Work Item 1 Subtasks: `ST1.1: {title}`, `ST1.2: {title}`, ..., `ST1.[N]: {title}`
       - Work Item 2 Subtasks: `ST2.1: {title}`, `ST2.2: {title}`, ..., `ST2.[N]: {title}`
   - **Example - Single Work Item (no subtasks):**
     - Work Item: Fix authentication timeout bug (6h)
       - Branch: `feature/12345/fix-authentication-timeout`
   - **Example - Work Item with Subtasks:**
     - Work Item: Implement User Authentication (18h)
       - ST1: Create authentication models (4h)
       - ST2: Add authentication service (6h)
       - ST3: Implement login endpoint (4h)
       - ST4: Add unit tests (4h)
   - **Example - Multi-Work Item Breakdown:**
     - W1: Implement Data Layer (18h)
       - ST1.1: Create data models (4h)
       - ST1.2: Add repository interfaces (3h)
       - ST1.3: Implement repositories (6h)
       - ST1.4: Add unit tests (5h)
     - W2: Implement API Layer (16h)
       - ST2.1: Create API controllers (5h)
       - ST2.2: Add validation logic (4h)
       - ST2.3: Implement error handling (3h)
       - ST2.4: Add integration tests (4h)

3. Ask user:
   "Would you like to:
   1. Break this into multiple work items (recommended)
   2. Proceed with the current large work item
   3. Revise the scope to reduce size"

4. If user chooses to break into multiple work items:
   - Return to Phase 1.1 to create new work items
   - Use current analysis as foundation
   - Distribute subtasks across new work items
   - **Establish work item-level dependencies with predecessor/successor relations**:
     - For sequential work items (W1 → W2 → W3), create predecessor/successor links
     - W2 has W1 as predecessor, W3 has W2 as predecessor, etc.
     - This ensures proper execution order and dependency tracking in ADO
   - **Before creating relations, ask user to confirm the execution order**

### 3.5 Present Breakdown


<!-- IMPORTANT: User must approve before proceeding to Phase 4 -->
Show user:
- Subtask list with descriptions (if applicable)
- Time estimates per subtask or for single work item
- Total estimated time
- **Sprint capacity check** (< 20 hours?)
- Dependency graph (if subtasks)
- Implementation order

**Get explicit approval before proceeding** (wait for explicit user confirmation).
**DO NOT proceed to Phase 4 (ADO Work Item Creation) without user approval**.

---

## Phase 4: ADO Work Item Creation (If Subtasks Needed)

**Note**: Skip this phase if work item is small enough to implement directly without subtasks.

### 4.1 Create Child Subtasks

Use [Create Child Work Items (Subtasks)](ado-operations.md#create-child-work-items-subtasks) to create ALL subtasks in a single call (max 50):
- Parent relations are automatically established
- Returns created work item IDs for all subtasks
- Set format to "Markdown" for descriptions
- Include iterationPath for each subtask

### 4.2 Establish Subtask Dependencies (Predecessor/Successor)

**After creating subtasks, establish execution order dependencies if needed.**

Use [Link Work Items](ado-operations.md#link-work-items) with type "predecessor" for sequential dependencies. See [Establishing Predecessor/Successor Relations](ado-operations.md#establishing-predecessorsuccessor-relations) for examples.

**Note**: Parent relations are automatically created by `wit_add_child_work_items` - no need to manually link.

**IMPORTANT: Verify Relations Were Created**

Use [Get Work Item](ado-operations.md#get-work-item) with `expand: "relations"` to verify:
- Parent link exists (should reference {workItemId})
- Predecessor links (if applicable)
- Any other expected relations

**If relations are missing:**
1. Check response for errors
2. Retry with correct subtask IDs
3. Document in progress files if manual linking needed

### 4.3 Update Progress File


Map subtasks to ADO IDs in `.spec-driven-progress/{workItemId}/subtasks.md`:
```markdown
# Subtask Breakdown

## Subtask List
1. [#12345] Data Model Updates (4h)
   - Prerequisites: None
   - Status: Not Started
   
2. [#12346] Implementation (8h)
   - Prerequisites: #12345
   - Status: Not Started

...

## Dependency Graph
[Visual representation]

## Implementation Order
Based on dependencies: #12345 → #12346 → #12347 ...
```

---

## Planning Phase Completion Checkpoint

**Before proceeding to Phase 5 (Implementation), verify ALL of the following:**

<!-- AI ASSISTANT: You MUST verify each item before proceeding to implementation -->

### Phase 1 - Initialization:
- [ ] ✅ Work item fetched or created in ADO (1.1)
- [ ] ✅ Parent hierarchy verified (1.1)
- [ ] ✅ Tags and iteration path confirmed (1.2)
- [ ] ✅ Progress tracking directory created (1.3)
- [ ] ✅ Codebase analysis completed (1.4)

### Phase 2 - Design:
- [ ] ✅ Design document created (2.1-2.2)
- [ ] ✅ **User approved design** (2.3)
- [ ] ✅ Work item description updated with plan summary (2.4)
- [ ] ✅ Design document attached to work item (2.5)
- [ ] ✅ Test plan created in ADO (if applicable) (2.6)

### Phase 3 - Breakdown (if needed):
- [ ] ✅ Subtasks decomposed with estimates (3.1-3.2)
- [ ] ✅ Dependencies identified (3.3)
- [ ] ✅ Size validated (< 20 hours per work item) (3.4)
- [ ] ✅ **User approved breakdown** (3.5)

### Phase 4 - ADO Creation (if subtasks needed):
- [ ] ✅ Child subtasks created in ADO (4.1)
- [ ] ✅ Predecessor/successor relations established (4.2)
- [ ] ✅ Relations verified via get work item (4.2)
- [ ] ✅ Progress file updated with ADO IDs (4.3)

### Final Check:
- [ ] ✅ **User approved proceeding to implementation**

**If any checkbox is NOT completed, DO NOT proceed. Go back and complete the missing step.**

---

**Workflow Navigation:**
← [Skill Overview](../SKILL.md) | → [Implementation](implementation.md) | [ADO Operations](ado-operations.md)
