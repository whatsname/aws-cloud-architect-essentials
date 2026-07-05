# Netflux — AWS Deployment Command Reference

Progressive AWS deployment of the netflux microservices (customer-service, movie-service)
via Terraform: VPC → RDS → EC2 → S3/CloudFront → ALB → ASG → ECS Fargate → Secrets Manager → CI/CD.

## Setup

```
aws configure                          # own IAM user, never share/paste access keys
aws sts get-caller-identity            # verify identity is not :root
brew install hashicorp/tap/terraform
```

## Terraform (from `terraform/` dir)

```
terraform init
terraform plan
terraform apply -auto-approve
terraform destroy                      # full teardown
export TF_VAR_rds_master_password='...'  # required for plan/apply/destroy
```

## Build + push images (local machine)

```
cd netflux/customer-service && mvn -q -DskipTests package
cd netflux/movie-service && mvn -q -DskipTests package

aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin <account>.dkr.ecr.ap-southeast-1.amazonaws.com

# amd64 required — Mac local build defaults arm64, Fargate/EC2 need amd64
docker buildx build --platform linux/amd64 -t <ecr-url>/netflux/customer-service:latest --push ./netflux/customer-service
docker buildx build --platform linux/amd64 -t <ecr-url>/netflux/movie-service:latest --push ./netflux/movie-service
```

## RDS schema load (via SSM — no direct DB access, RDS is private-subnet only)

```
aws ssm send-command --instance-ids <id> --document-name "AWS-RunShellScript" \
  --parameters 'commands=["docker run --rm -v /tmp/init.sql:/init.sql -e PGPASSWORD=... postgres:18 psql -h <rds-endpoint> -U netflux_admin -d postgres -f /init.sql"]'

aws ssm get-command-invocation --command-id <id> --instance-id <id>
```

## ECS ops

```
aws ecs describe-services --cluster netflux-cluster --services customer-service movie-service
aws ecs update-service --cluster netflux-cluster --service customer-service --force-new-deployment
aws logs tail /ecs/netflux/customer-service --since 10m --format short
```

## ALB target health

```
aws elbv2 describe-target-groups --names netflux-customer-tg
aws elbv2 describe-target-health --target-group-arn <arn>
```

## CI/CD

```
git push origin main                              # auto-triggers pipeline
aws codepipeline list-pipeline-executions --pipeline-name netflux-pipeline
aws codepipeline get-pipeline-execution --pipeline-name netflux-pipeline --pipeline-execution-id <id>
aws codepipeline start-pipeline-execution --name netflux-pipeline  # manual trigger
```

## Test endpoints

```
curl http://<alb-dns>/api/customers/1
curl https://<cloudfront-domain>/
```

## Notes

- RDS master username cannot be `admin` (Postgres reserved word on RDS).
- ECS `health_check_grace_period_seconds` must exceed actual app boot time (Secrets Manager fetch +
  Spring context init took ~100-120s here) or ALB marks tasks unhealthy before they finish booting.
- CodePipeline needs `pipeline_type = "V2"` + a `trigger` block for GitHub push auto-trigger — V1 does
  not auto-create the EventBridge rule via Terraform.
- CodeStar connection status `AVAILABLE` only means read access works. Auto-trigger additionally needs
  the "AWS Connector for GitHub" App installed with access to the specific repo
  (github.com/settings/installations).
