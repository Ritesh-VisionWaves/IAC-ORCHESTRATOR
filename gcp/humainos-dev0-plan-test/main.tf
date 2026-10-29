# Live check of the DevSecOps platform on humainos-dev0 (devsecops-s9): one of each type not tested yet - a small GKE
# cluster, a Cloud Run service behind an HTTP load balancer, Redis and a BigQuery table - on a network of their own.
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

output "project_number" {
  value = data.google_project.this.number
}

output "load_balancer_ip" {
  value = google_compute_global_forwarding_rule.s9.ip_address
}
