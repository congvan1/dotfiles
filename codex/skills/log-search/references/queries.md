# Query Patterns

## Main script

Use:

```bash
python3 ~/.codex/skills/log-search/scripts/fetch_index_docs.py
```

## Data views

`--dataview` resolves a real Kibana data view across **all spaces**
(`default`, `dev`, `stg`, `prd`), each fetched from `/s/<space>/api/data_views`
(the default space has no prefix). Kibana data views are authoritative; the
deprecated local aliases in `dataviews.py` are only a fallback for patterns
Kibana does not define yet (e.g. pulsar broker/proxy granularity).

Resolution rules:

- `space:name` — explicit, e.g. `dev:sn-dev-workload`, `stg:sn-stg-pulsar`.
- bare `name` — resolved if it is unique across spaces; if the same name exists
  in several spaces the script errors and lists the `space:name` options.
- if Kibana has no match, a deprecated local alias is tried.

List everything available (grouped by space):

```bash
python3 ~/.codex/skills/log-search/scripts/fetch_index_docs.py --list-dataviews
```

Examples:

```bash
# dev workload errors via the dev space data view
python3 .../fetch_index_docs.py --dataview dev:sn-dev-workload --minutes 30 --level error

# staging pulsar via the stg space data view
python3 .../fetch_index_docs.py --dataview stg:sn-stg-pulsar --minutes 30 --level all

# fallback alias for broker-only granularity Kibana lacks
python3 .../fetch_index_docs.py --dataview pulsar-dev-broker --minutes 30 --level all
```

Read [dataviews.py](/Users/van/.codex/skills/log-search/scripts/dataviews.py) to prune deprecated aliases as Kibana data views replace them.

## Common queries

Specific index query:

```bash
python3 ~/.codex/skills/log-search/scripts/fetch_index_docs.py \
  --index stg-db-cassandra-2026-05-26 \
  --from '2026-05-26 15:15' \
  --to '2026-05-26 15:18' \
  --level error
```

Production Pulsar errors:

```bash
python3 ~/.codex/skills/log-search/scripts/fetch_index_docs.py \
  --dataview pulsar-prd-all \
  --from '2026-04-03 11:00' \
  --to '2026-04-03 12:07' \
  --level error
```

Broad Seenow production workload query:

```bash
python3 ~/.codex/skills/log-search/scripts/fetch_index_docs.py \
  --dataview sn-prd-workload \
  --from '2026-04-03 11:00' \
  --to '2026-04-03 12:07' \
  --level error
```

Broad Mediahub staging workload query:

```bash
python3 ~/.codex/skills/log-search/scripts/fetch_index_docs.py \
  --dataview mh-stg-workload \
  --from '2026-04-03 11:00' \
  --to '2026-04-03 12:07' \
  --level warn
```

Production Pulsar warnings on broker:

```bash
python3 ~/.codex/skills/log-search/scripts/fetch_index_docs.py \
  --dataview pulsar-prd-broker \
  --from '2026-04-03 11:00' \
  --to '2026-04-03 12:07' \
  --level warn
```

Full source:

```bash
python3 ~/.codex/skills/log-search/scripts/fetch_index_docs.py \
  --dataview pulsar-prd-all \
  --from '2026-04-03 11:00' \
  --to '2026-04-03 12:07' \
  --level warn \
  --output full
```

Text filter:

```bash
python3 ~/.codex/skills/log-search/scripts/fetch_index_docs.py \
  --dataview pulsar-prd-all \
  --from '2026-04-03 11:00' \
  --to '2026-04-03 12:07' \
  --level error \
  --text 'EOFException'
```

## Notes

- Default timezone is `Asia/Ho_Chi_Minh`.
- Prefer `error`, then `warn`.
- Default output is CSV for LLM token efficiency.
- Use `--output compact` when you want structured JSON with normalized fields.
- Use `--output full` only when compact or CSV hides details you need.
