from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, Iterable

from pathlib import Path
import sys


REFERENCE_DIRECTORY = Path(__file__).resolve().parent.parent / "references"
if str(REFERENCE_DIRECTORY) not in sys.path:
    sys.path.insert(0, str(REFERENCE_DIRECTORY))

from pulsar_metrics import PULSAR_COMPONENT_CATALOG


@dataclass(frozen=True)
class PrometheusEnvironment:
    name: str
    base_url: str


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
    metrics: Dict[str, MetricDefinition]


PROMETHEUS_ENVIRONMENTS = {
    "dev": PrometheusEnvironment(
        name="dev",
        base_url="https://dev-prometheus.vtvprime.vn",
    ),
    "stg": PrometheusEnvironment(
        name="stg",
        base_url="https://stg-prometheus.vtvprime.vn",
    ),
    "prd": PrometheusEnvironment(
        name="prd",
        base_url="https://prometheus.vtvprime.vn",
    ),
}


COMPONENT_CATALOGS = {
    PULSAR_COMPONENT_CATALOG.name: PULSAR_COMPONENT_CATALOG,
}


class MetricCatalogRegistry:
    def __init__(self, catalogs: Dict[str, ComponentCatalog]):
        self._catalogs = catalogs

    def get_environment(self, environment_name: str) -> PrometheusEnvironment:
        environment = PROMETHEUS_ENVIRONMENTS.get(environment_name)
        if environment is None:
            raise ValueError(f"Unknown environment: {environment_name}")
        return environment

    def get_component_catalog(self, component_name: str) -> ComponentCatalog:
        component_catalog = self._catalogs.get(component_name)
        if component_catalog is None:
            raise ValueError(f"Unknown component: {component_name}")
        return component_catalog

    def get_metric_definition(
        self,
        component_name: str,
        metric_name: str,
    ) -> MetricDefinition:
        component_catalog = self.get_component_catalog(component_name)
        metric_definition = component_catalog.metrics.get(metric_name)
        if metric_definition is None:
            raise ValueError(
                f"Unknown metric '{metric_name}' for component '{component_name}'"
            )
        return metric_definition

    def list_metrics(self, component_name: str) -> Iterable[MetricDefinition]:
        component_catalog = self.get_component_catalog(component_name)
        return component_catalog.metrics.values()


def build_metric_catalog_registry() -> MetricCatalogRegistry:
    return MetricCatalogRegistry(COMPONENT_CATALOGS)
