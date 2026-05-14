# Obsidian URI Patterns

Use these when launching actions via `obsidian "obsidian://..."`.

## Encode Helper

Encode dynamic values before inserting into query params:

```bash
encode() { jq -sRr @uri <<<"$1"; }
```

## Open Existing Note

```bash
vault="Second_Brain"
file_path="Daily/2026-02-27.md"
obsidian "obsidian://open?vault=$(encode "$vault")&file=$(encode "$file_path")"
```

## Create New Note

```bash
vault="Second_Brain"
note_name="Inbox/Quick capture"
obsidian "obsidian://new?vault=$(encode "$vault")&name=$(encode "$note_name")"
```

## Run Search

```bash
vault="Second_Brain"
query="tag:#todo project"
obsidian "obsidian://search?vault=$(encode "$vault")&query=$(encode "$query")"
```
