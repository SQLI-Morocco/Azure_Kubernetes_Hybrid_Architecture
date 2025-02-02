##!/usr/bin/env bash
set -e

##Variables declaration
##Spoke 1 : AKS Zone
location="eastus"
aks_resource_group_name="spoke1-aks-zone"
cluster_name="rakata-aks"
cluster_node_size="Standard_B2s"
cluster_node_count="1"
node_disk_size="30"
aks_vnet_zone_name="AKS-vnet"
aks_vnet_zone_prefix="10.20.0.0/16"
aks_subnet_zone_name="AKS-subnet"
aks_subnet_zone_prefix="10.20.1.0/24"
## Spoke 2: ACR Zone
acr_resource_group_name="spoke2-acr-zone"
acr_name="rakataregistry"
acr_vnet_zone_name="acr-vnet"
acr_vnet_zone_prefix="10.22.0.0/16"
acr_subnet_zone_name="acr-subnet"
acr_subnet_zone_prefix="10.22.1.0/24"
acr_private_link="privatelink.azurecr.io"
acr_private_aks_role_reader="acr_private_aks_role_reader"

##HUB : Jump Zone
hub_resource_group_name="cloud-hub-zone"
hub_vnet_zone_name="hub-vnet"
hub_vnet_zone_prefix="10.21.0.0/16"
hub_subnet_zone_name="hub-subnet"
hub_subnet_zone_prefix="10.21.1.0/24"
hub_jumpbox_public_ip_address="jumpboxIP"
hub_jumpbox_name="JumpBox"

hub_gateway_subnet_prefix="10.21.255.0/27"
hub_gateway_subnet_name="GatewaySubnet"
hub_gateway_public_ip="VNet1GWIP"
hub_gateway_name="hub_vpn_gateway"

## Create resources groups

az group create --name $aks_resource_group_name --location $location
az group create --name $acr_resource_group_name --location $location
az group create --name $hub_resource_group_name --location $location

## Create spoke 1 AKS VNet and SubNet
az network vnet create \
    --resource-group $aks_resource_group_name \
    --name $aks_vnet_zone_name \
    --address-prefix $aks_vnet_zone_prefix \
    --subnet-name $aks_subnet_zone_name \
    --subnet-prefix $aks_subnet_zone_prefix

## Create spoke 2 ACR VNet and SubNet
az network vnet create \
    --resource-group $acr_resource_group_name \
    --name $acr_vnet_zone_name \
    --address-prefix $acr_vnet_zone_prefix \
    --subnet-name $acr_subnet_zone_name \
    --subnet-prefix $acr_subnet_zone_prefix

## Create hub VNet and SubNet
az network vnet create \
    --resource-group $hub_resource_group_name \
    --name $hub_vnet_zone_name \
    --address-prefix $hub_vnet_zone_prefix \
    --subnet-name $hub_subnet_zone_name \
    --subnet-prefix $hub_subnet_zone_prefix

## Create zone Peering 
vnet_aks_id=$(az network vnet show \
    --resource-group $aks_resource_group_name \
    --name $aks_vnet_zone_name \
    --query id -o tsv)
echo $vnet_aks_id

vnet_hub_id=$(az network vnet show \
    --resource-group $hub_resource_group_name \
    --name $hub_vnet_zone_name \
    --query id -o tsv)
echo $vnet_hub_id

vnet_acr_id=$(az network vnet show \
    --resource-group $acr_resource_group_name \
    --name $acr_vnet_zone_name \
    --query id -o tsv)
echo $vnet_acr_id

### Peering AKS Zone with hub zone
az network vnet peering create \
    --resource-group $aks_resource_group_name \
    --name "${aks_vnet_zone_name}-to-${hub_vnet_zone_name}" \
    --vnet-name $aks_vnet_zone_name \
    --remote-vnet $vnet_hub_id \
    --allow-vnet-access \
    --allow-forwarded-traffic  


az network vnet peering create \
    --resource-group $hub_resource_group_name \
    -name "${hub_vnet_zone_name}-to-${aks_vnet_zone_name}" \
    --vnet-name $hub_vnet_zone_name \
    --remote-vnet $vnet_aks_id \
    --allow-vnet-access \
    --allow-forwarded-traffic

### Peering ACR Zone with hub zone
az network vnet peering create \
    --resource-group $acr_resource_group_name \
    --name "${acs_vnet_zone_name}-to-${hub_vnet_zone_name}" \
    --vnet-name $acs_vnet_zone_name \
    --remote-vnet $vnet_hub_id \
    --allow-vnet-access \
    --allow-forwarded-traffic

az network vnet peering create \
    --resource-group $hub_resource_group_name \
    --name "${hub_vnet_zone_name}-to-${acs_vnet_zone_name}" \
    --vnet-name $hub_vnet_zone_name \
    --remote-vnet $vnet_acr_id \
    --allow-vnet-access \
    --allow-forwarded-traffic

### Peering AKS Zone with ACR Zone
az network vnet peering create \
    --resource-group $aks_resource_group_name \
    --name "${aks_vnet_zone_name}-to-${acr_vnet_zone_name}" \
    --vnet-name $aks_vnet_zone_name \
    --remote-vnet $vnet_acr_id \
    --allow-vnet-access \
    --allow-forwarded-traffic

az network vnet peering create \
    --resource-group $acr_resource_group_name \
    --name "${acr_vnet_zone_name}-to-${aks_vnet_zone_name}" \
    --vnet-name $acr_vnet_zone_name \
    --remote-vnet $vnet_aks_id \
    --allow-vnet-access \
    --allow-forwarded-traffic
## Create AKS Private cluster
aks_subnet_zone_id=$(az network vnet subnet show --name $aks_subnet_zone_name \
                            --vnet-name $aks_vnet_zone_name \
                            --resource-group $aks_resource_group_name \
                            --query id --output tsv)
 
## Get the latest AKS version available in the curent location
AKS_VERSION=$(az aks get-versions --location $location \
            --query "orchestrators[?to_string(isPreview)=='null'] | [-1].orchestratorVersion" \
            --output tsv)
echo $AKS_VERSION

az aks create --resource-group $aks_resource_group_name \
              --name $cluster_name \
              --kubernetes-version $AKS_VERSION \
              --location $location \
              --enable-private-cluster \
              --node-vm-size $cluster_node_size \
              --load-balancer-sku standard \
              --node-count $cluster_node_count \
              --node-osdisk-size $node_disk_size \
              --network-plugin kubenet \
              --vnet-subnet-id $aks_subnet_zone_id \
              --docker-bridge-address 172.17.0.1/16 \
              --dns-service-ip 10.30.0.10 \
              --service-cidr 10.30.0.0/16 

## Create the jumbox VM
az network public-ip create \
    --resource-group $hub_resource_group_name \
    --name $hub_jumpbox_public_ip_address \
    --allocation-method dynamic \
    --sku basic

az vm create --name $hub_jumpbox_name  \
             --resource-group $hub_resource_group_name \
             --image UbuntuLTS \
             --location $location \
             --size Standard_A1_v2 \
             --authentication-type ssh \
             --ssh-key-values ~/.ssh/id_rsa.pub \
             --admin-username jumboxadmin  \
             --vnet-name $hub_vnet_zone_name \
             --subnet $hub_subnet_zone_name \
             --public-ip-address $hub_jumpbox_public_ip_address 

jumpbox_vm_public_ip=$(az vm  show -d --name $hub_jumpbox_name \
             --resource-group $hub_resource_group_name \
             --query publicIps -o tsv)

## Link hub vnet to AKS private dns zone
node_resource_group=$(az aks show --name $cluster_name \
    --resource-group $aks_resource_group_name \
    --query 'nodeResourceGroup' -o tsv) 

echo $node_resource_group

dnszone=$(az network private-dns zone list \
    --resource-group $node_resource_group \
    --query [0].name -o tsv)

echo $dnszone
echo "${hub_vnet_zone_name}-${hub_resource_group_name}"

az network private-dns link vnet create \
    --name "${hub_vnet_zone_name}-${hub_resource_group_name}" \
    --resource-group $node_resource_group \
    --virtual-network $vnet_hub_id \
    --zone-name $dnszone \
    --registration-enabled false

## Create ACR with premium SKU , only premium SKU support private link
az acr create \
  --name $acr_name \
  --resource-group $acr_resource_group_name \
  --sku Premium

REGISTRY_ID=$(az acr show --name $acr_name \
  --query 'id' --output tsv)

REGISTRY_LOGIN_SERVER=$(az acr show --name $acr_name \
  --query 'loginServer' --output tsv)

echo $REGISTRY_ID
echo $REGISTRY_LOGIN_SERVER
##disable subunet private endpoit policies
az network vnet subnet update \
 --name  $acr_subnet_zone_name \
 --vnet-name $acr_vnet_zone_name \
 --resource-group $acr_resource_group_name \
 --disable-private-endpoint-network-policies

 
##Create acr private endpoint
az network private-endpoint create \
    --name "${acr_name}-${acr_resource_group_name}" \
    --resource-group $acr_resource_group_name \
    --vnet-name $acr_vnet_zone_name \
    --subnet $acr_subnet_zone_name \
    --private-connection-resource-id $REGISTRY_ID \
    --group-ids registry \
    --connection-name "${acr_name}-${acr_resource_group_name}-cnx"

##create private dns zone with the same name as acr registry
 az network private-dns zone create \
  --resource-group $acr_resource_group_name \
  --name $acr_private_link

##Get acr endpoint and data acr endpoint ip private addresses
acr_private_network_id=$(az network private-endpoint show \
  --name "${acr_name}-${acr_resource_group_name}" \
  --resource-group $acr_resource_group_name \
  --query 'networkInterfaces[0].id' \
  --output tsv)

acr_private_ip=$(az resource show \
  --ids $acr_private_network_id \
  --query 'properties.ipConfigurations[1].properties.privateIPAddress' \
  --output tsv)

data_acr_private_ip=$(az resource show \
  --ids $acr_private_network_id \
  --query 'properties.ipConfigurations[0].properties.privateIPAddress' \
  --output tsv)

echo $acr_private_ip
echo $data_acr_private_ip

##create A records in the private dns zone 
az network private-dns record-set a create \
  --name $acr_name \
  --zone-name $acr_private_link \
  --resource-group $acr_resource_group_name

az network private-dns record-set a create \
  --name ${acr_name}.${location}.data \
  --zone-name $acr_private_link \
  --resource-group $acr_resource_group_name

az network private-dns record-set a add-record \
  --record-set-name $acr_name \
  --zone-name $acr_private_link \
  --resource-group $acr_resource_group_name \
  --ipv4-address $acr_private_ip

az network private-dns record-set a add-record \
  --record-set-name ${acr_name}.${location}.data \
  --zone-name $acr_private_link \
  --resource-group $acr_resource_group_name \
  --ipv4-address $data_acr_private_ip

##Disable public access 
echo $acr_name
az acr update --name $acr_name --default-action Deny

## Link jumpbox network to acr private dns zone
az network private-dns link vnet create \
    --name "${hub_vnet_zone_name}-${hub_resource_group_name}" \
    --resource-group $acr_resource_group_name \
    --virtual-network $vnet_hub_id \
    --zone-name $acr_private_link \
    --registration-enabled false

## Link AKS private network to acr private dns zone
az network private-dns link vnet create \
    --name "${aks_vnet_zone_name}-${aks_resource_group_name}" \
    --resource-group $acr_resource_group_name \
    --virtual-network $vnet_aks_id \
    --zone-name $acr_private_link \
    --registration-enabled false

## Grant access to AKS to pull images from acr

acr_aks_role_password=$(az ad sp create-for-rbac \
             --name $acr_private_aks_role_reader  --query password -o tsv )
acr_aks_role_id=$(az ad sp list --show-mine \
            --query "[?displayName=='${acr_private_aks_role_reader}'].appId | [0]" \
            --output tsv)

az role assignment create --assignee  $acr_aks_role_id --scope $REGISTRY_ID --role Reader
echo $acr_aks_role_password

aks_resource_group_name="spoke1-aks-zone"
cluster_name="rakata-aks"

az aks update-credentials --resource-group $aks_resource_group_name \
                          --name $cluster_name \
                          --reset-service-principal \
                          --service-principal $acr_aks_role_id \
                          --client-secret $acr_aks_role_password

#az aks browse --resource-group myResourceGroup --name myAKSCluster

## Provision network VPN GateWay in Cloud hun vnet
az network vnet subnet create --name $hub_gateway_subnet_name \
            --resource-group $hub_resource_group_name \
            --vnet-name $hub_vnet_zone_name  \
            --address-prefixes $hub_gateway_subnet_prefix

az network public-ip create --name $hub_gateway_public_ip \
                            --resource-group $hub_resource_group_name \
                            --allocation-method Dynamic

az network vnet-gateway create \
            --name $hub_gateway_name \
            --location $location \
            --resource-group $hub_resource_group_name \
            --public-ip-address $hub_gateway_public_ip \
            --vnet $hub_vnet_zone_name \
            --gateway-type Vpn \
            --sku  VpnGw1 \
            --vpn-type RouteBased \
            --no-wait

az network vnet-gateway show \
            --name $hub_gateway_name \
            --resource-group $hub_resource_group_name \
            --query provisioningState \
            --output tsv

# Create P2S VPN
## Generate CA certificate
### Install tools to generate CA Certificate and client certificate
sudo apt-get install strongswan -y
sudo apt-get install strongswan-pki -y
sudo apt-get  install libstrongswan-extra-plugins -y
### End Installing tools
ipsec pki --gen --outform pem > caKey.pem
ipsec pki --self --in caKey.pem --dn "CN=P2SRootCert" \
        --ca --outform pem > caCert.pem
openssl x509 -in caCert.pem -outform der | base64 -w0  > caCert.cer
#Create client certificate
PASSWORD="pass@word"
USERNAME="azureuser"

ipsec pki --gen --outform pem > "${USERNAME}Key.pem"
ipsec pki --pub --in "${USERNAME}Key.pem" | ipsec pki \
          --issue --cacert caCert.pem --cakey caKey.pem \
          --dn "CN=${USERNAME}" --san "${USERNAME}" \
          --flag clientAuth --outform pem > "${USERNAME}Cert.pem"

openssl pkcs12 -in "${USERNAME}Cert.pem" \
              -inkey "${USERNAME}Key.pem" \
              -certfile caCert.pem \
              -export -out "${USERNAME}.p12" \
              -password "pass:${PASSWORD}"

#
az network vnet-gateway update \
                --name $hub_gateway_name \
                --resource-group $hub_resource_group_name \
                --client-protocol SSTP \
                --address-prefixes 172.16.1.0/24

az network vnet-gateway root-cert create \
                --resource-group $hub_resource_group_name \
                --name P2SRootCert \
                --gateway-name $hub_gateway_name \
                --public-cert-data caCert.cer

az network vnet-gateway vpn-client generate \
            --name $hub_gateway_name \
            --resource-group $hub_resource_group_name \
            --processor-architecture Amd64