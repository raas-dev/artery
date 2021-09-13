/*
------------------------------------------------------------------------------
PARAMETERS
------------------------------------------------------------------------------
*/

param app_name string
param app_slot_postfix string
param app_plan_name string
param vnet_name string
param sa_name string
param kv_name string
param law_name string
param ai_instrumentation_key string
param tags object

@allowed([
  'web'
  'functionapp'
])
param app_kind string = 'web'

@allowed([
  'linux'
  'elastic'
])
param app_plan_kind string = 'linux'

@allowed([
  'S1'
  'P1V2'
  'P1V3'
  'EP1'
])
param app_plan_sku string = 'P1V2'

param aad_app_client_id string = ''
param websites_port string = '8080'
param health_check_path string = '/'
param app_enable_file_shares bool = false
param arr_affinity_enabled bool = false
param web_sockets_enabled bool = false
param app_sa_logs_retention_in_days int = 90

/*
------------------------------------------------------------------------------
VARIABLES
------------------------------------------------------------------------------
*/

var app_file_shares = {
  share: {
    type: 'AzureFiles'
    accountName: sa.name
    accessKey: listKeys(sa.id, '2019-06-01').keys[0].value
    shareName: 'share'
    mountPath: '/share'
  }
}

var app_settings = [
  {
    name: 'AAD_APP_CLIENT_SECRET'
    value: '@Microsoft.KeyVault(VaultName=${kv_name};SecretName=AAD-APP-CLIENT-SECRET)'
  }
  {
    name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
    value: ai_instrumentation_key
  }
  {
    name: 'WEBSITES_PORT'
    value: websites_port
  }
  {
    name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
    value: 'false'
  }
  {
    name: 'WEBSITE_ADD_SITENAME_BINDINGS_IN_APPHOST_CONFIG'
    value: '1'
  }
  {
    name: 'WEBSITE_VNET_ROUTE_ALL'
    value: '1'
  }
]

/*
------------------------------------------------------------------------------
EXISTING RESOURCES
------------------------------------------------------------------------------
*/

resource vnet 'Microsoft.Network/virtualNetworks@2020-07-01' existing = {
  name: vnet_name
}

resource sa 'Microsoft.Storage/storageAccounts@2021-02-01' existing = {
  name: sa_name
}

resource kv 'Microsoft.KeyVault/vaults@2019-09-01' existing = {
  name: kv_name
}

resource law 'Microsoft.OperationalInsights/workspaces@2020-10-01' existing = {
  name: law_name
}

/*
------------------------------------------------------------------------------
RESOURCES
------------------------------------------------------------------------------
*/

resource app_plan 'Microsoft.Web/serverFarms@2020-12-01' = {
  name: app_plan_name
  location: resourceGroup().location
  tags: tags
  kind: app_plan_kind
  sku: {
    name:  app_plan_sku
  }
  properties: {
    perSiteScaling: true
    maximumElasticWorkerCount: app_plan_kind == 'elastic' ? 20 : null
    reserved: app_plan_kind == 'linux' ? true : false
  }
}

resource app 'Microsoft.Web/sites@2020-12-01' = {
  name: app_name
  location: resourceGroup().location
  kind: app_kind
  tags: tags
  properties: {
    serverFarmId: app_plan.id
    httpsOnly: true
    clientAffinityEnabled: arr_affinity_enabled
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource app_config 'Microsoft.Web/sites/config@2020-12-01' = {
  parent: app
  name: 'web'
  properties: {
    healthCheckPath: health_check_path
    minTlsVersion: '1.2'
    http20Enabled: true
    webSocketsEnabled: web_sockets_enabled
    alwaysOn: true
    ftpsState: 'Disabled'
    azureStorageAccounts: app_enable_file_shares ? app_file_shares : null
    acrUseManagedIdentityCreds: true
    appSettings: app_settings
  }
  dependsOn: [
    sa
  ]
}

resource app_slot 'Microsoft.Web/sites/slots@2020-12-01' = if (!empty(app_slot_postfix)) {
  parent: app
  name: app_slot_postfix
  location: resourceGroup().location
  kind: app_kind
  tags: tags
  properties: {
    serverFarmId: app_plan.id
    httpsOnly: true
    clientAffinityEnabled: arr_affinity_enabled
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource app_slot_config 'Microsoft.Web/sites/slots/config@2020-12-01' = if (!empty(app_slot_postfix)) {
  parent: app_slot
  name: 'web'
  properties: {
    healthCheckPath: health_check_path
    minTlsVersion: '1.2'
    http20Enabled: true
    webSocketsEnabled: web_sockets_enabled
    alwaysOn: true
    ftpsState: 'Disabled'
    azureStorageAccounts: app_enable_file_shares ? app_file_shares : null
    acrUseManagedIdentityCreds: true
    appSettings: app_settings
  }
  dependsOn: [
    sa
  ]
}

resource app_vnet_integration 'Microsoft.Web/sites/networkConfig@2020-06-01' = {
  parent: app
  name: 'virtualNetwork'
  properties: {
    subnetResourceId: vnet.properties.subnets[0].id
    swiftSupported: true
  }
  dependsOn: [
    vnet
  ]
}

resource app_slot_vnet_integration 'Microsoft.Web/sites/slots/networkConfig@2020-06-01' = if (!empty(app_slot_postfix)) {
  parent: app_slot
  name: 'virtualNetwork'
  properties: {
    subnetResourceId: vnet.properties.subnets[0].id
    swiftSupported: true
  }
  dependsOn: [
    vnet
  ]
}

// Bicep gives faulty warnings on authsettingsV2
// See: https://github.com/Azure/bicep/issues/2905

resource app_aad_auth 'Microsoft.Web/sites/config@2020-12-01' = if(!empty(aad_app_client_id)) {
  parent: app
  name: 'authsettingsV2'
  properties: {
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: 'RedirectToLoginPage'
      redirectToProvider: 'azureActiveDirectory'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          openIdIssuer: 'https://sts.windows.net/${subscription().tenantId}/v2.0'
          clientId: aad_app_client_id
          clientSecretSettingName: 'AAD_APP_CLIENT_SECRET'
        }
      }
    }
    httpSettings: {
      requireHttps: true
    }
    login: {
      tokenStore: {
        enabled: true
      }
    }
  }
}

resource app_slot_aad_auth 'Microsoft.Web/sites/slots/config@2020-12-01' = if(!empty(aad_app_client_id) && !empty(app_slot_postfix)) {
  parent: app_slot
  name: 'authsettingsV2'
  properties: {
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: 'RedirectToLoginPage'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          openIdIssuer: 'https://sts.windows.net/${subscription().tenantId}/v2.0'
          clientId: aad_app_client_id
          clientSecretSettingName: 'AAD_APP_CLIENT_SECRET'
        }
      }
    }
    httpSettings: {
      requireHttps: true
    }
    login: {
      tokenStore: {
        enabled: true
      }
    }
  }
}

// Log to the sa and the law only from the production slot
resource app_logs 'Microsoft.Insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'logs'
  scope: app
  properties: {
    storageAccountId: sa.id
    workspaceId: law.id
    /*metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: app_sa_logs_retention_in_days
        }
      }
    ]*/
    logs: [
      /*{
        category: 'AppServiceAntivirusScanAuditLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: app_sa_logs_retention_in_days
        }
      }*/
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: app_sa_logs_retention_in_days
        }
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: app_sa_logs_retention_in_days
        }
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: app_sa_logs_retention_in_days
        }
      }
      /*{
        category: 'AppServiceFileAuditLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: app_sa_logs_retention_in_days
        }
      }*/
      {
        category: 'AppServiceAuditLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: app_sa_logs_retention_in_days
        }
      }
      {
        category: 'AppServiceIPSecAuditLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: app_sa_logs_retention_in_days
        }
      }
      {
        category: 'AppServicePlatformLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: app_sa_logs_retention_in_days
        }
      }
    ]
  }
}

resource app_fs_logs 'Microsoft.Web/sites/config@2020-12-01' = {
  parent: app
  name: 'logs'
  properties: {
    applicationLogs: {
      fileSystem: {
        level: 'Warning'
      }
    }
    httpLogs: {
      fileSystem: {
        retentionInMb: 35
        enabled: true
      }
    }
    failedRequestsTracing: {
      enabled: true
    }
    detailedErrorMessages: {
      enabled: true
    }
  }
}

resource app_slot_fs_logs 'Microsoft.Web/sites/slots/config@2020-12-01' = if (!empty(app_slot_postfix)) {
  parent: app_slot
  name: 'logs'
  properties: {
    applicationLogs: {
      fileSystem: {
        level: 'Warning'
      }
    }
    httpLogs: {
      fileSystem: {
        retentionInMb: 35
        enabled: true
      }
    }
    failedRequestsTracing: {
      enabled: true
    }
    detailedErrorMessages: {
      enabled: true
    }
  }
}

resource app_kv_secret_reader 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid(app.id)
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: app.identity.principalId
  }
  dependsOn: [
    app
  ]
}

resource app_slot_kv_secret_reader 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = if (!empty(app_slot_postfix)) {
  name: guid(app_slot.id)
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: app_slot.identity.principalId
  }
  dependsOn: [
    app_slot
  ]
}

resource app_acr_pull 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid(app.name)
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: app.identity.principalId
  }
}

resource app_slot_acr_pull 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid(app_slot.name)
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: app_slot.identity.principalId
  }
}

/*
------------------------------------------------------------------------------
OUTPUTS
------------------------------------------------------------------------------
*/

output appServiceId string = app.id
output appServiceSlotId string = app_slot.id

output publicUrl string = app.properties.defaultHostName
output slotPublicUrl string = !empty(app_slot_postfix) ? app_slot.properties.defaultHostName : ''

output outboundIpAddresses string = app.properties.outboundIpAddresses
output possibleOutboundIpAddresses string = app.properties.possibleOutboundIpAddresses
