---
name: adx-rightsizing
description: "Analyze and right-size Azure Data Explorer (Kusto) clusters from an Engine Health spreadsheet. Reads cluster metrics (CPU, MEM, load factors, disk usage), applies decision logic, and writes recommendations (Hold, Scale-in %, SKU Change) back to the Excel file. Use when the user asks to analyze, right-size, or generate recommendations for ADX/Kusto clusters from a spreadsheet."
domain: "infrastructure"
confidence: "high"
---

# ADX Cluster Right-Sizing Skill

Analyze Azure Data Explorer (Kusto) cluster metrics from an Engine Health Excel spreadsheet and generate right-sizing recommendations to optimize cores and reduce COGs.

## When to Use This Skill

- User asks to "right-size", "analyze", or "generate recommendations" for ADX/Kusto clusters
- User references an Engine Health or Right-Sizing spreadsheet with cluster metrics
- User wants to identify under-utilized clusters or SKU change candidates

## What You Need

| Input | Required? | Example |
|---|---|---|
| Excel file path | Yes | `~/Downloads/Engine_Health_RightSizing.xlsx` |
| Source tab name | Optional (default: `Right-Sizing Snapshot updated`) | `Right-Sizing Snapshot updated` |

## How to Run

**The full analyzer script is embedded at the bottom of this skill** (under "Embedded analyzer script"). Materialize it to a temp file and run it:

```bash
# Extract the embedded script from this SKILL.md into a runnable file:
awk '/^# ===BEGIN analyze.py===$/{flag=1;next}/^# ===END analyze.py===$/{flag=0}flag' \
  ~/.copilot/skills/adx-rightsizing/SKILL.md > /tmp/adx_rightsizing_analyze.py

python3 /tmp/adx_rightsizing_analyze.py "<path_to_excel>"
```

Optional arguments:
- `--source-tab "Tab Name"` — override the source tab (default: `Right-Sizing Snapshot updated`)
- `--cpu-threshold 45` — override CPU/MEM threshold (default: 45)
- `--factor-threshold 45` — override capacity factor threshold (default: 45)
- `--dry-run` — print recommendations to stdout without modifying the file

The script will:
1. Read all cluster rows from the source tab
2. Apply the decision tree to each cluster
3. Write `Recommendation` (column K) and `Why` (column L) in the source tab
4. Regenerate the `Summary` tab with updated counts, costs, and savings
5. Save the modified Excel file

## Decision Logic

### Metrics Used

Primary metrics (columns):
- `Peak CPU` (col H)
- `Peak Memory` (col I)

Capacity factors (max values used for safety):
- `HotDataDiskSpaceUsage max`
- `IngestionCapacityUtilization max`
- `IngestionsLoadFactor max`
- `MergesLoadFactor max`
- `MaterializedViewsLoadFactor max`
- `ExportsLoadFactor max`

None/null values are treated as 0 (no load).

### Decision Tree

```
1. No CPU and no MEM data → "Insufficient data"

2. Peak CPU ≥ 45% OR Peak MEM ≥ 45% → "Hold"
   Cluster is well-utilized; scaling down risks impact.

3. Peak CPU < 45% AND Peak MEM < 45%:
   a. Check all capacity factors (max values)
   b. If ALL capacity factors < 45% → "Scale in"
      Determine percentage by highest metric across CPU, MEM, and all factors:
        • max ≤ 10% → Scale in 50%
        • max ≤ 20% → Scale in 40%
        • max ≤ 30% → Scale in 30%
        • max ≤ 45% → Scale in 25%
   c. If ANY capacity factor ≥ 45% → "SKU Change"
      Identifies bottleneck and suggests target SKU direction.
```

### SKU Change Recommendations

When CPU/MEM are low but a capacity factor is ≥ 45%, the script identifies the bottleneck:

| High Factor | Bottleneck | Direction |
|---|---|---|
| `HotDataDiskSpaceUsage` | Storage/SSD | Storage-optimized SKU with more SSD (L-series or Premium Storage) |
| `MergesLoadFactor` | Background merge compute | More nodes or larger SKU |
| `IngestionsLoadFactor` / `IngestionCapacityUtilization` | Ingestion throughput | More nodes or higher-throughput SKU |
| `MaterializedViewsLoadFactor` | Materialized view maintenance | More nodes to spread load |
| `ExportsLoadFactor` | Export workload | More nodes |

The script recommends 1-2 target SKUs ranked by priority based on the current SKU and bottleneck type.

## Summary Tab

The script regenerates the `Summary` tab with:
- One row per distinct recommendation category
- Columns: `Recommendation`, `Cluster count`, `Total Cost/Day`, `Potential Saving/Day`
- Savings heuristic: scale-in percentage × cost for scale-in recs; 0 for Hold/SKU Change
- `TOTAL` row at bottom

## Output Example

After running, the "Right-Sizing Snapshot updated" tab will have updated columns K and L:

| Recommendation | Why |
|---|---|
| Scale in 50% | CPU 5% / Mem 8% / all factors <10% — halve nodes |
| SKU Change | CPU 12% / Mem 15% / HotDisk 100% — consider L16as_v3 (2TB SSD) |
| Hold | CPU 72% / Mem 19% — compute in-band |
| Insufficient data | No CPU/MEM metrics available |

---

## Embedded analyzer script

Everything between the `===BEGIN analyze.py===` and `===END analyze.py===` markers below is the full, runnable Python script. Extract it with the `awk` one-liner in "How to Run" above.

```python
# ===BEGIN analyze.py===
#!/usr/bin/env python3
"""ADX Cluster Right-Sizing Analyzer.

Reads an Engine Health Excel spreadsheet, applies decision logic to each cluster,
and writes recommendations (Hold, Scale-in %, SKU Change) back to the file.
"""
import argparse
import sys
from openpyxl import load_workbook
from openpyxl.styles import Font, Alignment, PatternFill, Border, Side

# ---------------------------------------------------------------------------
# Capacity factors to check (in priority order for SKU-change diagnosis)
# ---------------------------------------------------------------------------
CAPACITY_FACTORS = [
    "HotDataDiskSpaceUsage max",
    "MergesLoadFactor max",
    "IngestionsLoadFactor max",
    "IngestionCapacityUtilization max",
    "MaterializedViewsLoadFactor max",
    "ExportsLoadFactor max",
]

FACTOR_SHORT_NAMES = {
    "HotDataDiskSpaceUsage max": "HotDisk",
    "MergesLoadFactor max": "MergeLF",
    "IngestionsLoadFactor max": "IngLF",
    "IngestionCapacityUtilization max": "ICU",
    "MaterializedViewsLoadFactor max": "MatViewLF",
    "ExportsLoadFactor max": "ExportLF",
}

FACTOR_BOTTLENECK_DESC = {
    "HotDataDiskSpaceUsage max": "storage/SSD pressure",
    "MergesLoadFactor max": "background merge compute",
    "IngestionsLoadFactor max": "ingestion throughput",
    "IngestionCapacityUtilization max": "ingestion capacity",
    "MaterializedViewsLoadFactor max": "materialized view maintenance",
    "ExportsLoadFactor max": "export workload",
}

# ---------------------------------------------------------------------------
# SKU reference table — ssd_gb is the approximate hot-cache SSD per node
# ---------------------------------------------------------------------------
SKU_CATALOG = {
    # --- Currently in use (legacy / deprecated) ---
    "standard_d2_v2":      {"cores": 2,  "ram": 7,   "ssd_gb": 100,  "cat": "compute"},
    "standard_d11_v2":     {"cores": 2,  "ram": 14,  "ssd_gb": 100,  "cat": "compute"},
    "standard_d13_v2":     {"cores": 8,  "ram": 56,  "ssd_gb": 400,  "cat": "compute"},
    "standard_d14_v2":     {"cores": 16, "ram": 112, "ssd_gb": 800,  "cat": "compute"},
    "standard_ds14_v2":    {"cores": 16, "ram": 112, "ssd_gb": 224,  "cat": "compute"},
    "standard_d2a_v4":     {"cores": 2,  "ram": 8,   "ssd_gb": 50,   "cat": "compute"},
    "standard_d4a_v4":     {"cores": 4,  "ram": 16,  "ssd_gb": 100,  "cat": "compute"},
    "standard_d8a_v4":     {"cores": 8,  "ram": 32,  "ssd_gb": 200,  "cat": "compute"},
    "standard_d16a_v4":    {"cores": 16, "ram": 64,  "ssd_gb": 400,  "cat": "compute"},
    "standard_d8d_v4":     {"cores": 8,  "ram": 32,  "ssd_gb": 300,  "cat": "compute"},
    "standard_d32d_v4":    {"cores": 32, "ram": 128, "ssd_gb": 1200, "cat": "compute"},
    "standard_e2a_v4":     {"cores": 2,  "ram": 16,  "ssd_gb": 50,   "cat": "compute"},
    "standard_e8as_v4":    {"cores": 8,  "ram": 64,  "ssd_gb": 128,  "cat": "compute"},
    "standard_e8s_v4":     {"cores": 8,  "ram": 64,  "ssd_gb": 128,  "cat": "compute"},
    "standard_e16a_v4":    {"cores": 16, "ram": 128, "ssd_gb": 256,  "cat": "compute"},
    "standard_e16as_v4":   {"cores": 16, "ram": 128, "ssd_gb": 256,  "cat": "compute"},
    "standard_e16as_v5":   {"cores": 16, "ram": 128, "ssd_gb": 256,  "cat": "compute"},
    "standard_e16s_v4":    {"cores": 16, "ram": 128, "ssd_gb": 256,  "cat": "compute"},
    "standard_e16d_v4":    {"cores": 16, "ram": 128, "ssd_gb": 600,  "cat": "compute"},
    "standard_e16d_v5":    {"cores": 16, "ram": 128, "ssd_gb": 600,  "cat": "compute"},
    # --- Compute Optimized (current-gen targets) ---
    "standard_e2d_v5":     {"cores": 2,  "ram": 16,  "ssd_gb": 75,   "cat": "compute"},
    "standard_e4d_v5":     {"cores": 4,  "ram": 32,  "ssd_gb": 150,  "cat": "compute"},
    "standard_e8d_v5":     {"cores": 8,  "ram": 64,  "ssd_gb": 300,  "cat": "compute"},
    "standard_e2ads_v5":   {"cores": 2,  "ram": 16,  "ssd_gb": 75,   "cat": "compute"},
    "standard_e4ads_v5":   {"cores": 4,  "ram": 32,  "ssd_gb": 150,  "cat": "compute"},
    "standard_e8ads_v5":   {"cores": 8,  "ram": 64,  "ssd_gb": 300,  "cat": "compute"},
    "standard_e16ads_v5":  {"cores": 16, "ram": 128, "ssd_gb": 600,  "cat": "compute"},
    # --- Storage Optimized (local SSD) ---
    "standard_l8as_v3":    {"cores": 8,  "ram": 64,  "ssd_gb": 1000,  "cat": "storage"},
    "standard_l16as_v3":   {"cores": 16, "ram": 128, "ssd_gb": 2000,  "cat": "storage"},
    "standard_l32as_v3":   {"cores": 32, "ram": 256, "ssd_gb": 4000,  "cat": "storage"},
    "standard_l8s_v3":     {"cores": 8,  "ram": 64,  "ssd_gb": 1000,  "cat": "storage"},
    "standard_l16s_v3":    {"cores": 16, "ram": 128, "ssd_gb": 2000,  "cat": "storage"},
    "standard_l32s_v3":    {"cores": 32, "ram": 256, "ssd_gb": 4000,  "cat": "storage"},
    # --- Storage Optimized (Premium Storage) ---
    "standard_e8as_v5+1tb_ps":  {"cores": 8,  "ram": 64,  "ssd_gb": 1000,  "cat": "storage-ps"},
    "standard_e16as_v5+2tb_ps": {"cores": 16, "ram": 128, "ssd_gb": 2000,  "cat": "storage-ps"},
    "standard_e16as_v5+4tb_ps": {"cores": 16, "ram": 128, "ssd_gb": 4000,  "cat": "storage-ps"},
    "standard_ds14_v2+4tb_ps":  {"cores": 16, "ram": 112, "ssd_gb": 4000,  "cat": "storage-ps"},
}

# Target SKUs for storage-bottleneck upgrades, ordered by SSD capacity
STORAGE_UPGRADE_CANDIDATES = [
    "standard_l8as_v3",          # 8c, 1 TB
    "standard_l8s_v3",           # 8c, 1 TB
    "standard_l16as_v3",         # 16c, 2 TB
    "standard_l16s_v3",          # 16c, 2 TB
    "standard_e16as_v5+4tb_ps",  # 16c, 4 TB PS
    "standard_l32as_v3",         # 32c, 4 TB
    "standard_l32s_v3",          # 32c, 4 TB
]


def _ssd_gb_label(gb):
    """Format SSD GB as human-readable string."""
    if gb >= 1000:
        return f"{gb // 1000} TB"
    return f"{gb} GB"


def _val(v):
    """Coerce a cell value to float, treating None/non-numeric as None."""
    if v is None:
        return None
    try:
        return float(v)
    except (ValueError, TypeError):
        return None


def _build_header_map(ws):
    """Build {header_name: column_index} from row 1 (1-based)."""
    hmap = {}
    for cell in ws[1]:
        if cell.value is not None:
            hmap[str(cell.value).strip()] = cell.column
    return hmap


def _require_headers(hmap, required):
    missing = [h for h in required if h not in hmap]
    if missing:
        raise ValueError(f"Missing required columns: {missing}")


def _get_sku_suggestion(current_sku, primary_bottleneck, high_factors, nodes_avg=None):
    """Return a human-readable SKU suggestion based on bottleneck.

    For HotDataDisk bottleneck, ensures suggested SKU has >= SSD per node
    and estimates the node count needed.
    """
    sku_lower = (current_sku or "").lower().strip()
    cur = SKU_CATALOG.get(sku_lower)
    cur_ssd_gb = cur["ssd_gb"] if cur else None
    cur_cores = cur["cores"] if cur else None
    nodes = int(round(nodes_avg)) if nodes_avg else None

    if primary_bottleneck == "HotDataDiskSpaceUsage max":
        if cur and cur["cat"] in ("storage", "storage-ps"):
            # Already storage-optimized — only suggest a LARGER storage SKU or more nodes
            bigger = []
            for sku_name in STORAGE_UPGRADE_CANDIDATES:
                spec = SKU_CATALOG[sku_name]
                if spec["ssd_gb"] > cur_ssd_gb:
                    bigger.append(f"{sku_name} ({spec['cores']}c, {_ssd_gb_label(spec['ssd_gb'])})")
                    if len(bigger) >= 2:
                        break
            if bigger:
                return f"already storage-optimized ({_ssd_gb_label(cur_ssd_gb)}/node); upgrade to {' or '.join(bigger)}, or scale out (more nodes)"
            return f"already on largest storage SKU ({_ssd_gb_label(cur_ssd_gb)}/node); scale out (add more nodes)"

        # Compute SKU → suggest storage SKU with >= SSD per node
        suggestions = []
        for sku_name in STORAGE_UPGRADE_CANDIDATES:
            spec = SKU_CATALOG[sku_name]
            if cur_ssd_gb is None or spec["ssd_gb"] >= cur_ssd_gb:
                label = f"{sku_name} ({spec['cores']}c, {_ssd_gb_label(spec['ssd_gb'])})"
                # Estimate node adjustment if we can
                if nodes and cur_ssd_gb and spec["ssd_gb"] > 0:
                    hot_disk_pct = high_factors.get("HotDataDiskSpaceUsage max", 100)
                    total_data_gb = (hot_disk_pct / 100) * nodes * cur_ssd_gb
                    needed_nodes = max(2, -(-int(total_data_gb) // spec["ssd_gb"]))  # ceil division
                    label += f" ~{needed_nodes} nodes"
                suggestions.append(label)
            if len(suggestions) >= 2:
                break
        if not suggestions:
            suggestions = [f"standard_l16as_v3 (16c, 2TB)", f"standard_l32as_v3 (32c, 4TB)"]
        cur_label = f" (current: {_ssd_gb_label(cur_ssd_gb)}/node)" if cur_ssd_gb else ""
        return f"move to storage-optimized SKU{cur_label}: { ' or '.join(suggestions)}"

    if primary_bottleneck in ("MergesLoadFactor max", "IngestionsLoadFactor max",
                               "IngestionCapacityUtilization max"):
        return "consider scaling out (more nodes) to spread compute/ingestion load"

    if primary_bottleneck == "MaterializedViewsLoadFactor max":
        return "consider scaling out (more nodes) to spread materialized-view maintenance"

    if primary_bottleneck == "ExportsLoadFactor max":
        return "consider scaling out (more nodes) to handle export workload"

    return "review SKU options for this workload profile"


def classify_cluster(ws, hmap, row_idx, cpu_threshold=45, factor_threshold=45):
    """Classify a single cluster. Returns (recommendation, why)."""
    def cell(header):
        col = hmap.get(header)
        if col is None:
            return None
        return _val(ws.cell(row=row_idx, column=col).value)

    cpu = cell("Peak CPU")
    mem = cell("Peak Memory")
    current_sku = ws.cell(row=row_idx, column=hmap.get("SKU", 5)).value

    factors = {}
    missing_factors = []
    for f in CAPACITY_FACTORS:
        v = cell(f)
        if v is None:
            missing_factors.append(FACTOR_SHORT_NAMES[f])
            factors[f] = 0
        else:
            factors[f] = v

    # 1. Insufficient data
    if cpu is None and mem is None:
        return "Insufficient data", "No CPU/MEM metrics available"

    cpu = cpu if cpu is not None else 0
    mem = mem if mem is not None else 0

    high_factors = {k: v for k, v in factors.items() if v >= factor_threshold}
    max_factor_val = max(factors.values()) if factors else 0

    # 2. Hold — CPU or MEM in-band
    if cpu >= cpu_threshold or mem >= cpu_threshold:
        why = f"CPU {cpu:.0f}% / Mem {mem:.0f}%"
        if cpu >= 80 or mem >= 80:
            why += " — at ceiling"
        else:
            why += " — in-band"
        if high_factors:
            top = sorted(high_factors.items(), key=lambda x: x[1], reverse=True)[:2]
            parts = [f"{FACTOR_SHORT_NAMES[k]} {v:.0f}%" for k, v in top]
            why += f" (note: {', '.join(parts)} elevated)"
        return "Hold", why

    # 3. CPU & MEM below threshold
    if not high_factors:
        # Scale in
        max_util = max(cpu, mem, max_factor_val)
        if max_util <= 10:
            pct = 50
        elif max_util <= 20:
            pct = 40
        elif max_util <= 30:
            pct = 30
        else:
            pct = 25
        why = f"CPU {cpu:.0f}% / Mem {mem:.0f}% / max factor {max_factor_val:.0f}%"
        if missing_factors and len(missing_factors) >= 4:
            why += f" (limited data: {len(missing_factors)} factors missing)"
        why += f" — scale in {pct}%"
        return f"Scale in {pct}%", why

    # SKU Change
    nodes_avg = cell("MachinesTotal avg")
    sorted_high = sorted(high_factors.items(), key=lambda x: (
        CAPACITY_FACTORS.index(x[0]), -x[1]
    ))
    primary = sorted_high[0][0]
    suggestion = _get_sku_suggestion(current_sku, primary, high_factors, nodes_avg)

    parts = [f"{FACTOR_SHORT_NAMES[k]} {v:.0f}%" for k, v in sorted_high]
    why = f"CPU {cpu:.0f}% / Mem {mem:.0f}% / {', '.join(parts)} — {suggestion}"
    return "SKU Change", why


def regenerate_summary(wb, source_sheet_name, results, hmap_source, ws_source):
    """Regenerate the Summary tab from results."""
    if "Summary" in wb.sheetnames:
        del wb["Summary"]
    summary = wb.create_sheet("Summary")

    headers = ["Recommendation", "Cluster count", "Total Cost/Day", "Potential Saving/Day (heuristic)"]
    header_font = Font(bold=True, size=11)
    header_fill = PatternFill("solid", fgColor="4472C4")
    header_font_white = Font(bold=True, size=11, color="FFFFFF")
    num_fmt = '#,##0.00'
    thin_border = Border(
        bottom=Side(style='thin', color='D9D9D9')
    )

    for ci, h in enumerate(headers, 1):
        cell = summary.cell(row=1, column=ci, value=h)
        cell.font = header_font_white
        cell.fill = header_fill
        cell.alignment = Alignment(horizontal="center")

    summary.column_dimensions['A'].width = 28
    summary.column_dimensions['B'].width = 16
    summary.column_dimensions['C'].width = 18
    summary.column_dimensions['D'].width = 30

    # Aggregate
    cost_col = hmap_source.get("Cost/Day")
    buckets = {}
    for row_idx, (rec, why) in results.items():
        cost = _val(ws_source.cell(row=row_idx, column=cost_col).value) or 0
        if rec not in buckets:
            buckets[rec] = {"count": 0, "cost": 0.0, "saving": 0.0}
        buckets[rec]["count"] += 1
        buckets[rec]["cost"] += cost

        pct_match = None
        if rec.startswith("Scale in"):
            try:
                pct_match = int(rec.split()[-1].replace('%', ''))
            except ValueError:
                pass
        if pct_match:
            buckets[rec]["saving"] += cost * pct_match / 100

    # Sort: Scale in 50%, Scale in 40%, Scale in 30%, Scale in 25%, SKU Change, Hold, Insufficient data
    order = ["Scale in 50%", "Scale in 40%", "Scale in 30%", "Scale in 25%",
             "SKU Change", "Hold", "Insufficient data"]
    sorted_keys = sorted(buckets.keys(), key=lambda x: order.index(x) if x in order else 999)

    row = 2
    total_count = 0
    total_cost = 0.0
    total_saving = 0.0
    for key in sorted_keys:
        b = buckets[key]
        summary.cell(row=row, column=1, value=key).border = thin_border
        summary.cell(row=row, column=2, value=b["count"]).border = thin_border
        c = summary.cell(row=row, column=3, value=round(b["cost"], 2))
        c.number_format = num_fmt
        c.border = thin_border
        s = summary.cell(row=row, column=4, value=round(b["saving"], 2))
        s.number_format = num_fmt
        s.border = thin_border
        total_count += b["count"]
        total_cost += b["cost"]
        total_saving += b["saving"]
        row += 1

    # Blank row
    row += 1

    # TOTAL row
    total_font = Font(bold=True, size=11)
    summary.cell(row=row, column=1, value="TOTAL").font = total_font
    summary.cell(row=row, column=2, value=total_count).font = total_font
    c = summary.cell(row=row, column=3, value=round(total_cost, 2))
    c.font = total_font
    c.number_format = num_fmt
    s = summary.cell(row=row, column=4, value=round(total_saving, 2))
    s.font = total_font
    s.number_format = num_fmt


def main():
    parser = argparse.ArgumentParser(description="ADX Cluster Right-Sizing Analyzer")
    parser.add_argument("excel_path", help="Path to the Engine Health Excel file")
    parser.add_argument("--source-tab", default="Right-Sizing Snapshot updated",
                        help="Tab name to analyze (default: 'Right-Sizing Snapshot updated')")
    parser.add_argument("--cpu-threshold", type=float, default=45,
                        help="CPU/MEM threshold for Hold (default: 45)")
    parser.add_argument("--factor-threshold", type=float, default=45,
                        help="Capacity factor threshold for SKU Change (default: 45)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print recommendations without modifying the file")
    args = parser.parse_args()

    print(f"Loading {args.excel_path} ...")
    wb = load_workbook(args.excel_path)

    if args.source_tab not in wb.sheetnames:
        print(f"ERROR: Tab '{args.source_tab}' not found. Available: {wb.sheetnames}")
        sys.exit(1)

    ws = wb[args.source_tab]
    hmap = _build_header_map(ws)

    required = ["Name", "SKU", "Peak CPU", "Peak Memory", "Cost/Day"]
    _require_headers(hmap, required)

    rec_col = hmap.get("Recommendation")
    why_col = hmap.get("Why")
    if rec_col is None or why_col is None:
        print("ERROR: 'Recommendation' and/or 'Why' columns not found in headers.")
        sys.exit(1)

    name_col = hmap["Name"]
    max_row = ws.max_row
    data_rows = max_row - 1
    print(f"Found {data_rows} clusters in '{args.source_tab}'")

    # Validate capacity factor headers
    for f in CAPACITY_FACTORS:
        if f not in hmap:
            print(f"WARNING: Capacity factor '{f}' not found in headers — will be treated as 0")

    results = {}
    for row_idx in range(2, max_row + 1):
        name = ws.cell(row=row_idx, column=name_col).value
        if not name:
            continue
        rec, why = classify_cluster(ws, hmap, row_idx, args.cpu_threshold, args.factor_threshold)
        results[row_idx] = (rec, why)

    # Count results
    from collections import Counter
    rec_counts = Counter(r[0] for r in results.values())
    print(f"\nRecommendation distribution:")
    for rec, count in rec_counts.most_common():
        print(f"  {rec}: {count}")
    print(f"  Total: {sum(rec_counts.values())}")

    if args.dry_run:
        print("\n[DRY RUN] — changes not written.")
        for row_idx, (rec, why) in sorted(results.items()):
            name = ws.cell(row=row_idx, column=name_col).value
            print(f"  {name}: {rec} — {why}")
        return

    # Write recommendations
    for row_idx, (rec, why) in results.items():
        ws.cell(row=row_idx, column=rec_col, value=rec)
        ws.cell(row=row_idx, column=why_col, value=why)

    # Regenerate Summary
    regenerate_summary(wb, args.source_tab, results, hmap, ws)

    wb.save(args.excel_path)
    print(f"\nSaved to {args.excel_path}")
    print("Done!")


if __name__ == "__main__":
    main()
# ===END analyze.py===
```
