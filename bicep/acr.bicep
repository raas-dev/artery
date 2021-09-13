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

resource acr 'Microsoft.ContainerRegistry/registries@2020-11-01-preview' = {
  name: acr_name
  location: resourceGroup().location
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

/*
------------------------------------------------------------------------------
OUTPUTS
------------------------------------------------------------------------------
*/

output loginServer string = acr.properties.loginServer
