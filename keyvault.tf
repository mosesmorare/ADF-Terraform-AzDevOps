# Create Key Vault

# Create Resource Group
resource "azurerm_resource_group" "KV-RG" {
  name     = "KeyVault-RG"
  location = var.resource_group_location
}

resource "azurerm_key_vault" "az-key-v1" {
  name                     = "az-key-v1"
  location                 = azurerm_resource_group.KV-RG.location
  resource_group_name      = azurerm_resource_group.KV-RG.name
  tenant_id                = data.azurerm_client_config.current.tenant_id
  purge_protection_enabled = false

  sku_name = "standard"
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault_access_policy" "current_user" {
  key_vault_id = azurerm_key_vault.az-key-v1.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id


  secret_permissions = [
    "Backup", "Delete", "Get", "List", "Purge", "Recover", "Restore", "Set"
  ]

}


resource "azurerm_key_vault_secret" "SQLPassword" {
  name         = "SQLPassword"
  value        = "YB4E9bvn1A"
  key_vault_id = azurerm_key_vault.az-key-v1.id

  depends_on = [
    azurerm_key_vault_access_policy.current_user
  ]
}


resource "azurerm_key_vault_secret" "ADFConnectionString" {
  name         = "ADFConnectionString"
  value        = "data source=adf-dev-server.database.windows.net;initial catalog=master;user id=adminuser;Password=YB4E9bvn1A;integrated security=False;encrypt=True;connection timeout=30"
  key_vault_id = azurerm_key_vault.az-key-v1.id

  depends_on = [
    azurerm_key_vault_access_policy.current_user
  ]
}