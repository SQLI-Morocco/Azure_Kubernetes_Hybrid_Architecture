Kubernetes is the most common open source orchestrator for containerized application, it was developed by Google.
Azure provide the ability to provision fully managed Kubernetes cluster using AKS service , by default AKS exposes Kubernetes API through public IP.

But it’s also possible to protect your cluster and allow access only through private network using clould hybrid architecture and the private end point feature.

In this tutorial we are going to create fully managed private Kubernetes environment, by implementing Hob-spoke network topology in azure.
We are going to define two spoke virtual networks:

1. Spoke 1 : this virtual network will contain Kubernetes cluster virtual network and all the components related to the creation of the K8S cluster.
2. Spoke 2 : this virtual network will contain Azure container registry , to store and pull docker images.

In the Hub virtual network, we are going to provision the Jumpbox and Virtual network gateway to connect the virtual network to the on premises network using secure VPN tunnel.

![image](/AKS_hub_Spoke_Topology.jpg)