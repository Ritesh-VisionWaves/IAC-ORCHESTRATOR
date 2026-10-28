# Step 8 final check: a test network, a small VM and a private DNS name for it, to check the deletion facts take the
# rest of the plan into account. Every resource here is a devsecops-s8 test resource, deleted right after.

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "this" {}

locals {
  zone = "${var.region}-b"
  labels = {
    purpose = "devsecops-step8-test"
    owner   = "devsecops-platform"
  }
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
  tags         = ["devsecops-s8"]
  labels       = local.labels

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
      type  = "pd-standard"
    }
  }

  # No access_config: the VM has no external address.
  network_interface {
    subnetwork = google_compute_subnetwork.s8.id
  }

  shielded_instance_config {
    enable_secure_boot = true
  }

  metadata = {
    block-project-ssh-keys = "true"
  }
}

resource "google_dns_managed_zone" "s8" {
  name       = "devsecops-s8-zone"
  dns_name   = "s8.devsecops.internal."
  visibility = "private"
  labels     = local.labels

  private_visibility_config {
    networks {
      network_url = google_compute_network.s8.id
    }
  }
}

resource "google_dns_record_set" "s8_vm" {
  name         = "vm.s8.devsecops.internal."
  managed_zone = google_dns_managed_zone.s8.name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_instance.s8_vm.network_interface[0].network_ip]
}

output "project_number" {
  value = data.google_project.this.number
}
