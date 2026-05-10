---
name: confluence-docs
description: Use when reading, searching, drafting, creating, or updating Confluence pages through the REST API. Primarily targets Confluence Cloud, including Cloud tenants behind custom domains, and covers safe page writes with version checks, CQL search fallback, and minimal-fetch workflows for documentation assistants.
---

# Confluence Docs

## Overview

Use this skill to read and write Confluence pages safely through the REST API without crawling an entire space. Prefer targeted fetches, preserve permissions, and validate page versions before updates.

## When To Use

- The user wants to search Confluence pages by title, label, space, or CQL.
- The user wants to fetch one page, summarize it, or extract a specific section.
- The user wants to create or update a page through the Confluence API.
- The user mentions Confluence custom domains and needs the correct API base path.
- The user is building a Confluence integration, MCP server, internal tool, or AI skill.

## Environment

Read [`.env.example`](./.env.example) for expected variables.

- Never print `.env` contents in responses.
- Prefer `CONFLUENCE_BASE_URL` as the human-facing custom domain, for example `https://docs.example.com`.
- Assume Confluence Cloud unless the user explicitly says Server or Data Center.
- Build API URLs by appending one of these prefixes to `CONFLUENCE_BASE_URL`:
  - Cloud v2 pages: `/wiki/api/v2`
  - Legacy content and CQL fallback: `/wiki/rest/api`

## Workflow

1. Identify intent: search, read, create, or update.
2. Fetch the minimum metadata needed first.
3. Prefer the local helper script for page export workflows:
   - `python3 /Users/van/.codex/skills/confluence-docs/scripts/fetch_page_to_docs.py <page_id>`
   - Add `--children --recursive` for descendant exports.
   - Add `--use-markitdown` to convert the stored Confluence HTML with Microsoft `markitdown`.
4. Fetch full page content only for the top relevant result or explicitly requested IDs when not using the helper script.
5. For updates, fetch the current page and version first.
6. Produce a proposed body in `storage` format unless the integration already uses `atlas_doc_format`.
7. Update only after version validation and, for risky pages, explicit human approval.

## Reading Strategy

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

Legacy fallback:
- If the target integration already depends on legacy content APIs, use:
  - `PUT /wiki/rest/api/content/{id}`
  - Include `body.storage` and incremented `version.number`

## Safe Defaults

- Never let the model freehand unknown Confluence HTML structure.
- Use page templates with stable headings and lists.
- Keep writes in `storage` representation unless the caller explicitly requires `atlas_doc_format`.
- Log every write action with page ID, title, previous version, and next version.
- Prefer dry-run mode for critical pages.
- For updates, preserve title, parent, and status unless the user asked to change them.

## Permission Model

- Best: use user-scoped OAuth so Confluence enforces the caller's permissions.
- Acceptable: use a service account with tightly scoped access.
- Never present hidden or unauthorized content as if it were accessible.

## API Notes

Directly verified through Context7 from Atlassian docs:
- Cloud v2 page endpoints use `/wiki/api/v2/pages`
- Cloud v2 page-by-id uses `/wiki/api/v2/pages/{id}`
- Cloud v2 update uses `/wiki/api/v2/pages/{id}`
- Legacy CQL search uses `/wiki/rest/api/content/search`
- Legacy content fetch/update uses `/wiki/rest/api/content/{id}`

Custom-domain note:
- The custom domain stays in the base URL, for example `https://docs.example.com`
- The API path still includes `/wiki/...`
- Example full URL:
  - `https://docs.example.com/wiki/api/v2/pages/123456`

Server/Data Center note:
- Do not assume `/wiki/api/v2/pages` exists outside Confluence Cloud.
- If the target is Server or Data Center, prefer the legacy content APIs first and verify the deployment-specific base path before writing code.

## References

- For verified path details and payload shapes, read [references/api-paths.md](./references/api-paths.md).
- For operational guardrails and update workflow, read [references/write-safety.md](./references/write-safety.md).

## Constraints

- Do not dump full Confluence spaces into context.
- Do not skip version checks on update.
- Do not expose tokens, cookies, or `.env` values.
- Do not assume the old `/rest/api/content` path is the only correct one on Cloud.
- Do not claim the skill can bypass Codex sandbox or approval policies; prefer the script path so previously approved command prefixes can be reused when available.
