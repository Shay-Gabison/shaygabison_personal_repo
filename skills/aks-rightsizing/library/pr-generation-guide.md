# PR Generation Guide — Config Files and Safe Edits

> How to locate the source-of-truth config for a rightsizing change and prepare a safe PR.
> Use this only when the user explicitly asks for a file change or PR.

---

## Configuration Approaches

MDA services commonly use one of two configuration models:

1. **Config Gen** — a higher-level config generates the final Helm values.
2. **Manual Helm values** — the team edits `values.yaml`-style files directly.

### Required first question

Before proposing edits, the skill must ask the user:

> Does this service use **Config Gen** or **manual Helm values** as the source of truth?

Do not modify files until this is known.

---

## Discovery Workflow

1. Identify the owning repo and deployment path.
2. Confirm whether the repo uses Config Gen or manual Helm values.
3. Read the target file before proposing or applying any change.
4. Map the rightsizing recommendation to the exact keys that need editing.
5. Preserve region-specific overrides unless the user explicitly wants to unify them.

---

## Common Helm Values Patterns

Resource requests, limits, autoscaling, topology, and JVM options often appear in values files like this:

```yaml
# Standard Kubernetes helm values pattern
resources:
  requests:
    cpu: "4"          # or "4000m"
    memory: "60Gi"    # or "61440Mi"
  limits:
    cpu: "8"          # or no CPU limit if removed
    memory: "60Gi"    # MUST equal request

# HPA configuration
autoscaling:
  enabled: true
  minReplicas: 10
  maxReplicas: 20

# KEDA configuration (alternative to HPA)
keda:
  enabled: true
  minReplicaCount: 10
  maxReplicaCount: 20

# Topology spread constraints
topologySpreadConstraints:
  - maxSkew: 1        # flag if 1, consider 2
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule

# JVM memory settings (if applicable)
env:
  - name: JAVA_OPTS
    value: "-Xmx32g -Xms16g"
  # or
  - name: JVM_MAX_MEMORY
    value: "32g"
```

---

## Common File Locations

Look for configuration in paths such as:

- `values.yaml`
- `values-prod.yaml`
- `values-production.yaml`
- `helm/values.yaml`
- `charts/{service}/values.yaml`
- `values-{region}.yaml`
- `values.{region}.yaml`

Config Gen repositories may store the source in a different directory tree; do not assume the generated file should be edited directly.

---

## Safe Modification Rules

1. **Always read the file first.**
   - Never edit blindly.
2. **Preserve YAML structure.**
   - Keep indentation, comments, and ordering unless the file already needs a local adjustment.
3. **Only change targeted values.**
   - Do not refactor or reformat unrelated sections.
4. **CPU limit removal**
   - If the recommendation is to remove a CPU limit, delete or comment the limit line rather than replacing it with an arbitrary new number.
5. **Memory limit policy**
   - Always set memory limit equal to memory request.
6. **Document rationale**
   - Add a short YAML comment near the changed value when appropriate so reviewers understand why the change exists.

---

## Mapping Recommendations to YAML

Typical edits:

- CPU request:
  - `resources.requests.cpu`
- CPU limit:
  - `resources.limits.cpu`
- Memory request:
  - `resources.requests.memory`
- Memory limit:
  - `resources.limits.memory`
- HPA minimum:
  - `autoscaling.minReplicas`
- HPA maximum:
  - `autoscaling.maxReplicas`
- KEDA minimum:
  - `keda.minReplicaCount`
- KEDA maximum:
  - `keda.maxReplicaCount`
- Topology:
  - `topologySpreadConstraints[].maxSkew`
- JVM settings:
  - `env[].value` for `JAVA_OPTS`
  - `env[].value` for `JVM_MAX_MEMORY`

When JVM changes are recommended, keep the JVM and container-memory recommendations consistent.

---

## PR Content

When handing off to a PR generator, use:

- **Title**
  - `perf(rightsizing): reduce {service_name} CPU/memory requests`

- **Description should include**
  - analysis summary with before / after values
  - confidence scores
  - CPU throttling data
  - affected clusters
  - links to Eng Hub pod-rightsizing docs
  - warnings for any **Low confidence** recommendation

- **Tags**
  - `rightsizing`
  - `compute-efficiency`

- **Optional linkage**
  - attach the ADO work item if one was created

---

## Cross-Cluster Considerations

When the same service exists on multiple clusters:

- If all clusters share one config file, a single PR may be correct.
- If configs differ, ask whether the goal is:
  - preserve per-cluster differences
  - or intentionally unify them

Keep in mind:

- config drift may be intentional
- regional traffic can justify different requests or HPA minima
- PRs still target all regions; SDP handles staged rollout

---

## Review Discipline

Before finalizing a PR:

1. Confirm the file edited is the real source of truth.
2. Confirm memory limit equals memory request everywhere touched.
3. Confirm CPU-limit removal is intentional and explained.
4. Confirm any HPA / KEDA change is framed as owner-validated if business context is required.

The PR should make the smallest safe config change that matches the measured recommendation.
