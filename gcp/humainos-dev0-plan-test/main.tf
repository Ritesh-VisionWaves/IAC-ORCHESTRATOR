# Live check of the DevSecOps platform on humainos-dev0 (devsecops-s11): the new readers. A Basic Redis that a small VM
# fills with 500 keys, and a GKE cluster whose workloads are added through its own API during the test. Test resources
# only: created for the check, deleted after it.

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "this" {}

locals {
  zone = "${var.region}-a"
}

resource "google_compute_network" "s11" {
  name                    = "devsecops-s11-net"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "s11" {
  name          = "devsecops-s11-subnet"
  network       = google_compute_network.s11.id
  ip_cidr_range = "10.110.0.0/20"

  secondary_ip_range {
    range_name    = "devsecops-s11-pods"
    ip_cidr_range = "10.114.0.0/16"
  }

  secondary_ip_range {
    range_name    = "devsecops-s11-services"
    ip_cidr_range = "10.115.0.0/20"
  }
}

resource "google_redis_instance" "s11" {
  name               = "devsecops-s11-redis"
  tier               = "BASIC"
  memory_size_gb     = 1
  region             = var.region
  authorized_network = google_compute_network.s11.id
}

# Writes 500 keys into the Redis above once, at boot (it needs the internet for redis-tools: an ephemeral address).
resource "google_compute_instance" "s11_writer" {
  name         = "devsecops-s11-writer"
  zone         = local.zone
  machine_type = "e2-micro"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.s11.id

    access_config {}
  }

  metadata = {
    startup-script = <<-EOT
      #!/bin/bash
      apt-get update -y && apt-get install -y redis-tools
      for i in $(seq 1 500); do
        redis-cli -h ${google_redis_instance.s11.host} -p ${google_redis_instance.s11.port} SET "devsecops:s11:key:$i" "value-$i" > /dev/null
      done
      redis-cli -h ${google_redis_instance.s11.host} -p ${google_redis_instance.s11.port} DBSIZE > /var/log/devsecops-s11-keys.txt
    EOT
  }
}

resource "google_container_cluster" "s11" {
  name                     = "devsecops-s11-gke"
  location                 = local.zone
  network                  = google_compute_network.s11.id
  subnetwork               = google_compute_subnetwork.s11.id
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  ip_allocation_policy {
    cluster_secondary_range_name  = "devsecops-s11-pods"
    services_secondary_range_name = "devsecops-s11-services"
  }
}

resource "google_container_node_pool" "s11" {
  name       = "devsecops-s11-pool"
  cluster    = google_container_cluster.s11.id
  location   = local.zone
  node_count = 1

  node_config {
    machine_type = "e2-medium"
    disk_size_gb = 20
    disk_type    = "pd-standard"
  }
}

output "project_number" {
  value = data.google_project.this.number
}
