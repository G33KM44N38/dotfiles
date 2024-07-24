import fs from "fs";
import { KarabinerRules } from "./types";
import { createHyperSubLayers, app, open } from "./utils";

const rules: KarabinerRules[] = [
  {
    description: "Caps Lock -> escape/control",
    manipulators: [
      {
        description: "Caps Lock -> escape/control",
        from: {
          key_code: "caps_lock",
          modifiers: {
            optional: ["any"],
          },
        },
        to: [
          {
            key_code: "left_control",
          },
        ],
        to_if_alone: [
          {
            key_code: "escape",
          },
        ],
        type: "basic",
      },
    ],
  },
  {
    description: "cmd touch",
    manipulators: [
      {
        description: "Caps Lock -> Hyper Key",
        from: {
          key_code: "right_gui",
          modifiers: {
            optional: ["any"],
          },
        },
        to: [
          {
            set_variable: {
              name: "hyper",
              value: 1,
            },
          },
        ],
        to_after_key_up: [
          {
            set_variable: {
              name: "hyper",
              value: 0,
            },
          },
        ],
        to_if_alone: [
          {
            key_code: "delete_or_backspace",
          },
        ],
        type: "basic",
      },
      {
        description: "Caps Lock -> Hyper Key",
        from: {
          key_code: "left_gui",
          modifiers: {
            optional: ["any"],
          },
        },
        to: [
          {
            key_code: "left_gui",
          },
        ],
        to_if_alone: [
          {
            key_code: "return_or_enter",
          },
        ],
        type: "basic",
      },
    ],
  },
  {
    description: "deactivate touch",
    manipulators: [
      {
        description: "deactivate delete ",
        from: {
          key_code: "delete_or_backspace",
          modifiers: {
            optional: ["any"],
          },
        },
        to_if_alone: [
          {
            key_code: "out",
          },
        ],
        type: "basic",
      },
      {
        description: "deactivate essacpe",
        from: {
          key_code: "escape",
          modifiers: {
            optional: ["any"],
          },
        },
        to_if_alone: [
          {
            key_code: "out",
          },
        ],
        type: "basic",
      },
    ],
  },
  ...createHyperSubLayers({
    spacebar: open(
      "raycast://extensions/stellate/mxstbr-commands/create-notion-todo"
    ),
    // b = "B"rowse
    b: {
      y: open("https://youtube.com"),
    },
    // o = "Open" applications
    o: {
      a: app("Arc"),
      c: app("Notion Calendar"),
      n: app("Notion"),
      t: app("iTerm"),
      b: app("Beeper"),
      i: app("Messages"),
      p: app("Music"),
      m: app("Mail"),
      s: app("Simulator"),
      f: app("Figma"),
    },

    // s = "System"
    s: {
      u: {
        to: [
          {
            key_code: "volume_increment",
          },
        ],
      },
      j: {
        to: [
          {
            key_code: "volume_decrement",
          },
        ],
      },
      i: {
        to: [
          {
            key_code: "display_brightness_increment",
          },
        ],
      },
      k: {
        to: [
          {
            key_code: "display_brightness_decrement",
          },
        ],
      },
      l: {
        to: [
          {
            key_code: "q",
            modifiers: ["right_control", "right_command"],
          },
        ],
      },
      p: {
        to: [
          {
            key_code: "play_or_pause",
          },
        ],
      },
      semicolon: {
        to: [
          {
            key_code: "fastforward",
          },
        ],
      },
      // "D"o not disturb toggle
      d: open(
        `raycast://extensions/yakitrak/do-not-disturb/toggle?launchType=background`
      ),
      // "T"heme
      t: open(`raycast://extensions/raycast/system/toggle-system-appearance`),
      c: open("raycast://extensions/raycast/system/open-camera"),
    },

    // v = "moVe" which isn't "m" because we want it to be on the left hand
    // so that hjkl work like they do in vim
    v: {
      h: {
        to: [{ key_code: "left_arrow" }],
      },
      j: {
        to: [{ key_code: "down_arrow" }],
      },
      k: {
        to: [{ key_code: "up_arrow" }],
      },
      l: {
        to: [{ key_code: "right_arrow" }],
      },
      // Magicmove via homerow.app
      m: {
        to: [{ key_code: "f", modifiers: ["right_control"] }],
        // TODO: Trigger Vim Easymotion when VSCode is focused
      },
      u: {
        to: [{ key_code: "page_down" }],
      },
      i: {
        to: [{ key_code: "page_up" }],
      },
    },

    // c = Musi*c* which isn't "m" because we want it to be on the left hand
    c: {
      p: {
        to: [{ key_code: "play_or_pause" }],
      },
      n: {
        to: [{ key_code: "fastforward" }],
      },
      b: {
        to: [{ key_code: "rewind" }],
      },
    },

    // r = "Raycast"
    r: {
      a: open("raycast://extensions/abielzulio/chatgpt/ask"),
      n: open("raycast://script-commands/dismiss-notifications"),
      e: open(
        "raycast://extensions/raycast/emoji-symbols/search-emoji-symbols"
      ),
      p: open("raycast://extensions/raycast/raycast/confetti"),
      s: open("raycast://extensions/peduarte/silent-mention/index"),
      h: open(
        "raycast://extensions/raycast/clipboard-history/clipboard-history"
      ),
      b: open(
        "raycast://extensions/VladCuciureanu/toothpick/manage-bluetooth-connections"
      ),
      o: open("raycast://extensions/benvp/audio-device/set-output-device"),
    },
  }),
];

fs.writeFileSync(
  "karabiner.json",
  JSON.stringify(
    {
      global: {
        show_in_menu_bar: false,
      },
      profiles: [
        {
          name: "Default",
          complex_modifications: {
            rules,
          },
        },
      ],
    },
    null,
    2
  )
);
