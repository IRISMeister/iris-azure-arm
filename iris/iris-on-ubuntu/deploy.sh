#!/bin/bash 

rg=IRIS-Group

echo "deleting a resource group"
az group delete --name $rg --yes
echo "creating a resource group"
az group create --name $rg --location "Japan East"

az deployment group create \
  --name ExampleDeployment \
  --resource-group $rg \
  --template-uri "https://raw.githubusercontent.com/IRISMeister/iris-azure-arm/main/iris/iris-on-ubuntu/azuredeploy.json" \
  --parameters @azuredeploy.parameters.json

az vm list-ip-addresses --resource-group $rg --output table
az network lb list --resource-group $rg --output table
az network nat gateway list --resource-group $rg --output table
az network public-ip list --resource-group $rg --output table
