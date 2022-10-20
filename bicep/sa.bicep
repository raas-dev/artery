/*
------------------------------------------------------------------------------
PARAMETERS
------------------------------------------------------------------------------
*/

param sa_name string
param tags object

@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Premium_LRS'
  'Premium_ZRS'
  'Standard_GZRS'
  'Standard_RAGZRS'
])
param sa_sku_name string = 'Standard_LRS'

@allowed([
  'Storage'
  'StorageV2'
  'BlobStorage'
  'FileStorage'
  'BlockBlobStorage'
])
param sa_kind string = 'StorageV2'

@allowed([
  'Hot'
  'Cool'
])
param sa_access_tier string = 'Hot'
param virtual_network_rules array = []
param ip_rules array = []

param location string = resourceGroup().location

/*
------------------------------------------------------------------------------
VARIABLES
------------------------------------------------------------------------------
*/

var file_share_quote_in_gbs = 1

/*
------------------------------------------------------------------------------
RESOURCES
------------------------------------------------------------------------------
*/

resource sa 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: sa_name
  location: location
  tags: tags
  sku: {
    name: sa_sku_name
  }
  kind: sa_kind
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: true
    allowSharedKeyAccess: true
    supportsHttpsTrafficOnly: true
    accessTier: sa_access_tier
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      virtualNetworkRules: virtual_network_rules
      ipRules: ip_rules
    }
  }
}

resource share 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-02-01' = {
  name: '${sa.name}/default/share'
  properties: {
    shareQuota: file_share_quote_in_gbs
  }
}

resource public 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-02-01' = {
  name: '${sa.name}/default/public'
  properties: {
    publicAccess: 'Blob'
  }
}

/*
------------------------------------------------------------------------------
OUTPUT
------------------------------------------------------------------------------
*/

output storageAccountId string = sa.id

output fileEndpoint string = sa.properties.primaryEndpoints.file
output blobEndpoint string = sa.properties.primaryEndpoints.blob
