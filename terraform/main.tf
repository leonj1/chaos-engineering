# Create Route53 Hosted Zone
resource "aws_route53_zone" "main" {
  name = var.domain_name
}

# Create Route53 Records with Weighted Routing Policy
resource "aws_route53_record" "us_east_1" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = module.ecs_us_east_1.alb_dns_name
    zone_id                = module.ecs_us_east_1.alb_zone_id
    evaluate_target_health = true
  }

  set_identifier = "us-east-1"
  weighted_routing_policy {
    weight = 50
  }
}

resource "aws_route53_record" "us_east_2" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = module.ecs_us_east_2.alb_dns_name
    zone_id                = module.ecs_us_east_2.alb_zone_id
    evaluate_target_health = true
  }

  set_identifier = "us-east-2"
  weighted_routing_policy {
    weight = 50
  }
}

# Deploy to us-east-1
module "ecs_us_east_1" {
  source = "./modules/ecs-region"
  
  providers = {
    aws = aws.us-east-1
  }
  
  region        = "us-east-1"
  app_name      = var.app_name
  container_port = var.container_port
  cpu           = var.cpu
  memory        = var.memory
  desired_count = var.desired_count
}

# Deploy to us-east-2
module "ecs_us_east_2" {
  source = "./modules/ecs-region"
  
  providers = {
    aws = aws.us-east-2
  }
  
  region        = "us-east-2"
  app_name      = var.app_name
  container_port = var.container_port
  cpu           = var.cpu
  memory        = var.memory
  desired_count = var.desired_count
}