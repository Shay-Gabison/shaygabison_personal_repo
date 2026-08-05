# PR Generator Configuration

This configuration file defines project-specific settings for the PR Generator tool.

## MCP Server Configuration

### Azure DevOps MCP Server Name
```
MCP Server Name: {{MCP_SERVER_NAME}}  # The key name of your ADO MCP server in VSCode MCP settings (e.g. "ado", "azure-devops")
```

**Examples:**
- `ado` - Short name
- `azure-devops` - Descriptive name
- `azdo` - Alternative short name

**To find your MCP server name:**
1. Open VSCode Settings
2. Search for "MCP"
3. Check your configured MCP servers
4. Use the exact name as it appears in your MCP settings

### PR Creation Tool
```
Tool Name: {{MCP_SERVER_NAME}}/repo_create_pull_request
```

## Repository Configuration

### Repository Details
```
Organization URL: {{ORGANIZATION_URL}}   # Full ADO org URL, e.g. https://dev.azure.com/my-org  (Settings → Overview → Organization URL)
Project Name: {{PROJECT_NAME}}           # ADO project name as it appears in the URL, e.g. MyProject
Repository Name: {{REPOSITORY_NAME}}     # Git repo name inside the project (Repos → Files → repo dropdown)
Repository ID: {{REPOSITORY_ID}}         # GUID; run: az repos list --project {{PROJECT_NAME}} --query "[?name=='{{REPOSITORY_NAME}}'].id" -o tsv
Base Branch: {{BASE_BRANCH}}             # Target branch for PRs, e.g. main or develop
```

## PR Title Convention

### Change Types
```
- feature: New functionality or capabilities
- bugfix: Bug fixes and issue resolution
- enhance: Improvements to existing features
- perf: Performance optimizations
```

### Component Areas
List your project's component names here:
```
- {{COMPONENT_1}}: Description  # Replace with a short component identifier and its role, e.g. "api: REST API controllers"
- {{COMPONENT_2}}: Description  # Add as many components as your project has; remove unused lines
- {{COMPONENT_3}}: Description
```

**Example:**
```
- api: API endpoints and controllers
- core: Core business logic
- db: Database and data access
- ui: User interface components
```

## Quality Gates

### Required Checks
```
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] Breaking changes noted
- [ ] Security reviewed
- [ ] Performance impact assessed
```

## Notes

- Replace all `{{TEMPLATE_VARIABLES}}` with your actual values
- Keep this file in the project root (add to .gitignore if it contains sensitive info)
- Update component areas as your project structure evolves
