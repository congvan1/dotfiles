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
4. For Pulsar dispatch/backlog issues, read `references/pulsar-dispatch.md`.
5. Query metrics with `notion-skills:metric-search` before inferring root cause.
6. Query logs with `notion-skills:log-search` when metrics suggest broker/storage issues or the user asks for log evidence.
7. Return structured tables and clearly separate direct evidence from inference.

## References

- `references/pulsar-dispatch.md`: Pulsar dispatch/backlog workflow and interpretation rules.
- `references/promql.md`: reusable Pulsar PromQL and query helper examples.
- `references/log-search.md`: Pulsar broker log queries for RCA.
- `references/output-format.md`: required Summary, Per Partition, and Diagnosis tables.
- `seenow-argocd.md`: Seenow service structure, shared configuration, secrets, Kustomize, Helm, and deployment conventions.

## Output Style

- Prefer compact tables over prose.
- Keep diagnosis short and operational.
- State what is direct evidence and what is inference.
- End with the next most useful check.
