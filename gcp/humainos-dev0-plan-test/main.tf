# Live check of the DevSecOps platform on humainos-dev0 (devsecops-s9): a Cloud Function (2nd gen) built from a zip
# committed to this repository (files/devsecops-s9-fn.zip), in a bucket of its own. Created for the test, deleted after.

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "this" {}

resource "google_storage_bucket" "s9_fn_source" {
  name                        = "${var.project_id}-devsecops-s9-fn"
  location                    = "US"
  uniform_bucket_level_access = true
  force_destroy               = true
}

resource "google_storage_bucket_object" "s9_fn_source" {
  name   = "fn-${filemd5("${path.module}/files/devsecops-s9-fn.zip")}.zip"
  bucket = google_storage_bucket.s9_fn_source.name
  source = "${path.module}/files/devsecops-s9-fn.zip"
}

resource "google_cloudfunctions2_function" "s9" {
  name     = "devsecops-s9-fn"
  location = var.region

  build_config {
    runtime     = "nodejs20"
    entry_point = "hello"

    source {
      storage_source {
        bucket = google_storage_bucket.s9_fn_source.name
        object = google_storage_bucket_object.s9_fn_source.name
      }
    }
  }

  service_config {
    max_instance_count = 1
    available_memory   = "256M"
    timeout_seconds    = 60
  }
}

output "project_number" {
  value = data.google_project.this.number
}

output "function_uri" {
  value = google_cloudfunctions2_function.s9.service_config[0].uri
}
