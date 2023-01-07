
provider "aws" {
  region = "${var.aws_region}"
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lightsail_instance
resource "aws_lightsail_instance" "shopizer" {
  name              = var.name
  availability_zone = var.availability_zone
  blueprint_id      = var.blueprint
  bundle_id         = var.bundle
  user_data         = <<EOF

#!/bin/bash
echo "Install docker + Docker compose"
curl -fsSL https://get.docker.com -o get-docker.sh | sudo sh get-docker.sh
usermod -aG docker ubuntu
sudo curl -L "https://github.com/docker/compose/releases/download/v2.0.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
docker-compose --version
mkdir /srv/docker
sudo curl -o /srv/docker/docker-compose.yml https://raw.githubusercontent.com/shopizer-ecommerce/shopizer-docker-compose/master/docker-compose-os-aws.yml

echo "Installation completed"
                        EOF

  tags = {
    Name = "${var.name}-${var.environment}"
  }
}

# Bucket


# CDN


# CloudFormation image handler