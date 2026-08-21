import fs from "fs";
import { KarabinerRules } from "./types";
import {
  sharedFunctionLayer,
  sharedHomeRowMods,
  sharedHostBridgeRules,
  sharedLayerTriggers,
  sharedNumbersLayer,
  sharedSymbolsLayer,
  sharedSystemLayer,
} from "./generated/shared-layout";
import {
  createHyperSubLayers,
  app,
  open,
  createBasicManipulator,
  createHomeRowMod,
  DisableKeyConfig,
  createKeyLayer,
  createModifierManipulator,
  CorneKeyboardCondition,
} from "./utils";

const hyperSubLayers = createHyperSubLayers({
  b: {
    a: open("https://chatgpt.com?_perso"),
    y: open("https://youtube.com?_perso"),
    r: open("https://reddit.com?_perso"),
    c: open("https://claude.ai/?_babacoiffure"),
    i: {
      to: [
        {
          shell_command:
            "/Users/boss/.dotfiles/bin/focus-arc-tab 'instagram.com' 'https://instagram.com?_perso'",
        },
      ],
      description: "Focus Instagram in Arc",
    },
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
    c: app("Calendar"),
    d: app("DaVinci Resolve"),
    e: app("Mail"),
    f: app("Figma"),
    g: app("Simulator"),
    h: app("Home"),
    i: app("Messages"),
    j: app("FaceTime"),
    k: app("ChatGPT"),
    comma: app("Slack"),
    m: app("Music"),
    n: app("Notion"),
    p: app("Obsidian"),
    q: app("Notes"),
    r: app("Finder"),
    s: app("Linear"),
    semicolon: app("Reminders"),
    t: app("Ghostty"),
    u: app("Codex"),
    v: app("Visual Studio Code"),
    w: app("WhatsApp"),
    x: app("Discord"),
    y: app("Brave Browser"),
    z: app("Safari"),
    quote: app("T3 Code (Alpha)"),
    slash: app("Google Chrome"),
  },
  s: sharedSystemLayer,
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

const leftGuiLayer = createKeyLayer(
  sharedLayerTriggers.numbers.input,
  sharedNumbersLayer,
  sharedLayerTriggers.numbers.tap
);

const left_option_layer = createKeyLayer(
  sharedLayerTriggers.functions.input,
  sharedFunctionLayer,
  sharedLayerTriggers.functions.tap
);

const rightGuiLayer = createKeyLayer(
  sharedLayerTriggers.symbols.input,
  sharedSymbolsLayer,
  sharedLayerTriggers.symbols.tap
);

const homeRowMods = sharedHomeRowMods.map(({ input, modifier, timing, tap }) =>
  createHomeRowMod(input, modifier, timing, tap)
);

const rules: KarabinerRules[] = [
  leftGuiLayer,
  rightGuiLayer,
  left_option_layer,
  {
    description: "Homerow mods",
    manipulators: homeRowMods,
  },
  ...sharedHostBridgeRules,
  {
    description: "cmd touch",
    manipulators: [
      createBasicManipulator("left_gui", "left_gui", "", [
        { key_code: "return_or_enter" },
      ]),
    ],
  },
  {
    description: "caps lock to escape/fn",
    manipulators: [
      {
        description: "caps_lock -> fn (hold), escape (tap)",
        type: "basic",
        conditions: [
          {
            type: "device_if",
            identifiers: [
              {
                vendor_id: 1452,
              },
            ],
            description: "MacBook Pro built-in keyboard",
          },
        ],
        from: {
          key_code: "caps_lock",
          modifiers: { optional: ["any"] },
        },
        to_if_held_down: [{ apple_vendor_top_case_key_code: "keyboard_fn" }],
        to_if_alone: [{ key_code: "escape" }],
        parameters: {
          "basic.to_if_held_down_threshold_milliseconds": 500,
        },
      },
    ],
  },
  {
    description: "corne escape to escape/fn",
    manipulators: [
      {
        description: "corne escape -> fn (hold), escape (tap)",
        type: "basic",
        conditions: [CorneKeyboardCondition],
        from: {
          key_code: "escape",
          modifiers: { optional: ["any"] },
        },
        to_if_held_down: [{ apple_vendor_top_case_key_code: "keyboard_fn" }],
        to_if_alone: [{ key_code: "escape" }],
        parameters: {
          "basic.to_if_held_down_threshold_milliseconds": 500,
        },
      },
    ],
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
