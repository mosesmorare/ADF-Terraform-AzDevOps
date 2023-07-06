# Azure Data Factory Deployment with Terraform

Step 1: Create a providers.tf module and copy the below code. Note we use the random provider in order to make our storage account name unique

~~~
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.57.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.4.3"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}
~~~

Step 2: Create an Azure Data Factory Instance.

Next, we creates an ADF instance with linked services; SQL Database, and Storage Account with container. Save this code to a file named main.tf. Note: we store our SQL Database administrator_login_password & the ADF linked_service_azure_sql_database" Connection String in a Key Vault which we will create later on.
~~~
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
  name                     = "adfstgdev${random_string.main.result}"
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

  # dependency on the azurerm_key_vault_secret that Terraform cannot
  # automatically infer, so it must be declared explicitly:

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
  start_ip_address = "Add your Public IP"
  end_ip_address   = "Add your Public IP"
}

resource "azurerm_mssql_firewall_rule" "adf_sql_frule2" {
  name             = "FirewallRule2"
  server_id        = azurerm_mssql_server.adf_sql_srv.id
  start_ip_address = "102.133.217.21" # Azure Integration Runtime IP
  end_ip_address   = "102.133.217.21" # Azure Integration Runtime IP
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

  # dependency on the azurerm_key_vault_secret that Terraform cannot
  # automatically infer, so it must be declared explicitly:

  depends_on = [
    azurerm_key_vault_secret.ADFConnectionString
  ]
}

resource "azurerm_data_factory_linked_service_azure_blob_storage" "destination" {
  name              = "az_adls_adfstgdev"
  data_factory_id   = azurerm_data_factory.adf.id
  connection_string = azurerm_storage_account.adf_stg.primary_connection_string
}

~~~


Step 3: Create Key Vault

Next, lets create a Key Vault to store the SQL Password and the ADF instance "azurerm_data_factory_linked_service_azure_sql_database" Connection String. One consideration is that both secrets are still visible within our codebase since this is a local deployemnt we can ignore this glaring security risk. However if we were to store our code in source control this would be ill-advised. To overcome such a requirement we would use a pre-existing kevault and reference the secrets within using "Data Sources" which allow Terraform to use information defined outside of Terraform.

~~~
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

  # dependency on the azurerm_key_vault_access_policy that Terraform cannot
  # automatically infer, so it must be declared explicitly:

  depends_on = [
    azurerm_key_vault_access_policy.current_user
  ]
}


resource "azurerm_key_vault_secret" "ADFConnectionString" {
  name         = "ADFConnectionString"
  value        = "data source=adf-dev-server.database.windows.net;initial catalog=master;user id=adminuser;Password=YB4E9bvn1A;integrated security=False;encrypt=True;connection timeout=30"
  key_vault_id = azurerm_key_vault.az-key-v1.id

  # dependency on the azurerm_key_vault_access_policy that Terraform cannot
  # automatically infer, so it must be declared explicitly:

  depends_on = [
    azurerm_key_vault_access_policy.current_user
  ]
}

~~~



Step 3: Create variables.tf and terraform.tfvars

Lastly we create the variables.tf and terraform.tfvars modules which contain the values referenced in our Terraform configuration files.

variables.tf
~~~
variable "resource_group_location" {
  description = "The location of the resource group."
}

variable "resource_group_name" {
  description = "The name of the resource group."
}

variable "adf_name" {
  description = "The name of the Azure Data Factory."
}


variable "adminlogin" {
  description = "The username for the DB master user"
  type        = string
  sensitive   = true
}
~~~

terraform.tfvars
~~~
resource_group_location = "southafricanorth"
resource_group_name     = "ADF-DevRg"
adf_name                = "ADF-Terraform"
adminlogin              = "adminuser"
~~~


# Conclusion
We created an Azure Data Factory Instance with linked services using Terraform. This deployment is for development purposes only as result we kept the terraform.tfstate file local. If this were a more serious deploment we would need to create a backend.tf file to store our state remotely for added security, we would also use a pre-existing keyvault in order to keep our secrets out of source control.