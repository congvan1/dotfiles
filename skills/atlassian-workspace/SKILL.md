---
name: atlassian-workspace
description: Use when reading, searching, summarizing, exporting, creating, or updating Atlassian workspace content, including Confluence pages and Jira issues/tasks. Trigger for Confluence pages, Jira tickets, Atlassian custom domains, page exports, issue summaries, comments, attachments, CQL/JQL searches, and safe REST API writes.
---

# Atlassian Workspace

## Overview

Use this skill to work with Atlassian Cloud content through official REST APIs. It currently covers Confluence pages and Jira issues, with room for additional Atlassian products later. Prefer targeted fetches, preserve permissions, and validate versions before writes.

## When To Use

- The user wants to fetch, summarize, or export a Confluence page.
- The user wants to read a Jira issue/task, including description, status, comments, assignee, labels, or attachments.
- The user wants to search Confluence by title, label, space, or CQL.
- The user wants to search Jira by issue key, project, assignee, status, or JQL.
- The user wants to create or update Confluence pages or Jira issues through REST APIs.
- The user mentions an Atlassian custom domain such as `https://example.atlassian.net`.
- The user is building an Atlassian integration, MCP server, internal tool, or AI workflow.

## Environment

Read [`.env.example`](./.env.example) for expected variables.

- Never print `.env` contents or token values.
- Prefer `ATLASSIAN_BASE_URL` as the tenant base URL, for example `https://example.atlassian.net`.
- Use `ATLASSIAN_EMAIL` and `ATLASSIAN_API_TOKEN` for Cloud basic auth.
- Service-specific variables override shared variables:
  - Confluence: `CONFLUENCE_BASE_URL`, `CONFLUENCE_EMAIL`, `CONFLUENCE_API_TOKEN`
  - Jira: `JIRA_BASE_URL`, `JIRA_EMAIL`, `JIRA_API_TOKEN`
- Keep backward compatibility with existing `CONFLUENCE_*` environments.

Cloud API path shapes:

- Confluence Cloud pages: `/wiki/api/v2/pages`
- Confluence legacy content/CQL: `/wiki/rest/api`
- Jira Cloud issues/JQL: `/rest/api/3`

## Workflow

1. Identify the product and intent: Confluence read/write, Jira read/search/write, or generic Atlassian auth/API help.
2. Fetch the minimum metadata needed first.
3. Prefer local helper scripts for deterministic exports:
   - Confluence page export:
     - `python3 scripts/fetch_page_to_docs.py <page_id>`
   - Jira issue fetch:
     - `python3 scripts/fetch_jira_issue.py NEOSC-17607`
4. Fetch full bodies only for explicitly requested pages/issues or the top relevant search result.
5. For writes, fetch current state and version/update metadata first.
6. Produce a dry-run proposal unless the user explicitly asks to write.
7. Update only after validating required version fields and confirming risky changes.

## Jira Reading Strategy

Prefer direct issue fetch when the user gives an issue key or Jira URL.

- Issue by key:
  - `GET /rest/api/3/issue/{issueKey}?fields=summary,status,description,comment,assignee,reporter,created,updated,issuetype,priority,labels,attachment`
- JQL search:
  - `GET /rest/api/3/search/jql?jql=...&maxResults=25`

Rules:

- If anonymous access returns `404`, treat it as private/inaccessible unless credentials are provided.
- Summarize ADF descriptions/comments into readable text; do not dump raw ADF unless requested.
- Avoid fetching all comments/attachments for broad searches. Fetch full issue details only after choosing a specific issue.
- Never present hidden or unauthorized Jira content as if it were accessible.

## Confluence Reading Strategy

Prefer a 2-step fetch pattern.

1. Search metadata first.
   - Prefer CQL search when the user knows title, label, or space.
   - Legacy endpoint:
     - `GET /wiki/rest/api/content/search?cql=...&limit=25&start=0`
2. Fetch the chosen page by ID.
   - Preferred Cloud v2 page fetch:
     - `GET /wiki/api/v2/pages/{id}?body-format=storage&include-version=true`
   - Legacy fallback when the integration expects `expand`:
     - `GET /wiki/rest/api/content/{id}?expand=body.storage,version`

Rules:

- Always paginate search requests.
- Do not crawl whole spaces by default.
- Chunk large page bodies by heading before passing them to the model.
- Cache metadata and body by page ID and invalidate when `version.number` changes.
- Prefer the local export script over ad hoc `curl` when the user wants files written to disk.

## Write Strategy

### Confluence

Prefer Cloud v2 page endpoints for page creation and updates.

- Create page:
  - `POST /wiki/api/v2/pages`
- Update page:
  - `PUT /wiki/api/v2/pages/{id}`

Required update pattern:

1. Fetch current page:
   - `GET /wiki/api/v2/pages/{id}?body-format=storage&include-version=true`
2. Increment `version.number`.
3. Send the full update body with `id`, `status`, `title`, `body`, and `version`.

### Jira

Prefer minimal field updates.

- Fetch current issue first:
  - `GET /rest/api/3/issue/{issueKey}?fields=summary,status,description,labels,assignee`
- Update fields:
  - `PUT /rest/api/3/issue/{issueKey}`
- Add comment:
  - `POST /rest/api/3/issue/{issueKey}/comment`

For Jira writes, explicitly state which fields or comments will change before sending the request.

## Safe Defaults

- Never freehand unknown Confluence storage HTML or Jira ADF structure when a structured helper or existing body can be preserved.
- Use stable headings and lists for Confluence page drafts.
- Use Atlassian Document Format for Jira rich text writes unless the API wrapper handles conversion.
- Log every write action with product, object ID/key, title/summary, previous version/update marker when available, and intended change.
- Prefer dry-run mode for production, customer-facing, or critical pages/issues.
- Preserve title, parent, status, issue type, and project unless the user explicitly asks to change them.

## Permission Model

- Best: use user-scoped OAuth so Atlassian enforces the caller's permissions.
- Acceptable: use an API token for the current user or a tightly scoped service account.
- Never claim the skill can bypass permissions.

## API Notes

Custom-domain note:

- The tenant domain stays in the base URL, for example `https://example.atlassian.net`.
- Confluence API paths still include `/wiki/...`.
- Jira API paths do not include `/wiki`.

Examples:

- `https://example.atlassian.net/wiki/api/v2/pages/123456`
- `https://example.atlassian.net/rest/api/3/issue/NEOSC-17607`

Server/Data Center note:

- Do not assume Cloud v2 paths exist outside Atlassian Cloud.
- If the target is Server or Data Center, verify the deployment-specific base path before writing code.

## References

- For verified path details and payload shapes, read [references/api-paths.md](./references/api-paths.md).
- For operational guardrails and update workflow, read [references/write-safety.md](./references/write-safety.md).

## Constraints

- Do not dump full Confluence spaces or broad Jira searches into context.
- Do not skip version checks on Confluence updates.
- Do not expose tokens, cookies, or `.env` values.
- Do not assume Confluence and Jira share the same API prefix.
- Do not claim the skill can bypass Codex sandbox or approval policies.
