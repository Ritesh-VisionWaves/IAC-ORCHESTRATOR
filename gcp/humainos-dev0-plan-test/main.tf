# Live check of the DevSecOps platform on humainos-dev0 (devsecops-s9): one of each type not tested yet - a small GKE
# cluster, a Cloud Run service behind an HTTP load balancer, Redis, a BigQuery table, a KMS key, a Cloud Function and a
# Cloud SQL database - on a network of their own.
# Every resource here is created for the test and deleted after it; nothing refers to the project's own resources.

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "this" {}

locals {
  zone = "${var.region}-a"
}

resource "google_compute_network" "s9" {
  name                    = "devsecops-s9-net"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "s9" {
  name          = "devsecops-s9-subnet"
  network       = google_compute_network.s9.id
  ip_cidr_range = "10.90.0.0/20"

  secondary_ip_range {
    range_name    = "devsecops-s9-pods"
    ip_cidr_range = "10.94.0.0/16"
  }

  secondary_ip_range {
    range_name    = "devsecops-s9-services"
    ip_cidr_range = "10.95.0.0/20"
  }
}

# GKE: one zonal cluster with a single small node, VPC-native on the test subnet.
resource "google_container_cluster" "s9" {
  name                = "devsecops-s9-gke"
  location            = local.zone
  network             = google_compute_network.s9.id
  subnetwork          = google_compute_subnetwork.s9.id
  initial_node_count  = 1
  deletion_protection = false

  ip_allocation_policy {
    cluster_secondary_range_name  = "devsecops-s9-pods"
    services_secondary_range_name = "devsecops-s9-services"
  }

  node_config {
    machine_type = "e2-medium"
    disk_size_gb = 20
    disk_type    = "pd-standard"
  }
}

# Cloud Run: Google's sample container, reached through the load balancer below.
resource "google_cloud_run_v2_service" "s9" {
  name                = "devsecops-s9-run"
  location            = var.region
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"

  template {
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"
    }
  }

  # Google reports an empty scaling block back that the code does not set (provider 6.x): not a change of ours.
  lifecycle {
    ignore_changes = [scaling]
  }
}

# A global HTTP load balancer in front of the Cloud Run service.
resource "google_compute_region_network_endpoint_group" "s9" {
  name                  = "devsecops-s9-neg"
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_v2_service.s9.name
  }
}

resource "google_compute_backend_service" "s9" {
  name                  = "devsecops-s9-backend"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTP"

  backend {
    group = google_compute_region_network_endpoint_group.s9.id
  }
}

resource "google_compute_url_map" "s9" {
  name            = "devsecops-s9-lb"
  default_service = google_compute_backend_service.s9.id
}

resource "google_compute_target_http_proxy" "s9" {
  name    = "devsecops-s9-proxy"
  url_map = google_compute_url_map.s9.id
}

resource "google_compute_global_forwarding_rule" "s9" {
  name                  = "devsecops-s9-http"
  target                = google_compute_target_http_proxy.s9.id
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# Redis: the smallest Basic tier instance on the test network.
resource "google_redis_instance" "s9" {
  name               = "devsecops-s9-redis"
  tier               = "BASIC"
  memory_size_gb     = 1
  region             = var.region
  authorized_network = google_compute_network.s9.id
}

# BigQuery: a dataset with one table; rows are added by hand during the test, so the delete has data to report.
resource "google_bigquery_dataset" "s9" {
  dataset_id = "devsecops_s9"
  location   = "US"
}

resource "google_bigquery_table" "s9_events" {
  dataset_id          = google_bigquery_dataset.s9.dataset_id
  table_id            = "events"
  deletion_protection = false

  schema = jsonencode([
    { name = "id", type = "INTEGER", mode = "REQUIRED" },
    { name = "kind", type = "STRING", mode = "NULLABLE" },
    { name = "at", type = "TIMESTAMP", mode = "NULLABLE" },
  ])
}

# KMS: a key ring and a key. Google never deletes either (only key versions), so these two stay in the project.
resource "google_kms_key_ring" "s9" {
  name     = "devsecops-s9-ring"
  location = var.region
}

resource "google_kms_crypto_key" "s9" {
  name            = "devsecops-s9-key"
  key_ring        = google_kms_key_ring.s9.id
  rotation_period = "7776000s"
}

# Cloud Functions (2nd gen): a tiny HTTP function from a zip kept in this repository (files/), in a bucket of its own.
resource "google_storage_bucket" "s9_fn_source" {
  name                        = "${var.project_id}-devsecops-s9-fn"
  location                    = "US"
  uniform_bucket_level_access = true
  force_destroy               = true
}

resource "google_storage_bucket_object" "s9_fn_source" {
  name   = "fn-${filemd5("${path.module}/files/devsecops-s9-fn.zip")}.zip"
  bucket = google_storage_bucket.s9_fn_source.name
  source = "${path.module}/files/devsecops-s9-fn.zip"
}

resource "google_cloudfunctions2_function" "s9" {
  name     = "devsecops-s9-fn"
  location = var.region

  build_config {
    runtime     = "nodejs20"
    entry_point = "hello"

    source {
      storage_source {
        bucket = google_storage_bucket.s9_fn_source.name
        object = google_storage_bucket_object.s9_fn_source.name
      }
    }
  }

  service_config {
    max_instance_count = 1
    available_memory   = "256M"
    timeout_seconds    = 60
  }
}

# Cloud SQL: the smallest MySQL with backups on, reachable only from the dev cluster and the tester's machine. Its
# tables are made by hand during the test and it is registered in Database DevOps, so a delete shows its tables.
resource "google_sql_database_instance" "s9" {
  name                = "devsecops-s9-sql"
  database_version    = "MYSQL_8_0"
  region              = var.region
  deletion_protection = false

  settings {
    tier      = "db-f1-micro"
    edition   = "ENTERPRISE"
    disk_size = 10

    backup_configuration {
      enabled            = true
      binary_log_enabled = true
    }

    ip_configuration {
      ipv4_enabled = true
      ssl_mode     = "ALLOW_UNENCRYPTED_AND_ENCRYPTED"

      authorized_networks {
        name  = "devsecops-dev-cluster"
        value = "47.247.172.146/32"
      }

      authorized_networks {
        name  = "devsecops-tester"
        value = "14.195.204.158/32"
      }
    }
  }
}

resource "google_sql_database" "s9_shop" {
  name     = "s9_shop"
  instance = google_sql_database_instance.s9.name
}

output "project_number" {
  value = data.google_project.this.number
}

output "load_balancer_ip" {
  value = google_compute_global_forwarding_rule.s9.ip_address
}

output "sql_public_ip" {
  value = google_sql_database_instance.s9.public_ip_address
}
