#------networking/variables.tf

variable "vpc_cidr" {}

variable "public_cidrs" {
  type = "list"
}

variable "accessip" {}

variable "subnet_count" {}