#### Enable public IP if needed ######
resource "azurerm_public_ip" "mh_pip_appgw" {
  name                = "pip-appgw-microhack"
  sku                 = "Standard"
  resource_group_name = azurerm_resource_group.microhack_monitoring.name
  location            = azurerm_resource_group.microhack_monitoring.location
  allocation_method   = "Static"
}


# local block for variables
locals {
  backend_address_pool_name      = "beap-appgw-microhack"
  frontend_port_name             = "feport-appgw-microhack"
  frontend_ip_configuration_name = "feip-appgw-microhack"
  http_setting_name              = "be-htst-appgw-microhack"
  listener_name                  = "httplstn-appgw-microhack"
  request_routing_rule_name      = "rqrt-appgw-microhack"
}


resource "azurerm_application_gateway" "appgw" {
  name                = "appgw-microhack"
  resource_group_name = azurerm_resource_group.microhack_monitoring.name
  location            = azurerm_resource_group.microhack_monitoring.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
  }

  autoscale_configuration {
    min_capacity = "1"
    max_capacity = "4"
  }

  gateway_ip_configuration {
    name      = "appgw-mh-ip-configuration"
    subnet_id = azurerm_subnet.microhack_subnet[1].id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.mh_pip_appgw.id
  }

   frontend_ip_configuration {
    name                                 = "${local.frontend_ip_configuration_name}-private"
    subnet_id                            = azurerm_subnet.microhack_subnet[1].id
    private_ip_address_allocation        = "Static"
    private_ip_address                   = "10.0.1.50"
  }

  backend_address_pool {
    name = local.backend_address_pool_name
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
    priority                   = 10
  }
}