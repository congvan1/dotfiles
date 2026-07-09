#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
from dataclasses import asdict, dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any
from urllib.parse import urlencode
from urllib.request import Request, urlopen
import io
import sys


SCRIPT_DIRECTORY = Path(__file__).resolve().parent
if str(SCRIPT_DIRECTORY) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIRECTORY))

from catalog import MetricCatalogRegistry, build_metric_catalog_registry


TIMEOUT_SECONDS = 30
DEFAULT_RANGE_STEP = "1m"
CSV_DITTO_MARK = "^"


@dataclass(frozen=True)
class InstantQueryRequest:
    environment_name: str
    expression: str
    query_time: str | None


@dataclass(frozen=True)
class RangeQueryRequest:
    environment_name: str
    expression: str
    start_time: str
    end_time: str
    step: str


class PrometheusApiClient:
    def __init__(self, registry: MetricCatalogRegistry):
        self._registry = registry

    def run_instant_query(self, request_data: InstantQueryRequest) -> dict[str, Any]:
        environment = self._registry.get_environment(request_data.environment_name)
        params = {"query": request_data.expression}
        if request_data.query_time is not None:
            params["time"] = normalize_timestamp(request_data.query_time)
        return fetch_prometheus_response(environment.base_url, "/api/v1/query", params)

    def run_range_query(self, request_data: RangeQueryRequest) -> dict[str, Any]:
        environment = self._registry.get_environment(request_data.environment_name)
        params = {
            "query": request_data.expression,
            "start": normalize_timestamp(request_data.start_time),
            "end": normalize_timestamp(request_data.end_time),
            "step": request_data.step,
        }
        return fetch_prometheus_response(
            environment.base_url,
            "/api/v1/query_range",
            params,
        )


@dataclass(frozen=True)
class MetricQueryWindow:
    start_time: str
    end_time: str
    step: str


@dataclass(frozen=True)
class MetricSampleGroupKey:
    label_values: tuple[str, ...]
    value: str


@dataclass
class MetricSampleGroup:
    start_time: Any
    end_time: Any
    count: int
    key: MetricSampleGroupKey


def fetch_prometheus_response(
    base_url: str,
    api_path: str,
    params: dict[str, str],
) -> dict[str, Any]:
    query_string = urlencode(params)
    request = Request(f"{base_url}{api_path}?{query_string}")
    with urlopen(request, timeout=TIMEOUT_SECONDS) as response:
        payload = response.read().decode("utf-8")
    return json.loads(payload)


def normalize_timestamp(raw_value: str) -> str:
    if raw_value.isdigit():
        return raw_value
    parsed_datetime = datetime.fromisoformat(raw_value)
    return str(parsed_datetime.timestamp())


def format_prometheus_timestamp(raw_value: Any) -> str:
    try:
        timestamp = float(raw_value)
    except (TypeError, ValueError):
        return str(raw_value)
    return datetime.fromtimestamp(timestamp, timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def format_prometheus_timestamp_ms(raw_value: Any) -> str:
    try:
        timestamp = float(raw_value)
    except (TypeError, ValueError):
        return str(raw_value)
    return str(int(timestamp * 1000))


def build_argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Query VTVPrime Prometheus endpoints with a reusable metric catalog.",
        add_help=False,
    )
    parser.add_argument("--help", action="help", help="Show this help message and exit.")
    parser.add_argument(
        "-h",
        dest="human_readable",
        action="store_true",
        help="Human-readable query output as an aligned table with ISO timestamps. Help is --help.",
    )
    parser.add_argument(
        "--output",
        choices=("json", "csv"),
        default="csv",
        help="Output format. CSV is the compact default for LLM-friendly query results.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    add_catalog_commands(subparsers)
    add_query_commands(subparsers)
    return parser


def add_help_argument(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--help", action="help", help="Show this help message and exit.")


def add_catalog_commands(subparsers: argparse._SubParsersAction[Any]) -> None:
    catalog_parser = subparsers.add_parser("catalog", help="Inspect the metric catalog.", add_help=False)
    add_help_argument(catalog_parser)
    catalog_subparsers = catalog_parser.add_subparsers(
        dest="catalog_command",
        required=True,
    )

    list_parser = catalog_subparsers.add_parser("list", help="List metrics.", add_help=False)
    add_help_argument(list_parser)
    list_parser.add_argument("--component", required=True)

    describe_parser = catalog_subparsers.add_parser(
        "describe",
        help="Describe one metric.",
        add_help=False,
    )
    add_help_argument(describe_parser)
    describe_parser.add_argument("--component", required=True)
    describe_parser.add_argument("--metric", required=True)


def add_query_commands(subparsers: argparse._SubParsersAction[Any]) -> None:
    query_parser = subparsers.add_parser("query", help="Run Prometheus queries.", add_help=False)
    add_help_argument(query_parser)
    query_subparsers = query_parser.add_subparsers(
        dest="query_command",
        required=True,
    )

    metric_parser = query_subparsers.add_parser(
        "metric",
        help="Run the default PromQL for a catalog metric.",
        add_help=False,
    )
    add_help_argument(metric_parser)
    metric_parser.add_argument("--env", required=True, choices=("dev", "stg", "prd"))
    metric_parser.add_argument("--component", required=True)
    metric_parser.add_argument("--metric", required=True)
    metric_parser.add_argument("--time")
    metric_parser.add_argument("--start")
    metric_parser.add_argument("--end")
    metric_parser.add_argument("--step", default=DEFAULT_RANGE_STEP)
    metric_parser.add_argument("--anchor-time")
    metric_parser.add_argument("--backward")
    metric_parser.add_argument("--forward")

    promql_parser = query_subparsers.add_parser(
        "promql",
        help="Run a custom instant PromQL expression.",
        add_help=False,
    )
    add_help_argument(promql_parser)
    promql_parser.add_argument("--env", required=True, choices=("dev", "stg", "prd"))
    promql_parser.add_argument("--expr", required=True)
    promql_parser.add_argument("--time")

    range_parser = query_subparsers.add_parser(
        "range",
        help="Run the default PromQL for a catalog metric over a time range.",
        add_help=False,
    )
    add_help_argument(range_parser)
    range_parser.add_argument("--env", required=True, choices=("dev", "stg", "prd"))
    range_parser.add_argument("--component", required=True)
    range_parser.add_argument("--metric", required=True)
    range_parser.add_argument("--start", required=True)
    range_parser.add_argument("--end", required=True)
    range_parser.add_argument("--step", required=True)


def handle_catalog_command(
    registry: MetricCatalogRegistry,
    arguments: argparse.Namespace,
) -> dict[str, Any]:
    if arguments.catalog_command == "list":
        metrics = [asdict(metric) for metric in registry.list_metrics(arguments.component)]
        component_catalog = registry.get_component_catalog(arguments.component)
        return {
            "component": component_catalog.name,
            "version": component_catalog.version,
            "description": component_catalog.description,
            "metrics": metrics,
        }

    metric_definition = registry.get_metric_definition(
        arguments.component,
        arguments.metric,
    )
    return {
        "component": arguments.component,
        "metric": asdict(metric_definition),
    }


def handle_query_command(
    registry: MetricCatalogRegistry,
    arguments: argparse.Namespace,
) -> dict[str, Any]:
    client = PrometheusApiClient(registry)

    if arguments.query_command == "metric":
        metric_definition = registry.get_metric_definition(
            arguments.component,
            arguments.metric,
        )
        query_window = build_metric_query_window(arguments)
        if query_window is None:
            response = client.run_instant_query(
                InstantQueryRequest(
                    environment_name=arguments.env,
                    expression=metric_definition.default_promql,
                    query_time=arguments.time,
                )
            )
        else:
            response = client.run_range_query(
                RangeQueryRequest(
                    environment_name=arguments.env,
                    expression=metric_definition.default_promql,
                    start_time=query_window.start_time,
                    end_time=query_window.end_time,
                    step=query_window.step,
                )
            )
        return {
            "component": arguments.component,
            "metric": asdict(metric_definition),
            "response": response,
        }

    if arguments.query_command == "promql":
        query_request = InstantQueryRequest(
            environment_name=arguments.env,
            expression=arguments.expr,
            query_time=arguments.time,
        )
        return {
            "environment": arguments.env,
            "expression": arguments.expr,
            "response": client.run_instant_query(query_request),
        }

    metric_definition = registry.get_metric_definition(
        arguments.component,
        arguments.metric,
    )
    range_request = RangeQueryRequest(
        environment_name=arguments.env,
        expression=metric_definition.default_promql,
        start_time=arguments.start,
        end_time=arguments.end,
        step=arguments.step,
    )
    return {
        "component": arguments.component,
        "metric": asdict(metric_definition),
        "response": client.run_range_query(range_request),
    }


def build_metric_query_window(
    arguments: argparse.Namespace,
) -> MetricQueryWindow | None:
    anchored_query_window = build_anchored_query_window(arguments)
    if anchored_query_window is not None:
        return anchored_query_window

    has_any_range_argument = any(
        value is not None for value in (arguments.start, arguments.end)
    )
    if not has_any_range_argument:
        return None

    if arguments.time is not None:
        raise ValueError("Use --time for instant queries or --start/--end/--step for range queries.")

    missing_arguments = [
        name
        for name, value in (
            ("--start", arguments.start),
            ("--end", arguments.end),
        )
        if value is None
    ]
    if missing_arguments:
        missing_text = ", ".join(missing_arguments)
        raise ValueError(f"Missing range arguments: {missing_text}")

    return MetricQueryWindow(
        start_time=arguments.start,
        end_time=arguments.end,
        step=arguments.step,
    )


def build_anchored_query_window(
    arguments: argparse.Namespace,
) -> MetricQueryWindow | None:
    has_any_anchor_argument = any(
        value is not None
        for value in (arguments.anchor_time, arguments.backward, arguments.forward)
    )
    if not has_any_anchor_argument:
        return None

    if arguments.time is not None:
        raise ValueError(
            "Use --time for instant queries, --start/--end/--step for explicit ranges, "
            "or --anchor-time with --backward/--forward and --step for anchored ranges."
        )

    if arguments.start is not None or arguments.end is not None:
        raise ValueError(
            "Do not mix --start/--end with --anchor-time. Choose one range mode."
        )

    missing_arguments = [
        name
        for name, value in (
            ("--anchor-time", arguments.anchor_time),
        )
        if value is None
    ]
    if missing_arguments:
        missing_text = ", ".join(missing_arguments)
        raise ValueError(f"Missing anchored range arguments: {missing_text}")

    if arguments.backward is None and arguments.forward is None:
        raise ValueError("Provide at least one of --backward or --forward with --anchor-time.")

    anchor_datetime = datetime.fromisoformat(arguments.anchor_time)
    start_datetime = anchor_datetime
    end_datetime = anchor_datetime

    if arguments.backward is not None:
        start_datetime = anchor_datetime - parse_duration(arguments.backward)
    if arguments.forward is not None:
        end_datetime = anchor_datetime + parse_duration(arguments.forward)

    if end_datetime < start_datetime:
        raise ValueError("Computed range is invalid because end time is earlier than start time.")

    return MetricQueryWindow(
        start_time=start_datetime.isoformat(),
        end_time=end_datetime.isoformat(),
        step=arguments.step,
    )


def parse_duration(raw_value: str) -> timedelta:
    if len(raw_value) < 2:
        raise ValueError(f"Invalid duration: {raw_value}")

    unit = raw_value[-1]
    amount_text = raw_value[:-1]
    if not amount_text.isdigit():
        raise ValueError(f"Invalid duration: {raw_value}")

    amount = int(amount_text)
    duration_by_unit = {
        "s": timedelta(seconds=amount),
        "m": timedelta(minutes=amount),
        "h": timedelta(hours=amount),
        "d": timedelta(days=amount),
    }
    duration = duration_by_unit.get(unit)
    if duration is None:
        raise ValueError(
            f"Invalid duration unit in '{raw_value}'. Use one of: s, m, h, d."
        )
    return duration


def main() -> int:
    parser = build_argument_parser()
    cleaned_arguments, human_readable = extract_human_readable_flag(sys.argv[1:])
    arguments = parser.parse_args(cleaned_arguments)
    arguments.human_readable = human_readable or arguments.human_readable
    registry = build_metric_catalog_registry()

    try:
        if arguments.command == "catalog":
            result = handle_catalog_command(registry, arguments)
        else:
            result = handle_query_command(registry, arguments)
    except ValueError as error:
        parser.error(str(error))

    print(render_output(result, arguments.output, human_readable=arguments.human_readable))
    return 0


def extract_human_readable_flag(raw_arguments: list[str]) -> tuple[list[str], bool]:
    cleaned_arguments: list[str] = []
    human_readable = False
    for argument in raw_arguments:
        if argument == "-h":
            human_readable = True
            continue
        cleaned_arguments.append(argument)
    return cleaned_arguments, human_readable


def render_output(
    result: dict[str, Any],
    output_format: str,
    *,
    human_readable: bool = False,
) -> str:
    if human_readable:
        return render_human_output(result)
    if output_format == "json":
        return json.dumps(result, indent=2, sort_keys=True)
    return render_csv_output(result)


def render_human_output(result: dict[str, Any]) -> str:
    if "response" not in result:
        return json.dumps(result, indent=2, sort_keys=True)

    response = result.get("response", {})
    data = response.get("data", {})
    series_list = data.get("result", [])
    if not series_list:
        return "timestamp  value\n---------  -----"

    label_names = sorted(
        {
            label_name
            for series in series_list
            for label_name in series.get("metric", {}).keys()
        }
    )
    rows = build_metric_rows(series_list, label_names, human_readable_time=True)
    headers = metric_table_headers(series_list)
    return render_table([*headers, *label_names, "value"], rows)


def render_csv_output(result: dict[str, Any]) -> str:
    if "response" not in result:
        return json.dumps(result, indent=2, sort_keys=True)

    response = result.get("response", {})
    data = response.get("data", {})
    series_list = data.get("result", [])
    if not series_list:
        return "start_time,end_time,count,value"

    label_names = sorted(
        {
            label_name
            for series in series_list
            for label_name in series.get("metric", {}).keys()
        }
    )
    first_series = series_list[0]
    if "values" in first_series:
        return render_range_csv(series_list, label_names)
    if "value" in first_series:
        return render_instant_csv(series_list, label_names)
    raise ValueError("Unsupported Prometheus response shape for CSV output.")


def build_metric_rows(
    series_list: list[dict[str, Any]],
    label_names: list[str],
    *,
    human_readable_time: bool = False,
    compact_csv: bool = False,
) -> list[list[str]]:
    if any("values" in series for series in series_list):
        return build_grouped_metric_rows(
            series_list,
            label_names,
            human_readable_time=human_readable_time,
            compact_csv=compact_csv,
        )

    rows: list[list[str]] = []
    previous_label_values: dict[str, str] = {}
    for series in series_list:
        metric_labels = series.get("metric", {})
        raw_label_values = [str(metric_labels.get(label_name, "")) for label_name in label_names]
        if "values" in series:
            for timestamp, value in series["values"]:
                rendered_timestamp = format_metric_timestamp(timestamp, human_readable_time=human_readable_time)
                label_values = format_label_values(label_names, raw_label_values, previous_label_values, compact_csv)
                rows.append([rendered_timestamp, *label_values, str(value)])
            continue
        if "value" in series:
            timestamp, value = series["value"]
            rendered_timestamp = format_metric_timestamp(timestamp, human_readable_time=human_readable_time)
            label_values = format_label_values(label_names, raw_label_values, previous_label_values, compact_csv)
            rows.append([rendered_timestamp, *label_values, str(value)])
    return rows


def build_grouped_metric_rows(
    series_list: list[dict[str, Any]],
    label_names: list[str],
    *,
    human_readable_time: bool = False,
    compact_csv: bool = False,
) -> list[list[str]]:
    rows: list[list[str]] = []
    previous_label_values: dict[str, str] = {}
    for series in series_list:
        metric_labels = series.get("metric", {})
        raw_label_values = tuple(str(metric_labels.get(label_name, "")) for label_name in label_names)
        for grouped_sample in group_metric_samples(series.get("values", []), raw_label_values):
            rendered_start_time = format_metric_timestamp(
                grouped_sample.start_time,
                human_readable_time=human_readable_time,
            )
            rendered_end_time = (
                "-"
                if grouped_sample.count == 1
                else format_metric_timestamp(grouped_sample.end_time, human_readable_time=human_readable_time)
            )
            label_values = format_label_values(
                label_names,
                list(grouped_sample.key.label_values),
                previous_label_values,
                compact_csv,
            )
            rows.append(
                [
                    rendered_start_time,
                    rendered_end_time,
                    str(grouped_sample.count),
                    *label_values,
                    grouped_sample.key.value,
                ]
            )
    return rows


def group_metric_samples(
    values: list[list[Any]],
    label_values: tuple[str, ...],
) -> list[MetricSampleGroup]:
    grouped_samples: list[MetricSampleGroup] = []
    current_group: MetricSampleGroup | None = None

    for timestamp, value in values:
        group_key = MetricSampleGroupKey(label_values=label_values, value=str(value))
        if current_group is None or current_group.key != group_key:
            current_group = MetricSampleGroup(
                start_time=timestamp,
                end_time=timestamp,
                count=1,
                key=group_key,
            )
            grouped_samples.append(current_group)
            continue

        current_group.end_time = timestamp
        current_group.count += 1

    return grouped_samples


def metric_table_headers(series_list: list[dict[str, Any]]) -> list[str]:
    if any("values" in series for series in series_list):
        return ["start_time", "end_time", "count"]
    return ["timestamp"]


def format_metric_timestamp(raw_value: Any, *, human_readable_time: bool = False) -> str:
    if human_readable_time:
        return format_prometheus_timestamp(raw_value)
    return format_prometheus_timestamp_ms(raw_value)


def format_label_values(
    label_names: list[str],
    values: list[str],
    previous_values: dict[str, str],
    compact_csv: bool,
) -> list[str]:
    return [
        format_label_value(label_name, values[idx], previous_values, compact_csv)
        for idx, label_name in enumerate(label_names)
    ]


def format_label_value(
    label_name: str,
    value: str,
    previous_values: dict[str, str],
    compact_csv: bool,
) -> str:
    if not compact_csv:
        return value

    previous_value = previous_values.get(label_name)
    previous_values[label_name] = value
    if value and value == previous_value:
        return CSV_DITTO_MARK
    return value


def render_table(headers: list[str], rows: list[list[str]]) -> str:
    normalized_rows = [[format_table_cell(cell) for cell in row] for row in rows]
    widths = [
        max(len(row[idx]) for row in [headers, *normalized_rows])
        for idx in range(len(headers) - 1)
    ]
    lines = [format_table_row(headers, widths)]
    lines.append(format_table_row(["-" * len(header) for header in headers], widths))
    lines.extend(format_table_row(row, widths) for row in normalized_rows)
    return "\n".join(lines)


def format_table_row(row: list[str], widths: list[int]) -> str:
    padded = [row[idx].ljust(widths[idx]) for idx in range(len(widths))]
    return "  ".join([*padded, row[-1]])


def format_table_cell(value: Any) -> str:
    if value in (None, ""):
        return "-"
    return " ".join(str(value).split())


def render_range_csv(series_list: list[dict[str, Any]], label_names: list[str]) -> str:
    output_buffer = io.StringIO()
    writer = csv.writer(output_buffer, lineterminator="\n")
    writer.writerow(["start_time", "end_time", "count", *label_names, "value"])
    writer.writerows(build_metric_rows(series_list, label_names, compact_csv=True))
    return output_buffer.getvalue().rstrip()


def render_instant_csv(series_list: list[dict[str, Any]], label_names: list[str]) -> str:
    output_buffer = io.StringIO()
    writer = csv.writer(output_buffer, lineterminator="\n")
    writer.writerow(["timestamp", *label_names, "value"])
    writer.writerows(build_metric_rows(series_list, label_names, compact_csv=True))
    return output_buffer.getvalue().rstrip()


if __name__ == "__main__":
    raise SystemExit(main())
