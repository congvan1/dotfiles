#!/usr/bin/env python3
from __future__ import annotations

from es_client import fail


# Simulated Kibana data views for direct-script querying.
DATA_VIEWS: dict[str, str] = {
    "sn-dev-workload": ".ds-k8s-dev_sn-dev-workload*",
    "sn-stg-workload": ".ds-k8s-stg_sn-stg-workload*",
    "sn-prd-workload": ".ds-k8s-prd_sn-prd-workload*",
    "mh-dev-workload": ".ds-k8s-dev_mh-dev-workload*",
    "mh-stg-workload": ".ds-k8s-stg_mh-stg-workload*",
    "mh-prd-workload": ".ds-k8s-prd_mh-prd-workload*",
    "pulsar-prd-all": ".ds-k8s-prd_sn-prd-pulsar*",
    "pulsar-prd-broker": ".ds-k8s-prd_sn-prd-pulsar_broker-*",
    "pulsar-prd-proxy": ".ds-k8s-prd_sn-prd-pulsar_proxy-*",
    "pulsar-prd-manager": ".ds-k8s-prd_sn-prd-pulsar_pulsar-manager-*",
    "pulsar-prd-generic": ".ds-k8s-prd_sn-prd-pulsar-*",
    "pulsar-stg-all": ".ds-k8s-stg_sn-stg-pulsar*",
    "pulsar-stg-broker": ".ds-k8s-stg_sn-stg-pulsar_broker-*",
    "pulsar-stg-proxy": ".ds-k8s-stg_sn-stg-pulsar_proxy-*",
    "pulsar-stg-manager": ".ds-k8s-stg_sn-stg-pulsar_pulsar-manager-*",
    "pulsar-dev-all": ".ds-k8s-dev_sn-dev-pulsar*",
    "pulsar-dev-broker": ".ds-k8s-dev_sn-dev-pulsar_broker-*",
    "pulsar-dev-proxy": ".ds-k8s-dev_sn-dev-pulsar_proxy-*",
    "pulsar-dev-operator": ".ds-k8s-dev_pulsar_sn-dev-pulsar-operator-crd-app-*",
}


def resolve_dataview(name: str) -> str:
    key = name.strip()
    if not key:
        fail("`--dataview` cannot be empty.")
    try:
        return DATA_VIEWS[key]
    except KeyError:
        fail(f"Unknown dataview `{key}`. Available: {sorted(DATA_VIEWS)}")
