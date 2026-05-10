# Confluence API Paths

Use these path patterns relative to `CONFLUENCE_BASE_URL`.

This reference assumes Confluence Cloud unless stated otherwise.

## Custom Domain

For a custom domain such as `https://docs.example.com`, the API path still keeps the `/wiki` prefix:

- `https://docs.example.com/wiki/api/v2/pages`
- `https://docs.example.com/wiki/rest/api/content/search`

This is the Cloud shape verified from Atlassian Cloud docs. If the target is Server or Data Center, verify the deployment-specific base path before assuming `/wiki/api/v2/...` exists.

## Preferred Cloud v2 Page Endpoints

Verified through Context7 from Atlassian Confluence Cloud REST v2.

- Get page by ID:
  - `GET /wiki/api/v2/pages/{id}?body-format=storage&include-version=true`
- Create page:
  - `POST /wiki/api/v2/pages`
- Update page:
  - `PUT /wiki/api/v2/pages/{id}`

Typical create payload:

```json
{
  "spaceId": "123456",
  "status": "current",
  "title": "Page title",
  "parentId": "789012",
  "body": {
    "representation": "storage",
    "value": "<h1>Summary</h1><p>Draft body</p>"
  }
}
```

Typical update payload:

```json
{
  "id": "123456",
  "status": "current",
  "title": "Page title",
  "body": {
    "representation": "storage",
    "value": "<h1>Summary</h1><p>Updated body</p>"
  },
  "version": {
    "number": 8,
    "message": "Update from automation"
  }
}
```

## Legacy Content Endpoints

Use these when the caller explicitly needs CQL search or an older content API shape.

- Search by CQL:
  - `GET /wiki/rest/api/content/search?cql=...&limit=25&start=0`
- Get content by ID:
  - `GET /wiki/rest/api/content/{id}?expand=body.storage,version`
- Update content:
  - `PUT /wiki/rest/api/content/{id}`
- Create content:
  - `POST /wiki/rest/api/content`

Typical legacy update payload:

```json
{
  "id": "123456",
  "type": "page",
  "title": "Page title",
  "version": {
    "number": 8
  },
  "body": {
    "storage": {
      "value": "<h1>Summary</h1><p>Updated body</p>",
      "representation": "storage"
    }
  }
}
```

## Search Guidance

Prefer targeted queries:

- By title:
  - `title ~ "Auth engineer"`
- By space:
  - `space = ENG`
- By label:
  - `label = auth`

Avoid broad, recursive fetches.
