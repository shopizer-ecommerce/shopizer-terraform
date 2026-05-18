variable "kind_version" {
  description = "Version of KIND to install"
  type        = string
  default     = "v0.20.0"
}

variable "kubectl_version" {
  description = "The version of kubectl to install"
  type        = string
  default     = "v1.29.0"
}

variable "registry" {
  default = "localhost:5000"
}

variable "microservices" {
  type    = list(string)
  default = ["references", "merchants", "users", "shop", "orders"]
}

variable "app_path" {
  description = "Relative path to the Maven parent project"
  default     = "~/Desktop/playground/microservices"
}

variable "postgres_data_host_path" {
  description = "Host path on the Mac to store Postgres data for Kind (will be mounted into the node)"
  type        = string
  default     = "/usr/local/opt/postgresql@15"
}

variable "enable_argocd" {
  description = "Install Argo CD into the local Kind cluster"
  type        = bool
  default     = true
}

variable "argocd_namespace" {
  description = "Namespace where Argo CD is installed"
  type        = string
  default     = "argocd"
}

variable "argocd_release_name" {
  description = "Helm release name for Argo CD"
  type        = string
  default     = "argocd"
}
