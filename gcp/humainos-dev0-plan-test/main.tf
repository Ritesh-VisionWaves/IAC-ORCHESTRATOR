# Internal network for integration tests.

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "this" {}

resource "google_compute_network" "s8h" {
  name                    = "devsecops-s8h-net"
  auto_create_subnetworks = false
}

resource "google_compute_firewall" "s8_mysql_open" {
  name    = "devsecops-s8h-mysql-open"
  network = google_compute_network.s8h.id

  allow {
    protocol = "tcp"
    ports    = ["3306"]
  }

  source_ranges = ["0.0.0.0/0"]
}

output "project_number" {
  value = data.google_project.this.number
}
