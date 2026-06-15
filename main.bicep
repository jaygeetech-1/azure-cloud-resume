// ── Parameters ────────────────────────────────────────────────────
param location string = 'eastus'
param storageAccountName string = 'jgcloudresume'
param cosmosAccountName string = 'jg-cloud-resume-db'
param functionAppName string = 'jg-resume-function'
param staticWebAppName string = 'jg-cloud-resume-swa'
param databaseName string = 'ResumeDatabase'
param containerName string = 'VisitorCounter'
param repositoryUrl string = 'https://github.com/jaygeetech-1/azure-cloud-resume'
param branch string = 'main'

// ── Storage Account (Static Website — legacy, kept for PDF hosting) ──
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

// ── Cosmos DB Account ──────────────────────────────────────────────
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2021-10-15' = {
  name: cosmosAccountName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
  }
}

// ── Cosmos DB Database ─────────────────────────────────────────────
resource cosmosDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-10-15' = {
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

// ── Cosmos DB Container ────────────────────────────────────────────
resource cosmosContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-10-15' = {
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

// ── App Service Plan (Consumption) ────────────────────────────────
resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: '${functionAppName}-plan'
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {}
}

// ── Storage Account for Function App ──────────────────────────────
resource functionStorage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: '${take(replace(functionAppName, '-', ''), 20)}stor'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
  }
}

// ── Function App
