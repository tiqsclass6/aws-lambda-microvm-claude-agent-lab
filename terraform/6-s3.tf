resource "aws_s3_bucket" "artifact" {
  bucket        = local.artifact_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "artifact" {
  bucket = aws_s3_bucket.artifact.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifact" {
  bucket = aws_s3_bucket.artifact.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }

    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "artifact" {
  bucket = aws_s3_bucket.artifact.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "app_artifact" {
  bucket = aws_s3_bucket.artifact.id
  key    = var.artifact_key
  source = data.archive_file.app_package.output_path
  etag   = data.archive_file.app_package.output_md5

  server_side_encryption = "AES256"

  depends_on = [
    aws_s3_bucket_server_side_encryption_configuration.artifact,
    aws_s3_bucket_public_access_block.artifact
  ]
}
