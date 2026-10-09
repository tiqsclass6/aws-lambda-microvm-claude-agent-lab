import base64
import json
import logging
import os
from typing import Any, Dict, Mapping, Optional

import anthropic
import boto3
from botocore.exceptions import ClientError


logger = logging.getLogger()
logger.setLevel(logging.INFO)

lambda_client = boto3.client("lambda-microvms")
secretsmanager = boto3.client("secretsmanager")


def response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
        },
        "body": json.dumps(body),
    }


def normalize_headers(headers: Optional[Mapping[str, Any]]) -> Dict[str, str]:
    normalized: Dict[str, str] = {}

    if not headers:
        return normalized

    for key, value in headers.items():
        if key is None or value is None:
            continue
        normalized[str(key).lower()] = str(value)

    return normalized


def has_webhook_signature_header(headers: Mapping[str, str]) -> bool:
    # Keep this broad so the lab does not depend on a single capitalization style.
    signature_header_names = {
        "x-webhook-signature",
        "webhook-signature",
        "anthropic-webhook-signature",
    }

    return any(header_name in headers for header_name in signature_header_names)


def get_required_env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise RuntimeError(f"Missing required Lambda environment variable: {name}")
    return value


def get_secret(secret_arn: str) -> str:
    try:
        result = secretsmanager.get_secret_value(SecretId=secret_arn)
    except ClientError as exc:
        error_code = exc.response.get("Error", {}).get("Code", "Unknown")
        raise RuntimeError(f"Unable to read Secrets Manager secret {secret_arn}: {error_code}") from exc

    secret_string = result.get("SecretString")
    if not secret_string:
        raise RuntimeError(f"Secret {secret_arn} does not contain a SecretString value")

    return secret_string


def decode_body(event: Dict[str, Any]) -> str:
    raw_body = event.get("body") or "{}"

    if event.get("isBase64Encoded"):
        return base64.b64decode(raw_body).decode("utf-8")

    return raw_body


def to_plain_dict(value: Any) -> Dict[str, Any]:
    if isinstance(value, dict):
        return value

    if hasattr(value, "model_dump"):
        return value.model_dump()

    if hasattr(value, "dict"):
        return value.dict()

    return json.loads(json.dumps(value, default=str))


def unwrap_claude_webhook(raw_body: str, headers: Mapping[str, str], signing_secret: str) -> Dict[str, Any]:
    # Anthropic SDK webhook verification reads this value from the environment.
    os.environ["ANTHROPIC_WEBHOOK_SIGNING_KEY"] = signing_secret

    # API key is not used for webhook verification here, but some SDK versions expect a value.
    client = anthropic.Anthropic(
        api_key=os.environ.get("ANTHROPIC_API_KEY", "not-used-for-webhook-verification")
    )

    event = client.beta.webhooks.unwrap(raw_body, headers=headers)
    return to_plain_dict(event)


def first_present(*values: Optional[str]) -> Optional[str]:
    for value in values:
        if value:
            return value
    return None


def extract_session_id(payload: Dict[str, Any]) -> Optional[str]:
    data = payload.get("data") or {}
    session = payload.get("session") or data.get("session") or {}

    return first_present(
        payload.get("session_id"),
        payload.get("sessionId"),
        session.get("id"),
        data.get("session_id"),
        data.get("sessionId"),
        data.get("id"),
    )


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    logger.info("Launcher Lambda received webhook request")

    raw_body = decode_body(event)
    headers = normalize_headers(event.get("headers"))

    # Manual curl tests are intentionally unsigned. Return 401 instead of failing at import/runtime.
    if not has_webhook_signature_header(headers):
        logger.warning("Webhook request rejected because no signature header was present")
        return response(401, {"error": "Invalid webhook signature"})

    try:
        aws_region = os.environ.get("AWS_REGION") or os.environ.get("AWS_DEFAULT_REGION") or "us-east-1"
        anthropic_environment_id = get_required_env("ANTHROPIC_ENVIRONMENT_ID")
        microvm_image_arn = get_required_env("MICROVM_IMAGE_ARN")
        microvm_runtime_role_arn = get_required_env("MICROVM_RUNTIME_ROLE_ARN")
        claude_environment_secret_arn = get_required_env("CLAUDE_ENVIRONMENT_SECRET_ARN")
        webhook_signing_secret_arn = get_required_env("WEBHOOK_SIGNING_SECRET_ARN")
        microvm_idle_policy = json.loads(get_required_env("MICROVM_IDLE_POLICY"))
        microvm_max_duration_seconds = int(os.environ.get("MICROVM_MAX_DURATION_SECONDS", "28800"))
    except Exception as exc:
        logger.exception("Launcher Lambda configuration error")
        return response(500, {"error": "Launcher Lambda configuration error", "details": str(exc)})

    try:
        signing_secret = get_secret(webhook_signing_secret_arn)
    except Exception as exc:
        logger.exception("Webhook signing secret is not configured correctly")
        return response(500, {"error": "Webhook signing secret not configured", "details": str(exc)})

    try:
        webhook = unwrap_claude_webhook(raw_body, headers, signing_secret)
    except Exception as exc:
        logger.warning("Invalid webhook signature or stale webhook payload: %s", exc)
        return response(401, {"error": "Invalid webhook signature"})

    event_type = webhook.get("type")
    event_id = webhook.get("id") or webhook.get("event_id")

    if event_type != "session.status_run_started":
        logger.info("Ignoring webhook event type: %s", event_type)
        return response(
            202,
            {
                "message": "Webhook ignored",
                "event_type": event_type,
                "event_id": event_id,
            },
        )

    session_id = extract_session_id(webhook)
    if not session_id:
        logger.error("Missing Claude session id in webhook payload: %s", json.dumps(webhook)[:2000])
        return response(400, {"error": "Missing Claude session id"})

    run_hook_payload = {
        "source": "claude-managed-agents",
        "event_id": event_id,
        "session_id": session_id,
        "anthropic_environment_id": anthropic_environment_id,
        "claude_environment_key_secret_arn": claude_environment_secret_arn,
    }

    logger.info("Launching MicroVM for Claude session %s", session_id)

    try:
        result = lambda_client.run_microvm(
            ImageIdentifier=microvm_image_arn,
            ExecutionRoleArn=microvm_runtime_role_arn,
            IngressNetworkConnectors=[
                f"arn:aws:lambda:{aws_region}:aws:network-connector:aws-network-connector:ALL_INGRESS"
            ],
            EgressNetworkConnectors=[
                f"arn:aws:lambda:{aws_region}:aws:network-connector:aws-network-connector:INTERNET_EGRESS"
            ],
            IdlePolicy=microvm_idle_policy,
            MaximumDurationInSeconds=microvm_max_duration_seconds,
            RunHookPayload=json.dumps(run_hook_payload),
        )
    except ClientError as exc:
        logger.exception("Failed to launch Lambda MicroVM")
        return response(
            500,
            {
                "error": "Failed to launch Lambda MicroVM",
                "details": exc.response.get("Error", {}).get("Code", "Unknown"),
            },
        )
    except Exception as exc:
        logger.exception("Unexpected error while launching Lambda MicroVM")
        return response(500, {"error": "Unexpected MicroVM launch error", "details": str(exc)})

    microvm_id = result.get("MicrovmId") or result.get("microvmId")
    state = result.get("State") or result.get("state")
    endpoint = result.get("Endpoint") or result.get("endpoint")

    logger.info("Launched MicroVM %s for session %s", microvm_id, session_id)

    return response(
        200,
        {
            "message": "MicroVM launched",
            "session_id": session_id,
            "event_id": event_id,
            "microvm_id": microvm_id,
            "state": state,
            "endpoint": endpoint,
        },
    )