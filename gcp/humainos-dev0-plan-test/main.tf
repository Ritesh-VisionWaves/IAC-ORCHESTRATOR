# DevSecOps IaC demo on humainos-dev0, stage 2 of 3: change it in place - a bigger VM (Compute Engine stops it),
# a lifecycle rule that deletes old exports, a longer ack deadline.
# Test resources only (prefix devsecops-demo); stage 3 deletes every one of them.

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "this" {}

locals {
  zone   = "${var.region}-a"
  labels = { purpose = "devsecops-demo", stage = "two" }
}

resource "google_compute_network" "demo" {
  name                    = "devsecops-demo-net"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "demo" {
  name          = "devsecops-demo-subnet"
  network       = google_compute_network.demo.id
  ip_cidr_range = "10.120.0.0/24"
}

resource "google_service_account" "demo" {
  account_id   = "devsecops-demo-app"
  display_name = "DevSecOps demo: order export app"
}

resource "google_compute_instance" "demo" {
  name                      = "devsecops-demo-vm"
  zone                      = local.zone
  machine_type              = "e2-small"
  allow_stopping_for_update = true
  labels                    = local.labels

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.demo.id
  }

  service_account {
    email  = google_service_account.demo.email
    scopes = ["cloud-platform"]
  }
}

resource "google_storage_bucket" "demo" {
  name                        = "${var.project_id}-devsecops-demo"
  location                    = "US-CENTRAL1"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true
  labels                      = local.labels

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_storage_bucket_object" "orders" {
  bucket  = google_storage_bucket.demo.name
  name    = "exports/orders-2026-10.csv"
  content = "order_id,customer,amount_inr\n1001,acme,2500\n1002,globex,1800\n1003,initech,4200\n"
}

resource "google_pubsub_topic" "orders" {
  name   = "devsecops-demo-orders"
  labels = local.labels
}

resource "google_pubsub_subscription" "billing" {
  name                       = "devsecops-demo-orders-billing"
  topic                      = google_pubsub_topic.orders.id
  ack_deadline_seconds       = 30
  message_retention_duration = "86400s"
  labels                     = local.labels
}

output "bucket" {
  value = google_storage_bucket.demo.url
}
