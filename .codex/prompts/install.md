---
description: "Add a new installer to @install/ following the existing Ansible pattern, then run it"
argument-hint: "Describe what to install and how, e.g. 'could you install discord, with brew' or provide a URL"
---

Add an installer to `@install/` based on this request:

`$ARGUMENTS`

Follow this workflow exactly:

1. Parse the request and extract:
- the software name
- the installation method if specified (`brew`, `brew cask`, `npm`, `pip`, `cargo`, `from source`, `url`, etc.)
- any platform restriction (`macOS`, `Linux`, cross-platform)
- any installation URL or external instructions

2. Inspect the existing installation structure before editing:
- read `@install/main.yaml`
- inspect relevant existing roles in `@install/roles/`
- match the current repository pattern instead of inventing a new one

3. Implement the new installer in `@install/`:
- create or update the appropriate role under `@install/roles/<name>/`
- keep the structure consistent with neighboring roles
- if the install is macOS-only, gate it with the same Darwin checks already used in this repo
- if the request includes a URL, use it as the source of truth
- if the request is ambiguous but can be resolved from local patterns, make the reasonable choice and state it briefly
- only ask the user a question if the installation method is truly unclear and a wrong guess would likely create the wrong installer

4. Wire it into the playbook:
- add the role to `@install/main.yaml` in the right section
- preserve the current style and ordering conventions of the file

5. Validate before running:
- run a focused syntax check if possible
- prefer the narrowest useful validation for the change

6. Launch the installation at the end:
- run the relevant playbook command after the files are updated
- prefer a targeted execution when possible, but stay compatible with the current playbook structure
- report whether the requested installer ran successfully, and separately report any unrelated playbook failure

Implementation constraints:
- do not redesign the install system
- do not introduce a generic meta-installer unless the user explicitly asks for one
- prefer existing Ansible modules already used in this repo over custom shell logic
- keep changes minimal and idiomatic for this repository

Output expectations:
- first explain in one short sentence what installer pattern you found and are following
- then implement the change
- then run the installation
- finally summarize:
  - files changed
  - install method chosen
  - whether the requested installation actually ran
  - any unrelated failure encountered during playbook execution
