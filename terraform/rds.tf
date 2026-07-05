# Phase 3: RDS Postgres, replaces the local postgres docker container.
# init.sql (create DBs/users/tables) is not run automatically by RDS — apply it manually after this is up,
# same way netflux/postgres/init.sql was applied locally.

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = { Name = "${var.project_name}-db-subnet-group" }
}

resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-db"
  engine         = "postgres"
  engine_version = "18.4"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp3"

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  username = "netflux_admin"
  password = var.rds_master_password

  publicly_accessible = false
  skip_final_snapshot  = true
  multi_az             = false

  tags = { Name = "${var.project_name}-db" }
}
