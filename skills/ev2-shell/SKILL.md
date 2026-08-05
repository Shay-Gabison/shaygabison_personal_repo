---
name: ev2-shell
description: 'Create, configure, and deploy MDA Ev2 Shell Extension scripts. Covers the generator values file schema, managed identities, VNET configuration, pipeline execution, Jinja templating, and troubleshooting. Uses the MDA.Ev2.Shell.Generator repository.'
---

You are an expert on the MDA Ev2 Shell Extension Generator. Use this knowledge to help users create, configure, troubleshoot, and deploy shell extensions via the Ev2 pipeline. The source repository is at `Dev/MDA.Ev2.Shell.Generator/`.

# MDA Ev2 Shell Extension Generator

## Repository Purpose

The MDA Ev2 Shell Extension Generator simplifies creating and deploying Azure Container Instances (ACI) that execute shell scripts during Ev2 deployments. Shell extensions are used for automation tasks like database migrations, secret management, configuration updates, and data operations that run as part of the Ev2 release pipeline.

**Key Concept**: You write a shell script, define its configuration in a values file (JSON or YAML), and the generator creates all the Ev2 ServiceModel/RolloutSpec/Parameters files needed to deploy it as an ACI container with proper networking, identity, and environment setup.

## Repository Structure

```
MDA.Ev2.Shell.Generator/
├── scripts/                    # Shell scripts organized by team/extension
│   └── {team}/
│       └── {extension-name}/
│           ├── {script}.sh     # Main shell script
│           ├── requirements.txt # Python dependencies (if applicable)
│           ├── src/            # Python source code (if applicable)
│           └── README.md       # Extension documentation
├── values/                     # Configuration files organized by team/extension/env
│   └── {team}/
│       └── {extension-name}/
│           ├── stg/            # Staging environment configs
│           │   └── *.values.json or *.values.yaml
│           └── prd/            # Production environment configs
│               └── *.values.json or *.values.yaml
├── templates/                  # Jinja2 templates for Ev2 files
│   ├── Parameters.json.j2
│   ├── RolloutSpec.json.j2
│   ├── ServiceModel.json.j2
│   └── schema.json            # JSON schema for values files
├── .pipelines/                # OneBranch pipeline definitions
└── README.md                  # Main documentation
```

## How to Add a New Shell Extension

Follow these steps to create a new shell extension:

### Step 1: Create Your Shell Script

Create a directory under `scripts/{team}/{extension-name}/`:

```bash
mkdir -p scripts/{team}/{extension-name}
```

Create your shell script (e.g., `my-script.sh`):

```bash
#!/bin/bash

# Standard pattern: retry az login with MSI
n=0
signInExitCode=-1
until [ "$n" -ge 5 ]; do
    if [ -z "$CLOUD_TYPE" ]; then
        echo "CLOUD_TYPE environment variable is not set. Will default to Public Cloud."
    else
        az cloud set --name "$CLOUD_TYPE"
    fi
    az login --identity && signInExitCode=0 && break
    n=$((n+1))
    echo "Failed to login az with identity. Retrying in 15 seconds [attempt: $n]"
    sleep 15
done

if [ $signInExitCode -eq 0 ]; then
    echo "Successfully logged in az with identity"
    
    # Install Python dependencies if needed
    python3 -m pip install -r requirements.txt
    
    # Run your script logic
    python3 src/main.py \
        --arg1 "$ARG1_ENV_VAR" \
        --arg2 "$ARG2_ENV_VAR"
else
    echo "Failed logging in az with identity"
    exit 1
fi
```

**Key Pattern**: Scripts execute inside ACI containers with:
- Azure CLI pre-installed
- Managed identity for authentication
- Environment variables from values file
- Python 3 available for automation

### Step 2: Create Values Files

Create a directory structure under `values/{team}/{extension-name}/`:

```bash
mkdir -p values/{team}/{extension-name}/stg
mkdir -p values/{team}/{extension-name}/prd
```

Create a values file for each environment/region combination. Both JSON and YAML formats are supported (e.g., `values/{team}/{extension-name}/stg/RS-02.values.json` or `PROD-02.values.yaml`):

```json
{
  "subscriptionId": "02b44435-dd28-41eb-98e3-b1b191c4d908",
  "subnetIds": [
    "/subscriptions/02b44435-dd28-41eb-98e3-b1b191c4d908/resourceGroups/mps-mda-plat-ev2shellgenerator-stg-weu/providers/Microsoft.Network/virtualNetworks/mps-mda-plat-ev2shellgenerator-stg-weu/subnets/ev2-aci-subnet"
  ],
  "projectName": "MyProject",
  "envAlias": "STG",
  "shellExtensionName": "my-extension",
  "shellCommand": [
    "/bin/bash",
    "-c",
    "my-script.sh"
  ],
  "envVars": {
    "ARG1_ENV_VAR": "value1",
    "ARG2_ENV_VAR": "value2",
    "CLOUD_TYPE": "AzureCloud"
  },
  "userAssignedIdentities": [
    "/subscriptions/91d8605f-b80a-4b1c-bca1-6ec55bfd1deb/resourcegroups/RS-2-EUW-Mongo-RG/providers/Microsoft.ManagedIdentity/userAssignedIdentities/rs-2-westeurope-mongos-dataops-msi"
  ]
}
```

**Required Fields**:
- `subscriptionId`: Where the ACI will be deployed (get from README infrastructure table)
- `subnetIds`: VNET subnet for ACI (get from README infrastructure table)
- `projectName`: Human-readable project name
- `envAlias`: Environment (STG, PRD, FF, FM)
- `shellExtensionName`: Must match your directory name
- `shellCommand`: Command to execute inside the container
- `envVars`: Environment variables passed to your script

**Common Optional Fields**:
- `location`: Azure region (default: `westeurope`). **Recommended**: Always set explicitly based on target environment — see [Location Recommendation](#values-file-format-reference).
- `userAssignedIdentities`: Infra standard MI resource IDs for cross-subscription access
- `secretEnvVars`: Secrets from Key Vault
- `maxExecutionTime`: Execution timeout (default: PT1H)

### Step 3: Reference Infrastructure Values

The README contains the **single source of truth** for Ev2 subscription IDs and subnet paths. Always use these values:

| Environment | DataCenter | Subscription ID | Subnet ARM ID |
|-------------|-----------|-----------------|---------------|
| STG | WestEurope | 02b44435-dd28-41eb-98e3-b1b191c4d908 | `/subscriptions/02b44435-dd28-41eb-98e3-b1b191c4d908/resourceGroups/mps-mda-plat-ev2shellgenerator-stg-weu/providers/Microsoft.Network/virtualNetworks/mps-mda-plat-ev2shellgenerator-stg-weu/subnets/ev2-aci-subnet` |
| PRD | WestEurope | 6a8b78f0-8491-4ef0-ac1a-e3071fc0bd10 | `/subscriptions/6a8b78f0-8491-4ef0-ac1a-e3071fc0bd10/resourceGroups/mps-mda-plat-ev2shellgenerator-prd-weu/providers/Microsoft.Network/virtualNetworks/mps-mda-plat-ev2shellgenerator-prd-weu/subnets/ev2-aci-subnet` |
| PRD | EastUs2 | ab14cdf9-b4f3-4155-967b-482791d3d78b | `/subscriptions/ab14cdf9-b4f3-4155-967b-482791d3d78b/resourceGroups/mps-mda-plat-ev2shellgenerator-prd-eus2/providers/Microsoft.Network/virtualNetworks/mps-mda-plat-ev2shellgenerator-prd-eus2/subnets/ev2-aci-subnet` |

See README for the complete table with all environments and regions.

### Step 4: Run the Pipeline

There are two pipelines for this repo:

| Pipeline | Definition ID | Purpose | Branch Convention |
|----------|--------------|---------|-------------------|
| **[Buddy Build](https://dev.azure.com/msazure/MCAS/_build?definitionId=375884)** | 375884 | Testing and validation in STG environment | Run on **feature/side branches** during development |
| **[Official Build](https://dev.azure.com/msazure/MCAS/_build?definitionId=375925)** | 375925 | Production deployments to STG/PRD/FF with approval gates | Run only on **main branch** after PR merge |

**Key Differences**:
- **Buddy pipeline**: Deploys to STG only. Used for iterative testing during development. Always triggered on your working branch.
- **Official pipeline**: Deploys to STG, PRD, or FF (selectable). Includes approval stages for PRD and FF environments. Should only run against the `main` branch after your PR is merged.

**Buddy Build** — Queue with these parameters:

```bash
az pipelines run \
    --id 375884 \
    --org https://dev.azure.com/msazure \
    --project MCAS \
    --branch {your-branch} \
    --parameters \
        valuesPath="{team}/{extension-name}/{env}/{file}.values.json" \
        scriptsPath="{team}/{extension-name}" \
        valuesFormat=json  # or yaml, matching your file format
```

**⚠️ CRITICAL**: Paths must be **RELATIVE** to `values/` and `scripts/` directories. The pipeline automatically prepends these prefixes via `$(Ev2ValuesDir)/` and `$(Ev2ScriptsDir)/`.

**Example** (for mma/conn-string-secret-extractor):

```bash
az pipelines run \
    --id 375884 \
    --org https://dev.azure.com/msazure \
    --project MCAS \
    --branch users/jocohe/conn-string-extractor \
    --parameters \
        valuesPath="mma/conn-string-secret-extractor/stg/RS-02.values.json" \
        scriptsPath="mma/conn-string-secret-extractor" \
        valuesFormat=json
```

**❌ WRONG** (double-prefix bug):
```bash
valuesPath="values/mma/..."  # Pipeline will create values/values/mma/...
scriptsPath="scripts/mma/..." # Pipeline will create scripts/scripts/mma/...
```

## Pipeline Configuration Deep Dive

### Pipeline Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `valuesPath` | string | **RELATIVE** path from `values/` directory to your values JSON file | `mma/conn-string-secret-extractor/stg/RS-02.values.json` |
| `scriptsPath` | string | **RELATIVE** path from `scripts/` directory to your script directory | `mma/conn-string-secret-extractor` |
| `valuesFormat` | string | Format of values file (`json` or `yaml`) | `json` |
| `overrideEnvVars` | string | Runtime environment variable overrides (optional) | `-D DRY_RUN false` |

### The NO-PREFIX Rule

**Why This Matters**: The OneBranch pipeline template uses YAML variables to construct full paths:

```yaml
# Inside pipeline template
- script: jinja templates/ServiceModel.json.j2 -d $(Ev2ValuesDir)/$(valuesPath)
```

Where:
- `$(Ev2ValuesDir)` = `values/`
- `$(valuesPath)` = your parameter (e.g., `mma/conn-string-secret-extractor/stg/RS-02.values.json`)

**Result**: `values/mma/conn-string-secret-extractor/stg/RS-02.values.json` ✅

If you pass `valuesPath="values/mma/..."`, you get:
- `values/values/mma/...` ❌

### Runtime Environment Variable Overrides

To allow runtime overrides of environment variables, use Jinja2 templating in your values file:

```json
{
  "envVars": {
    "DRY_RUN": "{{ DRY_RUN | default('true') }}",
    "DELETE_DISKS": "{{ DELETE_DISKS | default('false') }}"
  }
}
```

Then override at pipeline runtime:

```bash
az pipelines run \
    --id 375884 \
    ... \
    --parameters \
        valuesPath="..." \
        scriptsPath="..." \
        valuesFormat=json \
        overrideEnvVars="-D DRY_RUN false -D DELETE_DISKS true"
```

**Note**: All override values are strings (`"true"`/`"false"`, not booleans).

## Frequently Used Managed Identities

Binding a managed identity to a shell extension script is done through the `userAssignedIdentities[]` configuration property in the generator values file.

```json
{
    "userAssignedIdentities": [
        "/subscriptions/{subscriptionId}/resourcegroups/{resourceGroupName}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/{managedIdentityName}"
    ]
}
```

### Read Only Access

Managed Identities with read only access to ARM resources in each environment:

| Environment | MI ARM Resource ID |
|---|---|
| MSFT | `/subscriptions/c5d1c552-a815-4fc8-b12d-ab444e3225b1/resourcegroups/defender-infra-managed-identities-weu/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mps-stg-infra-arm-exporter` |
| AME | `/subscriptions/bf55aab8-7f9b-4204-83eb-f693ecb41019/resourcegroups/defender-infra-managed-identities-wus/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mps-prd-ame-infra-arm-exporter` |
| USME | `/subscriptions/2f981b86-3052-4810-97ad-d8abc4e0caf6/resourcegroups/defender-infra-managed-identities-usg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mps-prd-ff-infra-arm-exporter` |

### Terraform Server Managed Identities

Managed Identities used by Terraform Server in each environment, these identities have contributor access to most legacy resources in the environment:

| Environment | MI ARM Resource ID |
|---|---|
| MSFT | `/subscriptions/91d8605f-b80a-4b1c-bca1-6ec55bfd1deb/resourcegroups/OPSRS-0-EUW-Global-RG/providers/Microsoft.ManagedIdentity/userAssignedIdentities/terraform-server` |
| AME | `/subscriptions/570fa9b6-c460-4f06-8c3b-303f3060f9c9/resourcegroups/OPS-0-EUW-Global-RG/providers/Microsoft.ManagedIdentity/userAssignedIdentities/terraform-server` |
| USME | `/subscriptions/11c8c4ad-e458-4222-bd3c-1d44a11eacbc/resourcegroups/GOPS-0-USGV-Global-RG/providers/Microsoft.ManagedIdentity/userAssignedIdentities/terraform-server` |

> **Haven't Found Your Managed Identity?** The above managed identities are some of the most commonly used ones. If you haven't found the one you need, you can use ConfigGen to create a managed identity configuration for your specific needs.

> **Important**: It is **recommended** to use a dedicated managed identity for your use case to follow least privilege best practices. Choose the best identity suitable for your specific requirements and coordinate with your team lead or the Platform Axon team for guidance on identity selection.

## Pre-Provisioned Virtual Networks

> ⚠️ **VNET Requirement (Effective April 1st, 2026)**: All Ev2 Shell scripts are required to run attached to a VNET with explicit outbound connection using NAT Gateway and service tagged public IPs. This is a mandatory security and compliance requirement.

The Platform Axon team has pre-provisioned virtual networks for Ev2 Shell Generator scripts. When configuring your shell extension, you must specify one of the approved VNETs from the list below.

| Environment | DataCenter | Azure Location | Subnet ARM ID |
|---|---|---|---|
| STG | WestEurope | westeurope | `/subscriptions/02b44435-dd28-41eb-98e3-b1b191c4d908/resourceGroups/mps-mda-plat-ev2shellgenerator-stg-weu/providers/Microsoft.Network/virtualNetworks/mps-mda-plat-ev2shellgenerator-stg-weu/subnets/ev2-aci-subnet` |
| STG | NorthEurope | northeurope | `/subscriptions/d4824d43-49bd-472d-95af-4f5494b6549f/resourceGroups/mps-mda-plat-ev2shellgenerator-stg-neu/providers/Microsoft.Network/virtualNetworks/mps-mda-plat-ev2shellgenerator-stg-neu/subnets/ev2-aci-subnet` |
| PRD | WestUs | westus | `/subscriptions/5dbf2c00-8b54-4e79-a4a5-d55a095b7bd4/resourceGroups/mps-mda-plat-ev2shellgenerator-prd-wus/providers/Microsoft.Network/virtualNetworks/mps-mda-plat-ev2shellgenerator-prd-wus/subnets/ev2-aci-subnet` |
| PRD | WestEurope | westeurope | `/subscriptions/6a8b78f0-8491-4ef0-ac1a-e3071fc0bd10/resourceGroups/mps-mda-plat-ev2shellgenerator-prd-weu/providers/Microsoft.Network/virtualNetworks/mps-mda-plat-ev2shellgenerator-prd-weu/subnets/ev2-aci-subnet` |
| PRD | EastUs2 | eastus2 | `/subscriptions/ab14cdf9-b4f3-4155-967b-482791d3d78b/resourceGroups/mps-mda-plat-ev2shellgenerator-prd-eus2/providers/Microsoft.Network/virtualNetworks/mps-mda-plat-ev2shellgenerator-prd-eus2/subnets/ev2-aci-subnet` |
| PRD | SouthUk | uksouth | `/subscriptions/0c2460b8-943c-493c-9ec8-e4c9f92dfca0/resourceGroups/mps-mda-plat-ev2shellgenerator-prd-uks/providers/Microsoft.Network/virtualNetworks/mps-mda-plat-ev2shellgenerator-prd-uks/subnets/ev2-aci-subnet` |
| PRD | WestUs2 | westus2 | `/subscriptions/8f5e347b-6299-480d-a2e6-ec787ccc78d1/resourceGroups/mps-mda-plat-ev2shellgenerator-prd-wus2/providers/Microsoft.Network/virtualNetworks/mps-mda-plat-ev2shellgenerator-prd-wus2/subnets/ev2-aci-subnet` |
| PRD | EastUs | eastus | `/subscriptions/1e5d9e1c-2db4-42e6-a286-85e2a4aac551/resourceGroups/mps-mda-plat-ev2shellgenerator-prd-eus/providers/Microsoft.Network/virtualNetworks/mps-mda-plat-ev2shellgenerator-prd-eus/subnets/ev2-aci-subnet` |
| PRD | NorthEurope | northeurope | `/subscriptions/df3b5fd7-f3d7-4638-8d0b-d3b7b551342c/resourceGroups/mps-mda-plat-ev2shellgenerator-prd-neu/providers/Microsoft.Network/virtualNetworks/mps-mda-plat-ev2shellgenerator-prd-neu/subnets/ev2-aci-subnet` |
| PRD | CentralUs | centralus | `/subscriptions/be7d4e48-fa98-4a8f-ad98-b27aa907c7f1/resourceGroups/mps-mda-plat-ev2shellgenerator-prd-cus/providers/Microsoft.Network/virtualNetworks/mps-mda-plat-ev2shellgenerator-prd-cus/subnets/ev2-aci-subnet` |
| PRD | WestUk | ukwest | `/subscriptions/80eea7de-85b3-4c39-b515-93358566e3ca/resourceGroups/mps-mda-plat-ev2shellgenerator-prd-ukw/providers/Microsoft.Network/virtualNetworks/mps-mda-plat-ev2shellgenerator-prd-ukw/subnets/ev2-aci-subnet` |
| PRD | WestCentralUs | westcentralus | `/subscriptions/2c73315a-5711-41e5-b6a4-37a08a06ccd7/resourceGroups/mps-mda-plat-ev2shellgenerator-prd-wcus/providers/Microsoft.Network/virtualNetworks/mps-mda-plat-ev2shellgenerator-prd-wcus/subnets/ev2-aci-subnet` |
| FF | UsGovVirginia | usgovvirginia | `/subscriptions/1e72c20d-8f0f-42c4-b3d3-425a5fed97e1/resourceGroups/mps-mda-plat-ev2shellgenerator-ff-usgv/providers/Microsoft.Network/virtualNetworks/mps-mda-plat-ev2shellgenerator-ff-usgv/subnets/ev2-aci-subnet` |
| FF | UsGovTexas | usgovtexas | `/subscriptions/1df738d9-e54c-452a-a0fa-9f6b7752b020/resourceGroups/mps-mda-plat-ev2shellgenerator-ff-usgt/providers/Microsoft.Network/virtualNetworks/mps-mda-plat-ev2shellgenerator-ff-usgt/subnets/ev2-aci-subnet` |
| FM | UsModVirginia | usgovvirginia | `/subscriptions/e85163f6-95a1-4950-8885-7891f35685bd/resourceGroups/mps-mda-plat-ev2shellgenerator-fm-usmv/providers/Microsoft.Network/virtualNetworks/mps-mda-plat-ev2shellgenerator-fm-usmv/subnets/ev2-aci-subnet` |
| FM | UsModTexas | usgovtexas | `/subscriptions/5b84a105-825f-4ece-96bd-be5a58fc31fb/resourceGroups/mps-mda-plat-ev2shellgenerator-fm-usmt/providers/Microsoft.Network/virtualNetworks/mps-mda-plat-ev2shellgenerator-fm-usmt/subnets/ev2-aci-subnet` |

### VNET Configuration Example

To comply with the VNET requirement, ensure your generator values file includes the appropriate VNET configuration using the `subnetIds` field:

```json
{
    "subnetIds": [
        "/subscriptions/02b44435-dd28-41eb-98e3-b1b191c4d908/resourceGroups/mps-mda-plat-ev2shellgenerator-stg-weu/providers/Microsoft.Network/virtualNetworks/mps-mda-plat-ev2shellgenerator-stg-weu/subnets/ev2-aci-subnet"
    ]
}
```

Contact the Platform Axon team if you need assistance with VNET selection or configuration.

### Cross-Subscription Identity

MSIs support cross-subscription scenarios:
- ACI container runs in subscription A (e.g., STG shell generator subscription)
- MSI defined in subscription B (e.g., infra/team subscription)
- MSI can access resources in subscription C (e.g., Key Vault, Cosmos DB)

**How It Works**:
1. ACI container is assigned the MSI via `userAssignedIdentities`
2. Container runs `az login --identity` to authenticate as the MSI
3. MSI's RBAC permissions grant access to target resources

### Required RBAC Permissions

Ensure the MSI has appropriate role assignments on target resources:
- **Key Vault**: `Key Vault Secrets User` or `Key Vault Secrets Officer`
- **Cosmos DB**: `DocumentDB Account Contributor` or custom roles
- **Storage**: `Storage Blob Data Contributor` for blob access

## Values File Format Reference

Values files can be written in **JSON** (`.values.json`) or **YAML** (`.values.yaml`). Both formats are fully supported by the pipeline. Set the `valuesFormat` pipeline parameter to match your file format.

> **⚠️ Location Recommendation**: Although `location` defaults to `westeurope`, **always explicitly set the `location` field** in your values file based on the target environment and region. Relying on the default can cause unexpected deployments to the wrong region, especially when copying values files between environments.

### Minimal Example (JSON)

```json
{
  "subscriptionId": "02b44435-dd28-41eb-98e3-b1b191c4d908",
  "location": "westeurope",
  "subnetIds": ["/subscriptions/.../subnets/ev2-aci-subnet"],
  "projectName": "MyProject",
  "envAlias": "STG",
  "shellExtensionName": "my-extension",
  "shellCommand": ["/bin/bash", "-c", "my-script.sh"]
}
```

### Minimal Example (YAML)

```yaml
subscriptionId: "02b44435-dd28-41eb-98e3-b1b191c4d908"
location: "westeurope"
subnetIds:
  - "/subscriptions/.../subnets/ev2-aci-subnet"
projectName: MyProject
envAlias: STG
shellExtensionName: my-extension
shellCommand: ["/bin/bash", "-c", "my-script.sh"]
```

### Complete Example with Secrets (JSON)

```json
{
  "subscriptionId": "02b44435-dd28-41eb-98e3-b1b191c4d908",
  "location": "westeurope",
  "subnetIds": [
    "/subscriptions/02b44435-dd28-41eb-98e3-b1b191c4d908/resourceGroups/mps-mda-plat-ev2shellgenerator-stg-weu/providers/Microsoft.Network/virtualNetworks/mps-mda-plat-ev2shellgenerator-stg-weu/subnets/ev2-aci-subnet"
  ],
  "projectName": "MyProject",
  "envAlias": "STG",
  "shellExtensionName": "my-extension",
  "shellCommand": ["/bin/bash", "-c", "my-script.sh"],
  "maxExecutionTime": "PT2H",
  "envVars": {
    "KEY_VAULT_URI": "https://my-vault.vault.azure.net/",
    "CLOUD_TYPE": "AzureCloud"
  },
  "secretEnvVars": [
    {
      "name": "DB_PASSWORD",
      "secretId": "https://my-vault.vault.azure.net/secrets/db-password"
    }
  ],
  "userAssignedIdentities": [
    "/subscriptions/91d8605f-b80a-4b1c-bca1-6ec55bfd1deb/resourcegroups/RS-2-EUW-Mongo-RG/providers/Microsoft.ManagedIdentity/userAssignedIdentities/rs-2-westeurope-mongos-dataops-msi"
  ]
}
```

### Environment-Specific Values

Create separate files for each environment/region combination:

```
values/
└── {team}/
    └── {extension-name}/
        ├── stg/
        │   └── RS-02.values.json        # STG WestEurope
        └── prd/
            ├── Prod-01.values.json      # PRD WestUs
            ├── Prod-02.values.json      # PRD WestEurope
            ├── Prod-03.values.json      # PRD EastUs2
            ├── Prod-04.values.json      # PRD UKSouth
            └── Prod-05.values.json      # PRD WestUs2
```

Each file should have:
- Correct `subscriptionId` for that environment/region
- Correct `subnetIds` for that environment/region
- Appropriate `envAlias` (STG, PRD, FF, FM)
- Environment-specific `envVars` (Key Vault URIs, database endpoints, etc.)

## Common Pitfalls and Gotchas

### 1. Pipeline Path Prefixes

**Problem**: Passing `valuesPath="values/mma/..."` causes pipeline to fail with "file not found"

**Why**: Pipeline prepends `values/` automatically, creating `values/values/mma/...`

**Solution**: Always use relative paths without the `values/` or `scripts/` prefix

### 2. Subnet ID Typos

**Problem**: ACI deployment fails with subnet access errors

**Why**: Subnet ARM IDs are long and easy to mistype

**Solution**: Copy subnet IDs directly from README infrastructure table; never type manually

### 3. Subscription Mismatch

**Problem**: Shell extension deploys but can't access resources

**Why**: MSI lacks permissions in target subscription, or wrong subscription used for ACI

**Solution**:
- Verify `subscriptionId` matches README table for your environment
- Verify MSI has RBAC permissions on target resources
- Check MSI subscription vs ACI subscription vs resource subscription

### 4. Missing Environment Variables

**Problem**: Script fails with "environment variable not set"

**Why**: Values file doesn't include all required `envVars` for your script

**Solution**: Document all required environment variables in your script's README; validate values file has them

### 5. Cloud Type for Gov Cloud

**Problem**: `az login --identity` fails in Government Cloud environments

**Why**: Default cloud is AzureCloud; Gov Cloud requires explicit `CLOUD_TYPE` setting

**Solution**: Set `"CLOUD_TYPE": "AzureUSGovernment"` for FF/FM environments

```json
{
  "envAlias": "FF",
  "envVars": {
    "CLOUD_TYPE": "AzureUSGovernment"
  }
}
```

### 6. Script Permissions

**Problem**: Script fails with "permission denied"

**Why**: Shell script doesn't have execute permissions

**Solution**: Ensure scripts are executable before committing:

```bash
chmod +x scripts/{team}/{extension-name}/*.sh
git add scripts/{team}/{extension-name}/*.sh
git commit -m "Add executable script"
```

### 7. Timeout Issues

**Problem**: ACI container terminates before script completes

**Why**: Default `maxExecutionTime` is PT1H (1 hour)

**Solution**: Increase timeout for long-running operations:

```json
{
  "maxExecutionTime": "PT2H"  // 2 hours
}
```

## Testing and Validation

### Local Testing

Test your script locally before running in Ev2:

```bash
# Navigate to script directory
cd scripts/{team}/{extension-name}

# Install dependencies
pip install -r requirements.txt

# Set environment variables
export KEY_VAULT_URI="https://..."
export SOURCE_SECRET_NAME="..."

# Run script
bash my-script.sh
```

### Buddy Build Testing

Always test in buddy build before merging:

1. Create a feature branch
2. Add your script and values files
3. Queue buddy build pipeline
4. Monitor ACI execution in Azure Portal
5. Check logs for errors
6. Iterate until successful

### Official Build

After buddy build succeeds and PR is merged to `main`:

1. Queue the [Official pipeline](https://dev.azure.com/msazure/MCAS/_build?definitionId=375925) **from the `main` branch**
2. Select the target environment (STG, PRD, or FF)
3. For PRD and FF: an approval gate will pause the deployment until a reviewer approves
4. Monitor Ev2 deployment in the target environment

> **Note**: The Official pipeline should **only** be run against the `main` branch. The Buddy pipeline is for testing on feature branches.

## Buddy Build Retrigger Commands

If you need to re-run a buddy build with different parameters:

**Template**:
```bash
az pipelines run \
    --id 375884 \
    --org https://dev.azure.com/msazure \
    --project MCAS \
    --branch {your-branch-name} \
    --parameters \
        valuesPath="{relative-path-to-values-file}" \
        scriptsPath="{relative-path-to-scripts-dir}" \
        valuesFormat=json
```

**Example** (conn-string-secret-extractor):
```bash
az pipelines run \
    --id 375884 \
    --org https://dev.azure.com/msazure \
    --project MCAS \
    --branch users/jocohe/conn-string-extractor \
    --parameters \
        valuesPath="mma/conn-string-secret-extractor/stg/RS-02.values.json" \
        scriptsPath="mma/conn-string-secret-extractor" \
        valuesFormat=json
```

**With Runtime Overrides**:
```bash
az pipelines run \
    --id 375884 \
    --org https://dev.azure.com/msazure \
    --project MCAS \
    --branch users/jocohe/my-feature \
    --parameters \
        valuesPath="mma/my-extension/stg/config.values.json" \
        scriptsPath="mma/my-extension" \
        valuesFormat=json \
        overrideEnvVars="-D DRY_RUN false -D VERBOSE true"
```

## File Naming Conventions

### Scripts Directory

```
scripts/{team}/{extension-name}/
├── {extension-name}.sh          # Main script (matches directory name)
├── requirements.txt             # Python dependencies (if applicable)
├── src/                         # Python source code (if applicable)
│   └── main.py
└── README.md                    # Extension documentation
```

### Values Directory

```
values/{team}/{extension-name}/
├── stg/
│   └── RS-02.values.json        # WestEurope staging
└── prd/
    ├── Prod-01.values.json      # WestUs production
    ├── Prod-02.values.json      # WestEurope production
    ├── Prod-03.values.json      # EastUs2 production
    ├── Prod-04.values.json      # UKSouth production
    └── Prod-05.values.json      # WestUs2 production
```

**Naming Guidelines**:
- Values files support both `.values.json` and `.values.yaml` suffixes
- Use descriptive names for values files (e.g., `RS-02.values.json`, `Prod-01.values.json`, `PROD-02.values.yaml`)
- Keep file names unique within an environment directory
- Use `.values.json` or `.values.yaml` suffix for consistency
- Match `shellExtensionName` in JSON to directory name

## Advanced Scenarios

### Secret Volumes

Mount secrets from Key Vault as files:

```json
{
  "secretVolumes": [
    {
      "name": "secrets-volume",
      "mountPath": "/mnt/secrets",
      "secrets": [
        {
          "name": "certificate.pem",
          "secretId": "https://my-vault.vault.azure.net/secrets/cert"
        }
      ]
    }
  ]
}
```

Access in script:
```bash
cat /mnt/secrets/certificate.pem
```

### File Shares

Mount Azure File Shares for large data:

```json
{
  "fileVolumes": [
    {
      "name": "data-share",
      "mountPath": "/mnt/data",
      "shareName": "myshare",
      "storageAccountName": "mystorageaccount",
      "storageAccountKeySecretId": "https://my-vault.vault.azure.net/secrets/storage-key"
    }
  ]
}
```

### Custom DNS

Configure DNS for private endpoints:

```json
{
  "dnsConfig": {
    "nameServers": ["10.0.0.10"],
    "searchDomains": ["contoso.internal"],
    "options": "ndots:2"
  }
}
```

### Multiple Identities

Assign multiple MSIs for different resource access (e.g., read-only ARM + Terraform Server in AME):

```json
{
  "userAssignedIdentities": [
    "/subscriptions/bf55aab8-7f9b-4204-83eb-f693ecb41019/resourcegroups/defender-infra-managed-identities-wus/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mps-prd-ame-infra-arm-exporter",
    "/subscriptions/570fa9b6-c460-4f06-8c3b-303f3060f9c9/resourcegroups/OPS-0-EUW-Global-RG/providers/Microsoft.ManagedIdentity/userAssignedIdentities/terraform-server"
  ]
}
```

## Related Documentation

- [Ev2 Platform Documentation](https://ev2docs.azure.net/)
- [Azure Container Instances Docs](https://docs.microsoft.com/en-us/azure/container-instances/)
- [Managed Identity Documentation](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/)
- [Repository README](./README.md)
- [Templates Schema](./templates/schema.json)

## Getting Help

- **Pipeline Issues**: Contact OneBranch team via [OneBranch Support](https://aka.ms/onebranch/support)
- **Networking Issues**: Check VNET configuration in README; contact Platform Axon team
- **MSI/RBAC Issues**: Verify role assignments in Azure Portal; contact identity team
- **Script Bugs**: Debug locally first; check ACI logs in Azure Portal

## Quick Reference

### Essential Files
- **README.md**: Infrastructure table, VNET requirements, values schema
- **templates/schema.json**: Complete JSON schema for values files
- **scripts/{team}/{extension-name}/README.md**: Extension-specific documentation

### Key URLs
- **Buddy Build**: https://dev.azure.com/msazure/MCAS/_build?definitionId=375884 (feature branches, STG only)
- **Official Build**: https://dev.azure.com/msazure/MCAS/_build?definitionId=375925 (main branch, STG/PRD/FF with approvals)
- **Ev2 Docs**: https://ev2docs.azure.net/

### Common Commands
```bash
# Queue buddy build (feature branch, STG only)
az pipelines run --id 375884 --org https://dev.azure.com/msazure --project MCAS \
    --branch {branch} --parameters valuesPath="{path}" scriptsPath="{path}" valuesFormat=json

# Queue official build (main branch, select environment)
az pipelines run --id 375925 --org https://dev.azure.com/msazure --project MCAS \
    --branch main --parameters valuesPath="{path}" scriptsPath="{path}" valuesFormat=json deployEnvironment=PRD

# Check pipeline status
az pipelines build show --id {build-id} --org https://dev.azure.com/msazure --project MCAS

# Test script locally
cd scripts/{team}/{extension-name} && bash {script}.sh
```

### Terraform Server MSI (Example — MSFT)
```json
{
  "userAssignedIdentities": [
    "/subscriptions/91d8605f-b80a-4b1c-bca1-6ec55bfd1deb/resourcegroups/OPSRS-0-EUW-Global-RG/providers/Microsoft.ManagedIdentity/userAssignedIdentities/terraform-server"
  ]
}
```

> See the [Frequently Used Managed Identities](#frequently-used-managed-identities) section above for all available MSIs and guidance.
