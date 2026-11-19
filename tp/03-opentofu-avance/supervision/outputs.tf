output "urls" {
  description = "Interfaces publiées sur la boucle locale."
  value = {
    for name, svc in local.services : name => "http://localhost:${svc.port}"
    if svc.port != null
  }
}
