# Phase 4b: ECR repos for the two service images. Local machine builds+pushes; EC2 (and later ECS) only pulls.

resource "aws_ecr_repository" "customer_service" {
  name                 = "${var.project_name}/customer-service"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

resource "aws_ecr_repository" "movie_service" {
  name                 = "${var.project_name}/movie-service"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}
