resource "azurerm_resource_group" "dint" {
  name     = "dint-resources"
  location = "West US"
}

resource "azurerm_virtual_network" "dint" {
  name                = "dint-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = "West US"
  resource_group_name = "${azurerm_resource_group.dint.name}"
}

resource "azurerm_subnet" "dint" {
  name                 = "dint-subnet-vmss"
  resource_group_name  = "${azurerm_resource_group.dint.name}"
  virtual_network_name = "${azurerm_virtual_network.dint.name}"
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_storage_account" "dint" {
  name                     = "dintstorageaccounttest"
  resource_group_name      = "${azurerm_resource_group.dint.name}"
  location                 = "westus"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "staging"
  }
}

resource "azurerm_storage_container" "dint" {
  name                  = "vhds"
  resource_group_name   = "${azurerm_resource_group.dint.name}"
  storage_account_name  = "${azurerm_storage_account.dint.name}"
  container_access_type = "private"
}

resource "azurerm_virtual_machine_scale_set" "example" {
  name                = "mytestscaleset-1"
  location            = "West US"
  resource_group_name = "${azurerm_resource_group.dint.name}"
  upgrade_policy_mode = "Manual"

  sku {
    name     = "Standard_B1ls"
    tier     = "Standard"
    capacity = 1
  }

  os_profile {
    computer_name_prefix = "testvm"
    admin_username       = "myadmin"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/myadmin/.ssh/authorized_keys"
      key_data = "${file("~/.ssh/demo_key.pub")}"
    }
  }

  network_profile {
    name    = "TestNetworkProfile"
    primary = true

    ip_configuration {
      name      = "TestIPConfiguration"
      primary   = true
      subnet_id = "${azurerm_subnet.dint.id}"
    }
  }

  storage_profile_os_disk {
    name           = "osDiskProfile"
    caching        = "ReadWrite"
    create_option  = "FromImage"
    vhd_containers = ["${azurerm_storage_account.dint.primary_blob_endpoint}${azurerm_storage_container.dint.name}"]
  }

  storage_profile_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}