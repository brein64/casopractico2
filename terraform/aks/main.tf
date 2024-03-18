locals {
  env                 = "casopractico2"
  region              = "eastus2"
  resource_group_name = "casopractico2-aks-rg"
  aks_name            = "casopractico2-aks"
  aks_version         = "1.27"
}


resource "azurerm_resource_group" "this" {
  name     = local.resource_group_name
  location = local.region
}


resource "azurerm_virtual_network" "this" {
  name                = "main"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  tags = {
    env = local.env
  }
}


resource "azurerm_subnet" "subnet1" {
  name                 = "subnet1"
  address_prefixes     = ["10.0.0.0/19"]
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
}

resource "azurerm_subnet" "subnet2" {
  name                 = "subnet2"
  address_prefixes     = ["10.0.32.0/19"]
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
}


resource "azurerm_user_assigned_identity" "base" {
  name                = "base"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_role_assignment" "base" {
  scope                = azurerm_resource_group.this.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.base.principal_id
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = "${local.env}-${local.aks_name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix          = "casopractico2aks"

  kubernetes_version        = local.aks_version
  automatic_channel_upgrade = "stable"
  private_cluster_enabled   = false
  node_resource_group       = "${local.resource_group_name}-${local.env}-${local.aks_name}"

  sku_tier = "Free"

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  network_profile {
    network_plugin = "azure"
    dns_service_ip = "10.0.64.10"
    service_cidr   = "10.0.64.0/19"
  }

  default_node_pool {
    name                 = "general"
    vm_size              = "Standard_D2_v2"
    vnet_subnet_id       = azurerm_subnet.subnet1.id
    orchestrator_version = local.aks_version
    type                 = "VirtualMachineScaleSets"
    enable_auto_scaling  = true
    node_count           = 1
    min_count            = 1
    max_count            = 10

    node_labels = {
      role = "general"
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.base.id]
  }

  tags = {
    env = local.env
  }

  lifecycle {
    ignore_changes = [default_node_pool[0].node_count]
  }

  depends_on = [
    azurerm_role_assignment.base
  ]
}


resource "azurerm_kubernetes_cluster_node_pool" "spot" {
  name                  = "spot"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = "Standard_DS2_v2"
  vnet_subnet_id        = azurerm_subnet.subnet1.id
  orchestrator_version  = local.aks_version
  priority              = "Spot"
  spot_max_price        = -1
  eviction_policy       = "Delete"

  enable_auto_scaling = true
  node_count          = 1
  min_count           = 1
  max_count           = 10

  node_labels = {
    role                                    = "spot"
    "kubernetes.azure.com/scalesetpriority" = "spot"
  }

  node_taints = [
    "spot:NoSchedule",
    "kubernetes.azure.com/scalesetpriority=spot:NoSchedule"
  ]

  tags = {
    env = local.env
  }

  lifecycle {
    ignore_changes = [node_count]
  }
}

data "azurerm_kubernetes_cluster" "this" {
  name                = "${local.env}-${local.aks_name}"
  resource_group_name = local.resource_group_name
  depends_on = [azurerm_kubernetes_cluster.this]
}

provider "helm" {
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.this.kube_config.0.host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.this.kube_config.0.client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.this.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.this.kube_config.0.cluster_ca_certificate)
  }
}

resource "helm_release" "external_nginx" {
  name = "external"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress"
  create_namespace = true
  version          = "4.8.0"
  values = [file("${path.module}/kubernetes/ingress/ingress.yaml")]
}

resource "helm_release" "cert_manager" {
  name = "cert-manager"

  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = "v1.13.1"

  set {
    name  = "installCRDs"
    value = "true"
  }
}

resource "azurerm_user_assigned_identity" "casopractico2" {
  name                = "casopractico2"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_federated_identity_credential" "casopractico2" {
  name                = "casopractico2"
  resource_group_name = local.resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.this.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.casopractico2.id
  subject             = "system:serviceaccount:casopractico2:my-account"

  depends_on = [azurerm_kubernetes_cluster.this]
}


resource "random_integer" "this" {
  min = 10000
  max = 5000000
}

resource "azurerm_storage_account" "this" {
  name                     = "casopractico2${random_integer.this.result}"
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "this" {
  name                  = "casopractico2"
  storage_account_name  = azurerm_storage_account.this.name
  container_access_type = "private"
}

resource "azurerm_role_assignment" "casopractico2" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.casopractico2.principal_id
}