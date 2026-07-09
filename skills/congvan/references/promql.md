# Pulsar PromQL

Use these queries with `notion-skills:metric-search`.

Replace:

- `<env>` with `dev`, `stg`, or `prd`.
- `<topic_regex>` with a Prometheus regex, for example `.*subscription-subscription-v2.*`.
- `<reader_regex>` with reader names when known, for example `reader-(sfgzw|tcjjc|cdgrl|fixsw|ooevp|tgnra)`.

Keep shell commands on one line when a regex contains `|`; accidental newlines inside the regex can produce Prometheus HTTP 400.

## Summary Metrics

```promql
sum(pulsar_rate_in{topic=~"<topic_regex>"})
```

```promql
sum(pulsar_subscription_msg_rate_out{topic=~"<topic_regex>"})
```

```promql
sum(pulsar_subscription_msg_ack_rate{topic=~"<topic_regex>"})
```

```promql
sum(pulsar_subscription_back_log{topic=~"<topic_regex>"})
```

```promql
sum(pulsar_subscription_unacked_messages{topic=~"<topic_regex>"})
```

```promql
max(pulsar_subscription_blocked_on_unacked_messages{topic=~"<topic_regex>"})
```

## Per-Partition Metrics

```promql
sum by (topic, subscription) (pulsar_subscription_msg_rate_out{topic=~"<topic_regex>", subscription=~"<reader_regex>"})
```

```promql
sum by (topic, subscription) (pulsar_subscription_msg_ack_rate{topic=~"<topic_regex>", subscription=~"<reader_regex>"})
```

```promql
sum by (topic, subscription) (pulsar_subscription_back_log{topic=~"<topic_regex>", subscription=~"<reader_regex>"})
```

```promql
sum by (topic, subscription) (pulsar_subscription_unacked_messages{topic=~"<topic_regex>", subscription=~"<reader_regex>"})
```

```promql
max by (topic, subscription) (pulsar_subscription_blocked_on_unacked_messages{topic=~"<topic_regex>", subscription=~"<reader_regex>"})
```

```promql
sum by (topic, subscription) (pulsar_subscription_consumers_count{topic=~"<topic_regex>", subscription=~"<reader_regex>"})
```

## Query Helper

Generic command:

```bash
python3 ../metric-search/scripts/query_prometheus.py query promql --env <env> --expr 'sum(pulsar_subscription_msg_rate_out{topic=~"<topic_regex>"})'
```

Exact reader example:

```bash
python3 ../metric-search/scripts/query_prometheus.py query promql --env stg --expr 'sum by (topic, subscription) (pulsar_subscription_msg_rate_out{topic=~"persistent://seenow/es/subscription-subscription-v2-partition-[0-5]", subscription=~"reader-(sfgzw|tcjjc|cdgrl|fixsw|ooevp|tgnra)"})'
```
