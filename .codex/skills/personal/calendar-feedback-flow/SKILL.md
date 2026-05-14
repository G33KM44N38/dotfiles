---
name: calendar-feedback-flow
description: Turn calendar event feedback into concrete Obsidian note updates. Use when a user asks to inspect a calendar lesson, extract the feedback or notes from the event, and apply that feedback to a matching planning note or learning resource.
---

# Calendar Feedback Flow

## Overview

Use this skill when a calendar event contains feedback, a lesson note, or a learning plan that should be reflected in Obsidian. The goal is to turn event feedback into a concrete action: update the matching note, tighten the lesson wording, and replace vague resources with something more usable.

## Workflow

1. Identify the exact event.
- Capture the event title, calendar, date, and any notes or feedback attached to it.
- If multiple similar events exist, choose the one that matches the title and topic most closely.
- If you need the raw event payload fast, use `scripts/fetch_calendar_feedback.swift <query>` to print the matching event(s) as JSON.
- If the calendar event itself should be revised, use `scripts/update_calendar_feedback.swift <query> --append-text "<block>"` to add a clean follow-up note without deleting the original text.

2. Extract the useful feedback.
- Separate the lesson focus from the user's commentary.
- Keep the user's wording when it reveals intent, friction, or uncertainty.
- Ignore filler; retain only actionable constraints, goals, and resource hints.
- If the user says the lesson is not executable, treat that as a resource-design failure, not a wording issue.

3. Map feedback to the planning note.
- Find the matching Obsidian note by topic.
- Update the lesson line or section so it reflects what the event actually says.
- Keep the existing note structure unless the feedback clearly requires a rewrite.
- The final plan must be executable without guessing the source material.

4. Write back to the calendar event when useful.
- Add a short follow-up block to the original event notes when the feedback needs to be preserved there too.
- Keep the block concise and structured, for example: what changed, which sources were chosen, and what the next execution step is.
- Never overwrite the original notes unless the user explicitly asks for that.

5. Improve the resource when the current one is too vague.
- If the event says the lesson is unclear or hard to apply, replace broad resources with something concrete and task-specific.
- Prefer resources that are directly executable: a specific lesson page, a bounded course module, a PDF worksheet, or a vocab list with audio.
- Avoid homepage links, generic hubs, or resources that do not expose the actual items to study.
- Do not invent a count, chapter, or set of words unless the source explicitly provides it.
- If a chosen source cannot supply the needed items, switch to a different resource instead of papering over the gap.

6. Report the result succinctly.
- State what event was used.
- State what changed in the note.
- State what new resource or framing was added, if any.
- Mention when the calendar event itself was updated.
- If no safe update is possible, say what is missing instead of guessing.

## Editing Rules

- Preserve the user's note style and formatting.
- Use exact event details when available.
- Do not invent lesson context that is not present in the event notes.
- Keep the update minimal when the note already has a clear structure.
- When a resource is replaced, explain the replacement in plain language, not marketing language.

## Good Fit Examples

- A calendar lesson says "Reading simple words" but the resource is too broad, so update the planning note with a tighter reading exercise and a better reference.
- A lesson uses an Anki deck as a fake source of words; replace it with a concrete course lesson or vocab page the user can actually open and execute.
- A calendar note includes feedback like "I don't know how to use it," so rewrite the lesson as a practical checklist instead of a generic reminder.
- A user wants the calendar lesson translated into an Obsidian plan item that can actually be followed later.

## Helper Script

Use `scripts/fetch_calendar_feedback.swift` when the event lives in Apple Calendar and you want a fast export of the matching lesson notes.
Use `scripts/update_calendar_feedback.swift` when you also want to write the cleaned feedback back into the event notes.

Example:

```bash
/Users/boss/.dotfiles/.codex/skills/calendar-feedback-flow/scripts/fetch_calendar_feedback.swift "Thai learning"
```

Example:

```bash
/Users/boss/.dotfiles/.codex/skills/calendar-feedback-flow/scripts/update_calendar_feedback.swift --calendar Perso "Thai learning" --append-text "Feedback applied: source words are now linked directly in Obsidian, with pronunciation and review steps made explicit."
```

## Output Shape

When using this skill, return:

- the event title and date
- the exact feedback that mattered
- the note updated
- the resource chosen or replaced
- any remaining uncertainty
