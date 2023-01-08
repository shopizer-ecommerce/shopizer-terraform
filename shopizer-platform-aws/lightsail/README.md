
# Shopizer on AWS LightSail

## Lightsail

4GB of RAM 2vcpu Ubunto 20.X
This will run Nginx, Docker and Docker compse

## S3 Bucket

This bucket will be used to store images

## CloudFront distro

Cache for images

## Serverless Image Handler

Image resize at the request based on Sharp


## CloudWatch availability Alarm

```
terraform init
terraform plan -var-file variables.tfvars
terraform apply -var-file variables.tfvars
terraform destroy -var-file variables.tfvars
```

# Post installation tasks

- Edit /srv/docker/docer-compose

```

      - "config.cms.contentUrl=<VALUE FROM output.cloudfront_distribution"
      - "AWS_ACCESS_KEY_ID=<YOUR ACCESS KEY>"
      - "AWS_SECRET_ACCESS_KEY=<YOUR SECRET ACCESS_KEY>"
      - "config.cms.aws.bucket=<VALUE FROM output.bucket"
      - "config.cms.aws.region=<YOUR AWS ACCLUNT REGION>"

```

- Start docker compose

```
cd /src/docker
docker compose up -d
``