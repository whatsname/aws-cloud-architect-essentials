output "rds_endpoint" {
  value = aws_db_instance.main.endpoint
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "app_security_group_id" {
  value = aws_security_group.app.id
}

output "ecr_customer_service_url" {
  value = aws_ecr_repository.customer_service.repository_url
}

output "ecr_movie_service_url" {
  value = aws_ecr_repository.movie_service.repository_url
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.frontend.domain_name
}

output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "codestar_connection_arn" {
  description = "PENDING until you authorize it once in AWS console: CodePipeline -> Settings -> Connections"
  value       = aws_codestarconnections_connection.github.arn
}
