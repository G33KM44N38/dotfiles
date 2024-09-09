import fs from "fs";
import { KarabinerRules, Manipulator } from "./types";
import {
  createHyperSubLayers,
  app,
  open,
  createBasicManipulator,
  createHomeRowMod,
  DisableKeyConfig,
  createKeyLayer,
} from "./utils";

const hyperSubLayers = createHyperSubLayers({
  spacebar: open(
    "raycast://extensions/stellate/mxstbr-commands/create-notion-todo"
  ),
  b: {
    y: open("https://youtube.com"),
    r: open("https://reddit.com"),
    c: open("https://claude.ai"),
    i: open("https://instagram.com"),
    d: open("http://localhost:3000"),
  },
  o: {
    1: app("Cursor"),
    a: app("Arc"),
    d: app("Discord"),
    c: app("Notion Calendar"),
    u: app("Calendar"),
    n: app("Notion"),
    t: app("iTerm"),
    b: app("Beeper"),
    i: app("Messages"),
    p: app("Music"),
    m: app("Mail"),
    s: app("Safari"),
    f: app("Figma"),
    v: app("DaVinci Resolve"),
  },
  s: {
    u: { to: [{ key_code: "volume_increment" }] },
    j: { to: [{ key_code: "volume_decrement" }] },
    i: { to: [{ key_code: "display_brightness_increment" }] },
    k: { to: [{ key_code: "display_brightness_decrement" }] },
    l: {
      to: [{ key_code: "q", modifiers: ["right_control", "right_command"] }],
    },
    p: { to: [{ key_code: "play_or_pause" }] },
    semicolon: { to: [{ key_code: "fastforward" }] },
    d: open(
      `raycast://extensions/yakitrak/do-not-disturb/toggle?launchType=background`
    ),
    t: open(`raycast://extensions/raycast/system/toggle-system-appearance`),
    c: open("raycast://extensions/raycast/system/open-camera"),
  },
  v: {
    h: { to: [{ key_code: "left_arrow" }] },
    j: { to: [{ key_code: "down_arrow" }] },
    k: { to: [{ key_code: "up_arrow" }] },
    l: { to: [{ key_code: "right_arrow" }] },
    d: { to: [{ key_code: "page_down" }] },
    u: { to: [{ key_code: "page_up" }] },
  },
  c: {
    p: { to: [{ key_code: "play_or_pause" }] },
    n: { to: [{ key_code: "fastforward" }] },
    b: { to: [{ key_code: "rewind" }] },
  },
  r: {
    a: open("raycast://extensions/abielzulio/chatgpt/ask"),
    e: open("raycast://extensions/raycast/emoji-symbols/search-emoji-symbols"),
    p: open("raycast://extensions/raycast/raycast/confetti"),
    s: open("raycast://extensions/raycast/snippets/search-snippets"),
    h: open("raycast://extensions/raycast/clipboard-history/clipboard-history"),
    b: open(
      "raycast://extensions/VladCuciureanu/toothpick/manage-bluetooth-connections"
    ),
    o: open("raycast://extensions/benvp/audio-device/set-output-device"),
    1: open(
      "raycast://extensions/VladCuciureanu/toothpick/connect-favorite-device-1"
    ),
    2: open(
      "raycast://extensions/VladCuciureanu/toothpick/connect-favorite-device-2"
    ),
  },
});

// Define key layers
const leftGuiLayer = createKeyLayer(
  "left_gui",
  {
    q: { to: [{ key_code: "1" }] },
    w: { to: [{ key_code: "2" }] },
    e: { to: [{ key_code: "3" }] },
    r: { to: [{ key_code: "4" }] },
    t: { to: [{ key_code: "5" }] },
    y: { to: [{ key_code: "6" }] },
    u: { to: [{ key_code: "7" }] },
    i: { to: [{ key_code: "8" }] },
    o: { to: [{ key_code: "9" }] },
    p: { to: [{ key_code: "0" }] },

    // arrow key
    h: { to: [{ key_code: "left_arrow" }] },
    j: { to: [{ key_code: "down_arrow" }] },
    k: { to: [{ key_code: "up_arrow" }] },
    l: { to: [{ key_code: "right_arrow" }] },

    // signs
    s: { to: [{ key_code: "keypad_hyphen" }] },
    d: { to: [{ key_code: "keypad_plus" }] },
    f: { to: [{ key_code: "keypad_equal_sign" }] },
  },
  "return_or_enter"
);

const rightGuiLayer = createKeyLayer(
  "right_command",
  {
    //left hand
    b: { to: [{ key_code: "open_bracket", modifiers: ["left_shift"] }] },
    v: { to: [{ key_code: "open_bracket" }] },
    g: { to: [{ key_code: "9", modifiers: ["left_shift"] }] }, // to have the closing parenthesis
    //right hand
    m: { to: [{ key_code: "close_bracket" }] },
    n: { to: [{ key_code: "close_bracket", modifiers: ["left_shift"] }] },
    h: { to: [{ key_code: "0", modifiers: ["left_shift"] }] }, // to have the closing parenthesis
  },
  "spacebar"
);

const homeRowMods: Manipulator[] = [
  createHomeRowMod("a", "left_gui"),
  createHomeRowMod("s", "left_option"),
  createHomeRowMod("d", "left_shift"),
  createHomeRowMod("f", "left_control"),
  createHomeRowMod("j", "right_control"),
  createHomeRowMod("k", "right_shift"),
  createHomeRowMod("l", "right_option"),
  createHomeRowMod("semicolon", "right_gui"),
];

const rules: KarabinerRules[] = [
  leftGuiLayer,
  rightGuiLayer,
  {
    description: "Homerow mods",
    manipulators: homeRowMods,
  },
  {
    description: "cmd touch",
    manipulators: [
      createBasicManipulator("left_gui", "left_gui", "", [
        { key_code: "return_or_enter" },
      ]),
    ],
  },
  {
    description: "right option to tab",
    manipulators: [createBasicManipulator("right_option", "tab", "")],
  },
  {
    description: "left control to escape",
    manipulators: [
      createBasicManipulator("left_control", "left_control", "", [
        { key_code: "escape" },
      ]),
    ],
  },
  DisableKeyConfig("tab"),
  DisableKeyConfig("caps_lock"),
  DisableKeyConfig("delete_or_backspace"),
  DisableKeyConfig("escape"),
  DisableKeyConfig("right_shift"),
  DisableKeyConfig("left_shift"),
  DisableKeyConfig("return_or_enter"),
  {
    description: "alt to backspace",
    manipulators: [
      createBasicManipulator(
        "left_option",
        "delete_or_backspace",
        "alt to backspace"
      ),
    ],
  },

  // hyper key
  {
    description: "Hyper Key (spacebar)",
    manipulators: [
      {
        description: "spacebar -> Hyper Key",
        type: "basic",
        from: { key_code: "spacebar", modifiers: { optional: ["any"] } },
        to: [{ set_variable: { name: "hyper", value: 1 } }],
        to_if_alone: [{ key_code: "spacebar" }],
        to_after_key_up: [{ set_variable: { name: "hyper", value: 0 } }],
      },
    ],
  },
  ...hyperSubLayers,
];

fs.writeFileSync(
  "karabiner.json",
  JSON.stringify(
    {
      global: { show_in_menu_bar: false },
      profiles: [{ name: "Default", complex_modifications: { rules } }],
    },
    null,
    2
  )
);
