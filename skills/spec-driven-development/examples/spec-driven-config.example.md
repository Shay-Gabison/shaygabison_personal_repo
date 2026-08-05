# Spec-Driven Workflow Configuration

**Project**: Generic Project  
**Last Updated**: 2025-12-01

---

## Azure DevOps Configuration

### Organization & Project
```
Organization URL: https://dev.azure.com/contoso
Project Name: MyProject
Area Path: MyProject\MyTeam\MyComponent
```

### Repository
```
Repository Name: my-application
Repository ID: a1b2c3d4-1234-5678-abcd-ef0123456789
Base Branch: main
```

**How to get Repository ID**:
```bash
az repos list --project MyProject --query "[?name=='my-application'].id" -o tsv
```

---

## Work Item Configuration

### Available Work Item Tags
Select appropriate tag when creating work items:
- `Feature` - New features
- `Bug` - Bug fixes
- `Improvement` - Enhancements
- `Documentation` - Documentation updates
- `Technical-Debt` - Code refactoring

### Work Item Sizing Guidelines
- **Small** (< 8 hours): Single feature, minimal dependencies
- **Medium** (8-20 hours): Multiple related changes, some complexity
- **Large** (> 20 hours): Should be broken into multiple work items

---

## Git Configuration

### Branch Naming Conventions
**Pattern**: `feature/{workItemId}/{subtaskId}/{description}`

**Examples**:
- Single work item: `feature/12345/add-user-login`
- With subtasks: `feature/12345/ST1/implement-auth`
- Bug fix: `feature/12345/fix-validation-error`

### Commit Message Format
```
Brief description (50 chars max)

Detailed explanation if needed.
References work item #12345
```

---

## MCP Configuration

### MCP Server
- **Server Name**: `ado`

> **Note**: This is the name of your MCP ADO server as configured in your MCP settings. 
> Common names used by teams include `ado`, `azure-devops`, `azdo`.
> The workflow will automatically detect available tools from the connected MCP server.

### Fallback Method
If MCP server is not detected, the workflow will fall back to Azure CLI:
```bash
az login
az devops configure --defaults organization=https://dev.azure.com/contoso project=MyProject
```

---

## Build & Test Configuration

### Build Command
```bash
# Replace with your project's build command
make build
# OR
npm run build
# OR
./build.sh
```

### Test Command
```bash
# Replace with your project's test command
make test
# OR
npm test
# OR
./run-tests.sh
```

### Quality Verification
Before creating PR, verify:
```bash
# Run your project's quality checks
# Examples:
# - Linting
# - Type checking
# - Security scanning
# - Code coverage
```

---

## Pull Request Configuration

### PR Creation
**Fallback (Azure CLI)**:
```bash
az repos pr create \
  --repository my-application \
  --source-branch "feature/12345/ST1/my-feature" \
  --target-branch main \
  --title "Implement new feature" \
  --work-items 12345
```

### PR Requirements
- [ ] All tests passing
- [ ] Code meets quality standards
- [ ] Code review approved
- [ ] Work item linked
- [ ] Documentation updated

---

## Project Standards

### Development Guidelines
Adapt these to your project:
- Code style: Follow project conventions
- Testing: Add tests for new features
- Documentation: Update relevant docs
- Security: No secrets in code

### Documentation Locations
```
docs/          # Project documentation
README.md      # Main project README
CONTRIBUTING.md # Contribution guidelines
```

---

## Quality Gates

### Code Quality
- [ ] Follows project coding standards
- [ ] No compilation/syntax errors
- [ ] Proper error handling
- [ ] Code is well-documented
- [ ] No hardcoded sensitive values

### Testing
- [ ] Unit tests for new code
- [ ] Integration tests (if applicable)
- [ ] Tests follow project conventions
- [ ] Edge cases covered
- [ ] All tests passing

### Documentation
- [ ] Code comments for complex logic
- [ ] README updated if needed
- [ ] API/interface documented
- [ ] Architecture docs updated

### Security & Best Practices
- [ ] No secrets in code or version control
- [ ] Input validation implemented
- [ ] Dependencies up to date
- [ ] Security best practices followed
- [ ] Performance considerations addressed

---

---

## Notes

- Customize this configuration for your specific project
- Replace placeholder commands with actual commands
- Add project-specific quality gates
- Document any special requirements
- Keep this file updated as project evolves
