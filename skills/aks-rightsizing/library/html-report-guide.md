# HTML Report Guide — AKS Rightsizing

This document defines the section structure, content guidance, and component conventions for
generating self-contained AKS rightsizing report files.

The **complete HTML template** (skeleton + CSS) lives at:
[`../assets/report-template.html`](../assets/report-template.html)

Use that file as the structural reference. This guide tells you **what to put inside** each section.

---

## File Conventions

| Setting            | Value                                                                                                  |
| ------------------ | ------------------------------------------------------------------------------------------------------ |
| **File name**      | `{service}-rightsizing.html` (kebab-case, e.g., `copernicus-worker-rightsizing.html`)                   |
| **Location**       | User home folder: `~/` (macOS), `$HOME\` (PowerShell), `%USERPROFILE%\` (CMD)                          |
| **Self-contained** | All CSS is inline in a `<style>` block — no external stylesheets or JS libraries                       |
| **Dark mode**      | Auto-detected via `prefers-color-scheme` media query                                                   |
| **Encoding**       | UTF-8, `lang="en"`                                                                                     |

### Saving the file

Detect the OS and resolve the home folder path:

- **macOS**: write to `~/{service}-rightsizing.html`
- **Windows (PowerShell)**: write to `$HOME\{service}-rightsizing.html`
- **Windows (CMD)**: write to `%USERPROFILE%\{service}-rightsizing.html`

### Opening the file

After writing the file, **open it automatically**. On Windows, try PowerShell first; fall back
to CMD if PowerShell is unavailable:

```bash
# macOS
open ~/{service}-rightsizing.html

# Windows — PowerShell (try first)
Start-Process "$HOME\{service}-rightsizing.html"

# Windows — CMD (fallback)
start "" "%USERPROFILE%\{service}-rightsizing.html"
```

---

## Navigation

The `<nav class="section-nav">` must be **generated dynamically** — only include `<a>` links for
sections that are actually present in the report. Do not include links to omitted sections (e.g.,
skip `#jvm` for non-Java services). Each nav link's `href` must match the corresponding
`<section id="...">`.

---

## Section Structure

Generate sections **in this order**. Each section uses an `id` matching the nav links. Include only
sections that have data; skip the JVM section for non-Java services.

### 1. Executive Summary (`#summary`)

A grid of 3-5 stat cards showing the headline numbers, followed by alert boxes for critical findings.

**Stat card values** (pick from):
- Est. CPU Cores Saved
- Est. Memory GiB Saved
- Total Replicas
- CPU Throttling (fleet-wide)
- OOM Kills (14d)
- Critical Findings count

**Alert boxes**: One `alert-danger` per critical finding, one `alert-warning` per important warning.
Keep text to 1-2 sentences. Bold the title.

```html
<section id="summary">
<h2>📊 Executive Summary</h2>
<div class="grid-5">
  <div class="stat-card">
    <div class="stat-value">~5,240</div>
    <div class="stat-label">Est. CPU Cores Saved</div>
  </div>
  <!-- ... more stat cards ... -->
</div>
<div class="alert alert-danger" style="margin-top:16px">
  <strong>🚨 Critical — {title}:</strong> {description}
</div>
</section>
```

### 2. CPU Analysis (`#cpu`)

Sub-sections:
1. **Throttling Gate** — PASSED ✅ or FAILED ❌ with explanation
2. **CPU data table** inside a `.card` — columns: Cluster, CPU Req, CPU Limit, P50, P95, P99, Max,
   Throttling, Req/P99 Ratio, Classification (badge)
3. **Utilization bars** — one bar per cluster showing P99-vs-request %
4. **CPU Limit analysis** table — Cluster, Request, Limit, Limit/Req ratio, Status badge
5. **CPU Savings Estimate** table — Cluster, Current Req, Recommended Req, Saving/Pod, Replicas,
   Total Cores Saved (with a totals row)

Use `.highlight-row` on the most notable rows. Use `.arrow-down` class for savings values.
Add a totals row with `font-weight:700; background:var(--cp-accent-soft)`.

### 3. Memory Analysis (`#memory`)

Sub-sections:
1. **OOM Kill Gate** — PASSED ✅ or FAILED ❌
2. **Memory data table** — Cluster, Mem Req, Mem Limit, Avg Usage, Utilization %, JVM -Xmx,
   Expected Container (Xmx×1.2), Limit=Req? (badge)
3. **Alert boxes** for any limit≠request violations or unusual off-heap usage
4. **Memory savings table** — Cluster, Current Req, Recommended Req, Savings/Pod, Replicas,
   Total GiB Saved, Rationale

### 4. Replica / KEDA Analysis (`#replicas`)

Sub-sections:
1. **Alert** if all replicas are pinned at max
2. **Replica table** — Cluster, KEDA Min, KEDA Max (Helm), KEDA Max (Geneva/Live), Actual Replicas,
   % at Max, Replica Drift? (badge)
3. **Root cause card** explaining why replicas are pinned (if applicable)
4. Recommendation text

Use `badge-critical` for confirmed replica drift. Color anomalous values with
`color:var(--cp-danger)`.

### 5. Cross-Cluster Drift (`#drift`)

One big comparison table inside a `.card`:
- Rows = settings (CPU Req, CPU Limit, Mem Req, Mem Limit, JVM -Xmx, JVM -Xms, KEDA Max Helm,
  KEDA Max Live, Topology maxSkew, etc.)
- Columns = clusters
- Last column = "Drift?" with badge

Color divergent values with `color:var(--cp-warning)` or `color:var(--cp-danger)`.
Add an `alert-info` summary below the table.

### 6. JVM Deep-Dive (`#jvm`) — Java services only

Include only if the service is a Java application with memory request > 20 GiB.

Sub-sections:
1. Explanation of why K8s memory utilization is misleading for JVM services
2. **JVM config table** — Cluster, -Xms, -Xmx, Xms==Xmx?, Container Mem, Xmx×1.2, Excess
3. **OTEL JVM memory analysis** (when OTEL metrics are available):
   - Data source badge: `✅ OTEL metrics available (otelagent / jvm.memory.used)`
   - **Per-cluster OTEL JVM usage table** — each row is a separate cluster/data_center with
     its own independently queried data:
     Cluster, data_center, Avg JVM Used (14d), Current Xmx, Recommended Xmx (that DC's avg × 1.2),
     Recommended Container (Xmx × 1.2), Current Container, Savings per Pod
   - ⚠️ Each row MUST be based on that cluster's own OTEL query — never copy one region's
     JVM data to another row
   - Green success alert per cluster summarizing the automated finding
   - If OTEL data is available for a cluster, do NOT show the jcmd prompt for that cluster
4. **Investigation needed** alert (per-cluster, when OTEL is NOT available for that cluster):
   - Warning badge: `⚠️ OTEL metrics unavailable for {cluster} — manual investigation required`
   - Prompt to run `jcmd GC.heap_info`
   - If OTEL was detected in Helm but query returned empty for that region, include an info
     box explaining what was tried and suggesting the user verify OTEL agent configuration
5. Alert for Xms≠Xmx violations

### 7. Structured Recommendations (`#recommendations`)

Three tables inside `.card` blocks:
1. **Per-Cluster CPU Recommendation** — Cluster, Current, Recommended, Rule, Confidence badge,
   Rationale
2. **Per-Cluster Memory Recommendation** — Cluster, Current Req, Current Limit, Rec. Req,
   Rec. Limit, Confidence badge, Rationale
3. **KEDA / Scaling Recommendation** — Cluster, Current Max, Actual Replicas, Recommendation text

### 8. Action Items (`#actions`)

Prioritized action table inside a `.card`:
- Columns: #, Action, Impact (badge), Risk (badge), Owner Input?
- Rows ordered by priority (critical config issues first, then large savings, then investigations)

Followed by a **Helm Values Files to Change** card listing each file and the changes to make.

---

## Component Reference

### Badges

| Class             | Use for                                         |
| ----------------- | ----------------------------------------------- |
| `badge-high`      | High opportunity / high impact                  |
| `badge-medium`    | Medium opportunity / warning                    |
| `badge-low`       | Low risk / high confidence (green)              |
| `badge-ok`        | OK / no action needed                           |
| `badge-critical`  | Critical violations (white on red)              |

### Alerts

| Class            | Use for                                          |
| ---------------- | ------------------------------------------------ |
| `alert-danger`   | Critical findings, violations                    |
| `alert-warning`  | Important warnings, anomalies                    |
| `alert-success`  | Positive confirmations (gates passed)            |
| `alert-info`     | Informational summaries, context notes           |

### Color helpers

- `color:var(--cp-danger)` — red, for violations and dangerous values
- `color:var(--cp-warning)` — amber, for drifted/anomalous values
- `color:var(--cp-success)` — green, for savings arrows
- `color:var(--cp-accent)` — theme accent, for totals and emphasis

### Table patterns

- Wrap all data tables in `<div class="card table-wrap">` for horizontal scroll on narrow viewports
- Use `.num` class on `<td>` for right-aligned numeric values
- Use `.highlight-row` on `<tr>` for the most notable row
- Totals rows: `style="font-weight:700;background:var(--cp-accent-soft);"`
- Savings values: wrap in `<span class="arrow-down">−X</span>`

---

## Multi-Service Reports

When analyzing multiple services in a single run, generate **one HTML file per service** (e.g.,
`copernicus-worker-rightsizing.html` and `lgdlp-worker-rightsizing.html`). Each file is
self-contained.

---

## Rules

1. **Start from the template** — copy [`../assets/report-template.html`](../assets/report-template.html)
   and fill in the sections. The template already includes all CSS and the page structure.
2. **Do not use external resources** — no CDN links, no external fonts, no JavaScript libraries.
3. **Do not modify the CSS theme variables** — use them as-is for consistent theming.
4. **All numeric values in tables must use the `.num` class** for right-alignment.
5. **Always include the dark mode script** in the `<head>` before any styles.
6. **Round values** — CPU cores to integers (or 1 decimal for small values), memory to integers,
   percentages to 1 decimal.
7. **Use semantic HTML** — `<section>`, `<nav>`, `<table>`, `<thead>`, `<tbody>`.
8. **The file must render correctly when opened directly** from the filesystem (`file://` protocol).
9. **HTML-escape dynamic text** — service names, cluster names, and recommendation text may contain
   `&`, `<`, `>`, or `"`. Escape these before inserting into the HTML.
