resource "random_string" "prefix" {
  length  = 8
  upper   = false
  special = false
}


# Create Resource Group
resource "azurerm_resource_group" "adf_rg" {
  name     = var.resource_group_name
  location = var.resource_group_location
}

#Create Storage Account & Container
resource "azurerm_storage_account" "adf_stg" {
  name                     = "adfstgdev123"
  resource_group_name      = azurerm_resource_group.adf_rg.name
  location                 = azurerm_resource_group.adf_rg.location
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  is_hns_enabled           = "true"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "adf_cont" {
  name                  = "data"
  storage_account_name  = azurerm_storage_account.adf_stg.name
  container_access_type = "private"
}


# Create SQL Database & SQL Server

resource "azurerm_mssql_server" "adf_sql_srv" {
  name                         = "adf-dev-server"
  resource_group_name          = azurerm_resource_group.adf_rg.name
  location                     = azurerm_resource_group.adf_rg.location
  version                      = "12.0"
  administrator_login          = var.adminlogin
  administrator_login_password = azurerm_key_vault_secret.SQLPassword.value

  depends_on = [
    azurerm_key_vault_secret.SQLPassword
  ]
}


resource "azurerm_mssql_database" "adf_sql_db" {
  name      = "adf-dev-db"
  server_id = azurerm_mssql_server.adf_sql_srv.id
}

resource "azurerm_mssql_firewall_rule" "adf_sql_frule" {
  name             = "FirewallRule"
  server_id        = azurerm_mssql_server.adf_sql_srv.id
  start_ip_address = "154.0.15.246"
  end_ip_address   = "154.0.15.246"
}

resource "azurerm_mssql_firewall_rule" "adf_sql_frule2" {
  name             = "FirewallRule2"
  server_id        = azurerm_mssql_server.adf_sql_srv.id
  start_ip_address = "102.133.217.21"
  end_ip_address   = "102.133.217.21"
}


# Create Azure Data Factory
resource "azurerm_data_factory" "adf" {
  name                = var.adf_name
  location            = azurerm_resource_group.adf_rg.location
  resource_group_name = azurerm_resource_group.adf_rg.name
}


resource "azurerm_data_factory_linked_service_azure_sql_database" "source" {
  name              = "az_sqldb_adf_dev_server"
  data_factory_id   = azurerm_data_factory.adf.id
  connection_string = azurerm_key_vault_secret.ADFConnectionString.value

  depends_on = [
    azurerm_key_vault_secret.ADFConnectionString
  ]
}

resource "azurerm_data_factory_linked_service_azure_blob_storage" "destination" {
  name              = "az_adls_adfstgdev"
  data_factory_id   = azurerm_data_factory.adf.id
  connection_string = azurerm_storage_account.adf_stg.primary_connection_string
}