
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

variable "bucket_name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "default_root_object" {
  type    = string
  default = null

  description = "The default root object CloudFront is to request from the S3 bucket as root URL"
}

variable "ttl" {
  type = object({
    min     = number
    default = number
    max     = number
  })

  default = {
    min     = 0
    default = 86400
    max     = 31536000
  }

  description = "The min, default and max TTLs set on the CloudFront distribution"
}

variable "aliases" {
  type    = list(string)
  default = null

  description = <<EOS
    List of custom domain which shall be served by the CloudFront distribution.
    In order to serve the content via HTTPS, you need to specify an ACM certificate
    with matchgin domains via `acm_certificate_arn`.
  EOS
}


variable "acm_certificate" {
  type    = object({
    arn = string
  })
  default = null

  description = <<EOS
    The ARN of the ACM certificate that you want to use with the CloudFront distribution.
    If not specified, the default CloudFront certificate for *.cloudfront.net will be used.
    This only makes sense in combination with `aliases`.
  EOS
}

variable "acm_certificate_minimum_protocol_version" {
  type    = string
  default = "TLSv1.2_2021"

  description = <<EOS
    The minimum protocol version for the ACM viewer certificate that you want to use with
    the CloudFront distribution.
    Supported protocols and ciphers are documented here:
    https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/secure-connections-supported-viewer-protocols-ciphers.html
    If not specified, it defaults to `"TLSv1.2_2021"`.
  EOS
}