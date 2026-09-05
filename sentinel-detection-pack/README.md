# Azure Sentinel Detection Pack

This folder contains custom Azure Sentinel analytics rules mapped to MITRE ATT&CK. These detections form the foundation of the AI-SOC MVP.

## Included Rules

- **Brute Force Detection (T1110)** — `rules/brute_force.kql`
  Detects multiple failed logins followed by a successful login from the same IP + user.
- **Ransomware Indicator (T1486)** — `rules/ransomware_indicator.kql`
  Detects mass file deletions/renames (high event count of suspicious file operations outside system directories).

## How to Deploy

1. Open Azure Sentinel → Analytics → Create → Scheduled query rule.
2. Paste the `.kql` query into the rule query box.
3. Set frequency to 1 hour, lookup period to 1 hour (or align with your data).
4. Map MITRE tactics/techniques (T1110, T1486).
5. Enable incident creation so Sentinel creates incidents that trigger your SOAR playbook.

## Folder Structure

```
sentinel-detection-pack/
  rules/
    brute_force.kql
    ransomware_indicator.kql
```

## Notes

- Tune thresholds based on your environment (e.g., `threshold = 10` in brute force).
- To keep costs low, these rules run hourly and only on the required tables (`SigninLogs`, `Event`). Avoid broad `*` scans that increase ingestion and query cost.
- Add more rules as needed; keep each rule scoped to the minimum tables and time range.