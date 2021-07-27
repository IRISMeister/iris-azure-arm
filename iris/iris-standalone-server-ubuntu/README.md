# iris
[![Deploy To Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FIRISMeister%2Firis-azure-arm%2Fmain%2Firis%2Firis-standalone-server-ubuntu%2Fazuredeploy.json)  

How to deploy via portal. Open this URL in browser.
https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FIRISMeister%2Firis-azure-arm%2Fmain%2Firis%2Firis-standalone-server-ubuntu%2Fazuredeploy.json

- parameters 
adminUsername
 O/S username. any
dnsNamePrefix
 any
SSH public key
To access vm (ubuntu).
WRC username
 To download a iris kit
WRC password
 To download a iris kit
_artifactsLocationSasToken
 leave empty
_secretsLocation
 where iris.key is securely stored
_secretsLocationSasToken
 token to access the above secure location.

iris O/S login
adminUsername@MyubuntuVM:~$ sudo -u irisowner iris session iris

This is where installation files are stored.
cd /var/lib/waagent/custom-script/download/0
root@MyubuntuVM:/var/lib/waagent/custom-script/download/0# ls
IRIS-2021.1.0.215.0-lnxubuntux64.tar.gz  Installer.cls  install_iris.sh  stderr  stdout
