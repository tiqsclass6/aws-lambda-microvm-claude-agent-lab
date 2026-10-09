resource "terraform_data" "prepare_build_dir" {
  triggers_replace = {
    build_script_hash = filesha256("../scripts/prepare_build_dirs.py")
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/.."
    command     = "${var.python_command} scripts/prepare_build_dirs.py"
  }
}

data "archive_file" "app_package" {
  type        = "zip"
  source_dir  = local.app_source_dir
  output_path = local.artifact_zip_path

  depends_on = [
    terraform_data.prepare_build_dir
  ]
}

resource "terraform_data" "launcher_package" {
  triggers_replace = {
    lambda_hash       = filesha256("../launcher/lambda_function.py")
    requirements_hash = filesha256("../launcher/requirements.txt")
    package_script    = filesha256("../scripts/build_launcher_package.py")
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/.."
    command     = "${var.python_command} scripts/build_launcher_package.py"
  }
}

data "archive_file" "launcher_lambda" {
  type        = "zip"
  source_dir  = local.launcher_package_dir
  output_path = local.launcher_zip_path

  depends_on = [
    terraform_data.launcher_package
  ]
}

resource "aws_lambda_function" "microvm_launcher" {
  function_name = local.launcher_function_name
  description   = "Student lab launcher Lambda that verifies Claude webhooks and starts Lambda MicroVM sessions."
  role          = aws_iam_role.launcher_lambda.arn
  runtime       = "python3.14"
  handler       = "lambda_function.lambda_handler"

  filename         = data.archive_file.launcher_lambda.output_path
  source_code_hash = data.archive_file.launcher_lambda.output_base64sha256

  timeout     = var.launcher_timeout_seconds
  memory_size = var.launcher_memory_size

  environment {
    variables = {
      ANTHROPIC_ENVIRONMENT_ID      = var.anthropic_environment_id
      MICROVM_IMAGE_ARN             = aws_cloudformation_stack.microvm_image.outputs["MicrovmImageArn"]
      MICROVM_RUNTIME_ROLE_ARN      = aws_iam_role.microvm_runtime.arn
      CLAUDE_ENVIRONMENT_SECRET_ARN = aws_secretsmanager_secret.claude_environment_key.arn
      WEBHOOK_SIGNING_SECRET_ARN    = aws_secretsmanager_secret.claude_webhook_signing_secret.arn
      MICROVM_IDLE_POLICY           = jsonencode(var.microvm_idle_policy)
      MICROVM_MAX_DURATION_SECONDS  = tostring(var.microvm_max_duration_seconds)
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.launcher,
    aws_cloudformation_stack.microvm_image,
    aws_iam_role_policy_attachment.launcher_lambda
  ]
}