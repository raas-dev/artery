/*
------------------------------------------------------------------------------
PARAMETERS
------------------------------------------------------------------------------
*/

param name string
param target_id string
param type string
param pdns_zone_name string
param subnet_id string
param tags object

/*
------------------------------------------------------------------------------
EXISTING RESOURCES
------------------------------------------------------------------------------
*/

resource pdns 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: pdns_zone_name
}

/*
------------------------------------------------------------------------------
RESOURCES
------------------------------------------------------------------------------
*/

resource pe 'Microsoft.Network/privateEndpoints@2020-07-01' = {
  name: name
  location: resourceGroup().location
  tags: tags
  properties: {
    subnet: {
      id: subnet_id
    }
    privateLinkServiceConnections: [
      {
        name: name
        properties: {
          privateLinkServiceId: target_id
          groupIds: [
            type
          ]
        }
      }
    ]
  }
}

resource pdns_group 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-06-01' = {
  parent: pe
  name: type
  properties: {
    privateDnsZoneConfigs: [
      {
        name: type
        properties: {
          privateDnsZoneId: pdns.id
        }
      }
    ]
  }
}
