# Step 8 acceptance test of the DevSecOps platform on humainos-dev0: every devsecops-s8 test resource removed.
# Applying this deletes only what this state holds - the test resources - after the deletion checks and safety nets.

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "this" {}

output "project_number" {
  value = data.google_project.this.number
}
