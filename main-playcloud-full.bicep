// ═══════════════════════════════════════════════════════════════════
//  Full Cloud Resume — PlayCloud Compliant Template
//  Interactive naming convention + complete stack including Cosmos DB
//  Built to match PlayCloud sandbox specifications exactly.
//
//  Known exclusions:
//    - Static Web Apps (requires persistent GitHub connection)
// ═══════════════════════════════════════════════════════════════════

// ── Interactive Parameters ────────────────────────────────────────
@description('Short company or project prefix e.g. jg or contoso (lowercase, no spaces)')
@minLength(2)
@maxLength(10)
param prefix string

@description('Deployment environment')
@allowed([
  'dev'
  'staging'
  'prod'
])
param environment string

@description('Instance number e.g. 001')
@minLength(3)
@maxLength(3)
param instance string = '001'

@description('Azure region — must be centralus for PlayCloud')
param location string = 'centralus'

// ── Naming Convention Variables ───────────────────────────────────
var storageAccountName   = toLower('${prefix}${environment}st${instance}')
var functionStorageName  = toLower('${prefix}${environment}fst${instance}')
var functionAppName      = toLower('${prefix}-${environment}-func-${instance}')
var appServicePlanName   = toLower('${prefix}-${environment}-plan-${instance}')
var cosmosAccountName    = toLower('${prefix}-${environment}-cosmos-${instance}')
var databaseName         = 'ResumeDatabase'
var containerName        = 'VisitorCounter'

// ── Storage Account (resume site hosting) ────────────────────────
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

// ── Function Storage ──────────────────────────────────────────────
resource functionStorage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: functionStorageName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
  }
}

// ── App Service Plan (Consumption Y1) ────────────────────────────
resource appPlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {}
}

// ── Cosmos DB Account ─────────────────────────────────────────────
// Explicitly configured to match PlayCloud sandbox spec:
// Standard offer, provisioned throughput, no serverless capability
// Jun 2026: capacityMode only works on 2026-04-01-preview — verify before bumping this API version
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2026-04-01-preview' = {
  name: cosmosAccountName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    capacityMode: 'Provisioned'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    capabilities: []
  }
}

// ── Cosmos DB Database ────────────────────────────────────────────
resource cosmosDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-04-15' = {
  parent: cosmosAccount
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
    options: {
      throughput: 400
    }
  }
}

// ── Cosmos DB Container ───────────────────────────────────────────
resource cosmosContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: cosmosDatabase
  name: containerName
  properties: {
    resource: {
      id: containerName
      partitionKey: {
        paths: ['/id']
        kind: 'Hash'
      }
    }
  }
}

// ── Function App ──────────────────────────────────────────────────
resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  properties: {
    serverFarmId: appPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionStorage.name};AccountKey=${functionStorage.listKeys().keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~22'
        }
        {
          name: 'CosmosDB'
          value: 'AccountEndpoint=https://${cosmosAccount.name}.documents.azure.com:443/;AccountKey=${cosmosAccount.listKeys().primaryMasterKey};'
        }
      ]
cors: {
  allowedOrigins: [
    'https://${storageAccountName}.z19.web.${az.environment().suffixes.storage}'
  ]
}
    }
  }
}

// ── Outputs ───────────────────────────────────────────────────────
output storageAccountName   string = storageAccount.name
output functionAppName      string = functionApp.name
output cosmosAccountName    string = cosmosAccount.name
output functionAppUrl       string = 'https://${functionApp.properties.defaultHostName}/api/VisitorCounter'
output namingConvention     string = 'All resources named from prefix "${prefix}", environment "${environment}", instance "${instance}"'
