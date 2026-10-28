# Step 8 acceptance test of the DevSecOps platform on humainos-dev0.
# Every resource here is a test resource named devsecops-s8-*, created for this test and deleted after it.
# Nothing outside this state is read for changes or touched.

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

resource "random_id" "s8" {
  byte_length = 3
}

# --- network -------------------------------------------------------------------------------------------------------

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

# Deliberately open to the internet on port 22, so the misconfiguration scan has something to report.
resource "google_compute_firewall" "s8_ssh_open" {
  name    = "devsecops-s8-ssh-open"
  network = google_compute_network.s8.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["devsecops-s8"]
}

# --- compute -------------------------------------------------------------------------------------------------------

resource "google_compute_disk" "s8_data" {
  name   = "devsecops-s8-data"
  type   = "pd-standard"
  zone   = local.zone
  size   = 10
  labels = local.labels
}

# Not attached to anything: the disk that the replace test changes.
resource "google_compute_disk" "s8_scratch" {
  name   = "devsecops-s8-scratch"
  type   = "pd-standard"
  zone   = local.zone
  size   = 10
  labels = local.labels
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

  attached_disk {
    source = google_compute_disk.s8_data.id
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

# --- DNS: a private name for the VM, so the deletion checks can find what points at it ------------------------------

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

# --- storage, messaging, identity, secrets ------------------------------------------------------------------------

resource "google_storage_bucket" "s8" {
  name                        = "devsecops-s8-${random_id.s8.hex}"
  location                    = "US-CENTRAL1"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true
  labels                      = local.labels
}

resource "google_storage_bucket_object" "s8_note" {
  name    = "notes/hello.txt"
  bucket  = google_storage_bucket.s8.name
  content = "DevSecOps step 8 test object.\n"
}

resource "google_pubsub_topic" "s8" {
  name   = "devsecops-s8-topic"
  labels = local.labels
}

resource "google_pubsub_subscription" "s8" {
  name   = "devsecops-s8-sub"
  topic  = google_pubsub_topic.s8.id
  labels = local.labels
}

resource "google_service_account" "s8" {
  account_id   = "devsecops-s8-sa"
  display_name = "DevSecOps step 8 test (safe to delete)"
}

resource "random_password" "s8" {
  length  = 24
  special = false
}

resource "google_secret_manager_secret" "s8" {
  secret_id = "devsecops-s8-secret"
  labels    = local.labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "s8" {
  secret      = google_secret_manager_secret.s8.id
  secret_data = random_password.s8.result
}

# --- Cloud SQL: the smallest instance, no backup retention yet (the first delete test expects the backup to be refused)

resource "google_sql_database_instance" "s8" {
  name                = "devsecops-s8-sql-${random_id.s8.hex}"
  database_version    = "MYSQL_8_0"
  region              = var.region
  deletion_protection = false

  settings {
    tier              = "db-f1-micro"
    edition           = "ENTERPRISE"
    availability_type = "ZONAL"
    disk_size         = 10
    disk_type         = "PD_HDD"
    user_labels       = local.labels

    ip_configuration {
      ipv4_enabled = true
      ssl_mode     = "ENCRYPTED_ONLY"
    }
  }
}

resource "google_sql_database" "s8_orders" {
  name     = "orders"
  instance = google_sql_database_instance.s8.name
}

output "project_number" {
  value = data.google_project.this.number
}

output "vm_internal_ip" {
  value = google_compute_instance.s8_vm.network_interface[0].network_ip
}
