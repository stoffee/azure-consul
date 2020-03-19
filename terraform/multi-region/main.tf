terraform {
  required_version = ">= 0.10.1"
}

provider "azurerm" {
  subscription_id = "${var.auto_join_subscription_id}"
  client_id       = "${var.auto_join_client_id}"
  client_secret   = "${var.auto_join_client_secret}"
  tenant_id       = "${var.auto_join_tenant_id}"
}

resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-multi-region"
  location = "${var.region}"
}

module "ssh_key" {
  source = "../modules/ssh-keypair-data"

  private_key_filename = "${var.private_key_filename}"
}

module "network_westus" {
  source                = "../modules/network-azure"
  resource_group_name   = "${azurerm_resource_group.main.name}"
  location              = "westus"
  network_name          = "${prefix}-consul-westus"
  network_cidr          = "10.0.0.0/16"
  network_cidrs_public  = ["10.0.0.0/20"]
  network_cidrs_private = ["10.0.48.0/20", "10.0.64.0/20", "10.0.80.0/20"]
  os                    = "${var.os}"
  public_key_data       = "${module.ssh_key.public_key_data}"
}

module "network_eastus" {
  source                = "../modules/network-azure"
  resource_group_name   = "${azurerm_resource_group.main.name}"
  location              = "westus2"
  network_name          = "${prefix}-consul-westus2"
  network_cidr          = "10.1.0.0/16"
  network_cidrs_public  = ["10.1.0.0/20"]
  network_cidrs_private = ["10.1.48.0/20", "10.1.64.0/20", "10.1.80.0/20"]
  os                    = "${var.os}"
  public_key_data       = "${module.ssh_key.public_key_data}"
}

module "consul_azure_westus" {
  source                    = "../modules/consul-azure"
  resource_group_name       = "${azurerm_resource_group.main.name}"
  consul_datacenter         = "${prefix}-consul-westus"
  consul_join_wan           = ["${prefix}-consul-westus2"]
  location                  = "westus"
  cluster_size              = "${var.cluster_size}"
  private_subnet_ids        = ["${module.network_westus.subnet_private_ids}"]
  consul_version            = "${var.consul_version}"
  vm_size                   = "${var.consul_vm_size}"
  os                        = "${var.os}"
  public_key_data           = "${module.ssh_key.public_key_data}"
  auto_join_subscription_id = "${var.auto_join_subscription_id}"
  auto_join_tenant_id       = "${var.auto_join_tenant_id}"
  auto_join_client_id       = "${var.auto_join_client_id}"
  auto_join_client_secret   = "${var.auto_join_client_secret}"
}

module "consul_azure_eastus" {
  source                    = "../modules/consul-azure"
  resource_group_name       = "${azurerm_resource_group.main.name}"
  consul_datacenter         = "${prefix}-consul-westus2"
  consul_join_wan           = ["${prefix}-consul-westus"]
  location                  = "westus2"
  cluster_size              = "${var.cluster_size}"
  private_subnet_ids        = ["${module.network_eastus.subnet_private_ids}"]
  consul_version            = "${var.consul_version}"
  vm_size                   = "${var.consul_vm_size}"
  os                        = "${var.os}"
  public_key_data           = "${module.ssh_key.public_key_data}"
  auto_join_subscription_id = "${var.auto_join_subscription_id}"
  auto_join_tenant_id       = "${var.auto_join_tenant_id}"
  auto_join_client_id       = "${var.auto_join_client_id}"
  auto_join_client_secret   = "${var.auto_join_client_secret}"
}

resource "azurerm_virtual_network_peering" "peer-westus-to-westus2" {
  name                         = "${prefix}-peer-westus-to-westus2"
  resource_group_name          = "${azurerm_resource_group.main.name}"
  virtual_network_name         = "${module.network_westus.virtual_network_name}"
  remote_virtual_network_id    = "${module.network_eastus.virtual_network_id}"
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  # `allow_gateway_transit` must be set to false for vnet Global Peering
  allow_gateway_transit = false
}

resource "azurerm_virtual_network_peering" "peer-westus2-to-westus" {
  name                         = "${prefix}-peer-westus2-to-westus"
  resource_group_name          = "${azurerm_resource_group.main.name}"
  virtual_network_name         = "${module.network_eastus.virtual_network_name}"
  remote_virtual_network_id    = "${module.network_westus.virtual_network_id}"
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  # `allow_gateway_transit` must be set to false for vnet Global Peering
  allow_gateway_transit = false
}
