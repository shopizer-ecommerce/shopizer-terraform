
# Shopizer on AWS LightSail


IaC for creating a neat secure low cost infrastructure for running Shopizer ecommerce open source software.
This will proceed with the installation of required compute to run mysql, opensearch, nginx, certbot and shopizer.
In addition the scrip installs an S3 provate bucket from images fronted with CloudFront CDN for improving the performance of image distribution.
AWS Serverless image handler is also installed for image optimization from CloudFront cdn.

## Lightsail

4GB of RAM 2vcpu Ubuntu 20.X
This will run Nginx, Docker and Docker compse

## S3 Bucket

This bucket will be used to store images

## CloudFront distro

Cache for images

## Serverless Image Handler

Image resize at the request based on Sharp


## CloudWatch availability Alarm


### Scripts execution

```
terraform init
terraform plan -var-file variables.tfvars
terraform apply -var-file variables.tfvars
terraform destroy -var-file variables.tfvars
```

# Post installation tasks

- Test your installation. Test your lightsail instance http interface http://<ip address>

Should print a generic Nginx response message

- Edit /git add .srv/docker/docer-compose

```

      - "config.cms.contentUrl=<VALUE FROM output.cloudfront_distribution"
      - "AWS_ACCESS_KEY_ID=<YOUR ACCESS KEY>"
      - "AWS_SECRET_ACCESS_KEY=<YOUR SECRET ACCESS_KEY>"
      - "config.cms.aws.bucket=<VALUE FROM output.bucket"
      - "config.cms.aws.region=<YOUR AWS ACCLUNT REGION>"

```

- Configure an api endpoint in nginx that will proxy the request to Rest api

```

cd /etc/nginx/sites-available/
sudo vi reverse-proxy.conf

```

Add an api endpoint

```
server {
        listen 80;
        listen [::]:80;
        server_name api.yourserver.com;
        access_log /var/log/nginx/reverse-access.log;
        error_log /var/log/nginx/reverse-error.log;

        location / {
            proxy_pass http://localhost:8080;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
}
```

Increase allowed payload size when creating products with large images

```
cd /etc/nginx

# edit nginx.conf to add the following line in http { ... } section

client_max_body_size 25M;
```

Test and restart your configuration

```
sudo ln -s /etc/nginx/sites-available/reverse-proxy.conf /etc/nginx/sites-enabled/reverse-proxy.conf
sudo nginx -t
sudo systemctl restart nginx
```

- [OPTIONAL] Configure nginx amd certbot for serving Shopizer api from a sub-domain

# https://www.digitalocean.com/community/tutorials/how-to-secure-nginx-with-let-s-encrypt-on-ubuntu-20-04

** Requires a subdomain - A recored in your DNS provider (Godaddy ...) as certbot validates that there is an A record existing to the current instance IP address.

Install ssl certificate

```
sudo certbot --nginx -d demo.shopizer.com
```

Add port 443 to Lightsail firewall (Network)

- Start docker compose

```
cd /src/docker
docker compose up -d
``