targetScope = 'resourceGroup'

@description('Existing APIM service name that will host the HR MCP API.')
param apimName string

@description('APIM API resource name for the HR MCP publication.')
param apiName string = 'hr-mcp-api'

@description('APIM API display name.')
param apiDisplayName string = 'HR MCP Tools'

@description('APIM API path. The MCP endpoint is exposed at /{apiPath}/mcp.')
param apiPath string = 'hr-mcp'

@description('APIM backend resource name for the HR MCP ACA endpoint.')
param backendName string = 'hr-mcp-aca-backend'

@description('Backend base URL for the HR MCP Container App, without a trailing /mcp path.')
param backendBaseUrl string

@description('Deprecated. Host is derived from the APIM backend URL; this parameter is retained for script compatibility.')
param backendHostHeader string = ''

@description('Citadel-style APIM product/access-contract id.')
param productId string = 'MCP-HR-Tools-DEV'

@description('Citadel-style APIM product display name.')
param productDisplayName string = 'MCP HR Tools DEV'

@description('Citadel-style APIM subscription resource name.')
param subscriptionName string = 'MCP-HR-Tools-DEV-SUB-01'

@description('Citadel-style APIM subscription display name.')
param subscriptionDisplayName string = 'MCP HR Tools DEV SUB 01'

@description('Entra tenant id used for JWT validation.')
param tenantId string

@description('Expected JWT audience, for example api://<app-client-id>.')
param jwtAudience string

@description('Required delegated scope claim value in the JWT scp claim, for example Mcp.Access.')
param requiredScope string

@description('Required application role value in the JWT roles claim (for managed-identity callers), for example Mcp.Invoke.')
param requiredRole string = 'Mcp.Invoke'

@description('Transport type for the APIM MCP API.')
param mcpTransportType string = 'streamable'

@description('Set true to require APIM subscription key in addition to JWT.')
param subscriptionRequired bool = true

@description('Product policy XML template. Placeholders are replaced by this template.')
param productPolicyTemplate string = loadTextContent('policies/hr-mcp-product-policy.xml')

@description('API policy XML template. The backend placeholder is replaced by this template.')
param apiPolicyTemplate string = loadTextContent('policies/hr-mcp-api-policy.xml')

var jwtAudienceClientId = last(split(jwtAudience, 'api://'))
var productPolicyXml = replace(replace(replace(replace(replace(productPolicyTemplate, '__TENANT_ID__', tenantId), '__JWT_AUDIENCE__', jwtAudience), '__JWT_AUDIENCE_CLIENT_ID__', jwtAudienceClientId), '__REQUIRED_SCOPE__', requiredScope), '__REQUIRED_ROLE__', requiredRole)
var backendUrlWithoutScheme = last(split(backendBaseUrl, '://'))
var backendUrlHost = first(split(backendUrlWithoutScheme, '/'))
var effectiveBackendHost = empty(backendHostHeader) ? backendUrlHost : backendHostHeader
var apiPolicyXml = replace(replace(apiPolicyTemplate, '__BACKEND_NAME__', backendName), '__BACKEND_HOST__', effectiveBackendHost)

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimName
}

resource backend 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  parent: apim
  name: backendName
  properties: {
    description: 'HR MCP Azure Container Apps backend. Use a private ACA FQDN here when APIM has private network reachability.'
    url: backendBaseUrl
    protocol: 'http'
    credentials: !empty(backendHostHeader) ? {
      header: {
        Host: [
          backendHostHeader
        ]
      }
    } : null
  }
}

resource api 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: apiName
  properties: {
    type: 'mcp'
    displayName: apiDisplayName
    description: 'HR MCP server published through APIM as a Citadel governed MCP API.'
    subscriptionRequired: subscriptionRequired
    path: apiPath
    protocols: [
      'https'
    ]
    // A pass-through MCP API (proxying an existing remote MCP server) must reference the
    // backend via backendId. APIM rejects the API otherwise:
    // "Either BackendId or MCP tools must be set, but not both for MCP API."
    #disable-next-line BCP037
    backendId: backend.name
    #disable-next-line BCP037
    mcpProperties: {
      transportType: mcpTransportType
    }
  }
}

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: api
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: apiPolicyXml
  }
}

resource product 'Microsoft.ApiManagement/service/products@2024-06-01-preview' = {
  parent: apim
  name: productId
  properties: {
    displayName: productDisplayName
    description: 'Citadel-style access contract for the HR MCP tool server.'
    terms: 'Access is limited to approved HR MCP tool consumers with Entra JWT and APIM subscription credentials.'
    subscriptionRequired: true
    approvalRequired: false
    subscriptionsLimit: 10
    state: 'published'
  }
}

resource productApi 'Microsoft.ApiManagement/service/products/apis@2024-06-01-preview' = {
  parent: product
  name: api.name
}

resource productPolicy 'Microsoft.ApiManagement/service/products/policies@2024-06-01-preview' = {
  parent: product
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: productPolicyXml
  }
}

resource subscription 'Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview' = {
  parent: apim
  name: subscriptionName
  properties: {
    displayName: subscriptionDisplayName
    scope: '/products/${product.name}'
    state: 'active'
  }
}

output HR_MCP_APIM_API_NAME string = api.name
output HR_MCP_APIM_PATH string = apiPath
output HR_MCP_APIM_MCP_URL string = '${apim.properties.gatewayUrl}/${apiPath}/mcp'
output HR_MCP_APIM_PRODUCT_ID string = product.name
output HR_MCP_APIM_SUBSCRIPTION_NAME string = subscription.name
output HR_MCP_APIM_BACKEND_NAME string = backend.name
output HR_MCP_APIM_BACKEND_BASE_URL string = backendBaseUrl
