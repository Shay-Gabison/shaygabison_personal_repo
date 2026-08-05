---
name: orphaned-resources
description: 'Find orphaned/unused Azure network resources across MDA subscriptions using Kusto queries against IPAM and Azure Resource Graph. Covers 16 resource types: Public IP Prefixes, Unassociated Public IPs, AppGW Public IPs, Application Gateways, Load Balancers, VNETs, Subnets, NAT Gateways, Bastion Hosts, NICs, NSGs, Private Endpoints, Private Link Services, Deallocated VMs, and IPAM IP lookup.'
---

# Orphaned Resources Skill

> **Credits:** The orphaned-resources dashboards and this cleanup effort were created and are led by **Amit Cohen**. This skill packages that work into a reusable Agent Skill.

Find orphaned, unused, or idle Azure network resources across MDA (Microsoft Defender for Cloud Apps) subscriptions. Uses Kusto queries against IPAM and Azure Resource Graph clusters.

## How It Works

All queries run via the **Kusto MCP tool** connected to `Geneva` database. Queries use cross-cluster references to:
- **IPAM** (`ipam.kusto.windows.net` / `IpamReport`) — for subscription discovery and IP lookups
- **Azure Resource Graph** (`argwus2nrpone.westus2.kusto.windows.net` / `AzureResourceGraph`) — for resource state
- **Azure Resource Graph (South Central)** (`argscuscrpone.southcentralus.kusto.windows.net` / `AzureResourceGraph`) — for VM state

### Critical: Cross-Cluster Workaround

The original dashboard queries use `GetSubscriptionsAssociatedWith()` from ServiceTree (`servicetreepublic.westus.kusto.windows.net`). This function takes a **tabular parameter** and **fails in cross-cluster calls**.

**Workaround**: Replace the ServiceTree subscription lookup with IPAM-based subscription discovery:

```kql
// INSTEAD OF (doesn't work cross-cluster):
let Services = datatable(ServiceId:string)['2fa7ba65-93e0-46c6-98b0-1df0c4e8a74d', 'aa7d05ce-5b6c-449f-9f85-1982d2700d79'];
let subscriptions = cluster('servicetreepublic...').database('Shared').GetSubscriptionsAssociatedWith(Services) ...

// USE THIS (works cross-cluster):
let ipamAll = union 
    cluster('ipam.kusto.windows.net').database('IpamReport').CurrentVipByServiceTree("2fa7ba65-93e0-46c6-98b0-1df0c4e8a74d"),
    cluster('ipam.kusto.windows.net').database('IpamReport').CurrentVipByServiceTree("aa7d05ce-5b6c-449f-9f85-1982d2700d79");
let subscriptions = ipamAll | where isnotempty(SubscriptionId) | summarize Environment = take_any(Environment) by SubscriptionId;
let subscription_ids = subscriptions | project SubscriptionId;
```

**Limitation**: IPAM provides `SubscriptionId` + `Environment` but NOT `SubscriptionName` or `AzureCloud`. Drop those columns from the projection, or enrich via `az account show --subscription "<ID>" --query name -o tsv`.

### For queries using `_subscriptionIds` / `_subscriptions` variables

Some queries reference shared base variables. Replace them inline:

```kql
// Replace _subscriptionIds with:
let _subscriptionIds = union 
    cluster('ipam.kusto.windows.net').database('IpamReport').CurrentVipByServiceTree("2fa7ba65-93e0-46c6-98b0-1df0c4e8a74d"),
    cluster('ipam.kusto.windows.net').database('IpamReport').CurrentVipByServiceTree("aa7d05ce-5b6c-449f-9f85-1982d2700d79")
| distinct SubscriptionId | where isnotempty(SubscriptionId);

// Replace _subscriptions with (IPAM does not provide SubscriptionName/AzureCloud; emit empty columns for query compatibility):
let _subscriptions = union 
    cluster('ipam.kusto.windows.net').database('IpamReport').CurrentVipByServiceTree("2fa7ba65-93e0-46c6-98b0-1df0c4e8a74d"),
    cluster('ipam.kusto.windows.net').database('IpamReport').CurrentVipByServiceTree("aa7d05ce-5b6c-449f-9f85-1982d2700d79")
| distinct SubscriptionId, Environment
| extend SubscriptionName = "", AzureCloud = "";
```

### Projection Adjustments

When adapting queries, remove columns that IPAM doesn't provide:
- Remove `AzureCloud` from project/order
- Remove `SubscriptionName` from project/order  
- Keep `Environment` and `SubscriptionId` (IPAM has these)

## Service Tree IDs

- MDA Service 1: `2fa7ba65-93e0-46c6-98b0-1df0c4e8a74d`
- MDA Service 2: `aa7d05ce-5b6c-449f-9f85-1982d2700d79`

## Checking a Specific Resource

When a user asks whether a **specific resource** is orphaned (by name, resource ID, subscription/RG path, or IP address), do NOT just report whether it's orphaned or not. **Always provide a full picture** by including all of the following in your response:

1. **Orphan status** — Is the resource associated with anything? (e.g., ipConfiguration, natGateway, publicIPPrefix, backendPool, subnet, NIC, etc.)
2. **Associated resource details** — If associated, show the full resource ID/name of what it's attached to (e.g., the Load Balancer, Application Gateway, VM NIC, NAT Gateway, etc.) and the type of association.
3. **IP address** — If the resource has an IP address (public IP, frontend IP, etc.), always show it.
4. **SKU and allocation method** — Show the SKU (Standard/Basic, Regional/Global) and allocation method (Static/Dynamic).
5. **Location** — The Azure region.
6. **Resource group and subscription** — Full context of where the resource lives.
7. **Associated resource health** — If the resource is associated (not orphaned), do a **follow-up query** to verify the associated resource actually exists and is not itself deleted/orphaned. For example:
   - If a Public IP is attached to a Load Balancer → query ARG to confirm the LB exists and has active backend pools.
   - If a NIC is attached to a VM → query ARG to confirm the VM exists and is not deallocated.
   - If a Private Endpoint is attached to a Private Link Service → confirm the PLS exists.

**Example follow-up query** (for a Public IP associated with a Load Balancer):
```kql
cluster('argwus2nrpone.westus2.kusto.windows.net').database('AzureResourceGraph').table('Resources')
| where timestamp > ago(2d)
| where subscriptionId == "<SUBSCRIPTION_ID>"
| where type =~ "microsoft.network/loadbalancers"
| where name =~ "<LB_NAME>"
| summarize hint.strategy=shuffle arg_max(timestamp, *) by id
| where not(deleted)
| extend properties = todynamic(properties)
| extend backendPools = properties['backendAddressPools']
| extend frontendIPConfigs = properties['frontendIPConfigurations']
| extend backendPoolCount = array_length(backendPools)
| extend hasActiveBackends = backendPoolCount > 0
| project Name = name, ResourceGroup = resourceGroup, Location = location,
    BackendPoolCount = backendPoolCount, HasActiveBackends = hasActiveBackends,
    ProvisioningState = tostring(properties['provisioningState'])
```

### Mandatory: IPAM Service Tag Check

**For any resource that has an IP address**, you MUST run the **Service Tag Lookup (Query 9)** against IPAM before concluding whether a resource is orphaned or can be deleted.

⛔ **If the IPAM service tag is `backfill` → the resource is NOT orphaned and CANNOT be deleted.** `backfill` IPs are managed by the platform backfill process and are required for service operation even if they appear unused in ARG. Always report this clearly to the user:

> "This IP has a `backfill` service tag in IPAM — it is **not orphaned** and **must not be deleted**, regardless of whether its associated resource appears idle."

**Example IPAM lookup** (add `let ipToLookup = '<IP>';` at the top when running via Kusto MCP):
```kql
let ipToLookup = '<IP_ADDRESS>';
let ipamData = union 
    cluster('ipam.kusto.windows.net').database('IpamReport').CurrentVipByServiceTree("2fa7ba65-93e0-46c6-98b0-1df0c4e8a74d"),
    cluster('ipam.kusto.windows.net').database('IpamReport').CurrentVipByServiceTree("aa7d05ce-5b6c-449f-9f85-1982d2700d79")
| extend ServiceTag = case(
    isnotempty(FirstPartyUsage), replace_string(FirstPartyUsage, "/", ""),
    isnotempty(SystemService), SystemService,
    "No Service Tag")
| extend IPAddress = iff(isempty(IPAddress) and Prefix endswith "/32", replace_string(Prefix, "/32", ""), IPAddress)
| where IPAddress == ipToLookup
| project IPAddress, ServiceTag, ServiceName, Environment, Region = coalesce(Region, ResourceLocation), Status, SubscriptionId, ResourceId;
ipamData
```

**Decision flow:**
1. Run ARG query to check orphan status and associated resource health
2. If the resource has an IP → run IPAM Service Tag Lookup
3. If ServiceTag == `backfill` → **STOP** — report as not orphaned, cannot delete
4. Otherwise → continue with the full analysis and report findings

**Present the results as a summary table** so the user gets the full context at a glance. Flag any concerns (e.g., "IP is associated but the LB has 0 backend pools — may be effectively unused").

## Available Queries

When the user asks to "find orphaned resources" or "check for unused resources", offer to run any/all of these. Run them one at a time via Kusto MCP, summarize results after each.

### Query 1: Public IP Prefix — Summarized

**Tile**: Public IP Prefix - Summarized  
**Purpose**: Find Public IP Prefixes where ALL IPs are unattached (aggregated view).

```kql
let Services = datatable(ServiceId:string)['2fa7ba65-93e0-46c6-98b0-1df0c4e8a74d', 'aa7d05ce-5b6c-449f-9f85-1982d2700d79'];
let subscriptions = cluster('https://servicetreepublic.westus.kusto.windows.net').database('Shared').GetSubscriptionsAssociatedWith(Services) | distinct SubscriptionId, SubscriptionName, Environment, AzureCloud;
let subscription_ids = subscriptions | project SubscriptionId;
let prefixes = cluster('argwus2nrpone.westus2.kusto.windows.net').database('AzureResourceGraph').table('Resources')
| where timestamp > ago(2d)
| where subscriptionId in(subscription_ids)
| where type =~ 'Microsoft.Network/publicIPPrefixes'
| summarize hint.strategy=shuffle arg_max(timestamp, *) by id
| where not(deleted)
| extend properties = todynamic(properties)
| extend prefixLength = toint(properties['prefixLength'])
| extend ipPrefix = tostring(properties['ipPrefix'])
| project prefixId = id, prefixName = name, prefixResourceGroup = resourceGroup, prefixLocation = location, prefixSubscriptionId = subscriptionId, prefixLength, ipPrefix;
let publicIPs = cluster('argwus2nrpone.westus2.kusto.windows.net').database('AzureResourceGraph').table('Resources')
| where timestamp > ago(2d)
| where subscriptionId in(subscription_ids)
| where type =~ 'microsoft.network/publicipaddresses'
| summarize hint.strategy=shuffle arg_max(timestamp, *) by id
| where not(deleted)
| extend properties = todynamic(properties)
| extend publicIPPrefix = todynamic(properties['publicIPPrefix'])
| extend ipConfiguration = todynamic(properties['ipConfiguration'])
| extend natGateway = todynamic(properties['natGateway'])
| project publicIPPrefixId = tostring(publicIPPrefix['id']), isAttached = (isnotnull(ipConfiguration) or isnotnull(natGateway));
prefixes
| join kind=inner (publicIPs) on $left.prefixId == $right.publicIPPrefixId
| summarize TotalIPs = count(), AttachedIPs = countif(isAttached), UnattachedIPs = countif(not(isAttached))
    by prefixId, prefixName, prefixResourceGroup, prefixLocation, prefixSubscriptionId, prefixLength, ipPrefix
| where AttachedIPs == 0
| join kind=leftouter (subscriptions) on $left.prefixSubscriptionId == $right.SubscriptionId
| project Environment, AzureCloud, SubscriptionName, SubscriptionId = prefixSubscriptionId, ResourceGroup = prefixResourceGroup, Type = "microsoft.network/publicipprefixes", Name = prefixName, Location = prefixLocation, IPPrefix = ipPrefix, TotalUnattachedIPs = UnattachedIPs, OrphanedReason = "All Public IPs in prefix are unattached"
| order by Environment asc, AzureCloud asc, SubscriptionName asc, ResourceGroup asc, Name asc
```

---

### Query 2: Unassociated Public IPs

**Tile**: Unassociated Public IPs  
**Purpose**: Find individual Public IPs not associated with any resource. Excludes IPs used as VNet service endpoint network identifiers.  
**Uses base variables**: `_subscriptionIds`, `_subscriptions`

```kql
// Comprehensive Unassociated Public IP Addresses Query
let _network_identifier_resource_ids = () {
    cluster('argwus2nrpone.westus2.kusto.windows.net').database('AzureResourceGraph').table('Resources') 
        | where timestamp > ago(2d) 
        | where subscriptionId in(_subscriptionIds) 
        | where type =~ "microsoft.network/virtualnetworks"
        | summarize hint.strategy=shuffle arg_max(timestamp, *) by id
        | where not(deleted)
        | mv-expand subnet = properties['subnets']
        | where bag_has_key( subnet['properties'], "serviceEndpoints")
        | extend subnet_properties = subnet['properties']
        | where array_length( subnet_properties['serviceEndpoints']) > 0
        | mv-expand service_endpoint = subnet_properties['serviceEndpoints']
        | where bag_has_key( service_endpoint, "networkIdentifier")
        | extend network_id_public_ip_address_resource_id = tostring( service_endpoint['networkIdentifier']['id'])
        | distinct network_id_public_ip_address_resource_id
};
cluster('argwus2nrpone.westus2.kusto.windows.net').database('AzureResourceGraph').table('Resources') 
| where timestamp > ago(2d) 
| where subscriptionId in(_subscriptionIds) 
| where type =~ "microsoft.network/publicipaddresses"
| summarize hint.strategy=shuffle arg_max(timestamp, *) by id
| where not(deleted)
| where id !in (_network_identifier_resource_ids())
| extend properties = todynamic(properties) 
| extend ipConfiguration = todynamic(properties['ipConfiguration'])
| extend natGateway = todynamic(properties['natGateway'])
| extend publicIPPrefix = todynamic(properties['publicIPPrefix'])
| extend sku = todynamic(sku)
| extend publicIPAllocationMethod = tostring(properties['publicIPAllocationMethod'])
| extend ipAddress = tostring(properties['ipAddress'])
| extend skuName = tostring(sku['name'])
| extend skuTier = tostring(sku['tier'])
| where isnull(ipConfiguration) and isnull(natGateway) and isnull(publicIPPrefix)
| join kind=leftouter (_subscriptions) on $left.subscriptionId == $right.SubscriptionId
| project Environment, AzureCloud, SubscriptionName, SubscriptionId, ResourceGroup = resourceGroup, Type = type, Name = name, Location = location, AllocationMethod = publicIPAllocationMethod, IPAddress = ipAddress, SKU = strcat(skuName, " (", skuTier, ")"), OrphanedReason = "Not associated with any resource"
| order by Environment asc, AzureCloud asc, SubscriptionName asc, ResourceGroup asc, Name asc
```

---

### Query 3: Orphaned AppGW Public IPs

**Tile**: Orphaned AppGW Public IPs  
**Purpose**: Find Public IPs attached to Application Gateways that have empty backend pools.

```kql
let Services = datatable(ServiceId:string)['2fa7ba65-93e0-46c6-98b0-1df0c4e8a74d', 'aa7d05ce-5b6c-449f-9f85-1982d2700d79'];
let subscriptions = cluster('https://servicetreepublic.westus.kusto.windows.net').database('Shared').GetSubscriptionsAssociatedWith(Services) | distinct SubscriptionId, SubscriptionName, Environment, AzureCloud;
let subscription_ids = subscriptions | project  SubscriptionId;
let appgws = cluster('argwus2nrpone.westus2.kusto.windows.net').database('AzureResourceGraph').table('Resources') 
| where timestamp > ago(2d) 
| where subscriptionId in(subscription_ids) 
| where type =~ "Microsoft.Network/applicationGateways"
| summarize hint.strategy=shuffle arg_max(timestamp, *) by id
| where not(deleted)
| extend properties = todynamic(properties) 
| extend backendAddressPools = todynamic(properties['backendAddressPools'])
| project id, backendAddressPools;
let orphaned_appgws =
    (appgws
    | extend poolCount = toint(coalesce(array_length(backendAddressPools), 0))
    | where poolCount == 0
    | project id)
| union
    (appgws
    | extend poolCount = toint(coalesce(array_length(backendAddressPools), 0))
    | where poolCount > 0
    | mv-expand backendAddressPool = backendAddressPools
    | extend backendAddresses = todynamic(backendAddressPool['properties']['backendAddresses'])
    | extend poolIsEmpty = (array_length(backendAddresses) == 0)
    | summarize emptyPoolCount = countif(poolIsEmpty), poolCountExpanded = count() by id
    | where emptyPoolCount == poolCountExpanded
    | project id)
| distinct id;
cluster('argwus2nrpone.westus2.kusto.windows.net').database('AzureResourceGraph').table('Resources') 
| where timestamp > ago(2d) 
| where subscriptionId in(subscription_ids) 
| where type =~ "Microsoft.Network/publicipaddresses"
| summarize hint.strategy=shuffle arg_max(timestamp, *) by id
| where not(deleted)
| extend properties = todynamic(properties) 
| extend ipConfiguration = todynamic(properties['ipConfiguration'])
| where isnotnull( ipConfiguration)
| extend ipConfigurationId = tostring( ipConfiguration['id'])
| where ipConfigurationId has "Microsoft.Network/applicationGateways"
| extend associatedResource = replace_regex(ipConfigurationId, "/(ipConfigurations|frontendIPConfigurations)/[^/]+$", "")
| where associatedResource in (orphaned_appgws)
| join kind=leftouter (subscriptions) on $left.subscriptionId == $right.SubscriptionId
| project Environment, AzureCloud, SubscriptionName, SubscriptionId, ResourceGroup = resourceGroup, Type = type, Name = name, Location = location, AssociatedResourceId = associatedResource
| order by Environment asc , AzureCloud asc , SubscriptionName asc , ResourceGroup asc , Name asc
```

---

### Query 4: Unused Application Gateways

**Tile**: Unnused Application Gateways  
**Purpose**: Find Application Gateways that are idle — no backend pools, no listeners, no routing rules, or all pools empty.

```kql
// Comprehensive Idle Application Gateways Query
// Checks: 1) no backend pools 2) all backend pools empty 3) no HTTP listeners 4) no routing rules 5) no frontend IPs
let Services = datatable(ServiceId:string)['2fa7ba65-93e0-46c6-98b0-1df0c4e8a74d', 'aa7d05ce-5b6c-449f-9f85-1982d2700d79'];
let subscriptions = cluster('https://servicetreepublic.westus.kusto.windows.net').database('Shared').GetSubscriptionsAssociatedWith(Services) | distinct SubscriptionId, SubscriptionName, Environment, AzureCloud;
let subscription_ids = subscriptions | project SubscriptionId;
cluster('argwus2nrpone.westus2.kusto.windows.net').database('AzureResourceGraph').table('Resources') 
| where timestamp > ago(2d) 
| where subscriptionId in(subscription_ids) 
| where type =~ "Microsoft.Network/applicationGateways"
| summarize hint.strategy=shuffle arg_max(timestamp, *) by id
| where not(deleted)
| extend properties = todynamic(properties)
| extend backendAddressPools = todynamic(properties['backendAddressPools'])
| extend httpListeners = todynamic(properties['httpListeners'])
| extend requestRoutingRules = todynamic(properties['requestRoutingRules'])
| extend frontendIPConfigurations = todynamic(properties['frontendIPConfigurations'])
| extend hasNoBackendPools = (array_length(backendAddressPools) == 0)
| extend hasNoHttpListeners = (array_length(httpListeners) == 0)
| extend hasNoRoutingRules = (array_length(requestRoutingRules) == 0)
| extend hasNoFrontendIPs = (array_length(frontendIPConfigurations) == 0)
| extend backendAddressPoolsCount = array_length(backendAddressPools)
| mv-expand kind=outer backendPool = backendAddressPools
| extend backendAddresses = todynamic(backendPool['properties']['backendAddresses'])
| extend poolIsEmpty = iff(backendAddressPoolsCount == 0, true, coalesce(array_length(backendAddresses), 0) == 0)
| summarize hasNoBackendPools = max(hasNoBackendPools), hasNoHttpListeners = max(hasNoHttpListeners), hasNoRoutingRules = max(hasNoRoutingRules), hasNoFrontendIPs = max(hasNoFrontendIPs), allPoolsEmpty = min(poolIsEmpty), poolCount = max(backendAddressPoolsCount)
    by subscriptionId, resourceGroup, name, location, type
| where hasNoBackendPools or hasNoHttpListeners or hasNoRoutingRules or hasNoFrontendIPs or (poolCount > 0 and allPoolsEmpty)
| extend OrphanedReason = case(
    hasNoBackendPools, "No backend pools",
    hasNoFrontendIPs, "No frontend IPs",
    hasNoHttpListeners, "No HTTP listeners",
    hasNoRoutingRules, "No request routing rules",
    (poolCount > 0 and allPoolsEmpty), "All backend pools empty",
    "Unknown")
| join kind=leftouter (subscriptions) on $left.subscriptionId == $right.SubscriptionId
| project Environment, AzureCloud, SubscriptionName, SubscriptionId, ResourceGroup = resourceGroup, Type = type, Name = name, Location = location, OrphanedReason
| order by Environment asc, AzureCloud asc, SubscriptionName asc, ResourceGroup asc, Name asc
```

---

### Query 5: Unused Load Balancers

**Tile**: Unused Load Balancers  
**Purpose**: Find Load Balancers with no backend pools, no frontend IPs, no rules, or all empty pools.

```kql
// Comprehensive Idle Load Balancers Query
let Services = datatable(ServiceId:string)['2fa7ba65-93e0-46c6-98b0-1df0c4e8a74d', 'aa7d05ce-5b6c-449f-9f85-1982d2700d79'];
let subscriptions = cluster('https://servicetreepublic.westus.kusto.windows.net').database('Shared').GetSubscriptionsAssociatedWith(Services) | distinct SubscriptionId, SubscriptionName, Environment, AzureCloud;
let subscription_ids = subscriptions | project SubscriptionId;
cluster('argwus2nrpone.westus2.kusto.windows.net').database('AzureResourceGraph').table('Resources') 
| where timestamp > ago(2d) 
| where subscriptionId in(subscription_ids) 
| where type =~ "Microsoft.Network/loadBalancers"
| summarize hint.strategy=shuffle arg_max(timestamp, *) by id
| where not(deleted)
| extend properties = todynamic(properties)
| extend backendAddressPools = todynamic(properties['backendAddressPools'])
| extend frontendIPConfigurations = todynamic(properties['frontendIPConfigurations'])
| extend loadBalancingRules = todynamic(properties['loadBalancingRules'])
| extend outboundRules = todynamic(properties['outboundRules'])
| extend hasNoBackendPools = (array_length(backendAddressPools) == 0)
| extend hasNoFrontendIPs = (array_length(frontendIPConfigurations) == 0)
| extend hasNoRules = (array_length(loadBalancingRules) == 0 and array_length(outboundRules) == 0)
| mv-expand kind=outer backendPool = backendAddressPools
| extend backendIPConfigs = todynamic(backendPool['properties']['backendIPConfigurations'])
| extend backendAddresses = todynamic(backendPool['properties']['loadBalancerBackendAddresses'])
| extend backendIPConfigCount = coalesce(array_length(backendIPConfigs), 0)
| extend backendAddressCount = coalesce(array_length(backendAddresses), 0)
| extend poolIsEmpty = iif(isnull(backendPool), true, (backendIPConfigCount == 0 and backendAddressCount == 0))
| summarize hasNoBackendPools = max(hasNoBackendPools), hasNoFrontendIPs = max(hasNoFrontendIPs), hasNoRules = max(hasNoRules), allPoolsEmpty = min(poolIsEmpty), poolCount = countif(isnotnull(backendPool))
    by subscriptionId, resourceGroup, name, location, type
| where hasNoBackendPools or hasNoFrontendIPs or hasNoRules or (poolCount > 0 and allPoolsEmpty)
| extend OrphanedReason = case(
    hasNoBackendPools, "No backend pools",
    hasNoFrontendIPs, "No frontend IPs",
    hasNoRules, "No load balancing or outbound rules",
    (poolCount > 0 and allPoolsEmpty), "All backend pools empty",
    "Unknown")
| join kind=leftouter (subscriptions) on $left.subscriptionId == $right.SubscriptionId
| project Environment, AzureCloud, SubscriptionName, SubscriptionId, ResourceGroup = resourceGroup, Type = type, Name = name, Location = location, OrphanedReason
| order by Environment asc, AzureCloud asc, SubscriptionName asc, ResourceGroup asc, Name asc
```

---

### Query 6: Public IP Prefix — Detailed

**Tile**: Public IP Prefix - Detailed  
**Purpose**: Same as Query 1 but expands each prefix to list individual IPs (name, address, SKU).

```kql
let Services = datatable(ServiceId:string)['2fa7ba65-93e0-46c6-98b0-1df0c4e8a74d', 'aa7d05ce-5b6c-449f-9f85-1982d2700d79'];
let subscriptions = cluster('https://servicetreepublic.westus.kusto.windows.net').database('Shared').GetSubscriptionsAssociatedWith(Services) | distinct SubscriptionId, SubscriptionName, Environment, AzureCloud;
let subscription_ids = subscriptions | project SubscriptionId;
let prefixes = cluster('argwus2nrpone.westus2.kusto.windows.net').database('AzureResourceGraph').table('Resources')
| where timestamp > ago(2d) | where subscriptionId in(subscription_ids) | where type =~ 'Microsoft.Network/publicIPPrefixes'
| summarize hint.strategy=shuffle arg_max(timestamp, *) by id | where not(deleted)
| extend properties = todynamic(properties)
| extend prefixLength = toint(properties['prefixLength']), ipPrefix = tostring(properties['ipPrefix'])
| project prefixId = id, prefixName = name, prefixResourceGroup = resourceGroup, prefixLocation = location, prefixSubscriptionId = subscriptionId, prefixLength, ipPrefix;
let publicIPs = cluster('argwus2nrpone.westus2.kusto.windows.net').database('AzureResourceGraph').table('Resources')
| where timestamp > ago(2d) | where subscriptionId in(subscription_ids) | where type =~ 'microsoft.network/publicipaddresses'
| summarize hint.strategy=shuffle arg_max(timestamp, *) by id | where not(deleted)
| extend properties = todynamic(properties), sku = todynamic(sku)
| extend publicIPPrefix = todynamic(properties['publicIPPrefix']), ipConfiguration = todynamic(properties['ipConfiguration']), natGateway = todynamic(properties['natGateway'])
| extend ipAddress = tostring(properties['ipAddress']), publicIPAllocationMethod = tostring(properties['publicIPAllocationMethod']), skuName = tostring(sku['name'])
| project ipId = id, ipName = name, ipResourceGroup = resourceGroup, ipLocation = location, publicIPPrefixId = tostring(publicIPPrefix['id']), isAttached = (isnotnull(ipConfiguration) or isnotnull(natGateway)), ipAddress, publicIPAllocationMethod, skuName;
let orphanedPrefixes = prefixes
| join kind=inner (publicIPs) on $left.prefixId == $right.publicIPPrefixId
| summarize TotalIPs = count(), AttachedIPs = countif(isAttached), UnattachedIPs = countif(not(isAttached)),
    IPList = make_list(pack("name", ipName, "ipAddress", ipAddress, "allocationMethod", publicIPAllocationMethod, "sku", skuName))
    by prefixId, prefixName, prefixResourceGroup, prefixLocation, prefixSubscriptionId, prefixLength, ipPrefix
| where AttachedIPs == 0
| project prefixId, prefixName, prefixResourceGroup, prefixLocation, prefixSubscriptionId, prefixLength, ipPrefix, TotalIPs, IPList;
orphanedPrefixes
| mv-expand IP = IPList
| extend IPName = tostring(IP['name']), IPAddress = tostring(IP['ipAddress']), AllocationMethod = tostring(IP['allocationMethod']), SKU = tostring(IP['sku'])
| join kind=leftouter (subscriptions) on $left.prefixSubscriptionId == $right.SubscriptionId
| project Environment, AzureCloud, SubscriptionName, SubscriptionId = prefixSubscriptionId, ResourceGroup = prefixResourceGroup, Location = prefixLocation, PrefixName = prefixName, IPPrefix = ipPrefix, TotalIPsInPrefix = TotalIPs, PublicIPName = IPName, IPAddress, AllocationMethod, SKU, OrphanedReason = "Part of orphaned Public IP Prefix (all IPs unattached)"
| order by Environment asc, AzureCloud asc, SubscriptionName asc, ResourceGroup asc, PrefixName asc, PublicIPName asc
```

---

### Query 7: Completely Unused VNETs

**Tile**: Completely Unused VNETs  
**Purpose**: Find VNets where ALL subnets have no resources and no peerings exist.

```kql
// Completely Unused Virtual Networks
let Services = datatable(ServiceId:string)['2fa7ba65-93e0-46c6-98b0-1df0c4e8a74d', 'aa7d05ce-5b6c-449f-9f85-1982d2700d79'];
let subscriptions = cluster('https://servicetreepublic.westus.kusto.windows.net').database('Shared').GetSubscriptionsAssociatedWith(Services) | distinct SubscriptionId, SubscriptionName, Environment, AzureCloud;
let subscription_ids = subscriptions | project SubscriptionId;
cluster('argwus2nrpone.westus2.kusto.windows.net').database('AzureResourceGraph').table('Resources') 
| where timestamp > ago(2d) | where subscriptionId in(subscription_ids) 
| where type =~ "Microsoft.Network/virtualNetworks"
| summarize hint.strategy=shuffle arg_max(timestamp, *) by id | where not(deleted)
| extend properties = todynamic(properties)
| extend subnets = todynamic(properties['subnets'])
| extend addressSpace = todynamic(properties['addressSpace'])
| extend addressPrefixes = todynamic(addressSpace['addressPrefixes'])
| extend virtualNetworkPeerings = todynamic(properties['virtualNetworkPeerings'])
| extend hasPeerings = (array_length(virtualNetworkPeerings) > 0)
| mv-expand subnet = subnets
| extend subnetName = tostring(subnet['name'])
| extend subnetProperties = todynamic(subnet['properties'])
| extend ipConfigurations = todynamic(subnetProperties['ipConfigurations'])
| extend delegations = todynamic(subnetProperties['delegations'])
| extend serviceEndpoints = todynamic(subnetProperties['serviceEndpoints'])
| extend subnetIsUsed = ((isnotnull(ipConfigurations) and array_length(ipConfigurations) > 0) or (isnotnull(delegations) and array_length(delegations) > 0) or (isnotnull(serviceEndpoints) and array_length(serviceEndpoints) > 0))
| summarize TotalSubnets = count(), UsedSubnets = countif(subnetIsUsed), UnusedSubnets = countif(not(subnetIsUsed)), SubnetNames = make_list(subnetName), HasPeerings = take_any(hasPeerings), AddressPrefixes = take_any(addressPrefixes)
    by id, name, subscriptionId, resourceGroup, location
| where UsedSubnets == 0 and HasPeerings == false
| join kind=leftouter (subscriptions) on $left.subscriptionId == $right.SubscriptionId
| project Environment, AzureCloud, SubscriptionName, SubscriptionId = subscriptionId, ResourceGroup = resourceGroup, Type = "microsoft.network/virtualnetworks", Name = name, Location = location, AddressPrefixes = tostring(AddressPrefixes), TotalSubnets, UnusedSubnets, SubnetNames = tostring(SubnetNames), OrphanedReason = "All subnets unused, no peerings"
| order by Environment asc, AzureCloud asc, SubscriptionName asc, ResourceGroup asc, Name asc
```

---

### Query 8: Unused Subnets

**Tile**: Unused Subnets  
**Purpose**: Find individual subnets with no ipConfigurations, delegations, or serviceEndpoints. Excludes special subnets (GatewaySubnet, AzureFirewallSubnet, etc.).

```kql
// Unused Virtual Network Subnets
let Services = datatable(ServiceId:string)['2fa7ba65-93e0-46c6-98b0-1df0c4e8a74d', 'aa7d05ce-5b6c-449f-9f85-1982d2700d79'];
let subscriptions = cluster('https://servicetreepublic.westus.kusto.windows.net').database('Shared').GetSubscriptionsAssociatedWith(Services) | distinct SubscriptionId, SubscriptionName, Environment, AzureCloud;
let subscription_ids = subscriptions | project SubscriptionId;
cluster('argwus2nrpone.westus2.kusto.windows.net').database('AzureResourceGraph').table('Resources') 
| where timestamp > ago(2d) | where subscriptionId in(subscription_ids) 
| where type =~ "Microsoft.Network/virtualNetworks"
| summarize hint.strategy=shuffle arg_max(timestamp, *) by id | where not(deleted)
| extend properties = todynamic(properties), subnets = todynamic(properties['subnets'])
| mv-expand subnet = subnets
| extend subnetName = tostring(subnet['name']), subnetId = tostring(subnet['id'])
| extend subnetProperties = todynamic(subnet['properties'])
| extend ipConfigurations = todynamic(subnetProperties['ipConfigurations'])
| extend delegations = todynamic(subnetProperties['delegations'])
| extend serviceEndpoints = todynamic(subnetProperties['serviceEndpoints'])
| extend addressPrefix = tostring(subnetProperties['addressPrefix'])
| extend isSpecialSubnet = (subnetName in~ ('GatewaySubnet', 'AzureFirewallSubnet', 'AzureFirewallManagementSubnet', 'RouteServerSubnet', 'AzureBastionSubnet'))
| where not((isnotnull(ipConfigurations) and array_length(ipConfigurations) > 0)) and not((isnotnull(delegations) and array_length(delegations) > 0)) and not((isnotnull(serviceEndpoints) and array_length(serviceEndpoints) > 0)) and not(isSpecialSubnet)
| join kind=leftouter (subscriptions) on $left.subscriptionId == $right.SubscriptionId
| project Environment, AzureCloud, SubscriptionName, SubscriptionId = subscriptionId, ResourceGroup = resourceGroup, VNetName = name, VNetLocation = location, SubnetName = subnetName, SubnetAddressPrefix = addressPrefix, OrphanedReason = "No resources attached to subnet"
| order by Environment asc, AzureCloud asc, SubscriptionName asc, ResourceGroup asc, VNetName asc, SubnetName asc
```

---

### Query 9: Service Tag Lookup (IPAM)

**Tile**: Service Tag Lookup  
**Purpose**: Look up a specific IP address in IPAM to find its service tag, owner, and resource details.  
**Parameter**: `ipToLookup` — the IP address to search for.

```kql
// IP Address Service Tag Lookup
// Set ipToLookup to the target IP before running
let ipamData = union 
    cluster('ipam.kusto.windows.net').database('IpamReport').CurrentVipByServiceTree("2fa7ba65-93e0-46c6-98b0-1df0c4e8a74d"),
    cluster('ipam.kusto.windows.net').database('IpamReport').CurrentVipByServiceTree("aa7d05ce-5b6c-449f-9f85-1982d2700d79")
| extend ServiceTag = case(
    isnotempty(FirstPartyUsage), replace_string(FirstPartyUsage, "/", ""),
    isnotempty(SystemService), SystemService,
    "No Service Tag")
| extend IPAddress = iff(isempty( IPAddress) and Prefix endswith "/32", replace_string(Prefix, "/32", ""), IPAddress )
| where IPAddress == ipToLookup
| project IPAddress, ServiceTag, ServiceName, Environment, Region = coalesce(Region, ResourceLocation), Status, SubscriptionId, ResourceId, IpSku, PublicIPAllocationMethod, DeviceType, PreciseTimeStamp;
ipamData
| extend Found = true
| union (
    print IPAddress = ipToLookup, ServiceTag = "Not Found in IPAM", Found = false, 
          ServiceName = "", Environment = "", Region = "", Status = "", 
          SubscriptionId = "", ResourceId = "", IpSku = "", 
          PublicIPAllocationMethod = "", DeviceType = "", PreciseTimeStamp = datetime(null)
    | where toscalar(ipamData | count) == 0)
| project IPAddress, Found, ServiceTag, ServiceName, Environment, Region, Status, SubscriptionId, ResourceId, IpSku, AllocationMethod = PublicIPAllocationMethod, DeviceType, LastUpdated = PreciseTimeStamp
```

**When adapting for Kusto MCP**: Add `let ipToLookup = '<IP_ADDRESS>';` at the top.

---

### Query 10: Unused NAT Gateways

**Tile**: Unused NAT Gateways  
**Purpose**: Find NAT Gateways with no subnets, no public IPs, or no public IP prefixes.

```kql
// Idle NAT Gateways
let Services = datatable(ServiceId:string)['2fa7ba65-93e0-46c6-98b0-1df0c4e8a74d', 'aa7d05ce-5b6c-449f-9f85-1982d2700d79'];
let subscriptions = cluster('https://servicetreepublic.westus.kusto.windows.net').database('Shared').GetSubscriptionsAssociatedWith(Services) | distinct SubscriptionId, SubscriptionName, Environment, AzureCloud;
let subscription_ids = subscriptions | project SubscriptionId;
cluster('argwus2nrpone.westus2.kusto.windows.net').database('AzureResourceGraph').table('Resources') 
| where timestamp > ago(2d) | where subscriptionId in(subscription_ids) 
| where type =~ "microsoft.network/natgateways"
| summarize hint.strategy=shuffle arg_max(timestamp, *) by id | where not(deleted)
| extend properties = todynamic(properties)
| extend subnets = todynamic(properties['subnets'])
| extend publicIpAddresses = todynamic(properties['publicIpAddresses'])
| extend publicIpPrefixes = todynamic(properties['publicIpPrefixes'])
| extend hasSubnets = (isnotnull(subnets) and array_length(subnets) > 0)
| extend hasPublicIPs = (isnotnull(publicIpAddresses) and array_length(publicIpAddresses) > 0)
| extend hasPublicIPPrefixes = (isnotnull(publicIpPrefixes) and array_length(publicIpPrefixes) > 0)
| extend subnetCount = array_length(subnets), publicIPCount = array_length(publicIpAddresses), publicIPPrefixCount = array_length(publicIpPrefixes)
| where not(hasSubnets) or (not(hasPublicIPs) and not(hasPublicIPPrefixes))
| extend idleReason = case(
    not(hasSubnets) and not(hasPublicIPs) and not(hasPublicIPPrefixes), "No subnets, no public IPs or prefixes",
    not(hasSubnets) and (hasPublicIPs or hasPublicIPPrefixes), "No subnets attached",
    hasSubnets and not(hasPublicIPs) and not(hasPublicIPPrefixes), "Has subnets but no public IPs or prefixes",
    "Unknown idle condition")
| join kind=leftouter (subscriptions) on $left.subscriptionId == $right.SubscriptionId
| project Environment, AzureCloud, SubscriptionName, SubscriptionId = subscriptionId, ResourceGroup = resourceGroup, Type = type, Name = name, Location = location, SubnetCount = subnetCount, PublicIPCount = publicIPCount, PublicIPPrefixCount = publicIPPrefixCount, OrphanedReason = idleReason
| order by Environment asc, AzureCloud asc, SubscriptionName asc, ResourceGroup asc, Name asc
```

---

### Query 11: Unused Azure Bastion Hosts

**Tile**: Unused Azure Bastion Hosts  
**Purpose**: Find Bastion hosts with no IP configurations (~$140/month for Basic SKU).

```kql
// Idle Azure Bastion Hosts
let Services = datatable(ServiceId:string)['2fa7ba65-93e0-46c6-98b0-1df0c4e8a74d', 'aa7d05ce-5b6c-449f-9f85-1982d2700d79'];
let subscriptions = cluster('https://servicetreepublic.westus.kusto.windows.net').database('Shared').GetSubscriptionsAssociatedWith(Services) | distinct SubscriptionId, SubscriptionName, Environment, AzureCloud;
let subscription_ids = subscriptions | project SubscriptionId;
cluster('argwus2nrpone.westus2.kusto.windows.net').database('AzureResourceGraph').table('Resources') 
| where timestamp > ago(2d) | where subscriptionId in(subscription_ids) 
| where type =~ "microsoft.network/bastionhosts"
| summarize hint.strategy=shuffle arg_max(timestamp, *) by id | where not(deleted)
| extend properties = todynamic(properties)
| extend ipConfigurations = todynamic(properties['ipConfigurations'])
| extend virtualNetwork = todynamic(properties['virtualNetwork'])
| extend scaleUnits = toint(properties['scaleUnits'])
| extend dnsName = tostring(properties['dnsName'])
| extend provisioningState = tostring(properties['provisioningState'])
| extend sku = todynamic(sku), skuName = tostring(sku['name'])
| extend hasIPConfigurations = (isnotnull(ipConfigurations) and array_length(ipConfigurations) > 0)
| extend hasVirtualNetwork = isnotnull(virtualNetwork)
| extend idleReason = case(
    not(hasIPConfigurations) and not(hasVirtualNetwork), "No IP configurations and no virtual network",
    not(hasIPConfigurations) and hasVirtualNetwork, "No IP configurations (not connected to subnet)",
    "Active")
| where idleReason != "Active"
| join kind=leftouter (subscriptions) on $left.subscriptionId == $right.SubscriptionId
| project Environment, AzureCloud, SubscriptionName, SubscriptionId = subscriptionId, ResourceGroup = resourceGroup, Type = type, Name = name, Location = location, SKU = coalesce(skuName, "Standard"), ScaleUnits = scaleUnits, OrphanedReason = idleReason
| order by Environment asc, AzureCloud asc, SubscriptionName asc, ResourceGroup asc, Name asc
```

---

### Query 12: Unattached Network Interfaces

**Tile**: Unattached Network Interfaces  
**Purpose**: Find NICs not attached to any VM or Private Endpoint.

```kql
// Unattached Network Interfaces (NICs)
let Services = datatable(ServiceId:string)['2fa7ba65-93e0-46c6-98b0-1df0c4e8a74d', 'aa7d05ce-5b6c-449f-9f85-1982d2700d79'];
let subscriptions = cluster('https://servicetreepublic.westus.kusto.windows.net').database('Shared').GetSubscriptionsAssociatedWith(Services) | distinct SubscriptionId, SubscriptionName, Environment, AzureCloud;
let subscription_ids = subscriptions | project SubscriptionId;
cluster('argwus2nrpone.westus2.kusto.windows.net').database('AzureResourceGraph').table('Resources') 
| where timestamp > ago(2d) | where subscriptionId in(subscription_ids) 
| where type =~ "microsoft.network/networkinterfaces"
| summarize hint.strategy=shuffle arg_max(timestamp, *) by id | where not(deleted)
| extend properties = todynamic(properties)
| extend virtualMachine = todynamic(properties['virtualMachine'])
| extend privateEndpoint = todynamic(properties['privateEndpoint'])
| extend ipConfigurations = todynamic(properties['ipConfigurations'])
| extend networkSecurityGroup = todynamic(properties['networkSecurityGroup'])
| extend enableAcceleratedNetworking = tobool(properties['enableAcceleratedNetworking'])
| where isnull(virtualMachine) and isnull(privateEndpoint)
| mv-expand ipConfig = ipConfigurations
| extend privateIP = tostring(ipConfig['properties']['privateIPAddress'])
| summarize PrivateIPs = make_set(privateIP), HasNSG = any(isnotnull(networkSecurityGroup)), AcceleratedNetworking = any(enableAcceleratedNetworking)
    by id, name, subscriptionId, resourceGroup, location
| join kind=leftouter (subscriptions) on $left.subscriptionId == $right.SubscriptionId
| project Environment, AzureCloud, SubscriptionName, SubscriptionId = subscriptionId, ResourceGroup = resourceGroup, Type = "microsoft.network/networkinterfaces", Name = name, Location = location, PrivateIPs = tostring(PrivateIPs), HasNSG, AcceleratedNetworking, OrphanedReason = "Not attached to any virtual machine"
| order by Environment asc, AzureCloud asc, SubscriptionName asc, ResourceGroup asc, Name asc
```

---

### Query 13: Unassociated NSGs

**Tile**: Unassociated NSGs  
**Purpose**: Find NSGs not attached to any NIC or subnet.

```kql
// Unattached Network Security Groups (NSGs)
let Services = datatable(ServiceId:string)['2fa7ba65-93e0-46c6-98b0-1df0c4e8a74d', 'aa7d05ce-5b6c-449f-9f85-1982d2700d79'];
let subscriptions = cluster('https://servicetreepublic.westus.kusto.windows.net').database('Shared').GetSubscriptionsAssociatedWith(Services) | distinct SubscriptionId, SubscriptionName, Environment, AzureCloud;
let subscription_ids = subscriptions | project SubscriptionId;
cluster('argwus2nrpone.westus2.kusto.windows.net').database('AzureResourceGraph').table('Resources') 
| where timestamp > ago(2d) | where subscriptionId in(subscription_ids) 
| where type =~ "microsoft.network/networksecuritygroups"
| summarize hint.strategy=shuffle arg_max(timestamp, *) by id | where not(deleted)
| extend properties = todynamic(properties)
| extend networkInterfaces = todynamic(properties['networkInterfaces'])
| extend subnets = todynamic(properties['subnets'])
| extend securityRules = todynamic(properties['securityRules'])
| where not((isnotnull(networkInterfaces) and array_length(networkInterfaces) > 0)) and not((isnotnull(subnets) and array_length(subnets) > 0))
| extend ruleCount = array_length(securityRules)
| join kind=leftouter (subscriptions) on $left.subscriptionId == $right.SubscriptionId
| project Environment, AzureCloud, SubscriptionName, SubscriptionId = subscriptionId, ResourceGroup = resourceGroup, Type = type, Name = name, Location = location, SecurityRuleCount = ruleCount, OrphanedReason = "Not attached to any network interface or subnet"
| order by Environment asc, AzureCloud asc, SubscriptionName asc, ResourceGroup asc, Name asc
```

---

### Query 14: Orphaned Private Endpoints

**Tile**: Orphaned Private Endpoints  
**Purpose**: Find Private Endpoints with no connections, or all connections rejected/pending.

```kql
// Orphaned Private Endpoints
let Services = datatable(ServiceId:string)['2fa7ba65-93e0-46c6-98b0-1df0c4e8a74d', 'aa7d05ce-5b6c-449f-9f85-1982d2700d79'];
let subscriptions = cluster('https://servicetreepublic.westus.kusto.windows.net').database('Shared').GetSubscriptionsAssociatedWith(Services) | distinct SubscriptionId, SubscriptionName, Environment, AzureCloud;
let subscription_ids = subscriptions | project SubscriptionId;
cluster('argwus2nrpone.westus2.kusto.windows.net').database('AzureResourceGraph').table('Resources') 
| where timestamp > ago(2d) | where subscriptionId in(subscription_ids) 
| where type =~ "microsoft.network/privateendpoints"
| summarize hint.strategy=shuffle arg_max(timestamp, *) by id | where not(deleted)
| extend properties = todynamic(properties)
| extend privateLinkServiceConnections = todynamic(properties['privateLinkServiceConnections'])
| extend manualPrivateLinkServiceConnections = todynamic(properties['manualPrivateLinkServiceConnections'])
| extend hasAutoConnections = (isnotnull(privateLinkServiceConnections) and array_length(privateLinkServiceConnections) > 0)
| extend hasManualConnections = (isnotnull(manualPrivateLinkServiceConnections) and array_length(manualPrivateLinkServiceConnections) > 0)
| extend connections = case(
    hasAutoConnections, privateLinkServiceConnections,
    hasManualConnections, manualPrivateLinkServiceConnections,
    dynamic([{}])  // preserves a row so endpoints with no connections can be counted
)
| mv-expand connection = connections
| extend connectionState = tostring(connection['properties']['privateLinkServiceConnectionState']['status'])
| summarize ConnectionCount = countif(isnotempty(connectionState)), ApprovedCount = countif(connectionState == "Approved"), RejectedCount = countif(connectionState == "Rejected"), PendingCount = countif(connectionState == "Pending")
    by id, name, subscriptionId, resourceGroup, location, type
| where ConnectionCount == 0 or ApprovedCount == 0
| extend OrphanedReason = case(
    ConnectionCount == 0, "No private link service connections",
    RejectedCount > 0 and ApprovedCount == 0, strcat("All connections rejected (", RejectedCount, " rejected)"),
    PendingCount > 0 and ApprovedCount == 0, strcat("All connections pending approval (", PendingCount, " pending)"),
    ApprovedCount == 0, "No approved connections",
    "Active")
| join kind=leftouter (subscriptions) on $left.subscriptionId == $right.SubscriptionId
| project Environment, AzureCloud, SubscriptionName, SubscriptionId = subscriptionId, ResourceGroup = resourceGroup, Type = type, Name = name, Location = location, OrphanedReason, ConnectionCount, ApprovedCount, RejectedCount, PendingCount
| order by Environment asc, AzureCloud asc, SubscriptionName asc, ResourceGroup asc, Name asc
```

---

### Query 15: Orphaned Private Link Services

**Tile**: Orphaned Private Link Services  
**Purpose**: Find Private Link Services with no PE connections, no approved connections, or no backend Load Balancer.

```kql
// Idle Private Link Services
let Services = datatable(ServiceId:string)['2fa7ba65-93e0-46c6-98b0-1df0c4e8a74d', 'aa7d05ce-5b6c-449f-9f85-1982d2700d79'];
let subscriptions = cluster('https://servicetreepublic.westus.kusto.windows.net').database('Shared').GetSubscriptionsAssociatedWith(Services) | distinct SubscriptionId, SubscriptionName, Environment, AzureCloud;
let subscription_ids = subscriptions | project SubscriptionId;
cluster('argwus2nrpone.westus2.kusto.windows.net').database('AzureResourceGraph').table('Resources') 
| where timestamp > ago(2d) | where subscriptionId in(subscription_ids) 
| where type =~ "microsoft.network/privatelinkservices"
| summarize hint.strategy=shuffle arg_max(timestamp, *) by id | where not(deleted)
| extend properties = todynamic(properties)
| extend privateEndpointConnections = todynamic(properties['privateEndpointConnections'])
| extend loadBalancerFrontendIpConfigurations = todynamic(properties['loadBalancerFrontendIpConfigurations'])
| extend hasLoadBalancer = (isnotnull(loadBalancerFrontendIpConfigurations) and array_length(loadBalancerFrontendIpConfigurations) > 0)
| extend privateEndpointConnections = iif(
    isnull(privateEndpointConnections) or array_length(privateEndpointConnections) == 0,
    dynamic([pack("properties", pack("privateLinkServiceConnectionState", pack("status", "")))]),
    privateEndpointConnections)
| mv-expand connection = privateEndpointConnections
| extend connectionStatus = tostring(connection['properties']['privateLinkServiceConnectionState']['status'])
| summarize ConnectionCount = countif(isnotempty(connectionStatus)), ApprovedCount = countif(connectionStatus == "Approved"), PendingCount = countif(connectionStatus == "Pending"), RejectedCount = countif(connectionStatus == "Rejected"), DisconnectedCount = countif(connectionStatus == "Disconnected"), HasLoadBalancer = any(hasLoadBalancer)
    by id, name, subscriptionId, resourceGroup, location, type
| where ConnectionCount == 0 or ApprovedCount == 0 or not(HasLoadBalancer)
| extend IdleReason = case(
    not(HasLoadBalancer), "No Load Balancer frontend configured",
    ConnectionCount == 0, "No Private Endpoint connections",
    ApprovedCount == 0 and RejectedCount > 0, strcat("All PE connections rejected (", RejectedCount, " rejected)"),
    ApprovedCount == 0 and PendingCount > 0, strcat("All PE connections pending (", PendingCount, " pending)"),
    ApprovedCount == 0, "No approved connections",
    "Active")
| join kind=leftouter (subscriptions) on $left.subscriptionId == $right.SubscriptionId
| project Environment, AzureCloud, SubscriptionName, SubscriptionId = subscriptionId, ResourceGroup = resourceGroup, Type = type, Name = name, Location = location, IdleReason, ConnectionCount, ApprovedCount, RejectedCount, PendingCount, HasLoadBalancer
| order by Environment asc, AzureCloud asc, SubscriptionName asc, ResourceGroup asc, Name asc
```

---

### Query 16: Deallocated Virtual Machines

**Tile**: Deallocated Virtual Machines  
**Purpose**: Find VMs in deallocated state (still incurring storage costs).  
**Uses base variables**: `_subscriptionIds`, `_subscriptions`  
**Note**: Uses a different ARG cluster: `argscuscrpone.southcentralus.kusto.windows.net`

```kql
cluster('argscuscrpone.southcentralus.kusto.windows.net').database('AzureResourceGraph').table('Resources') 
| where subscriptionId in (_subscriptionIds)
| where type =~ "Microsoft.Compute/virtualMachines"
| where not(deleted)
| summarize hint.strategy=shuffle arg_max(timestamp, *) by id
| extend powerStateCode = tostring(properties['extended']['instanceView']['powerState']['code'])
| where powerStateCode == "PowerState/deallocated"
| extend vmSize = tostring(properties['hardwareProfile']['vmSize'])
| join kind=leftouter (_subscriptions) on $left.subscriptionId == $right.SubscriptionId
| project Environment, AzureCloud, SubscriptionName, SubscriptionId = subscriptionId, ResourceGroup = resourceGroup, Name = name, PowerState = powerStateCode, VmSize = vmSize
| order by Environment asc, AzureCloud asc, SubscriptionName asc, ResourceGroup asc, Name asc
```

---

## IPAM Schema Reference

Columns available from `CurrentVipByServiceTree`: PreciseTimeStamp, OrganizationName, ServiceName, ServiceId, SubscriptionId, Environment, IsHOBO, IPAddress, Prefix, Status, FirstPartyUsage, SystemService, Region, ResourceId, ResourceLocation, IpSku, Tier, PublicIPAllocationMethod, IpVersion, DeviceType, LogicalZones, RoutingPreference

## Cluster Reference

| Alias | Cluster URL | Database |
|-------|-------------|----------|
| IPAM | `ipam.kusto.windows.net` | `IpamReport` |
| ARG (West US 2) | `argwus2nrpone.westus2.kusto.windows.net` | `AzureResourceGraph` |
| ARG (South Central) | `argscuscrpone.southcentralus.kusto.windows.net` | `AzureResourceGraph` |
| ServiceTree | `servicetreepublic.westus.kusto.windows.net` | `Shared` |
