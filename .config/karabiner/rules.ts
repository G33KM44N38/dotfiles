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
  createModifierManipulator,
} from "./utils";

const hyperSubLayers = createHyperSubLayers({
  b: {
    a: open("https://chatgpt.com?_perso"),
    y: open("https://youtube.com?_perso"),
    r: open("https://reddit.com?_perso"),
    c: open("https://claude.ai/?_babacoiffure"),
    i: open("https://instagram.com?_perso"),
    d: open("http://localhost:3000"),
    t: open("raycast://extensions/the-browser-company/arc/search-tabs"),
    x: open("https://www.x.com/?_perso"),
    f: open("https://www.netflix.com/?_perso"),
  },
  q: {
    a: open("https://babacoiffure-monorepo-bnj2.onrender.com"),
    s: open(
      "https://dashboard.render.com/project/prj-d0ibijqdbo4c739c9tcg?babacoiffure"
    ),
    c: open(
      "https://www.tiktok.com/@timal___ff/video/7450418795220356374?q=imagine%20t%27es%20mbappe%20et%20tu%20tombe%20sur%20cet%20edit&t=1737645862371"
    ),
    g: open("https://github.com/babacoiffure/babacoiffure_monorepo"),
    m: open("raycast://script-commands/babacoiffure-metrics"),
    d: open(
      "https://cloud.mongodb.com/v2/6823b121f0e64a2a9f745630#/explorer/6823b1742084b0561c1fb495?babacoiffure"
    ),
  },
  o: {
    a: app("Arc"),
    b: app("Beeper Desktop"),
    c: app("Fantastical"),
    d: app("DaVinci Resolve"),
    e: app("Mail"),
    f: app("Figma"),
    g: app("Simulator"),
    h: app("Home"),
    i: app("Messages"),
    j: app("FaceTime"),
    k: app("Ledger Wallet"),
    m: app("Music"),
    n: app("Notion"),
    p: app("Obsidian"),
    q: app("Notes"),
    s: app("Linear"),
    r: app("Finder"),
    semicolon: app("Pages"),
    t: app("Ghostty"),
    v: app("Visual Studio Code"),
    w: app("WhatsApp"),
    x: app("Discord"),
    y: app("Telegram"),
    z: app("Safari"),
  },
  s: {
    u: { to: [{ key_code: "volume_increment" }] },
    j: { to: [{ key_code: "volume_decrement" }] },
    i: { to: [{ key_code: "display_brightness_increment" }] },
    k: { to: [{ key_code: "display_brightness_decrement" }] },
    l: {
      to: [{ key_code: "q", modifiers: ["right_control", "right_command"] }],
    },
    h: app("Home"),
    t: open(`raycast://extensions/raycast/system/toggle-system-appearance`),
    c: open("raycast://extensions/raycast/system/open-camera"),
    m: open("raycast://extensions/raycast/system/toggle-mute"),
  },
  c: {
    h: { to: [{ key_code: "play_or_pause" }] },
    k: { to: [{ key_code: "fastforward" }] },
    j: { to: [{ key_code: "rewind" }] },
  },
  r: {
    a: open("raycast://extensions/destiner/render/view-services"),
    c: open(
      "raycast://extensions/VladCuciureanu/toothpick/manage-bluetooth-connections"
    ),
    e: open("raycast://extensions/raycast/emoji-symbols/search-emoji-symbols"),
    h: open("raycast://extensions/raycast/clipboard-history/clipboard-history"),
    i: open("raycast://extensions/benvp/audio-device/set-input-device"),
    k: open("raycast://extensions/rolandleth/kill-process/index"),
    l: open("raycast://extensions/eluce2/displayplacer/displayplacer"),
    m: open("raycast://extensions/raycast/navigation/search-menu-items"),
    n: open("raycast://extensions/raycast/raycast-notes/raycast-notes"),
    o: open("raycast://extensions/benvp/audio-device/set-output-device"),
    p: open("raycast://extensions/raycast/raycast/confetti"),
    q: open("raycast://extensions/raycast/raycast/search-quicklinks"),
    s: open("raycast://extensions/raycast/snippets/search-snippets"),
    u: open("raycast://extensions/raycast/screenshots/search-screenshots"),
  },
  n: {
    s: open("raycast://extensions/notion/notion/search-page"),
    c: open("raycast://extensions/notion/notion/create-database-page"),
  },
  g: {
    i: open("raycast://extensions/raycast/github/my-issues"),
    p: open("raycast://extensions/raycast/github/my-pull-requests"),
    w: open("raycast://extensions/raycast/github/workflow-runs"),
  },
});

// Define key layers
const leftGuiLayer = createKeyLayer(
  "left_gui",
  {
    a: {
      to: [{ key_code: "grave_accent_and_tilde", modifiers: ["left_shift"] }],
    },
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

const left_option_layer = createKeyLayer(
  "left_option",
  {
    a: { to: [{ key_code: "f1" }] },
    s: { to: [{ key_code: "f2" }] },
    d: { to: [{ key_code: "f3" }] },
    f: { to: [{ key_code: "f4" }] },
    g: { to: [{ key_code: "f5" }] },
    h: { to: [{ key_code: "f6" }] },
    j: { to: [{ key_code: "f7" }] },
    k: { to: [{ key_code: "f8" }] },
    l: { to: [{ key_code: "f9" }] },
    p: { to: [{ key_code: "f10" }] },
  },
  "delete_or_backspace"
);

const rightGuiLayer = createKeyLayer(
  "right_command",
  {
    //left hand
    a: { to: [{ key_code: "backslash", modifiers: ["left_shift"] }] }, // pipe
    d: { to: [{ key_code: "open_bracket" }] },
    g: { to: [{ key_code: "9", modifiers: ["left_shift"] }] },
    f: { to: [{ key_code: "open_bracket", modifiers: ["left_shift"] }] }, // square bracket
    e: { to: [{ key_code: "slash" }] },
    r: { to: [{ key_code: "hyphen", modifiers: ["left_shift"] }] },
    s: { to: [{ key_code: "hyphen", modifiers: ["left_shift"] }] },

    //right hand
    h: { to: [{ key_code: "0", modifiers: ["left_shift"] }] },
    u: { to: [{ key_code: "hyphen" }] },
    j: { to: [{ key_code: "close_bracket", modifiers: ["left_shift"] }] },
    i: { to: [{ key_code: "backslash" }] },
    k: { to: [{ key_code: "close_bracket" }] },
    l: { to: [{ key_code: "grave_accent_and_tilde" }] },
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
  left_option_layer,
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
    description: "caps lock to escape",
    manipulators: [createBasicManipulator("caps_lock", "escape", "")],
  },
  {
    description: "close backet to alt-enter",
    manipulators: [
      createModifierManipulator("close_bracket", "right_option", [
        {
          key_code: "return_or_enter",
          modifiers: ["right_option"],
        },
      ]),
    ],
  },
  {
    description: "open_bracket to cmd space ",
    manipulators: [
      createModifierManipulator("open_bracket", "spacebar", [
        {
          key_code: "spacebar",
          modifiers: ["right_gui"],
        },
      ]),
    ],
  },

  DisableKeyConfig("grave_accent_and_tilde"),
  DisableKeyConfig("tab"),
  DisableKeyConfig("caps_lock"),
  DisableKeyConfig("delete_or_backspace"),
  DisableKeyConfig("escape"),
  DisableKeyConfig("right_shift"),
  DisableKeyConfig("left_shift"),
  DisableKeyConfig("return_or_enter"),
  // DisableKeyConfig("open_bracket"),
  // DisableKeyConfig("close_bracket"),
  DisableKeyConfig("0"),
  DisableKeyConfig("1"),
  DisableKeyConfig("2"),
  DisableKeyConfig("3"),
  DisableKeyConfig("4"),
  DisableKeyConfig("5"),
  DisableKeyConfig("6"),
  DisableKeyConfig("7"),
  DisableKeyConfig("8"),
  DisableKeyConfig("9"),
  DisableKeyConfig("hyphen"),
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
  {
    description: "crkdb",
    manipulators: [
      {
        description: "crkdb -> Hyper Key",
        type: "basic",
        from: {
          key_code: "f24",
          modifiers: {
            optional: ["any"],
          },
        },
        to: [{ set_variable: { name: "hyper", value: 1 } }],
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
