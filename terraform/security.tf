# App-tier SG. Used by EC2 (Phase 4/7, now decommissioned) and ECS Fargate tasks (Phase 8).
# RDS SG below only trusts this SG, not any CIDR.

resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "netflux app servers (customer-service, movie-service)"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-app-sg" }
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Postgres RDS, inbound only from app SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-rds-sg" }
}
