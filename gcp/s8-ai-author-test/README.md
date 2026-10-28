# DevSecOps Step 8 - AI Logs Bucket

This Terraform configuration creates a private Cloud Storage bucket for application logs in `us-central1` with object versioning enabled, uniform bucket-level access, public access prevention enforced, and a lifecycle rule that deletes objects older than 30 days.

## Resources

- `google_storage_bucket.logs` – Log bucket with 30-day retention via lifecycle rule and required security settings.
- `random_id.logs_bucket_suffix` – Random suffix used to ensure the bucket name is globally unique.

## Usage

1. Ensure you have Terraform 1.5.7+ and access to the `humainos-dev0` project.
2. Review `terraform.tfvars.example`, copy it to `terraform.tfvars`, and adjust values if needed.
3. Run:

```sh
terraform init
terraform plan
terraform apply
```

## Variables

- `project_id` – GCP project ID (default: `humainos-dev0`).
- `region` – Default region for resources (default: `us-central1`).
- `labels` – Map of labels applied to all resources (default includes `purpose=devsecops-step8-test`).
