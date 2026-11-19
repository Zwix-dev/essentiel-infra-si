variable "vm_host" {
  description = "Adresse de la VM de test (réseau privé hôte)"
  type        = string
  default     = "192.168.56.20"
}

variable "vm_user" {
  description = "Compte SSH de la VM, membre du groupe docker"
  type        = string
  default     = "vboxuser"
}

variable "environment" {
  description = "Nom de l'environnement, utilisé comme préfixe des ressources"
  type        = string
  default     = "test"
}

variable "api_image_name" {
  description = "Nom de l'image de l'API construite sur la VM"
  type        = string
  default     = "websolutions-api"
}

variable "api_version" {
  description = "Tag de l'image à déployer (SHA court du commit)"
  type        = string
}

variable "api_port" {
  description = "Port de l'API sur la boucle locale de la VM, cible du reverse proxy Nginx"
  type        = number
  default     = 3000
}

variable "db_name" {
  type    = string
  default = "websolutions"
}

variable "db_user" {
  type    = string
  default = "websolutions"
}

variable "db_password" {
  description = "Mot de passe PostgreSQL (terraform.tfvars local ou secret du pipeline)"
  type        = string
  sensitive   = true
}
