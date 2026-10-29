# Live check of the DevSecOps platform on humainos-dev0 (devsecops-s9): every s9 test resource removed. The KMS key ring
# and key (devsecops-s9-ring / devsecops-s9-key) cannot be deleted in Google Cloud; they left Terraform's state by hand,
# with rotation off and their only version disabled. files/devsecops-s9-fn.zip waits for the Cloud Functions check.

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "this" {}

output "project_number" {
  value = data.google_project.this.number
}
