# Pulsar Triage Output Format

Use this structure when returning Pulsar dispatch/backlog results.

## Summary

| Signal | Value | Read |
|---|---:|---|
| `pulsar_rate_in` | `<value> msg/s` | Producer traffic now |
| `pulsar_subscription_msg_rate_out` | `<value> msg/s` | Broker dispatch to subscription |
| `pulsar_subscription_msg_ack_rate` | `<value> ack/s` | Consumer ack rate |
| `pulsar_subscription_back_log` | `<value> msgs` | Backlog remaining |
| `pulsar_subscription_unacked_messages` | `<value>` | In-flight messages not acked |
| `pulsar_subscription_blocked_on_unacked_messages` | `<value>` | Broker flow-control block |

## Per Partition

| Partition | Reader Subscription | Backlog | Rate Out | Ack Rate | Consumer Count |
|---|---|---:|---:|---:|---:|
| `partition-0` | `reader-name` | `n` | `n` | `n` | `n` |

## Diagnosis

| Hypothesis | Result | Evidence |
|---|---|---|
| Producer still flooding | `Likely/Not likely` | `rate_in ...` |
| Consumer slow because not acking | `Likely/Not strongly supported` | `unacked/blocked ...` |
| Broker globally stuck | `Likely/Not globally` | `rate_out per partition ...` |
| Partition-level drain problem | `Likely/No` | `partitions ...` |
| Overall drain is slow | `Yes/No` | `backlog ... with rate_out ...` |

End with a short paragraph:

- State whether the evidence points to Pulsar/broker/storage, consumer/read loop, or inconclusive.
- Name the next most useful check.
- Clearly separate direct evidence from inference.
