# Configure the Microsoft Azure Provider
provider "azurerm" {
    # The "feature" block is required for AzureRM provider 2.x. 
    # If you're using version 1.x, the "features" block is not allowed.
    version = "~>2.0"
    features {}
}


resource "azurerm_resource_group" "udacitynd" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    environment = "dev"
  }
}

resource "azurerm_virtual_network" "udacitynd" {
  name                = "udacitynd-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.udacitynd.name

  tags = {
    environment = "dev"
  }
}

resource "azurerm_subnet" "udacitynd" {
  name                 = "udacitynd-subnet"
  resource_group_name  = azurerm_resource_group.udacitynd.name
  virtual_network_name = azurerm_virtual_network.udacitynd.name
  address_prefixes       = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "udacitynd" {
  name                         = "udacitynd-public-ip"
  location                     = var.location
  resource_group_name          = azurerm_resource_group.udacitynd.name
  allocation_method            = "Static"
  domain_name_label            = "udacitynddeploywebserver"

  tags = {
    environment = "dev"
  }
}
# Add VM scale set
resource "azurerm_lb" "udacitynd" {
  name                = "udacitynd-lb"
  location            = var.location
  resource_group_name = azurerm_resource_group.udacitynd.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.udacitynd.id
  }

  tags = {
    environment = "dev"
  }
}

resource "azurerm_lb_backend_address_pool" "bpepool" {
  resource_group_name = azurerm_resource_group.udacitynd.name
  loadbalancer_id     = azurerm_lb.udacitynd.id
  name                = "BackEndAddressPool"
}

resource "azurerm_lb_probe" "udacitynd" {
  resource_group_name = azurerm_resource_group.udacitynd.name
  loadbalancer_id     = azurerm_lb.udacitynd.id
  name                = "ssh-running-probe"
  port                = var.application_port
}

resource "azurerm_lb_rule" "lbnatrule" {
  resource_group_name            = azurerm_resource_group.udacitynd.name
  loadbalancer_id                = azurerm_lb.udacitynd.id
  name                           = "http"
  protocol                       = "Tcp"
  frontend_port                  = var.application_port
  backend_port                   = var.application_port
  backend_address_pool_id        = azurerm_lb_backend_address_pool.bpepool.id
  frontend_ip_configuration_name = "PublicIPAddress"
  probe_id                       = azurerm_lb_probe.udacitynd.id
}

data "azurerm_resource_group" "image" {
  name = "myResourceGroup"
}

data "azurerm_image" "image" {
  name                = "udacityNDDeployWebServerPackerImage"
  resource_group_name = data.azurerm_resource_group.image.name
}

resource "azurerm_virtual_machine_scale_set" "udacitynd" {
  name                = "vmscaleset"
  location            = var.location
  resource_group_name = azurerm_resource_group.udacitynd.name
  upgrade_policy_mode = "Manual"

  sku {
    name     = "Standard_DS1_v2"
    tier     = "Standard"
    capacity = 2
  }

  storage_profile_image_reference {
    id=data.azurerm_image.image.id
  }

  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_profile_data_disk {
    lun          = 0
    caching        = "ReadWrite"
    create_option  = "Empty"
    disk_size_gb   = 10
  }

  os_profile {
    computer_name_prefix = "vmlab"
    admin_username       = "azureuser"
    admin_password       = "Passwword1234"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/azureuser/.ssh/authorized_keys"
      key_data = file("~/.ssh/id_rsa.pub")
    }
  }

  network_profile {
    name    = "terraformnetworkprofile"
    primary = true

    ip_configuration {
      name                                   = "IPConfiguration"
      subnet_id                              = azurerm_subnet.udacitynd.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.bpepool.id]
      primary = true
    }
  }
  
  tags = {
    environment = "dev"
  }
}
