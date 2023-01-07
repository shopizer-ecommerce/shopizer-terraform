
variable "name" {
  type = string
}


variable "environment" {
  type = string
  default = "demo"
}


variable "aws_region" {
  type = string
  default = "ca-central-1"
}

variable "blueprint" {
  type = string
}

variable "bundle" {
  type = string
}

variable "availability_zone" {
  type = string
  default = "ca-central-1a"
}