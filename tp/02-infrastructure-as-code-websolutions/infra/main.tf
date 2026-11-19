locals {
  prefix    = "websolutions-${var.environment}"
  api_image = "${var.api_image_name}:${var.api_version}"
}

resource "docker_network" "app" {
  name = "${local.prefix}-net"
}

resource "docker_volume" "db" {
  name = "${local.prefix}-pgdata"
}

resource "docker_image" "postgres" {
  name         = "postgres:16-alpine"
  keep_locally = true
}

resource "docker_container" "db" {
  name    = "${local.prefix}-db"
  image   = docker_image.postgres.image_id
  restart = "unless-stopped"

  env = [
    "POSTGRES_DB=${var.db_name}",
    "POSTGRES_USER=${var.db_user}",
    "POSTGRES_PASSWORD=${var.db_password}",
  ]

  networks_advanced {
    name    = docker_network.app.name
    aliases = ["db"]
  }

  volumes {
    volume_name    = docker_volume.db.name
    container_path = "/var/lib/postgresql/data"
  }

  healthcheck {
    test     = ["CMD", "pg_isready", "-h", "127.0.0.1", "-U", var.db_user, "-d", var.db_name]
    interval = "3s"
    timeout  = "2s"
    retries  = 20
  }

  wait         = true
  wait_timeout = 90
}

resource "docker_container" "api" {
  name    = "${local.prefix}-api"
  image   = local.api_image
  restart = "unless-stopped"

  env = [
    "APP_VERSION=${var.api_version}",
    "DB_HOST=db",
    "DB_NAME=${var.db_name}",
    "DB_USER=${var.db_user}",
    "DB_PASSWORD=${var.db_password}",
  ]

  networks_advanced {
    name = docker_network.app.name
  }

  ports {
    internal = 3000
    external = var.api_port
    ip       = "127.0.0.1"
  }

  healthcheck {
    test     = ["CMD", "wget", "-qO-", "http://127.0.0.1:3000/health"]
    interval = "5s"
    timeout  = "2s"
    retries  = 12
  }

  wait         = true
  wait_timeout = 90

  depends_on = [docker_container.db]
}
