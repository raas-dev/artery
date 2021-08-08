/*
------------------------------------------------------------------------------
PARAMETERS
------------------------------------------------------------------------------
*/

param vnet_name string
param vnet_mask string
param public_subnet_mask string
param private_subnet_mask string
param tags object

param vnet_dns_servers array = [
  '168.63.129.16'
]
param public_subnet_name string = 'public'
param public_subnet_delegations array = [
  {
    name: 'asp'
    properties: {
      serviceName: 'Microsoft.Web/serverFarms'
    }
  }
]
param private_subnet_name string = 'private'
param private_subnet_delegations array = []

/*
------------------------------------------------------------------------------
VARIABLES
------------------------------------------------------------------------------
*/

var all_service_endpoints = [
  {
    service: 'Microsoft.AzureActiveDirectory'
    locations: [
      '*'
    ]
  }
  {
    service: 'Microsoft.AzureCosmosDB'
    locations: [
      '*'
    ]
  }
  {
    service: 'Microsoft.CognitiveServices'
    locations: [
      '*'
    ]
  }
  {
    service: 'Microsoft.ContainerRegistry'
    locations: [
      '*'
    ]
  }
  {
    service: 'Microsoft.EventHub'
    locations: [
      '*'
    ]
  }
  {
    service: 'Microsoft.KeyVault'
    locations: [
      '*'
    ]
  }
  {
    service: 'Microsoft.ServiceBus'
    locations: [
      '*'
    ]
  }
  {
    service: 'Microsoft.Sql'
    locations: [
      '*'
    ]
  }
  {
    service: 'Microsoft.Storage'
    locations: [
      '*'
    ]
  }
  {
    service: 'Microsoft.Web'
    locations: [
      '*'
    ]
  }
]

/*
------------------------------------------------------------------------------
RESOURCES
------------------------------------------------------------------------------
*/

resource vnet 'Microsoft.Network/virtualNetworks@2020-07-01' = {
  name: vnet_name
  location: resourceGroup().location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnet_mask
      ]
    }
    dhcpOptions: {
      dnsServers: vnet_dns_servers
    }
    subnets: [
      {
        name: public_subnet_name
        properties: {
          addressPrefix: public_subnet_mask
          serviceEndpoints: all_service_endpoints
          delegations: public_subnet_delegations
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: private_subnet_name
        properties: {
          addressPrefix: private_subnet_mask
          serviceEndpoints: []
          delegations: private_subnet_delegations
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

/*
------------------------------------------------------------------------------
OUTPUTS
------------------------------------------------------------------------------
*/

output vnetId string = vnet.id

output publicSubnetId string = vnet.properties.subnets[0].id
output privateSubnetId string = vnet.properties.subnets[1].id
