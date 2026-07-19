import type {
  Binding,
  DeviceManifest,
  DeviceProfile,
  KeyId,
  LayerId,
  ManifestEntry,
  ModifierId,
  SystemAction,
} from "./domain.js";

const karabinerModifiers: Record<ModifierId, string> = {
  leftGui: "left_gui", leftAlt: "left_option", leftShift: "left_shift",
  leftControl: "left_control", rightControl: "right_control",
  rightShift: "right_shift", rightAlt: "right_option", rightGui: "right_gui",
};

const simpleKeys: Partial<Record<KeyId, string>> = {
  a: "a", b: "b", c: "c", d: "d", e: "e", f: "f", g: "g", h: "h",
  i: "i", j: "j", k: "k", l: "l", m: "m", n: "n", o: "o", p: "p",
  q: "q", r: "r", s: "s", t: "t", u: "u", v: "v", w: "w", x: "x",
  y: "y", z: "z", digit0: "0", digit1: "1", digit2: "2", digit3: "3",
  digit4: "4", digit5: "5", digit6: "6", digit7: "7", digit8: "8",
  digit9: "9", backspace: "delete_or_backspace", enter: "return_or_enter",
  space: "spacebar", tab: "tab", semicolon: "semicolon", quote: "quote",
  comma: "comma", dot: "period", slash: "slash", backslash: "backslash",
  grave: "grave_accent_and_tilde", minus: "hyphen", equals: "equal_sign",
  leftBracket: "open_bracket", rightBracket: "close_bracket", left: "left_arrow",
  down: "down_arrow", up: "up_arrow", right: "right_arrow", f1: "f1", f2: "f2",
  f3: "f3", f4: "f4", f5: "f5", f6: "f6", f7: "f7", f8: "f8", f9: "f9",
  f10: "f10", f14: "f14", f15: "f15", f16: "f16", f17: "f17",
  f21: "f21", f22: "f22",
};

function keyCommand(key: KeyId, layer: LayerId): string {
  if (layer === "numbers") {
    if (key === "minus") return `{ to: [{ key_code: "keypad_hyphen" }] }`;
    if (key === "plus") return `{ to: [{ key_code: "keypad_plus" }] }`;
    if (key === "equals") return `{ to: [{ key_code: "keypad_equal_sign" }] }`;
  }
  const shifted: Partial<Record<KeyId, string>> = {
    tilde: "grave_accent_and_tilde", underscore: "hyphen", pipe: "backslash",
    leftBrace: "open_bracket", rightBrace: "close_bracket",
    leftParen: "9", rightParen: "0", plus: "equal_sign",
  };
  const shiftedKey = shifted[key];
  if (shiftedKey !== undefined) {
    return `{ to: [{ key_code: "${shiftedKey}", modifiers: ["left_shift"] }] }`;
  }
  const keyCode = simpleKeys[key];
  if (keyCode === undefined) throw new Error(`No Karabiner key for ${key}`);
  return `{ to: [{ key_code: "${keyCode}" }] }`;
}

function systemCommand(action: SystemAction): string {
  switch (action) {
    case "brightnessDown": return `{ to: [{ key_code: "display_brightness_decrement" }] }`;
    case "brightnessUp": return `{ to: [{ key_code: "display_brightness_increment" }] }`;
    case "volumeDown": return `{ to: [{ key_code: "volume_decrement" }] }`;
    case "volumeUp": return `{ to: [{ key_code: "volume_increment" }] }`;
    case "mute": return `{ to: [{ key_code: "mute" }] }`;
    case "lockScreen": return `{ to: [{ key_code: "q", modifiers: ["right_control", "right_command"] }] }`;
    case "home": return `app("Home")`;
    case "toggleAppearance": return `open("raycast://extensions/raycast/system/toggle-system-appearance")`;
    case "controlCenter": return `{ to: [{ key_code: "c", modifiers: ["fn"] }] }`;
    case "notificationCenter": return `{ to: [{ key_code: "n", modifiers: ["fn"] }] }`;
  }
}

function layerCommand(entry: ManifestEntry): string | undefined {
  const binding = entry.binding;
  if (binding.kind !== "emit") return undefined;
  if (binding.intent.kind === "transparent" || binding.intent.kind === "disabled") return undefined;
  if (binding.intent.kind === "key") return keyCommand(binding.intent.key, entry.layer);
  if (binding.intent.kind === "system") return systemCommand(binding.intent.action);
  return undefined;
}

function renderLayer(manifest: DeviceManifest, layer: LayerId, exportName: string): string {
  const entries = manifest.entries
    .filter((entry) => entry.layer === layer)
    .flatMap((entry) => {
      const command = layerCommand(entry);
      return command === undefined ? [] : [[entry.input.label, command] as const];
    })
    .sort(([left], [right]) => left.localeCompare(right));
  return `export const ${exportName} = {\n${entries
    .map(([key, command]) => `  ${JSON.stringify(key)}: ${command},`)
    .join("\n")}\n} satisfies Partial<Record<KeyCode, LayerCommand>>;`;
}

function modTaps(manifest: DeviceManifest) {
  return manifest.entries
    .filter((entry) => entry.layer === "base")
    .flatMap((entry) => {
      const binding: Binding = entry.binding;
      if (binding.kind !== "tapHold" || binding.hold.kind !== "modifier") return [];
      if (binding.tap.kind !== "key") return [];
      const tap = simpleKeys[binding.tap.key];
      if (tap === undefined) throw new Error(`No Karabiner tap key for ${binding.tap.key}`);
      const timing = entry.timing;
      if (timing === undefined) throw new Error(`Missing timing for ${entry.position}`);
      return [{
        input: entry.input.label,
        tap,
        modifier: karabinerModifiers[binding.hold.modifier],
        timing: {
          toIfHeldDownThresholdMilliseconds: timing.tappingTermMs,
          toIfAloneTimeoutMilliseconds: timing.aloneTimeoutMs ?? timing.tappingTermMs,
        },
      }];
    });
}

function renderedLayerTriggers(profile: DeviceProfile) {
  return Object.fromEntries(
    Object.entries(profile.layerTriggers)
      .filter(([layer]) => layer !== "system")
      .map(([layer, trigger]) => {
        if (trigger === undefined) return [layer, trigger];
        const tap = trigger.tap === undefined ? undefined : simpleKeys[trigger.tap];
        if (trigger.tap !== undefined && tap === undefined) {
          throw new Error(`No Karabiner trigger tap key for ${trigger.tap}`);
        }
        return [layer, {
          input: trigger.input,
          mode: trigger.mode,
          ...(tap === undefined ? {} : { tap }),
        }];
      }),
  );
}

function bridgeRule(key: KeyId, action: SystemAction): string {
  const keyCode = simpleKeys[key];
  if (keyCode === undefined) throw new Error(`Invalid bridge key ${key}`);
  return `  {
    description: "Keyboard bridge ${keyCode} -> ${action}",
    manipulators: [{
      ...${systemCommand(action)},
      type: "basic",
      from: { key_code: "${keyCode}", modifiers: { optional: ["any"] } },
    }],
  },`;
}

export function renderKarabiner(
  manifest: DeviceManifest,
  profile: DeviceProfile,
  bridgeKeys: Readonly<Partial<Record<SystemAction, KeyId>>>,
): string {
  const mods = modTaps(manifest);
  const triggers = renderedLayerTriggers(profile);
  const bridges = Object.entries(bridgeKeys) as [SystemAction, KeyId][];
  return `/* Generated by keyboard-layout (${manifest.layoutDigest}). Do not edit. */
import type { KarabinerRules, KeyCode } from "../types";
import { app, open, type LayerCommand } from "../utils";

export const sharedHomeRowTiming = ${JSON.stringify({
    toIfHeldDownThresholdMilliseconds: profile.timings.homeRow.tappingTermMs,
    toIfAloneTimeoutMilliseconds: profile.timings.homeRow.aloneTimeoutMs,
  }, null, 2)} as const;

export const sharedHomeRowMods = ${JSON.stringify(mods, null, 2)} as const;

export const sharedLayerTriggers = ${JSON.stringify(triggers, null, 2)} as const;

${renderLayer(manifest, "numbers", "sharedNumbersLayer")}

${renderLayer(manifest, "symbols", "sharedSymbolsLayer")}

${renderLayer(manifest, "system", "sharedSystemLayer")}

${renderLayer(manifest, "functions", "sharedFunctionLayer")}

export const sharedHostBridgeRules: KarabinerRules[] = [
${bridges.map(([action, key]) => bridgeRule(key, action)).join("\n")}
];
`;
}
