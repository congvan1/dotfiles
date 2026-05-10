# Write Safety

## Required Update Flow

1. Fetch the current page by ID.
2. Read the current `version.number`.
3. Draft the new body outside the API call.
4. Validate the representation:
   - Prefer `storage`
   - Only use `atlas_doc_format` if the integration already depends on it
5. Increment `version.number`.
6. Submit the update.

## Guardrails

- Keep writes small and intentional.
- Preserve existing fields unless the user asked to change them.
- Use templates for repeated page types.
- If the page is sensitive, show a draft or diff before write.

## Suggested Templates

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

## Caching

Cache:

- page ID
- title
- space ID
- last known version
- chunked body sections

Invalidate cache when `version.number` changes.
