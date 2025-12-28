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
  default = ["references", "merchant", "users", "shop", "orders"]
}

variable "app_path" {
  description = "Relative path to the Maven parent project"
}

variable "postgres_data_host_path" {
  description = "Host path on the Mac to store Postgres data for Kind (will be mounted into the node)"
  type        = string
}
