const http = require("http");

const port = process.env.PORT || 8080;

function sendJson(res, statusCode, payload) {
  res.writeHead(statusCode, {
    "Content-Type": "application/json"
  });
  res.end(JSON.stringify(payload));
}

async function readBody(req) {
  return new Promise((resolve, reject) => {
    let body = "";

    req.on("data", chunk => {
      body += chunk.toString();
    });

    req.on("end", () => resolve(body));
    req.on("error", reject);
  });
}

async function handleRunHook(req, res) {
  const rawBody = await readBody(req);
  let payload = {};

  try {
    payload = rawBody ? JSON.parse(rawBody) : {};
  } catch (error) {
    return sendJson(res, 400, {
      ok: false,
      error: "Invalid JSON run hook payload"
    });
  }

  console.log("MicroVM run hook received:", JSON.stringify({
    source: payload.source,
    event_id: payload.event_id,
    session_id: payload.session_id,
    anthropic_environment_id: payload.anthropic_environment_id,
    claude_environment_key_secret_arn_present: Boolean(payload.claude_environment_key_secret_arn)
  }));

  /*
    Student lab behavior:

    This app proves that the Lambda MicroVM image can boot, expose lifecycle hooks,
    receive the Run hook payload, and return a successful hook response.

    A real Claude Managed Agents worker would use the Claude environment key,
    claim session work, execute tools inside /workspace, and send results back to Claude.
    That worker loop is intentionally not implemented in this student lab.
  */

  return sendJson(res, 200, {
    ok: true,
    lab_mode: true,
    message: "Run hook accepted by the student lab MicroVM worker stub.",
    session_id: payload.session_id || null,
    next_step: "Replace this stub with a real Claude Managed Agents worker loop for full production behavior."
  });
}

const server = http.createServer(async (req, res) => {
  console.log(`${req.method} ${req.url}`);

  try {
    if (req.url === "/" || req.url === "/health") {
      return sendJson(res, 200, {
        ok: true,
        service: "lambda-microvm-claude-agent-lab",
        lab_mode: true,
        message: "Student lab MicroVM worker is running."
      });
    }

    if (req.url === "/aws/lambda-microvms/runtime/v1/ready") {
      return sendJson(res, 200, {
        ready: true,
        service: "lambda-microvm-claude-agent-lab",
        platform: "lambda-microvm"
      });
    }

    if (req.url === "/aws/lambda-microvms/runtime/v1/validate") {
      return sendJson(res, 200, {
        valid: true,
        service: "lambda-microvm-claude-agent-lab",
        platform: "lambda-microvm"
      });
    }

    if (req.url === "/aws/lambda-microvms/runtime/v1/run") {
      return await handleRunHook(req, res);
    }

    if (req.url === "/aws/lambda-microvms/runtime/v1/terminate") {
      console.log("MicroVM terminate hook received.");

      return sendJson(res, 200, {
        ok: true,
        message: "Terminate hook acknowledged."
      });
    }

    return sendJson(res, 404, {
      ok: false,
      error: "Route not found",
      path: req.url
    });
  } catch (error) {
    console.error("Unhandled application error:", error);

    return sendJson(res, 500, {
      ok: false,
      error: "Internal server error"
    });
  }
});

server.listen(port, () => {
  console.log(`Lambda MicroVM student lab worker listening on port ${port}`);
});