provider "google" {
  project = var.project
  region  = var.region
}
abc

resource "google_compute_network" "cloud_app" {
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  delete_default_routes_on_create = true
}

resource "google_compute_subnetwork" "webapp" {
  name          = var.webapp_subnet_name
  ip_cidr_range = var.webapp_subnet_cidr
  region        = var.region
  network       = google_compute_network.cloud_app.self_link
}

resource "google_compute_subnetwork" "db" {
  name          = var.db_subnet_name
  ip_cidr_range = var.db_subnet_cidr
  region        = var.region
  network       = google_compute_network.cloud_app.self_link
}

resource "google_compute_route" "webapp_internet" {
  name            = var.internet_route_name
  dest_range      = "0.0.0.0/0"
  network         = google_compute_network.cloud_app.name
  next_hop_gateway = "default-internet-gateway"
  priority        = var.internet_route_priority
  tags            = var.internet_access_tags
}

