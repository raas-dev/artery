/*
------------------------------------------------------------------------------
PARAMETERS
------------------------------------------------------------------------------
*/

param webtest_name string
param ai_name string
param app_name string
param tags object

param location string = resourceGroup().location

/*
------------------------------------------------------------------------------
EXISTING RESOURCES
------------------------------------------------------------------------------
*/

resource app 'Microsoft.Web/sites@2020-12-01' existing = {
  name: app_name
}

resource ai 'Microsoft.Insights/components@2020-02-02-preview' existing = {
  name: ai_name
}

/*
------------------------------------------------------------------------------
RESOURCES
------------------------------------------------------------------------------
*/

resource webtest 'Microsoft.Insights/webtests@2015-05-01' = {
  name: webtest_name
  location: location
  tags: union(tags, {
    'hidden-link:${resourceId('microsoft.Insights/Components', ai.name)}': 'Resource'
  })
  kind: 'ping'
  properties: {
    Name: webtest_name
    SyntheticMonitorId: webtest_name
    Description: app.name
    Enabled: true
    Frequency: 300
    Timeout: 30
    Kind: 'ping'
    RetryEnabled: true
    Locations: [
      {
        Id: 'emea-se-sto-edge'
      }
      {
        Id: 'emea-nl-ams-azr'
      }
      {
        Id: 'emea-gb-db3-azr'
      }
      {
        Id: 'emea-ch-zrh-edge'
      }
      {
        Id: 'emea-fr-pra-edge'
      }
      {
        Id: 'emea-ru-msa-edge'
      }
      {
        Id: 'emea-au-syd-edge'
      }
      {
        Id: 'us-va-ash-azr'
      }
      {
        Id: 'us-fl-mia-edge'
      }
      {
        Id: 'us-il-ch1-azr'
      }
      {
        Id: 'us-tx-sn1-azr'
      }
      {
        Id: 'us-ca-sjc-azr'
      }
      {
        Id: 'latam-br-gru-edge'
      }
      {
        Id: 'apac-jp-kaw-edge'
      }
      {
        Id: 'apac-hk-hkn-azr'
      }
      {
        Id: 'apac-sg-sin-azr'
      }
    ]
    Configuration: {
      WebTest: '<WebTest         Name="${webtest_name}"                Enabled="True"         CssProjectStructure=""         CssIteration=""         Timeout="30"         WorkItemIds=""         xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010"         Description=""         CredentialUserName=""         CredentialPassword=""         PreAuthenticate="True"         Proxy="default"         StopOnError="False"         RecordedResultFile=""         ResultsLocale="">        <Items>        <Request         Method="GET"                Version="1.1"         Url="https://${app.properties.defaultHostName}/"         ThinkTime="0"         Timeout="30"         ParseDependentRequests="False"         FollowRedirects="True"         RecordResult="True"         Cache="False"         ResponseTimeGoal="0"         Encoding="utf-8"         ExpectedHttpStatusCode="200"         ExpectedResponseUrl=""         ReportingName=""         IgnoreHttpStatusCode="False" />        </Items>        </WebTest>'
    }
  }
  dependsOn: [
    app
    ai
  ]
}
