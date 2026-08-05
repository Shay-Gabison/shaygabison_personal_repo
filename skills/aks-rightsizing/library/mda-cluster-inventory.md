# MDA Cluster Inventory

> Authoritative list of all MDA production clusters for rightsizing analysis.
> Use this instead of discovering clusters by ID range heuristics.

---

## Cluster Types

MDA clusters are classified into two types:

| Type | Topology | Rightsizing approach |
|------|----------|---------------------|
| **Core** | Primary / DR per cluster group | Focus on Primary clusters. DR clusters are typically paused (0 replicas, no compute). Unexpectedly running DR clusters are optimization opportunities. |
| **Inline** | Active-Active (all carry live traffic) | All clusters should be analyzed equally. No Primary/DR distinction. |

---

## Core Clusters

Core clusters run non-inline workloads. Each group has Primary clusters (carry live traffic) and
DR clusters (standby, typically paused via KEDA).

### Core 101

| Role | Clusters |
|------|----------|
| **Primary** | WUS-101, WEU-102, EUS2-101, UKS-101, WUS2-101, USGV-102, USMV-102 |
| **DR** | EUS-102, NEU-102, CUS-101, UKW-102, WCUS-101, USGT-102, USMT-102 |

### Core 103

| Role | Clusters |
|------|----------|
| **Primary** | WUS-103, WEU-103, EUS2-103, UKS-103, WUS2-103, USGV-103, USMV-103 |
| **DR** | EUS-103, NEU-103, CUS-103, UKW-103, WCUS-103, USGT-103, USMT-103 |

### Core 105

| Role | Clusters |
|------|----------|
| **Primary** | WUS-105, WEU-105, EUS2-105, UKS-105, WUS2-105 |
| **DR** | EUS-105, NEU-105, CUS-105, UKW-105, WCUS-105 |

### Core 106

| Role | Clusters |
|------|----------|
| **Primary** | WUS-106, WEU-106, EUS2-106, UKS-106, WUS2-106, USGV-106, USMV-106 |
| **DR** | EUS-106, NEU-106, CUS-106, UKW-106, WCUS-106, USGT-106, USMT-106 |

### Core 111

| Role | Clusters |
|------|----------|
| **Primary** | WUS-111, WEU-111, EUS2-111, UKS-111, WUS2-111, USGV-111, USMV-111 |
| **DR** | EUS-111, NEU-111, CUS-111, UKW-111, WCUS-111, USGT-111, USMT-111 |

### Core 112

| Role | Clusters |
|------|----------|
| **Primary** | WUS-112, WEU-112, EUS2-112, UKS-112, WUS2-112, USGV-112, USMV-112 |
| **DR** | EUS-112, NEU-112, CUS-112, UKW-112, WCUS-112, USGT-111, USMT-111 |

### Core cluster totals

| Group | Primary | DR | Total |
|-------|--------:|---:|------:|
| 101 | 7 | 7 | 14 |
| 103 | 7 | 7 | 14 |
| 105 | 5 | 5 | 10 |
| 106 | 7 | 7 | 14 |
| 111 | 7 | 7 | 14 |
| 112 | 7 | 7 | 14 |
| **Total** | **40** | **40** | **80** |

---

## Inline Clusters

Inline clusters run active-active workloads (`inline-access-connectors`, `inline-connectors`,
`inline-session-connectors`). All carry live traffic equally — no Primary/DR distinction.

| Clusters (-101 suffix) | Clusters (-108 suffix) |
|-------------------------|------------------------|
| WEU-101 | WEU-108 |
| AUS-101 | AUS-108 |
| FRC-101 | FRC-108 |
| UKW-101 | UKW-108 |
| CIN-101 | CIN-108 |
| WUS3-101 | WUS3-108 |
| CNC-101 | CNC-108 |
| EAS-101 | EAS-108 |
| NEU-101 | NEU-108 |
| EUS-101 | EUS-108 |
| BRS-101 | BRS-108 |
| USGV-101 | USGV-108 |
| USGA-101 | USGA-108 |
| USMV-101 | USMV-108 |
| USMA-101 | USMA-108 |

**Total inline clusters: 30** (15 × -101 + 15 × -108)

---

## Fleet Totals

| Type | Clusters |
|------|----------|
| Core Primary | 40 |
| Core DR | 40 |
| Inline | 30 |
| **Grand Total** | **110** |

---

## DR Paused Patterns

Core DR clusters typically have services paused via:

1. **KEDA paused annotation**: `autoscaling.keda.sh/paused-replicas: "0"`
2. **KEDA disabled + zero replicas**: `keda.enabled: false` with `replicaCount: 0`

When paused, Geneva will show no utilization data (0 replicas = 0 pods). This is expected — not a
data coverage issue. Skip utilization queries for paused DR services.

## DR Running Unexpectedly

If a Core DR cluster shows active replicas and KEDA is not paused, flag it as an optimization
opportunity — unexpected DR compute that may be wasteful.

---

## Usage Notes

- **For fleet-wide analysis**: iterate over all clusters in this inventory rather than discovering
  by ID range. Process cluster-by-cluster, namespace-by-namespace.
- **For single-service analysis**: use this inventory to classify the target cluster's type and
  role, then apply the appropriate analysis approach.
- **Savings attribution**: count savings from Primary and Inline clusters. Paused DR clusters
  consume no compute (savings = 0). Unexpectedly running DR clusters contribute to savings but
  categorize them separately.
