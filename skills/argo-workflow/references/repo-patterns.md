# Repo Argo Patterns

This reference captures the conventions visible in the current workspace.

## Reusable template pattern

Use `DevOps/reusable-argo-workflow-templates/workflow-templates/` for generic building blocks.

Common traits:

- single `WorkflowTemplate` with one main template
- inputs are direct and execution-focused
- container logic is mostly self-contained
- annotations may describe intent for UI readers
- shared volumes and secrets are declared directly in the template

Representative examples:

- `build-and-push-wft.yaml`
  - Kaniko-based build/push template with direct container execution
- `git-checkout-wft.yaml`
  - clones repo, checks out revision, writes commit SHA to `/tmp`
- `update-manifests-wft.yaml`
  - applies a list of yq updates over a checked-out workspace

## Ops primitive pattern

Use `ops-automation/workflows/primitives/` for atomic, boring, idempotent actions.

Common traits:

- `metadata.namespace: argo-events`
- narrow parameter surface
- one operational action per template
- outputs promoted for upstream templates
- logs are explicit and operator-readable

Representative examples:

- `run-kubectl-wft.yaml`
  - generic kubectl executor using env-specific kubeconfigs and optional stdin
- `truncate-redis-keys-wft.yaml`
  - multi-step primitive with explicit create/wait/exec flow and `onExit` cleanup
- `parse-yaml-wft.yaml`
  - helper template that reads YAML input and emits structured JSON output

## Ops composite pattern

Use `ops-automation/workflows/composites/` when the workflow composes primitives into a reusable procedure.

Common traits:

- orchestration is the main value
- steps call primitives via `templateRef`
- intermediate outputs are passed explicitly
- helper templates may exist locally when composition needs a small custom transform

Representative examples:

- `k8s-scale-to-zero-wft.yaml`
  - fetches workload, parses replicas, then scales to zero
- `create-and-patch-resource-from-configmap-wft.yaml`
  - gets configmap content, patches it with yq, then applies it

## Release orchestration pattern

Use `ops-automation/workflows/releases/` for service-level or system-level releases.

Common traits:

- higher-level ordering and rollback/cleanup concerns
- `dag` is common when dependencies matter
- parameters are broader because they coordinate many downstream workflows
- `onExit` handlers restore safety settings or cleanup system state

Representative example:

- `subscription-v2-migration-wft.yaml`
  - disables ArgoCD automation, runs multiple service migrations with dependencies, then restores automation in `rollback-handler`

## Practical rules

- Prefer adding one more reusable primitive over embedding another long shell block in a release workflow.
- If the same logic could be useful outside one release, it likely belongs in `primitives` or `composites`.
- If a workflow creates temporary pods or resources, add deterministic cleanup.
- Keep step names literal. Operators should understand the workflow from the graph view alone.
- Preserve existing environment vocabulary: `dev`, `stg`, `prd`, and sometimes `ctl`.
