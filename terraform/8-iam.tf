data "aws_iam_policy_document" "lambda_service_assume_role" {
  statement {
    sid    = "AllowLambdaAssumeRole"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

resource "aws_iam_role" "microvm_build" {
  name               = "${local.name_prefix}-microvm-build-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_service_assume_role.json
  description        = "Least-privilege build role assumed by Lambda MicroVM image builder."
}

data "aws_iam_policy_document" "microvm_build_permissions" {
  statement {
    sid    = "ReadOnlyMicrovmApplicationArtifact"
    effect = "Allow"

    actions = [
      "s3:GetObject"
    ]

    resources = [
      aws_s3_object.app_artifact.arn
    ]
  }

  statement {
    sid    = "WriteMicrovmBuildLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents"
    ]

    resources = [
      aws_cloudwatch_log_group.microvm.arn,
      "${aws_cloudwatch_log_group.microvm.arn}:*"
    ]
  }
}

resource "aws_iam_policy" "microvm_build" {
  name        = "${local.name_prefix}-microvm-build-policy"
  description = "Least-privilege permissions for Lambda MicroVM image builds."
  policy      = data.aws_iam_policy_document.microvm_build_permissions.json
}

resource "aws_iam_role_policy_attachment" "microvm_build" {
  role       = aws_iam_role.microvm_build.name
  policy_arn = aws_iam_policy.microvm_build.arn
}

resource "aws_iam_role" "microvm_runtime" {
  name               = "${local.name_prefix}-microvm-runtime-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_service_assume_role.json
  description        = "Runtime execution role for MicroVMs launched from this image."
}

data "aws_iam_policy_document" "microvm_runtime_permissions" {
  statement {
    sid    = "ReadClaudeEnvironmentKeyOnly"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue"
    ]

    resources = [
      aws_secretsmanager_secret.claude_environment_key.arn
    ]
  }

  statement {
    sid    = "WriteMicrovmRuntimeLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents"
    ]

    resources = [
      aws_cloudwatch_log_group.microvm.arn,
      "${aws_cloudwatch_log_group.microvm.arn}:*"
    ]
  }
}

resource "aws_iam_policy" "microvm_runtime" {
  name        = "${local.name_prefix}-microvm-runtime-policy"
  description = "Runtime permissions for Claude session MicroVMs."
  policy      = data.aws_iam_policy_document.microvm_runtime_permissions.json
}

resource "aws_iam_role_policy_attachment" "microvm_runtime" {
  role       = aws_iam_role.microvm_runtime.name
  policy_arn = aws_iam_policy.microvm_runtime.arn
}

resource "aws_iam_role" "launcher_lambda" {
  name               = "${local.name_prefix}-launcher-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_service_assume_role.json
  description        = "Least-privilege role for launching Lambda MicroVMs from Claude webhooks."
}

data "aws_iam_policy_document" "launcher_lambda_permissions" {
  statement {
    sid    = "RunMicrovmFromThisImage"
    effect = "Allow"

    actions = [
      "lambda:RunMicrovm"
    ]

    resources = [
      aws_cloudformation_stack.microvm_image.outputs["MicrovmImageArn"]
    ]
  }

  statement {
    sid    = "PassOnlyMicrovmRuntimeRole"
    effect = "Allow"

    actions = [
      "iam:PassRole"
    ]

    resources = [
      aws_iam_role.microvm_runtime.arn
    ]
  }

  statement {
    sid    = "ReadWebhookSigningSecretOnly"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue"
    ]

    resources = [
      aws_secretsmanager_secret.claude_webhook_signing_secret.arn
    ]
  }

  statement {
    sid    = "WriteLauncherLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents"
    ]

    resources = [
      "${aws_cloudwatch_log_group.launcher.arn}:*"
    ]
  }
}

resource "aws_iam_policy" "launcher_lambda" {
  name        = "${local.name_prefix}-launcher-lambda-policy"
  description = "Least-privilege permissions for Claude webhook MicroVM launcher."
  policy      = data.aws_iam_policy_document.launcher_lambda_permissions.json
}

resource "aws_iam_role_policy_attachment" "launcher_lambda" {
  role       = aws_iam_role.launcher_lambda.name
  policy_arn = aws_iam_policy.launcher_lambda.arn
}

data "aws_iam_policy_document" "api_gateway_cloudwatch_assume_role" {
  statement {
    sid    = "AllowApiGatewayAssumeRole"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole"
    ]
  }
}

resource "aws_iam_role" "api_gateway_cloudwatch" {
  name               = "${local.name_prefix}-api-gateway-cloudwatch-role"
  assume_role_policy = data.aws_iam_policy_document.api_gateway_cloudwatch_assume_role.json
  description        = "Allows API Gateway REST API to write execution logs to CloudWatch."
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  role       = aws_iam_role.api_gateway_cloudwatch.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn

  depends_on = [
    aws_iam_role_policy_attachment.api_gateway_cloudwatch
  ]
}
