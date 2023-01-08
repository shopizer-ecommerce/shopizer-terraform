#----root/outputs.tf-----

#----bucket and cdn outputs------

output "bucket" {
  value = aws_s3_bucket.shopizer_bucket

  description = "The created bucket"
}

output "cloudfront_distribution" {
  value = aws_cloudfront_distribution.shopizer_cdn

  description = "The CloudFront distribution connected with the created bucket"
}