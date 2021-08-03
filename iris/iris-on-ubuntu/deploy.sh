#!/bin/bash 

rg=IRIS-Group

az group delete --name $rg --yes
az group create --name $rg --location "Japan East"

az deployment group create \
  --name ExampleDeployment \
  --resource-group $rg \
  --template-uri "https://raw.githubusercontent.com/IRISMeister/iris-azure-arm/main/iris/iris-on-ubuntu/azuredeploy.json" \
  --parameters @azuredeploy.parameters.json
