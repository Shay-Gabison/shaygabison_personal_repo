---
name: configgen
description: 'Work with MDA ConfigGen (Configuration Generation) projects — C# code that defines Azure resource topologies and generates EV2 deployment artifacts. Covers the build-before-push workflow, resource types, deploy flags, DR patterns, manifest references, and the ConfigGen MCP tools for API lookup.'
---

# ConfigGen Skill

This skill helps you work with **ConfigGen** projects — C# codebases that declaratively define Azure resource topologies and **generate** EV2 deployment artifacts (ARM parameter files, shell extension configs, manifests).

## What is ConfigGen?

ConfigGen is a code-generation framework used across MDA (Microsoft Defender for Cloud Apps) services. Engineers define Azure resources in C# topology classes. **Building the project** runs the generator, which produces all deployment files:

- **ARM parameter JSON files** (`Ev2Deployment.V2/Parameters/`)
- **Shell extension parameter files** (`Ev2Deployment.V2/Parameters/ShellExtension/`)
- **Manifest JSON files** (`.configgen/`, `<service>Resources.Manifest/`)
- **Resource config details** (`.configgen/ResourceConfigDetails/`)
- **Rollout specs, scope bindings, service models** (EV2 orchestration files)

These generated files are **checked into the repo** alongside the C# source code. The CI pipeline expects them to be up-to-date.

---

## ⚠️ CRITICAL: Build Before Push

**You MUST build the ConfigGen project before committing/pushing.** The generated files must match the C# topology code. If you push C# changes without regenerating, the deployment will use stale parameter files.

> ⚠️ **ATTENTION: NEVER manually edit files under `Ev2Deployment.V2/` or `.configgen/`.** These are generated output — all changes MUST flow from C# topology code → build → generated files. Manual edits will be overwritten on the next build and may cause deployment failures. If you cannot build locally (e.g., SDK version mismatch), push only the C# changes and let the CI pipeline regenerate the files.

### How to Build

```bash
# From the service .Resources directory:
dotnet build <service>.Resources.sln

# Or build just the Topology project to check compilation:
dotnet build ConfigurationGeneration/<service>Resources.Topology/<service>Resources.Topology.csproj
```

The build:
1. Compiles the C# topology code
2. Runs the generator (`Ev2FilesGenerator` / `TtHelper.GetTopology()`)
3. Writes all output files to `Ev2Deployment.V2/` and `.configgen/`
4. These regenerated files should be included in your commit

### Workflow

1. Edit C# topology code (Environments, ResourceCreators, Manifest)
2. **Build the solution** — this regenerates all JSON/YAML artifacts
3. `git add` both the C# changes AND the regenerated files
4. Commit and push

**Never manually edit files under `Ev2Deployment.V2/Parameters/` or `.configgen/`.** They will be overwritten on the next build. All changes flow from C# → build → generated output.

---

## Project Structure

```
<service>.Resources/
├── <service>.Resources.sln                   # Solution file — BUILD THIS
├── ConfigurationGeneration/
│   ├── <service>Resources.Topology/          # C# topology (SOURCE OF TRUTH)
│   │   ├── Environments/                     # Staging.cs, Production.cs, Fairfax.cs, etc.
│   │   ├── ResourceCreators/                 # Factory classes per resource type
│   │   ├── Utils/                            # Naming helpers, constants
│   │   └── <service>Resources.Topology.csproj
│   ├── <service>Resources.Manifest/          # Manifest subject definitions
│   │   ├── ResourceManifestSubjects.cs
│   │   ├── Manifest/                         # Manifest JSON templates
│   │   └── <service>Resources.Manifest.csproj
│   └── ConfigFileBuild.UnitTests/            # Unit tests for generation
├── Ev2Deployment.V2/                         # GENERATED OUTPUT — do not hand-edit
│   ├── Parameters/                           # Per-resource-type parameter files
│   │   ├── KeyVaultAccessPolicy/
│   │   ├── ManagedIdentity/
│   │   ├── RoleAssignment/
│   │   ├── RemoveResource/
│   │   ├── StorageAccount/
│   │   └── ...
│   ├── Templates/                            # ARM templates
│   ├── ShellExtensionPackages/               # Shell extension scripts
│   ├── RolloutSpec/                          # EV2 rollout specifications
│   └── ScopeBinding/                         # EV2 scope bindings
└── .configgen/                               # GENERATED metadata
    └── ResourceConfigDetails/
```

---

## Core Concepts

### TopologyBase

The root class. Defines all environments and their resources. Key members:
- `Environments` — array of environment instances
- `RepositoryName`, `SquadName`, `ServiceTreeServiceId` — service metadata
- `GetResourceInfos()` — resolves all resources across all environments
- `ResourceAdjustments` — post-processing adjustments on generated resource infos
- `InheritDeployFlagFromParentResource` — topology-wide default for child deploy behavior

### EnvironmentBase

Each environment (Staging, Production, Fairfax, etc.) inherits from a base like `StagingBase`, `ProductionBase`, etc. Key members:
- `DataCenters` — all DCs in this environment
- `GeoPrimaryDataCenters` — primary (non-DR) DCs
- `ConstantProvider` — environment-specific constants (subscription IDs, etc.)
- `CreateDcSettings(dataCenters)` — **the main entry point** that iterates DCs and creates resources
- `ResourceAdjustments` — environment-level post-processing on resource names, properties, etc.
- `IsDeployable`, `IsProduction` — environment classification

### ResourceBase

All Azure resources inherit from `ResourceBase`. Key properties:

| Property | Type | Description |
|----------|------|-------------|
| `Subject` | `string` | Unique identifier for this resource instance |
| `Deploy` | `bool` | Whether to deploy (default: true). Set false for DR/reference-only |
| `Delete` | `bool` | Set true to delete via EV2 pipeline |
| `UsageScope` | `ResourceUsageScope` | Creation scope: `Dc`, `Environment`, `Global` |
| `ParametersFileId` | `string` | Groups resources into parameter files |
| `DeploymentWave` | `DeploymentWave` | Controls deployment ordering (wave + resolution scope) |
| `RoleAssignments` | `List<RoleAssignment>` | RBAC roles on this resource |
| `CustomDependencyRefs` | `List<ManifestReference>` | Explicit deployment dependencies |
| `Ev2ResourceDeletionManagedIdentityRef` | ref | MI used for deletion operations |
| `AllowUseInEnvironments` | `List<IEnvironment>` | Restrict resource to specific environments |

Child resources have additional:
- `InheritDeployFlagFromParentResource` — whether child inherits parent's `Deploy` flag (default: true on `RoleAssignment`)

### ManifestReference\<T\>

Cross-resource references that resolve to ARM resource IDs at generation time:

```csharp
new ManifestReference<ManagedIdentityManifest>(nameof(ManagedIdentitySubject.MyService))
new ManifestReference<ResourceGroupManifest>(nameof(ResourceGroupSubject.MyService))
new ManifestReference<KeyVaultManifest>(nameof(KeyVaultSubject.MyCerts))
```

### ResourceUsageScope vs ResourceAccessScope

- **`ResourceUsageScope`** — Where the resource itself is created:
  - `Dc` — one per data center
  - `Environment` — one per environment (shared across DCs)
  - `Global` — single global instance

- **`ResourceAccessScope`** — How far a reference/policy reaches:
  - `Dc` — same DC only
  - `Env` — all DCs in the environment

**Key insight**: When an `AccessPolicy` uses `AccessScope.Env`, the generator produces entries for resources from ALL DCs in the environment. If a referenced resource has `Deploy = false` in some DCs (e.g., DR), the ARM deployment will fail with `ResourceNotFound`.

### DR Region Pattern

Disaster Recovery regions typically have resources created but not deployed:

```csharp
// In CreateDcSettings:
if (DRRegions.Contains(dataCenterInfo))
{
    // Resources exist in topology for manifest resolution but aren't deployed
    foreach (var rg in CreateResourceGroups(dataCenterInfo))
    {
        rg.Deploy = false;
        yield return rg;
    }
}
```

To deploy a child resource (e.g., RoleAssignment) even when the parent has `Deploy = false`:
```csharp
rg.RoleAssignments.Add(new RoleAssignment(scope, miRef, AzureRole.Contributor)
{
    InheritDeployFlagFromParentResource = false  // Deploy this even though parent is non-deployed
});
```

### Resource Deletion

**Pattern 1: Delete a ConfigGen-managed resource**
```csharp
resource.Delete = true;
resource.Ev2ResourceDeletionManagedIdentityRef = new ManifestReference<ManagedIdentityManifest>("MyMI");
// MI must have Contributor or Owner on the target
```

**Pattern 2: Delete a non-ConfigGen resource (RemoveResource shell extension)**
```csharp
var remove = new RemoveResource(subject, nameCreator, rgRef)
{
    CustomARMResourceId = "/subscriptions/{sub}/resourceGroups/{rg}/providers/{type}/{name}",
    Ev2ResourceDeletionManagedIdentityRef = miRef
};
// MI must have Contributor or Owner on the target
```

### ResourceAdjustments

Post-processing hooks that modify generated resource info objects. Defined in environment classes:

```csharp
public override IResourceAdjustment[] ResourceAdjustments => new IResourceAdjustment[]
{
    new ResourceAdjustment<ResourceGroupInfo>((dc, rg) =>
    {
        if (rg.IsSubject("MyRG")) rg.Name = "custom-rg-name";
    }),
    new ResourceAdjustment<KeyVaultAccessPolicyInfo>((dc, kvapi) =>
    {
        if (kvapi.IsSubject("MyCerts")) kvapi.KeyVaultName = "my-custom-kv";
    }),
};
```

---

## Common Resource Types

| Type | Package | Description |
|------|---------|-------------|
| `ManagedIdentity` | `ConfigurationGeneration.Identity` | User-assigned managed identity |
| `ResourceGroup` | `ConfigurationGeneration.Infra` | Azure resource group |
| `RoleAssignment` | `ConfigurationGeneration.Infra` | Azure RBAC role assignment |
| `KeyVault` | `ConfigurationGeneration.Infra` | Azure Key Vault |
| `KeyVaultAccessPolicy` | `ConfigurationGeneration.Infra` | KV access policy for identities |
| `StorageAccount` | `ConfigurationGeneration.Infra` | Azure Storage Account |
| `AzureSubscription` | `ConfigurationGeneration.Infra` | Subscription reference |
| `AadApp` | `ConfigurationGeneration.Infra` | Azure AD application |
| `ShellExtension` | `ConfigurationGeneration.ShellExtension` | Custom EV2 shell extension |
| `AzShellExtension` | `ConfigurationGeneration.Infra` | Azure CLI-based shell extension |
| `RemoveResource` | `ConfigurationGeneration.RemoveResource` | Shell extension for resource deletion |
| `CompositeResourceBase` | `ConfigurationGeneration.Infra` | Resource that groups child resources |

---

## ConfigGen MCP Tools

**Always use these tools** before making ConfigGen changes to verify class names, constructors, and property signatures.

### `configgen-configgen-search-classes`
Find a class across all ConfigGen packages. Returns full namespace and package name.
```
className: "KeyVaultAccessPolicy"
partialMatch: true  // optional, for broader search
```

### `configgen-configgen-search-publicapi`
Search for any text (properties, methods, enums) across all library PublicAPI files.
```
query: "InheritDeployFlagFromParentResource"
```

### `configgen-configgen-get-core-library-publicapi`
Full public API for a core library. Core libraries: `Infra`, `RemoveResource`, `ShellExtension`, `Ev2FilesGeneration`.
```
library: "Infra"
```

### `configgen-configgen-get-core-library-docs`
Detailed documentation (doc comments, usage examples) for a core library.
```
library: "RemoveResource"
```

### `configgen-configgen-get-azure-library-publicapi`
Full public API for an Azure resource library: `Identity`, `CosmosDB`, `RedisCache`, `Synapse`, etc.
```
library: "Identity"
```

### `configgen-configgen-get-azure-library-example`
Example C# code for an Azure library.
```
library: "Identity"
```

### `configgen-configgen-get-shellextension-library-publicapi`
Public API for a shell extension library.
```
library: "DnsRecordShellExtension"
```

---

## Workflow Summary

1. **Read** the existing topology code (`Environments/`, `ResourceCreators/`)
2. **Use MCP tools** to look up API signatures for the classes you need
3. **Edit C# only** — environment files, resource creators, manifest subjects
4. **Build the solution** — `dotnet build <service>.Resources.sln`
5. **Verify** the regenerated JSON files make sense (spot-check `Ev2Deployment.V2/Parameters/`)
6. **Commit everything** — C# changes + regenerated output files together
7. **Push** — the CI pipeline will validate

---

## Common Pitfalls

1. **Pushing without building** — Generated files will be stale. Always build before push.
2. **Hand-editing generated JSON** — Changes will be lost on next build. Edit C# instead.
3. **Env-scope referencing non-deployed resources** — `AccessScope.Env` or `UsageScope.Environment` generates entries across ALL DCs. If a resource has `Deploy = false` in DR regions, the ARM deployment fails with `ResourceNotFound`.
4. **Missing `InheritDeployFlagFromParentResource = false`** — Child resources on `Deploy = false` parents won't deploy unless this is explicitly set to false.
5. **Enum iteration in policies** — `Enum.GetValues(typeof(SomeSubject))` iterates ALL members. Adding a new enum value affects every existing policy/access-policy that iterates the enum.
6. **Missing RBAC for deletion** — `RemoveResource` and `Delete = true` require the MI to have `Contributor` or `Owner` on the target resource.
7. **Forgetting to add constants** — New DCs/subscriptions need entries in `ConstantsProvider` (the `AdditionalDataCenterConstants` property).
