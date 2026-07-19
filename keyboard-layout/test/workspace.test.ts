import assert from "node:assert/strict";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import { compileFamily } from "../src/compiler.js";
import { keyboardFamily } from "../src/family.js";
import { planSync, writeSync } from "../src/workspace.js";

test("plans and writes generated artifacts without touching unmanaged files", async (context) => {
  const root = await mkdtemp(join(tmpdir(), "keyboard-layout-"));
  context.after(async () => rm(root, { recursive: true, force: true }));
  const roots = {
    dotfiles: join(root, "dotfiles"),
    qmk: join(root, "qmk"),
    zmk: join(root, "zmk"),
  };
  const compiled = compileFamily(keyboardFamily);

  const before = await planSync(compiled, roots);
  assert.equal(before.ok, true);
  assert.ok(before.items.every((item) => item.status === "create"));

  const changed = await writeSync(before);
  assert.equal(changed.length, 6);
  assert.match(
    await readFile(join(roots.qmk, "keyboards/crkbd/keymaps/g33km44n38/keymap.c"), "utf8"),
    /Do not edit/,
  );

  const after = await planSync(compiled, roots);
  assert.ok(after.items.every((item) => item.status === "clean"));
});
