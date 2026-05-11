#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
from dataclasses import asdict, dataclass
from datetime import datetime, timedelta
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


def build_argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Query VTVPrime Prometheus endpoints with a reusable metric catalog."
    )
    parser.add_argument(
        "--output",
        choices=("json", "csv"),
        default="json",
        help="Output format. CSV is optimized for compact LLM-friendly range results.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    add_catalog_commands(subparsers)
    add_query_commands(subparsers)
    return parser


def add_catalog_commands(subparsers: argparse._SubParsersAction[Any]) -> None:
    catalog_parser = subparsers.add_parser("catalog", help="Inspect the metric catalog.")
    catalog_subparsers = catalog_parser.add_subparsers(
        dest="catalog_command",
        required=True,
    )

    list_parser = catalog_subparsers.add_parser("list", help="List metrics.")
    list_parser.add_argument("--component", required=True)

    describe_parser = catalog_subparsers.add_parser(
        "describe",
        help="Describe one metric.",
    )
    describe_parser.add_argument("--component", required=True)
    describe_parser.add_argument("--metric", required=True)


def add_query_commands(subparsers: argparse._SubParsersAction[Any]) -> None:
    query_parser = subparsers.add_parser("query", help="Run Prometheus queries.")
    query_subparsers = query_parser.add_subparsers(
        dest="query_command",
        required=True,
    )

    metric_parser = query_subparsers.add_parser(
        "metric",
        help="Run the default PromQL for a catalog metric.",
    )
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
    )
    promql_parser.add_argument("--env", required=True, choices=("dev", "stg", "prd"))
    promql_parser.add_argument("--expr", required=True)
    promql_parser.add_argument("--time")

    range_parser = query_subparsers.add_parser(
        "range",
        help="Run the default PromQL for a catalog metric over a time range.",
    )
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
    arguments = parser.parse_args()
    registry = build_metric_catalog_registry()

    try:
        if arguments.command == "catalog":
            result = handle_catalog_command(registry, arguments)
        else:
            result = handle_query_command(registry, arguments)
    except ValueError as error:
        parser.error(str(error))

    print(render_output(result, arguments.output))
    return 0


def render_output(result: dict[str, Any], output_format: str) -> str:
    if output_format == "json":
        return json.dumps(result, indent=2, sort_keys=True)
    return render_csv_output(result)


def render_csv_output(result: dict[str, Any]) -> str:
    response = result.get("response", {})
    data = response.get("data", {})
    series_list = data.get("result", [])
    if not series_list:
        return "timestamp,value"

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


def render_range_csv(series_list: list[dict[str, Any]], label_names: list[str]) -> str:
    output_buffer = io.StringIO()
    writer = csv.writer(output_buffer, lineterminator="\n")
    writer.writerow(["timestamp", *label_names, "value"])
    for series in series_list:
        metric_labels = series.get("metric", {})
        label_values = [metric_labels.get(label_name, "") for label_name in label_names]
        for timestamp, value in series["values"]:
            writer.writerow([timestamp, *label_values, value])
    return output_buffer.getvalue().rstrip()


def render_instant_csv(series_list: list[dict[str, Any]], label_names: list[str]) -> str:
    output_buffer = io.StringIO()
    writer = csv.writer(output_buffer, lineterminator="\n")
    writer.writerow(["timestamp", *label_names, "value"])
    for series in series_list:
        metric_labels = series.get("metric", {})
        label_values = [metric_labels.get(label_name, "") for label_name in label_names]
        timestamp, value = series["value"]
        writer.writerow([timestamp, *label_values, value])
    return output_buffer.getvalue().rstrip()


if __name__ == "__main__":
    raise SystemExit(main())
