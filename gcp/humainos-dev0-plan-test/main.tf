# DevSecOps IaC demo on humainos-dev0, stage 3 of 3: delete everything the demo created.

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "this" {}

output "project_number" {
  value = data.google_project.this.number
}
