# Lambda MicroVM + Claude Managed Agents CLI Commands

## Deploy infrastructure

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

## Get a valid MicroVM base image version

```bash
aws lambda-microvms list-managed-microvm-image-versions \
  --image-identifier arn:aws:lambda:us-east-1:aws:microvm-image:al2023-1 \
  --region us-east-1
```

Update `terraform.tfvars` with the selected value before `terraform apply`.

## Store Claude secrets after Terraform creates the secret containers

```bash
aws secretsmanager put-secret-value \
  --secret-id "$(terraform output -raw claude_environment_key_secret_arn)" \
  --secret-string "REPLACE_WITH_CLAUDE_ENVIRONMENT_KEY" \
  --region us-east-1
```

```bash
aws secretsmanager put-secret-value \
  --secret-id "$(terraform output -raw claude_webhook_signing_secret_arn)" \
  --secret-string "REPLACE_WITH_CLAUDE_WEBHOOK_SIGNING_SECRET" \
  --region us-east-1
```

## Register webhook in Claude Console

Use this URL:

```bash
terraform output -raw claude_webhook_url
```

Subscribe it to:

```text
session.status_run_started
```

## Monitor

```bash
terraform output -raw tail_launcher_logs_command
terraform output -raw tail_microvm_logs_command
```

## Audit MicroVM data events

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=RunMicrovm \
  --region us-east-1 \
  --max-results 10
```
