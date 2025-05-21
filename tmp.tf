/*

Alternate command for service linkes role:
$ aws iam create-service-linked-role --aws-service-name es.amazonaws.com

*/

resource "null_resource" "aos_service_linked_role" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-COMMAND
      aws iam create-sevice-linked-role --aws-service-name es.amazonaws.com
    COMMAND
    on_failure = continue
  }

}

 

data "aws_iam_role" "aos_service_linked_role" {
  name = "AWSServiceRoleForAmazonElasticsearchService"
  depends_on = [
    null_resource.aos_service_linked_role
  ]
}

 

resource "aws_elasticsearch_domain" "aos" {
  domain_name = var.opensearch_domain
  elasticsearch_version = var.elasticsearch_version

  cluster_config {

    dedicated_master_enabled = false
    instance_count           = 2
    instance_type            = var.opensearch_instance_class
    warm_enabled             = false
    zone_awareness_enabled   = true

  }

 

  ebs_options {
    ebs_enabled = true
    volume_size = var.opensearch_volume_size
  }

 

  vpc_options {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.opensearch.id]
  }

 

  encrypt_at_rest {
    enabled = false
  }

 

  node_to_node_encryption {
    enabled = false
  }

 
  # TODO tls policy to be revised
  domain_endpoint_options {
    enforce_https = true
    tls_security_policy = "Policy-Min-TLS-1-0-2019-07"

  }

 

  #https://docs.aws.amazon.com/opensearch-service/latest/developerguide/ac.html

  access_policies = <<CONFIG

{

    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "es:*",
            "Principal": "*",
            "Effect": "Allow",
            "Resource": "arn:aws:es:${var.aws_region}:${data.aws_caller_identity.current.account_id}:domain/${var.opensearch_domain}/*"

        }
    ]
}

CONFIG

 

  # access_policies = data.aws_iam_policy_document.aos_access_policies.json
  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_logs.arn
    log_type = "INDEX_SLOW_LOGS"

  }

 

  log_publishing_options {

    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_logs.arn
    log_type = "SEARCH_SLOW_LOGS"

  }

 

  log_publishing_options {

    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_logs.arn
    log_type = "ES_APPLICATION_LOGS"

  }


  tags = {"name" = "${var.environment}-${var.name}"}

  depends_on = [data.aws_iam_role.aos_service_linked_role]

}

 

 

####################################################################################################

# Logs

####################################################################################################

 

resource "aws_cloudwatch_log_group" "opensearch_logs" {

  name = "opensearch/${var.opensearch_domain}"

}

 

resource "aws_cloudwatch_log_resource_policy" "opensearch_logs" {

  policy_name = "opensearch-${var.opensearch_domain}"
  policy_document = data.aws_iam_policy_document.opensearch_logs.json

}

 

data "aws_iam_policy_document" "opensearch_logs" {

  statement {

    effect = "Allow"
    principals {
      type = "Service"
      identifiers = ["es.amazonaws.com"]

    }

    actions = [

      "logs:PutLogEvents",

      "logs:PutLogEventsBatch",

      "logs:CreateLogStream",

    ]

    resources = [

      "arn:aws:logs:*"

    ]

  }

}

#---- security group
#--------------------

data "aws_vpc" "selected" {
  id = var.vpc_id
}

 

data "aws_subnet" "opensearch" {
  count = length(var.private_subnet_ids)
  id = var.private_subnet_ids[count.index]

}

 

resource "aws_security_group" "opensearch" {
  name = "${var.opensearch_domain}-opensearch-domain"
  description = "OpenSearch Domain"
  vpc_id = var.vpc_id


  egress {
    description = "Allow all outbound traffic"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]

  }


  tags = {"name" = "${var.environment}-${var.name}"}

}

 

resource "aws_security_group_rule" "opensearch" {

  count = length(var.private_subnet_ids)
  description = "Cluster Subnets"
  security_group_id = aws_security_group.opensearch.id

  type = "ingress"
  from_port = 443
  to_port = 443
  protocol = "tcp"
  cidr_blocks = compact([data.aws_subnet.opensearch[count.index].cidr_block])
  ipv6_cidr_blocks = compact([data.aws_subnet.opensearch[count.index].ipv6_cidr_block])

}

 

resource "aws_security_group_rule" "opensearch_proxy" {

  description = "Proxy"
  security_group_id = aws_security_group.opensearch.id

  type = "ingress"
  from_port = 443
  to_port = 443
  protocol = "tcp"
  source_security_group_id = aws_security_group.proxy.id

}

 

resource "aws_security_group" "proxy" {

  name = "${var.opensearch_domain}-opensearch-proxy"

  description = "Proxy for OpenSearch Domain"

  vpc_id = var.vpc_id

 

  ingress {

    description = "TLS from IP range"

    from_port = 443

    to_port = 443

    protocol = "tcp"

    cidr_blocks = [var.vpc_cidr]

  }

 

  egress {

    description = "Allow all outbound traffic"

    from_port = 0

    to_port = 0

    protocol = "-1"

    cidr_blocks = ["0.0.0.0/0"]

    ipv6_cidr_blocks = ["::/0"]

  }

 

  tags = {"name" = "${var.environment}-${var.name}"}

}

################## output

output "cluster_name" {

  description = "The name of the OpenSearch cluster."

  value       = aws_elasticsearch_domain.aos.domain_name

}

 

output "cluster_endpoint" {

  description = "The endpoint URL of the OpenSearch cluster."

  value       = https://${aws_elasticsearch_domain.aos.endpoint}

}

 

output "kibana_endpoint" {

  description = "The endpoint URL of the OpenSearch dashboards."

  value       = https://${aws_elasticsearch_domain.aos.kibana_endpoint}

}