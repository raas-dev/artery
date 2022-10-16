/*
------------------------------------------------------------------------------
PARAMETERS
------------------------------------------------------------------------------
*/

@description('Prefix')
@minLength(2)
@maxLength(8)
param prefix string

@description('Name')
@minLength(2)
@maxLength(10)
param name string

@description('Environment')
@allowed([
  'prod'
  'stg'
])
param environment string = 'stg'

@description('Owner')
@minLength(2)
@maxLength(32)
param owner string

@description('App Service slot name i.e. postfix to append to the hostname')
param app_slot_postfix string = 'slot'

@description('Service principal object ID for App Service to pull from ACR')
param acr_sp_object_id string = ''

@description('Service principal client ID for App Service to puill from ACR')
param acr_sp_client_id string = ''

@description('Service principal password for App Service to puill from ACR')
param acr_sp_password string = ''

@description('Azure AD application client ID for App Service auth')
param aad_app_client_id string = ''

@description('Azure AD application client secret for App Service auth')
param aad_app_client_secret string = ''

@description('Virtual network address space to create')
param vnet_mask string = '172.16.10.0/24'

@description('Virtual network DNS servers to configure')
param vnet_dns_servers array = [
  '168.63.129.16'
]

@description('Public subnet address space to create in the virtual network')
param public_subnet_mask string = '172.16.10.0/25'

@description('Private subnet address space to create in the virtual network')
param private_subnet_mask string = '172.16.10.128/25'

/*
------------------------------------------------------------------------------
VARIABLES
------------------------------------------------------------------------------
*/

var tags = {
  app: name
  environment: environment
  owner: owner
}

var vnet_name = '${prefix}-${environment}-${name}-vnet'
var sa_name = replace('${prefix}${environment}${name}sa', '-',  '')
var law_name = '${prefix}-${environment}-${name}-law'
var ai_name = '${prefix}-${environment}-${name}-ai'
var kv_name = '${prefix}-${environment}-${name}-kv'
var acr_name = replace('${prefix}${environment}${name}acr', '-', '')
var app_plan_name = '${prefix}-${environment}-${name}-asp'
var app_name = '${prefix}-${environment}-${name}-app'
var webtest_name = '${prefix}-${environment}-${name}-wt'

/*
------------------------------------------------------------------------------
MODULES
------------------------------------------------------------------------------
*/

// Virtual Network

module vnet 'vnet.bicep' = {
  name: 'vnet'
  params: {
    vnet_name: vnet_name
    vnet_mask: vnet_mask
    vnet_dns_servers: vnet_dns_servers
    public_subnet_mask: public_subnet_mask
    private_subnet_mask: private_subnet_mask
    tags: tags
  }
}

// Storage Account

module sa 'sa.bicep' = {
  name: 'sa'
  params: {
    sa_name: sa_name
    virtual_network_rules: [
      {
        id: vnet.outputs.publicSubnetId
        action: 'Allow'
      }
    ]
    tags: tags
  }
}

// Key Vault
// For Azure DevOps, see: https://docs.microsoft.com/en-us/azure/devops/organizations/security/allow-list-ip-url?view=azure-devops&tabs=IP-V4#inbound-connections

module kv 'kv.bicep' = {
  name: 'kv'
  params: {
    kv_name: kv_name
    acr_sp_client_id: acr_sp_client_id
    acr_sp_password: acr_sp_password
    aad_app_client_secret: aad_app_client_secret
    virtual_network_rules: [
      {
        id: vnet.outputs.publicSubnetId
      }
    ]
    ip_rules: [
      {
        value: '40.74.28.0/23' // Azure DevOps, Western Europe
      }
    ]
    tags: tags
  }
}

// Azure Container Registry

module acr 'acr.bicep' = {
  name: 'acr'
  params: {
    acr_name: acr_name
    acr_sp_object_id: acr_sp_object_id
    tags: tags
  }
}

// Log Analytics Workspace

module law 'law.bicep' = {
  name: 'law'
  params: {
    law_name: law_name
    tags: tags
  }
}

// Application Insights

module ai 'ai.bicep' = {
  name: 'ai'
  params: {
    ai_name: ai_name
    law_id: law.outputs.workspaceId
    azure_app_push_receivers: [
      {
        name: owner
        emailAddress: owner
      }
    ]
    tags: tags
  }
}

// App Service

module app 'app.bicep' = {
  name: 'app'
  params: {
    app_name: app_name
    app_slot_postfix: app_slot_postfix
    app_plan_name: app_plan_name
    vnet_name: vnet_name
    sa_name: sa_name
    kv_name: kv_name
    law_name: law_name
    ai_instrumentation_key: ai.outputs.instrumentationKey
    aad_app_client_id: aad_app_client_id
    tags: tags
  }
}

// Function App
/*
module app 'app.bicep' = {
  name: 'fapp'
  params: {
    app_name: '${prefix}-${environment}-${name}-fapp'
    app_kind: 'functionapp'
    sku: {
      name: 'EP1'
      tier: 'ElasticPremium'
    }
    app_slot_postfix: app_slot_postfix
    app_plan_name: app_plan_name
    app_plan_kind: 'elastic'
    vnet_name: vnet_name
    sa_name: sa_name
    kv_name: kv_name
    law_name: law_name
    ai_instrumentation_key: ai.outputs.instrumentationKey
    aad_app_client_id: aad_app_client_id
    tags: tags
  }
}
*/

// Availability web test for App Service

module wt 'wt.bicep' = {
  name: 'wt'
  params: {
    webtest_name: webtest_name
    ai_name: ai_name
    app_name: app_name
    tags: tags
  }
}

// Private DNS zones and endpoints for Storage Account Blob Container

module pdns_blob 'pdns.bicep' = {
  name: 'pdns_blob'
  params: {
    pdns_zone_name: 'privatelink.blob.core.windows.net'
    vnet_id_to_link: vnet.outputs.vnetId
    tags: tags
  }
}

module pe_blob 'pe.bicep' = {
  name: 'pe_blob'
  params: {
    name: '${prefix}-${environment}-${name}-sa-blob-pe'
    target_id: sa.outputs.storageAccountId
    type: 'blob'
    pdns_zone_name: pdns_blob.outputs.privateDnsZoneName
    subnet_id: vnet.outputs.privateSubnetId
    tags: tags
  }
}

// Private DNS zones and endpoints for App Service
// Note: Availability tests do not work with App Service private endpoints
/*
module pdns_sites 'pdns.bicep' = {
  name: 'pdns_sites'
  params: {
    pdns_zone_name: 'privatelink.azurewebsites.net'
    vnet_id_to_link: vnet.outputs.vnetId
    tags: tags
  }
}

module pe_app 'pe.bicep' = {
  name: 'pe_app'
  params: {
    name: '${prefix}-${environment}-${name}-app-pe'
    target_id: app.outputs.appServiceId
    type: 'sites'
    pdns_zone_name: pdns_sites.outputs.privateDnsZoneName
    subnet_id: vnet.outputs.privateSubnetId
    tags: tags
  }
}

// Note: Slot private endpoint does not work via ARM - create it from portal
// See: https://docs.microsoft.com/en-us/answers/questions/244087/azure-app-service-with-private-endpoints-does-not.html
module pe_app_slot 'pe.bicep' = {
  name: 'pe_app_slot'
  params: {
    name: '${prefix}-${environment}-${name}-app-${app_slot_postfix}-pe'
    target_id: app.outputs.appServiceSlotId
    type: 'sites'
    pdns_zone_name: pdns_sites.outputs.privateDnsZoneName
    subnet_id: vnet.outputs.privateSubnetId
    tags: tags
  }
}
*/
