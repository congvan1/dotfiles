from __future__ import annotations

from dataclasses import dataclass


PULSAR_3_0_X_METRICS_SOURCE = "https://pulsar.apache.org/docs/3.0.x/reference-metrics/"


@dataclass(frozen=True)
class MetricDefinition:
    name: str
    metric_type: str
    meaning: str
    when_to_use: str
    default_promql: str
    labels: tuple[str, ...]
    source: str
    notes: str = ""


@dataclass(frozen=True)
class ComponentCatalog:
    name: str
    version: str
    description: str
    metrics: dict[str, MetricDefinition]


PULSAR_COMPONENT_CATALOG = ComponentCatalog(
    name="pulsar",
    version="3.0.x (validated against official 3.0.x docs for Pulsar 3.0.16 usage)",
    description=(
        "Core Apache Pulsar metrics for broker traffic, backlog, storage, load balancing, "
        "connections, replication, cache, and BookKeeper client health."
    ),
    metrics={
        "pulsar_broker_rate_in": MetricDefinition(
            name="pulsar_broker_rate_in",
            metric_type="Gauge",
            meaning="Inbound publish rate in messages per second across broker topics.",
            when_to_use="Use when checking producer traffic volume or verifying publish-side drops.",
            default_promql="sum by (cluster) (pulsar_broker_rate_in)",
            labels=("cluster",),
            source=PULSAR_3_0_X_METRICS_SOURCE,
        ),
        "pulsar_broker_rate_out": MetricDefinition(
            name="pulsar_broker_rate_out",
            metric_type="Gauge",
            meaning="Outbound delivery rate in messages per second across broker topics.",
            when_to_use="Use when comparing consumer throughput against inbound traffic.",
            default_promql="sum by (cluster) (pulsar_broker_rate_out)",
            labels=("cluster",),
            source=PULSAR_3_0_X_METRICS_SOURCE,
        ),
        "pulsar_broker_throughput_in": MetricDefinition(
            name="pulsar_broker_throughput_in",
            metric_type="Gauge",
            meaning="Inbound traffic volume in bytes per second.",
            when_to_use="Use when message count looks normal but payload size may be stressing brokers.",
            default_promql="sum by (cluster) (pulsar_broker_throughput_in)",
            labels=("cluster",),
            source=PULSAR_3_0_X_METRICS_SOURCE,
        ),
        "pulsar_broker_throughput_out": MetricDefinition(
            name="pulsar_broker_throughput_out",
            metric_type="Gauge",
            meaning="Outbound traffic volume in bytes per second.",
            when_to_use="Use when validating consumer egress or replication-side delivery pressure.",
            default_promql="sum by (cluster) (pulsar_broker_throughput_out)",
            labels=("cluster",),
            source=PULSAR_3_0_X_METRICS_SOURCE,
        ),
        "pulsar_broker_msg_backlog": MetricDefinition(
            name="pulsar_broker_msg_backlog",
            metric_type="Gauge",
            meaning="Total queued backlog entries on the broker.",
            when_to_use="Use first for consumer lag, blocked subscriptions, or delivery incidents.",
            default_promql="sum by (cluster) (pulsar_broker_msg_backlog)",
            labels=("cluster",),
            source=PULSAR_3_0_X_METRICS_SOURCE,
        ),
        "pulsar_broker_storage_write_rate": MetricDefinition(
            name="pulsar_broker_storage_write_rate",
            metric_type="Gauge",
            meaning="Write rate to storage in message batches per second.",
            when_to_use="Use when broker traffic is normal but storage write pressure may be the bottleneck.",
            default_promql="sum by (cluster) (pulsar_broker_storage_write_rate)",
            labels=("cluster",),
            source=PULSAR_3_0_X_METRICS_SOURCE,
        ),
        "pulsar_broker_storage_read_rate": MetricDefinition(
            name="pulsar_broker_storage_read_rate",
            metric_type="Gauge",
            meaning="Read rate from storage in message batches per second.",
            when_to_use="Use for backlog drain analysis, catch-up behavior, and storage read hot spots.",
            default_promql="sum by (cluster) (pulsar_broker_storage_read_rate)",
            labels=("cluster",),
            source=PULSAR_3_0_X_METRICS_SOURCE,
        ),
        "pulsar_broker_storage_size": MetricDefinition(
            name="pulsar_broker_storage_size",
            metric_type="Gauge",
            meaning="Physical storage size in bytes, including replicas.",
            when_to_use="Use for capacity tracking and to detect storage growth on the broker.",
            default_promql="sum by (cluster) (pulsar_broker_storage_size)",
            labels=("cluster",),
            source=PULSAR_3_0_X_METRICS_SOURCE,
        ),
        "pulsar_broker_storage_logical_size": MetricDefinition(
            name="pulsar_broker_storage_logical_size",
            metric_type="Gauge",
            meaning="Logical storage size in bytes without replicas.",
            when_to_use="Use to compare effective data footprint against replicated footprint.",
            default_promql="sum by (cluster) (pulsar_broker_storage_logical_size)",
            labels=("cluster",),
            source=PULSAR_3_0_X_METRICS_SOURCE,
        ),
        "pulsar_storage_backlog_quota_check_duration_seconds": MetricDefinition(
            name="pulsar_storage_backlog_quota_check_duration_seconds",
            metric_type="Histogram",
            meaning="Duration of backlog quota checks.",
            when_to_use="Use when backlog enforcement is slow or quota processing may be hurting broker responsiveness.",
            default_promql=(
                "sum by (cluster) "
                "(rate(pulsar_storage_backlog_quota_check_duration_seconds_sum[5m])) "
                "/ "
                "sum by (cluster) "
                "(rate(pulsar_storage_backlog_quota_check_duration_seconds_count[5m]))"
            ),
            labels=("cluster",),
            source=PULSAR_3_0_X_METRICS_SOURCE,
            notes="Uses histogram _sum/_count to estimate average check duration over 5 minutes.",
        ),
        "pulsar_broker_storage_backlog_quota_exceeded_evictions_total": MetricDefinition(
            name="pulsar_broker_storage_backlog_quota_exceeded_evictions_total",
            metric_type="Counter",
            meaning="Number of backlog quota evictions since broker start.",
            when_to_use="Use when messages may be evicted because time or size quota limits are exceeded.",
            default_promql=(
                "sum by (cluster, quota_type) "
                "(rate(pulsar_broker_storage_backlog_quota_exceeded_evictions_total[5m]))"
            ),
            labels=("cluster", "quota_type"),
            source=PULSAR_3_0_X_METRICS_SOURCE,
        ),
        "pulsar_ml_cache_used_size": MetricDefinition(
            name="pulsar_ml_cache_used_size",
            metric_type="Gauge",
            meaning="Managed ledger cache payload size in bytes.",
            when_to_use="Use when diagnosing broker memory pressure caused by entry cache growth.",
            default_promql="sum by (cluster) (pulsar_ml_cache_used_size)",
            labels=("cluster",),
            source=PULSAR_3_0_X_METRICS_SOURCE,
        ),
        "pulsar_ml_cache_hits_rate": MetricDefinition(
            name="pulsar_ml_cache_hits_rate",
            metric_type="Gauge",
            meaning="Broker-side cache hits per second.",
            when_to_use="Use with cache miss metrics to judge read locality and cache efficiency.",
            default_promql="sum by (cluster) (pulsar_ml_cache_hits_rate)",
            labels=("cluster",),
            source=PULSAR_3_0_X_METRICS_SOURCE,
        ),
        "pulsar_ml_cache_misses_rate": MetricDefinition(
            name="pulsar_ml_cache_misses_rate",
            metric_type="Gauge",
            meaning="Broker-side cache misses per second.",
            when_to_use="Use when storage reads are rising and cache effectiveness looks poor.",
            default_promql="sum by (cluster) (pulsar_ml_cache_misses_rate)",
            labels=("cluster",),
            source=PULSAR_3_0_X_METRICS_SOURCE,
        ),
        "pulsar_replication_connected_count": MetricDefinition(
            name="pulsar_replication_connected_count",
            metric_type="Gauge",
            meaning="Replication subscriber connections currently up to remote clusters.",
            when_to_use="Use during geo-replication incidents or when cross-cluster delivery stops.",
            default_promql="sum by (cluster) (pulsar_replication_connected_count)",
            labels=("cluster",),
            source=PULSAR_3_0_X_METRICS_SOURCE,
        ),
        "pulsar_replication_delay_in_seconds": MetricDefinition(
            name="pulsar_replication_delay_in_seconds",
            metric_type="Gauge",
            meaning="Replication lag in seconds between produce time and replication attempt.",
            when_to_use="Use when replication is connected but remote clusters are receiving data late.",
            default_promql="max by (cluster) (pulsar_replication_delay_in_seconds)",
            labels=("cluster",),
            source=PULSAR_3_0_X_METRICS_SOURCE,
        ),
        "pulsar_lb_cpu_usage": MetricDefinition(
            name="pulsar_lb_cpu_usage",
            metric_type="Gauge",
            meaning="Broker CPU usage percentage from the load balancer view.",
            when_to_use="Use to spot overloaded brokers that may need bundle movement or capacity.",
            default_promql="max by (cluster, broker) (pulsar_lb_cpu_usage)",
            labels=("cluster", "broker", "metric"),
            source=PULSAR_3_0_X_METRICS_SOURCE,
        ),
        "pulsar_lb_memory_usage": MetricDefinition(
            name="pulsar_lb_memory_usage",
            metric_type="Gauge",
            meaning="Broker process memory usage percentage.",
            when_to_use="Use when brokers show heap pressure or traffic imbalance.",
            default_promql="max by (cluster, broker) (pulsar_lb_memory_usage)",
            labels=("cluster", "broker", "metric"),
            source=PULSAR_3_0_X_METRICS_SOURCE,
        ),
        "pulsar_lb_directMemory_usage": MetricDefinition(
            name="pulsar_lb_directMemory_usage",
            metric_type="Gauge",
            meaning="Broker direct memory usage percentage.",
            when_to_use="Use when Netty or entry cache direct memory may be exhausting off-heap capacity.",
            default_promql="max by (cluster, broker) (pulsar_lb_directMemory_usage)",
            labels=("cluster", "broker", "metric"),
            source=PULSAR_3_0_X_METRICS_SOURCE,
        ),
        "pulsar_active_connections": MetricDefinition(
            name="pulsar_active_connections",
            metric_type="Gauge",
            meaning="Current number of active broker connections.",
            when_to_use="Use during connection storms, proxy incidents, or listener exhaustion checks.",
            default_promql="sum by (cluster, broker) (pulsar_active_connections)",
            labels=("cluster", "broker", "metric"),
            source=PULSAR_3_0_X_METRICS_SOURCE,
        ),
        "pulsar_broker_throttled_connections": MetricDefinition(
            name="pulsar_broker_throttled_connections",
            metric_type="Gauge",
            meaning="Number of currently throttled connections.",
            when_to_use="Use when clients report connection rejections or high connection churn.",
            default_promql="sum by (cluster, broker) (pulsar_broker_throttled_connections)",
            labels=("cluster", "broker", "metric"),
            source=PULSAR_3_0_X_METRICS_SOURCE,
        ),
        "pulsar_managedLedger_client_bookkeeper_client_ADD_ENTRY": MetricDefinition(
            name="pulsar_managedLedger_client_bookkeeper_client_ADD_ENTRY",
            metric_type="Summary",
            meaning="BookKeeper add-entry latency from the broker client path.",
            when_to_use="Use when publish latency rises and storage write path is suspected.",
            default_promql=(
                "sum by (cluster) "
                "(rate(pulsar_managedLedger_client_bookkeeper_client_ADD_ENTRY_sum[5m])) "
                "/ "
                "sum by (cluster) "
                "(rate(pulsar_managedLedger_client_bookkeeper_client_ADD_ENTRY_count[5m]))"
            ),
            labels=("cluster",),
            source=PULSAR_3_0_X_METRICS_SOURCE,
            notes="Exposed only when bookkeeperClientExposeStatsToPrometheus=true.",
        ),
        "pulsar_managedLedger_client_bookkeeper_client_READ_ENTRY": MetricDefinition(
            name="pulsar_managedLedger_client_bookkeeper_client_READ_ENTRY",
            metric_type="Summary",
            meaning="BookKeeper read-entry latency from the broker client path.",
            when_to_use="Use when backlog drain or consumer read latency suggests bookie read issues.",
            default_promql=(
                "sum by (cluster) "
                "(rate(pulsar_managedLedger_client_bookkeeper_client_READ_ENTRY_sum[5m])) "
                "/ "
                "sum by (cluster) "
                "(rate(pulsar_managedLedger_client_bookkeeper_client_READ_ENTRY_count[5m]))"
            ),
            labels=("cluster",),
            source=PULSAR_3_0_X_METRICS_SOURCE,
            notes="Exposed only when bookkeeperClientExposeStatsToPrometheus=true.",
        ),
        "pulsar_managedLedger_client_bookkeeper_client_BOOKIE_QUARANTINE": MetricDefinition(
            name="pulsar_managedLedger_client_bookkeeper_client_BOOKIE_QUARANTINE",
            metric_type="Counter",
            meaning="Count of bookie clients quarantined by the broker.",
            when_to_use="Use when brokers appear to avoid unhealthy bookies or storage errors spike.",
            default_promql=(
                "sum by (cluster) "
                "(rate(pulsar_managedLedger_client_bookkeeper_client_BOOKIE_QUARANTINE[5m]))"
            ),
            labels=("cluster",),
            source=PULSAR_3_0_X_METRICS_SOURCE,
            notes="Exposed only when bookkeeperClientExposeStatsToPrometheus=true.",
        ),
    },
)
