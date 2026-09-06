param(
    [Parameter(Mandatory=$true)]
    [string]$WorkspaceId,
    [Parameter(Mandatory=$true)]
    [string]$SharedKey,
    [string]$LogType = "AISOCSigninLogs",
    [int]$FailCount = 12,
    [int]$Threshold = 5
)

<#
.SYNOPSIS
  Ingest synthetic brute-force sign-in data into a custom Log Analytics table for demoing the AI-SOC detection rule.
.DESCRIPTION
  Pushes a batch of failed sign-ins plus one success from a single IP/user into the AISOCSigninLogs custom table,
  matching the pattern the "AI-SOC Brute Force" analytics rule detects. Used to produce a real fired incident for
  portfolio screenshots without needing live Entra sign-in data.
.EXAMPLE
  .\push-signin-data.ps1 -WorkspaceId "<workspace-guid>" -SharedKey "<primary-key>"
.NOTES
  The data collector API auto-creates the custom table (_CL suffix) on first ingest. The workspace GUID and
  primary shared key are in the Azure portal under Log Analytics workspace -> Agents/Data collector API.
#>

$Endpoint = "https://" + $WorkspaceId + ".ods.opinsights.azure.com/api/logs?api-version=2016-04-01"

$records = @()
$attackerIp = "185.220.101.10"
$targetUser = "koate@socsim.onmicrosoft.com"

# Failed sign-ins - a few minutes ago (distinct event times)
$baseTime = (Get-Date).AddMinutes(-5).ToUniversalTime()
1..$FailCount | ForEach-Object {
    $records += @{
        IPAddress         = $attackerIp
        UserPrincipalName = $targetUser
        ResultType        = if ($_ % 2) { "50053" } else { "50126" }
        AppDisplayName    = "Azure Portal"
    }
}

# One successful sign-in after the failures
$records += @{
    IPAddress         = $attackerIp
    UserPrincipalName = $targetUser
    ResultType        = "0"
    AppDisplayName    = "Azure Portal"
}

$json = $records | ConvertTo-Json -Depth 4

# Build the HMAC-SHA256 signature for the data collector API
$date = (Get-Date).ToUniversalTime().ToString("r")
$contentLength = [System.Text.Encoding]::UTF8.GetByteCount($json)
$stringToHash = "POST`n$contentLength`napplication/json`nx-ms-date:$date`n/api/logs"
$keyBytes = [Convert]::FromBase64String($SharedKey)
$hmac = New-Object System.Security.Cryptography.HMACSHA256
$hmac.Key = $keyBytes
$hashBytes = $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($stringToHash))
$signature = [Convert]::ToBase64String($hashBytes)
$auth = "SharedKey $WorkspaceId`:$signature"

$headers = @{
    "Content-Type"   = "application/json"
    "Log-Type"       = $LogType
    "x-ms-date"      = $date
    "Authorization"  = $auth
}

try {
    $resp = Invoke-WebRequest -Uri $Endpoint -Method Post -Headers $headers -Body $json -UseBasicParsing
    Write-Output "HTTP $($resp.StatusCode) - records sent: $($records.Count)"
    Write-Output "Rule will fire when failures >= $Threshold for a single IP+user."
} catch {
    Write-Output "ERROR: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        Write-Output $reader.ReadToEnd()
    }
}
