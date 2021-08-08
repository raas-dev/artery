/*
------------------------------------------------------------------------------
PARAMETERS
------------------------------------------------------------------------------
*/

param pdns_zone_name string = ''
param vnet_id_to_link string = ''
param tags object

/*
------------------------------------------------------------------------------
RESOURCES
------------------------------------------------------------------------------
*/

resource pdns 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: pdns_zone_name
  location: 'global'
  tags: tags
}

resource pdns_vnet_link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: pdns
  name: pdns_zone_name
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet_id_to_link
    }
  }
}

/*
------------------------------------------------------------------------------
OUTPUTS
------------------------------------------------------------------------------
*/

output privateDnsZoneName string = pdns.name
