# Pulsar Dispatch And Backlog Triage

Use this reference when a Pulsar topic/subscription drains slowly, backlog remains high, dispatch looks uneven, or the user asks whether Pulsar or the consumer is slow.

## Principles

- Query live metrics before guessing.
- Compare producer ingress, broker dispatch, consumer ack, backlog, unacked, and flow-control signals together.
- Use per-partition tables for partitioned topics.
- Search broker logs only after metrics show a broker/storage possibility or the user asks for log evidence.
- Separate direct evidence from inference.

## Workflow

1. Identify environment: `dev`, `stg`, or `prd`.
2. Identify topic regex and subscription or reader names.
3. Read `promql.md` and run summary metrics:
   - publish rate
   - dispatch/rate out
   - ack rate
   - backlog
   - unacked
   - blocked on unacked
4. Run per-partition metrics if the topic is partitioned.
5. If broker/storage is still possible, read `log-search.md` and query affected topic/partitions.
6. Read `output-format.md` and return Summary, Per Partition, and Diagnosis tables.

## Interpretation Rules

| Signal | Interpretation |
|---|---|
| `rate_in > 0`, backlog grows | Producer is still flooding or ingress exceeds drain. |
| `rate_in = 0`, backlog high, `rate_out` low | Drain path is slow. Continue with partition-level table. |
| `unacked > 0` or `blocked_on_unacked = 1` | Consumer received messages but is not acking fast enough, or broker flow control is active. |
| `unacked = 0`, `blocked_on_unacked = 0`, backlog high, low `rate_out` | Consumer is connected but likely not requesting/receiving steadily, or broker dispatcher is not actively sending. Check per-partition and logs. |
| Some partitions have `rate_out > 0`, others have `rate_out = 0` | Partition-level drain imbalance. Focus on affected reader goroutines, flow permits, reader position, or broker ownership for those partitions. |
| Topic-specific broker `ERROR/WARN` in `PersistentDispatcher`, `ManagedLedger`, `OpReadEntry`, offload/read handle | Broker/storage/read path is a stronger suspect. |
| Broker logs clean for exact topic but `consumer_count` is present | Prefer client/read loop/flow/processing bottleneck over Pulsar storage failure. |

## Broker-Side Consumer Availability Check

Use these together before saying a connected consumer is not effectively available:

| Metric | What it proves |
|---|---|
| `pulsar_subscription_msg_rate_out` | Broker is dispatching messages to the subscription. |
| `pulsar_subscription_back_log` | Messages still remain to be drained. |
| `pulsar_subscription_unacked_messages` | Consumer has received messages that are not acknowledged yet. |
| `pulsar_subscription_blocked_on_unacked_messages` | Broker flow control is blocking dispatch because unacked is over limit. |

Concrete read:

- `back_log > 0`, `msg_rate_out = 0`, `unacked_messages = 0`, `blocked_on_unacked = 0`: connected does not mean actively draining; inspect reader receive loop, permits, partition ownership, and broker dispatcher logs.
- `back_log > 0`, `msg_rate_out > 0`, `unacked_messages = 0`: broker is dispatching and consumer is not holding unacked messages; check drain speed and partition imbalance.
- `unacked_messages > 0` or `blocked_on_unacked = 1`: consumer has received messages but is not acking fast enough, or dispatch is blocked by unacked flow control.

## Reader Pattern Note

If the client uses Pulsar `Reader`, it can create per-partition reader subscriptions like `reader-xxxxx`. A reader can be connected while still draining slowly if its loop is blocked, receiving in small batches, seeking inefficiently, waiting on downstream work, or not polling all partitions evenly.

Parallel partition goroutines are generally the right shape. If metrics still show only some partitions dispatching, inspect whether each goroutine is actively calling receive/read, whether downstream writes block per partition, and whether errors are swallowed or retried slowly.

Short causes for connected-but-not-available:

- Receiver queue has no permits because the client/app is not draining fast enough.
- Reader loop is not calling `Next`/`Receive` steadily, or is blocked by processing/writes.
- `HasNext`/`GetLastMessageID` is called too often and adds broker round trips/timeouts.
- Namespace/topic ownership churn forces lookup/reconnect and interrupts dispatch.
- Dispatcher logs `no available consumer found` while the process is still connected.
- Broker can read ledger but returns small batches, so dispatch continues but throughput is low.
- Cursor is already near the end for that reader, so `rows=0`/idle can mean caught up rather than slow.

## Example Diagnosis

Direct evidence:

- `rate_in = 0`, so producers are not currently adding new messages.
- Backlog remains high at `153,550`.
- Total dispatch is low at `~15.9 msg/s`.
- `unacked = 0` and `blocked_on_unacked = 0`.
- Some partitions have consumers connected but `rate_out = 0`.

Inference:

- This is not classic "consumer received messages but cannot ack".
- This is more consistent with partition-level drain imbalance.
- If broker logs for the exact topic are clean, focus on client reader loop, receive permits, reader position, or downstream blocking rather than Pulsar storage first.
