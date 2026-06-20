#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import Counter
import csv
from datetime import datetime
import io
from dataclasses import dataclass
from typing import Any

from dataviews import format_dataview_listing, resolve_dataview
from es_client import ElasticsearchClient, extract_shard_failures, load_config, normalize_hit, print_json, resolve_time_range, validate_index_pattern, validate_positive_int


LEVEL_ALIASES = {
    "error": ["ERROR", "Error", "error"],
    "warn": ["WARN", "WARNING", "Warning", "warn", "warning"],
    "info": ["INFO", "Info", "info"],
}

ANSI_RESET = "\033[0m"
ANSI_BOLD_GREEN = "\033[1;32m"
ANSI_BOLD_YELLOW = "\033[1;33m"
ANSI_BOLD_RED = "\033[1;31m"
CSV_DITTO_MARK = "^"

COMPACT_SOURCE_FIELDS = [
    "@timestamp",
    "message",
    "log.original",
    "event.original",
    "decode.alert_level",
    "decode.caller",
    "decode.alert_msg",
    "decode.alert_error",
    "decode.alert_stacktrace",
    "decode.stack_trace",
    "error.message",
    "error.type",
    "kubernetes.labels.component",
    "kubernetes.pod.name",
    "kubernetes.container.name",
]

FULL_SOURCE_FIELDS = [
    "@timestamp",
    "message",
    "log.original",
    "event.original",
    "decode.alert_level",
    "decode.caller",
    "decode.alert_msg",
    "decode.alert_error",
    "decode.alert_stacktrace",
    "decode.stack_trace",
    "error.message",
    "error.type",
    "error.stack_trace",
    "exception.type",
    "exception.stacktrace",
    "kubernetes.labels.component",
    "kubernetes.pod.name",
    "kubernetes.container.name",
    "kubernetes.labels.controller-revision-hash",
    "log.file.path",
    "host.name",
    "host.hostname",
]


@dataclass(frozen=True)
class CsvEventGroupKey:
    level: str | None
    caller: str | None
    alert_msg: str | None
    component: str | None
    pod: str | None


@dataclass
class CsvEventGroup:
    start_time: str
    end_time: str
    count: int
    key: CsvEventGroupKey


def compact_message(event: dict[str, Any], max_chars: int) -> str | None:
    message = event.get("message")

    if not message:
        return None

    text = " ".join(str(message).split())
    if len(text) <= max_chars:
        return text
    return text[: max_chars - 1].rstrip() + "…"


def build_case_insensitive_keyword_filter(field: str, values: list[str]) -> dict[str, Any]:
    raw_should = []
    for value in values:
        raw_should.append(
            {
                "wildcard": {
                    field: {
                        "value": value,
                        "case_insensitive": True,
                    }
                }
            }
        )
        raw_should.append(
            {
                "wildcard": {
                    f"{field}.keyword": {
                        "value": value,
                        "case_insensitive": True,
                    }
                }
            }
        )
    return {
        "bool": {
            "should": raw_should,
            "minimum_should_match": 1,
        }
    }


def build_contains_keyword_filter(field: str, value: str) -> dict[str, Any]:
    pattern = value if any(wildcard in value for wildcard in ("*", "?")) else f"*{value}*"
    return build_case_insensitive_keyword_filter(field, [pattern])


def build_level_filter(level: str) -> dict[str, Any] | None:
    if level == "all":
        return None

    if level == "error":
        return {
            "bool": {
                "should": [
                    build_case_insensitive_keyword_filter("log.level", LEVEL_ALIASES["error"]),
                    build_case_insensitive_keyword_filter("level", LEVEL_ALIASES["error"]),
                    build_case_insensitive_keyword_filter("severity", LEVEL_ALIASES["error"]),
                    build_case_insensitive_keyword_filter("decode.alert_level", LEVEL_ALIASES["error"]),
                    {"exists": {"field": "error.type"}},
                    {"exists": {"field": "exception.type"}},
                ],
                "minimum_should_match": 1,
            }
        }

    if level == "warn":
        return {
            "bool": {
                "should": [
                    build_case_insensitive_keyword_filter("log.level", LEVEL_ALIASES["warn"]),
                    build_case_insensitive_keyword_filter("level", LEVEL_ALIASES["warn"]),
                    build_case_insensitive_keyword_filter("severity", LEVEL_ALIASES["warn"]),
                    build_case_insensitive_keyword_filter("decode.alert_level", LEVEL_ALIASES["warn"]),
                ],
                "minimum_should_match": 1,
            }
        }

    if level == "info":
        return {
            "bool": {
                "should": [
                    build_case_insensitive_keyword_filter("log.level", LEVEL_ALIASES["info"]),
                    build_case_insensitive_keyword_filter("level", LEVEL_ALIASES["info"]),
                    build_case_insensitive_keyword_filter("severity", LEVEL_ALIASES["info"]),
                    build_case_insensitive_keyword_filter("decode.alert_level", LEVEL_ALIASES["info"]),
                ],
                "minimum_should_match": 1,
            }
        }

    return None


def build_query(
    args: argparse.Namespace,
    *,
    page_size: int,
    search_after: list[Any] | None = None,
) -> dict[str, Any]:
    must: list[dict[str, Any]] = [
        {
            "range": {
                "@timestamp": resolve_time_range(args.minutes, args.time_from, args.time_to, args.tz)
            }
        }
    ]

    level_filter = build_level_filter(args.level)
    if level_filter is not None:
        must.append(level_filter)

    if args.text:
        must.append(
            {
                "simple_query_string": {
                    "query": args.text,
                    "fields": [
                        "message",
                        "log.original",
                        "event.original",
                        "error.message",
                        "error.type",
                        "error.stack_trace",
                        "exception.type",
                        "exception.stacktrace",
                        "stacktrace",
                        "decode.alert_msg",
                        "decode.caller",
                        "kubernetes.pod.name",
                        "kubernetes.container.name",
                    ],
                    "default_operator": "and",
                    "lenient": True,
                }
            }
        )

    if args.pod:
        must.append(build_contains_keyword_filter("kubernetes.pod.name", args.pod))

    if args.container:
        must.append(build_contains_keyword_filter("kubernetes.container.name", args.container))

    if args.log_file:
        must.append(build_contains_keyword_filter("log.file.path", args.log_file))

    query = {
        "size": page_size,
        "sort": [{"@timestamp": {"order": args.sort}}],
        "track_total_hits": True,
        "_source": args.source_fields or (FULL_SOURCE_FIELDS if args.output == "full" else COMPACT_SOURCE_FIELDS),
        "query": {"bool": {"must": must}},
    }

    if search_after is not None:
        query["search_after"] = search_after

    return query


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Fetch documents from Elasticsearch by index pattern.",
        add_help=False,
    )
    parser.add_argument("--help", action="help", help="Show this help message and exit.")
    parser.add_argument(
        "--index-pattern",
        "--index",
        dest="index_pattern",
        help="Exact index or index pattern. Example: 'stg-db-cassandra-2026-05-26' or '.ds-k8s-prd_sn-prd-pulsar*'",
    )
    parser.add_argument(
        "--dataview",
        help=(
            "Kibana data view to query, across all spaces. Use a bare name "
            "(resolved if unique) or `space:name` to disambiguate, e.g. "
            "`dev:sn-dev-workload`. Falls back to a deprecated local alias when "
            "Kibana has no match. Use --list-dataviews to see all options."
        ),
    )
    parser.add_argument(
        "--list-dataviews",
        action="store_true",
        help="List curated local aliases and real Kibana data views, then exit.",
    )
    parser.add_argument("--minutes", type=int, default=60, help="Look back window in minutes. Default: 60")
    parser.add_argument("--from", dest="time_from", help="Absolute start time, for example: 2026-04-03T11:00:00+07:00")
    parser.add_argument("--to", dest="time_to", help="Absolute end time, for example: 2026-04-03T12:00:00+07:00")
    parser.add_argument("--tz", default="Asia/Ho_Chi_Minh", help="Timezone for naive --from/--to values. Default: Asia/Ho_Chi_Minh")
    parser.add_argument("--limit", type=int, default=50, help="Max number of docs. Default: 50")
    parser.add_argument("--level", default="all", choices=["error", "warn", "info", "all"])
    parser.add_argument("--text", help="Optional text filter, for example: timeout OR ledger")
    parser.add_argument("--pod", help="Filter kubernetes.pod.name by exact name, wildcard, or substring.")
    parser.add_argument("--container", help="Filter kubernetes.container.name by exact name, wildcard, or substring.")
    parser.add_argument("--log-file", help="Filter log.file.path by exact path, wildcard, or substring.")
    parser.add_argument(
        "-h",
        dest="human_readable",
        action="store_true",
        help="Human-readable table output with ISO timestamps. Help is --help.",
    )
    parser.add_argument("--sort", default="desc", choices=["asc", "desc"])
    parser.add_argument(
        "--output",
        default="csv",
        choices=["csv", "compact", "full", "message"],
        help="CSV is the default for token-efficient LLM analysis. Use compact/full for JSON, or message for message-only output.",
    )
    parser.add_argument("--message-chars", type=int, default=10000, help="Max chars for compact message field. Default: 10000")
    parser.add_argument(
        "--source-fields",
        nargs="*",
        help="Optional list of _source fields to return. If omitted, returns full _source.",
    )
    return parser.parse_args()


def build_csv_text(
    events: list[dict[str, Any]],
    raw_hits: list[dict[str, Any]],
    *,
    human_readable: bool = False,
) -> str:
    grouped_events = build_grouped_csv_events(events, raw_hits)
    output_buffer = io.StringIO()
    writer = csv.writer(output_buffer, lineterminator="\n")
    writer.writerow(
        [
            "start_time",
            "end_time",
            "count",
            "level",
            "caller",
            "alert_msg",
            "component",
            "pod",
        ]
    )

    previous_ditto_values: dict[str, str | None] = {}
    for grouped_event in grouped_events:
        level = ditto_csv_value("level", grouped_event.key.level, previous_ditto_values)
        caller = ditto_csv_value("caller", grouped_event.key.caller, previous_ditto_values)
        component = ditto_csv_value("component", grouped_event.key.component, previous_ditto_values)
        pod = ditto_csv_value("pod", grouped_event.key.pod, previous_ditto_values)
        writer.writerow(
            [
                format_csv_time(grouped_event.start_time, human_readable=human_readable),
                (
                    "-"
                    if grouped_event.count == 1
                    else format_csv_time(grouped_event.end_time, human_readable=human_readable)
                ),
                grouped_event.count,
                level,
                caller,
                grouped_event.key.alert_msg,
                component,
                pod,
            ]
        )
    return output_buffer.getvalue().rstrip()


def ditto_csv_value(field_name: str, value: str | None, previous_values: dict[str, str | None]) -> str | None:
    previous_value = previous_values.get(field_name)
    previous_values[field_name] = value
    if value not in (None, "") and value == previous_value:
        return CSV_DITTO_MARK
    return value


def build_table_text(
    events: list[dict[str, Any]],
    raw_hits: list[dict[str, Any]],
    *,
    limit: int,
) -> str:
    grouped_events = build_grouped_csv_events(events, raw_hits)
    headers = ["start_time", "end_time", "count", "level", "caller", "component", "pod", "alert_msg"]
    rows: list[list[str]] = []

    for grouped_event in grouped_events:
        rows.append(
            [
                format_csv_time(grouped_event.start_time, human_readable=True),
                "-" if grouped_event.count == 1 else format_csv_time(grouped_event.end_time, human_readable=True),
                str(grouped_event.count),
                format_table_cell(grouped_event.key.level),
                format_table_cell(grouped_event.key.caller),
                format_table_cell(grouped_event.key.component),
                format_table_cell(grouped_event.key.pod),
                format_table_cell(grouped_event.key.alert_msg),
            ]
        )

    widths = [
        max(len(row[idx]) for row in [headers, *rows])
        for idx in range(len(headers) - 1)
    ]
    lines = [format_table_row(headers, widths, limit=limit)]
    lines.append(format_table_row(["-" * len(header) for header in headers], widths))
    lines.extend(format_table_row(row, widths, limit=limit) for row in rows)
    return "\n".join(lines)


def format_table_row(row: list[str], widths: list[int], *, limit: int | None = None) -> str:
    padded = [color_table_cell(idx, row[idx].ljust(widths[idx]), row[idx], limit) for idx in range(len(widths))]
    return "  ".join([*padded, color_table_cell(len(row) - 1, row[-1], row[-1], limit)])


def color_table_cell(column_idx: int, padded_value: str, raw_value: str, limit: int | None) -> str:
    if column_idx == 2 and limit:
        try:
            count = int(raw_value)
        except ValueError:
            return padded_value
        ratio = count / limit
        if ratio > 0.3:
            return f"{ANSI_BOLD_RED}{padded_value}{ANSI_RESET}"
        if ratio > 0.1:
            return f"{ANSI_BOLD_YELLOW}{padded_value}{ANSI_RESET}"
        return padded_value

    if column_idx == 3:
        normalized = raw_value.lower()
        if normalized == "error":
            return f"{ANSI_BOLD_RED}{padded_value}{ANSI_RESET}"
        if normalized in {"warn", "warning"}:
            return f"{ANSI_BOLD_YELLOW}{padded_value}{ANSI_RESET}"
        if normalized == "info":
            return f"{ANSI_BOLD_GREEN}{padded_value}{ANSI_RESET}"

    return padded_value


def format_table_cell(value: Any) -> str:
    if value in (None, ""):
        return "-"
    return " ".join(str(value).split())


def format_csv_time(value: str, *, human_readable: bool = False) -> str:
    if not value:
        return ""
    if human_readable:
        return value
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return value
    return str(int(parsed.timestamp() * 1000))


def build_message_text(
    events: list[dict[str, Any]],
    raw_hits: list[dict[str, Any]],
    max_chars: int,
) -> str:
    output_buffer = io.StringIO()
    writer = csv.writer(output_buffer, lineterminator="\n")
    writer.writerow(["timestamp", "pod", "message"])

    for idx, raw_hit in enumerate(raw_hits):
        source = raw_hit.get("_source", {})
        pod_name = source.get("kubernetes", {}).get("pod", {}).get("name")
        writer.writerow(
            [
                events[idx].get("timestamp"),
                pod_name,
                compact_message(events[idx], max_chars),
            ]
        )

    return output_buffer.getvalue().rstrip()


def build_grouped_csv_events(
    events: list[dict[str, Any]],
    raw_hits: list[dict[str, Any]],
) -> list[CsvEventGroup]:
    grouped_events: list[CsvEventGroup] = []
    current_group: CsvEventGroup | None = None

    for idx, raw_hit in enumerate(raw_hits):
        source = raw_hit.get("_source", {})
        event = events[idx]
        timestamp = event.get("timestamp") or ""
        group_key = CsvEventGroupKey(
            level=event.get("level"),
            caller=event.get("caller"),
            alert_msg=event.get("alert_msg"),
            component=source.get("kubernetes", {}).get("labels", {}).get("component"),
            pod=source.get("kubernetes", {}).get("pod", {}).get("name"),
        )

        if current_group is None or current_group.key != group_key:
            current_group = CsvEventGroup(
                start_time=timestamp,
                end_time=timestamp,
                count=1,
                key=group_key,
            )
            grouped_events.append(current_group)
            continue

        current_group.end_time = timestamp
        current_group.count += 1

    for grouped_event in grouped_events:
        grouped_event.start_time, grouped_event.end_time = sort_time_range(
            grouped_event.start_time,
            grouped_event.end_time,
        )

    return grouped_events


def sort_time_range(first_time: str, second_time: str) -> tuple[str, str]:
    if first_time <= second_time:
        return first_time, second_time
    return second_time, first_time


def main() -> None:
    args = parse_args()

    config = load_config()
    client = ElasticsearchClient(config)

    if args.list_dataviews:
        print(format_dataview_listing(client))
        return

    if not args.index_pattern and not args.dataview:
        raise SystemExit("Provide one of `--index-pattern` or `--dataview`.")
    if args.index_pattern and args.dataview:
        raise SystemExit("Use only one of `--index-pattern` or `--dataview`.")

    index_pattern = (
        resolve_dataview(args.dataview, client)
        if args.dataview
        else validate_index_pattern(args.index_pattern)
    )
    validate_positive_int("minutes", args.minutes, maximum=7 * 24 * 60)
    validate_positive_int("limit", args.limit, maximum=50000)
    page_size = min(args.limit, 1000)
    raw_hits: list[dict[str, Any]] = []
    seen_hit_ids: set[str] = set()
    shard_failures: list[dict[str, Any]] = []
    total_hits: int | None = None
    failed_shards = 0
    search_after: list[Any] | None = None

    while len(raw_hits) < args.limit:
        response = client.search(
            index_pattern,
            build_query(
                args,
                page_size=min(page_size, args.limit - len(raw_hits)),
                search_after=search_after,
            ),
        )
        shard_failures.extend(extract_shard_failures(response))
        failed_shards += response.get("_shards", {}).get("failed", 0)
        if total_hits is None:
            total_hits = response.get("hits", {}).get("total", {}).get("value")

        page_hits = response.get("hits", {}).get("hits", [])
        if not page_hits:
            break

        for hit in page_hits:
            hit_id = hit.get("_id")
            if hit_id and hit_id in seen_hit_ids:
                continue
            if hit_id:
                seen_hit_ids.add(hit_id)
            raw_hits.append(hit)
            if len(raw_hits) >= args.limit:
                break
        search_after = page_hits[-1].get("sort")
        if not search_after:
            break

    events = [normalize_hit(hit) for hit in raw_hits]
    index_counter = Counter(event.get("index") or "UNKNOWN" for event in events)

    if args.output == "csv":
        if args.human_readable:
            print(build_table_text(events, raw_hits, limit=args.limit))
            return
        print(build_csv_text(events, raw_hits, human_readable=args.human_readable))
        return

    if args.output == "message":
        print(build_message_text(events, raw_hits, args.message_chars))
        return

    print_json(
        {
            "meta": {
                "dataview": args.dataview,
                "index_pattern": index_pattern,
                "minutes": args.minutes,
                "from": args.time_from,
                "to": args.time_to,
                "tz": args.tz,
                "limit": args.limit,
                "level": args.level,
                "text": args.text,
                "pod": args.pod,
                "container": args.container,
                "log_file": args.log_file,
                "output": args.output,
                "returned": len(raw_hits),
                "total_hits": total_hits,
                "failed_shards": failed_shards,
            },
            "summary": {
                "top_indexes": [{"index": name, "count": count} for name, count in index_counter.most_common(10)],
                "shard_failures": shard_failures[:5],
            },
            "documents": [
                (
                    {
                        "timestamp": events[idx].get("timestamp"),
                        "level": events[idx].get("level"),
                        "decode": raw_hit.get("_source", {}).get("decode", {}),
                        "caller": events[idx].get("caller"),
                        "alert_msg": events[idx].get("alert_msg"),
                        "component": (
                            raw_hit.get("_source", {})
                            .get("kubernetes", {})
                            .get("labels", {})
                            .get("component")
                        ),
                        "pod": (
                            raw_hit.get("_source", {})
                            .get("kubernetes", {})
                            .get("pod", {})
                            .get("name")
                        ),
                        "message": compact_message(events[idx], args.message_chars),
                    }
                    if args.output == "compact"
                    else {
                        "normalized": events[idx],
                        "source": raw_hit.get("_source", {}),
                    }
                )
                for idx, raw_hit in enumerate(raw_hits)
            ],
        }
    )


if __name__ == "__main__":
    main()
