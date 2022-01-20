resource "azurerm_resource_group" "azure_portal_sso" {
  name     = "AzurePortalSSO-RG"
  location = "Korea Central"
  tags = var.tags
}

resource "azurerm_kubernetes_cluster" "azure_portal_sso_aks" {
  name                = "azure_portal_sso-aks"
  location            = azurerm_resource_group.azure_portal_sso.location
  resource_group_name = azurerm_resource_group.azure_portal_sso.name
  dns_prefix          = "azureportalsso-aks"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_B2s"
  }

  identity {
    type = "SystemAssigned"
  }
  tags = var.tags
}
