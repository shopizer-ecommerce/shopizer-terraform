variable "keycloak_url" {
  description = "Base URL of the Keycloak server"
  type        = string
  default     = "http://localhost:8080"
}

variable "keycloak_username" {
  description = "Keycloak admin username"
  type        = string
  default     = "admin"
}

variable "keycloak_password" {
  description = "Keycloak admin password"
  type        = string
  sensitive   = true
  default     = "master"
}

variable "realm_name" {
  description = "Name of the realm to create"
  type        = string
  default     = "shopizer"
}

variable "client_id" {
  description = "Client ID"
  type        = string
  default     = "shopizer"
}

variable "client_name" {
  description = "Display name of the client"
  type        = string
  default     = "shopizer"
}

variable "client_secret" {
  description = "Client secret"
  type        = string
  sensitive   = true
  default     = "shopizer"
}

variable "admin_username" {
  description = "Admin user email/username"
  type        = string
  default     = "admin@shopizer.com"
}

variable "admin_password" {
  description = "Password for the admin user"
  type        = string
  sensitive   = true
  default     = "Admin123"
}
