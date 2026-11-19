variable "sonar_db_password" {
  description = "Mot de passe du compte PostgreSQL sonar (laboratoire uniquement)."
  type        = string
  sensitive   = true
}

variable "postgres_port" {
  description = "Port publié sur 127.0.0.1 pour PostgreSQL (5432 si aucun PostgreSQL local ne l'occupe)."
  type        = number
  default     = 5432
}
