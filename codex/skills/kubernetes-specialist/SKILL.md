---
name: kubernetes-specialist
description: Use when deploying or managing Kubernetes workloads. Invoke to create deployment manifests, configure pod security policies, set up service accounts, define network isolation rules, debug pod crashes, analyze resource limits, inspect container logs, or right-size workloads. Use for Helm charts, RBAC policies, NetworkPolicies, storage configuration, performance optimization, GitOps pipelines, and multi-cluster management. Before running kubectl, identify and state the current kube context. In production contexts, especially `vng-prd`, restrict kubectl usage to read-only inspection commands unless the user explicitly asks for a mutating action.
license: MIT
metadata:
  author: https://github.com/Jeffallan
  version: "1.1.1"
  domain: infrastructure
  triggers: Kubernetes, K8s, kubectl, Helm, container orchestration, pod deployment, RBAC, NetworkPolicy, Ingress, StatefulSet, Operator, CRD, CustomResourceDefinition, ArgoCD, Flux, GitOps, Istio, Linkerd, service mesh, multi-cluster, cost optimization, VPA, spot instances
  role: specialist
  scope: infrastructure
  output-format: manifests
  related-skills: devops-engineer, cloud-architect, sre-engineer, terraform-engineer, security-reviewer, chaos-engineer
---

# Kubernetes Specialist

## When to Use This Skill

- Deploying workloads (Deployments, StatefulSets, DaemonSets, Jobs)
- Configuring networking (Services, Ingress, NetworkPolicies)
- Managing configuration (ConfigMaps, Secrets, environment variables)
- Setting up persistent storage (PV, PVC, StorageClasses)
- Creating Helm charts for application packaging
- Troubleshooting cluster and workload issues
- Implementing security best practices

## Core Workflow

1. **Analyze requirements** — Understand workload characteristics, scaling needs, security requirements
2. **Confirm context** — Before any `kubectl` command, identify the current kube context, state it, and confirm whether the intended action matches that environment
3. **Design architecture** — Choose workload types, networking patterns, storage solutions
4. **Implement manifests** — Create declarative YAML with proper resource limits, health checks
5. **Secure** — Apply RBAC, NetworkPolicies, Pod Security Standards, least privilege
6. **Validate** — Use context-appropriate validation commands; in production contexts prefer read-only inspection such as `kubectl get`, `kubectl describe`, `kubectl logs`, and `kubectl events`

## Kubectl Safety Policy

- Detect and state the active kube context before running `kubectl`.
- If the context is unclear, ask the user which cluster or context to use before running `kubectl`.
- Treat `vng-prd` as production.
- In `vng-prd`, run only read-only inspection commands by default.
- In `vng-prd`, do not run mutating commands unless the user explicitly asks for that exact action and acknowledges production risk.
- In `vng-prd`, before any mutating command, run a dry-run first when the tool supports it and present the exact target context and command.
- In `vng-prd`, after dry-run succeeds, ask for a final explicit confirmation before the real mutating command.
- In GitOps-managed production environments, prefer changing git and syncing via the delivery system over direct `kubectl apply`.
- Outside production, still state the context before running `kubectl`, but proceed normally when the requested action is appropriate.

### Read-only commands

Read-only commands include inspection and discovery operations such as:

- `kubectl get`
- `kubectl describe`
- `kubectl logs`
- `kubectl top`
- `kubectl auth can-i`
- `kubectl cluster-info`
- `kubectl version`
- `kubectl config current-context`

### Mutating commands

Treat these as mutating and never run them in `vng-prd` without explicit user authorization:

- `kubectl apply`
- `kubectl create`
- `kubectl delete`
- `kubectl edit`
- `kubectl patch`
- `kubectl replace`
- `kubectl scale`
- `kubectl annotate`
- `kubectl label`
- `kubectl cordon`
- `kubectl uncordon`
- `kubectl drain`
- `kubectl rollout restart`
- `kubectl rollout undo`
- `kubectl exec` when it changes state in the container

### Production mutation workflow

For `vng-prd`, use this sequence for any mutating kubectl action:

1. State the exact context and namespace.
2. Show the exact mutating command that would run.
3. Run a dry-run first when available.
4. Summarize the dry-run result briefly.
5. Ask for final confirmation.
6. Only then run the real command.

Examples:

```bash
kubectl apply --context vng-prd --server-side --dry-run=server -f manifest.yaml
kubectl diff --context vng-prd -f manifest.yaml
```

Do not skip the dry-run step for `kubectl apply`, `kubectl delete`, `kubectl patch`, `kubectl replace`, `kubectl scale`, or similar production mutations unless the user explicitly instructs you to bypass it.

## Reference Guide

Load detailed guidance based on context:

| Topic | Reference | Load When |
|-------|-----------|-----------|
| Workloads | `references/workloads.md` | Deployments, StatefulSets, DaemonSets, Jobs, CronJobs |
| Networking | `references/networking.md` | Services, Ingress, NetworkPolicies, DNS |
| Configuration | `references/configuration.md` | ConfigMaps, Secrets, environment variables |
| Storage | `references/storage.md` | PV, PVC, StorageClasses, CSI drivers |
| Helm Charts | `references/helm-charts.md` | Chart structure, values, templates, hooks, testing, repositories |
| Troubleshooting | `references/troubleshooting.md` | kubectl debug, logs, events, common issues |
| Custom Operators | `references/custom-operators.md` | CRD, Operator SDK, controller-runtime, reconciliation |
| Service Mesh | `references/service-mesh.md` | Istio, Linkerd, traffic management, mTLS, canary |
| GitOps | `references/gitops.md` | ArgoCD, Flux, progressive delivery, sealed secrets |
| Cost Optimization | `references/cost-optimization.md` | VPA, HPA tuning, spot instances, quotas, right-sizing |
| Multi-Cluster | `references/multi-cluster.md` | Cluster API, federation, cross-cluster networking, DR |

## Constraints

### MUST DO
- Use declarative YAML manifests (avoid imperative kubectl commands)
- State the active kube context before any `kubectl` command
- Ask for clarification before any `kubectl` command if the target cluster or context is ambiguous
- Restrict `kubectl` in `vng-prd` to read-only commands unless the user explicitly requests a mutating production action
- For mutating `kubectl` in `vng-prd`, run dry-run first when supported and ask for final confirmation before the real command
- Set resource requests and limits on all containers
- Include liveness and readiness probes
- Use secrets for sensitive data (never hardcode credentials)
- Apply least privilege RBAC permissions
- Implement NetworkPolicies for network segmentation
- Use namespaces for logical isolation
- Label resources consistently for organization
- Document configuration decisions in annotations

### MUST NOT DO
- Do not run mutating `kubectl` commands in `vng-prd` unless the user explicitly requests them
- Do not run real mutating `kubectl` commands in `vng-prd` before a dry-run and final confirmation when dry-run is supported
- Deploy to production without resource limits
- Store secrets in ConfigMaps or as plain environment variables
- Use default ServiceAccount for application pods
- Allow unrestricted network access (default allow-all)
- Run containers as root without justification
- Skip health checks (liveness/readiness probes)
- Use latest tag for production images
- Expose unnecessary ports or services

## Common YAML Patterns

### Deployment with resource limits, probes, and security context

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: my-namespace
  labels:
    app: my-app
    version: "1.2.3"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
        version: "1.2.3"
    spec:
      serviceAccountName: my-app-sa   # never use default SA
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
      containers:
        - name: my-app
          image: my-registry/my-app:1.2.3   # never use latest
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
          livenessProbe:
            httpGet:
              path: /healthz
              port: 8080
            initialDelaySeconds: 15
            periodSeconds: 20
          readinessProbe:
            httpGet:
              path: /ready
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          envFrom:
            - secretRef:
                name: my-app-secret   # pull credentials from Secret, not ConfigMap
```

### Minimal RBAC (least privilege)

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-sa
  namespace: my-namespace
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: my-app-role
  namespace: my-namespace
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list"]   # grant only what is needed
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: my-app-rolebinding
  namespace: my-namespace
subjects:
  - kind: ServiceAccount
    name: my-app-sa
    namespace: my-namespace
roleRef:
  kind: Role
  name: my-app-role
  apiGroup: rbac.authorization.k8s.io
```

### NetworkPolicy (default-deny + explicit allow)

```yaml
# Deny all ingress and egress by default
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: my-namespace
spec:
  podSelector: {}
  policyTypes: ["Ingress", "Egress"]
---
# Allow only specific traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-my-app
  namespace: my-namespace
spec:
  podSelector:
    matchLabels:
      app: my-app
  policyTypes: ["Ingress"]
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 8080
```

## Validation Commands

After deploying, verify health and security posture:

```bash
# Confirm the active context first
kubectl config current-context

# Watch rollout complete
kubectl rollout status deployment/my-app -n my-namespace

# Stream pod events to catch crash loops or image pull errors
kubectl get pods -n my-namespace -w

# Inspect a specific pod for failures
kubectl describe pod <pod-name> -n my-namespace

# Check container logs
kubectl logs <pod-name> -n my-namespace --previous   # use --previous for crashed containers

# Verify resource usage vs. limits
kubectl top pods -n my-namespace

# Audit RBAC permissions for a service account
kubectl auth can-i --list --as=system:serviceaccount:my-namespace:my-app-sa

# Roll back a failed deployment
kubectl rollout undo deployment/my-app -n my-namespace
```

In `vng-prd`, limit validation to read-only commands from this section unless the user explicitly asks for a production mutation.

## Output Templates

When implementing Kubernetes resources, provide:
1. Complete YAML manifests with proper structure
2. RBAC configuration if needed (ServiceAccount, Role, RoleBinding)
3. NetworkPolicy for network isolation
4. Brief explanation of design decisions and security considerations
