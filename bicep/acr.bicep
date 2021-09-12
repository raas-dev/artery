/*
------------------------------------------------------------------------------
PARAMETERS
------------------------------------------------------------------------------
*/

@minLength(5)
@maxLength(50)
param acr_name string

param tags object

@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param acr_sku_name string = 'Basic'

param acr_sp_object_id string = ''

/*
------------------------------------------------------------------------------
RESOURCES
------------------------------------------------------------------------------
*/

// adminUserEnabled was changed to true on 2021-09-12
// on 2021-08, was confirmed to work with adminUserEnabled: false and an SP
//
// possibly related https://github.com/MicrosoftDocs/azure-docs/issues/64660
// Microsoft must seriously fix this issue...
resource acr 'Microsoft.ContainerRegistry/registries@2020-11-01-preview' = {
  name: acr_name
  location: resourceGroup().location
  tags: tags
  sku: {
    name: acr_sku_name
  }
  properties: {
    adminUserEnabled: true // has to be enabled as of 2021-09-12 for AppService
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
    anonymousPullEnabled: false
  }
}

// AcrPull to rg for Service Principal
resource sp_acr_pull 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = if (!empty(acr_sp_object_id)) {
  name: acr_sp_object_id
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: acr_sp_object_id
  }
}

/*
------------------------------------------------------------------------------
OUTPUTS
------------------------------------------------------------------------------
*/

output loginServer string = acr.properties.loginServer
