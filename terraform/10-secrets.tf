resource "aws_secretsmanager_secret" "claude_environment_key" {
  name                    = "${local.name_prefix}/claude/environment-key"
  description             = "Claude Managed Agents environment key used only by MicroVM runtime workers."
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret" "claude_webhook_signing_secret" {
  name                    = "${local.name_prefix}/claude/webhook-signing-secret"
  description             = "Claude Managed Agents webhook signing secret used only by the launcher Lambda."
  recovery_window_in_days = 0
}