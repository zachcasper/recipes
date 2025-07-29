# Recipes

## `rad recipe register` commands

### Redis

#### Set general environment variables

```bash
export AZURE_SUBSCRIPTION_ID=$(az account show | jq  -r '.id')
export AKS_CLUSTER_NAME=
export AKS_RESOURCE_GROUP_NAME=

export VIRTUAL_NETWORK_RESOURCE_GROUP_NAME=$(az aks show \    
  --resource-group $AKS_RESOURCE_GROUP_NAME \
  --name $AKS_CLUSTER_NAME --query "nodeResourceGroup" -o tsv)

export VIRTUAL_NETWORK_NAME=$(az network vnet list \
  --resource-group $VIRTUAL_NETWORK_RESOURCE_GROUP_NAME \
  --query "[0].name" \
  -o tsv)

export SUBNET_NAME=$(az network vnet subnet list \
  --resource-group $VIRTUAL_NETWORK_RESOURCE_GROUP_NAME \
  --vnet-name $(az network vnet list \
    --resource-group $VIRTUAL_NETWORK_RESOURCE_GROUP_NAME \
    --query "[0].name" -o tsv) \
  --query "[0].name" \
  -o tsv)
```

#### To use the Azure Verified Module version

```bash
rad recipe register  default \
  --resource-type Applications.Datastores/redisCaches \
  --template-kind terraform \
  --template-path git::https://github.com/zachcasper/recipes.git//azure/redis-avm \
  --parameters location=centralus \
  --parameters vnet_id=/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$VIRTUAL_NETWORK_RESOURCE_GROUP_NAME/providers/Microsoft.Network/virtualNetworks/$VIRTUAL_NETWORK_NAME \
  --parameters subnet_id=/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$VIRTUAL_NETWORK_RESOURCE_GROUP_NAME/providers/Microsoft.Network/virtualNetworks/$VIRTUAL_NETWORK_NAME/subnets/$SUBNET_NAME
```

#### To use the the recipe with no modules

Change `recipes.git//azure/redis-avm` to `recipes.git//azure/redis`.