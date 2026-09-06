# Azure Sentinel Detection Pack

This folder contains custom Azure Sentinel analytics rules mapped to MITRE ATT&CK. These detections form the foundation of the AI-SOC MVP.

## Included Rules

### Standard rules (production data sources)
- **Brute Force Detection (T1110)** — `rules/brute_force.kql`
  Detects multiple failed logins followed by a successful login from the same IP + user (uses `SigninLogs`).
- **Ransomware Indicator (T1486)** — `rules/ransomware_indicator.kql`
  Detects mass file deletions/renames (high event count of suspicious file operations outside system directories, uses Sysmon/`Event`).

### Demo rule (custom table, no live data needed)
- **AI-SOC Brute Force (custom)** — `rules/custom/aisoc-brute-force.json`
  Detects `>= 5` failed sign-ins from a single IP + user over the `AISOCSigninLogs_CL` custom table. This lets you demo the full **rule → incident → SOAR → AI triage → comment → email** flow without live Entra sign-in data.

## How to Deploy

### Standard rules
1. Open Azure Sentinel → Analytics → Create → Scheduled query rule.
2. Paste the `.kql` query into the rule query box.
3. Set frequency to 1 hour, lookup period to 1 hour (or align with your data).
4. Map MITRE tactics/techniques (T1110, T1486).
5. Enable incident creation so Sentinel creates incidents that trigger your SOAR playbook.

### Demo rule + synthetic data
1. Ingest synthetic sign-in data into the `AISOCSigninLogs` custom table:
   ```powershell
   .\scripts\push-signin-data.ps1 -WorkspaceId "<workspace-guid>" -SharedKey "<primary-shared-key>"
   ```
   (Workspace GUID + primary key: Log Analytics workspace → Agents / Data collector API.)
2. Import `rules/custom/aisoc-brute-force.json` as a Scheduled analytics rule.
3. Within the next 5-min cycle the rule fires and creates an incident → triggers the Logic App playbook.

## Folder Structure

```
sentinel-detection-pack/
  rules/
    brute_force.kql
    ransomware_indicator.kql
    custom/
      aisoc-brute-force.json
  scripts/
    push-signin-data.ps1
```

## Notes

- Tune thresholds based on your environment (e.g., `threshold = 10` in brute force).
- To keep costs low, rules run hourly (or 5-min for the demo) and only on required tables. Custom-table ingestion is a few KB → effectively $0.
- Add more rules as needed; keep each rule scoped to the minimum tables and time range.
