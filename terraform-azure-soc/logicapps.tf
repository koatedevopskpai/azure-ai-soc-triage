resource "azurerm_resource_group_template_deployment" "soc_playbook" {
  name                = "la-soc-playbook-deploy"
  resource_group_name = azurerm_resource_group.soc.name
  deployment_mode     = "Incremental"

  parameters_content = jsonencode({
    enrichmentUrl = { value = "https://${azurerm_container_app.enrichment.latest_revision_fqdn}/api/EnrichIP" }
    aiTriageUrl   = { value = "https://${azurerm_container_app.ai_triage.latest_revision_fqdn}/triage" }
  })

  lifecycle {
    replace_triggered_by = [
      azurerm_container_app.enrichment,
      azurerm_container_app.ai_triage,
    ]
  }

  template_content = <<TEMPLATE
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "workflowName": {
      "type": "string",
      "defaultValue": "la-soc-playbook"
    },
    "enrichmentUrl": {
      "type": "string",
      "defaultValue": "https://${azurerm_container_app.enrichment.latest_revision_fqdn}/api/EnrichIP"
    },
    "aiTriageUrl": {
      "type": "string",
      "defaultValue": "https://${azurerm_container_app.ai_triage.latest_revision_fqdn}/triage"
    },
    "workspaceResourceId": {
      "type": "string",
      "defaultValue": "${azurerm_log_analytics_workspace.sentinel.id}"
    }
  },
  "resources": [
    {
      "type": "Microsoft.Logic/workflows",
      "apiVersion": "2019-05-01",
      "name": "[parameters('workflowName')]",
      "location": "[resourceGroup().location]",
      "identity": {
        "type": "SystemAssigned"
      },
      "properties": {
        "state": "Enabled",
        "definition": {
          "$schema": "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
          "contentVersion": "1.0.0.0",
          "parameters": {
            "$connections": {
              "type": "Object",
              "defaultValue": {}
            }
          },
          "triggers": {
            "When_a_Sentinel_incident_is_created": {
              "type": "Request",
              "kind": "Http",
              "inputs": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "IncidentARMId": { "type": "string" },
                    "IncidentName": { "type": "string" },
                    "IncidentId": { "type": "string" },
                    "WorkspaceId": { "type": "string" },
                    "IPAddress": { "type": "string" },
                    "UserPrincipalName": { "type": "string" }
                  },
                  "required": [ "IncidentName", "IncidentId", "WorkspaceId", "IPAddress" ]
                }
              }
            }
          },
          "actions": {
            "Call_Enrichment": {
              "type": "Http",
              "inputs": {
                "method": "POST",
                "uri": "[parameters('enrichmentUrl')]",
                "body": {
                  "IPAddress": "@triggerBody()?['IPAddress']",
                  "UserPrincipalName": "@triggerBody()?['UserPrincipalName']",
                  "AlertName": "@triggerBody()?['IncidentName']"
                }
              },
              "runAfter": {}
            },
            "Call_AI_Triage": {
              "type": "Http",
              "inputs": {
                "method": "POST",
                "uri": "[parameters('aiTriageUrl')]",
                "body": {
                  "IPAddress": "@triggerBody()?['IPAddress']",
                  "Geo": "@body('Call_Enrichment')?['Geo']",
                  "AbuseScore": "@body('Call_Enrichment')?['AbuseScore']",
                  "AlertName": "@triggerBody()?['IncidentName']",
                  "UserPrincipalName": "@triggerBody()?['UserPrincipalName']"
                }
              },
              "runAfter": {
                "Call_Enrichment": [ "Succeeded" ]
              }
            },
            "Compose_Comment": {
              "type": "Compose",
              "inputs": "AI Triage Decision: @{body('Call_AI_Triage')}",
              "runAfter": {
                "Call_AI_Triage": [ "Succeeded" ]
              }
            },
            "Update_incident": {
              "type": "Http",
              "inputs": {
                "method": "PUT",
                "uri": "@concat('https://management.azure.com/subscriptions/', split(triggerBody()?['IncidentARMId'], '/')[2], '/resourceGroups/', split(triggerBody()?['IncidentARMId'], '/')[4], '/providers/Microsoft.OperationalInsights/workspaces/log-soc-mvp/providers/Microsoft.SecurityInsights/incidents/', triggerBody()?['IncidentId'], '/comments/', guid())",
                "headers": {
                  "Content-Type": "application/json"
                },
                "queries": {
                  "api-version": "2023-12-01-preview"
                },
                "body": {
                  "properties": {
                    "message": "@outputs('Compose_Comment')"
                  }
                },
                "authentication": {
                  "type": "ManagedServiceIdentity",
                  "audience": "https://management.azure.com"
                }
              },
              "runAfter": {
                "Compose_Comment": [ "Succeeded" ]
              }
            },
            "Notify_SOC": {
              "type": "ApiConnection",
              "inputs": {
                "host": {
                  "connection": {
                    "name": "@parameters('$connections')['office365']['connectionId']"
                  }
                },
                "operationId": "SendEmail",
                "parameters": {
                  "to": "soc-team@contoso.com",
                  "subject": "SOC Incident - @{triggerBody()?['IncidentName']}",
                  "body": "Enrichment: @{body('Call_Enrichment')}\n\nAI Triage: @{body('Call_AI_Triage')}"
                }
              },
              "runAfter": {
                "Update_incident": [ "Succeeded" ]
              }
            }
          },
          "outputs": {}
        },
        "parameters": {
          "$connections": {
            "value": {
              "office365": {
                "id": "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Web/locations/${azurerm_resource_group.soc.location}/managedApis/office365",
                "connectionId": "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${azurerm_resource_group.soc.name}/providers/Microsoft.Web/connections/office365",
                "connectionName": "office365"
              }
            }
          }
        }
      }
    },
    {
      "type": "Microsoft.Authorization/roleAssignments",
      "apiVersion": "2022-04-01",
      "name": "[guid(parameters('workspaceResourceId'), 'sentinel-responder')]",
      "scope": "[parameters('workspaceResourceId')]",
      "dependsOn": [
        "[resourceId('Microsoft.Logic/workflows', parameters('workflowName'))]"
      ],
      "properties": {
        "principalId": "[reference(resourceId('Microsoft.Logic/workflows', parameters('workflowName')), '2019-05-01', 'Full').identity.principalId]",
        "roleDefinitionId": "[subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '3e150937-b8fe-4cfb-8069-0eaf05ecd056')]",
        "principalType": "ServicePrincipal"
      }
    }
  ],
  "outputs": {
    "workflowName": {
      "type": "string",
      "value": "[parameters('workflowName')]"
    }
  }
}
TEMPLATE
}

output "logic_app_name" {
  value = "la-soc-playbook"
}

output "logic_app_trigger_url" {
  value = try(azurerm_resource_group_template_deployment.soc_playbook.output_content, null)
}