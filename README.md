Kubernetes is the most common open source orchestrator for containerized application, it was developed by Google.
Azure provide the ability to provision fully managed Kubernetes cluster using AKS service , by default AKS exposes Kubernetes API through public IP.

But it’s also possible to protect your cluster and allow access only through private network using clould hybrid architecture and the private end point feature.

In this tutorial we are going to create fully managed private Kubernetes environment, by implementing Hob-spoke network topology in azure.
We are going to define two spoke virtual networks:

1. Spoke 1 : this virtual network will contain Kubernetes cluster virtual network and all the components related to the creation of the K8S cluster.
2. Spoke 2 : this virtual network will contain Azure container registry , to store and pull docker images.

In the Hub virtual network, we are going to provision the Jumpbox and Virtual network gateway to connect the virtual network to the on premises network using secure VPN tunnel.

![image](/AKS_hub_Spoke_Topology.jpg)

First, we are going to start by initializing all parameters that we will need for this tutorial
<br>
```
##Variables declaration
##Spoke 1 : AKS Zone
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
## Spoke 2: ACR Zone
acr_resource_group_name="spoke2-acr-zone"
acr_name="rakataregistry"
acr_vnet_zone_name="acr-vnet"
acr_vnet_zone_prefix="10.22.0.0/16"
acr_subnet_zone_name="acr-subnet"
acr_subnet_zone_prefix="10.22.1.0/24"
acr_private_link="privatelink.azurecr.io"
acr_private_aks_role_reader="acr_private_aks_role_reader"
##HUB : Jump Zone
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
```
<br>
In the next step  we create a resource group and virtual network vent for each zone ( Spoke 1, Spocke 2 and Hub)

<br>
``` bash
## Create spoke 1 AKS VNet and SubNet
az network vnet create \
    --resource-group $aks_resource_group_name \
    --name $aks_vnet_zone_name \
    --address-prefix $aks_vnet_zone_prefix \
    --subnet-name $aks_subnet_zone_name \
    --subnet-prefix $aks_subnet_zone_prefix

## Create spoke 2 ACR VNet and SubNet
az network vnet create \
    --resource-group $acr_resource_group_name \
    --name $acr_vnet_zone_name \
    --address-prefix $acr_vnet_zone_prefix \
    --subnet-name $acr_subnet_zone_name \
    --subnet-prefix $acr_subnet_zone_prefix

## Create hub VNet and SubNet
az network vnet create \
    --resource-group $hub_resource_group_name \
    --name $hub_vnet_zone_name \
    --address-prefix $hub_vnet_zone_prefix \
    --subnet-name $hub_subnet_zone_name \
    --subnet-prefix $hub_subnet_zone_prefix
```
<br>
Now we need to enable the communication between the three vnets :

1. Hub needs to connect to spoke 1 to mange kubernetes cluster using Kubectl command
2. Hub needs to connect to spoke 2 to push images from the Jumbox to ACR
3. Spoke1 needs to connect to Spoke2 to enable AKS to pull images from the ACR during the deployment.

<br>
the script bellow enable the peering between the vnets

<br>
``` bash
### Peering AKS Zone with hub zone
az network vnet peering create \
    --resource-group $aks_resource_group_name \
    --name "${aks_vnet_zone_name}-to-${hub_vnet_zone_name}" \
    --vnet-name $aks_vnet_zone_name \
    --remote-vnet $vnet_hub_id \
    --allow-vnet-access \
    --allow-forwarded-traffic


az network vnet peering create \
    --resource-group $hub_resource_group_name \
    -name "${hub_vnet_zone_name}-to-${aks_vnet_zone_name}" \
    --vnet-name $hub_vnet_zone_name \
    --remote-vnet $vnet_aks_id \
    --allow-vnet-access \
    --allow-forwarded-traffic

### Peering ACR Zone with hub zone
az network vnet peering create \
    --resource-group $acr_resource_group_name \
    --name "${acs_vnet_zone_name}-to-${hub_vnet_zone_name}" \
    --vnet-name $acs_vnet_zone_name \
    --remote-vnet $vnet_hub_id \
    --allow-vnet-access \
    --allow-forwarded-traffic

az network vnet peering create \
    --resource-group $hub_resource_group_name \
    --name "${hub_vnet_zone_name}-to-${acs_vnet_zone_name}" \
    --vnet-name $hub_vnet_zone_name \
    --remote-vnet $vnet_acr_id \
    --allow-vnet-access \
    --allow-forwarded-traffic

### Peering AKS Zone with ACR Zone
az network vnet peering create \
    --resource-group $aks_resource_group_name \
    --name "${aks_vnet_zone_name}-to-${acr_vnet_zone_name}" \
    --vnet-name $aks_vnet_zone_name \
    --remote-vnet $vnet_acr_id \
    --allow-vnet-access \
    --allow-forwarded-traffic

az network vnet peering create \
    --resource-group $acr_resource_group_name \
    --name "${acr_vnet_zone_name}-to-${aks_vnet_zone_name}" \
    --vnet-name $acr_vnet_zone_name \
    --remote-vnet $vnet_aks_id \
    --allow-vnet-access \
    --allow-forwarded-traffic
```