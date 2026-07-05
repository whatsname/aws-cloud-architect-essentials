# Phase 8: DB creds moved out of instance user_data (Phase 7) into Secrets Manager.
# App code already expects this exact path/shape — see netflux/*/src/main/resources/application-prod.properties:
#   spring.config.import=aws-secretsmanager:/prod/netflux/db/customer?prefix=db.
# The app pulls these itself at boot via spring-cloud-aws-starter-secrets-manager (task role needs read access,
# not the execution role — this isn't injected as a container env var by ECS).

resource "aws_secretsmanager_secret" "db_customer" {
  name                    = "/prod/netflux/db/customer"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_customer" {
  secret_id = aws_secretsmanager_secret.db_customer.id
  secret_string = jsonencode({
    host     = aws_db_instance.main.address
    username = "customer_user"
    password = "customer_password"
  })
}

resource "aws_secretsmanager_secret" "db_movie" {
  name                    = "/prod/netflux/db/movie"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_movie" {
  secret_id = aws_secretsmanager_secret.db_movie.id
  secret_string = jsonencode({
    host     = aws_db_instance.main.address
    username = "movie_user"
    password = "movie_password"
  })
}
