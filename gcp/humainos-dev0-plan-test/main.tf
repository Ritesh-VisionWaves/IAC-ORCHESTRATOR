# Live check of the DevSecOps platform on humainos-dev0 (devsecops-s10): updates and replaces. Stage 1 creates small
# test resources; later stages change them in place, then force replaces, then delete everything. Test resources only.

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "this" {}

locals {
  zone   = "${var.region}-a"
  labels = { purpose = "devsecops-s10-live-check", stage = "one" }
}

resource "google_compute_network" "s10" {
  name                    = "devsecops-s10-net"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "s10" {
  name          = "devsecops-s10-subnet"
  network       = google_compute_network.s10.id
  ip_cidr_range = "10.100.0.0/20"

  secondary_ip_range {
    range_name    = "devsecops-s10-pods"
    ip_cidr_range = "10.104.0.0/16"
  }

  secondary_ip_range {
    range_name    = "devsecops-s10-services"
    ip_cidr_range = "10.105.0.0/20"
  }
}

resource "google_compute_firewall" "s10_internal" {
  name          = "devsecops-s10-internal"
  network       = google_compute_network.s10.id
  source_ranges = ["10.100.0.0/20"]

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }
}

resource "google_compute_disk" "s10_data" {
  name   = "devsecops-s10-data"
  zone   = local.zone
  size   = 10
  type   = "pd-standard"
  labels = local.labels
}

resource "google_compute_instance" "s10_vm" {
  name                      = "devsecops-s10-vm"
  zone                      = local.zone
  machine_type              = "e2-micro"
  allow_stopping_for_update = true
  labels                    = local.labels

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
    }
  }

  attached_disk {
    source = google_compute_disk.s10_data.id
  }

  network_interface {
    subnetwork = google_compute_subnetwork.s10.id
  }
}

resource "google_storage_bucket" "s10" {
  name                        = "${var.project_id}-devsecops-s10"
  location                    = "US"
  uniform_bucket_level_access = true
  force_destroy               = true
  labels                      = local.labels
}

resource "google_cloud_run_v2_service" "s10" {
  name                = "devsecops-s10-run"
  location            = var.region
  deletion_protection = false

  template {
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"
    }
  }

  lifecycle {
    ignore_changes = [scaling]
  }
}

resource "google_container_cluster" "s10" {
  name                     = "devsecops-s10-gke"
  location                 = local.zone
  network                  = google_compute_network.s10.id
  subnetwork               = google_compute_subnetwork.s10.id
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  ip_allocation_policy {
    cluster_secondary_range_name  = "devsecops-s10-pods"
    services_secondary_range_name = "devsecops-s10-services"
  }
}

resource "google_container_node_pool" "s10" {
  name       = "devsecops-s10-pool"
  cluster    = google_container_cluster.s10.id
  location   = local.zone
  node_count = 1

  node_config {
    machine_type = "e2-medium"
    disk_size_gb = 20
    disk_type    = "pd-standard"
  }
}

resource "google_redis_instance" "s10" {
  name               = "devsecops-s10-redis"
  tier               = "BASIC"
  memory_size_gb     = 1
  region             = var.region
  authorized_network = google_compute_network.s10.id
}

resource "google_sql_database_instance" "s10" {
  name                = "devsecops-s10-sql"
  database_version    = "MYSQL_8_0"
  region              = var.region
  deletion_protection = false

  settings {
    tier      = "db-f1-micro"
    edition   = "ENTERPRISE"
    disk_size = 10

    backup_configuration {
      enabled = true
    }
  }
}

resource "google_bigquery_dataset" "s10" {
  dataset_id                 = "devsecops_s10"
  location                   = "US"
  delete_contents_on_destroy = true
}

resource "google_bigquery_table" "s10_events" {
  dataset_id          = google_bigquery_dataset.s10.dataset_id
  table_id            = "events"
  deletion_protection = false

  schema = jsonencode([
    { name = "id", type = "INTEGER", mode = "REQUIRED" },
    { name = "kind", type = "STRING", mode = "NULLABLE" },
    { name = "happened", type = "TIMESTAMP", mode = "NULLABLE" },
  ])
}

resource "google_pubsub_topic" "s10" {
  name = "devsecops-s10-topic"
}

resource "google_pubsub_subscription" "s10" {
  name                 = "devsecops-s10-sub"
  topic                = google_pubsub_topic.s10.id
  ack_deadline_seconds = 20
}

output "project_number" {
  value = data.google_project.this.number
}
