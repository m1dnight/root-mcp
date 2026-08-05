"""Client helper for RootMCP composition scripts.

Stdlib-only. Talks MCP (Streamable HTTP, JSON responses) to the RootMCP
proxy endpoint given by the ROOT_MCP_URL / ROOT_MCP_TOKEN environment
variables, which the composition runner injects.

Usage inside a composition:

    from root import call_tool, text

    def run(args):
        result = call_tool("time", "get_current_time", {"timezone": "UTC"})
        return {"now": text(result)}
"""

import json
import os
import urllib.request

_PROTOCOL_VERSION = "2025-06-18"

_session_id = None
_request_id = 1


class ToolError(Exception):
    """Raised when an upstream tool call fails or reports isError."""


def call_tool(upstream, tool, arguments=None):
    """Call `tool` of `upstream` through the RootMCP proxy.

    Returns the MCP call result as a dict: {"content": [...], "isError": bool}.
    Raises ToolError on protocol errors or when the tool reports an error.
    """
    result = _request(
        "tools/call",
        {"name": f"{upstream}__{tool}", "arguments": arguments or {}},
    )
    if result.get("isError"):
        raise ToolError(text(result) or json.dumps(result))
    return result


def text(result):
    """Concatenated text content of a tool result."""
    return "".join(
        c.get("text", "") for c in result.get("content", []) if c.get("type") == "text"
    )


def _request(method, params):
    _ensure_session()
    response = _post({"method": method, "params": params}, request=True)
    if "error" in response:
        raise ToolError(json.dumps(response["error"]))
    return response["result"]


def _ensure_session():
    global _session_id
    if _session_id is not None:
        return
    body, headers = _post_raw(
        {
            "method": "initialize",
            "params": {
                "protocolVersion": _PROTOCOL_VERSION,
                "capabilities": {},
                "clientInfo": {"name": "root-composition", "version": "0.1.0"},
            },
        },
        request=True,
    )
    if "error" in body:
        raise ToolError(json.dumps(body["error"]))
    _session_id = headers["mcp-session-id"]
    _post({"method": "notifications/initialized"}, request=False)


def _post(payload, request):
    body, _headers = _post_raw(payload, request)
    return body


def _post_raw(payload, request):
    global _request_id
    message = {"jsonrpc": "2.0", **payload}
    if request:
        message["id"] = _request_id
        _request_id += 1

    req = urllib.request.Request(
        os.environ["ROOT_MCP_URL"],
        data=json.dumps(message).encode(),
        method="POST",
    )
    req.add_header("Content-Type", "application/json")
    req.add_header("Accept", "application/json")
    req.add_header("Authorization", "Bearer " + os.environ["ROOT_MCP_TOKEN"])
    if _session_id is not None:
        req.add_header("mcp-session-id", _session_id)
        req.add_header("mcp-protocol-version", _PROTOCOL_VERSION)

    with urllib.request.urlopen(req) as resp:
        raw = resp.read()
        headers = {k.lower(): v for k, v in resp.headers.items()}
    return (json.loads(raw) if raw else {}), headers
