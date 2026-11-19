output "web_url" {
  description = "Point d'entrée public (Nginx sur la VM)"
  value       = "http://${var.vm_host}/"
}

output "health_url" {
  description = "Route de santé contrôlée par le pipeline"
  value       = "http://${var.vm_host}/health"
}

output "deployed_image" {
  description = "Image de l'API actuellement déployée"
  value       = local.api_image
}

output "api_upstream" {
  description = "Adresse de l'API vue depuis la VM (cible de Nginx)"
  value       = "http://127.0.0.1:${var.api_port}"
}

output "db_volume" {
  description = "Volume à sauvegarder avant toute destruction"
  value       = docker_volume.db.name
}
