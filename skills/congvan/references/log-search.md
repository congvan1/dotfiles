# Pulsar Log Search

Use log search after metrics show a broker-side possibility, or when the user explicitly asks for log evidence.

Focus the first queries on the affected topic/partitions. Broad cluster-wide errors are useful context, but they are weaker evidence unless they mention the exact topic or broker path involved.

## Error Query

```bash
python3 ../log-search/scripts/fetch_index_docs.py \
  --dataview stg:sn-stg-pulsar \
  --minutes 120 \
  --level error \
  --text 'subscription-subscription-v2-partition-0 OR subscription-subscription-v2-partition-3 OR subscription-subscription-v2-partition-4 OR PersistentDispatcher OR ManagedLedger OR OpReadEntry OR BlobStoreBackedReadHandleImpl' \
  --limit 80 -h
```

## Warning Query

```bash
python3 ../log-search/scripts/fetch_index_docs.py \
  --dataview stg:sn-stg-pulsar \
  --minutes 120 \
  --level warn \
  --text 'subscription-subscription-v2-partition-0 OR subscription-subscription-v2-partition-3 OR subscription-subscription-v2-partition-4 OR PersistentDispatcher OR ManagedLedger OR OpReadEntry OR BlobStoreBackedReadHandleImpl' \
  --limit 80 -h
```

## Raw Topic Query

```bash
python3 ../log-search/scripts/fetch_index_docs.py \
  --dataview stg:sn-stg-pulsar \
  --minutes 120 \
  --level all \
  --text 'subscription-subscription-v2' \
  --limit 100 --output message
```

## Interpretation

- Exact-topic `ERROR/WARN` in dispatcher, managed ledger, read entry, or offload paths strengthens the Pulsar/broker/storage hypothesis.
- No exact-topic errors plus connected consumers shifts suspicion to the client reader loop, permits, reader position, or downstream processing.
- Cluster-wide offload/read errors on unrelated topics should be reported as context, not treated as root cause for the target topic.
