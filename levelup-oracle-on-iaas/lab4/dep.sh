 az group delete --name oragroup --yes
 az group create --resource-group oragroup --location centralindia
 az deployment group create --resource-group oragroup --template-file main.bicep --parameters main.bicepparam