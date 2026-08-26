---
name: congvan
description: Use this skill for VTVPrime DevOps incident triage, especially Apache Pulsar dispatch/backlog problems where the user wants structured metric tables, PromQL, and broker-vs-consumer diagnosis. Trigger on Pulsar slow drain, dispatch rate, consumer rate, backlog, unacked, partition-level lag, reader subscriptions, or structured incident output.
---

# Congvan DevOps Skill

Use this skill for VTVPrime incident analysis where the user wants direct evidence, compact tables, and clear next checks.

## Default Workflow

1. Identify environment: `dev`, `stg`, or `prd`.
2. Identify target service, topic, subscription, pod, or namespace.
3. For Seenow service setup or deployment, read `seenow-argocd.md`.
4. For ArgoCD/Kubernetes deployment, rollout, hook, image, ConfigMap, Secret,
   StatefulSet, or Flink failures, also read `references/argocd.md`.
5. Before writing manifests, enumerate every mandatory environment variable from
   the service README and source, per component. Classify each as shared,
   plaintext configuration, or credential; do not silently omit unknown keys.
   Do not set optional variables that already have documented application
   defaults unless the user asks to override them; set only mandatory values
   and explicitly requested overrides.
   When a required credential is unavailable, create the requested
   `*-sealed-secret.yaml` draft as a Kubernetes `Secret` with `stringData` keys
   set to `<FILL_ME>`; do not copy another environment's ciphertext or secret.
   Mark the overlay non-deployable until the draft is populated and sealed.
   Do not add CI-owned annotations or labels to service/projector values unless
   the user explicitly provides them. Leave `annotations`, `podAnnotations`,
   `labels`, and `podLabels` absent when CI injects Backstage,
   central-contract, or event-routing metadata. For Flink overlays, copy the
   S3 endpoint and credential pair from an existing projector in the same
   environment when they share checkpoint/savepoint storage.
   When a cursor key is shared across services in one environment, reuse the
   existing same-environment sealed ciphertext rather than generating a new
   key; use that environment's sealed-secret key.
   When the service documentation does not specify a Redis cluster, use the
   default Redis cluster endpoint already used by other services in the same
   environment. Do not invent a service-specific Redis address.
6. For Pulsar dispatch/backlog issues, read `references/pulsar-dispatch.md`.
7. Query metrics with `notion-skills:metric-search` before inferring root cause.
8. Query logs with `notion-skills:log-search` when metrics suggest broker/storage issues or the user asks for log evidence.
9. Return structured tables and clearly separate direct evidence from inference.

## References

- `references/pulsar-dispatch.md`: Pulsar dispatch/backlog workflow and interpretation rules.
- `references/promql.md`: reusable Pulsar PromQL and query helper examples.
- `references/log-search.md`: Pulsar broker log queries for RCA.
- `references/output-format.md`: required Summary, Per Partition, and Diagnosis tables.
- `references/argocd.md`: ArgoCD/Kubernetes deployment and rollout triage.
- `seenow-argocd.md`: Seenow service structure, shared configuration, secrets, Kustomize, Helm, and deployment conventions.

## Output Style

- Prefer compact tables over prose.
- Keep diagnosis short and operational.
- State what is direct evidence and what is inference.
- End with the next most useful check.

## Missing production secrets

For a requested production overlay with an unavailable credential, create a
placeholder draft using this exact shape, even though the filename contains
`sealed-secret`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: <service>-<purpose>
type: Opaque
stringData:
  REQUIRED_KEY: <FILL_ME>
```

Never block the manifest work solely because the real value is unavailable.
Do not claim the overlay is deployable; explicitly report that the placeholder
must be filled, sealed, and revalidated before ArgoCD sync.
