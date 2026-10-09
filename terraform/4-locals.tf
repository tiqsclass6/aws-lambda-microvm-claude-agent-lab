locals {
  name_prefix = "${var.project_name}-${var.environment}"

  artifact_bucket_name = coalesce(
    var.artifact_bucket_name,
    "${local.name_prefix}-artifacts-${random_id.suffix.hex}"
  )

  cloudtrail_bucket_name = "${local.name_prefix}-cloudtrail-${random_id.suffix.hex}"

  app_source_dir       = abspath("${path.module}/../app")
  build_dir            = abspath("${path.module}/../build")
  artifact_zip_path    = abspath("${path.module}/../build/app.zip")
  launcher_package_dir = abspath("${path.module}/../build/launcher-package")
  launcher_zip_path    = abspath("${path.module}/../build/launcher.zip")

  microvm_log_group_name  = "/aws/lambda/microvms/${var.microvm_image_name}"
  microvm_log_stream_name = "image-build"

  launcher_function_name = "${local.name_prefix}-microvm-launcher"
  api_log_group_name     = "/aws/apigateway/${local.name_prefix}-claude-webhook"

  environment_variable_list = [
    for key, value in var.environment_variables : {
      Key   = key
      Value = value
    }
  ]

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Lab         = "LambdaMicroVMClaudeManagedAgents"
  }
}
