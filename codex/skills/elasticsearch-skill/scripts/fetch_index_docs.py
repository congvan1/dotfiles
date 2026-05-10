#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import Counter
import csv
import io
from dataclasses import dataclass
from typing import Any

from dataviews import DATA_VIEWS, resolve_dataview
from es_client import ElasticsearchClient, extract_shard_failures, load_config, normalize_hit, print_json, resolve_time_range, validate_index_pattern, validate_positive_int


LEVEL_ALIASES = {
    "error": ["ERROR", "Error", "error"],
    "warn": ["WARN", "WARNING", "Warning", "warn", "warning"],
    "info": ["INFO", "Info", "info"],
}

COMPACT_SOURCE_FIELDS = [
    "@timestamp",
    "message",
    "log.original",
    "event.original",
    "decode.alert_level",
    "decode.caller",
    "decode.alert_msg",
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
    parser = argparse.ArgumentParser(description="Fetch documents from Elasticsearch by index pattern.")
    parser.add_argument("--index-pattern", help="Example: '.ds-k8s-prd_sn-prd-pulsar*'")
    parser.add_argument("--dataview", choices=sorted(DATA_VIEWS), help="Use a simulated Kibana data view name.")
    parser.add_argument("--minutes", type=int, default=60, help="Look back window in minutes. Default: 60")
    parser.add_argument("--from", dest="time_from", help="Absolute start time, for example: 2026-04-03T11:00:00+07:00")
    parser.add_argument("--to", dest="time_to", help="Absolute end time, for example: 2026-04-03T12:00:00+07:00")
    parser.add_argument("--tz", default="Asia/Ho_Chi_Minh", help="Timezone for naive --from/--to values. Default: Asia/Ho_Chi_Minh")
    parser.add_argument("--limit", type=int, default=50, help="Max number of docs. Default: 50")
    parser.add_argument("--level", default="all", choices=["error", "warn", "info", "all"])
    parser.add_argument("--text", help="Optional text filter, for example: timeout OR ledger")
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

    for grouped_event in grouped_events:
        writer.writerow(
            [
                grouped_event.start_time,
                grouped_event.end_time,
                grouped_event.count,
                grouped_event.key.level,
                grouped_event.key.caller,
                grouped_event.key.alert_msg,
                grouped_event.key.component,
                grouped_event.key.pod,
            ]
        )
    return output_buffer.getvalue().rstrip()


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
    if not args.index_pattern and not args.dataview:
        raise SystemExit("Provide one of `--index-pattern` or `--dataview`.")
    if args.index_pattern and args.dataview:
        raise SystemExit("Use only one of `--index-pattern` or `--dataview`.")

    index_pattern = resolve_dataview(args.dataview) if args.dataview else validate_index_pattern(args.index_pattern)
    validate_positive_int("minutes", args.minutes, maximum=7 * 24 * 60)
    validate_positive_int("limit", args.limit, maximum=50000)

    config = load_config()
    client = ElasticsearchClient(config)
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
        print(build_csv_text(events, raw_hits))
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
