# PR Generator Configuration - Example

This is an **example configuration file** for the PR Generator tool. Copy this file and customize it for your project.

> **Note:** For a blank template with placeholder variables, see `templates/pr-generator-config.md`

## MCP Server Configuration

### Azure DevOps MCP Server Name
```
MCP Server Name: ado
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
Tool Name: ado/repo_create_pull_request
```

## Repository Configuration

### Repository Details
```
Organization URL: https://dev.azure.com/your-organization
Project Name: YourProject
Repository Name: your-repository
Repository ID: a1b2c3d4-1234-5678-abcd-ef0123456789
Base Branch: main
```

**How to get Repository ID:**
```bash
az repos list --project YourProject --query "[?name=='your-repository'].id" -o tsv
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
- api: API endpoints and controllers
- core: Core business logic
- db: Database and data access
- ui: User interface components
- docs: Documentation changes
- infra: Infrastructure and deployment
```

## PR Template Location

```
PR Template Path: templates/pull_request_template.md
```

**Note:** The PR template is included in this package. When integrating into a project, you can:
- Copy it to `.azuredevops/pull_request_template.md` (Azure DevOps standard location)
- Copy it to `.github/pull_request_template.md` (GitHub standard location)
- Keep it in a custom location and update this path

## Quality Gates

### Required Checks
```
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] Breaking changes noted
- [ ] Security reviewed
- [ ] Performance impact assessed
```

## Usage

1. This file is automatically copied to your project root by the install script
2. Rename it to `pr-generator-config.md`
3. Replace all example values with your actual project values:
   - Organization URL
   - Project Name
   - Repository Name and ID
   - Component areas specific to your project
4. Optionally add the config to `.gitignore` if it contains sensitive information
