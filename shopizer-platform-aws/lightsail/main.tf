
provider "aws" {
  region = "${var.aws_region}"
}

########## Lightsail ##########
###############################

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lightsail_instance
resource "aws_lightsail_instance" "shopizer" {
  name              = var.name
  availability_zone = var.availability_zone
  blueprint_id      = var.blueprint
  bundle_id         = var.bundle
  user_data         = <<EOF

#!/bin/bash
echo "Install docker + Docker compose"
sudo apt update -y
curl -fsSL https://get.docker.com -o get-docker.sh | sudo sh get-docker.sh
usermod -aG docker ubuntu
sudo curl -L "https://github.com/docker/compose/releases/download/v2.0.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
docker-compose --version
mkdir /srv/docker
sudo curl -o /srv/docker/docker-compose.yml https://raw.githubusercontent.com/shopizer-ecommerce/shopizer-docker-compose/master/docker-compose-os-aws.yml

echo "Install nginx"
sudo apt install nginx -y
sudo unlink /etc/nginx/sites-enabled/default
#cd /etc/nginx/sites-available
echo "Installation completed"
                        EOF

  tags = {
    Name = "${var.name}-${var.environment}"
  }
}

########## Bucket #############
###############################

resource "aws_s3_bucket" "shopizer_bucket" {
  bucket = var.bucket_name

  tags = {
    Name = "${var.name}-${var.environment}"
  }
}

data "aws_iam_policy_document" "bucket_policy" {
  statement {

    principals {
      type        = "CanonicalUser"
      identifiers = [aws_cloudfront_origin_access_identity.shopizer_cdn_identity.s3_canonical_user_id]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.shopizer_bucket.arn}/*"]
  }
}

resource "aws_s3_bucket_policy" "s3_bucket_policy" {
  bucket = aws_s3_bucket.shopizer_bucket.bucket
  policy = data.aws_iam_policy_document.bucket_policy.json

  lifecycle {
    ignore_changes = [
      # When setting a "CanonicalUser" in an S3 bucket policy,
      # S3 changes the policy into something like
      # "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity ...",
      # sometimes with spaces and sometimes with underscores as separators after
      # "user/".
      #
      # We also cannot set that IAM user directly, because we cannot know whether
      # a bucket accepts an IAM user with spaces or with underscores.
      #
      # https://github.com/terraform-providers/terraform-provider-aws/issues/10158
      #
      # However, we can always set the documented way using "CanonicalUser",
      # even if S3 changes value into the IAM user later on.
      #
      # We just need to ignore changes on the policy when refreshing
      # the Terraform state from the S3 API.
      #
      policy,
    ]
  }
}





########## CDN ################
###############################


resource "aws_cloudfront_distribution" "shopizer_cdn" {
  comment = aws_s3_bucket.shopizer_bucket.bucket
  enabled = true

  aliases = var.aliases

  http_version = "http2"

  default_root_object = var.default_root_object

  origin {
    origin_id   = "S3-${aws_s3_bucket.shopizer_bucket.bucket}"
    domain_name = aws_s3_bucket.shopizer_bucket.bucket_domain_name

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.shopizer_cdn_identity.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    target_origin_id       = "S3-${aws_s3_bucket.shopizer_bucket.bucket}"
    viewer_protocol_policy = "allow-all"

    allowed_methods = [
      "GET",
      "HEAD",
    ]

    cached_methods = [
      "GET",
      "HEAD",
    ]

    forwarded_values {
      query_string = false

      headers = [
        "Access-Control-Request-Headers",
        "Access-Control-Request-Method",
        "Origin",
      ]

      cookies {
        forward = "none"
      }
    }

    min_ttl     = var.ttl.min
    default_ttl = var.ttl.default
    max_ttl     = var.ttl.max

    compress = true
  }

  viewer_certificate {
    acm_certificate_arn            = local.viewer_certificate.acm_certificate_arn
    cloudfront_default_certificate = local.viewer_certificate.cloudfront_default_certificate

    minimum_protocol_version = local.viewer_certificate.minimum_protocol_version
    ssl_support_method       = local.viewer_certificate.ssl_support_method
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name = "${var.name}-${var.environment}"
  }
}

resource "aws_cloudfront_origin_access_identity" "shopizer_cdn_identity" {
  comment = aws_s3_bucket.shopizer_bucket.bucket
}

locals {
  default_viewer_certificate = {
    acm_certificate_arn            = null
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1"
    ssl_support_method             = null
  }

  # enable when cert is in cetr manager
  acm_viewer_certificate = {
    acm_certificate_arn            = try(var.acm_certificate.arn, null)
    cloudfront_default_certificate = false
    minimum_protocol_version       = var.acm_certificate_minimum_protocol_version
    ssl_support_method             = "sni-only"
  }

  viewer_certificate = var.acm_certificate != null ? local.acm_viewer_certificate : local.default_viewer_certificate
}


# CloudFormation image handler #
################################

resource "aws_cloudformation_stack" "image_handler" {
  name = "serverless-image-handler-stack"
  capabilities = ["CAPABILITY_IAM"]
  parameters = {
    SourceBucketsParameter = var.bucket_name
  }
  template_url = "https://solutions-reference.s3.amazonaws.com/serverless-image-handler/latest/serverless-image-handler.template"
}