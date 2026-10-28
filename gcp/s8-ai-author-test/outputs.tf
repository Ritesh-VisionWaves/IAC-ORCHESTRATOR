output "logs_bucket_name" {
  description = "Name of the logs Cloud Storage bucket."
  value       = google_storage_bucket.logs.name
}

output "logs_bucket_url" {
  description = "gs:// URL of the logs Cloud Storage bucket."
  value       = google_storage_bucket.logs.url
}
