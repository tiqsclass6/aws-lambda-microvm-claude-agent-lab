variable "aws_region" {
  description = "AWS Region where the Lambda MicroVM platform will be deployed."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short project name used for resource naming."
  type        = string
  default     = "lambda-microvm-lab"

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.project_name))
    error_message = "project_name may only contain letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"
}

variable "python_command" {
  description = "Python command Terraform should use when packaging the launcher Lambda dependencies. Use python3 on Linux/macOS if python is unavailable."
  type        = string
  default     = "python"
}

variable "artifact_bucket_name" {
  description = "Optional fixed S3 artifact bucket name. Leave empty to generate a globally unique bucket name."
  type        = string
  default     = "microvm-artifacts-bucket"
}

variable "artifact_key" {
  description = "S3 object key for the MicroVM application artifact zip."
  type        = string
  default     = "microvm-artifacts/app.zip"
}

variable "microvm_image_name" {
  description = "Name of the Lambda MicroVM image."
  type        = string
  default     = "class7-microvm-image"

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]{1,64}$", var.microvm_image_name))
    error_message = "microvm_image_name must be 1-64 characters and may contain letters, numbers, hyphens, and underscores."
  }
}

variable "microvm_description" {
  description = "Description for the Lambda MicroVM image."
  type        = string
  default     = "Class 7 Lambda MicroVM image built from Terraform."
}

variable "microvm_base_image_arn" {
  description = "Lambda-managed MicroVM base image ARN."
  type        = string
  default     = "arn:aws:lambda:us-east-1:aws:microvm-image:al2023-1"
}

variable "microvm_base_image_version" {
  description = "Specific managed MicroVM base image version."
  type        = string
}

variable "microvm_minimum_memory_mib" {
  description = "Minimum memory in MiB for the MicroVM image."
  type        = number
  default     = 2048

  validation {
    condition     = contains([512, 1024, 2048, 4096, 8192], var.microvm_minimum_memory_mib)
    error_message = "Use a supported MicroVM baseline memory value: 512, 1024, 2048, 4096, or 8192 MiB."
  }
}

variable "application_port" {
  description = "Port the app listens on inside the MicroVM image."
  type        = number
  default     = 8080

  validation {
    condition     = var.application_port >= 1 && var.application_port <= 65535
    error_message = "application_port must be between 1 and 65535."
  }
}

variable "ready_timeout_seconds" {
  description = "Timeout for the MicroVM image ready hook."
  type        = number
  default     = 60
}

variable "validate_timeout_seconds" {
  description = "Timeout for the MicroVM image validate hook."
  type        = number
  default     = 60
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days."
  type        = number
  default     = 14
}

variable "egress_network_connectors" {
  description = "Runtime egress network connectors available to MicroVMs created from this image."
  type        = list(string)

  default = [
    "arn:aws:lambda:us-east-1:aws:network-connector:aws-network-connector:INTERNET_EGRESS"
  ]
}

variable "environment_variables" {
  description = "Environment variables configured for the MicroVM runtime environment."
  type        = map(string)

  default = {
    NODE_ENV = "production"
    PORT     = "8080"
  }
}

variable "anthropic_environment_id" {
  description = "Claude Managed Agents self-hosted environment ID."
  type        = string
}

variable "launcher_memory_size" {
  description = "Launcher Lambda memory size in MB."
  type        = number
  default     = 256
}

variable "launcher_timeout_seconds" {
  description = "Launcher Lambda timeout in seconds."
  type        = number
  default     = 30
}

variable "microvm_max_duration_seconds" {
  description = "Hard maximum runtime for a launched MicroVM. AWS Lambda MicroVMs support up to 28800 seconds."
  type        = number
  default     = 28800
}

variable "microvm_idle_policy" {
  description = "Idle policy used by the launcher when starting session MicroVMs."
  type = object({
    maxIdleDurationSeconds   = number
    suspendedDurationSeconds = number
    autoResumeEnabled        = bool
  })
  default = {
    maxIdleDurationSeconds   = 120
    suspendedDurationSeconds = 0
    autoResumeEnabled        = false
  }
}
