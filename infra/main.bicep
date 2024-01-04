targetScope = 'subscription'

@description('Id of the user or app to assign application roles')
param principalId string

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('The email address of the owner of the service')
@minLength(1)
param publisherEmail string

@description('The name of the owner of the service')
@minLength(1)
param publisherName string

@description('The IP address of the client making the request')
@minLength(1)
param sourceIpAddress string = '10.10.10.10'

@description('whether to create a private deployment private-> true | public -> false')
param private bool = false

param resourceGroupName string = ''

// api
param apiManagementName string = ''

// appservice
param appServicePlanName string = ''
param backendServiceName string = ''

// search
param searchServicesName string = ''
param searchServiceResourceGroupName string = ''
param searchServicesSkuName string = 'standard'
param searchServiceResourceGroupLocation string = location
param searchIndexName string = 'gptkbindex'

// storage
param storageAccountName string = ''
param storageResourceGroupName string = ''
param storageResourceGroupLocation string = location
param storageContainerName string = 'content'


// openai
param openAiServiceName string = ''
param openAiResourceGroupName string = ''
@description('Location for the OpenAI resource group')
// @allowed(['eastus', 'southcentralus', 'westeurope'])
@metadata({
  azd: {
    type: 'location'
  }
})
param openAiResourceGroupLocation string
param openAiSkuName string = 'S0'

// param cognitiveServicesAccountName string = ''
// param cognitiveServicesSkuName string = 'S0'

param gptDeploymentName string = 'davinci'
param gptDeploymentCapacity int = 10
param gptModelName string = 'gpt-4'
param chatGptDeploymentName string = 'chat'
param chatGptDeploymentCapacity int = 10
param chatGptModelName string = 'gpt-4'
param embeddingDeploymentName string = 'embedding'
param embeddingDeploymentCapacity int = 30
param embeddingModelName string = 'text-embedding-ada-002'

// formrecognizer
param formRecognizerServiceName string = ''
param formRecognizerResourceGroupName string = ''
param formRecognizerResourceGroupLocation string = location
param formRecognizerSkuName string = 'S0'


var abbrs = loadJsonContent('abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// Organize resources in a resource group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${environmentName}'
  location: location
  tags: tags
}

resource openAiResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = if (!empty(openAiResourceGroupName)) {
  name: !empty(openAiResourceGroupName) ? openAiResourceGroupName : resourceGroup.name
}

resource formRecognizerResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = if (!empty(formRecognizerResourceGroupName)) {
  name: !empty(formRecognizerResourceGroupName) ? formRecognizerResourceGroupName : resourceGroup.name
}

resource searchServiceResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = if (!empty(searchServiceResourceGroupName)) {
  name: !empty(searchServiceResourceGroupName) ? searchServiceResourceGroupName : resourceGroup.name
}

resource storageResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = if (!empty(storageResourceGroupName)) {
  name: !empty(storageResourceGroupName) ? storageResourceGroupName : resourceGroup.name
}


// Create an API Managament
module apimanagement 'core/api/apimanagement.bicep' = {
  name: 'apimanagement'
  scope: resourceGroup
  params: {
    name: !empty(apiManagementName) ? apiManagementName : '${abbrs.apiManagementService}${resourceToken}'
    publisherEmail: publisherEmail
    publisherName: publisherName
    location: location
    tags: tags
    // private environment
    private: private
    apimsubnetId: ( private ) ? vnet.outputs.apimSubnetId : ''
    publicIpAddressId: ( private ) ? publicIp.outputs.pipId : ''
  }
}

// Create an App Service Plan to group applications under the same payment plan and SKU
module appServicePlan 'core/host/appserviceplan.bicep' = {
  name: 'appserviceplan'
  scope: resourceGroup
  params: {
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: 'B1'
      capacity: 1
    }
    kind: 'linux'
  }
}

// create a Web Apps for backend for backend apps
module backend 'core/host/appservice.bicep' = {
  name: 'web'
  scope: resourceGroup
  params: {
    name: !empty(backendServiceName) ? backendServiceName : '${abbrs.webSitesAppService}backend-${resourceToken}'
    location: location
    tags: union(tags, { 'azd-service-name': 'backend' })
    appServicePlanId: appServicePlan.outputs.id
    runtimeName: 'python'
    runtimeVersion: '3.10'
    appCommandLine: 'python3 -m gunicorn "app:create_app()"'
    scmDoBuildDuringDeployment: true
    managedIdentity: true
    appSettings: {
      AZURE_STORAGE_ACCOUNT: storage.outputs.name
      AZURE_STORAGE_CONTAINER: storageContainerName
      AZURE_OPENAI_SERVICE: openAi.outputs.name
      AZURE_SEARCH_INDEX: searchIndexName
      AZURE_SEARCH_SERVICE: searchService.outputs.name
      AZURE_OPENAI_GPT_DEPLOYMENT: gptDeploymentName
      AZURE_OPENAI_CHATGPT_DEPLOYMENT: chatGptDeploymentName
      AZURE_OPENAI_EMB_DEPLOYMENT: embeddingDeploymentName
    }
    // vnet integration for private environment
    private: private
    subnetId: ( private ) ? vnet.outputs.appSubnetId : ''
    sourceIpAddress: ( private) ? sourceIpAddress : ''
  }
}

module openAi 'core/ai/cognitiveservices.bicep' = {
  scope: openAiResourceGroup
  name: 'openai'
  params: {
    name: !empty(openAiServiceName) ? openAiServiceName : '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    location: openAiResourceGroupLocation
    tags: tags
    sku: {
      name: openAiSkuName
    }
    deployments: [
      {
        name: gptDeploymentName
        model: {
          format: 'OpenAI'
          name: gptModelName
          version: '0613'
        }
        capacity: gptDeploymentCapacity
      }
      {
        name: chatGptDeploymentName
        model: {
          format: 'OpenAI'
          name: chatGptModelName
          version: '0613'
        }
        capacity: chatGptDeploymentCapacity
      }
      {
        name: embeddingDeploymentName
        model: {
          format: 'OpenAI'
          name: embeddingModelName
          version: '2'
        }
        capacity: embeddingDeploymentCapacity
      }
    ]
    // for private environment
    private: private
    sourceIpAddress: ( private) ? sourceIpAddress : ''
  }
}

module formRecognizer 'core/ai/cognitiveservices.bicep' = {
  name: 'formrecognizer'
  scope: formRecognizerResourceGroup
  params: {
    name: !empty(formRecognizerServiceName) ? formRecognizerServiceName : '${abbrs.cognitiveServicesFormRecognizer}${resourceToken}'
    kind: 'FormRecognizer'
    location: formRecognizerResourceGroupLocation
    tags: tags
    sku: {
      name: formRecognizerSkuName
    }
  }
}


module searchService 'core/search/search-services.bicep' = {
  scope: searchServiceResourceGroup
  name: 'search-services'
  params: {
    name: !empty(searchServicesName) ? searchServicesName : 'gptkb-${resourceToken}'
    location: searchServiceResourceGroupLocation
    tags: tags
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
    sku: {
      name: searchServicesSkuName
    }
    semanticSearch: 'free'
    // for private environment
    private: private
    sourceIpAddress:  ( private) ? sourceIpAddress : ''
  }
}

module storage 'core/storage/storage-account.bicep' = {
  name: 'storage'
  scope: storageResourceGroup
  params: {
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
    location: storageResourceGroupLocation
    tags: tags
    sku: {
      name: 'Standard_ZRS'
    }
    deleteRetentionPolicy: {
      enabled: true
      days: 2
    }
    containers: [
      {
        name: 'content'
        publicAccess: 'None'
      }
    ]
    // for private environment
    private: private
    sourceIpAddress:  ( private) ? sourceIpAddress : ''
  }
}

// USER ROLES
module openAiRoleUser 'core/security/role.bicep' = {
  scope: openAiResourceGroup
  name: 'openai-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
    principalType: 'User'
  }
}

module formRecognizerRoleUser 'core/security/role.bicep' = {
  scope: formRecognizerResourceGroup
  name: 'formrecognizer-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: 'a97b65f3-24c7-4388-baec-2e87135dc908'
    principalType: 'User'
  }
}

module storageRoleUser 'core/security/role.bicep' = {
  scope: storageResourceGroup
  name: 'storage-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
    principalType: 'User'
  }
}

module storageContribRoleUser 'core/security/role.bicep' = {
  scope: storageResourceGroup
  name: 'storage-contribrole-user'
  params: {
    principalId: principalId
    roleDefinitionId: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
    principalType: 'User'
  }
}

module searchRoleUser 'core/security/role.bicep' = {
  scope: searchServiceResourceGroup
  name: 'search-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: '1407120a-92aa-4202-b7e9-c0e197c71c8f'
    principalType: 'User'
  }
}

module searchContribRoleUser 'core/security/role.bicep' = {
  scope: searchServiceResourceGroup
  name: 'search-contrib-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
    principalType: 'User'
  }
}

module searchSvcContribRoleUser 'core/security/role.bicep' = {
  scope: searchServiceResourceGroup
  name: 'search-svccontrib-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
    principalType: 'User'
  }
}

// SYSTEM IDENTITIES
module openAiRoleBackend 'core/security/role.bicep' = {
  scope: openAiResourceGroup
  name: 'openai-role-backend'
  params: {
    principalId: backend.outputs.identityPrincipalId
    roleDefinitionId: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
    principalType: 'ServicePrincipal'
  }
}

module storageRoleBackend 'core/security/role.bicep' = {
  scope: storageResourceGroup
  name: 'storage-role-backend'
  params: {
    principalId: backend.outputs.identityPrincipalId
    roleDefinitionId: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
    principalType: 'ServicePrincipal'
  }
}

module searchRoleBackend 'core/security/role.bicep' = {
  scope: searchServiceResourceGroup
  name: 'search-role-backend'
  params: {
    principalId: backend.outputs.identityPrincipalId
    roleDefinitionId: '1407120a-92aa-4202-b7e9-c0e197c71c8f'
    principalType: 'ServicePrincipal'
  }
}

// Vnet for private environment
param vnetName string = 'vnet'
param peSubnetName string = 'privateEndpointSubnet'
param appSubnetName string = 'appServiceSubnet'
param apimSubnetName string = 'apimServiceSubnet'
param vnetAddressPrefix string = '10.0.0.0/16'
param peSubnetAddressPrefix string = '10.0.1.0/24'
param appSubnetAddressPrefix string = '10.0.2.0/24'
param apimSubnetAddressPrefix string = '10.0.3.0/24'

module vnet 'core/network/vnet.bicep' = if ( private ) {
  scope: resourceGroup
  name: vnetName
  params: {
    vnetName: vnetName
    location: location
    tags: tags
    vnetAddressPrefix: vnetAddressPrefix
    peSubnetAddressPrefix: peSubnetAddressPrefix
    appSubnetAddressPrefix: appSubnetAddressPrefix
    apimSubnetAddressPrefix: apimSubnetAddressPrefix
    peSubnetName: peSubnetName
    appSubnetName: appSubnetName
    apimSubnetName: apimSubnetName
    apimNSGId: (private) ? apimnsg.outputs.nsgId : ''
  }
}

// for private environment used by API Management
module publicIp 'core/network/publicip.bicep' = if ( private ) {
  scope: resourceGroup
  name: 'apimPublicIp'
  params: {
    publicIpName: '${abbrs.networkPublicIPAddresses}${resourceToken}'
    location: location
    tags: tags
  }
}

// Private Endpoint for app service
module appServicePrivateEndpoint 'core/network/private-endpoint.bicep' = if ( private ) {
  scope: resourceGroup
  name: 'appServicePrivateEndpoint'
  params: {
    privateDnsZoneName: 'privatelink.azurewebsites.net'
    location: location
    tags: tags
    vnetId: (private) ? vnet.outputs.vnetId : ''
    subnetId: (private) ? vnet.outputs.subnetId : ''
    privateEndpointName: 'pe-appservice'
    privateLinkServiceId: backend.outputs.id
    privateLinkServicegroupId: 'sites'
  }
}

// Private Endpoint for search service
module searchPrivateEndpoint 'core/network/private-endpoint.bicep' = if ( private ) {
  scope: resourceGroup
  name: 'searchPrivateEndpoint'
  params: {
    privateDnsZoneName: 'privatelink.search.windows.net'
    location: location
    tags: tags
    vnetId: (private) ? vnet.outputs.vnetId : ''
    subnetId: (private) ? vnet.outputs.subnetId : ''
    privateEndpointName: 'pe-searchservice'
    privateLinkServiceId: searchService.outputs.id
    privateLinkServicegroupId: 'searchService'
  }
}

// Private Endpoint for storage
module storagePrivateEndpoint 'core/network/private-endpoint.bicep' = if ( private ) {
  scope: resourceGroup
  name: 'storagePrivateEndpoint'
  params: {
    privateDnsZoneName: 'privatelink.blob.core.windows.net'
    location: location
    tags: tags
    vnetId: (private) ? vnet.outputs.vnetId : ''
    subnetId: (private) ? vnet.outputs.subnetId : ''
    privateEndpointName: 'pe-blob'
    privateLinkServiceId: storage.outputs.id 
    privateLinkServicegroupId: 'BLOB'
  }
}

// Private Endpoint for openai service
module openaiPrivateEndpoint 'core/network/private-endpoint.bicep' = if ( private ) {
  scope: resourceGroup
  name: 'openaiPrivateEndpoint'
  params: {
    privateDnsZoneName: 'privatelink.openai.azure.com'
    location: location
    tags: tags
    vnetId: (private) ? vnet.outputs.vnetId : ''
    subnetId: (private) ? vnet.outputs.subnetId : ''
    privateEndpointName: 'pe-openai'
    privateLinkServiceId: openAi.outputs.id
    privateLinkServicegroupId: 'account'
  }
}

// NSG rules for API Management subnet
// refer https://learn.microsoft.com/ja-jp/azure/api-management/api-management-using-with-vnet?tabs=stv2#configure-nsg-rules

param apimNSG array = [
  {
    name: 'AllowClientInBound'
    properties: {
      description: 'AllowClientInBound'
      protocol: 'TCP'
      sourcePortRange: '*'
      destinationPortRanges: ['80','443']
      sourceAddressPrefix: 'Internet'
      destinationAddressPrefix: 'VirtualNetwork'
      access: 'Allow'
      priority: 1000
      direction: 'Inbound'
    }
  }
  {
    name: 'AllowManagementInBound'
    properties: {
      description: 'AllowManagementInBound'
      protocol: 'TCP'
      sourcePortRange: '*'
      destinationPortRange: '3443'
      sourceAddressPrefix: 'ApiManagement'
      destinationAddressPrefix: 'VirtualNetwork'
      access: 'Allow'
      priority: 1001
      direction: 'Inbound'
    }
  }
  {
    name: 'AllowLBInbound'
    properties: {
      description: 'AllowLBInbound'
      protocol: 'TCP'
      sourcePortRange: '*'
      destinationPortRange: '6390'
      sourceAddressPrefix: 'AzureLoadBalancer'
      destinationAddressPrefix: 'VirtualNetwork'
      access: 'Allow'
      priority: 1002
      direction: 'Inbound'
    }
  }
  {
    name: 'AllowStroageOutbound'
    properties: {
      description: 'AllowStroageOutbound'
      protocol: 'TCP'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: 'Storage'
      access: 'Allow'
      priority: 1003
      direction: 'Outbound'
    }
  }
  {
    name: 'AllowSQLOutbound'
    properties: {
      description: 'AllowSQLOutbound'
      protocol: 'TCP'
      sourcePortRange: '*'
      destinationPortRange: '1443'
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: 'SQL'
      access: 'Allow'
      priority: 1004
      direction: 'Outbound'
    }
  }
  {
    name: 'AllowKVOutbound'
    properties: {
      protocol: 'TCP'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: 'AzureKeyVault'
      access: 'Allow'
      priority: 1005
      direction: 'Outbound'
    }
  }
]

// NSG for API Management subnet
module apimnsg 'core/network/nsg.bicep' = if ( private ) {
  scope: resourceGroup
  name: 'NSG_apim'
  params: {
    nsgName: 'NSG_apim'
    location: location
    tags: tags
    securityRules: apimNSG
  }
}

output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = resourceGroup.name

output AZURE_OPENAI_SERVICE string = openAi.outputs.name
output AZURE_OPENAI_RESOURCE_GROUP string = openAiResourceGroup.name
output AZURE_OPENAI_GPT_DEPLOYMENT string = gptDeploymentName
output AZURE_OPENAI_CHATGPT_DEPLOYMENT string = chatGptDeploymentName
output AZURE_OPENAI_EMB_DEPLOYMENT string = embeddingDeploymentName

output AZURE_FORMRECOGNIZER_SERVICE string = formRecognizer.outputs.name
output AZURE_FORMRECOGNIZER_RESOURCE_GROUP string = formRecognizerResourceGroup.name

output AZURE_SEARCH_INDEX string = searchIndexName
output AZURE_SEARCH_SERVICE string = searchService.outputs.name
output AZURE_SEARCH_SERVICE_RESOURCE_GROUP string = searchServiceResourceGroup.name

output AZURE_STORAGE_ACCOUNT string = storage.outputs.name
output AZURE_STORAGE_CONTAINER string = storageContainerName
output AZURE_STORAGE_RESOURCE_GROUP string = storageResourceGroup.name

output BACKEND_URI string = backend.outputs.uri
