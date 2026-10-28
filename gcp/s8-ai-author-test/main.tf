resource "random_id" "logs_bucket_suffix" {
  byte_length = 4
}

resource "google_storage_bucket" "logs" {
  name     = "devsecops-s8-ai-logs-${random_id.logs_bucket_suffix.hex}"
  location = upper(var.region)

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }

    condition {
      age = 30
    }
  }

  labels = var.labels
}
