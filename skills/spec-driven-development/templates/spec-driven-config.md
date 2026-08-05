# Spec-Driven Workflow Configuration Template

<!-- 
SETUP INSTRUCTIONS:
1. This file was copied to your project root by the install script. Customize it here.
2. Replace all {{TEMPLATE_VARIABLES}} with your actual values
3. Customize tags, standards, and tools for your project
4. Keep this file updated as your project evolves
-->

## Azure DevOps Settings

### Organization & Project
- **Organization**: `{{ADO_ORGANIZATION_URL}}`  
  Example: `https://dev.azure.com/myorg`
- **Project**: `{{ADO_PROJECT_NAME}}`  
  Example: `MyProject`
- **Area Path**: `{{ADO_AREA_PATH}}`  
  Example: `MyProject\MyTeam\MyComponent`

### Repository
- **Repository Name**: `{{REPOSITORY_NAME}}`  
  Example: `my-application`
- **Repository ID**: `{{REPOSITORY_ID}}`  
  Example: `12345678-1234-1234-1234-123456789abc`
  
  > **How to find Repository ID:**
  > - Azure CLI: `az repos show --repository {{REPOSITORY_NAME}} --query id -o tsv`
  > - Or find in Azure DevOps repo settings URL

- **Base Branch**: `{{BASE_BRANCH}}`  
  Default: `main` (or `master`, `develop` depending on your branching strategy)

---

## Work Item Configuration

### Work Item Tags

Define project-specific tags that can be applied to work items. Tags help categorize and filter work items.

**Available Tags** (customize for your project):
- `{{TAG_1}}` - {{Description of when to use this tag}}
- `{{TAG_2}}` - {{Description of when to use this tag}}
- `{{TAG_3}}` - {{Description of when to use this tag}}

**Examples:**
- `Backend` - For backend service changes
- `Frontend` - For UI/UX changes
- `Database` - For schema or data changes
- `API` - For API contract changes
- `Infrastructure` - For deployment/config changes

**Tag Selection Process:**
1. Analyze which components are being modified
2. The AI assistant will suggest appropriate tags based on changes
3. User can confirm or provide alternative tags

### Work Item Sizing Guidelines

- **Single work items**: < 20 hours (half sprint)
- **Large work items**: Break into multiple smaller work items
- **Buffer**: Allow time for code review, unexpected issues, and other commitments

> **Customize these values** based on your team's sprint length and capacity:
> - Sprint Length: {{SPRINT_LENGTH_WEEKS}} weeks = {{SPRINT_HOURS}} hours
> - Max Work Item Size: {{MAX_WORK_ITEM_HOURS}} hours ({{PERCENTAGE_OF_SPRINT}}% of sprint)

---

## Git Configuration

### Branch Naming Conventions

**Default Pattern** (recommended):

**If current work item is a subtask** of a larger User Story/Feature/Epic:
```
feature/{workItemId}/{subtaskId}/{title-kebab-case}
```

**If current work item is independent** (not part of a parent work item):
```
feature/{workItemId}/{title-kebab-case}
```

**Examples:**
- Subtask: `feature/12345/ST1/implement-user-authentication`
- Independent: `feature/12345/add-logging-middleware`

**Custom Patterns** (if your team uses different conventions):
```
{{CUSTOM_BRANCH_PATTERN}}
```

Examples of alternative patterns:
- `users/{username}/feature/{workItemId}/{title}`
- `work-items/{workItemId}-{title}`
- `{workItemType}/{workItemId}/{title}`

---

## Project Standards & Documentation

Define paths to your project-specific standards and documentation.

### Development Standards
- **Path**: `{{PATH_TO_DEV_STANDARDS}}`  
  Example: `docs/development-standards.md`
- **Purpose**: Coding conventions, patterns, best practices

### Testing Standards
- **Path**: `{{PATH_TO_TEST_STANDARDS}}`  
  Example: `docs/testing-standards.md`
- **Purpose**: Testing requirements, coverage expectations, test patterns

### Configuration Standards
- **Path**: `{{PATH_TO_CONFIG_STANDARDS}}`  
  Example: `docs/configuration-standards.md`
- **Purpose**: Configuration management, environment setup, deployment patterns

### Additional Standards
Add any project-specific standards files:
- **{{STANDARD_NAME}}**: `{{PATH_TO_STANDARD}}`

---

## Tool Configuration

### MCP Server Configuration

**ADO MCP Server** (if using MCP for Azure DevOps integration):
- **Server Name**: `{{MCP_ADO_SERVER_NAME}}`
- **Detection**: Workflow will look for this server name in connected MCP servers
- **Fallback**: Azure CLI if MCP server not detected

> **Note**: Common server names used by teams include `ado`, `azure-devops`, `azdo`. 
> Use whatever name is configured in your MCP server settings.

### PR Creation Tools

**PR Creation Prompt** (recommended):
- **Path**: `{{PR_CREATION_PROMPT_PATH}}`  
  Example: `pr-generator-config.md`
- **Config**: `{{PR_CREATION_CONFIG_PATH}}`  
  Example: `pr-generator-config.md`

> **Setup**: Copy from [pr-generator package](../pr-generator/) to your project.

**PR Creation Script** (alternative):
- **Path**: `{{PR_CREATION_SCRIPT_PATH}}`  
  Example: `./eng/tools/New-PullRequest.ps1`
- **Command Pattern**: `{{PR_CREATION_COMMAND}}`  
  Example: `pwsh {{SCRIPT_PATH}} -Title "..." -Description "..." -WorkItemId {{ID}}`

**PR Notification Prompt** (optional):
- **Path**: `{{PR_NOTIFICATION_PROMPT_PATH}}`  
  Example: `Send-PRTeamsNotification.config.ps1`

> **Setup**: Copy from [teams-notifications package](../teams-notifications/) to your project.

**PR Notification Script** (alternative):
- **Path**: `{{PR_NOTIFICATION_SCRIPT_PATH}}`  
  Example: `./eng/tools/Send-PRTeamsNotification.ps1`
- **Command Pattern**: `{{NOTIFICATION_COMMAND}}`  
  Example: `pwsh {{SCRIPT_PATH}} -PRId {{ID}} -Destination "{{CHANNEL}}"`

**Fallback Method** (if no custom scripts):
```bash
# Use Azure CLI
az repos pr create \
  --repository {{REPOSITORY_NAME}} \
  --source-branch {{BRANCH}} \
  --target-branch {{BASE_BRANCH}} \
  --title "{{TITLE}}" \
  --description "{{DESCRIPTION}}" \
  --work-items {{WORK_ITEM_IDS}}
```

### Build & Test Commands

**Build Command**:
```bash
{{BUILD_COMMAND}}
```
Examples:
- .NET: `dotnet build --configuration Release`
- Java (Maven): `mvn compile` or `mvn package`
- Java (Gradle): `gradle build`
- Node.js: `npm run build`
- Python: `python setup.py build` or `pip install -e .`
- Go: `go build ./...`
- Rust: `cargo build --release`

**Test Command**:
```bash
{{TEST_COMMAND}}
```
Examples:
- .NET: `dotnet test`
- Java (Maven): `mvn test`
- Java (Gradle): `gradle test`
- Node.js: `npm test`
- Python: `pytest`
- Go: `go test ./...`
- Rust: `cargo test`

**Test with Coverage** (optional):
```bash
{{TEST_WITH_COVERAGE_COMMAND}}
```

---

## Quality Gates

Define quality gates that must pass before PR creation.

### Code Quality
- [ ] Follows established patterns
- [ ] No hardcoded values
- [ ] Proper error handling
- [ ] {{CUSTOM_QUALITY_CHECK_1}}
- [ ] {{CUSTOM_QUALITY_CHECK_2}}

### Testing Requirements
- [ ] Unit tests written and passing
- [ ] {{MINIMUM_COVERAGE_PERCENTAGE}}% code coverage
- [ ] Integration tests passing (if applicable)
- [ ] {{CUSTOM_TEST_REQUIREMENT}}

### Build Requirements
- [ ] Builds in {{BUILD_CONFIGURATION}} mode
- [ ] No compiler warnings
- [ ] {{CUSTOM_BUILD_REQUIREMENT}}

### Documentation Requirements
- [ ] Code comments added
- [ ] README updated (if needed)
- [ ] API documentation updated
- [ ] {{CUSTOM_DOC_REQUIREMENT}}

---

## Work Item Hierarchy

Define the expected work item hierarchy for your project.

**Standard ADO Hierarchy**:
```
Epic → Feature → User Story → Task/Bug
```

**Your Project's Hierarchy** (customize if different):
```
{{LEVEL_1}} → {{LEVEL_2}} → {{LEVEL_3}} → {{LEVEL_4}}
```

**When to Create Parent Work Items**:
- {{CONDITION_1}}
- {{CONDITION_2}}

---

## Workflow Customization

### Custom Phases (Optional)

If your team requires additional workflow phases, define them here:

**Phase {{N}}: {{PHASE_NAME}}**
- **When**: {{WHEN_TO_EXECUTE}}
- **Purpose**: {{PHASE_PURPOSE}}
- **Deliverables**: {{EXPECTED_OUTPUTS}}
- **Documentation**: `{{PATH_TO_PHASE_DOC}}`

### Integration Points

Define how this workflow integrates with your existing processes:

**CI/CD Integration**:
- Pipeline triggers on: {{TRIGGER_EVENTS}}
- Required checks: {{REQUIRED_CHECKS}}
- Deployment strategy: {{DEPLOYMENT_STRATEGY}}

**Code Review Process**:
- Required reviewers: {{REVIEWER_REQUIREMENTS}}
- Approval process: {{APPROVAL_PROCESS}}
- Review checklist: `{{PATH_TO_REVIEW_CHECKLIST}}`

---

## Team-Specific Conventions

### Commit Message Format
```
{{COMMIT_MESSAGE_PATTERN}}
```
Example: `feat: {description} - #{workItemId}`

### PR Title Format
```
{{PR_TITLE_PATTERN}}
```
Example: `[{workItemId}] {type}: {description}`

### Documentation Format
- Progress files: {{PROGRESS_FILE_FORMAT}}
- Design docs: {{DESIGN_DOC_FORMAT}}
- Test plans: {{TEST_PLAN_FORMAT}}

---

## Reference Links

**Quick Links** (customize for your project):
- [Azure DevOps Project]({{ADO_PROJECT_URL}})
- [Repository]({{REPO_URL}})
- [Build Pipelines]({{PIPELINES_URL}})
- [Documentation]({{DOCS_URL}})
- [Team Wiki]({{WIKI_URL}})

---

## Maintenance Notes

**Last Updated**: {{DATE}}  
**Updated By**: {{PERSON}}  
**Changes**: {{CHANGE_DESCRIPTION}}

**Review Schedule**: {{REVIEW_FREQUENCY}}  
**Next Review**: {{NEXT_REVIEW_DATE}}

---

## Usage Notes

### Getting Started
1. Ensure all {{TEMPLATE_VARIABLES}} are replaced with actual values
2. Verify Azure DevOps credentials and permissions
3. Test MCP server connectivity (if using MCP)
4. Validate PR creation scripts exist and work
5. Review team-specific conventions with team members

### Troubleshooting
- **ADO Connection Issues**: {{TROUBLESHOOTING_STEPS}}
- **MCP Server Not Found**: {{FALLBACK_INSTRUCTIONS}}
- **PR Creation Fails**: {{PR_CREATION_TROUBLESHOOTING}}

### Support
- **Team Contact**: {{TEAM_CONTACT}}
- **Documentation**: {{SUPPORT_DOCS_URL}}
- **Issues**: {{ISSUE_TRACKER_URL}}
