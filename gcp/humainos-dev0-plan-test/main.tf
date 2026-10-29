# Live check of the DevSecOps platform on humainos-dev0 (devsecops-s9): every s9 test resource removed except the KMS
# key ring and key, which Google never deletes and the platform refuses to destroy; they leave Terraform's state by hand.

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "this" {}

resource "google_kms_key_ring" "s9" {
  name     = "devsecops-s9-ring"
  location = var.region
}

resource "google_kms_crypto_key" "s9" {
  name            = "devsecops-s9-key"
  key_ring        = google_kms_key_ring.s9.id
  rotation_period = "7776000s"
}

output "project_number" {
  value = data.google_project.this.number
}
