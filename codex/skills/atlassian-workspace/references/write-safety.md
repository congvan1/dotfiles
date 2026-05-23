# Write Safety

## Required Update Flow

### Confluence Pages

1. Fetch the current page by ID.
2. Read the current `version.number`.
3. Draft the new body outside the API call.
4. Validate the representation:
   - Prefer `storage`
   - Only use `atlas_doc_format` if the integration already depends on it
5. Increment `version.number`.
6. Submit the full page update.

### Jira Issues

1. Fetch the current issue by key.
2. Read the current fields that may be changed.
3. Draft the intended field update or comment outside the API call.
4. Validate rich text payloads as Atlassian Document Format when updating `description` or adding formatted comments.
5. Submit only the changed fields or one comment.
6. Report exactly which fields/comments changed.

## Guardrails

- Keep writes small and intentional.
- Preserve existing fields unless the user asked to change them.
- Use templates for repeated page or issue comment types.
- If the page or issue is sensitive, show a draft or diff before writing.
- Never change status, assignee, issue type, project, parent page, or page title unless explicitly requested.

## Suggested Confluence Template

Use stable sections:

```html
<h1>Title</h1>
<p>Summary</p>
<h2>Context</h2>
<p>...</p>
<h2>Details</h2>
<ul>
  <li>...</li>
</ul>
```

Avoid arbitrary markup generation when a simple structure works.

## Suggested Jira Comment Template

Use a concise structure:

```text
Summary:
- ...

Validation:
- ...

Next action:
- ...
```

Convert to Atlassian Document Format only at the API boundary.

## Caching

Cache Confluence:

- page ID
- title
- space ID
- last known version
- chunked body sections

Cache Jira:

- issue key
- summary
- status
- updated timestamp
- selected comments or description hash

Invalidate Confluence cache when `version.number` changes. Invalidate Jira cache when `updated` changes.
