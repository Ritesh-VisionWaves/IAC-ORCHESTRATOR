# Step 8 Cloud Asset check on humainos-dev0: a test service account, and a small test VM that runs as it. The VM names the
# account by its email as plain text, so Terraform does not know the VM depends on it. Deleting only the account must
# still show that the VM uses it. Every resource here is a devsecops-s8 test resource, deleted right after the check.

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "this" {}

locals {
  zone     = "${var.region}-b"
  sa_email = "devsecops-s8-sa@${var.project_id}.iam.gserviceaccount.com"
  labels = {
    purpose = "devsecops-step8-test"
    owner   = "devsecops-platform"
  }
}

resource "google_service_account" "s8" {
  account_id   = "devsecops-s8-sa"
  display_name = "DevSecOps step 8 test (safe to delete)"
}

resource "google_compute_network" "s8" {
  name                    = "devsecops-s8-net"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "s8" {
  name                     = "devsecops-s8-subnet"
  ip_cidr_range            = "10.98.0.0/24"
  region                   = var.region
  network                  = google_compute_network.s8.id
  private_ip_google_access = true
}

resource "google_compute_instance" "s8_vm" {
  name         = "devsecops-s8-vm"
  machine_type = "e2-micro"
  zone         = local.zone
  labels       = local.labels

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.s8.id
  }

  # The account by its email only: Terraform does not see this as a dependency.
  service_account {
    email  = local.sa_email
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot = true
  }

  metadata = {
    block-project-ssh-keys = "true"
  }

  # Only so the account exists before the VM is created.
  depends_on = [google_service_account.s8]
}

output "project_number" {
  value = data.google_project.this.number
}
