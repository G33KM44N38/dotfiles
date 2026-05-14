---
name: obsidian-cli
description: Use Obsidian from terminal for vault workflows and Neovim note navigation. Use when the user asks to open, create, search, or link Obsidian markdown notes from shell, or to run `obsidian://` URI actions.
---

# Obsidian CLI

Use this workflow to operate an Obsidian vault from terminal while editing in Neovim.

## Quick Check

1. Confirm command exists: `which obsidian`.
2. Confirm vault context: `pwd` and check `.obsidian/` directory.
3. Quote all note paths because vault paths often include spaces.

## Core Commands

1. Open app, note, or folder:
- `obsidian`
- `obsidian "/abs/path/to/note.md"`
- `obsidian "/abs/path/to/folder"`

2. Run Obsidian URI actions:
- `obsidian "obsidian://open?vault=<VaultName>&file=<EncodedPath>"`
- `obsidian "obsidian://new?vault=<VaultName>&name=<EncodedName>"`
- `obsidian "obsidian://search?vault=<VaultName>&query=<EncodedQuery>"`

3. Create note from terminal, then open in Obsidian:
- `note="My Note.md"`
- `printf "# %s\n\n" "${note%.md}" > "$note"`
- `obsidian "$PWD/$note"`

4. Find notes and wiki-links quickly:
- `rg --files -g '*.md'`
- `rg -n "<search text>" -g '*.md'`
- `rg -n "\\[\\[.*<term>.*\\]\\]" -g '*.md'`

## Neovim Workflow

1. Get current buffer absolute path inside Neovim:
- `:echo expand('%:p')`

2. Open that note in Obsidian from shell:
- `obsidian "<absolute-path>"`

3. Keep content edits in markdown files by default; avoid changing `.obsidian/` internals unless user requests config/plugin changes.

## Troubleshooting

1. If `obsidian` command missing:
- Reinstall wrapper at `~/.dotfiles/bin/obsidian`.
- Re-check `PATH` includes `~/bin` or `~/.dotfiles/bin`.

2. If user asks for official built-in Obsidian CLI subcommands:
- Require Obsidian `1.12+` early access and CLI enabled inside app settings.

## References

- For URI encoding patterns and ready-to-run examples, read `references/uri-patterns.md`.
