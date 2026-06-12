---
name: diagram-to-tmp
description: Create diagram artifacts in /tmp by default. Use when the user asks Codex to make, draw, visualize, map, or explain with a diagram, flowchart, architecture diagram, sequence diagram, state machine, process flow, dependency graph, or HTML/SVG/Mermaid visual, especially when they ask for a standalone page or artifact.
---

# Diagram To /tmp

## Rule

When creating a diagram artifact, write it under `/tmp` unless the user explicitly requests another path.

Prefer a standalone `.html` file for visual diagrams because it opens directly in the browser and can combine layout, styling, SVG, Mermaid text, and explanatory notes in one artifact.

## Workflow

1. Choose a clear filename in `/tmp`, such as `/tmp/<topic>-diagram.html`.
2. Create the artifact directly in `/tmp`.
3. Make it self-contained: inline CSS and avoid build steps or external package dependencies.
4. Use readable, responsive layout and accessible contrast.
5. Include enough labels that the diagram stands alone without requiring the chat transcript.
6. Validate the file exists and, for HTML, run a basic syntax/sanity check when practical.
7. Return the absolute path as a clickable local file link.

## Diagram Defaults

- Use flowcharts for processes, control flow, cache behavior, request lifecycles, and user journeys.
- Use sequence diagrams for actor-to-actor message ordering.
- Use architecture diagrams for systems, services, files, and dependencies.
- Use state diagrams for finite states, modes, and transitions.
- Use tables or legends beside the diagram when they clarify symbols or tradeoffs.

## Constraints

- Do not put generated diagram artifacts in the repository unless the user explicitly asks for a repo file.
- Do not start a dev server for a standalone HTML diagram.
- Do not require the user to copy or save content manually.
- Keep the final response short: path, format, and any important caveat.
