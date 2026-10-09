output "artifact_bucket_name" {
  description = "S3 bucket containing the packaged MicroVM application artifact."
  value       = aws_s3_bucket.artifact.bucket
}

output "artifact_s3_uri" {
  description = "S3 URI for the MicroVM application artifact zip."
  value       = "s3://${aws_s3_bucket.artifact.bucket}/${aws_s3_object.app_artifact.key}"
}

output "microvm_build_role_arn" {
  description = "IAM role assumed during Lambda MicroVM image creation."
  value       = aws_iam_role.microvm_build.arn
}

output "microvm_runtime_role_arn" {
  description = "Runtime execution role for Claude session MicroVMs."
  value       = aws_iam_role.microvm_runtime.arn
}

output "microvm_log_group_name" {
  description = "CloudWatch Logs group for Lambda MicroVM image build and runtime logs."
  value       = aws_cloudwatch_log_group.microvm.name
}

output "launcher_lambda_name" {
  description = "Launcher Lambda function name."
  value       = aws_lambda_function.microvm_launcher.function_name
}

output "launcher_lambda_log_group_name" {
  description = "Launcher Lambda CloudWatch log group."
  value       = aws_cloudwatch_log_group.launcher.name
}

output "api_gateway_log_group_name" {
  description = "API Gateway CloudWatch access log group."
  value       = aws_cloudwatch_log_group.api_gateway.name
}

output "claude_webhook_url" {
  description = "REST API webhook URL to register in Claude Console for session.status_run_started events."
  value       = "${aws_api_gateway_stage.prod.invoke_url}/claude/webhook"
}

output "claude_environment_key_secret_arn" {
  description = "Secret ARN where the Claude self-hosted environment key must be stored."
  value       = aws_secretsmanager_secret.claude_environment_key.arn
}

output "claude_webhook_signing_secret_arn" {
  description = "Secret ARN where the Claude webhook signing secret must be stored."
  value       = aws_secretsmanager_secret.claude_webhook_signing_secret.arn
}

output "microvm_image_name" {
  description = "Friendly Lambda MicroVM image name from terraform.tfvars."
  value       = var.microvm_image_name
}

output "microvm_image_arn" {
  description = "CloudFormation output: Lambda MicroVM image ARN."
  value       = aws_cloudformation_stack.microvm_image.outputs["MicrovmImageArn"]
}

output "microvm_image_state" {
  description = "CloudFormation output: Lambda MicroVM image state."
  value       = aws_cloudformation_stack.microvm_image.outputs["MicrovmImageState"]
}

output "latest_active_image_version" {
  description = "CloudFormation output: latest active Lambda MicroVM image version."
  value       = aws_cloudformation_stack.microvm_image.outputs["LatestActiveImageVersion"]
}

output "cloudtrail_bucket_name" {
  description = "S3 bucket receiving CloudTrail audit records."
  value       = aws_s3_bucket.cloudtrail.bucket
}

output "cloudtrail_trail_arn" {
  description = "CloudTrail trail ARN used for Lambda MicroVM audit events."
  value       = aws_cloudtrail.microvm.arn
}

output "list_base_image_versions_command" {
  description = "Command to list available Lambda-managed MicroVM base image versions."
  value       = "aws lambda-microvms list-managed-microvm-image-versions --image-identifier ${var.microvm_base_image_arn} --region ${var.aws_region}"
}

output "tail_microvm_logs_command" {
  description = "Git Bash-safe command to tail MicroVM image build and runtime logs."
  value       = "MSYS_NO_PATHCONV=1 aws logs tail \"${aws_cloudwatch_log_group.microvm.name}\" --follow --region ${var.aws_region}"
}

output "tail_launcher_logs_command" {
  description = "Git Bash-safe command to tail launcher Lambda logs."
  value       = "MSYS_NO_PATHCONV=1 aws logs tail \"${aws_cloudwatch_log_group.launcher.name}\" --follow --region ${var.aws_region}"
}