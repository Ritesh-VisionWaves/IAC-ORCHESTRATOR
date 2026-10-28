# Step 8 pre-check test: this commit breaks each new pre-check rule on purpose. The platform must refuse it before
# Terraform runs, so nothing here ever reaches Google Cloud. The next commit removes it.

provider "google" {
  project = var.project_id
  region  = var.region

  # Refused: an endpoint override off googleapis.com would receive the run's Google token.
  compute_custom_endpoint = "https://compute.example.com/compute/v1/"
}

provider "google-beta" {
  project = var.project_id

  # Refused: another Google Cloud universe.
  universe_domain = "example-universe.test"
}

variable "test_password" {
  description = "A made-up value for the pre-check test; not a real secret."
  type        = string
  sensitive   = true
  default     = "not-a-real-secret-step8-test"
}

# Refused: nonsensitive() would print the value in the plan.
output "unwrapped" {
  value = nonsensitive(var.test_password)
}

# Refused: reads a certificate from a URL, a connection from inside the platform.
data "tls_certificate" "probe" {
  url = "https://example.com"
}

# Refused: remote state from a backend other than GCS.
data "terraform_remote_state" "elsewhere" {
  backend = "http"
  config = {
    address = "https://example.com/state"
  }
}

data "google_project" "this" {}

output "project_number" {
  value = data.google_project.this.number
}
