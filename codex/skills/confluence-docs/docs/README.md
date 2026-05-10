# Generated Confluence Docs

Run the fetcher to export a Confluence page into this directory:

```bash
python3 /Users/van/.codex/skills/confluence-docs/scripts/fetch_page_to_docs.py 140148744
```

Use `markitdown` for richer HTML-to-Markdown conversion:

```bash
python3 /Users/van/.codex/skills/confluence-docs/scripts/fetch_page_to_docs.py 140148744 --use-markitdown
```

Export all child pages under a parent page:

```bash
python3 /Users/van/.codex/skills/confluence-docs/scripts/fetch_page_to_docs.py 138969118 --children --recursive --use-markitdown
```

The script reads credentials from `/Users/van/.codex/skills/confluence-docs/.env` by default and writes one Markdown file per page.
