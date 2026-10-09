# 🧭 **RUNBOOK: Lambda MicroVM + Claude Managed Agents Student Lab**

## **1. Purpose**

This runbook documents how to deploy, validate, troubleshoot, and destroy the **Lambda MicroVM + Claude Managed Agents Student Lab**.

This is a student lab / proof-of-concept. It demonstrates how Terraform can provision an AWS control plane that receives Claude Managed Agent webhook events, validates webhook signatures, and launches an isolated Lambda MicroVM runtime session.

---

## **2. Current Canonical Deployment Values**

| **Item**                              | **Current value**                                                                                                  |
|---------------------------------------|--------------------------------------------------------------------------------------------------------------------|
| **AWS Region**                        | `us-east-1`                                                                                                        |
| **AWS Account**                       | `<ACCOUNT_ID>`                                                                                                     |
| **Terraform backend bucket**          | `class-7-state-files`                                                                                              |
| **Terraform backend key**             | `lambda-labs/microvm.tfstate`                                                                                      |
| **API Gateway webhook URL**           | `https://<API_ID>.execute-api.us-east-1.amazonaws.com/prod/claude/webhook`                                         |
| **Artifact bucket**                   | `microvm-artifacts-bucket`                                                                                         |
| **Artifact S3 URI**                   | `s3://microvm-artifacts-bucket/microvm-artifacts/app.zip`                                                          |
| **Claude environment key secret ARN** | `arn:aws:secretsmanager:us-east-1:<ACCOUNT_ID>:secret:lambda-microvm-lab-dev/claude/environment-key-HbbDkY`        |
| **Claude webhook signing secret ARN** | `arn:aws:secretsmanager:us-east-1:<ACCOUNT_ID>:secret:lambda-microvm-lab-dev/claude/webhook-signing-secret-r9XywX` |
| **MicroVM image name**                | `class7-microvm-image`                                                                                             |
| **MicroVM image ARN**                 | `arn:aws:lambda:us-east-1:<ACCOUNT_ID>:microvm-image:class7-microvm-image`                                         |
| **MicroVM image state**               | `CREATED`                                                                                                          |
| **Latest active image version**       | `1.0`                                                                                                              |
| **Launcher Lambda log group**         | `/aws/lambda/lambda-microvm-lab-dev-microvm-launcher`                                                              |
| **API Gateway log group**             | `/aws/apigateway/lambda-microvm-lab-dev-claude-webhook`                                                            |
| **MicroVM log group**                 | `/aws/lambda/microvms/class7-microvm-image`                                                                        |
| **CloudTrail bucket**                 | `lambda-microvm-lab-dev-cloudtrail-d06df742`                                                                       |
| **CloudTrail trail ARN**              | `arn:aws:cloudtrail:us-east-1:<ACCOUNT_ID>:trail/lambda-microvm-lab-dev-microvm-trail`                             |

---

## **3. Success Criteria**

The lab is considered working when all of the following are true:

- AWS identity is valid.
- Terraform backend bucket is reachable.
- Terraform initializes successfully.
- Terraform validates successfully.
- Terraform apply completes.
- Lambda MicroVM image state is `CREATED`.
- Latest active image version is `1.0`.
- Manual unsigned webhook test returns `401 Invalid webhook signature`.
- Manual MicroVM launch reaches `RUNNING`.
- MicroVM auth token is generated.
- Direct MicroVM `/health` call returns `HTTP/1.1 200 OK`.
- CloudWatch logs show expected launcher and API Gateway activity.
- CloudTrail selectors show management events and Lambda MicroVM data events.

---

## **4. Architecture Overview**

### Build Pipeline

```text
Terraform apply
→ Package app/Dockerfile + app/app.js
→ Create app.zip
→ Upload app.zip to S3
→ CloudFormation creates AWS::Lambda::MicrovmImage
→ Lambda MicroVM image becomes versioned and launchable
```

### Runtime Request Flow

```text
Claude Managed Agent
→ Sends session.status_run_started webhook
→ API Gateway REST API receives POST /claude/webhook
→ Python launcher Lambda verifies webhook signature
→ Launcher Lambda calls RunMicroVM
→ Lambda MicroVM starts one isolated session
→ MicroVM worker runs the student lab Node.js service on port 8080
```

### Supporting Services

1. **S3** - Stores the packaged app artifact.
2. **Secrets Manager** - Stores Claude environment key and webhook signing secret.
3. **IAM** - Provides least-privilege roles and policies.
4. **CloudWatch** - Stores logs, metrics, and alarms.
5. **CloudTrail** - Audits management events and Lambda MicroVM data events.
6. **API Gateway** - Exposes the Claude webhook route.
7. **Lambda** - Runs the Python launcher.

---

## **5. Prerequisites**

Required tools:

1. Terraform 1.14+
2. AWS CLI v2
3. Python 3.14
4. Git Bash
5. jq
6. Claude Console access
7. .venv with Python dependencies installed

### **Python Build Environment**

Use a dedicated virtual environment for the Lambda launcher package build:

```bash
python -m venv .venv-lambda-build
source .venv-lambda-build/Scripts/activate
python -m pip install --upgrade pip
```

Set your shell environment:

```bash
export AWS_REGION="us-east-1"
export AWS_PROFILE="default"
```

Verify identity:

```bash
aws sts get-caller-identity --region "$AWS_REGION"
```

Expected account:

![aws-verifications.jpg](/images/aws-verifications.jpg)

---

## **6. Backend Validation**

The project uses this Terraform backend: [**1-authentication.tf**](/terraform/1-authentication.tf)

Verify the backend bucket:

```bash
aws s3api head-bucket \
  --bucket class-7-state-files \
  --region "$AWS_REGION"
```

Expected:

![s3-bucket-verification.jpg](/images/s3-bucket-verification.jpg)

---

## **7. Base Image Version Check**

```bash
aws lambda-microvms list-managed-microvm-image-versions \
  --image-identifier arn:aws:lambda:us-east-1:aws:microvm-image:al2023-1 \
  --region "$AWS_REGION" \
  --output table
```

![base-image-versions.jpg](/images/base-image-versions.jpg)

This lab currently uses:

```hcl
microvm_base_image_version = "1"
```

---

## **8. Terraform Deployment**

```bash
cd terraform
terraform init -upgrade
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

Expected successful result:

![terraform-init-fmt-validate.jpg](/images/terraform-init-fmt-validate.jpg)
![terraform-plan.jpg](/images/terraform-plan.jpg)
![terraform-apply.jpg](/images/terraform-apply.jpg)

---

## **9. Current Terraform Outputs**

```bash
export MICROVM_IMAGE_ARN="$(terraform output -raw microvm_image_arn | tr -d '\r')"
export MICROVM_IMAGE_NAME="$(terraform output -raw microvm_image_name | tr -d '\r')"
export MICROVM_RUNTIME_ROLE_ARN="$(terraform output -raw microvm_runtime_role_arn | tr -d '\r')"
export MICROVM_LOG_GROUP="$(terraform output -raw microvm_log_group_name | tr -d '\r')"
export LAUNCHER_LAMBDA_NAME="$(terraform output -raw launcher_lambda_name | tr -d '\r')"
export LAUNCHER_LOG_GROUP="$(terraform output -raw launcher_lambda_log_group_name | tr -d '\r')"
export API_GATEWAY_LOG_GROUP="$(terraform output -raw api_gateway_log_group_name | tr -d '\r')"
export CLAUDE_WEBHOOK_URL="$(terraform output -raw claude_webhook_url | tr -d '\r')"
export CLAUDE_ENVIRONMENT_SECRET_ARN="$(terraform output -raw claude_environment_key_secret_arn | tr -d '\r')"
export CLAUDE_WEBHOOK_SIGNING_SECRET_ARN="$(terraform output -raw claude_webhook_signing_secret_arn | tr -d '\r')"
export CLOUDTRAIL_TRAIL_ARN="$(terraform output -raw cloudtrail_trail_arn | tr -d '\r')"
```

![terraform-outputs.jpg](/images/terraform-outputs.jpg)

---

## **10. Configure Claude Console**

1. Open the Claude Managed Agent.

    ![claude-console-agent-environment.jpg](/images/claude-console-agent-environment.jpg)

2. Open the self-hosted environment.

    ![claude-console-environment.jpg](/images/claude-console-environment.jpg)

3. Register this Terraform output webhook URL:

    ![claude-console-webhook.jpg](/images/claude-console-webhook.jpg)

4. Subscribe to:

    ```text
    session.status_run_started
    ```

    ![claude-console-webhook-subscribe.jpg](/images/claude-console-webhook-subscribe.jpg)

5. Store the webhook signing secret in AWS Secrets Manager (**SEE STEP 11**).

---

## **11. Store Claude Secrets**

### **Put Secrets in AWS Secrets Manager**

```bash
aws secretsmanager put-secret-value \
  --secret-id "$(terraform output -raw claude_environment_key_secret_arn)" \
  --secret-string "REPLACE_WITH_CLAUDE_ENVIRONMENT_KEY" \
  --region "$AWS_REGION"

aws secretsmanager put-secret-value \
  --secret-id "$(terraform output -raw claude_webhook_signing_secret_arn)" \
  --secret-string "REPLACE_WITH_CLAUDE_WEBHOOK_SIGNING_SECRET" \
  --region "$AWS_REGION"
```

![claude-secrets.jpg](/images/claude-secrets.jpg)

### **Describe the secrets**

```bash
aws secretsmanager describe-secret \
  --secret-id "$CLAUDE_ENVIRONMENT_SECRET_ARN" \
  --region "$AWS_REGION"
```

  ![claude-secrets-describe-pt1.jpg](/images/claude-secrets-describe-pt1.jpg)

```bash
aws secretsmanager describe-secret \
  --secret-id "$CLAUDE_WEBHOOK_SIGNING_SECRET_ARN" \
  --region "$AWS_REGION"
```

  ![claude-secrets-describe-pt2.jpg](/images/claude-secrets-describe-pt2.jpg)

---

## **12. Webhook Security Smoke Test**

```bash
WEBHOOK_URL="$(terraform output -raw claude_webhook_url | tr -d '\r')"

curl --ssl-no-revoke -i -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  --data-raw '{"type":"session.status_run_started","session_id":"manual-test"}'
```

Expected:

```http
HTTP/1.1 401 Unauthorized
```

```json
{"error": "Invalid webhook signature"}
```

![webhook-smoke-test.jpg](/images/webhook-smoke-test.jpg)

This is correct for unsigned manual curl testing.

---

## **13. Manual MicroVM Runtime Smoke Test**

### Load outputs

```bash
MICROVM_IMAGE_ARN="$(terraform output -raw microvm_image_arn | tr -d '\r')"
MICROVM_RUNTIME_ROLE_ARN="$(terraform output -raw microvm_runtime_role_arn | tr -d '\r')"
```

![manual-microvm-outputs.jpg](/images/manual-microvm-outputs.jpg)

### Launch MicroVM

```bash
aws lambda-microvms run-microvm \
  --image-identifier "$MICROVM_IMAGE_ARN" \
  --image-version "1.0" \
  --execution-role-arn "$MICROVM_RUNTIME_ROLE_ARN" \
  --ingress-network-connectors "arn:aws:lambda:${AWS_REGION}:aws:network-connector:aws-network-connector:ALL_INGRESS" \
  --egress-network-connectors "arn:aws:lambda:${AWS_REGION}:aws:network-connector:aws-network-connector:INTERNET_EGRESS" \
  --idle-policy '{"maxIdleDurationSeconds":900,"suspendedDurationSeconds":0,"autoResumeEnabled":false}' \
  --maximum-duration-in-seconds 28800 \
  --run-hook-payload '{"source":"manual-lab-test","session_id":"manual-test"}' \
  --region "$AWS_REGION" \
  > microvm-run.json
```

![manual-microvm-launch.jpg](/images/manual-microvm-launch.jpg)

### Extract MicroVM ID and endpoint

```bash
MICROVM_ID="$(cat microvm-run.json | jq -r '.microvmId')"
MICROVM_ENDPOINT="$(cat microvm-run.json | jq -r '.endpoint')"
```

![manual-microvm-id.jpg](/images/manual-microvm-id.jpg)

### Wait for RUNNING

```bash
while true; do
  STATE="$(aws lambda-microvms get-microvm  \
     --microvm-identifier "$MICROVM_ID"  \
     --region "$AWS_REGION" \
     --query 'state' \
     --output text)"

  echo "MicroVM state: $STATE"

  if [ "$STATE" = "RUNNING" ]; then
    break
  fi

  if [ "$STATE" = "TERMINATED" ]; then
    echo "MicroVM terminated before becoming reachable. Check MicroVM logs."
    break
  fi

  sleep 5
done
```

![manual-microvm-running.jpg](/images/manual-microvm-running.jpg)

### Create auth token and test health

```bash
aws lambda-microvms create-microvm-auth-token \
  --microvm-identifier "$MICROVM_ID" \
  --expiration-in-minutes 30 \
  --allowed-ports '[{"port":8080}]' \
  --region "$AWS_REGION" \
  > microvm-token.json

TOKEN="$(cat microvm-token.json | jq -r '.authToken."X-aws-proxy-auth"')"

curl -i --ssl-no-revoke "https://${MICROVM_ENDPOINT}/health"  \
  -H "X-aws-proxy-auth: $TOKEN" \
  -H "X-aws-proxy-port: 8080"
```

Expected:

![manual-microvm-health.jpg](/images/manual-microvm-health.jpg)

---

## **14. Observability Validation**

### Launcher Lambda logs

```bash
LAUNCHER_LOG_GROUP="$(terraform output -raw launcher_lambda_log_group_name | tr -d '\r')"

MSYS_NO_PATHCONV=1 aws logs tail "$LAUNCHER_LOG_GROUP" \
  --since 30m \
  --region "$AWS_REGION" \
  --format short
```

![launcher-lambda-logs.jpg](/images/launcher-lambda-logs.jpg)

### CloudWatch alarms

```bash
aws cloudwatch describe-alarms  \
  --alarm-name-prefix "lambda-microvm-lab" \
  --region "$AWS_REGION" \
  --output table
```

Expected alarms:

![cloudwatch-alarms-pt1.jpg](/images/cloudwatch-alarms-pt1.jpg)
![cloudwatch-alarms-pt2.jpg](/images/cloudwatch-alarms-pt2.jpg)

### CloudTrail selectors

```bash
aws cloudtrail get-event-selectors \
  --trail-name "lambda-microvm-lab-dev-microvm-trail" \
  --region "$AWS_REGION" \
  --output json
```

Expected selectors:

![cloudtrail-selectors.jpg](/images/cloudtrail-selectors.jpg)

---

## **15. Troubleshooting Quick Reference**

| **Issue**                                      | **Likely cause**                                     | **Fix**                                     |
|------------------------------------------------|------------------------------------------------------|---------------------------------------------|
| **`https://lambda.$AWS_REGION.amazonaws.com`** | Empty `AWS_REGION`                                   | `export AWS_REGION="us-east-1"`             |
| **`https://logs.$AWS_REGION.amazonaws.com`**   | Empty `AWS_REGION`                                   | `export AWS_REGION="us-east-1"`             |
| **Log group regex/path error**                 | Git Bash path conversion                             | Prefix command with `MSYS_NO_PATHCONV=1`    |
| **`pydantic_core` import error**               | Windows-built Python dependency                      | Rebuild Lambda package with Linux wheels.   |
| **`KeyError: ANTHROPIC_ENVIRONMENT_ID`**       | Missing Lambda env var                               | Set `anthropic_environment_id` and reapply. |
| **API Gateway `502`**                          | Launcher Lambda failed                               | Tail launcher Lambda logs.                  |
| **Webhook returns `401`**                      | Manual curl request is unsigned                      | Expected passing result.                    |
| **Empty `MICROVM_ID`**                         | Did not parse `microvm-run.json`                     | Re-export `MICROVM_ID` using `jq`.          |
| **MicroVM endpoint `502`**                     | MicroVM is terminated, token expired, or app failed  | Check MicroVM state/logs and relaunch.      |
| **Schannel revocation error**                  | Windows curl certificate revocation issue            | Use `curl --ssl-no-revoke`.                 |

---

## **16. Teardown**

List MicroVMs:

```bash
aws lambda-microvms list-microvms \
  --region "$AWS_REGION" \
  --output table
```

![manual-microvm-list.jpg](/images/manual-microvm-list.jpg)

Destroy Terraform resources:

```bash
terraform destroy
```

![terraform-destroy.jpg](/images/terraform-destroy.jpg)

Press `deactivate` to exit the Python virtual environment.

---

## **17. Final Lab Proof Summary**

1. Terraform deployment: **PASS**
2. AWS identity: **PASS**
3. Terraform backend bucket: **PASS**
4. MicroVM image state: **CREATED**
5. Latest image version: **1.0**
6. Webhook security test: **PASS, 401 Invalid webhook signature**
7. Manual MicroVM runtime test: **PASS, RUNNING**
8. MicroVM /health endpoint: **PASS, HTTP/1.1 200 OK**
9. CloudTrail selectors: **PASS**
10. CloudWatch logging: **PASS**

---

## **18. Version**

- Version: 2.1
- Last updated: July 2026
- Project type: Student lab / proof-of-concept
