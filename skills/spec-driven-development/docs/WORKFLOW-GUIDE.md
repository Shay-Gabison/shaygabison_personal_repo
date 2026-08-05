# Spec-Driven Development Workflow

A comprehensive, structured workflow for implementing Azure DevOps work items with proper planning, implementation tracking, and completion verification.

## Overview

This workflow guides AI assistants and development teams through a systematic approach to implementing work items, ensuring:

✅ **Proper Planning** - Design review and approval before coding  
✅ **Structured Implementation** - Step-by-step execution with progress tracking  
✅ **Quality Gates** - Automated checks before PR creation  
✅ **Complete Documentation** - All decisions and context preserved in ADO  
✅ **Progress Continuity** - Resume work across sessions without losing context

## Quick Start

For setup instructions, see the [package README](../README.md).

Once configured, start the workflow with:
```
/spec-driven-development {workItemId}
```

Or naturally: "Let's work on work item 12345 using the spec-driven workflow"

## Workflow Structure

The workflow consists of three main processes:

### 📋 [Planning](../reference/planning.md)
**Phases 1-4**: Discovery, design, breakdown, ADO work item creation

**Key Activities:**
- Fetch/create work item in ADO
- Gather requirements and context
- Design solution (with user approval)
- Break into subtasks if needed (with user approval)
- Create ADO subtasks with dependencies
- Create test plans (if applicable)

**Deliverables:**
- Approved design document
- ADO subtasks created (if needed)
- Progress tracking initialized
- Test plan in ADO (if applicable)

### 💻 [Implementation](../reference/implementation.md)
**Phase 5**: Coding, testing, PR creation, monitoring

**Key Activities:**
- Create feature branches with dependency checking
- Implement code following project standards
- Run builds and tests
- Get user approval before commits/pushes
- Create PRs with proper linking
- Send team notifications
- Monitor PR review status
- Move to next subtask when ready

**Deliverables:**
- Implemented and tested code
- PRs created and linked to work items
- Progress documented and attached to ADO

### ✅ [Completion](../reference/completion.md)
**Phase 6**: Verification, documentation, cleanup

**Key Activities:**
- Verify all PRs merged
- Update work item status
- Attach documentation to ADO
- Clean up progress files (optional)

**Deliverables:**
- Work item closed
- Documentation preserved in ADO
- Clean local workspace

## Key Features

### 🎯 Intelligent Planning
- Automatic context gathering from codebase
- Pattern discovery from existing implementations
- Size validation (work items < 20 hours)
- Smart subtask breakdown with dependencies
- Test plan generation for features

### 🔄 Progress Tracking
- Session-independent context preservation
- `.spec-driven-progress/` directory for tracking
- All progress backed up to ADO work items
- Resume work from any point

### 🛡️ Quality Assurance
- Comprehensive quality gates
- Build verification before PRs
- Test coverage requirements
- Standards compliance checks
- User approval for all git operations

### 📊 Dependency Management
- PR status checking before branching
- Subtask predecessor/successor relations
- Sequential work item dependencies
- Automatic base branch selection

### 🤖 Automation
- MCP server integration for ADO
- Automatic PR creation and linking
- Team notifications via webhooks
- Progress file attachment to ADO

## Configuration

All project-specific settings are centralized in [`spec-driven-config.md`](../templates/spec-driven-config.md):

- **Azure DevOps**: Organization, project, repository, area path
- **Work Items**: Tags, sizing guidelines, hierarchy
- **Git**: Branch naming conventions
- **Tools**: MCP servers, PR scripts, build commands
- **Standards**: Development, testing, configuration standards
- **Quality Gates**: Required checks before PR creation

See [`spec-driven-config.md`](../templates/spec-driven-config.md) for a complete template.

## Usage Examples

### Starting a Work Item
```
User: "Let's implement work item 36004542"

Agent: [Reads work item from ADO]
       [Analyzes codebase patterns]
       [Creates design proposal]
       "Here's my design... approve?"

User: "Yes"

Agent: [Creates subtasks if needed]
       [Implements with progress tracking]
       [Creates PRs]
       [Updates ADO]
```

### Resuming After Break
```
User: "Continue work on 36004542"

Agent: [Reads .spec-driven-progress/36004542.md]
       "Resuming: 2 of 3 subtasks complete.
        Next: Implement integration tests"
       [Continues from checkpoint]
```

### Handling Large Work Items
```
Agent: "This work item is 35 hours, exceeding
        the 20-hour limit. I recommend breaking
        it into 2 work items:
        
        W1: Data Layer (18h)
        W2: API Layer (16h)
        
        Shall I create these work items?"

User: "Yes"

Agent: [Creates W1 and W2 in ADO]
       [Establishes dependencies]
       [Starts with W1]
```

## File Structure

```
skills/spec-driven-development/
├── SKILL.md                    # AI agent entry point
├── README.md                   # Human docs
├── docs/
│   ├── setup.md                # Configuration guide
│   └── WORKFLOW-GUIDE.md       # This file
├── reference/
│   ├── planning.md             # Phases 1-4: Planning
│   ├── implementation.md       # Phase 5: Implementation
│   ├── completion.md           # Phase 6: Completion
│   └── ado-operations.md       # ADO MCP operation reference
├── templates/
│   └── spec-driven-config.md   # Template for new projects
└── examples/
    └── spec-driven-config.example.md
```

## Integration Points

### With Azure DevOps
- Work item CRUD operations
- PR creation and linking
- Test plan management
- File attachments for documentation
- Work item relations (parent/child, predecessor/successor)

### With MCP Servers
- Automatic ADO server detection
- Fallback to Azure CLI
- Extensible tool integration

### With Project Standards
- References project standards and documentation files for patterns
- Follows project-specific quality gates
- Integrates with existing build/test commands
- Uses custom PR creation scripts

## Customization

### Adding Custom Phases

Edit workflow files to add custom phases:

```markdown
## Phase X: Custom Phase Name

### X.1 Step One
[Instructions]

### X.2 Step Two
[Instructions]
```

### Modifying Quality Gates

Update `spec-driven-config.md`:

```markdown
### Code Quality
- [ ] Your custom check here
- [ ] Another custom requirement
```

### Custom Branch Naming

Update `spec-driven-config.md`:

```markdown
### Branch Naming Conventions
**Custom Pattern**:
```
{customPrefix}/{workItemId}/{customSuffix}
```
```

### Language-Specific Adaptations

The workflow is language-agnostic but includes hooks for:
- Custom build commands
- Custom test commands
- Project-specific standards
- Language-specific quality gates

## Best Practices

### For Teams
1. **Review config together** - Ensure everyone agrees on conventions
2. **Keep config updated** - Review quarterly or when structure changes
3. **Document custom phases** - If you extend the workflow
4. **Share examples** - Create example work items showing the workflow
5. **Provide feedback** - Improve the workflow based on experience

### For AI Assistants
1. **Always read config first** - Load `spec-driven-config.md` at workflow start
2. **Wait for approvals** - Never proceed without user confirmation on key steps
3. **Track progress continuously** - Update progress files after each major step
4. **Preserve context** - Document decisions for future sessions
5. **Follow project patterns** - Reference project standards and existing code

### For Users
1. **Approve thoughtfully** - Review designs and breakdowns carefully
2. **Provide context** - Share business requirements and constraints
3. **Confirm git operations** - Always review diffs before approving commits
4. **Keep config current** - Update when team standards evolve
5. **Use progress files** - Refer back to design docs when needed

## Troubleshooting

### Common Issues

**"Workflow not found"**
- Ensure files are in `agent skills directory/`
- Check file permissions (should be readable)
- Verify file names match exactly

**"Configuration missing"**
- Replace all `{{TEMPLATE_VARIABLES}}` in your `spec-driven-config.md`
- Validate all required sections are complete

**"ADO connection failed"**
- Check MCP server is running and connected
- Try Azure CLI fallback: `az login`
- Verify credentials and permissions
- Check organization/project names in config

**"PR creation failed"**
- Verify PR script paths in config
- Check script permissions (should be executable)
- Try fallback Azure CLI command
- Verify branch exists and is pushed

**"Progress files not saved"**
- Check `.spec-driven-progress/` directory exists
- Verify write permissions
- Ensure directory is gitignored
- Check disk space

### Getting Help

1. **Review documentation** - Check all workflow files for guidance
2. **Check examples** - See `examples/` directory (if available)
3. **Ask AI assistant** - It can explain workflow steps
4. **Team discussion** - Review with team members
5. **File issues** - Report problems to workflow maintainers

## Migration Guide

### From Ad-Hoc Development

1. **Start small** - Try workflow on a small work item first
2. **Learn phases** - Understand planning → implementation → completion
3. **Adopt gradually** - Not all work items need full workflow initially
4. **Customize** - Adapt quality gates to your team's standards
5. **Iterate** - Improve configuration based on experience

### From Other Workflows

1. **Map phases** - Align your existing phases to workflow structure
2. **Merge quality gates** - Combine your checks with workflow's
3. **Preserve tools** - Configure existing PR scripts and build commands
4. **Maintain conventions** - Keep your branch naming and commit patterns
5. **Document differences** - Note customizations in config file

## Examples

See `examples/` directory for:
- **.NET Project** - Complete setup for .NET microservices
- **Python Project** - Configuration for Python applications
- **Generic Project** - Language-agnostic minimal setup

Each example includes:
- Customized `spec-driven-config.md`
- Project-specific `` files
- Sample work item walkthrough
- Integration patterns

## Contributing

To improve this workflow:

1. **Test changes** - Try modifications on real work items
2. **Document patterns** - Share successful approaches
3. **Provide examples** - Show how you adapted for your project
4. **Report issues** - Document problems and solutions
5. **Suggest improvements** - Propose enhancements

Refer to your project's contribution guidelines for pull request process.

## Version History

- **v1.0** (2025-11-30) - Initial genericized version
  - Extracted from Prevention.SecurityForAI project
  - Created template configuration system
  - Added adoption guide and examples
  - Documented customization points

## License

This workflow documentation is provided as-is for use in your projects. Customize freely to meet your team's needs.

## Related Documentation

- **[ADO Operations](../reference/ado-operations.md)** - Azure DevOps command examples
- **[Skill Overview](../SKILL.md)** - Workflow entry point
- **[Planning](../reference/planning.md)** - Phases 1-4
- **[Implementation](../reference/implementation.md)** - Phase 5
- **[Completion](../reference/completion.md)** - Phase 6
- **[Configuration Template](../templates/spec-driven-config.md)** - Setup template

---

**Ready to start?** 

1. Configure your project (copy template → customize → save)
2. Try the workflow on a small work item
3. Refine based on your team's feedback
4. Scale to more work items

**Questions?** Check the troubleshooting section or ask your AI assistant to explain any workflow step.
