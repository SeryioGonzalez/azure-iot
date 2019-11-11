#!/bin/bash

source config.sh

echo ""

log "Creating RG $resourceGroup in $region"
az group create --name $resourceGroup --location $region > /dev/null

log "Creating storage account for messages"
az storage account create --name $groupId --resource-group $resourceGroup --https-only true --kind StorageV2 --sku Standard_GRS > /dev/null

log "Creating storage container for messages"
az storage container create --name $messageStorageContainerName --account-name $groupId --public-access container --output none > /dev/null

STORAGE_CONNECTION_STRING=$(az storage account show-connection-string --name $groupId --query connectionString -o tsv)

log "Deploying IoT Hub"
az group deployment create --no-wait --resource-group $resourceGroup --name "iot-hub" --template-file "iot-hub-deploy.json" \
	--parameters iot-hub-name=$groupId \
	--parameters storageAccountContainer=$messageStorageContainerName \
	--parameters storageAccountConnectionString=$STORAGE_CONNECTION_STRING

log "Deploying client VM"
az group deployment create --no-wait --resource-group $resourceGroup --name "client"  --template-file "clientdeploy.json" \
	--parameters environmentName=$clientEnvironment \
	--parameters adminUsername=$vmUser \
	--parameters adminUserPassword=$vmUserPassword \
	--parameters hostnameDNS=$groupId

log "Waiting for IoT Hub creation completion"
az group deployment wait --resource-group $resourceGroup --name "iot-hub" --created

log "Creating IoT device"	
az iot hub device-identity create --device-id $deviceId --hub-name $groupId > /dev/null

##OUTPUT
log "Device Connection String"
az iot hub device-identity show-connection-string --device-id $deviceId --hub-name $groupId -o tsv

CLIENT_PUBLIC_IP=$(az network public-ip list -g $resourceGroup --query "[0].ipAddress" -o tsv)
CLIENT_USERNAME=$(az vm show -g $resourceGroup -n $clientEnvironment"-vm" --query "osProfile.adminUsername" -o tsv)
log "Connect to client in: "
echo "ssh -o 'StrictHostKeyChecking no' $CLIENT_USERNAME@$CLIENT_PUBLIC_IP"
