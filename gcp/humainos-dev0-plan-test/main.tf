# Plan-only test of the DevSecOps platform's Terraform runs on humainos-dev0.
# v3 (cleanup): the test network and subnet are removed, so the project is back to what it was before the test.

provider "google" {
  project = var.project_id
  region  = var.region
}

# Read only: proves the platform's identity can see the project.
data "google_project" "this" {}

output "project_number" {
  value = data.google_project.this.number
}
