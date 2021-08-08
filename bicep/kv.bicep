/*
------------------------------------------------------------------------------
PARAMETERS
------------------------------------------------------------------------------
*/

param kv_name string
param tags object

param acr_sp_client_id string = ''
param acr_sp_password string = ''
param aad_app_client_secret string = ''
param soft_delete_retention_in_days int = 30
param virtual_network_rules array = []
param ip_rules array = []

/*
------------------------------------------------------------------------------
RESOURCES
------------------------------------------------------------------------------
*/

resource kv 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: kv_name
  location: resourceGroup().location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: []
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true
    enableSoftDelete: true
    softDeleteRetentionInDays: soft_delete_retention_in_days
    enableRbacAuthorization: true
    networkAcls: {
      bypass: 'AzureServices'  // enabledForTemplateDeployment
      defaultAction: 'Deny'
      virtualNetworkRules: virtual_network_rules
      ipRules: ip_rules
    }
  }
}

resource kv_registry_username 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = if (!empty(acr_sp_client_id)) {
  parent: kv
  name: 'DOCKER-REGISTRY-SERVER-USERNAME'
  tags: tags
  properties: {
    value: acr_sp_client_id
    attributes: {
      enabled: true
    }
  }
}

resource kv_registry_password 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = if (!empty(acr_sp_password)) {
  parent: kv
  name: 'DOCKER-REGISTRY-SERVER-PASSWORD'
  tags: tags
  properties: {
    value: acr_sp_password
    attributes: {
      enabled: true
    }
  }
}

resource kv_aad_app_secret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = if (!empty(aad_app_client_secret)) {
  parent: kv
  name: 'AAD-APP-CLIENT-SECRET'
  tags: tags
  properties: {
    value: aad_app_client_secret
    attributes: {
      enabled: true
    }
  }
}

/*
------------------------------------------------------------------------------
OUTPUTS
------------------------------------------------------------------------------
*/

output uri string = kv.properties.vaultUri
