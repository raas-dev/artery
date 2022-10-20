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

param location string = resourceGroup().location

/*
------------------------------------------------------------------------------
RESOURCES
------------------------------------------------------------------------------
*/

// adminUserEnabled: false may or may not work (works as of 2021-09-12)
// https://github.com/MicrosoftDocs/azure-docs/issues/64660
resource acr 'Microsoft.ContainerRegistry/registries@2020-11-01-preview' = {
  name: acr_name
  location: location
  tags: tags
  sku: {
    name: acr_sku_name
  }
  properties: {
    adminUserEnabled: false
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
