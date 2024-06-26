resource "google_compute_region_instance_template" "webapp_template" {
  name_prefix  = "instance-template-"
  machine_type  = var.machine_type
  # provider = google-beta

  depends_on = [google_kms_crypto_key_iam_binding.compute_key_binding]
  tags = var.access_tags

  disk {
    source_image = var.image
    auto_delete  = true
    boot         = true
    disk_size_gb = var.disk_size
    disk_type    = var.type
    disk_encryption_key {
      kms_key_self_link = google_kms_crypto_key.compute_key.id
    }
  }

  region = var.region

  network_interface {
    network    = google_compute_network.cloud_app.id
    subnetwork = google_compute_subnetwork.webapp.id

    access_config {
      // Ephemeral IP will be assigned by GCP
    }
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    provisioning_model  = "STANDARD"
  }

  lifecycle {
    create_before_destroy = true
  }

  service_account {
    email  = google_service_account.service_account.email
    scopes = var.scopes
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    if [ ! -f /etc/webapp.flag ]; then
      echo "DB_USER=webapp" > /etc/webapp.env
      echo "DB_PASSWORD=${random_password.db_password.result}" >> /etc/webapp.env
      echo "DB_NAME=webapp" >> /etc/webapp.env
      echo "DB_HOST=${google_sql_database_instance.webapp_instance.ip_address[0].ip_address}" >> /etc/webapp.env
      sudo chown csye6225:csye6225 /etc/systemd/system/webapp.service
      sudo touch /etc/webapp.flag
    else
      echo "/etc/webapp.flag exists, skipping script execution."
    fi
  EOT
}

resource "google_compute_region_instance_group_manager" "webapp_group" {
  name               = "webapp-group-manager"
  base_instance_name = "webapp-vm"
  region           = var.region

  version {
    instance_template = google_compute_region_instance_template.webapp_template.id
  }

  named_port {
    name = "http"
    port = 8080
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.webapp_health_check.id
    initial_delay_sec = 180
  }

  # # distribution_policy_zones  = [var.zone]
  # distribution_policy_zones = ["us-east1-b", "us-east1-c"]

  # distribution_policy_target_shape = "BALANCED"

  # update_policy {
  #   type                         = "PROACTIVE"
  #   instance_redistribution_type = "NONE"
  #   minimal_action               = "REPLACE"
  #   max_surge_fixed              = 3
  # }
}

resource "google_compute_region_autoscaler" "webapp_autoscaler" {
  name   = "webapp-autoscaler"
  # zone   = var.zone
  region = var.region
  target = google_compute_region_instance_group_manager.webapp_group.self_link

  autoscaling_policy {
    max_replicas    = var.max_replicas
    min_replicas    = var.min_replicas
    cooldown_period = 300

    cpu_utilization {
      target = var.target
    }
  }

  # depends_on = [ google_compute_region_instance_group_manager.webapp_group ]
}
