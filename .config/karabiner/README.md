# Karabiner-Elements Configuration

This project provides a custom configuration for Karabiner-Elements on macOS, designed to enhance keyboard productivity through advanced key remappings, hyper key sublayers, and application launchers.

## Technical Aspects

### Purpose
The primary goal of this configuration is to optimize keyboard workflows by creating intuitive shortcuts and layers for launching applications, opening websites, controlling system settings, and executing Raycast commands.

### Technologies
*   **TypeScript**: The configuration is written in TypeScript, providing type safety and improved code organization.
*   **Node.js**: Used as the runtime environment for building and watching the configuration files.
*   **Karabiner-Elements**: The core application that interprets and applies the defined keyboard modifications.
*   **`run-applescript`**: A Node.js library used to execute AppleScript commands, enabling interaction with macOS applications like Arc browser for specific functionalities.

### Key Features

#### Hyper Key Sublayers
A central feature is the "Hyper Key" (configured to be the `spacebar` or `f24` key), which, when held down, activates various sublayers for quick access to:

*   **Websites**:
    *   `Hyper + B + A`: ChatGPT
    *   `Hyper + B + Y`: YouTube
    *   `Hyper + B + R`: Reddit
    *   `Hyper + B + C`: Claude AI
    *   `Hyper + B + I`: Instagram
    *   `Hyper + B + D`: Localhost (http://localhost:3000)
    *   `Hyper + B + T`: Twitch
    *   `Hyper + B + X`: X (formerly Twitter)
    *   `Hyper + B + F`: Netflix
*   **Applications**:
    *   `Hyper + O + A`: Arc
    *   `Hyper + O + B`: Beeper
    *   `Hyper + O + C`: Calendar
    *   `Hyper + O + D`: DaVinci Resolve
    *   `Hyper + O + E`: Mail
    *   `Hyper + O + F`: Figma
    *   `Hyper + O + G`: Simulator
    *   `Hyper + O + H`: Home
    *   `Hyper + O + I`: Messages
    *   `Hyper + O + J`: FaceTime
    *   `Hyper + O + K`: Ledger Live
    *   `Hyper + O + M`: Music
    *   `Hyper + O + N`: Notion
    *   `Hyper + O + P`: Obsidian
    *   `Hyper + O + R`: Reader
    *   `Hyper + O + S`: The Sims 4
    *   `Hyper + O + Semicolon`: Cursor
    *   `Hyper + O + T`: Ghostty
    *   `Hyper + O + V`: Visual Studio Code
    *   `Hyper + O + X`: Discord
    *   `Hyper + O + Y`: Telegram
    *   `Hyper + O + Z`: Safari
*   **System Controls**:
    *   `Hyper + S + U`: Volume Up
    *   `Hyper + S + J`: Volume Down
    *   `Hyper + S + I`: Display Brightness Up
    *   `Hyper + S + K`: Display Brightness Down
    *   `Hyper + S + L`: Lock Screen (`Control + Command + Q`)
    *   `Hyper + S + H`: Home
    *   `Hyper + S + D`: Toggle Do Not Disturb (via Raycast)
    *   `Hyper + S + T`: Toggle System Appearance (via Raycast)
    *   `Hyper + S + C`: Open Camera (via Raycast)
*   **Raycast Commands**:
    *   `Hyper + R + A`: Maximize Window
    *   `Hyper + R + C`: Manage Bluetooth Connections
    *   `Hyper + R + K`: Kill Process
    *   `Hyper + R + U`: Search Screenshots
    *   `Hyper + R + E`: Search Emoji Symbols
    *   `Hyper + R + H`: Clipboard History
    *   `Hyper + R + I`: Set Audio Input Device
    *   `Hyper + R + O`: Set Audio Output Device
    *   `Hyper + R + P`: Confetti
    *   `Hyper + R + S`: Search Snippets
    *   `Hyper + R + M`: Search Menu Items
    *   `Hyper + R + L`: Display Placer
*   **Notion Commands**:
    *   `Hyper + N + S`: Search Notion Page
    *   `Hyper + N + C`: Create Notion Database Page

#### Key Layers
Additional key layers provide further remappings:

*   **Left GUI Layer (Left Command held)**:
    *   `QWERTY` row maps to `1234567890`
    *   `HJKL` maps to `Left, Down, Up, Right Arrow`
    *   `S, D, F` map to `Keypad Hyphen, Keypad Plus, Keypad Equal Sign`
*   **Left Option Layer (Left Option held)**:
    *   `ASDFGHJKLP` maps to `F1-F10`
*   **Right GUI Layer (Right Command held)**:
    *   Various keys map to symbols like `\`, `[`, `]`, `(`, `~`, `/`, `'`, `{`, `}`, `)`, `_`, `` ` ``.

#### Homerow Mods
The home row keys (`A`, `S`, `D`, `F`, `J`, `K`, `L`, `Semicolon`) function as standard modifier keys (`left_gui`, `left_option`, `left_shift`, `left_control`, `right_control`, `right_shift`, `right_option`, `right_gui`) when held down, but produce their original character when tapped. This is optimized for fast typing.

#### Basic Key Remappings
*   `right_option` remapped to `tab`
*   `caps_lock` remapped to `escape`
*   `close_bracket` remapped to `escape`
*   `open_bracket` remapped to `command + spacebar`
*   `left_option` remapped to `delete_or_backspace`

#### Key Disabling
Several keys are explicitly disabled to prevent accidental presses or to free them up for custom mappings within the Karabiner-Elements configuration. These include: `grave_accent_and_tilde`, `tab`, `caps_lock`, `delete_or_backspace`, `escape`, `right_shift`, `left_shift`, `return_or_enter`, and number keys (`0-9`), and `hyphen`.

### Build Process
The `karabiner.json` configuration file is generated from TypeScript source files:

*   **Build Command**: `yarn build` or `npm run build` executes `tsm rules.ts`. This command compiles the `rules.ts` file and generates the `karabiner.json` file in the project root.
*   **Watch Command**: `yarn watch` or `npm run watch` uses `nodemon` to monitor changes in `.ts` files. Any modification automatically triggers a rebuild of `karabiner.json`, streamlining the development process.

### Code Structure
*   `rules.ts`: The main TypeScript file where the Karabiner-Elements rules are defined and assembled. It imports utilities and types to construct the complex modifications.
*   `utils.ts`: Contains a collection of helper functions that simplify the creation of Karabiner-Elements manipulators and conditions. This includes functions for creating hyper sublayers, application launchers, opening URLs, defining home row modifiers, and disabling keys.
*   `types.ts`: Defines the TypeScript interfaces and types that mirror the Karabiner-Elements JSON schema, ensuring type safety and consistency throughout the configuration.
*   `scripts/arc.ts`: A dedicated script containing the `openArcWebsite` function. This function leverages AppleScript to intelligently open URLs in the Arc browser, checking if Arc is already running or if the tab already exists to optimize user experience.

### Dependencies
The project relies on the following development and runtime dependencies, managed via `package.json`:

*   `@types/node`: TypeScript type definitions for Node.js.
*   `nodemon`: A utility that monitors for changes in source files and automatically restarts the build process.
*   `prettier`: An opinionated code formatter used to maintain consistent code style.
*   `tsm`: A TypeScript module loader that allows direct execution of TypeScript files without prior compilation.
*   `run-applescript`: A utility for running AppleScript commands from Node.js, crucial for interacting with macOS applications.
