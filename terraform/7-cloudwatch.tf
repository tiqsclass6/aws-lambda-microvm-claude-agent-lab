resource "aws_cloudwatch_log_group" "microvm" {
  name              = local.microvm_log_group_name
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "launcher" {
  name              = "/aws/lambda/${local.launcher_function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = local.api_log_group_name
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_metric_filter" "launcher_errors" {
  name           = "${local.name_prefix}-launcher-errors"
  log_group_name = aws_cloudwatch_log_group.launcher.name

  # Do not include "Invalid webhook signature" here.
  # A 401 response is expected for unsigned manual curl tests.
  pattern = "?ERROR ?Exception ?Traceback ?AccessDeniedException ?Runtime.ImportModuleError"

  metric_transformation {
    name      = "LauncherErrors"
    namespace = "LambdaMicroVM/${local.name_prefix}"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "launcher_errors" {
  alarm_name          = "${local.name_prefix}-launcher-errors"
  alarm_description   = "Launcher Lambda logged an error, exception, traceback, import error, or access denied exception."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.launcher_errors.metric_transformation[0].name
  namespace           = "LambdaMicroVM/${local.name_prefix}"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_log_metric_filter" "api_gateway_5xx" {
  name           = "${local.name_prefix}-api-gateway-5xx"
  log_group_name = aws_cloudwatch_log_group.api_gateway.name
  pattern        = "{ $.status >= 500 }"

  metric_transformation {
    name      = "ApiGateway5xx"
    namespace = "LambdaMicroVM/${local.name_prefix}"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "api_gateway_5xx" {
  alarm_name          = "${local.name_prefix}-api-gateway-5xx"
  alarm_description   = "API Gateway returned one or more 5XX responses."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.api_gateway_5xx.metric_transformation[0].name
  namespace           = "LambdaMicroVM/${local.name_prefix}"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
}