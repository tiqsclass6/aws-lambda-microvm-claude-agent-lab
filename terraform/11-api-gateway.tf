resource "aws_api_gateway_rest_api" "claude_webhook" {
  name        = "${local.name_prefix}-claude-webhook-rest-api"
  description = "REST API endpoint for Claude Managed Agents webhook events."

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "claude" {
  rest_api_id = aws_api_gateway_rest_api.claude_webhook.id
  parent_id   = aws_api_gateway_rest_api.claude_webhook.root_resource_id
  path_part   = "claude"
}

resource "aws_api_gateway_resource" "webhook" {
  rest_api_id = aws_api_gateway_rest_api.claude_webhook.id
  parent_id   = aws_api_gateway_resource.claude.id
  path_part   = "webhook"
}

resource "aws_api_gateway_method" "claude_webhook_post" {
  rest_api_id   = aws_api_gateway_rest_api.claude_webhook.id
  resource_id   = aws_api_gateway_resource.webhook.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "claude_webhook_lambda" {
  rest_api_id = aws_api_gateway_rest_api.claude_webhook.id
  resource_id = aws_api_gateway_resource.webhook.id
  http_method = aws_api_gateway_method.claude_webhook_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.microvm_launcher.invoke_arn
}

resource "aws_api_gateway_deployment" "claude_webhook" {
  rest_api_id = aws_api_gateway_rest_api.claude_webhook.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.claude.id,
      aws_api_gateway_resource.webhook.id,
      aws_api_gateway_method.claude_webhook_post.id,
      aws_api_gateway_integration.claude_webhook_lambda.id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.claude_webhook_lambda
  ]
}

resource "aws_api_gateway_stage" "prod" {
  rest_api_id   = aws_api_gateway_rest_api.claude_webhook.id
  deployment_id = aws_api_gateway_deployment.claude_webhook.id
  stage_name    = "prod"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn

    format = jsonencode({
      requestId         = "$context.requestId"
      ip                = "$context.identity.sourceIp"
      requestTime       = "$context.requestTime"
      httpMethod        = "$context.httpMethod"
      resourcePath      = "$context.resourcePath"
      status            = "$context.status"
      protocol          = "$context.protocol"
      responseLength    = "$context.responseLength"
      integrationStatus = "$context.integration.status"
      errorMessage      = "$context.error.message"
    })
  }

  depends_on = [
    aws_api_gateway_account.main,
    aws_cloudwatch_log_group.api_gateway
  ]
}

resource "aws_api_gateway_method_settings" "prod" {
  rest_api_id = aws_api_gateway_rest_api.claude_webhook.id
  stage_name  = aws_api_gateway_stage.prod.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled    = true
    logging_level      = "INFO"
    data_trace_enabled = false
  }

  depends_on = [
    aws_api_gateway_account.main
  ]
}

resource "aws_lambda_permission" "allow_api_gateway_launcher" {
  statement_id  = "AllowApiGatewayInvokeLauncher"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.microvm_launcher.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.claude_webhook.execution_arn}/*/*"
}
