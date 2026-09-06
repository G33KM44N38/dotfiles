// Host-only display navigation. Screen numbers are resolved from live geometry.
export function macosScreenRule() {
  const digits = ["1", "2", "3"] as const;
  return {
    description: "Screens left to right: Hyper focus, Option+Shift move",
    manipulators: digits.flatMap((key_code) => [
      {
        type: "basic" as const,
        from: { key_code, modifiers: { mandatory: ["command", "control", "option", "shift"] } },
        to: [{ shell_command: `"$HOME/.dotfiles/bin/screen-control" focus ${key_code}`, repeat: false }],
      },
      {
        type: "basic" as const,
        from: { key_code, modifiers: { mandatory: ["option", "shift"] } },
        to: [{ shell_command: `"$HOME/.dotfiles/bin/screen-control" move ${key_code}`, repeat: false }],
      },
    ]),
  };
}
