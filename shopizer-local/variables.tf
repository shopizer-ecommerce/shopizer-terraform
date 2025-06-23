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
  default = ["references", "merchant", "user", "shop"]
}

variable "app_path" {
  description = "Relative path to the Maven parent project"
}