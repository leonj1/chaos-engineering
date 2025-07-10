output "route53_nameservers" {
  description = "Route53 nameservers"
  value       = aws_route53_zone.main.name_servers
}

output "domain_name" {
  description = "Domain name"
  value       = var.domain_name
}

output "us_east_1_alb_dns" {
  description = "ALB DNS for us-east-1"
  value       = module.ecs_us_east_1.alb_dns_name
}

output "us_east_2_alb_dns" {
  description = "ALB DNS for us-east-2"
  value       = module.ecs_us_east_2.alb_dns_name
}