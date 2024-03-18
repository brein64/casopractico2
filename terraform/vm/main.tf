locals {
  location       = "North Europe"
  base_name      = "caso-practico-2"
  resource_group = "caso-practico-2"
  vnet_rg_name   = "caso-practico-2"
  vnet_name      = "caso-practico-2-vnet"
  subnet_name    = "caso_practico-subnet"
  ssh_key        = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDSijhnUt2ws3YM43eDIMNeH1BELpCQRLpu44OJUFoiF6QFZyop4MlI4nAZde2GpZUNnlpwtkOYvz4c6y3vqzh/2+dN89RsGlq03lwmz3A40OFh73WK1zrqJN8QZnuDlmzncFW4GZIWHsjUFjB0Ba7suMR00Y/dsKjzEU5cysyxLbw5CPrMr0KELqO4LERqvknDuKC5O11LCBgBABWyqt6VUx5kEoj8+hViBndqKdrPdz0vQ8msCUmq/HuPTkp62ry/rfs/05CPhDMppeQ8UF7ATMb0NdeoBQfDOPBNl+94P0MyBcA95JngsyDr7nAnAy7RYWKy7JwmXcWP427i3DV5VzFVBhoAP3MxodW4kPNa8u4P2N9XRhLxvSNKgFOmDinDKiPAisttmsq4/yfrH6nwyNtqCwIIPSnAL2Y0W0vnb+EozrRXRy/AozGkwYLr8QS2BI5LQSChZFoLeQE/3x7iSddiFBOX2vdH9jPfUZ++ZoCf7FJYpDA4usnNNPhWhZvcLP01Jazs0w75mGO39RMjOnRa4FgXCrW89RbTo+RSOi24ggYHNy+4PLAscnDt+Ih3qpNgGe9a0VSe8QzfpeuoCrCrITTzaNqCBXwYII9ZKwPtmNaiGDs8k1TSXXrqMOXS3r54h4ce0nBUYUEL8rAqhhWO4aD9qqj13GyqzLLSDw== bpineros@bpineros-WT9W61GYGF"

  vm_caso_practico_2_size              = "Standard_B1ms"
  vm_count                             = 1
}

resource "azurerm_resource_group" "resource_group" {
    name     = local.resource_group
    location = local.location
}

resource "azurerm_availability_set" "availability_set" {
    name                         = "${azurerm_resource_group.resource_group.name}-availability-set"
    location                     = local.location
    resource_group_name          = "${azurerm_resource_group.resource_group.name}"
    platform_update_domain_count = "4" 
    platform_fault_domain_count  = "2"
    managed                      = "true"
}

resource "azurerm_virtual_network" "network" {
    name                = "${azurerm_resource_group.resource_group.name}-vnet"
    address_space       = ["10.0.0.0/24"]
    location            = local.location
    resource_group_name = "${azurerm_resource_group.resource_group.name}"
}

resource "azurerm_subnet" "subnet" {
  name                 = local.subnet_name
  virtual_network_name = "${azurerm_virtual_network.network.name}"
  resource_group_name  = "${azurerm_resource_group.resource_group.name}"
  address_prefixes       = ["10.0.0.0/24"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "${azurerm_resource_group.resource_group.name}-NSG"
  location            = local.location
  resource_group_name = "${azurerm_resource_group.resource_group.name}"
}

resource "azurerm_network_security_rule" "rule_http" {
  name                        = "Http"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "${azurerm_resource_group.resource_group.name}"
  network_security_group_name = "${azurerm_network_security_group.nsg.name}"
}


data "azurerm_subnet" "caso-practico-2" {
  name                 = "${azurerm_subnet.subnet.name}"
  virtual_network_name = local.vnet_name
  resource_group_name  = local.vnet_rg_name
}

resource "azurerm_public_ip" "pip_caso_practico_2" {
  name                = "${local.base_name}-public-ip-${count.index}"
  location            = local.location
  count               = local.vm_count
  resource_group_name = "${azurerm_resource_group.resource_group.name}"
  allocation_method   = "Static"
  }

resource "azurerm_network_interface" "nic_caso_practico_2" {
  count                         = local.vm_count
  name                          = "${local.base_name}-nic-${count.index}"
  location                      = local.location
  resource_group_name           = "${azurerm_resource_group.resource_group.name}"
  enable_accelerated_networking = false
  
  ip_configuration {
    name                          = "${local.base_name}-nic-config-${count.index}"
    subnet_id                     = data.azurerm_subnet.caso-practico-2.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = element(azurerm_public_ip.pip_caso_practico_2[*].id, count.index)
  }
}

resource "azurerm_virtual_machine" "caso-practico-2" {
  count                            = local.vm_count
  name                             = "${local.base_name}-${count.index}"
  location                         = local.location
  resource_group_name              = "${azurerm_resource_group.resource_group.name}"
  vm_size                          = local.vm_caso_practico_2_size
  network_interface_ids            = [element(azurerm_network_interface.nic_caso_practico_2[*].id, count.index)]
  delete_data_disks_on_termination = true
  delete_os_disk_on_termination    = true

  identity {
    type = "SystemAssigned"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${local.base_name}-${count.index}-OsDisk"
    create_option     = "FromImage"
    caching           = "ReadWrite"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "${local.base_name}-${count.index}"
    admin_username = "azure_root"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/azure_root/.ssh/authorized_keys"
      key_data = local.ssh_key
    }
  }
}

resource "azurerm_virtual_machine_extension" "extensions" {
  count                = local.vm_count
  name                 = "AADSSHLoginForLinux"
  virtual_machine_id   = element(azurerm_virtual_machine.caso-practico-2[*].id, count.index)
  publisher            = "Microsoft.Azure.ActiveDirectory"
  type                 = "AADSSHLoginForLinux"
  type_handler_version = "1.0"
}