terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.30.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "=4.0.4"
    }
  }
}

resource "tls_private_key" "admin_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "nc" {
  name     = "nextcloud"
  location = "West Europe"
  tags = {
    "terraform" = "true"
  }
}

resource "azurerm_virtual_network" "ncNet" {
  name                = "nextcloud-network"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.nc.location
  resource_group_name = azurerm_resource_group.nc.name
}

resource "azurerm_subnet" "ncVMSubnet" {
  name                 = "nextcloud-instances"
  resource_group_name  = azurerm_resource_group.nc.name
  virtual_network_name = azurerm_virtual_network.ncNet.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_public_ip" "ncVMPubIP" {
  name                = "nextcloud-instance-publicip"
  location            = azurerm_resource_group.nc.location
  resource_group_name = azurerm_resource_group.nc.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_security_group" "ncNet_sg" {
  name                = "nextcloud-network-sg"
  location            = azurerm_resource_group.nc.location
  resource_group_name = azurerm_resource_group.nc.name
}

resource "azurerm_network_security_rule" "allow_ssh" {
  name                       = "SSH"
  priority                   = 1002
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "22"
  source_address_prefix      = "*"
  destination_address_prefix = "*"

  resource_group_name = azurerm_resource_group.nc.name
  network_security_group_name = azurerm_network_security_group.ncNet_sg.name
}

resource "azurerm_network_security_rule" "allow_http" {
  name                       = "HTTP"
  priority                   = 1001
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "80"
  source_address_prefix      = "*"
  destination_address_prefix = "*"

  resource_group_name = azurerm_resource_group.nc.name
  network_security_group_name = azurerm_network_security_group.ncNet_sg.name
}

resource "azurerm_network_interface" "ncVMnic" {
  name                = "nextcloud-instance-nic"
  location            = azurerm_resource_group.nc.location
  resource_group_name = azurerm_resource_group.nc.name

  ip_configuration {
    name                          = "nc_nic_configuration"
    subnet_id                     = azurerm_subnet.ncVMSubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ncVMPubIP.id
  }
}

resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.ncVMnic.id
  network_security_group_id = azurerm_network_security_group.ncNet_sg.id
}

resource "azurerm_linux_virtual_machine" "ncVM" {
  name                  = "nextcloud-instance"
  location              = azurerm_resource_group.nc.location
  resource_group_name   = azurerm_resource_group.nc.name
  network_interface_ids = [azurerm_network_interface.ncVMnic.id]
  size                  = "Standard_B1s"

  os_disk {
    name                 = "ncVMosDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal-daily"
    sku       = "20_04-daily-lts-gen2"
    version   = "latest"
  }

  computer_name                   = "nextcloud-instance1"
  admin_username                  = "azure"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azure"
    public_key = tls_private_key.admin_key.public_key_openssh
  }
}

output "admin_private_key" {
  value     = tls_private_key.admin_key.private_key_pem
  sensitive = true
}

output "publicip" {
  value = azurerm_public_ip.ncVMPubIP.ip_address
}