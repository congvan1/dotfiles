# Query Patterns

## Main script

Use:

```bash
python3 ~/.codex/skills/elasticsearch-skill/scripts/fetch_index_docs.py
```

## Built-in data views

- `sn-dev-workload`
- `sn-stg-workload`
- `sn-prd-workload`
- `mh-dev-workload`
- `mh-stg-workload`
- `mh-prd-workload`
- `pulsar-prd-all`
- `pulsar-prd-broker`
- `pulsar-prd-proxy`
- `pulsar-prd-manager`

Read [dataviews.py](/Users/van/.codex/skills/elasticsearch-skill/scripts/dataviews.py) to add or change mappings.

## Common queries

Production Pulsar errors:

```bash
python3 ~/.codex/skills/elasticsearch-skill/scripts/fetch_index_docs.py \
  --dataview pulsar-prd-all \
  --from '2026-04-03 11:00' \
  --to '2026-04-03 12:07' \
  --level error
```

Broad Seenow production workload query:

```bash
python3 ~/.codex/skills/elasticsearch-skill/scripts/fetch_index_docs.py \
  --dataview sn-prd-workload \
  --from '2026-04-03 11:00' \
  --to '2026-04-03 12:07' \
  --level error
```

Broad Mediahub staging workload query:

```bash
python3 ~/.codex/skills/elasticsearch-skill/scripts/fetch_index_docs.py \
  --dataview mh-stg-workload \
  --from '2026-04-03 11:00' \
  --to '2026-04-03 12:07' \
  --level warn
```

Production Pulsar warnings on broker:

```bash
python3 ~/.codex/skills/elasticsearch-skill/scripts/fetch_index_docs.py \
  --dataview pulsar-prd-broker \
  --from '2026-04-03 11:00' \
  --to '2026-04-03 12:07' \
  --level warn
```

Full source:

```bash
python3 ~/.codex/skills/elasticsearch-skill/scripts/fetch_index_docs.py \
  --dataview pulsar-prd-all \
  --from '2026-04-03 11:00' \
  --to '2026-04-03 12:07' \
  --level warn \
  --output full
```

Text filter:

```bash
python3 ~/.codex/skills/elasticsearch-skill/scripts/fetch_index_docs.py \
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
