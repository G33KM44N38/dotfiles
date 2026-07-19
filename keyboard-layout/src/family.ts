import {
  emit,
  hyper,
  key,
  layer,
  modifier,
  positions,
  system,
  tapHold,
  type Capability,
  type DeviceProfile,
  type InputAddress,
  type KeyboardFamily,
  type Position,
  type SystemAction,
} from "./domain.js";

const base = {
  "left.top.pinky": emit(key("q")),
  "left.top.ring": emit(key("w")),
  "left.top.middle": emit(key("e")),
  "left.top.index": emit(key("r")),
  "left.top.inner": emit(key("t")),
  "right.top.inner": emit(key("y")),
  "right.top.index": emit(key("u")),
  "right.top.middle": emit(key("i")),
  "right.top.ring": emit(key("o")),
  "right.top.pinky": emit(key("p")),
  "left.home.pinky": tapHold(key("a"), modifier("leftGui"), "homeRow"),
  "left.home.ring": tapHold(key("s"), modifier("leftAlt"), "homeRow"),
  "left.home.middle": tapHold(key("d"), modifier("leftShift"), "homeRow"),
  "left.home.index": tapHold(key("f"), modifier("leftControl"), "homeRow"),
  "left.home.inner": emit(key("g")),
  "right.home.inner": emit(key("h")),
  "right.home.index": tapHold(key("j"), modifier("rightControl"), "homeRow"),
  "right.home.middle": tapHold(key("k"), modifier("rightShift"), "homeRow"),
  "right.home.ring": tapHold(key("l"), modifier("rightAlt"), "homeRow"),
  "right.home.pinky": tapHold(key("semicolon"), modifier("rightGui"), "homeRow"),
  "left.bottom.pinky": emit(key("z")),
  "left.bottom.ring": emit(key("x")),
  "left.bottom.middle": emit(key("c")),
  "left.bottom.index": emit(key("v")),
  "left.bottom.inner": emit(key("b")),
  "right.bottom.inner": emit(key("n")),
  "right.bottom.index": emit(key("m")),
  "right.bottom.middle": emit(key("comma")),
  "right.bottom.ring": emit(key("dot")),
  "right.bottom.pinky": emit(key("slash")),
  "left.thumb.outer": emit(layer("functions")),
  "left.thumb.middle": tapHold(key("backspace"), layer("system"), "thumbLayer"),
  "left.thumb.inner": tapHold(key("enter"), layer("numbers"), "thumbLayer"),
  "right.thumb.inner": tapHold(key("space"), layer("symbols"), "thumbLayer"),
  "right.thumb.middle": tapHold(key("tab"), modifier("rightShift"), "shiftTab"),
  "right.thumb.outer": emit(hyper()),
} as const;

const numbers = {
  "left.top.pinky": emit(key("digit1")),
  "left.top.ring": emit(key("digit2")),
  "left.top.middle": emit(key("digit3")),
  "left.top.index": emit(key("digit4")),
  "left.top.inner": emit(key("digit5")),
  "right.top.inner": emit(key("digit6")),
  "right.top.index": emit(key("digit7")),
  "right.top.middle": emit(key("digit8")),
  "right.top.ring": emit(key("digit9")),
  "right.top.pinky": emit(key("digit0")),
  "left.home.pinky": emit(key("tilde")),
  "left.home.ring": emit(key("minus")),
  "left.home.middle": emit(key("plus")),
  "left.home.index": emit(key("equals")),
  "right.home.inner": emit(key("left")),
  "right.home.index": emit(key("down")),
  "right.home.middle": emit(key("up")),
  "right.home.ring": emit(key("right")),
} as const;

const symbols = {
  "left.top.middle": emit(key("slash")),
  "left.top.index": emit(key("underscore")),
  "right.top.index": emit(key("minus")),
  "right.top.middle": emit(key("backslash")),
  "left.home.pinky": emit(key("pipe")),
  "left.home.ring": emit(key("underscore")),
  "left.home.middle": emit(key("leftBracket")),
  "left.home.index": emit(key("leftBrace")),
  "left.home.inner": emit(key("leftParen")),
  "right.home.inner": emit(key("rightParen")),
  "right.home.index": emit(key("rightBrace")),
  "right.home.middle": emit(key("rightBracket")),
  "right.home.ring": emit(key("grave")),
} as const;

const systemLayer = {
  "left.top.inner": emit(system("toggleAppearance")),
  "right.top.index": emit(system("volumeUp")),
  "right.top.middle": emit(system("brightnessUp")),
  "left.bottom.middle": emit(system("controlCenter")),
  "right.bottom.inner": emit(system("notificationCenter")),
  "right.bottom.index": emit(system("mute")),
  "right.home.inner": emit(system("home")),
  "right.home.index": emit(system("volumeDown")),
  "right.home.middle": emit(system("brightnessDown")),
  "right.home.ring": emit(system("lockScreen")),
} as const;

const functions = {
  "left.home.pinky": emit(key("f1")),
  "left.home.ring": emit(key("f2")),
  "left.home.middle": emit(key("f3")),
  "left.home.index": emit(key("f4")),
  "left.home.inner": emit(key("f5")),
  "right.home.inner": emit(key("f6")),
  "right.home.index": emit(key("f7")),
  "right.home.middle": emit(key("f8")),
  "right.home.ring": emit(key("f9")),
  "right.top.pinky": emit(key("f10")),
} as const;

const slotByPosition = Object.fromEntries(
  positions.map((position, index) => {
    if (index < 10) return [position, index < 5 ? index + 1 : index + 1];
    if (index < 20) return [position, index < 15 ? index + 3 : index + 3];
    if (index < 30) return [position, index < 25 ? index + 5 : index + 5];
    return [position, index + 6];
  }),
) as Record<Position, number>;

function corneInputs(target: "qmk" | "zmk"): Record<Position, InputAddress> {
  return Object.fromEntries(
    positions.map((position) => [
      position,
      {
        id: `${target}:${position}`,
        label: position,
        slot: slotByPosition[position],
      },
    ]),
  ) as Record<Position, InputAddress>;
}

function swapInputs(
  source: Record<Position, InputAddress>,
  first: Position,
  second: Position,
): Record<Position, InputAddress> {
  return { ...source, [first]: source[second], [second]: source[first] };
}

const macKeyByPosition: Record<Position, string> = {
  "left.top.pinky": "q", "left.top.ring": "w", "left.top.middle": "e",
  "left.top.index": "r", "left.top.inner": "t", "right.top.inner": "y",
  "right.top.index": "u", "right.top.middle": "i", "right.top.ring": "o",
  "right.top.pinky": "p", "left.home.pinky": "a", "left.home.ring": "s",
  "left.home.middle": "d", "left.home.index": "f", "left.home.inner": "g",
  "right.home.inner": "h", "right.home.index": "j", "right.home.middle": "k",
  "right.home.ring": "l", "right.home.pinky": "semicolon",
  "left.bottom.pinky": "z", "left.bottom.ring": "x", "left.bottom.middle": "c",
  "left.bottom.index": "v", "left.bottom.inner": "b", "right.bottom.inner": "n",
  "right.bottom.index": "m", "right.bottom.middle": "comma",
  "right.bottom.ring": "dot", "right.bottom.pinky": "slash",
  "left.thumb.outer": "left_option", "left.thumb.middle": "hyper+s",
  "left.thumb.inner": "left_gui", "right.thumb.inner": "right_command",
  "right.thumb.middle": "right_option", "right.thumb.outer": "spacebar",
};

const macInputs = Object.fromEntries(
  positions.map((position) => [
    position,
    { id: `karabiner:${macKeyByPosition[position]}`, label: macKeyByPosition[position] },
  ]),
) as Record<Position, InputAddress>;

const bridgeKeys: Partial<Record<SystemAction, Capability>> = {
  home: { route: "hostBridge", key: "f14" },
  toggleAppearance: { route: "hostBridge", key: "f15" },
  controlCenter: { route: "hostBridge", key: "f16" },
  notificationCenter: { route: "hostBridge", key: "f17" },
};

const firmwareCapabilities = Object.fromEntries(
  [
    "brightnessDown", "brightnessUp", "lockScreen", "mute", "volumeDown", "volumeUp",
    "controlCenter", "home", "notificationCenter", "toggleAppearance",
  ].map((action) => [
    action,
    bridgeKeys[action as SystemAction] ?? { route: "native" },
  ]),
) as Record<SystemAction, Capability>;

const macCapabilities = Object.fromEntries(
  [
    "brightnessDown", "brightnessUp", "lockScreen", "mute", "volumeDown", "volumeUp",
    "controlCenter", "home", "notificationCenter", "toggleAppearance",
  ].map((action) => [
    action,
    bridgeKeys[action as SystemAction] === undefined
      ? { route: "native" }
      : { route: "host" },
  ]),
) as Record<SystemAction, Capability>;

const qmkProfile: DeviceProfile = {
  id: "corne-qmk-wired",
  name: "Wired Corne (QMK)",
  target: "qmk",
  repository: "qmk",
  positionMap: corneInputs("qmk"),
  timings: {
    homeRow: { tappingTermMs: 125, quickTapMs: 0, flavor: "default", permissiveHold: true },
    thumbLayer: { tappingTermMs: 100, quickTapMs: 0, flavor: "default" },
    shiftTab: { tappingTermMs: 125, quickTapMs: 0, flavor: "default", permissiveHold: true },
  },
  capabilities: firmwareCapabilities,
  layerTriggers: {
    functions: { input: "left.thumb.outer", mode: "hold" },
    system: { input: "left.thumb.middle", tap: "backspace", mode: "hold" },
    numbers: { input: "left.thumb.inner", tap: "enter", mode: "hold" },
    symbols: { input: "right.thumb.inner", tap: "space", mode: "hold" },
  },
  adjustments: [],
};

const zmkInputs = swapInputs(
  corneInputs("zmk"),
  "left.thumb.middle",
  "left.thumb.inner",
);

const zmkProfile: DeviceProfile = {
  id: "corne-zmk-wireless",
  name: "Wireless Corne (ZMK)",
  target: "zmk",
  repository: "zmk",
  positionMap: zmkInputs,
  timings: {
    homeRow: { tappingTermMs: 125, quickTapMs: 0, flavor: "balanced" },
    thumbLayer: { tappingTermMs: 100, flavor: "tapPreferred" },
    shiftTab: { tappingTermMs: 125, quickTapMs: 0, flavor: "balanced" },
  },
  capabilities: firmwareCapabilities,
  layerTriggers: {
    functions: { input: "left.thumb.outer", mode: "hold" },
    system: { input: "left.thumb.middle", tap: "backspace", mode: "hold" },
    numbers: { input: "left.thumb.inner", tap: "enter", mode: "hold" },
    symbols: { input: "right.thumb.inner", tap: "space", mode: "hold" },
  },
  adjustments: [{
    kind: "swapInputs",
    positions: ["left.thumb.middle", "left.thumb.inner"],
    reason: "Compensate for the wireless Corne's reversed left-thumb inputs.",
  }],
};

const macProfile: DeviceProfile = {
  id: "macbook-built-in",
  name: "MacBook built-in keyboard",
  target: "karabiner",
  repository: "dotfiles",
  positionMap: macInputs,
  timings: {
    homeRow: { tappingTermMs: 150, aloneTimeoutMs: 180, flavor: "default" },
    thumbLayer: { tappingTermMs: 150, aloneTimeoutMs: 180, flavor: "default" },
    shiftTab: { tappingTermMs: 150, aloneTimeoutMs: 180, flavor: "default" },
  },
  capabilities: macCapabilities,
  layerTriggers: {
    numbers: { input: "left_gui", tap: "enter", mode: "hold" },
    functions: { input: "left_option", tap: "backspace", mode: "hold" },
    symbols: { input: "right_command", tap: "space", mode: "hold" },
    system: { input: "hyper+s", mode: "chord" },
  },
  adjustments: [],
};

export const keyboardFamily: KeyboardFamily = {
  id: "shared-ergonomic-keyboard-family",
  layout: {
    id: "shared-corne-mac-ergonomics",
    layers: { base, numbers, symbols, system: systemLayer, functions },
  },
  devices: [qmkProfile, zmkProfile, macProfile],
};
