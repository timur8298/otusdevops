terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}
provider "yandex" {
  service_account_key_file = var.service_account_key_file
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = var.zone
}

resource "yandex_kubernetes_cluster" "testkube" {
  network_id = var.network_id
  master {
    version = "1.23"
    zonal {
      zone      = var.zone
      subnet_id = var.subnet_id
    }
    public_ip = true
  }
  name                    = "testkube"
  service_account_id      = var.k8s_account_id
  node_service_account_id = var.k8s_account_id
}

resource "yandex_kubernetes_node_group" "test-group" {
  cluster_id = yandex_kubernetes_cluster.testkube.id
  name       = "test-group"
  version    = "1.23"

  instance_template {
    platform_id = "standard-v2"

    network_interface {
      nat        = true
      subnet_ids = [var.subnet_id]
    }

    resources {
      cores         = 4
      memory        = 12
      core_fraction = 100
    }

    scheduling_policy {
      preemptible = true
    }

    boot_disk {
      type = "network-ssd-nonreplicated"
      size = 93
    }

    container_runtime {
      type = "containerd"
    }

    metadata = {
      ssh-keys = "ubuntu:${file(var.public_key_path)}"
    }
  }
  scale_policy {
    fixed_scale {
      size = var.nodes
    }
  }
}
