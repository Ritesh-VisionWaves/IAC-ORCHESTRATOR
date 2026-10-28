# Kubernetes runner check on humainos-dev0: one empty test network, planned and applied by a worker pod, then removed.

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "this" {}

resource "google_compute_network" "s8k" {
  name                    = "devsecops-s8k-net"
  auto_create_subnetworks = false
}

output "project_number" {
  value = data.google_project.this.number
}
