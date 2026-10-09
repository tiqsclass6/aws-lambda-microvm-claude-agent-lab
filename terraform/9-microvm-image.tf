resource "aws_cloudformation_stack" "microvm_image" {
  name = "${local.name_prefix}-microvm-image-stack"

  template_body = yamlencode({
    AWSTemplateFormatVersion = "2010-09-09"
    Description              = "Lambda MicroVM image created by Terraform through AWS::Lambda::MicrovmImage."

    Resources = {
      MicrovmImage = {
        Type = "AWS::Lambda::MicrovmImage"

        Properties = {
          Name             = var.microvm_image_name
          Description      = var.microvm_description
          BaseImageArn     = var.microvm_base_image_arn
          BaseImageVersion = var.microvm_base_image_version
          BuildRoleArn     = aws_iam_role.microvm_build.arn

          CodeArtifact = {
            Uri = "s3://${aws_s3_bucket.artifact.bucket}/${aws_s3_object.app_artifact.key}"
          }

          CpuConfigurations = [
            {
              Architecture = "ARM_64"
            }
          ]

          Resources = [
            {
              MinimumMemoryInMiB = var.microvm_minimum_memory_mib
            }
          ]

          AdditionalOsCapabilities = [
            "ALL"
          ]

          EgressNetworkConnectors = var.egress_network_connectors

          EnvironmentVariables = local.environment_variable_list

          Hooks = {
            Port = var.application_port

            MicrovmImageHooks = {
              Ready                    = "ENABLED"
              ReadyTimeoutInSeconds    = var.ready_timeout_seconds
              Validate                 = "ENABLED"
              ValidateTimeoutInSeconds = var.validate_timeout_seconds
            }

            MicrovmHooks = {
              Run                       = "ENABLED"
              RunTimeoutInSeconds       = 60
              Resume                    = "DISABLED"
              ResumeTimeoutInSeconds    = 10
              Suspend                   = "DISABLED"
              SuspendTimeoutInSeconds   = 10
              Terminate                 = "ENABLED"
              TerminateTimeoutInSeconds = 30
            }
          }

          Logging = {
            CloudWatch = {
              LogGroup  = aws_cloudwatch_log_group.microvm.name
              LogStream = local.microvm_log_stream_name
            }
          }

          Tags = [
            for key, value in local.common_tags : {
              Key   = key
              Value = value
            }
          ]
        }
      }
    }

    Outputs = {
      MicrovmImageName = {
        Description = "Name of the Lambda MicroVM image."
        Value       = { Ref = "MicrovmImage" }
      }

      MicrovmImageArn = {
        Description = "ARN of the Lambda MicroVM image."
        Value       = { "Fn::GetAtt" = ["MicrovmImage", "ImageArn"] }
      }

      LatestActiveImageVersion = {
        Description = "Latest active MicroVM image version."
        Value       = { "Fn::GetAtt" = ["MicrovmImage", "LatestActiveImageVersion"] }
      }

      MicrovmImageState = {
        Description = "Current MicroVM image state."
        Value       = { "Fn::GetAtt" = ["MicrovmImage", "State"] }
      }
    }
  })

  depends_on = [
    aws_iam_role_policy_attachment.microvm_build,
    aws_s3_object.app_artifact,
    aws_cloudwatch_log_group.microvm
  ]
}
