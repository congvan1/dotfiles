#!/usr/bin/env python3
from __future__ import annotations

import base64
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo


def load_dotenv(dotenv_path: Path) -> dict[str, str]:
    data: dict[str, str] = {}
    if not dotenv_path.exists():
        return data

    for raw_line in dotenv_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip("'").strip('"')
        if key:
            data[key] = value
    return data


def load_config() -> dict[str, str]:
    base_dir = Path(__file__).resolve().parent
    env_data: dict[str, str] = {}

    for env_path in (base_dir / ".env", base_dir.parent / ".env"):
        env_data.update(load_dotenv(env_path))

    merged = dict(env_data)
    merged.update({k: v for k, v in os.environ.items() if v})
    return merged


def require_config(config: dict[str, str], key: str) -> str:
    value = config.get(key, "").strip()
    if not value:
        fail(
            f"Missing config `{key}`. Add it to "
            f"{Path(__file__).resolve().parent.parent / '.env'} or export it in your shell."
        )
    return value


def fail(message: str, exit_code: int = 2) -> None:
    print(json.dumps({"error": message}, ensure_ascii=False, indent=2), file=sys.stderr)
    raise SystemExit(exit_code)


def validate_positive_int(name: str, value: int, minimum: int = 1, maximum: int = 1000) -> int:
    if not (minimum <= value <= maximum):
        fail(f"`{name}` must be between {minimum} and {maximum}. Got {value}.")
    return value


def validate_index_pattern(index_pattern: str) -> str:
    pattern = index_pattern.strip()
    if not pattern:
        fail("`--index-pattern` cannot be empty.")
    if " " in pattern:
        fail("`--index-pattern` must not contain spaces.")
    return pattern


def parse_user_datetime(value: str, tz_name: str) -> str:
    raw = value.strip()
    if not raw:
        fail("Datetime input cannot be empty.")

    normalized = raw.replace("Z", "+00:00")
    parsed: datetime | None = None

    for candidate in (normalized, normalized.replace(" ", "T", 1)):
        try:
            parsed = datetime.fromisoformat(candidate)
            break
        except ValueError:
            continue

    if parsed is None:
        fail(
            "Unsupported datetime format. Use ISO-like input such as "
            "`2026-04-03T11:00:00+07:00` or `2026-04-03 11:00`."
        )

    if parsed.tzinfo is None:
        try:
            parsed = parsed.replace(tzinfo=ZoneInfo(tz_name))
        except Exception as exc:
            fail(f"Invalid timezone `{tz_name}`: {exc}")

    return parsed.isoformat()


def resolve_time_range(minutes: int, time_from: str | None, time_to: str | None, tz_name: str) -> dict[str, str]:
    if bool(time_from) != bool(time_to):
        fail("Provide both `--from` and `--to`, or neither.")

    if time_from and time_to:
        gte = parse_user_datetime(time_from, tz_name)
        lte = parse_user_datetime(time_to, tz_name)
        if gte >= lte:
            fail("`--from` must be earlier than `--to`.")
        return {"gte": gte, "lte": lte}

    return {"gte": f"now-{minutes}m", "lte": "now"}


def pick_first(hit: dict[str, Any], field_names: list[str], default: Any = None) -> Any:
    source = hit.get("_source", {})
    fields = hit.get("fields", {})

    for field_name in field_names:
        if field_name in source and source[field_name] not in (None, ""):
            return source[field_name]
        current: Any = source
        found = True
        for part in field_name.split("."):
            if isinstance(current, dict) and part in current:
                current = current[part]
            else:
                found = False
                break
        if found and current not in (None, ""):
            return current
        if field_name in fields:
            field_value = fields[field_name]
            if isinstance(field_value, list):
                if field_value:
                    return field_value[0]
            elif field_value not in (None, ""):
                return field_value
    return default


def normalize_hit(hit: dict[str, Any]) -> dict[str, Any]:
    message = pick_first(hit, ["message", "log.original", "event.original"], "")
    if isinstance(message, list):
        message = " ".join(str(item) for item in message)

    error_type = pick_first(
        hit,
        [
            "error.type",
            "exception.type",
            "labels.error_type",
            "json.error.type",
        ],
    )
    stack = pick_first(
        hit,
        [
            "error.stack_trace",
            "error.stack",
            "exception.stacktrace",
            "stacktrace",
        ],
    )

    return {
        "index": hit.get("_index"),
        "id": hit.get("_id"),
        "timestamp": pick_first(hit, ["@timestamp", "timestamp"]),
        "level": pick_first(
            hit,
            ["decode.alert_level", "log.level", "level", "severity", "labels.level"],
            "UNKNOWN",
        ),
        "service": pick_first(
            hit,
            [
                "service.name",
                "service",
                "kubernetes.labels.app",
                "kubernetes.container.name",
            ],
        ),
        "environment": pick_first(hit, ["labels.env", "environment", "env"]),
        "trace_id": pick_first(hit, ["trace.id", "trace_id", "labels.trace_id"]),
        "request_id": pick_first(
            hit,
            [
                "http.request.id",
                "request.id",
                "request_id",
                "labels.request_id",
                "correlation_id",
            ],
        ),
        "error_type": error_type,
        "message": message,
        "stack": stack,
        "host": pick_first(hit, ["host.name", "host.hostname", "kubernetes.pod.name"]),
        "caller": pick_first(hit, ["decode.caller"]),
        "alert_msg": pick_first(hit, ["decode.alert_msg", "error.message"]),
    }


class ElasticsearchClient:
    def __init__(self, config: dict[str, str]) -> None:
        self.base_url = require_config(config, "ES_URL").rstrip("/")
        self.api_key = config.get("ES_API_KEY", "").strip()
        self.username = config.get("ES_USERNAME", "").strip()
        self.password = config.get("ES_PASSWORD", "").strip()
        self.verify_tls = config.get("ES_VERIFY_TLS", "true").strip().lower() not in {"0", "false", "no"}
        self.timeout_seconds = int(config.get("ES_TIMEOUT_SECONDS", "30"))

        if not self.api_key and not (self.username and self.password):
            fail("Provide either `ES_API_KEY` or both `ES_USERNAME` and `ES_PASSWORD`.")

    def _build_headers(self) -> dict[str, str]:
        headers = {
            "Accept": "application/json",
            "Content-Type": "application/json",
        }
        if self.api_key:
            headers["Authorization"] = f"ApiKey {self.api_key}"
        else:
            token = base64.b64encode(f"{self.username}:{self.password}".encode("utf-8")).decode("ascii")
            headers["Authorization"] = f"Basic {token}"
        return headers

    def _request(self, method: str, path: str, payload: dict[str, Any] | None = None) -> dict[str, Any]:
        url = f"{self.base_url}/{path.lstrip('/')}"
        body = None if payload is None else json.dumps(payload).encode("utf-8")
        request = urllib.request.Request(url=url, data=body, method=method, headers=self._build_headers())

        try:
            with urllib.request.urlopen(request, timeout=self.timeout_seconds) as response:
                response_body = response.read().decode("utf-8")
                return json.loads(response_body) if response_body else {}
        except urllib.error.HTTPError as exc:
            details = exc.read().decode("utf-8", errors="replace")
            fail(f"Elasticsearch HTTP {exc.code} for `{url}`: {details}", exit_code=1)
        except urllib.error.URLError as exc:
            fail(f"Cannot connect to Elasticsearch `{url}`: {exc.reason}", exit_code=1)

    def search(self, index_pattern: str, query: dict[str, Any]) -> dict[str, Any]:
        encoded_index = urllib.parse.quote(index_pattern, safe="*,-_.")
        return self._request("POST", f"{encoded_index}/_search", query)


def print_json(data: dict[str, Any]) -> None:
    print(json.dumps(data, ensure_ascii=False, indent=2))


def extract_shard_failures(response: dict[str, Any]) -> list[dict[str, Any]]:
    shards = response.get("_shards", {})
    failures = shards.get("failures", []) or []
    return failures
