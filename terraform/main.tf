# Simplified version for LocalStack testing
# This creates basic ECS services in two regions with Route53

# Create a simple VPC in us-east-1
resource "aws_vpc" "us_east_1" {
  provider             = aws.us-east-1
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.app_name}-vpc-us-east-1"
  }
}

# Create a simple VPC in us-east-2
resource "aws_vpc" "us_east_2" {
  provider             = aws.us-east-2
  cidr_block           = "10.1.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.app_name}-vpc-us-east-2"
  }
}

# Create ECS clusters
resource "aws_ecs_cluster" "us_east_1" {
  provider = aws.us-east-1
  name     = "${var.app_name}-cluster-us-east-1"
}

resource "aws_ecs_cluster" "us_east_2" {
  provider = aws.us-east-2
  name     = "${var.app_name}-cluster-us-east-2"
}

# Create Route53 Hosted Zone
resource "aws_route53_zone" "main" {
  name = var.domain_name
}

# Simple A records for testing
resource "aws_route53_record" "test" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "test.${var.domain_name}"
  type    = "A"
  ttl     = "300"
  records = ["1.2.3.4"]
}