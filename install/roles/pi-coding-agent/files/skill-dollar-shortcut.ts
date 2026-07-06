// Use `$skill-name ...` as a shortcut for `/skill:skill-name ...`, with `$` autocomplete.
// Reload Pi with /reload after editing this file.

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import type { AutocompleteItem, AutocompleteProvider, AutocompleteSuggestions } from "@earendil-works/pi-tui";
import { fuzzyFilter } from "@earendil-works/pi-tui";

type SkillCommand = {
  commandName: string;
  skillName: string;
  description?: string;
};

const MAX_SUGGESTIONS = 20;

function skillNameFromCommand(commandName: string): string {
  return commandName.startsWith("skill:") ? commandName.slice("skill:".length) : commandName;
}

function getSkillCommands(pi: ExtensionAPI): SkillCommand[] {
  return pi
    .getCommands()
    .filter((command) => command.source === "skill")
    .map((command) => ({
      commandName: command.name,
      skillName: skillNameFromCommand(command.name),
      description: command.description,
    }))
    .sort((a, b) => a.skillName.localeCompare(b.skillName));
}

function findSkill(pi: ExtensionAPI, requested: string): SkillCommand | undefined {
  const normalized = skillNameFromCommand(requested.trim());
  return getSkillCommands(pi).find(
    (skill) => skill.skillName === normalized || skill.commandName === normalized || skill.commandName === `skill:${normalized}`,
  );
}

function extractDollarToken(textBeforeCursor: string): string | undefined {
  const match = textBeforeCursor.match(/(?:^|[ \t])\$([a-zA-Z0-9-]*)$/);
  return match?.[1];
}

function formatSkillItem(skill: SkillCommand): AutocompleteItem {
  return {
    value: `$${skill.skillName}`,
    label: `$${skill.skillName}`,
    description: skill.description,
  };
}

function filterSkills(skills: SkillCommand[], query: string): AutocompleteItem[] {
  if (!query.trim()) return skills.slice(0, MAX_SUGGESTIONS).map(formatSkillItem);

  return fuzzyFilter(skills, query, (skill) => `${skill.skillName} ${skill.description ?? ""}`)
    .slice(0, MAX_SUGGESTIONS)
    .map(formatSkillItem);
}

function createDollarSkillAutocompleteProvider(pi: ExtensionAPI, current: AutocompleteProvider): AutocompleteProvider {
  return {
    triggerCharacters: ["$"],

    async getSuggestions(lines, cursorLine, cursorCol, options): Promise<AutocompleteSuggestions | null> {
      const currentLine = lines[cursorLine] ?? "";
      const textBeforeCursor = currentLine.slice(0, cursorCol);
      const token = extractDollarToken(textBeforeCursor);
      if (token === undefined) return current.getSuggestions(lines, cursorLine, cursorCol, options);

      const suggestions = filterSkills(getSkillCommands(pi), token);
      if (options.signal.aborted || suggestions.length === 0) {
        return current.getSuggestions(lines, cursorLine, cursorCol, options);
      }

      return {
        prefix: `$${token}`,
        items: suggestions,
      };
    },

    applyCompletion(lines, cursorLine, cursorCol, item, prefix) {
      return current.applyCompletion(lines, cursorLine, cursorCol, item, prefix);
    },

    shouldTriggerFileCompletion(lines, cursorLine, cursorCol) {
      return current.shouldTriggerFileCompletion?.(lines, cursorLine, cursorCol) ?? true;
    },
  };
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    if (!ctx.hasUI) return;
    ctx.ui.addAutocompleteProvider((current) => createDollarSkillAutocompleteProvider(pi, current));
  });

  pi.on("input", async (event) => {
    const match = event.text.match(/^(\s*)\$([a-zA-Z0-9-]+)(?=\s|$)([\s\S]*)$/);
    if (!match) return { action: "continue" as const };

    const [, leading = "", requested = "", rest = ""] = match;
    const skill = findSkill(pi, requested);
    if (!skill) return { action: "continue" as const };

    return {
      action: "transform" as const,
      text: `${leading}/${skill.commandName}${rest}`,
      images: event.images,
    };
  });
}
