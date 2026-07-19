import {
  layerIds,
  type Binding,
  type Capability,
  type DeviceManifest,
  type DeviceProfile,
  type Intent,
  type KeyId,
  type LayerId,
  type ManifestEntry,
  type ModifierId,
  type SystemAction,
  type TapHoldTiming,
} from "./domain.js";

const qmkKeys: Record<KeyId, string> = {
  a: "KC_A", b: "KC_B", c: "KC_C", d: "KC_D", e: "KC_E", f: "KC_F",
  g: "KC_G", h: "KC_H", i: "KC_I", j: "KC_J", k: "KC_K", l: "KC_L",
  m: "KC_M", n: "KC_N", o: "KC_O", p: "KC_P", q: "KC_Q", r: "KC_R",
  s: "KC_S", t: "KC_T", u: "KC_U", v: "KC_V", w: "KC_W", x: "KC_X",
  y: "KC_Y", z: "KC_Z", digit0: "KC_0", digit1: "KC_1", digit2: "KC_2",
  digit3: "KC_3", digit4: "KC_4", digit5: "KC_5", digit6: "KC_6",
  digit7: "KC_7", digit8: "KC_8", digit9: "KC_9", backspace: "KC_BSPC",
  enter: "KC_ENT", space: "KC_SPC", tab: "KC_TAB", semicolon: "KC_SCLN",
  quote: "KC_QUOT", comma: "KC_COMM", dot: "KC_DOT", slash: "KC_SLSH",
  backslash: "KC_BSLS", tilde: "KC_TILD", grave: "KC_GRV", minus: "KC_MINS",
  underscore: "KC_UNDS", plus: "KC_PLUS", equals: "KC_EQL", pipe: "KC_PIPE",
  leftBracket: "KC_LBRC", rightBracket: "KC_RBRC", leftBrace: "KC_LCBR",
  rightBrace: "KC_RCBR", leftParen: "KC_LPRN", rightParen: "KC_RPRN",
  left: "KC_LEFT", down: "KC_DOWN", up: "KC_UP", right: "KC_RGHT",
  f1: "KC_F1", f2: "KC_F2", f3: "KC_F3", f4: "KC_F4", f5: "KC_F5",
  f6: "KC_F6", f7: "KC_F7", f8: "KC_F8", f9: "KC_F9", f10: "KC_F10",
  f14: "KC_F14", f15: "KC_F15", f16: "KC_F16", f17: "KC_F17",
  f21: "KC_F21", f22: "KC_F22",
};

const zmkKeys: Record<KeyId, string> = {
  a: "A", b: "B", c: "C", d: "D", e: "E", f: "F", g: "G", h: "H",
  i: "I", j: "J", k: "K", l: "L", m: "M", n: "N", o: "O", p: "P",
  q: "Q", r: "R", s: "S", t: "T", u: "U", v: "V", w: "W", x: "X",
  y: "Y", z: "Z", digit0: "NUMBER_0", digit1: "NUMBER_1", digit2: "NUMBER_2",
  digit3: "NUMBER_3", digit4: "NUMBER_4", digit5: "NUMBER_5",
  digit6: "NUMBER_6", digit7: "NUMBER_7", digit8: "NUMBER_8",
  digit9: "NUMBER_9", backspace: "BACKSPACE", enter: "ENTER", space: "SPACE",
  tab: "TAB", semicolon: "SEMICOLON", quote: "SINGLE_QUOTE", comma: "COMMA",
  dot: "DOT", slash: "FSLH", backslash: "BACKSLASH", tilde: "TILDE",
  grave: "GRAVE", minus: "MINUS", underscore: "UNDER", plus: "PLUS",
  equals: "EQUAL", pipe: "PIPE", leftBracket: "LEFT_BRACKET",
  rightBracket: "RIGHT_BRACKET", leftBrace: "LEFT_BRACE", rightBrace: "RIGHT_BRACE",
  leftParen: "LEFT_PARENTHESIS", rightParen: "RIGHT_PARENTHESIS", left: "LEFT",
  down: "DOWN", up: "UP_ARROW", right: "RIGHT", f1: "F1", f2: "F2", f3: "F3",
  f4: "F4", f5: "F5", f6: "F6", f7: "F7", f8: "F8", f9: "F9", f10: "F10",
  f14: "F14", f15: "F15", f16: "F16", f17: "F17", f21: "F21", f22: "F22",
};

const qmkModifiers: Record<ModifierId, string> = {
  leftGui: "LGUI", leftAlt: "LALT", leftShift: "LSFT", leftControl: "LCTL",
  rightControl: "RCTL", rightShift: "RSFT", rightAlt: "RALT", rightGui: "RGUI",
};

const zmkModifiers: Record<ModifierId, string> = {
  leftGui: "LGUI", leftAlt: "LALT", leftShift: "LSHIFT", leftControl: "LCTRL",
  rightControl: "RCTRL", rightShift: "RSHIFT", rightAlt: "RALT", rightGui: "RGUI",
};

const qmkNativeSystem: Record<SystemAction, string | undefined> = {
  brightnessDown: "KC_BRID", brightnessUp: "KC_BRIU", controlCenter: undefined,
  home: undefined, lockScreen: "LCTL(LGUI(KC_Q))", mute: "KC_MUTE",
  notificationCenter: undefined, toggleAppearance: undefined,
  volumeDown: "KC_VOLD", volumeUp: "KC_VOLU",
};

const zmkNativeSystem: Record<SystemAction, string | undefined> = {
  brightnessDown: "&kp C_BRIGHTNESS_DEC", brightnessUp: "&kp C_BRI_UP",
  controlCenter: undefined, home: undefined, lockScreen: "&kp LC(LG(Q))",
  mute: "&kp C_MUTE", notificationCenter: undefined, toggleAppearance: undefined,
  volumeDown: "&kp C_VOL_DN", volumeUp: "&kp C_VOLUME_UP",
};

const qmkLayerNames: Record<LayerId, string> = {
  base: "BASE", numbers: "NUMBERS", symbols: "SYMBOLS",
  system: "SYSTEM", functions: "FUNCTIONS",
};

const zmkLayerNumbers: Record<LayerId, number> = {
  base: 0, numbers: 1, symbols: 2, system: 3, functions: 4,
};

const zmkLayerNames: Record<LayerId, string> = {
  base: "base", numbers: "layer_1", symbols: "layer_2",
  system: "layer_3", functions: "layer_4",
};

function systemCapability(entry: ManifestEntry): Capability {
  if (entry.capability === undefined) {
    throw new Error(`Missing capability for ${entry.layer}.${entry.position}`);
  }
  return entry.capability;
}

function renderQmkSystem(entry: ManifestEntry, action: SystemAction): string {
  const capability = systemCapability(entry);
  if (capability.route === "hostBridge") return qmkKeys[capability.key];
  if (capability.route === "native") return qmkNativeSystem[action] ?? "KC_NO";
  return "KC_NO";
}

function renderZmkSystem(entry: ManifestEntry, action: SystemAction): string {
  const capability = systemCapability(entry);
  if (capability.route === "hostBridge") return `&kp ${zmkKeys[capability.key]}`;
  if (capability.route === "native") return zmkNativeSystem[action] ?? "&none";
  return "&none";
}

function renderQmkIntent(entry: ManifestEntry, intent: Intent): string {
  switch (intent.kind) {
    case "key": return qmkKeys[intent.key];
    case "modifier": return `KC_${qmkModifiers[intent.modifier]}`;
    case "layer": return `MO(${qmkLayerNames[intent.layer]})`;
    case "system": return renderQmkSystem(entry, intent.action);
    case "hyper": return "KC_F24";
    case "transparent": return "KC_TRNS";
    case "disabled": return "KC_NO";
  }
}

function renderZmkIntent(entry: ManifestEntry, intent: Intent): string {
  switch (intent.kind) {
    case "key": return `&kp ${zmkKeys[intent.key]}`;
    case "modifier": return `&kp ${zmkModifiers[intent.modifier]}`;
    case "layer": return `&mo ${zmkLayerNumbers[intent.layer]}`;
    case "system": return renderZmkSystem(entry, intent.action);
    case "hyper": return "&shared_hyper";
    case "transparent": return "&trans";
    case "disabled": return "&none";
  }
}

function renderQmkBinding(entry: ManifestEntry): string {
  const binding = entry.binding;
  if (binding.kind === "emit") return renderQmkIntent(entry, binding.intent);
  if (binding.tap.kind !== "key") return "KC_NO";
  if (binding.hold.kind === "layer") {
    return `LT(${qmkLayerNames[binding.hold.layer]}, ${qmkKeys[binding.tap.key]})`;
  }
  if (binding.hold.kind === "modifier") {
    return `${qmkModifiers[binding.hold.modifier]}_T(${qmkKeys[binding.tap.key]})`;
  }
  return "KC_NO";
}

function renderZmkBinding(entry: ManifestEntry): string {
  const binding = entry.binding;
  if (binding.kind === "emit") return renderZmkIntent(entry, binding.intent);
  if (binding.tap.kind !== "key") return "&none";
  if (binding.hold.kind === "layer") {
    return `&shared_lt ${zmkLayerNumbers[binding.hold.layer]} ${zmkKeys[binding.tap.key]}`;
  }
  if (binding.hold.kind === "modifier") {
    const behavior = binding.timing === "shiftTab" ? "shared_st" : "shared_hm";
    return `&${behavior} ${zmkModifiers[binding.hold.modifier]} ${zmkKeys[binding.tap.key]}`;
  }
  return "&none";
}

function layerSlots(
  manifest: DeviceManifest,
  layer: LayerId,
  renderer: (entry: ManifestEntry) => string,
  transparent: string,
): string[] {
  const slots = Array<string>(42).fill(transparent);
  for (const entry of manifest.entries.filter((candidate) => candidate.layer === layer)) {
    if (entry.input.slot === undefined) continue;
    slots[entry.input.slot] = renderer(entry);
  }
  return slots;
}

function applyExtras(slots: string[], extras: Readonly<Record<number, string>>): string[] {
  const result = [...slots];
  for (const [slot, value] of Object.entries(extras)) result[Number(slot)] = value;
  return result;
}

function qmkLayer(name: string, slots: readonly string[]): string {
  const rows = [slots.slice(0, 12), slots.slice(12, 24), slots.slice(24, 36)];
  const thumbs = slots.slice(36, 42);
  return `    [${name}] = LAYOUT_split_3x6_3(\n${rows
    .map((row) => `        ${row.join(", ")},`)
    .join("\n")}\n        ${thumbs.join(", ")}\n    )`;
}

function zmkLayer(name: string, displayName: string, slots: readonly string[]): string {
  const rows = [slots.slice(0, 12), slots.slice(12, 24), slots.slice(24, 36), slots.slice(36, 42)];
  return `        ${name} {\n            display-name = "${displayName}";\n            bindings = <\n${rows
    .map((row) => `                ${row.join("  ")}`)
    .join("\n")}\n            >;\n        };`;
}

const qmkExtras: Partial<Record<LayerId, Record<number, string>>> = {
  base: { 0: "TO(GAMING)", 11: "LGUI(KC_SPC)", 12: "KC_ESC", 23: "KC_QUOT", 35: "KC_NO" },
  system: { 0: "QK_BOOT", 11: "QK_BOOT" },
  functions: { 7: "KC_F21", 8: "KC_F22" },
};

const zmkExtras: Partial<Record<LayerId, Record<number, string>>> = {
  base: { 0: "&to 5", 11: "&kp LG(SPACE)", 12: "&kp ESCAPE", 23: "&kp SINGLE_QUOTE", 35: "&none" },
  system: { 0: "&bootloader", 11: "&bootloader" },
  functions: {
    7: "&pwd", 8: "&pwd2", 30: "&bt BT_SEL 0", 31: "&bt BT_SEL 1",
    32: "&bt BT_SEL 2", 33: "&bt BT_SEL 3", 34: "&bt BT_SEL 4", 35: "&bt BT_CLR",
  },
};

const qmkGaming = [
  "TO(BASE)", "KC_Q", "KC_W", "KC_E", "KC_R", "KC_T", "KC_Y", "KC_U", "KC_I", "KC_O", "KC_P", "TO(BASE)",
  "KC_ESC", "KC_A", "KC_S", "KC_D", "KC_F", "KC_G", "KC_H", "KC_J", "KC_K", "KC_L", "KC_SCLN", "KC_QUOT",
  "KC_LSFT", "KC_Z", "KC_X", "KC_C", "KC_V", "KC_B", "KC_N", "KC_M", "KC_COMM", "KC_DOT", "KC_SLSH", "KC_NO",
  "MO(GAMING_FUNCTIONS)", "KC_SPC", "MO(GAMING_NUMBERS)", "KC_SPC", "KC_TAB", "KC_F24",
];

const qmkGamingFunctions = [
  "KC_TRNS", "KC_F1", "KC_F2", "KC_F3", "KC_F4", "KC_F5", "KC_TRNS", "KC_TRNS", "KC_TRNS", "KC_TRNS", "KC_TRNS", "TO(BASE)",
  "KC_TRNS", "KC_F6", "KC_F7", "KC_F8", "KC_F9", "KC_F10", "KC_TRNS", "KC_TRNS", "KC_TRNS", "KC_TRNS", "KC_TRNS", "KC_TRNS",
  "KC_TRNS", "KC_F11", "KC_F12", "KC_TRNS", "KC_TRNS", "KC_TRNS", "KC_TRNS", "KC_TRNS", "KC_TRNS", "KC_TRNS", "KC_TRNS", "KC_TRNS",
  "KC_TRNS", "KC_TRNS", "KC_TRNS", "KC_TRNS", "KC_TRNS", "KC_TRNS",
];

const qmkGamingNumbers = [
  "KC_TRNS", "KC_1", "KC_2", "KC_3", "KC_4", "KC_5", "KC_TRNS", "KC_TRNS", "KC_TRNS", "KC_TRNS", "KC_TRNS", "TO(BASE)",
  "KC_TRNS", "KC_6", "KC_7", "KC_8", "KC_9", "KC_0", "KC_TRNS", "KC_TRNS", "KC_TRNS", "KC_TRNS", "KC_TRNS", "KC_TRNS",
  "KC_TRNS", "KC_TRNS", "KC_TRNS", "KC_TRNS", "KC_TRNS", "KC_TRNS", "KC_TRNS", "KC_TRNS", "KC_TRNS", "KC_TRNS", "KC_TRNS", "KC_TRNS",
  "KC_TRNS", "KC_TRNS", "KC_TRNS", "KC_TRNS", "KC_TRNS", "KC_TRNS",
];

const zmkGaming = qmkGaming.map((token) => ({
  "TO(BASE)": "&to 0", KC_Q: "&kp Q", KC_W: "&kp W", KC_E: "&kp E", KC_R: "&kp R",
  KC_T: "&kp T", KC_Y: "&kp Y", KC_U: "&kp U", KC_I: "&kp I", KC_O: "&kp O",
  KC_P: "&kp P", KC_ESC: "&kp ESCAPE", KC_A: "&kp A", KC_S: "&kp S", KC_D: "&kp D",
  KC_F: "&kp F", KC_G: "&kp G", KC_H: "&kp H", KC_J: "&kp J", KC_K: "&kp K",
  KC_L: "&kp L", KC_SCLN: "&kp SEMICOLON", KC_QUOT: "&kp SINGLE_QUOTE",
  KC_LSFT: "&kp LSHIFT", KC_Z: "&kp Z", KC_X: "&kp X", KC_C: "&kp C", KC_V: "&kp V",
  KC_B: "&kp B", KC_N: "&kp N", KC_M: "&kp M", KC_COMM: "&kp COMMA", KC_DOT: "&kp DOT",
  KC_SLSH: "&kp FSLH", KC_NO: "&none", "MO(GAMING_FUNCTIONS)": "&mo 6", KC_SPC: "&kp SPACE",
  "MO(GAMING_NUMBERS)": "&mo 7", KC_TAB: "&kp TAB", KC_F24: "&shared_hyper",
} satisfies Record<string, string>)[token] ?? "&trans");

const zmkGamingFunctions = qmkGamingFunctions.map((token) => {
  if (token === "TO(BASE)") return "&to 0";
  if (token === "KC_TRNS") return "&trans";
  return `&kp ${token.replace("KC_", "")}`;
});

const zmkGamingNumbers = qmkGamingNumbers.map((token) => {
  if (token === "TO(BASE)") return "&to 0";
  if (token === "KC_TRNS") return "&trans";
  return `&kp ${token.replace("KC_", "NUMBER_")}`;
});

function assertLayerSize(name: string, slots: readonly string[]): void {
  if (slots.length !== 42) throw new Error(`${name} has ${slots.length} slots instead of 42`);
}

function modifierTapEntries(manifest: DeviceManifest): ManifestEntry[] {
  return manifest.entries.filter((entry) =>
    entry.layer === "base"
    && entry.binding.kind === "tapHold"
    && entry.binding.tap.kind === "key"
    && entry.binding.hold.kind === "modifier"
  );
}

function qmkHyperPlainKeySupport(manifest: DeviceManifest): string {
  const dualRoleKeys = modifierTapEntries(manifest);
  if (dualRoleKeys.length > 16) {
    throw new Error(`QMK Hyper bridge supports at most 16 dual-role keys, got ${dualRoleKeys.length}`);
  }

  const cases = dualRoleKeys.map((entry, index) => {
    const binding = entry.binding;
    if (binding.kind !== "tapHold" || binding.tap.kind !== "key" || binding.hold.kind !== "modifier") {
      throw new Error(`Expected a modifier tap-hold at ${entry.position}`);
    }
    const modTap = `${qmkModifiers[binding.hold.modifier]}_T(${qmkKeys[binding.tap.key]})`;
    return `        case ${modTap}: plain_key = ${qmkKeys[binding.tap.key]}; plain_mask = (1u << ${index}); break;`;
  });

  return `static bool hyper_bridge_active = false;
static uint16_t hyper_plain_keys = 0;

bool process_record_user(uint16_t keycode, keyrecord_t *record) {
    if (keycode == KC_F24) {
        hyper_bridge_active = record->event.pressed;
        return true;
    }

    uint16_t plain_key = KC_NO;
    uint16_t plain_mask = 0;
    switch (keycode) {
${cases.join("\n")}
        default: return true;
    }

    if (record->event.pressed) {
        if (!hyper_bridge_active) return true;
        hyper_plain_keys |= plain_mask;
        register_code16(plain_key);
        return false;
    }
    if ((hyper_plain_keys & plain_mask) != 0) {
        hyper_plain_keys &= ~plain_mask;
        unregister_code16(plain_key);
        return false;
    }
    return true;
}`;
}

const zmkHyperPlainLayerNumber = layerIds.length + 3;

function zmkHyperPlainLayer(manifest: DeviceManifest): string {
  const slots = Array<string>(42).fill("&trans");
  for (const entry of modifierTapEntries(manifest)) {
    if (entry.input.slot === undefined) continue;
    const binding = entry.binding;
    if (binding.kind !== "tapHold" || binding.tap.kind !== "key") {
      throw new Error(`Expected a modifier tap-hold at ${entry.position}`);
    }
    slots[entry.input.slot] = `&kp ${zmkKeys[binding.tap.key]}`;
  }
  assertLayerSize("hyper_plain", slots);
  return zmkLayer("hyper_plain", "Hyper Plain", slots);
}

export function renderQmk(manifest: DeviceManifest, profile: DeviceProfile): string {
  const sharedLayers = layerIds.map((layer) => {
    const slots = applyExtras(
      layerSlots(manifest, layer, renderQmkBinding, "KC_TRNS"),
      qmkExtras[layer] ?? {},
    );
    assertLayerSize(layer, slots);
    return qmkLayer(qmkLayerNames[layer], slots);
  });
  for (const [name, slots] of [["GAMING", qmkGaming], ["GAMING_FUNCTIONS", qmkGamingFunctions], ["GAMING_NUMBERS", qmkGamingNumbers]] as const) {
    assertLayerSize(name, slots);
  }
  const thumbTerm = profile.timings.thumbLayer.tappingTermMs;
  const homeTerm = profile.timings.homeRow.tappingTermMs;
  return `/* Generated by keyboard-layout (${manifest.layoutDigest}). Do not edit. */
#include QMK_KEYBOARD_H

enum layers { BASE, NUMBERS, SYMBOLS, SYSTEM, FUNCTIONS, GAMING, GAMING_FUNCTIONS, GAMING_NUMBERS };

const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
${[...sharedLayers, qmkLayer("GAMING", qmkGaming), qmkLayer("GAMING_FUNCTIONS", qmkGamingFunctions), qmkLayer("GAMING_NUMBERS", qmkGamingNumbers)].join(",\n\n")}
};

uint16_t get_tapping_term(uint16_t keycode, keyrecord_t *record) {
    (void)record;
    switch (keycode) {
        case LT(NUMBERS, KC_ENT):
        case LT(SYSTEM, KC_BSPC):
        case LT(SYMBOLS, KC_SPC):
            return ${thumbTerm};
        default:
            return ${homeTerm};
    }
}

bool get_permissive_hold(uint16_t keycode, keyrecord_t *record) {
    (void)record;
    switch (keycode) {
        case LGUI_T(KC_A): case LALT_T(KC_S): case LSFT_T(KC_D): case LCTL_T(KC_F):
        case RCTL_T(KC_J): case RSFT_T(KC_K): case RALT_T(KC_L): case RGUI_T(KC_SCLN):
        case RSFT_T(KC_TAB):
            return true;
        default:
            return false;
    }
}

${qmkHyperPlainKeySupport(manifest)}
`;
}

function zmkTiming(name: string, timing: TapHoldTiming, bindings: string): string {
  const flavor = timing.flavor === "tapPreferred" ? "tap-preferred" : timing.flavor;
  const quickTap = timing.quickTapMs === undefined ? "" : `\n            quick-tap-ms = <${timing.quickTapMs}>;`;
  return `        ${name}: ${name} {
            compatible = "zmk,behavior-hold-tap";
            #binding-cells = <2>;
            tapping-term-ms = <${timing.tappingTermMs}>;${quickTap}
            flavor = "${flavor}";
            bindings = <${bindings}>;
        };`;
}

export function renderZmk(manifest: DeviceManifest, profile: DeviceProfile): string {
  const sharedLayers = layerIds.map((layer) => {
    const slots = applyExtras(
      layerSlots(manifest, layer, renderZmkBinding, "&trans"),
      zmkExtras[layer] ?? {},
    );
    assertLayerSize(layer, slots);
    const display = `${layer.charAt(0).toUpperCase()}${layer.slice(1)}`;
    return zmkLayer(zmkLayerNames[layer], display, slots);
  });
  for (const [name, slots] of [["gaming", zmkGaming], ["gaming_functions", zmkGamingFunctions], ["gaming_numbers", zmkGamingNumbers]] as const) {
    assertLayerSize(name, slots);
  }
  return `/* Generated by keyboard-layout (${manifest.layoutDigest}). Do not edit. */
/ {
    behaviors {
${zmkTiming("shared_hm", profile.timings.homeRow, "&kp>, <&kp")}
${zmkTiming("shared_lt", profile.timings.thumbLayer, "&mo>, <&kp")}
${zmkTiming("shared_st", profile.timings.shiftTab, "&kp>, <&kp")}
    };

    macros {
        shared_hyper: shared_hyper {
            compatible = "zmk,behavior-macro";
            #binding-cells = <0>;
            wait-ms = <0>;
            tap-ms = <0>;
            bindings
                = <&macro_press &kp F24 &mo ${zmkHyperPlainLayerNumber}>
                , <&macro_pause_for_release>
                , <&macro_release &mo ${zmkHyperPlainLayerNumber} &kp F24>
                ;
        };
    };

    keymap {
        compatible = "zmk,keymap";

${[...sharedLayers, zmkLayer("gaming", "Gaming", zmkGaming), zmkLayer("gaming_funcs", "Gaming Funcs", zmkGamingFunctions), zmkLayer("gaming_nums", "Gaming Nums", zmkGamingNumbers), zmkHyperPlainLayer(manifest)].join("\n\n")}
    };
};
`;
}
