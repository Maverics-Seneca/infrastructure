# main.tf

# Provider configuration
provider "azurerm" {
  features {}
  subscription_id = "0cb69517-b7d3-4bde-a4b7-3905c5b3d55c" # Your Azure subscription ID
}

# Variables for SSH key paths
variable "private_key_path" {
  description = "Path to the SSH private key"
  default     = "~/.ssh/terraform/terraform_key"  # Path from your earlier commands
}

variable "public_key_path" {
  description = "Path to the SSH public key"
  default     = "~/.ssh/terraform/terraform_key.pub"  # Path from your earlier commands
}

# Resource Group
resource "azurerm_resource_group" "maveric" {
  name     = "maveric"
  location = "East US" # Choose a cost-friendly region
}

# Virtual Network
resource "azurerm_virtual_network" "maveric_vnet" {
  name                = "maveric-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.maveric.location
  resource_group_name = azurerm_resource_group.maveric.name
}

# Subnet
resource "azurerm_subnet" "maveric_subnet" {
  name                 = "maveric-subnet"
  resource_group_name  = azurerm_resource_group.maveric.name
  virtual_network_name = azurerm_virtual_network.maveric_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Public IP (Standard SKU with Static Allocation)
resource "azurerm_public_ip" "maveric_public_ip" {
  name                = "maveric-public-ip"
  location            = azurerm_resource_group.maveric.location
  resource_group_name = azurerm_resource_group.maveric.name
  allocation_method   = "Static" # Required for Standard SKU
  sku                 = "Standard" # Use Standard SKU
}

# Network Security Group (NSG) with additional ports
resource "azurerm_network_security_group" "maveric_nsg" {
  name                = "maveric-nsg"
  location            = azurerm_resource_group.maveric.location
  resource_group_name = azurerm_resource_group.maveric.name

  # Rule for SSH (port 22)
  security_rule {
    name                       = "allow-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*" # Allow all IPs (or specify your IP)
    destination_address_prefix = "*"
  }

  # Rule for port 3000 (Frontend)
  security_rule {
    name                       = "allow-port-3000"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = "*" # Allow all IPs (or specify your IP)
    destination_address_prefix = "*"
  }

  # Rule for port 4004 (Caretaker Service)
  security_rule {
    name                       = "allow-port-4004"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "4004"
    source_address_prefix      = "*" # Allow all IPs (or specify your IP)
    destination_address_prefix = "*"
  }

  # Rule for port 4000 (Auth Service)
  security_rule {
    name                       = "allow-port-4000"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "4000"
    source_address_prefix      = "*" # Allow all IPs (or specify your IP)
    destination_address_prefix = "*"
  }

  # Rule for port 3001 (Middleware)
  security_rule {
    name                       = "allow-port-3001"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3001"
    source_address_prefix      = "*" # Allow all IPs (or specify your IP)
    destination_address_prefix = "*"
  }

  # Rule for port 4002 (Medication Service)
  security_rule {
    name                       = "allow-port-4002"
    priority                   = 150
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "4002"
    source_address_prefix      = "*" # Allow all IPs (or specify your IP)
    destination_address_prefix = "*"
  }
}

# Associate NSG with the subnet
resource "azurerm_subnet_network_security_group_association" "maveric_nsg_assoc" {
  subnet_id                 = azurerm_subnet.maveric_subnet.id
  network_security_group_id = azurerm_network_security_group.maveric_nsg.id
}

# Network Interface
resource "azurerm_network_interface" "maveric_nic" {
  name                = "maveric-nic"
  location            = azurerm_resource_group.maveric.location
  resource_group_name = azurerm_resource_group.maveric.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.maveric_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.maveric_public_ip.id # Associate Public IP
  }
}

# Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "maveric_vm" {
  name                = "maveric-vm"
  resource_group_name = azurerm_resource_group.maveric.name
  location            = azurerm_resource_group.maveric.location
  size                = "Standard_B1s" # Cost-friendly VM size
  admin_username      = "azureuser"
  network_interface_ids = [
    azurerm_network_interface.maveric_nic.id, # Use the correct NIC
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file(var.public_key_path) # Updated to use the variable
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS" # Cost-friendly storage
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS" # Free tier eligible
    version   = "latest"
  }

  # Optional: Connection block for provisioners
  connection {
    type        = "ssh"
    user        = "azureuser"
    private_key = file(var.private_key_path) # Use the private key for SSH
    host        = azurerm_public_ip.maveric_public_ip.ip_address
  }

  # Optional: Provisioner to test SSH
  provisioner "remote-exec" {
    inline = [
      "echo 'SSH connection successful' > /tmp/terraform_test.txt",
      "sudo apt update -y"
    ]
  }
}

# Azure Container Registry (ACR)
resource "azurerm_container_registry" "maveric_acr" {
  name                = "mavericacr"
  resource_group_name = azurerm_resource_group.maveric.name
  location            = azurerm_resource_group.maveric.location
  sku                 = "Basic" # Cost-friendly ACR SKU
  admin_enabled       = true
}
