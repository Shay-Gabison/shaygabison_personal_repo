---
name: configgen-development
description: "ConfigGen development workflow for MCAS platform services. Use when working on topology, parameter files, EV2 deployment manifests, or any ConfigGen project. Covers the generate-only workflow: edit Topology C# code, run dotnet build && dotnet run, validate generated EV2 files. NEVER edit manifest or EV2 files directly."
domain: "configgen"
confidence: "high"
tools:
  - name: "configgen"
    description: "ConfigGen MCP server for configgen project operations — schema validation, topology introspection, generation commands"
    when: "When working on any configgen project"
    install: "dotnet tool install --global ConfigurationGeneration.Mcp --add-source 'https://pkgs.dev.azure.com/microsoft/_packaging/WDATP/nuget/v3/index.json'"
---

# ConfigGen Development Skill

Development workflow for ConfigGen-based projects in the MCAS platform. ConfigGen generates EV2 deployment files from C# topology definitions — the generated files are NEVER edited by hand.

## When to Use This Skill

- Working on any ConfigGen project (proxyllom, TenantService, InlineConnectors, etc.)
- Adding or modifying parameter entries (PEs), service configurations, or deployment topology
- Adding cross-service parameter entries across data centers
- Reviewing or validating EV2 deployment files
- Debugging ConfigGen build or generation failures

## Core Principle: Generate, Never Edit

```
┌─────────────────────┐      dotnet build       ┌──────────────────────┐
│  Topology C# Code   │ ──── && dotnet run ────► │  EV2 Deployment      │
│  (YOU EDIT THIS)     │                          │  Files (READ-ONLY)   │
└─────────────────────┘                          └──────────────────────┘
         ✅ EDIT                                          ❌ NEVER EDIT
```

**The golden rule:** Only modify files in the Topology/ConfigurationGeneration folder. The manifest JSON files, EV2 deployment files (`Ev2Deployment.V2/`), and any generated output are **read-only artifacts** produced by `dotnet build && dotnet run`.

## Workflow

### Step 1: Make Changes in Topology Code

Edit the C# topology files in the `ConfigurationGeneration/` or `Topology/` folder. This is where all configuration is defined — service parameters, cross-service PEs, DC-level settings.

**Key files to modify:**
- `*.Topology.csproj` — the project file
- `*.cs` files — topology definitions, parameter entries, service configs

### Step 2: Generate EV2 Files

```bash
cd {project}/ConfigurationGeneration/{ProjectName}.Topology/
dotnet build && dotnet run
```

This regenerates all EV2 deployment files from the topology code. The output goes to `Ev2Deployment.V2/` (or similar output directory).

### Step 3: Validate Generated Output

After generation, validate the EV2 files as **read-only artifacts**:
- Check that expected parameter files exist for each DC/environment
- Verify parameter values are correct in the generated JSON
- Ensure cross-service PEs appear in ALL relevant DC parameter files
- Run any existing validation scripts

**Treat EV2 files as deployment artifacts** — we validate them the same way we'd validate a compiled binary. We read them, we don't write them.

## Patterns

### Cross-Service Parameter Entries

Cross-service PEs must be added to EACH Inline DC's existing parameter file. This is done through the Topology C# code, NOT by editing parameter files directly.

In the topology code, add the PE so it generates across all target DCs:

```csharp
// Example: Adding a PE that applies to multiple DCs
AddParameterEntry("MyNewParameter", value, targetDcs: allInlineDcs);
```

After `dotnet build && dotnet run`, verify the PE appears in every target DC's generated parameter file.

### Shared Libraries

ConfigGen projects depend on shared libraries:

| Library | Repository | Purpose |
|---------|-----------|---------|
| MDA.ConfigGen.Library | `https://msazure.visualstudio.com/MCAS/_git/MDA.ConfigGen.Library` | Shared ConfigGen base classes and utilities |
| Platform.Resources | `https://msazure.visualstudio.com/MCAS/_git/Platform.Resources` | Shared platform resource definitions |

When adding new features or PEs, check these repos for:
- Existing base classes to inherit from
- Shared constants and enums
- Platform-level resource definitions that your topology should reference

### Using ConfigGen MCP

The ConfigGen MCP server provides tools for schema validation, topology introspection, and generation commands.

**Installation (one-time):**
```bash
dotnet tool install --global ConfigurationGeneration.Mcp \
  --add-source "https://pkgs.dev.azure.com/microsoft/_packaging/WDATP/nuget/v3/index.json"
```

Use MCP tools (prefixed `configgen_*` or `configgen-*`) when available. Fall back to direct `dotnet build && dotnet run` when MCP is unavailable.

## Examples

### Adding a new parameter entry

```bash
# 1. Edit the topology C# code
#    (add your PE in the appropriate .cs file)

# 2. Build and generate
cd proxyllom/InlineConnectors.Resources/ConfigurationGeneration/InlineConnectorsResources.Topology/
dotnet build && dotnet run

# 3. Validate the generated output
# Check that the PE appears in all expected DC parameter files
find ../Ev2Deployment.V2/ -name "*.json" | xargs grep "MyNewParameter"
```

### Validating generated files after changes

```bash
# After dotnet build && dotnet run, diff the generated output
git diff Ev2Deployment.V2/

# Verify no unexpected changes — only the intended PEs/configs should change
# If unexpected files changed, the topology code may have side effects
```

## Anti-Patterns

- **❌ NEVER edit manifest JSON files directly** — only modify via `dotnet build && dotnet run` on the Topology project
- **❌ NEVER edit Ev2Deployment.V2/ files directly** — these are generated output, always regenerate from topology
- **❌ NEVER add a cross-service PE to only one DC's parameter file** — it must appear in ALL relevant DCs (use topology code to ensure this)
- **❌ NEVER skip validation after generation** — always verify the generated output matches your intent
- **❌ NEVER commit topology changes without running generation** — the generated files must be in sync with the topology code
