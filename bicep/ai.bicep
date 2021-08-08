/*
------------------------------------------------------------------------------
PARAMETERS
------------------------------------------------------------------------------
*/

param ai_name string
param law_id string
param tags object

@description('Response time threshold in milliseconds to trigger an alert')
@minValue(1000)
@maxValue(60000)
param response_time_threshold_ms int = 5000

@minValue(99)
@maxValue(100)
param availability_threshold_pct int = 99

param azure_app_push_receivers array = []

/*
------------------------------------------------------------------------------
RESOURCES
------------------------------------------------------------------------------
*/

resource ai 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: ai_name
  location: resourceGroup().location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: law_id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource availability_mal 'Microsoft.Insights/metricAlerts@2018-03-01' = if(!empty(azure_app_push_receivers)) {
  name: 'Availability below target - ${ai.name}'
  location: 'global'
  tags: tags
  properties: {
    description: 'Decreased availability alert'
    severity: 0
    enabled: true
    scopes: [
      ai.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'Availability below target'
          metricName: 'availabilityResults/availabilityPercentage'
          operator: 'LessThan'
          threshold: availability_threshold_pct
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    autoMitigate: true
    actions: [
      {
        actionGroupId: ops_action_group.id
      }
    ]
  }
}

resource latency_mal 'Microsoft.Insights/metricAlerts@2018-03-01' = if(!empty(azure_app_push_receivers)) {
  name: 'High Response Time - ${ai.name}'
  location: 'global'
  tags: tags
  properties: {
    description: 'High response time alert'
    severity: 0
    enabled: true
    scopes: [
      ai.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'Response time over threshold'
          metricName: 'requests/duration'
          operator: 'GreaterThan'
          threshold: response_time_threshold_ms
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    autoMitigate: true
    actions: [
      {
        actionGroupId: ops_action_group.id
      }
    ]
  }
}

resource ops_action_group 'Microsoft.Insights/actionGroups@2019-06-01' = if(!empty(azure_app_push_receivers)) {
  name: 'Operators'
  location: 'global'
  tags: tags
  properties: {
    groupShortName: 'Ops'
    enabled: true
    azureAppPushReceivers: azure_app_push_receivers
  }
}

/*
------------------------------------------------------------------------------
OUTPUTS
------------------------------------------------------------------------------
*/

output instrumentationKey string = ai.properties.InstrumentationKey
output retentionInDays int = ai.properties.RetentionInDays
