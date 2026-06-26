@description('Deployment suffix for resource names')
param deploySuffix string = '-tsk8s-dev-eastus-001'

@description('Azure region')
param location string = resourceGroup().location

@description('Kubernetes version')
param kubernetesVersion string = '1.34.8'

@description('Node count')
param nodeCount int = 3

@description('VM Size')
param vmSize string = 'Standard_D4s_v5'

@description('VNet CIDR')
param vnetAddressSpace string = '10.0.0.0/16'

@description('AKS Subnet CIDR')
param aksSubnetPrefix string = '10.0.1.0/24'

@description('Node Resource Group')
param nodeResourceGroup string = 'rg-node${deploySuffix}'


// Log Analytics
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'la${deploySuffix}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}


// Public IP for NAT
resource natIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'ip${deploySuffix}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}


// NAT Gateway
resource natGateway 'Microsoft.Network/natGateways@2023-09-01' = {
  name: 'nat-${deploySuffix}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIpAddresses: [
      {
        id: natIp.id
      }
    ]
  }
}


// VNet
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet${deploySuffix}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressSpace
      ]
    }
  }
}


// AKS subnet
resource aksSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  name: '${vnet.name}/aks-subnet'
  properties: {
    addressPrefix: aksSubnetPrefix
    natGateway: {
      id: natGateway.id
    }
  }
}

// Managed Identity
resource aksIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id${deploySuffix}'
  location: location
}


// AKS Cluster
resource aks 'Microsoft.ContainerService/managedClusters@2024-05-01' = {
  name: 'aks${deploySuffix}'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${aksIdentity.id}': {}
    }
  }

  properties: {
    kubernetesVersion: kubernetesVersion

    dnsPrefix: 'aks'

    nodeResourceGroup: nodeResourceGroup

    oidcIssuerProfile: {
      enabled: true
    }

    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }

    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      networkPolicy: 'azure'
      outboundType: 'userAssignedNATGateway'
      podCidr: '172.16.0.0/16'
      serviceCidr: '10.100.0.0/16'
      dnsServiceIP: '10.100.0.10'
    }

    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalytics.id
        }
      }
    }

    agentPoolProfiles: [
      {
        name: 'system'
        count: nodeCount
        vmSize: vmSize
        mode: 'System'
        type: 'VirtualMachineScaleSets'
        osType: 'Linux'
        vnetSubnetID: aksSubnet.id
      }
    ]
  }
}
