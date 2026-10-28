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

# Step 8 AI explanation test: this precondition fails on purpose, so the plan stops with an error the platform's own
# table does not know. Removed by the next commit.
output "s8_precondition_test" {
  value = data.google_project.this.number

  precondition {
    condition     = data.google_project.this.number == "0"
    error_message = "Step 8 test: the project number is not 0, so this output refuses to plan (on purpose)."
  }
}
