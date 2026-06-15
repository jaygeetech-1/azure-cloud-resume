// ═══════════════════════════════════════════════════════════════════
//  Interactive Naming Convention Template
//  Prompts for prefix, environment, and instance at deploy time.
//  Builds all resource names from Microsoft CAF abbreviations.
// ═══════════════════════════════════════════════════════════════════

// ── Interactive Parameters (prompted at deploy time) ──────────────
@description('Short company or project prefix, e.g. jg or contoso (lowercase, no spaces)')
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

@description('Instance number, e.g. 001')
@minLength(3)
@maxLength(3)
param instance string = '001'

@description('Azure region for all resources')
param location string = resourceGroup().location

// ── Naming Convention Variables (CAF-aligned) ─────────────────────
// Storage accounts: no dashes, max 24 chars, lowercase only
var storageAccountName = toLower('${prefix}${environment}st${instance}')
var functionStorageName = toLower('${prefix}${environment}fst${instance}')

// Dashed names for everything that allows them
var functionAppName   = toLower('${prefix}-${environment}-func-${instance}')
var appServicePlan    = toLower('${prefix}-${environment}-plan-${instance}')

// ── Storage Account ───────────────────────────────────────────────
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

// ── App Service Plan (Consumption) ────────────────────────────────
resource appPlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appServicePlan
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {}
}

// ── Function App ───────────────────────────────────────────────────
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
      ]
    }
  }
}

// ── Outputs — shows the generated names ───────────────────────────
output generatedStorageAccount string = storageAccount.name
output generatedFunctionApp string = functionApp.name
output generatedAppServicePlan string = appPlan.name
output namingExample string = 'All resources named from prefix "${prefix}", environment "${environment}", instance "${instance}"'
