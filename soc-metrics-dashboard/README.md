# SOC Metrics Dashboard

## Overview

KQL queries for the AI-SOC MVP's key performance indicators:

- **Time-to-Triage (TTT)** — average minutes from incident creation to Logic App run.
- **Automation Success Rate** — % of Logic App runs that succeeded.
- **AI Triage Usage** — call volume and severity distribution.

Use these queries in:

- **Sentinel Workbooks** (line chart, KPI cards, pie charts)
- **Power BI** via the Log Analytics connector

## Folder Structure

```
soc-metrics-dashboard/
  kql/
    time_to_triage.kql
    automation_success.kql
    ai_usage.kql
```

## KPI Summary

| KPI | Query | Visual |
|---|---|---|
| Avg Time-to-Triage (min) | `time_to_triage.kql` | Line chart by day |
| Automation Success Rate (%) | `automation_success.kql` | KPI card + success/fail bar |
| AI severity distribution | `ai_usage.kql` | Pie chart + CriticalRate KPI |

## Cost Notes

- Queries run against Log Analytics data you already ingest — no extra cost.
- Keep the workbook scoped to the last 30 days (retention is set to 30 days anyway).

## Notes

Extend with MTTR, MTTD, and SOC maturity KPIs as the platform grows.