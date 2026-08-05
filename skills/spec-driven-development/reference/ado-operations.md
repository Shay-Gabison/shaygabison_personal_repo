# Azure DevOps Reference

Part of: [Spec-Driven Development](../SKILL.md)

**Purpose**: Command reference for Azure DevOps operations  
**When to Use**: When you need specific command syntax for ADO operations

This reference provides command examples for interacting with Azure DevOps using both MCP tools and Azure CLI.

**Note**: MCP tool names and schemas shown here are examples. Always verify actual tool names and arguments from your connected MCP server's documentation, as they may differ between implementations.

**Configuration Note**: Examples in this reference use placeholder values like `{PROJECT_NAME}`, `{REPOSITORY_ID}`, and `{REPOSITORY_NAME}`. Replace these with your actual values from your [spec-driven-config.md](../templates/spec-driven-config.md) when using these commands in your workflow.

---

## MCP ADO Commands

Replace `{mcpServerName}` with the MCP server name configured in your [spec-driven-config.md](../templates/spec-driven-config.md).

### Work Item Operations

#### Get Work Item
```
use_mcp_tool:
  server_name: {mcpServerName}
  tool_name: wit_get_work_item
  arguments:
    id: {workItemId}
    project: {PROJECT_NAME}
```

#### Create Work Item
```
use_mcp_tool:
  server_name: {mcpServerName}
  tool_name: wit_create_work_item
  arguments:
    project: {PROJECT_NAME}
    workItemType: Task|Bug|User Story|Feature|Epic
    fields:
      - name: "System.Title"
        value: "{title}"
      - name: "System.Description"
        value: "{description}"
        format: "Markdown"  # Optional: "Markdown" or "Html" (default: Html)
      - name: "System.IterationPath"
        value: "{iterationPath}"
      - name: "System.Tags"
        value: "{tags}"
      - name: "Microsoft.VSTS.Scheduling.OriginalEstimate"
        value: "{hours}"
      - name: "Microsoft.VSTS.Scheduling.RemainingWork"
        value: "{hours}"
```

**Note**: 
**Important - Always Use Markdown Format**: 
- **ALWAYS** set `format: "Markdown"` for the description field
- The format is set at creation time and cannot be changed via API updates
- If you create a work item without `format: "Markdown"`, you must delete and recreate it
- Markdown enables proper rendering of tables, code blocks, checkboxes, and formatting
- This tool does NOT support parent relation - use `wit_add_child_work_items` for creating subtasks with parent link

#### Create Child Work Items (Subtasks)
**Use this tool when creating subtasks under a parent work item**

```
use_mcp_tool:
  server_name: {mcpServerName}
  tool_name: wit_add_child_work_items
  arguments:
    parentId: {parentWorkItemId}
    project: {PROJECT_NAME}
    workItemType: Task  # Child work item type
    items:
      - title: "{subtask1Title}"
        description: "{subtask1Description}"
        format: "Markdown"  # or "Html" (default)
        areaPath: "{areaPath}"  # Optional
        iterationPath: "{iterationPath}"  # Optional
      - title: "{subtask2Title}"
        description: "{subtask2Description}"
        format: "Markdown"
```

**Important Notes**:
- Maximum 50 child work items per call
- Parent relation is automatically created
- All children inherit project from parent
- AreaPath and IterationPath are optional

#### Update Work Item
```
use_mcp_tool:
  server_name: {mcpServerName}
  tool_name: wit_update_work_item
  arguments:
    id: {workItemId}
    updates:
      - op: "replace"
        path: "/fields/System.State"
        value: "Active|Resolved|Closed"
      - op: "replace"
        path: "/fields/Microsoft.VSTS.Scheduling.RemainingWork"
        value: "{hours}"
```

#### Add Work Item Comment
```
use_mcp_tool:
  server_name: {mcpServerName}
  tool_name: wit_add_work_item_comment
  arguments:
    project: {PROJECT_NAME}
    workItemId: {workItemId}
    comment: "{comment text}"
```

#### Link Work Items
**Use this tool to create relations between work items (predecessor/successor, related, etc.)**

```
use_mcp_tool:
  server_name: {mcpServerName}
  tool_name: wit_work_items_link
  arguments:
    project: {PROJECT_NAME}
    updates:
      - id: {sourceWorkItemId}
        linkToId: {targetWorkItemId}
        type: "predecessor|successor|related|parent|child|duplicate|duplicate of|tested by|tests|affects|affected by"
        comment: "{optional comment}"
```

**Relation Type Mappings**:
- **predecessor**: Source must be completed before target (Dependency-Reverse)
- **successor**: Target depends on source completion (Dependency-Forward)
- **parent**: Target is parent of source (Hierarchy-Reverse)
- **child**: Source is parent of target (Hierarchy-Forward)
- **related**: Logical connection (Related)
- **duplicate**: Source duplicates target (Duplicate-Forward)
- **tested by**: Source is tested by target (TestedBy-Forward)

**Important**: Use `wit_add_child_work_items` for creating new children. Use this tool for existing work items.

#### Attach File to Work Item
```
use_mcp_tool:
  server_name: {mcpServerName}
  tool_name: wit_add_work_item_attachment
  arguments:
    project: {PROJECT_NAME}
    workItemId: {workItemId}
    filePath: "{path/to/file}"
    comment: "{description of attachment}"
```

### Test Plan Operations

#### Create Test Plan
```
use_mcp_tool:
  server_name: {mcpServerName}
  tool_name: testplan_create_test_plan
  arguments:
    project: {PROJECT_NAME}
    name: "Test Plan: {Work Item Title}"
    iteration: "{iterationPath}"
    description: |
      Test plan for work item #{workItemId}
      
      ## Objectives
      {Summary of test objectives}
      
      ## Scenarios
      {List of scenarios}
    areaPath: "{areaPath}"
    startDate: "{YYYY-MM-DD}"  # Optional
    endDate: "{YYYY-MM-DD}"    # Optional
```

#### Create Test Suite
```
use_mcp_tool:
  server_name: {mcpServerName}
  tool_name: testplan_create_test_suite
  arguments:
    project: {PROJECT_NAME}
    planId: {testPlanId}
    parentSuiteId: {rootSuiteId}  # Use root suite ID from test plan
    name: "{Scenario Name}"
```

**Returns**: `suiteId` for the created test suite

#### Create Test Case
```
use_mcp_tool:
  server_name: {mcpServerName}
  tool_name: testplan_create_test_case
  arguments:
    project: {PROJECT_NAME}
    title: "{Test Case Name}"
    steps: |
      1. {Step 1 description}|{Expected result 1}
      2. {Step 2 description}|{Expected result 2}
      3. {Step 3 description}|{Expected result 3}
    priority: {1-4}  # 1=High, 2=Medium, 3=Low, 4=Very Low
    areaPath: "{areaPath}"
    iterationPath: "{iterationPath}"
    testsWorkItemId: {testingTaskId}  # Links to testing subtask via "Tested By"
```

**Important Notes**:
- Steps format uses `|` as delimiter between action and expected result
- **DO NOT** use `|` within step descriptions or expected results
- `testsWorkItemId` automatically creates "Tested By" relationship
- Returns created test case work item ID

#### Add Test Cases to Suite
```
use_mcp_tool:
  server_name: {mcpServerName}
  tool_name: testplan_add_test_cases_to_suite
  arguments:
    project: {PROJECT_NAME}
    planId: {testPlanId}
    suiteId: {suiteId}
    testCaseIds: "{testCaseId1},{testCaseId2},{testCaseId3}"
```

**Format Notes**:
- `testCaseIds` accepts **comma-separated string** or array of strings
- Array format: `["12345", "12346", "12347"]` (auto-converted to comma-separated)
- Single test case: `testCaseIds: "12345"`
- Multiple test cases: `testCaseIds: "12345,12346,12347"`

### Pull Request Operations

#### Get Pull Requests
```
use_mcp_tool:
  server_name: {mcpServerName}
  tool_name: repo_list_pull_requests_by_repo_or_project
  arguments:
    repositoryId: "{REPOSITORY_ID}"
    project: {PROJECT_NAME}
    status: "Active|Completed|Abandoned|All"
    sourceRefName: "refs/heads/feature/{storyId}/*"
```

#### Get Single Pull Request
```
use_mcp_tool:
  server_name: {mcpServerName}
  tool_name: repo_get_pull_request_by_id
  arguments:
    repositoryId: "{REPOSITORY_ID}"
    pullRequestId: {prId}
```

#### Create Pull Request
```
use_mcp_tool:
  server_name: {mcpServerName}
  tool_name: repo_create_pull_request
  arguments:
    repositoryId: "{REPOSITORY_ID}"
    sourceRefName: "refs/heads/feature/{storyId}/{taskId}/{title}"
    targetRefName: "refs/heads/main"
    title: "{PR title}"
    description: "{PR description}"
    isDraft: false
    workItems: "{workItemId1} {workItemId2}"
```

#### Update Pull Request
```
use_mcp_tool:
  server_name: {mcpServerName}
  tool_name: repo_update_pull_request
  arguments:
    repositoryId: "{REPOSITORY_ID}"
    pullRequestId: {prId}
    title: "{new title}"
    description: "{new description}"
    status: "Active|Abandoned"
```

---

## Azure CLI Commands

If not using MCP, these Azure CLI alternatives can be used.

### Prerequisites
```bash
# Login to Azure DevOps
az login

# Set default organization and project
az devops configure --defaults \
  organization={ADO_ORGANIZATION_URL} \
  project={PROJECT_NAME}
```

### Work Item Operations

#### Get Work Item
```bash
az boards work-item show --id {workItemId}
```

#### Create Work Item
```bash
az boards work-item create \
  --title "{title}" \
  --type "Task|Bug|User Story" \
  --description "{description}" \
  --iteration "{iterationPath}" \
  --fields "System.Tags={tags}" \
  --fields "Microsoft.VSTS.Scheduling.OriginalEstimate={hours}"
```

#### Update Work Item
```bash
az boards work-item update \
  --id {workItemId} \
  --state "Active|Resolved|Closed" \
  --fields "Microsoft.VSTS.Scheduling.RemainingWork={hours}"
```

#### Link Work Items
```bash
az boards work-item relation add \
  --id {sourceWorkItemId} \
  --target-id {targetWorkItemId} \
  --relation-type "parent|child|related"
```

### Pull Request Operations

#### List Pull Requests
```bash
az repos pr list \
  --repository {REPOSITORY_NAME} \
  --status "active|completed|abandoned|all" \
  --source-branch "feature/{storyId}/*"
```

#### Get Pull Request
```bash
az repos pr show --id {prId}
```

#### Create Pull Request
```bash
az repos pr create \
  --repository {REPOSITORY_NAME} \
  --source-branch "feature/{storyId}/{taskId}/{title}" \
  --target-branch main \
  --title "{title}" \
  --description "{description}" \
  --work-items {workItemId1} {workItemId2}
```

#### Update Pull Request
```bash
az repos pr update \
  --id {prId} \
  --title "{new title}" \
  --description "{new description}" \
  --status "active|abandoned"
```

---

## Common Patterns

### Creating Child Subtasks
**Best practice: Use `wit_add_child_work_items` for creating subtasks**

```
# MCP - Correct way to create child subtasks
use_mcp_tool:
  server_name: {mcpServerName}
  tool_name: wit_add_child_work_items
  arguments:
    parentId: {parentWorkItemId}
    project: {PROJECT_NAME}
    workItemType: Task
    items:
      - title: "{subtaskTitle}"
        description: "{subtaskDescription}"
        format: "Markdown"
        iterationPath: "{iterationPath}"
```

**Note**: Parent relation is automatically created. No need to manually link.

```bash
# Azure CLI
az boards work-item create \
  --title "{taskTitle}" \
  --type Task \
  --iteration "{iterationPath}" \
  --fields "Microsoft.VSTS.Scheduling.OriginalEstimate={hours}" \
  --parent {parentStoryId}
```

### Establishing Predecessor/Successor Relations
**Use this for work item execution order dependencies**

```
# MCP - Create predecessor relation (W1 must complete before W2)
use_mcp_tool:
  server_name: {mcpServerName}
  tool_name: wit_work_items_link
  arguments:
    project: {PROJECT_NAME}
    updates:
      - id: {workItem2Id}  # This work item
        linkToId: {workItem1Id}  # Depends on this work item
        type: "predecessor"  # W1 is predecessor of W2
        comment: "W2 depends on W1 completion"
```

**Sequential Dependencies Example** (W1 → W2 → W3):
```
# W2 depends on W1
- id: {workItem2Id}
  linkToId: {workItem1Id}
  type: "predecessor"

# W3 depends on W2  
- id: {workItem3Id}
  linkToId: {workItem2Id}
  type: "predecessor"
```

### Linking PR to Work Items
When creating PR, link work items by:
- **MCP**: Use `workItems` parameter with space-separated IDs
- **Azure CLI**: Use `--work-items` flag with space-separated IDs

### Checking PR Status Before Branching
```
# MCP
use_mcp_tool:
  server_name: {mcpServerName}
  tool_name: repo_list_pull_requests_by_repo_or_project
  arguments:
    repositoryId: "{REPOSITORY_ID}"
    sourceRefName: "refs/heads/feature/{storyId}/{previousTaskId}/*"
    status: "Active"
```

```bash
# Azure CLI
az repos pr list \
  --repository {REPOSITORY_NAME} \
  --source-branch "feature/{storyId}/{previousTaskId}/*" \
  --status active
```

---

## Tips

### MCP vs Azure CLI
- **MCP**: Preferred when available, integrated with agent tool calling
- **Azure CLI**: Fallback option, requires manual authentication
- **Choose based on**: Available tools and user preference

### Work Item States
- **Active**: Work in progress
- **Resolved**: Work completed, awaiting verification
- **Closed**: Verified and accepted

### PR Statuses
- **Active**: Open for review
- **Completed**: Merged to target branch
- **Abandoned**: Closed without merging

### Relation Types
- **Parent/Child**: Hierarchical relationship
- **Related**: Logical connection
- **Predecessor/Successor**: Dependency chain
- **Tested By**: Test coverage link

---

**Workflow Navigation:**
↑ [Skill Overview](../SKILL.md) | [Planning](planning.md) | [Implementation](implementation.md) | [Completion](completion.md)
