terraform {
  required_version = ">= 0.11.1"
}

variable "location" {
  description = "Azure location in which to create resources"
  default = "East US"
}

variable "environment" {
  description = "The environment for this deployment"
  default = "dev"
}

variable "resource_group_name" {
  description = "An associated resource group name"
}

variable "windows_dns_prefix" {
  description = "DNS prefix to add to to public IP address for Windows VM"
}

variable "admin_password" {
  description = "admin password for Windows VM"
  default = "pTFE1234!"
}

module "windowsserver" {
  source              = "Azure/compute/azurerm"
  version             = "1.1.5"
  location            = "${var.location}"
  vm_hostname         = "pwc-ptfe"
  admin_password      = "${var.admin_password}"
  vm_os_simple        = "WindowsServer"
  public_ip_dns       = ["${var.windows_dns_prefix}"]
  vnet_subnet_id      = "${module.network.vnet_subnets[0]}"
  resource_group_name = "${var.resource_group_name}"
}

module "network" {
  source              = "Azure/network/azurerm"
  version             = "1.1.1"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
  allow_ssh_traffic   = true
}

output "lb_fqdn" {
  value = "${data.azurerm_public_ip.windowsserverip.fqdn}"
}

data "azurerm_public_ip" "windowsserverip" {
  resource_group_name = "${var.resource_group_name}"
  name = "${azurerm_public_ip.windowsserverip.name}"
}

resource "azurerm_public_ip" "windowsserverip" {
  resource_group_name          = "${var.resource_group_name}"
  name                         = "${format("windowsserverip-%s", var.environment)}"
  location                     = "${var.location}"
  public_ip_address_allocation = "dynamic"
  domain_name_label            = "${var.windows_dns_prefix}"
 }

resource "azurerm_lb" "windowsserver" {
  resource_group_name = "${var.resource_group_name}"
  name                = "${format("windowsserver-%s", var.environment)}"
  location            = "${var.location}"

  frontend_ip_configuration {
      name                 = "LoadBalancerFrontEnd"
      public_ip_address_id = "${azurerm_public_ip.windowsserverip.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "backend_pool" {
  resource_group_name = "${var.resource_group_name}"
  loadbalancer_id     = "${azurerm_lb.windowsserver.id}"
  name                = "${format("BackendPool1-%s", var.environment)}"
}

resource "azurerm_lb_rule" "lb_rule" {
    resource_group_name            = "${var.resource_group_name}"
    loadbalancer_id                = "${azurerm_lb.windowsserver.id}"
    name                           = "LBRule"
    protocol                       = "tcp"
    frontend_port                  = 80
    backend_port                   = 80
    frontend_ip_configuration_name = "LoadBalancerFrontEnd"
    enable_floating_ip             = false
    backend_address_pool_id        = "${azurerm_lb_backend_address_pool.backend_pool.id}"
    idle_timeout_in_minutes        = 5
}
