---
name: argo-workflow
description: Use when creating, updating, reviewing, or refactoring Argo Workflow or WorkflowTemplate YAML, especially when following the patterns in DevOps/reusable-argo-workflow-templates and ops-automation. Covers reusable templates, ops primitives, composites, releases, templateRef composition, parameter design, outputs, and safety-oriented workflow structure.
---

# Argo Workflow Skill

Use this skill when the user wants Argo Workflow YAML written to match the patterns already used in the Cellutions repositories.

## Default workflow

1. Inspect nearby templates before editing. Match the local style instead of inventing a new one.
2. Classify the change before writing YAML:
   - reusable building block in `DevOps/reusable-argo-workflow-templates/workflow-templates/`
   - ops primitive in `ops-automation/workflows/primitives/`
   - ops composite in `ops-automation/workflows/composites/`
   - release or orchestration workflow in `ops-automation/workflows/releases/`
3. Keep the abstraction boundary clean:
   - primitives do one thing and expose concrete inputs and outputs
   - composites stitch primitives together with `templateRef`
   - releases encode ordering, dependencies, guardrails, and cleanup
4. Preserve naming conventions:
   - file names usually end in `-wft.yaml`
   - `metadata.name` matches the file stem
   - `spec.entrypoint` matches the main template name
5. Prefer explicit parameter contracts:
   - add `description` for non-obvious parameters
   - use `default` and `enum` where the examples do
   - pass values through `arguments.parameters` explicitly
6. For `ops-automation`, prefer composition via `templateRef` instead of duplicating kubectl/yq/git logic.
7. Keep shell steps operationally readable:
   - use `sh` or `bash` with `-euc`
   - log intent with short prefixes like `[kubectl]` or `[Redis]`
   - write output parameters to files under `/tmp`
8. Bias toward safe, auditable workflows:
   - destructive steps should be explicit
   - cleanup belongs in `onExit` handlers when temporary resources are created
   - favor idempotent primitives and forward recovery patterns

## Repo-specific guidance

- In `ops-automation`, most templates are `WorkflowTemplate` objects in namespace `argo-events`.
- Reusable templates in `DevOps/reusable-argo-workflow-templates` are usually more self-contained and may omit namespace.
- If the workflow needs shared execution capability in `ops-automation`, first look for an existing primitive or helper template to reuse.
- If multiple workflows will need the same logic, add or extend a reusable template instead of embedding shell inline everywhere.
- For larger ops workflows, prefer `steps` or `dag` that make sequencing obvious from the YAML.

## Authoring checklist

- `apiVersion`, `kind`, `metadata.name`, and `spec.entrypoint` are aligned
- parameters are named consistently across `inputs`, `arguments`, and `workflow.parameters`
- outputs use `valueFrom.path` or `valueFrom.parameter` consistently
- referenced template names actually exist
- shell snippets quote interpolated values carefully
- examples of environment values, namespaces, and resource names match existing repo usage

## When to read more

Read the repo pattern reference before making non-trivial edits:
[repo-patterns.md](/Users/van/.codex/skills/argo-workflow/references/repo-patterns.md)
