terraform {
  required_version = ">= 1.8"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.7.0"
    }
  }

  # Chemin de l'état fourni à l'init : -backend-config="path=..."
  # Il est placé hors du dépôt pour être partagé entre les exécutions manuelles et le runner.
  backend "local" {}
}

# Le fournisseur pilote le moteur Docker de la VM de test à travers SSH.
provider "docker" {
  host     = "ssh://${var.vm_user}@${var.vm_host}:22"
  ssh_opts = ["-o", "BatchMode=yes", "-o", "ConnectTimeout=10"]
}
