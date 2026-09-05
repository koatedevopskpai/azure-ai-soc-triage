# Cribl Lite SOC Pipeline

## Overview

Cribl Stream normalizes and routes logs. This folder contains pipeline configs for a **local/free Cribl Lite simulation** (cost: $0) plus conceptual multi-cloud routes (Azure, AWS, GCP) that will later stream into a single Sentinel workspace.

## Pipelines

```
cribl-lite-soc-pipeline/
  pipelines/
    azure.json       # Azure Activity + SigninLogs -> Sentinel
    aws.json         # CloudTrail -> Sentinel
    gcp.json         # GCP Audit Logs -> Sentinel
    local_sim.json   # LOCAL only: sample logs -> filter -> normalize -> file
```

## Local Simulation (Cost: $0)

`local_sim.json` shows the core Cribl concepts without any cloud spend:

- **Input**: read a sample JSON log file
- **Route**: drop noise (healthchecks, debug severity)
- **Processor**: `eval` to normalize fields (`_time`, `sourcetype`, `host`)
- **Output**: write normalized events to a local file

Run Cribl Stream (free tier / CE) locally and load this pipeline to demonstrate routing + normalization.

## Multi-Cloud Notes (Future Work)

- Each cloud pipeline routes into the same `sentinel-http` output for unified analytics.
- Refine filters and field mappings once real log sources are connected.
- Add routing to S3/BigQuery for long-term storage (post-MVP).

## Cost Notes

- Cribl Lite / Community Edition runs locally at **$0**.
- Cloud Cribl SaaS is not needed for the MVP — do not deploy it to keep under $20/month.