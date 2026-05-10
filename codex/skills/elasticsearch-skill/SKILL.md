---
name: elasticsearch-skill
description: Use when investigating application, infrastructure, Kubernetes, or Pulsar issues by querying Elasticsearch logs first. Use this skill for log-based RCA, Kibana-style data view queries, time-range log inspection, and broker/client incident analysis before making assumptions.
---

# Elasticsearch Skill

Use this skill when the user wants log-based diagnosis, especially for Pulsar, broker issues, or Kibana-like data view queries.

## Default workflow

1. Query Elasticsearch first. Do not guess root cause before reading logs.
2. Prefer the local script:
   `python3 ~/.codex/skills/elasticsearch-skill/scripts/fetch_index_docs.py`
3. Use `--dataview` when available.
4. Timezone defaults to `Asia/Ho_Chi_Minh`. The user usually does not need `--tz`.
5. For RCA:
   start with `--level error`
   then check `--level warn`
6. Prefer the default CSV output for LLM analysis because it removes JSON envelopes and reduces token usage.
7. Use `--output message` when the user only wants the raw log message field with timestamp and pod.
8. Use `--output compact` when JSON structure is helpful and `--output full` only when needed.
9. CSV output is intentionally minimal:
   - keeps `start_time`, `end_time`, `count`, `level`, `caller`, `alert_msg`, `component`, `pod`
   - collapses duplicate log rows only when they are consecutive in timeline order into one ranged row
   - does not include `message` by default because it is often a noisy duplicate of `alert_msg`
10. Compact JSON output is intentionally minimal:
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
- Only inspect `.env.example` when checking required config keys.
- Only read `queries.md` or `dataviews.py` when necessary.
- Never expose Elasticsearch credentials in responses, logs, or command output.

## When to read more

- For example commands and common Pulsar workflows, read:
  [queries.md](/Users/van/.codex/skills/elasticsearch-skill/references/queries.md)
- For data view mappings, read:
  [dataviews.py](/Users/van/.codex/skills/elasticsearch-skill/scripts/dataviews.py)

## Config

The skill reads Elasticsearch credentials from:
- [/.env](/Users/van/.codex/skills/elasticsearch-skill/.env)
- or shell environment variables

If the user asks to extend the skill, update the scripts in `scripts/` and keep the workflow centered on querying Elasticsearch before analysis.

## Output preference

- Prefer the default CSV output when passing logs to another LLM step.
- Use `--output compact` for structured JSON with key normalized fields.
- Use `--output full` only when the compact view hides details needed for RCA.
