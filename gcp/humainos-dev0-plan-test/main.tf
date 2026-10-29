# Live check of the DevSecOps platform on humainos-dev0 (devsecops-s9): every test resource removed. files/ keeps the
# function zip for later checks.

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "this" {}

output "project_number" {
  value = data.google_project.this.number
}
