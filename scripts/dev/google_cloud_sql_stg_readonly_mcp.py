#!/usr/bin/env python3
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request

PROJECT_ID = os.environ.get("GOOGLE_CLOUD_PROJECT", "")
INSTANCE_ID = os.environ.get("CLOUD_SQL_INSTANCE", "")
DATABASE_NAME = os.environ.get("CLOUD_SQL_DATABASE", "")
SERVICE_ACCOUNT = os.environ.get("GOOGLE_MCP_IMPERSONATE_SERVICE_ACCOUNT", "")
TOOL_NAME = "execute_sql_readonly"
SERVER_NAME = "google-cloud-sql-stg-readonly"

FORBIDDEN_SQL = re.compile(
    r"\b("
    r"insert|update|delete|alter|drop|create|truncate|grant|revoke|comment|"
    r"vacuum|reindex|cluster|copy|call|do|merge|refresh|analyze|explain\s+analyze|"
    r"begin|commit|rollback|savepoint|lock|set\s+role|reset\s+role"
    r")\b",
    re.IGNORECASE,
)


def write_message(payload: dict) -> None:
    sys.stdout.write(json.dumps(payload) + "\n")
    sys.stdout.flush()


def read_message():
    first_line = sys.stdin.buffer.readline()
    if not first_line:
        return None

    stripped = first_line.strip()
    if stripped.startswith(b"{"):
        return json.loads(stripped.decode("utf-8"))

    headers = {}
    line = first_line
    while True:
        if line in (b"\r\n", b"\n"):
            break
        key, value = line.decode("utf-8").split(":", 1)
        headers[key.strip().lower()] = value.strip()
        line = sys.stdin.buffer.readline()
        if not line:
            return None

    length = int(headers["content-length"])
    body = sys.stdin.buffer.read(length)
    return json.loads(body.decode("utf-8"))


def get_access_token() -> str:
    env_token = os.environ.get("GOOGLE_MCP_ACCESS_TOKEN", "").strip()
    if env_token:
        return env_token

    env = os.environ.copy()
    env["GOOGLE_CLOUD_PROJECT"] = PROJECT_ID
    env["GOOGLE_MCP_IMPERSONATE_SERVICE_ACCOUNT"] = SERVICE_ACCOUNT
    helper = os.path.join(os.path.dirname(os.path.realpath(__file__)), "google-mcp-access-token.sh")

    try:
        result = subprocess.run(
            [helper, "--token-only"],
            check=True,
            capture_output=True,
            text=True,
            env=env,
        )
        token = result.stdout.strip()
        if token:
            return token
    except Exception:
        pass

    result = subprocess.run(
        [
            "gcloud",
            "auth",
            "print-access-token",
            "--project",
            PROJECT_ID,
            "--impersonate-service-account",
            SERVICE_ACCOUNT,
        ],
        check=True,
        capture_output=True,
        text=True,
        env=env,
    )
    return result.stdout.strip()


def validate_sql(sql_statement: str) -> str:
    sql = sql_statement.strip()
    if not sql:
        raise ValueError("sqlStatement must not be empty")

    trimmed = sql[:-1].strip() if sql.endswith(";") else sql
    if ";" in trimmed:
        raise ValueError("Only a single SQL statement is allowed")

    if not re.match(r"^(select|with|explain)\b", sql, re.IGNORECASE):
        raise ValueError("Only read-only SELECT, WITH, or EXPLAIN statements are allowed")

    if FORBIDDEN_SQL.search(sql):
        raise ValueError("The SQL statement contains a forbidden keyword for this read-only tool")

    return sql


def execute_readonly_sql(sql_statement: str, row_limit: int | None):
    if not all((PROJECT_ID, INSTANCE_ID, DATABASE_NAME, SERVICE_ACCOUNT)):
        raise ValueError("Configure GOOGLE_CLOUD_PROJECT, CLOUD_SQL_INSTANCE, CLOUD_SQL_DATABASE, and GOOGLE_MCP_IMPERSONATE_SERVICE_ACCOUNT")
    token = get_access_token()
    payload = {
        "database": DATABASE_NAME,
        "sqlStatement": validate_sql(sql_statement),
        "autoIamAuthn": True,
    }
    if row_limit is not None:
        payload["rowLimit"] = str(row_limit)

    request = urllib.request.Request(
        f"https://sqladmin.googleapis.com/sql/v1beta4/projects/{PROJECT_ID}/instances/{INSTANCE_ID}/executeSql",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Cloud SQL executeSql failed with HTTP {exc.code}: {body}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"Cloud SQL executeSql network error: {exc}") from exc


def result_to_text(result: dict) -> str:
    if "status" in result:
        return result["status"].get("message", "Execution failed.")

    results = result.get("results", [])
    row_count = sum(len(item.get("rows", [])) for item in results)
    return f"Execution complete. {row_count} row(s) returned across {len(results)} result set(s)."


TOOL_DEF = {
    "name": TOOL_NAME,
    "description": (
        "Execute a single read-only SQL statement against the fixed staging database "
        "the configured project, instance, and database using auto IAM auth. "
        "This tool is intended to replace the flaky remote Cloud SQL readonly SQL MCP path."
    ),
    "inputSchema": {
        "type": "object",
        "properties": {
            "sqlStatement": {
                "type": "string",
                "description": "A single read-only SQL statement. Only SELECT, WITH, or EXPLAIN are allowed.",
            },
            "rowLimit": {
                "type": "integer",
                "description": "Optional row limit forwarded to the Cloud SQL executeSql API.",
            },
        },
        "required": ["sqlStatement"],
        "additionalProperties": False,
    },
}


def handle_request(message: dict):
    method = message.get("method")
    request_id = message.get("id")

    if method == "initialize":
        return {
            "jsonrpc": "2.0",
            "id": request_id,
            "result": {
                "protocolVersion": "2025-06-18",
                "serverInfo": {
                    "name": SERVER_NAME,
                    "version": "0.1.0",
                },
                "capabilities": {
                    "tools": {},
                },
            },
        }

    if method == "notifications/initialized":
        return None

    if method == "ping":
        return {"jsonrpc": "2.0", "id": request_id, "result": {}}

    if method == "tools/list":
        return {"jsonrpc": "2.0", "id": request_id, "result": {"tools": [TOOL_DEF]}}

    if method == "tools/call":
        params = message.get("params", {})
        name = params.get("name")
        arguments = params.get("arguments", {})
        if name != TOOL_NAME:
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "error": {"code": -32602, "message": f"Unknown tool: {name}"},
            }

        try:
            result = execute_readonly_sql(arguments["sqlStatement"], arguments.get("rowLimit"))
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "result": {
                    "content": [{"type": "text", "text": result_to_text(result)}],
                    "structuredContent": result,
                },
            }
        except KeyError:
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "error": {"code": -32602, "message": "Missing required argument: sqlStatement"},
            }
        except Exception as exc:
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "result": {
                    "content": [{"type": "text", "text": str(exc)}],
                    "isError": True,
                },
            }

    return {
        "jsonrpc": "2.0",
        "id": request_id,
        "error": {"code": -32601, "message": f"Method not found: {method}"},
    }


def main():
    while True:
        message = read_message()
        if message is None:
            return
        response = handle_request(message)
        if response is not None:
            write_message(response)


if __name__ == "__main__":
    main()
