# Apply-readiness live check (batch 4) on humainos-dev0: PLAN ONLY - the run is discarded, never applied.
# Each resource is here to make one readiness check speak:
#   name_free        - a network named humainos-vpc, which the project already has outside this workspace's state
#   apply_permissions - an IAM member on a Pub/Sub subscription (run #57 failed at apply on exactly this)
#   apis_enabled     - a Memorystore Redis instance (its API may be off in this project)
#   project_ready    - the project itself (billing, not marked for deletion)

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "this" {}

resource "google_compute_network" "taken_name" {
  name                    = "humainos-vpc"
  auto_create_subnetworks = false
}

resource "google_pubsub_topic" "ready" {
  name   = "devsecops-ready-topic"
  labels = { purpose = "devsecops-readiness-check" }
}

resource "google_pubsub_subscription" "ready" {
  name  = "devsecops-ready-sub"
  topic = google_pubsub_topic.ready.id
}

resource "google_pubsub_subscription_iam_member" "ready" {
  subscription = google_pubsub_subscription.ready.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${data.google_project.this.number}-compute@developer.gserviceaccount.com"
}

resource "google_redis_instance" "ready" {
  name           = "devsecops-ready-redis"
  memory_size_gb = 1
  region         = var.region
}

output "project_number" {
  value = data.google_project.this.number
}
