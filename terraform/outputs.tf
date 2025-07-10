output "route53_nameservers" {
  description = "Route53 nameservers"
  value       = aws_route53_zone.main.name_servers
}

output "domain_name" {
  description = "Domain name"
  value       = var.domain_name
}

output "ecs_cluster_us_east_1" {
  description = "ECS Cluster name for us-east-1"
  value       = aws_ecs_cluster.us_east_1.name
}

output "ecs_cluster_us_east_2" {
  description = "ECS Cluster name for us-east-2"
  value       = aws_ecs_cluster.us_east_2.name
}