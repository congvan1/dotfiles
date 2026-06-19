#!/usr/bin/env python3
from __future__ import annotations

from typing import TYPE_CHECKING

from es_client import fail

if TYPE_CHECKING:
    from es_client import ElasticsearchClient


# DEPRECATED local aliases — fallback only.
# Real Kibana data views (fetched per space) are the primary source now.
# These remain as a last resort for patterns Kibana does not define yet,
# e.g. pulsar broker/proxy granularity. Prune entries here as the matching
# Kibana data views are created. Kibana matches win over these.
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


def _list_spaces(client: "ElasticsearchClient") -> list[str]:
    response = client.get_json("/api/spaces/space")
    spaces: list[str] = []
    if isinstance(response, list):
        for space in response:
            space_id = space.get("id") if isinstance(space, dict) else None
            if isinstance(space_id, str) and space_id:
                spaces.append(space_id)
    return spaces or ["default"]


def _data_views_path(space: str) -> str:
    # The default space has no URL prefix; named spaces use /s/<space>.
    return "/api/data_views" if space == "default" else f"/s/{space}/api/data_views"


def fetch_kibana_dataviews(client: "ElasticsearchClient") -> dict[str, dict[str, str]]:
    """Return {space: {name|title: title}} across all Kibana spaces."""
    result: dict[str, dict[str, str]] = {}
    for space in _list_spaces(client):
        response = client.get_json(_data_views_path(space))
        space_map: dict[str, str] = {}
        for data_view in response.get("data_view", []) if isinstance(response, dict) else []:
            title = (data_view.get("title") or "").strip()
            if not title:
                continue
            name = (data_view.get("name") or "").strip()
            if name:
                space_map.setdefault(name, title)
            space_map.setdefault(title, title)
        result[space] = space_map
    return result


def resolve_dataview(name: str, client: "ElasticsearchClient | None" = None) -> str:
    key = name.strip()
    if not key:
        fail("`--dataview` cannot be empty.")

    if client is not None:
        spaces = fetch_kibana_dataviews(client)

        # Explicit `space:name` (or `space:title`).
        if ":" in key:
            space, _, sub = key.partition(":")
            space_map = spaces.get(space.strip(), {})
            sub = sub.strip()
            if sub in space_map:
                return space_map[sub]
            fail(f"Unknown data view `{key}`. Run --list-dataviews to see options.")

        # Bare name: search across all spaces.
        matches = [(space, space_map[key]) for space, space_map in spaces.items() if key in space_map]
        distinct_titles = {title for _, title in matches}
        if len(distinct_titles) == 1:
            return next(iter(distinct_titles))
        if len(distinct_titles) > 1:
            options = ", ".join(f"{space}:{key}" for space, _ in matches)
            fail(f"`{key}` exists in multiple spaces. Disambiguate: {options}")

        # No Kibana match: fall back to deprecated local aliases.
        if key in DATA_VIEWS:
            return DATA_VIEWS[key]

        available = sorted(f"{space}:{n}" for space, m in spaces.items() for n in m) + sorted(DATA_VIEWS)
        fail(f"Unknown data view `{key}`. Available: {available}")

    # Offline path (no client): deprecated local aliases only.
    if key in DATA_VIEWS:
        return DATA_VIEWS[key]
    fail(f"Unknown data view `{key}`. Available: {sorted(DATA_VIEWS)}")


def format_dataview_listing(client: "ElasticsearchClient") -> str:
    lines: list[str] = []
    for space in _list_spaces(client):
        response = client.get_json(_data_views_path(space))
        data_views = response.get("data_view", []) if isinstance(response, dict) else []
        lines.append(f"[space: {space}]")
        for data_view in sorted(data_views, key=lambda d: (d.get("name") or d.get("title") or "")):
            name = data_view.get("name") or "(unnamed)"
            lines.append(f"  {space}:{name} -> {data_view.get('title')}")
        lines.append("")

    lines.append("[deprecated local aliases — fallback only]")
    for key in sorted(DATA_VIEWS):
        lines.append(f"  {key} -> {DATA_VIEWS[key]}")
    return "\n".join(lines)
