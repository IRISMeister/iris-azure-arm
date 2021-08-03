#!/bin/bash 

az group create --name ExampleGroup --location "Japan East"

az deployment group create \
  --name ExampleDeployment \
  --resource-group ExampleGroup \
  --template-uri "https://raw.githubusercontent.com/IRISMeister/iris-azure-arm/main/iris/iris-on-ubuntu/azuredeploy.json" \
  --parameters @azuredeploy.parameters.json
