@description('VM Name')
param vmName string 

@description('Script Name')
param scriptName string 

@description('Script Content')
param scriptContent string 

@description('The Azure location .')
param location string = resourceGroup().location

// Run the supplied custom script
resource runCustomScript 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  name: '${vmName}/${scriptName}'
  // dependsOn: [deleteExistingExtension]
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    
    typeHandlerVersion: '2.1'
    protectedSettings:{
      script: scriptContent
    }
  }
}
 