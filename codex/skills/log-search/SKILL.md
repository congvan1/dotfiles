---
name: log-search
description: Use when investigating application, infrastructure, Kubernetes, or Pulsar issues by querying logs first. Queries Elasticsearch logs (directly or via a Kibana gateway) and resolves Kibana data views across spaces. Use this skill for log-based RCA, data view queries, time-range log inspection, and broker/client incident analysis before making assumptions.
---

# Log Search

Use this skill when the user wants log-based diagnosis, especially for Pulsar, broker issues, or Kibana data view queries. It queries Elasticsearch logs (directly or through a Kibana gateway) and resolves Kibana data views across spaces.

## Default workflow

1. Query Elasticsearch first. Do not guess root cause before reading logs.
2. Prefer the local script:
   `python3 ~/.codex/skills/log-search/scripts/fetch_index_docs.py`
3. Use `--dataview` when available. It resolves a real Kibana data view across all spaces (default, dev, stg, prd). Pass a bare `name` (resolved if unique across spaces) or `space:name` to disambiguate, for example `dev:sn-dev-workload` or `stg:sn-stg-pulsar`. Deprecated local aliases (e.g. `pulsar-dev-broker`) are used only as a fallback when Kibana has no match. Run `--list-dataviews` to see everything. If the user gives a concrete index name, use `--index` or `--index-pattern` directly, for example `--index stg-db-cassandra-2026-05-26`.
4. Timezone defaults to `Asia/Ho_Chi_Minh`. The user usually does not need `--tz`.
5. For RCA:
   start with `--level error`
   then check `--level warn`
6. Prefer the default CSV output for LLM analysis because it removes JSON envelopes and reduces token usage.
7. Use `--output message` when the user only wants the raw log message field with timestamp and pod.
8. Use `--output compact` when JSON structure is helpful and `--output full` only when needed.
9. Use structured filters for Kubernetes metadata:
   - `--pod` filters `kubernetes.pod.name` by exact name, wildcard, or substring.
   - `--container` filters `kubernetes.container.name` by exact name, wildcard, or substring.
   - `--log-file` filters `log.file.path` by exact path, wildcard, or substring. This is useful when Elasticsearch has multiple rotated/restarted container log files and you need to match a single `kubectl logs` source.
   - Do not use `--text` to filter pod/container names; those fields are keywords and may not tokenize partial values.
10. CSV output is intentionally minimal:
   - keeps `start_time`, `end_time`, `count`, `level`, `caller`, `alert_msg`, `component`, `pod`
   - writes `start_time` and ranged `end_time` as Unix milliseconds to save tokens while preserving millisecond precision
   - writes `end_time` as `-` when `count` is `1`
   - writes `^` for repeated `level`, `caller`, `component`, or `pod` values from the previous CSV row
   - use `-h` for human-readable aligned table output with ISO timestamps; level is bold colored (`info` green, `warn` yellow, `error` red), and `count` is bold yellow when above 10% of `--limit` or bold red when above 30%
   - collapses duplicate log rows only when they are consecutive in timeline order into one ranged row
   - does not include `message` by default because it is often a noisy duplicate of `alert_msg`
11. Compact JSON output is intentionally minimal:
   - keeps `timestamp`, `level`, `caller`, `alert_msg`, `component`, `pod`
   - only includes a shortened fallback `message` when `alert_msg` is empty
   - use `--message-chars` or `--output full` only when needed

## Interpretation guidance

- If client restart does not help but broker restart does, prefer broker-side explanations.
- Distinguish direct evidence from inference.
- A dispatcher being "stuck" is often an inference from dispatcher/read failures, not a literal log string.
- For Pulsar broker RCA, pay special attention to:
  - `PersistentDispatcherSingleActiveConsumer`
  - `BlobStoreBackedReadHandleImpl`
  - `ManagedLedgerImpl`
  - `OpReadEntry`
  - `ServerCnx`
  - `PersistentTopic`

## Safety

- Never read or print the contents of `.env`.
- Use the local scripts directly; they already load credentials from `.env`.
- The script first tries raw Elasticsearch `/<index>/_search`; when the log URL is a Kibana gateway, it automatically falls back to `/api/console/proxy`.
- Only inspect `.env.example` when checking required config keys.
- Only read `queries.md` or `dataviews.py` when necessary.
- Never expose Elasticsearch credentials in responses, logs, or command output.

## When to read more

- For example commands and common Pulsar workflows, read:
  [queries.md](/Users/van/.codex/skills/log-search/references/queries.md)
- For data view mappings, read:
  [dataviews.py](/Users/van/.codex/skills/log-search/scripts/dataviews.py)

## Config

The skill reads Elasticsearch credentials from:
- [/.env](/Users/van/.codex/skills/log-search/.env)
- or shell environment variables

If the user asks to extend the skill, update the scripts in `scripts/` and keep the workflow centered on querying Elasticsearch before analysis.

## Output preference

- Prefer the default CSV output when passing logs to another LLM step.
- Use `--output compact` for structured JSON with key normalized fields.
- Use `--output full` only when the compact view hides details needed for RCA.
