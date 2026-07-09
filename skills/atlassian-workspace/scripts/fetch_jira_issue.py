#!/usr/bin/env python3
"""Fetch a Jira issue by key and print JSON or Markdown."""

from __future__ import annotations

import argparse
import base64
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
SKILL_DIR = SCRIPT_DIR.parent
DEFAULT_ENV_PATH = SKILL_DIR / ".env"

DEFAULT_FIELDS = (
    "summary,status,description,comment,assignee,reporter,created,updated,"
    "issuetype,priority,labels,attachment"
)


def load_env_file(path: Path) -> None:
    if not path.exists():
        return
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
            value = value[1:-1]
        os.environ.setdefault(key.strip(), value.strip())


def first_env(*names: str) -> str:
    for name in names:
        value = os.environ.get(name)
        if value:
            return value
    raise SystemExit(f"Missing required environment variable, expected one of: {', '.join(names)}")


def make_auth_headers() -> dict[str, str]:
    email = first_env("JIRA_EMAIL", "ATLASSIAN_EMAIL")
    api_token = first_env("JIRA_API_TOKEN", "ATLASSIAN_API_TOKEN")
    auth = base64.b64encode(f"{email}:{api_token}".encode("utf-8")).decode("ascii")
    return {
        "Authorization": f"Basic {auth}",
        "Accept": "application/json",
        "User-Agent": "atlassian-workspace-jira-fetcher/1.0",
    }


def jira_request_json(path: str, query: dict[str, str] | None = None) -> dict[str, Any]:
    base_url = first_env("JIRA_BASE_URL", "ATLASSIAN_BASE_URL").rstrip("/")
    query_string = urllib.parse.urlencode(query or {})
    url = f"{base_url}{path}"
    if query_string:
        url = f"{url}?{query_string}"
    request = urllib.request.Request(url, headers=make_auth_headers())
    timeout = int(os.environ.get("JIRA_TIMEOUT_SECONDS") or os.environ.get("ATLASSIAN_TIMEOUT_SECONDS") or "30")
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.load(response)


def adf_to_text(node: Any) -> str:
    if node is None:
        return ""
    if isinstance(node, str):
        return node
    if isinstance(node, list):
        return "\n".join(part for part in (adf_to_text(item) for item in node) if part)
    if not isinstance(node, dict):
        return ""

    node_type = node.get("type")
    if node_type == "text":
        return str(node.get("text") or "")
    if node_type == "hardBreak":
        return "\n"

    children = [part for part in (adf_to_text(item) for item in node.get("content", [])) if part]
    text = "".join(children) if node_type in {"paragraph", "heading"} else "\n".join(children)
    if node_type == "paragraph":
        return text.strip()
    if node_type == "heading":
        level = node.get("attrs", {}).get("level", 2)
        return f"{'#' * int(level)} {text.strip()}" if text.strip() else ""
    if node_type == "bulletList":
        return "\n".join(f"- {line}" for line in text.splitlines() if line)
    if node_type == "orderedList":
        return "\n".join(f"{idx}. {line}" for idx, line in enumerate(text.splitlines(), 1) if line)
    if node_type == "listItem":
        return " ".join(line.strip() for line in text.splitlines() if line.strip())
    return text.strip()


def field_name(value: Any) -> str:
    if isinstance(value, dict):
        return str(value.get("displayName") or value.get("name") or value.get("value") or "")
    return ""


def render_markdown(issue: dict[str, Any]) -> str:
    key = issue.get("key", "")
    fields = issue.get("fields", {})
    lines = [
        f"# {key}: {fields.get('summary', '')}".strip(),
        "",
        f"- Type: {field_name(fields.get('issuetype'))}",
        f"- Status: {field_name(fields.get('status'))}",
        f"- Priority: {field_name(fields.get('priority'))}",
        f"- Assignee: {field_name(fields.get('assignee')) or 'Unassigned'}",
        f"- Reporter: {field_name(fields.get('reporter'))}",
        f"- Created: {fields.get('created', '')}",
        f"- Updated: {fields.get('updated', '')}",
        f"- Labels: {', '.join(fields.get('labels') or [])}",
        "",
        "## Description",
        "",
        adf_to_text(fields.get("description")) or "_No description._",
    ]

    comments = ((fields.get("comment") or {}).get("comments") or [])
    if comments:
        lines.extend(["", "## Comments", ""])
        for comment in comments:
            author = field_name(comment.get("author")) or "Unknown"
            created = comment.get("created", "")
            body = adf_to_text(comment.get("body")) or "_No body._"
            lines.extend([f"### {author} - {created}", "", body, ""])

    attachments = fields.get("attachment") or []
    if attachments:
        lines.extend(["", "## Attachments", ""])
        for attachment in attachments:
            name = attachment.get("filename", "")
            size = attachment.get("size", "")
            lines.append(f"- {name} ({size} bytes)")

    return "\n".join(lines).rstrip() + "\n"


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("issue_key", help="Jira issue key, for example NEOSC-17607")
    parser.add_argument("--env-file", type=Path, default=DEFAULT_ENV_PATH)
    parser.add_argument("--fields", default=DEFAULT_FIELDS)
    parser.add_argument("--json", action="store_true", help="Print raw JSON instead of Markdown")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    load_env_file(args.env_file)
    try:
        issue = jira_request_json(
            f"/rest/api/3/issue/{urllib.parse.quote(args.issue_key)}",
            {"fields": args.fields},
        )
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            raise SystemExit(
                f"Jira issue {args.issue_key} was not found or is not accessible with the configured credentials."
            ) from exc
        raise

    if args.json:
        print(json.dumps(issue, indent=2, ensure_ascii=False))
    else:
        print(render_markdown(issue), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
