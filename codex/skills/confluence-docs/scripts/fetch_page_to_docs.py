#!/usr/bin/env python3
"""Fetch Confluence pages by ID and write them to local Markdown files."""

from __future__ import annotations

import argparse
import base64
import collections
import html
import json
import os
import re
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Iterable


SCRIPT_DIR = Path(__file__).resolve().parent
SKILL_DIR = SCRIPT_DIR.parent
DEFAULT_ENV_PATH = SKILL_DIR / ".env"
DEFAULT_OUTPUT_DIR = SKILL_DIR / "docs"


def load_env_file(path: Path) -> None:
    if not path.exists():
        return
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip())


def require_env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise SystemExit(f"Missing required environment variable: {name}")
    return value


def make_auth_headers() -> dict[str, str]:
    email = require_env("CONFLUENCE_EMAIL")
    api_token = require_env("CONFLUENCE_API_TOKEN")
    auth = base64.b64encode(f"{email}:{api_token}".encode("utf-8")).decode("ascii")
    return {
        "Authorization": f"Basic {auth}",
        "Accept": "application/json",
        "User-Agent": "confluence-docs-fetcher/1.0",
    }


def confluence_request_json(path: str, query: dict[str, str] | None = None) -> dict:
    base_url = require_env("CONFLUENCE_BASE_URL").rstrip("/")
    query_string = urllib.parse.urlencode(query or {})
    url = f"{base_url}{path}"
    if query_string:
        url = f"{url}?{query_string}"
    request = urllib.request.Request(
        url,
        headers=make_auth_headers(),
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def confluence_get_json(page_id: str) -> dict:
    return confluence_request_json(
        f"/api/v2/pages/{page_id}",
        {"body-format": "storage", "include-version": "true"},
    )


def list_child_page_ids(parent_page_id: str) -> list[str]:
    child_ids: list[str] = []
    start = 0
    limit = 100
    while True:
        payload = confluence_request_json(
            f"/rest/api/content/{parent_page_id}/child/page",
            {"limit": str(limit), "start": str(start)},
        )
        results = payload.get("results", [])
        child_ids.extend(str(item["id"]) for item in results if item.get("id"))
        if len(results) < limit:
            break
        start += limit
    return child_ids


def collect_descendant_page_ids(parent_page_id: str, recursive: bool) -> list[str]:
    if not recursive:
        return list_child_page_ids(parent_page_id)

    queue: collections.deque[str] = collections.deque([parent_page_id])
    seen: set[str] = {parent_page_id}
    descendants: list[str] = []

    while queue:
        current = queue.popleft()
        for child_id in list_child_page_ids(current):
            if child_id in seen:
                continue
            seen.add(child_id)
            descendants.append(child_id)
            queue.append(child_id)
    return descendants


def slugify(value: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9]+", "-", value).strip("-")
    return slug or "page"


def collapse_whitespace(text: str) -> str:
    return re.sub(r"\s+", " ", text or "").strip()


def text_from_node(node: ET.Element) -> str:
    parts: list[str] = []

    def visit(current: ET.Element) -> None:
        if current.text:
            parts.append(current.text)
        for child in current:
            visit(child)
            if child.tail:
                parts.append(child.tail)

    visit(node)
    return collapse_whitespace(html.unescape("".join(parts)))


def list_prefix(tag: str, index: int) -> str:
    return f"{index}. " if tag == "ol" else "- "


def append_block(lines: list[str], text: str = "") -> None:
    if lines and lines[-1] == "" and text == "":
        return
    lines.append(text)


def render_children(
    node: ET.Element,
    lines: list[str],
    *,
    indent: int = 0,
) -> None:
    ordered_index = 0
    for child in node:
        local_name = child.tag.rsplit("}", 1)[-1]
        if local_name in {"h1", "h2", "h3", "h4", "h5", "h6"}:
            level = int(local_name[1])
            append_block(lines)
            text = text_from_node(child)
            if text:
                append_block(lines, f"{'#' * level} {text}")
                append_block(lines)
        elif local_name == "p":
            text = text_from_node(child)
            if text:
                append_block(lines, (" " * indent) + text)
                append_block(lines)
        elif local_name in {"ul", "ol"}:
            ordered_index = 0
            for item in child:
                if item.tag.rsplit("}", 1)[-1] != "li":
                    continue
                ordered_index += 1
                prefix = (" " * indent) + list_prefix(local_name, ordered_index)
                text = text_from_node(item)
                if text:
                    append_block(lines, prefix + text)
                nested_lines: list[str] = []
                render_children(item, nested_lines, indent=indent + 2)
                for nested in nested_lines:
                    append_block(lines, nested)
            append_block(lines)
        elif local_name == "table":
            append_block(lines, (" " * indent) + "[Table content omitted in text conversion]")
            append_block(lines)
        elif local_name in {"structured-macro", "adf-extension", "layout", "layout-section"}:
            render_children(child, lines, indent=indent)
        else:
            render_children(child, lines, indent=indent)


def confluence_storage_to_markdown(storage_value: str) -> str:
    wrapped = f"<root>{storage_value}</root>"
    wrapped = re.sub(r"&nbsp;", " ", wrapped)
    try:
        root = ET.fromstring(wrapped)
    except ET.ParseError:
        # Fall back to a coarse text extraction if the storage body is not XML-clean.
        text = re.sub(r"<[^>]+>", " ", storage_value)
        return collapse_whitespace(html.unescape(text))

    lines: list[str] = []
    render_children(root, lines)
    while lines and lines[-1] == "":
        lines.pop()
    return "\n".join(lines).strip()


def markitdown_convert_storage(storage_value: str, title: str) -> str:
    try:
        from markitdown import MarkItDown
    except ImportError as exc:
        raise RuntimeError(
            "markitdown is not installed. Install it with "
            "`python3 -m pip install --user --break-system-packages markitdown`."
        ) from exc

    html_document = (
        "<!doctype html><html><head>"
        f"<meta charset='utf-8'><title>{html.escape(title)}</title>"
        "</head><body>"
        f"{storage_value}"
        "</body></html>"
    )
    with tempfile.NamedTemporaryFile("w", suffix=".html", encoding="utf-8", delete=False) as handle:
        temp_path = Path(handle.name)
        handle.write(html_document)
    try:
        result = MarkItDown().convert(temp_path)
        return (result.markdown or result.text_content or "").strip()
    finally:
        temp_path.unlink(missing_ok=True)


def build_document(page: dict, *, use_markitdown: bool = False) -> str:
    title = page["title"]
    page_id = page["id"]
    version = page.get("version", {}).get("number", "unknown")
    space_id = page.get("spaceId", "unknown")
    webui = page.get("_links", {}).get("webui", "")
    base = page.get("_links", {}).get("base", "")
    url = f"{base}{webui}" if base and webui else ""
    storage_value = page.get("body", {}).get("storage", {}).get("value", "")
    body = (
        markitdown_convert_storage(storage_value, title)
        if use_markitdown
        else confluence_storage_to_markdown(storage_value)
    )

    metadata = [
        f"# {title}",
        "",
        f"- Page ID: `{page_id}`",
        f"- Space ID: `{space_id}`",
        f"- Version: `{version}`",
    ]
    if url:
        metadata.append(f"- URL: {url}")
    metadata.extend(["", "## Content", "", body or "_No readable content extracted._", ""])
    return "\n".join(metadata)


def write_output(output_dir: Path, page: dict, content: str) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    filename = f"{page['id']}-{slugify(page['title'])}.md"
    output_path = output_dir / filename
    output_path.write_text(content, encoding="utf-8")
    return output_path


def parse_args(argv: Iterable[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Fetch a Confluence page and write it to a local Markdown file."
    )
    parser.add_argument("page_id", help="Confluence page ID")
    parser.add_argument(
        "--env-file",
        type=Path,
        default=DEFAULT_ENV_PATH,
        help=f"Path to env file (default: {DEFAULT_ENV_PATH})",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help=f"Directory for generated docs (default: {DEFAULT_OUTPUT_DIR})",
    )
    parser.add_argument(
        "--children",
        action="store_true",
        help="Fetch child pages for the given page ID instead of only the page itself.",
    )
    parser.add_argument(
        "--recursive",
        action="store_true",
        help="When used with --children, walk all descendant pages recursively.",
    )
    parser.add_argument(
        "--use-markitdown",
        action="store_true",
        help="Convert the Confluence storage HTML with the markitdown library before writing the .md file.",
    )
    return parser.parse_args(list(argv))


def main(argv: Iterable[str]) -> int:
    args = parse_args(argv)
    load_env_file(args.env_file)
    try:
        if args.children:
            parent_page = confluence_get_json(args.page_id)
            page_ids = collect_descendant_page_ids(args.page_id, recursive=args.recursive)
            output_dir = args.output_dir / f"{parent_page['id']}-{slugify(parent_page['title'])}"
            for page_id in page_ids:
                page = confluence_get_json(page_id)
                document = build_document(page, use_markitdown=args.use_markitdown)
                output_path = write_output(output_dir, page, document)
                print(output_path)
            return 0

        page = confluence_get_json(args.page_id)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        print(f"HTTP error {exc.code}: {detail}", file=sys.stderr)
        return 1
    except urllib.error.URLError as exc:
        print(f"Network error: {exc.reason}", file=sys.stderr)
        return 1
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    document = build_document(page, use_markitdown=args.use_markitdown)
    output_path = write_output(args.output_dir, page, document)
    print(output_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
