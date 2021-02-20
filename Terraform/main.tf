provider "azurerm" {
  # whilst the `version` attribute is optional, we recommend pinning to a given version of the Provider
  version = "=2.40.0"
  features {}
}

#Creating a Resource Group
resource "azurerm_resource_group" "rg" {
  name      = "Tata-RG"
  location  = "eastus"
}

#Creating a Vnet Inside the Resource Group
resource "azurerm_virtual_network" "vnet" {
  name                = "Tata-Vnet"
  address_space       = [ "192.168.0.0/16" ]
  location            = "eastus"
  resource_group_name = azurerm_resource_group.rg.name
}

#Creating Public Subnet for Server
resource "azurerm_subnet" "subnet-public" {
  name                  = "Tata-frontend-server"
  resource_group_name   = azurerm_resource_group.rg.name
  virtual_network_name  = azurerm_virtual_network.vnet.name
  address_prefixes      = [ "192.168.1.0/24" ]
}

#Creating Backend Subnet for Database
resource "azurerm_subnet" "subnet-private" {
  name                  = "Tata-backend-db"
  resource_group_name   = azurerm_resource_group.rg.name
  virtual_network_name  = azurerm_virtual_network.vnet.name
  address_prefixes      = [ "192.168.2.0/24" ]
}

#Creating a public IP for Server VM
resource "azurerm_public_ip" "ip-frontend" {
  name                = "Tata-frontend-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

#NSG- Public Subnet
resource "azurerm_network_security_group" "nsg-frontend" {
  name                = "Tata-frontend-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  #Allowing Internet access to port 80 : inbound
  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  #Allowing Internet access to HTTPS : inbound
  security_rule {
    name                       = "Allow-HTTPS"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  # Allow SSH Port Open
  security_rule {
    name                       = "Allow-SSH"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

#NSG- Private Subnet
resource "azurerm_network_security_group" "nsg-backend" {
  name                = "Tata-backend-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

   #Allowing Internet access to port 3306 : inbound
  security_rule {
    name                       = "MySql-Access"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  # Allow SSH Port Open
  security_rule {
    name                       = "Allow-SSH"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

#Outbound Rules : Stop Internet Access
  security_rule {
    name                       = "Stop-Internet"
    priority                   = 101
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }
}

#Attaching Public Subnet with Frontend NSG
resource "azurerm_subnet_network_security_group_association" "public-nsg-association" {
  subnet_id                 = azurerm_subnet.subnet-public.id
  network_security_group_id = azurerm_network_security_group.nsg-frontend.id
}

#Attaching Private Subnet with Backend NSG
resource "azurerm_subnet_network_security_group_association" "private-nsg-association" {
  subnet_id                 = azurerm_subnet.subnet-private.id
  network_security_group_id = azurerm_network_security_group.nsg-backend.id
}

#Creating a public IP for LoadBalancer
resource "azurerm_public_ip" "ip-loadbalancer" {
  name                = "Tata-loadbalancer-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

#Load Balancer
resource "azurerm_lb" "lb" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = "Tata-Lb"
  location            = azurerm_resource_group.rg.location

  frontend_ip_configuration {
    name                 = "Tata-IP"
    public_ip_address_id = azurerm_public_ip.ip-loadbalancer.id
  }
}

#LB: Address Pool
resource "azurerm_lb_backend_address_pool" "lb-pool" {
  resource_group_name = azurerm_resource_group.rg.name
  loadbalancer_id     = azurerm_lb.lb.id
  name                = "Tata-Lb-BackendPool"
}

#LB: Health Probe
resource "azurerm_lb_probe" "lb-health-probe" {
  resource_group_name = azurerm_resource_group.rg.name
  loadbalancer_id     = azurerm_lb.lb.id
  name                = "Tata-Tcp-Lb-Probe"
  protocol            = "tcp"
  port                = 80
  interval_in_seconds = 5
  number_of_probes    = 2
}

#LB : Rule
resource "azurerm_lb_rule" "lb-rule" {
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "Tata-Lb-Rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "Tata-IP"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb-pool.id
  probe_id = azurerm_lb_probe.lb-health-probe.id

}

# NIC Card : VM & LB
resource "azurerm_network_interface" "nic-frontend" {
  name                = "Tata-frontend-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "Tata-IP-config"
    subnet_id                     = azurerm_subnet.subnet-public.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ip-frontend.id
  }
}

# Associating Network Card with Public-Nsg
resource "azurerm_network_interface_security_group_association" "nic-nsg-association" {
  network_interface_id      = azurerm_network_interface.nic-frontend.id
  network_security_group_id = azurerm_network_security_group.nsg-frontend.id
}

# Associating Network Card with backend Pool
resource "azurerm_network_interface_backend_address_pool_association" "Lb-pool-association" {
  network_interface_id    = azurerm_network_interface.nic-frontend.id
  ip_configuration_name   = "Tata-IP-config"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb-pool.id
}

# Virtual Machine : Web Server
resource "azurerm_linux_virtual_machine" "server-vm" {
  name                = "Tata-Server-VM"
  computer_name       = "Tata-Server-VM"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1ms"

  admin_username      = "azureuser"
  admin_password      = "Password@123"
  disable_password_authentication = false

  network_interface_ids = [ azurerm_network_interface.nic-frontend.id ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

#Creating a public IP
resource "azurerm_public_ip" "ip-backend" {
  name                = "Tata-backend-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# NIC Card : DB
resource "azurerm_network_interface" "nic-backend" {
  name                = "Tata-backend-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "Tata-IP-config-DB"
    subnet_id                     = azurerm_subnet.subnet-private.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ip-backend.id
  }
}

# Associating Network Card with Private-Nsg
resource "azurerm_network_interface_security_group_association" "nic-nsg-association-backend" {
  network_interface_id      = azurerm_network_interface.nic-backend.id
  network_security_group_id = azurerm_network_security_group.nsg-backend.id
}

# Virtual Machine : Database
resource "azurerm_linux_virtual_machine" "backend-vm" {
  name                = "Tata-DB-VM"
  computer_name       = "Tata-DB-VM"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1ms"

  admin_username      = "azureuser"
  admin_password      = "Password@123"
  disable_password_authentication = false

  network_interface_ids = [ azurerm_network_interface.nic-backend.id ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}