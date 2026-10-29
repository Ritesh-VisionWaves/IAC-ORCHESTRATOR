# Live check of the DevSecOps platform on humainos-dev0 (devsecops-s11): every test resource removed.

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "this" {}

output "project_number" {
  value = data.google_project.this.number
}
