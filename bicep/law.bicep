/*
------------------------------------------------------------------------------
PARAMETERS
------------------------------------------------------------------------------
*/

param law_name string
param tags object
param retention_in_days int = 30 // first 30 days are free

param location string = resourceGroup().location

/*
------------------------------------------------------------------------------
VARIABLES
------------------------------------------------------------------------------
*/

resource law 'Microsoft.OperationalInsights/workspaces@2020-10-01' = {
  name: law_name
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retention_in_days
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

/*
------------------------------------------------------------------------------
OUTPUTS
------------------------------------------------------------------------------
*/

output workspaceId string = law.id
output retetionInDays int = law.properties.retentionInDays
