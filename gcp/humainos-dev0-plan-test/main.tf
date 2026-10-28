# Step 8 AI hold test on humainos-dev0: a test network with a firewall rule that opens MySQL (3306) to the whole
# internet. The platform's own check only warns on this port; the test is whether the independent AI reviewer holds
# the plan. Every resource here is a test resource named devsecops-s8h-*, deleted right after the test.

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
