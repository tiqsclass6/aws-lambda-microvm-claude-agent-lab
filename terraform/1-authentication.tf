terraform {
  required_version = ">= 1.15.0"

  backend "s3" {
    bucket       = "class-7-state-files"
    key          = "lambda-labs/microvm.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.8"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
  }
}
