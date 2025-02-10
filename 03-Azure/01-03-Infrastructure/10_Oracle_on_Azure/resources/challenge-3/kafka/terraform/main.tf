data "azurerm_client_config" "current" {}

data "azuread_user" "current_user_object_id" {
  object_id = data.azurerm_client_config.current.object_id
}

resource "azurerm_resource_group" "rg" {
  name     = var.prefix
  location = var.location
}

####################################################
# Container Apps
####################################################

resource "azurerm_container_app_environment" "aca" {
  name                           = var.prefix
  location                       = azurerm_resource_group.rg.location
  resource_group_name            = azurerm_resource_group.rg.name
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.law.id
  infrastructure_subnet_id       = azurerm_subnet.subnet_aca.id
  internal_load_balancer_enabled = true
#  logs_destination               = "log-analytics"
  depends_on                     = [azurerm_storage_share.fileshare]
  workload_profile {
    name                  = "${var.prefix}D8"
    workload_profile_type = "D8"
    maximum_count         = 2
    minimum_count         = 1
  }
}

# see https://learn.microsoft.com/en-us/azure/container-apps/storage-mounts-azure-files?tabs=bash
resource "azurerm_container_app_environment_storage" "acastorage" {
  name                         = var.prefix
  container_app_environment_id = azurerm_container_app_environment.aca.id
  account_name                 = azurerm_storage_account.storage.name
  share_name                   = azurerm_storage_share.fileshare.name
  access_key                   = azurerm_storage_account.storage.primary_access_key
  access_mode                  = "ReadWrite"
  depends_on                   = [azurerm_storage_share.fileshare]
}

resource "azurerm_container_app" "container_app_zookeeper" {
  name                         = "${var.prefix}-zookeeper"
  container_app_environment_id = azurerm_container_app_environment.aca.id
  resource_group_name          = azurerm_resource_group.rg.name
  # location            = azurerm_resource_group.rg.location
  revision_mode         = "Single"
  workload_profile_name = "${var.prefix}D8"
  # count                 = 1
  ingress {
    transport        = "tcp"
    external_enabled = true
    target_port      = 2181
    exposed_port     = 2181
    traffic_weight {
      # label = "zookeeper"
      percentage      = 100
      revision_suffix = "zookeeper"
    }
  }
  template {
    min_replicas = 1

    volume {
      name         = azurerm_storage_share.fileshare.name
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.acastorage.name
    }
    container { # Zookeeper
      name   = "zookeeper"
      image  = "confluentinc/cp-zookeeper:latest"
      cpu    = 0.25
      memory = "0.5Gi"
      env {
        name  = "ZOOKEEPER_CLIENT_PORT"
        value = "2181"
      }
      env {
        name  = "ZOOKEEPER_TICK_TIME"
        value = "2000"
      }
      env {
        name  = "ZOOKEEPER_MAX_CLIENT_CNXNS"
        value = "60"
      }
    }
  }
}

resource "azurerm_container_app" "container_app_kafka" {
  depends_on                   = [azurerm_container_app.container_app_zookeeper]
  name                         = "${var.prefix}-kafka"
  container_app_environment_id = azurerm_container_app_environment.aca.id
  resource_group_name          = azurerm_resource_group.rg.name
  # location            = azurerm_resource_group.rg.location
  revision_mode         = "Single"
  workload_profile_name = "${var.prefix}D8"
  # count                 = 1
  ingress {
    transport        = "tcp"
    external_enabled = true
    target_port      = 9092
    exposed_port     = 9092
    traffic_weight {
      # label = "kafka"
      percentage      = 100
      revision_suffix = "kafka"
    }
  }
  template {
    min_replicas = 1
    volume {
      name         = azurerm_storage_share.fileshare.name
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.acastorage.name
    }
    container { # Kafka
      name   = "kafka"
      image  = "confluentinc/cp-kafka:latest"
      cpu    = 0.25
      memory = "0.5Gi"
      env {
        name  = "KAFKA_BROKER_ID"
        value = "1"
      }
      env {
        name  = "KAFKA_ZOOKEEPER_CONNECT"
        value = "${var.prefix}-zookeeper:2181"
      }
      env {
        name  = "KAFKA_ADVERTISED_LISTENERS"
        value = "PLAINTEXT://${var.prefix}-kafka:9092"
      }
      env {
        name  = "KAFKA_LISTENERS"
        value = "PLAINTEXT://${var.prefix}-kafak:9092"
      }
      env {
        name  = "KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR"
        value = "1"
      }
      env {
        name  = "KAFKA_TRANSACTION_STATE_LOG_MIN_ISR"
        value = "1"
      }
      env {
        name  = "KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR"
        value = "1"
      }
      env {
        name  = "KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS"
        value = "100"
      }
    }
  }
}

resource "azurerm_container_app" "container_app_kafka_connect" {
  depends_on                   = [azurerm_container_app.container_app_kafka]
  name                         = "${var.prefix}-kafka-connect"
  container_app_environment_id = azurerm_container_app_environment.aca.id
  resource_group_name          = azurerm_resource_group.rg.name
  # location            = azurerm_resource_group.rg.location
  revision_mode         = "Single"
  workload_profile_name = "${var.prefix}D8"
  # count                 = 1
  ingress {
    transport        = "tcp"
    external_enabled = true
    target_port      = 8083
    exposed_port     = 8083
    traffic_weight {
      percentage      = 100
      revision_suffix = "kafka-connect"
    }
  }
  template {
    min_replicas = 1
    volume {
      name         = azurerm_storage_share.fileshare.name
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.acastorage.name
    }
    container { # Kafka-Connect
      name   = "kafka-connect"
      image  = "confluentinc/cp-kafka-connect:latest"
      cpu    = 0.25
      memory = "0.5Gi"
      env {
        name  = "CONNECT_BOOTSTRAP_SERVERS"
        value = "${var.prefix}-kafka:9092"
      }
      env {
        name  = "CONNECT_REST_PORT"
        value = "8083"
      }
      env {
        name  = "CONNECT_GROUP_ID"
        value = "connect-cluster"
      }
      env {
        name  = "CONNECT_CONFIG_STORAGE_TOPIC"
        value = "connect-configs"
      }
      env {
        name  = "CONNECT_OFFSET_STORAGE_TOPIC"
        value = "connect-offsets"
      }
      env {
        name  = "CONNECT_STATUS_STORAGE_TOPIC"
        value = "connect-statuses"
      }
      env {
        name  = "CONNECT_KEY_CONVERTER"
        value = "org.apache.kafka.connect.json.JsonConverter"
      }
      env {
        name  = "CONNECT_VALUE_CONVERTER"
        value = "org.apache.kafka.connect.json.JsonConverter"
      }
      env {
        name  = "CONNECT_INTERNAL_KEY_CONVERTER"
        value = "org.apache.kafka.connect.json.JsonConverter"
      }
      env {
        name  = "CONNECT_INTERNAL_VALUE_CONVERTER"
        value = "org.apache.kafka.connect.json.JsonConverter"
      }
      env {
        name  = "CONNECT_REST_ADVERTISED_HOST_NAME"
        value = "connect"
      }
      env {
        name  = "CONNECT_PLUGIN_PATH"
        value = "/kafka/plugins"
      }
      env {
        name  = "CLASSPATH"
        value = "/kafka/plugins/ojdbc8.jar,/kafka/plugins/postgresql-42.7.5.jar"
      }
      volume_mounts {
        name = azurerm_storage_share.fileshare.name
        path = "/mnt/${azurerm_storage_share.fileshare.name}"
      }
    }
    # container { # oracle
    #   name   = "oracle"
    #   image  = "oracleinanutshell/oracle-xe-11g"
    #   cpu    = 0.25
    #   memory = "0.5Gi"
    #   env {
    #     name  = "ORACLE_PASSWORD"
    #     value = "password"
    #   }
    #   env {
    #     name  = "ORACLE_ALLOW_REMOTE"
    #     value = "true"
    #   }
    # }
    # container { # postgres
    #   name   = "postgres"
    #   image  = "postgres:latest"
    #   cpu    = 0.25
    #   memory = "0.5Gi"
    #   env {
    #     name  = "POSTGRES_USER"
    #     value = "postgres"
    #   }
    #   env {
    #     name  = "POSTGRES_PASSWORD"
    #     value = "password"
    #   }
    #   env {
    #     name  = "POSTGRES_DB"
    #     value = "microhack"
    #   }
    # }
  }
}


resource "azurerm_container_app" "container_app_ora2pg" {
  #depends_on                   = [azurerm_container_app.container_app_zookeeper]
  name                         = "${var.prefix}-ora2pg"
  container_app_environment_id = azurerm_container_app_environment.aca.id
  resource_group_name          = azurerm_resource_group.rg.name
  # location            = azurerm_resource_group.rg.location
  revision_mode         = "Single"
  workload_profile_name = "${var.prefix}D8"
  # count                 = 1
  #ingress {
  #  transport        = "tcp"
  #  external_enabled = true
  #  target_port      = 9092
  #  exposed_port     = 9092
  #  traffic_weight {
  #    # label = "kafka"
  #    percentage      = 100
  #    revision_suffix = "kafka"
  #  }
  #}
  template {
    min_replicas = 1
    volume {
      name         = azurerm_storage_share.fileshare.name
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.acastorage.name
    }
    container { # ORA2PG
      name   = "ora2pg"
      image  = "georgmoser/ora2pg"
      cpu    = 0.25
      memory = "0.5Gi"
            env {
        name  = "ORACLE_DSN"
        value = "dbi:Oracle:host=oracle-xe1;sid=XE;port=1521"
      }
      env {
        name  = "ORA_USER"
        value = "demo_user"
      }
      env {
        name  = "ORA_PWD"
        value = "password"
      }
      env {
        name  = "CONFIG_LOCATION"
        value = "ora2pg/config/ora2pg.conf"
      }
      env {
        name  = "OUTPUT_LOCATION"
        value = "ora2pg/data"
      }
      volume_mounts {
        name = azurerm_storage_share.fileshare.name
        path = "/ora2pg"
      }
    }
  }
}