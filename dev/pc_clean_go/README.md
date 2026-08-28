# pc_clean

`pc_clean` is a macOS storage reporter and cleanup runner for development machines.

Running it without arguments starts Mole, then mac-cleanup, then prints a storage report:

```sh
pc_clean
```

Use analysis mode to inspect storage without cleaning anything:

```sh
pc_clean --analyze
```

## Install

The binary committed at `../../bin/pc_clean` is built for Apple Silicon Macs. Copy it somewhere on your `PATH`:

```sh
install -m 0755 ../../bin/pc_clean "$HOME/bin/pc_clean"
```

For another architecture, install Go 1.26 or later and build it:

```sh
go build -trimpath -buildvcs=false -o pc_clean .
install -m 0755 pc_clean "$HOME/bin/pc_clean"
```

The default run expects `mole` and `mac-cleanup`. Storage reports use `dua` when available and fall back to macOS `du`.

```sh
brew install dua-cli mole
brew tap fwartner/tap
brew install fwartner/tap/mac-cleanup
```

Some optional cleanup actions also require Homebrew, Docker, pnpm, or Xcode.

Mole and [mac-cleanup](https://github.com/mac-cleanup/mac-cleanup-sh) have their own cleanup rules. Review those projects before running the default command on another Mac.

## Cleanup actions

List the available actions and preview the exact plan before applying it:

```sh
pc_clean --list
pc_clean --dry-run --only maestro-cache
pc_clean --apply --only maestro-cache
```

File cleanup moves validated targets to macOS Trash. Review Trash before emptying it. Docker volumes, Xcode Archives, Git branches, and Codex history are never removed by the low-risk actions.
