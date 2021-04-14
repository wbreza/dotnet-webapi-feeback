param defaultResourceNamePrefix string
param environmentNamePrefix string

@secure()
param sqlServerAdminPassword string

// Following recommended naming conventions: 
// https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/naming-and-tagging
param webAppName string = 'app-${defaultResourceNamePrefix}-${environmentNamePrefix}'
param keyVaultName string = '${defaultResourceNamePrefix}-${environmentNamePrefix}'
param sqlServerName string = 'sql-${defaultResourceNamePrefix}-${environmentNamePrefix}'
param sqlDatabaseName string = 'webapidb'
param applicationInsightsName string = 'appi-${defaultResourceNamePrefix}-${environmentNamePrefix}'
param logAnalyticsWorkspaceName string = 'log-${defaultResourceNamePrefix}-${environmentNamePrefix}'
param webAppHostingPlanName string = 'appplan-${defaultResourceNamePrefix}-${environmentNamePrefix}'


var webAppSku = 'P1v2'
var sqlServerAdminName = 'azure_dba'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2020-08-01' = {
  name: logAnalyticsWorkspaceName
  location: resourceGroup().location
  tags: {
    Environment: environmentNamePrefix
  }
  properties: {
  }
}

resource ai 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: applicationInsightsName
  location: resourceGroup().location
  kind: 'web'
  tags: {
    Environment: environmentNamePrefix
  }
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: keyVaultName
  location: resourceGroup().location
  tags: {
    Environment: environmentNamePrefix
  }
  properties: {
    enableSoftDelete: true
    tenantId: subscription().tenantId
    sku:{
      name: 'standard'
      family: 'A'
    }
    accessPolicies:[
      {
        tenantId: subscription().tenantId
        objectId: webApp.identity.principalId
        permissions: {
          secrets: [ 
            'get' 
            'list' 
          ]
        }
      }
    ]
  }
}

resource sqlServerConnectionString 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyVaultName}/SQLCONNSTRING'
  dependsOn: [ 
    keyVault
    sqlServer
    db
  ]
  properties: {
    value: 'Data Source=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Database=${sqlDatabaseName};User ID=${sqlServerAdminName};Persist Security Info=True;Password=${sqlServerAdminPassword}'
  }
}

resource sqlServer 'Microsoft.Sql/servers@2019-06-01-preview' = {
  name: sqlServerName
  location: resourceGroup().location
  tags: {
    Environment: environmentNamePrefix
  }
  properties: {
    administratorLogin: sqlServerAdminName
    administratorLoginPassword: sqlServerAdminPassword
  }
}

resource db 'Microsoft.Sql/servers/databases@2020-08-01-preview' = {
  name: '${sqlServer.name}/${sqlDatabaseName}'
  location: resourceGroup().location
  tags: {
    Environment: environmentNamePrefix
  }
  properties: {
    licenseType: 'LicenseIncluded'
  }
  sku: {
    name: 'GP_Gen5'
    capacity: 2
  }
}

resource sqlFirewallRule 'Microsoft.Sql/servers/firewallRules@2015-05-01-preview' = {
  name: '${sqlServer.name}/allowInboundTraffic'
  dependsOn: [
    sqlServer
  ]
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource webAppHostingPlan 'Microsoft.Web/serverfarms@2020-06-01' = {
  name: webAppHostingPlanName
  location: resourceGroup().location
  tags: {
    Environment: environmentNamePrefix
  }
  properties: {
    reserved: false // Windows code
  }
  sku: {
    name: webAppSku
    capacity: 1
  }
}

resource webApp 'Microsoft.Web/sites@2020-06-01' = {
  name: webAppName
  location: resourceGroup().location
  tags: {
    Environment: environmentNamePrefix
  }
  properties: {
    serverFarmId: webAppHostingPlan.id
    httpsOnly: true
    siteConfig: {
      http20Enabled: true
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: ai.properties.InstrumentationKey
        }
        {
          name: 'APPINSIGHTS_PROFILERFEATURE_VERSION'
          value: '1.0.0'
        }
        {
          name: 'APPINSIGHTS_SNAPSHOTFEATURE_VERSION'
          value: '1.0.0'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: 'InstrumentationKey=${ai.properties.InstrumentationKey};IngestionEndpoint=https://westeurope-1.in.applicationinsights.azure.com/'
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~2'
        }        
        {
          name: 'DiagnosticServices_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'InstrumentationEngine_EXTENSION_VERSION'
          value: 'disabled'
        }
        {
          name: 'SnapshotDebugger_EXTENSION_VERSION'
          value: 'disabled'
        }
        {
          name: 'WEBSITE_HTTPLOGGING_RETENTION_DAYS'
          value: '7'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '6.9.1'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_BaseExtensions'
          value: 'disabled'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_Mode'
          value: 'recommended'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_PreemptSdk'
          value: '1'
        }
        {
          name: 'KeyVaultName'
          value: '${keyVaultName}'
        }
      ]
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

output webAppFinalName string = webAppName
output sqlDatabaseFinalName string = db.name
