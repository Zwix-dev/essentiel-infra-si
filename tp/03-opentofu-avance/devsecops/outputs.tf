output "urls" {
  description = "Interfaces publiées sur la boucle locale."
  value = {
    gitea    = "http://localhost:3000"
    jenkins  = "http://localhost:8080"
    sonar    = "http://localhost:9000"
    postgres = "127.0.0.1:${var.postgres_port}"
  }
}

output "volumes" {
  description = "Volumes gérés par OpenTofu (supprimés par le plan de destruction)."
  value       = [for v in docker_volume.data : v.name]
}
