---
name: metric-search
description: Query live metrics from the VTVPrime environments. Use when Codex needs metric data from dev, stg, or prd Prometheus, wants to inspect metric values or time ranges, needs help writing PromQL, or wants to use the bundled metric catalog. This skill currently queries Prometheus-backed metrics and includes Apache Pulsar guidance as one catalog domain, but it is not limited to Pulsar-only tasks.
---

# Metric Search

Use this skill when the user wants live metrics instead of log-only analysis. It currently queries Prometheus-backed metrics from the VTVPrime environments.

The runtime may display this skill as `notion-skills:metric-search` because of how your local skill bundle is namespaced. That prefix is only a discovery label. This skill is not related to Notion.

## Endpoints

- `dev` -> `https://dev-prometheus.vtvprime.vn`
- `stg` -> `https://stg-prometheus.vtvprime.vn`
- `prd` -> `https://prometheus.vtvprime.vn`

## Default workflow

1. Pick the environment first: `dev`, `stg`, or `prd`.
2. If the user names a known Pulsar metric, describe it from the catalog before querying it.
3. Prefer the local helper:
   `python3 scripts/query_prometheus.py`
4. Default query output is compact CSV for LLM analysis because it removes the Prometheus response envelope and reduces token usage.
5. Use `-h` for human-readable query output as an aligned table with ISO timestamps; use `--help` for command help.
6. Use `--output json` only when metadata or the raw Prometheus response envelope matters.
7. Use `catalog` subcommands to discover supported component metrics.
8. Use `query metric` when the metric exists in the catalog and `query promql` only for custom expressions.
9. Distinguish direct metric evidence from inference.
10. For Pulsar incidents, start with broker traffic, backlog, storage, load-balancing, and BookKeeper client latency metrics.

## Common commands

```bash
# List supported Pulsar metrics
python3 scripts/query_prometheus.py \
  catalog list --component pulsar

# Explain one metric
python3 scripts/query_prometheus.py \
  catalog describe --component pulsar --metric pulsar_broker_rate_in

# Query a catalog metric with its default PromQL
python3 scripts/query_prometheus.py \
  query metric --env prd --component pulsar --metric pulsar_broker_rate_in

# Human-readable aligned table with ISO timestamps
python3 scripts/query_prometheus.py \
  -h \
  query metric --env prd --component pulsar --metric pulsar_broker_rate_in

# Query a time range
python3 scripts/query_prometheus.py \
  query range --env prd --component pulsar --metric pulsar_broker_msg_backlog \
  --start 2026-04-07T00:00:00+07:00 --end 2026-04-07T06:00:00+07:00 --step 5m

# Query around a timestamp with the default 1-minute step
python3 scripts/query_prometheus.py \
  query metric --env prd --component pulsar --metric pulsar_broker_rate_in \
  --anchor-time 2026-04-07T00:30:00+07:00 --backward 20m --forward 20m

# Run custom PromQL
python3 scripts/query_prometheus.py \
  query promql --env stg --expr 'sum by (cluster) (pulsar_broker_rate_out)'
```

## Catalog design

- The metric registry is a hash-map style structure keyed by component, then by metric name.
- Add new components by creating another reference module and registering it in `scripts/catalog.py`.
- Keep each metric definition focused on:
  - meaning
  - when to use it
  - metric type
  - labels
  - default PromQL
  - source
- Default CSV output writes timestamps as Unix milliseconds and uses `^` for repeated label values from the previous row.
- Range CSV output groups consecutive samples with the same labels and value into `start_time`, `end_time`, `count`, labels, and `value`. `end_time` is `-` when `count` is `1`.
- Use JSON only when metadata or raw Prometheus structure matters.

## Pulsar guidance

- The bundled Pulsar catalog is aligned to Apache Pulsar `3.0.x`, which covers `3.0.16`.
- Read the metric meaning before choosing a query. Some metrics are better as `sum`, some as `max`, and summaries often need `_sum/_count` math.
- BookKeeper client metrics are only available when `bookkeeperClientExposeStatsToPrometheus=true` in `broker.conf`.
- Consumer-level metrics require the related Prometheus exposure flags to be enabled in Pulsar.

## When to read more

- Pulsar metric registry:
  [pulsar_metrics.py](references/pulsar_metrics.py)
- Query/catalog implementation:
  [catalog.py](scripts/catalog.py)
  [query_prometheus.py](scripts/query_prometheus.py)
