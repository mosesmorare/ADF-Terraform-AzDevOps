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