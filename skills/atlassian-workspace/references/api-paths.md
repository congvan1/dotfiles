# Atlassian API Paths

Use these path patterns relative to `ATLASSIAN_BASE_URL`, normally `https://example.atlassian.net`.

This reference assumes Atlassian Cloud unless stated otherwise.

## Custom Domain

For an Atlassian Cloud tenant such as `https://example.atlassian.net`:

- Confluence keeps the `/wiki` prefix:
  - `https://example.atlassian.net/wiki/api/v2/pages`
  - `https://example.atlassian.net/wiki/rest/api/content/search`
- Jira does not use `/wiki`:
  - `https://example.atlassian.net/rest/api/3/issue/NEOSC-17607`
  - `https://example.atlassian.net/rest/api/3/search/jql`

If the target is Server or Data Center, verify the deployment-specific base path before assuming these Cloud paths.

## Confluence Cloud v2 Page Endpoints

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

## Confluence Legacy Content Endpoints

Use these when the caller explicitly needs CQL search or an older content API shape.

- Search by CQL:
  - `GET /wiki/rest/api/content/search?cql=...&limit=25&start=0`
- Get content by ID:
  - `GET /wiki/rest/api/content/{id}?expand=body.storage,version`
- Update content:
  - `PUT /wiki/rest/api/content/{id}`
- Create content:
  - `POST /wiki/rest/api/content`

## Jira Cloud Issue Endpoints

- Get issue by key:
  - `GET /rest/api/3/issue/{issueKey}?fields=summary,status,description,comment,assignee,reporter,created,updated,issuetype,priority,labels,attachment`
- JQL search:
  - `GET /rest/api/3/search/jql?jql=project%20%3D%20NEOSC&maxResults=25`
- Update issue fields:
  - `PUT /rest/api/3/issue/{issueKey}`
- Add comment:
  - `POST /rest/api/3/issue/{issueKey}/comment`

Typical issue update payload:

```json
{
  "fields": {
    "summary": "Updated summary",
    "labels": ["automation", "reviewed"]
  }
}
```

Jira rich text fields such as `description` and comments use Atlassian Document Format.

## Search Guidance

Prefer targeted queries.

Confluence CQL:

- By title:
  - `title ~ "Auth engineer"`
- By space:
  - `space = ENG`
- By label:
  - `label = auth`

Jira JQL:

- By issue key:
  - `key = NEOSC-17607`
- By project and status:
  - `project = NEOSC AND statusCategory != Done`
- By assignee:
  - `assignee = currentUser() ORDER BY updated DESC`

Avoid broad, recursive fetches.
