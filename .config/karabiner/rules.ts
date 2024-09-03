import fs from "fs";
import { KarabinerRules, KeyCode, Manipulator } from "./types";
import {
  createHyperSubLayers,
  app,
  open,
  createBasicManipulator,
  createHomeRowMod,
} from "./utils";

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
  {
    description: "Homerow mods",
    manipulators: homeRowMods,
  },
  {
    description: "Caps Lock -> escape/control",
    manipulators: [
      createBasicManipulator(
        "caps_lock",
        "left_control",
        "Caps Lock -> escape/control",
        [{ key_code: "escape" }]
      ),
      createBasicManipulator(
        "spacebar",
        "left_control",
        "spacebar -> spacebar/control",
        [{ key_code: "spacebar" }]
      ),
    ],
  },
  {
    description: "Hyper Key (Right Command)",
    manipulators: [
      {
        description: "Right Command -> Hyper Key",
        type: "basic",
        from: { key_code: "right_command", modifiers: { optional: ["any"] } },
        to: [{ set_variable: { name: "hyper", value: 1 } }],
        to_after_key_up: [{ set_variable: { name: "hyper", value: 0 } }],
      },
    ],
  },
  {
    description: "cmd touch",
    manipulators: [
      createBasicManipulator("left_gui", "left_gui", "Caps Lock -> Hyper Key", [
        { key_code: "return_or_enter" },
      ]),
    ],
  },
  {
    description: "deactivate touch",
    manipulators: [
      "delete_or_backspace",
      "escape",
      "right_shift",
      "left_shift",
      "return_or_enter",
    ].map((key) =>
      createBasicManipulator(key as KeyCode, "vk_none", `deactivate ${key}`, [
        { key_code: key as KeyCode },
      ])
    ),
  },
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
  ...createHyperSubLayers({
    spacebar: open(
      "raycast://extensions/stellate/mxstbr-commands/create-notion-todo"
    ),
    b: {
      y: open("https://youtube.com"),
      r: open("https://reddit.com"),
      c: open("https://claude.ai"),
      i: open("https://instagram.com"),
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
      e: open(
        "raycast://extensions/raycast/emoji-symbols/search-emoji-symbols"
      ),
      p: open("raycast://extensions/raycast/raycast/confetti"),
      s: open("raycast://extensions/raycast/snippets/search-snippets"),
      h: open(
        "raycast://extensions/raycast/clipboard-history/clipboard-history"
      ),
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
  }),
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
