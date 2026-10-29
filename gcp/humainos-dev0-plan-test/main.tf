# Live check of the DevSecOps platform on humainos-dev0 (devsecops-s9): a Cloud Function (2nd gen) packaged by Terraform
# (archive_file) into a bucket of its own; an update raises its memory. Created for the test, deleted after.

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

# Packaged by Terraform from sources written in the code (archive_file), the usual way to ship a function.
data "archive_file" "s9_fn" {
  type        = "zip"
  output_path = "${path.module}/.build/devsecops-s9-fn.zip"

  source {
    filename = "index.js"
    content  = "exports.hello = (req, res) => { res.send('devsecops s9, packaged by archive_file'); };\n"
  }

  source {
    filename = "package.json"
    content  = jsonencode({ name = "devsecops-s9-fn", version = "1.1.0", main = "index.js" })
  }
}

resource "google_storage_bucket_object" "s9_fn_source" {
  name   = "fn-${data.archive_file.s9_fn.output_md5}.zip"
  bucket = google_storage_bucket.s9_fn_source.name
  source = data.archive_file.s9_fn.output_path
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
    available_memory   = "512M"
    timeout_seconds    = 60
  }
}

output "project_number" {
  value = data.google_project.this.number
}

output "function_uri" {
  value = google_cloudfunctions2_function.s9.service_config[0].uri
}
