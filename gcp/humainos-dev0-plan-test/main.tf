# Plan-only test of the DevSecOps platform's Terraform runs on a read-only (Viewer) connector.
# Nothing here is ever applied: Google would refuse the write, and the run is not approved.

provider "google" {
  project = var.project_id
  region  = var.region
}

# Read only: proves the platform's identity can see the project.
data "google_project" "this" {}

# Planned, never applied.
resource "google_compute_network" "plan_test" {
  name                    = "devsecops-plan-test"
  auto_create_subnetworks = false
  description             = "Plan-only test of the DevSecOps platform; not applied"
}

output "project_number" {
  value = data.google_project.this.number
}

# v2 (rollback test): one small subnet in the test network only. Free; removed again by rolling back to run #1.
resource "google_compute_subnetwork" "plan_test" {
  name                     = "devsecops-plan-test-subnet"
  ip_cidr_range            = "10.250.0.0/28"
  region                   = var.region
  network                  = google_compute_network.plan_test.id
  private_ip_google_access = true
}
