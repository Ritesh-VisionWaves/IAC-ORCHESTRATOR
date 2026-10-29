# Kubernetes runner check on humainos-dev0: the test network removed again. Applying this deletes only what this state
# holds - the test network devsecops-s8k-net.

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "this" {}

output "project_number" {
  value = data.google_project.this.number
}
