#!/usr/bin/env node

import { resolve } from "node:path";

import { compileFamily } from "./compiler.js";
import { keyboardFamily } from "./family.js";
import { planSync, writeSync, type RepositoryRoots } from "./workspace.js";

function usage(): void {
  console.log(`Usage: keyboard-layout <command> [options]

Commands:
  check                 Validate the canonical family and render all targets
  manifest              Print semantic manifests
  sync --check          Report drift across all three repositories
  sync --write          Write only generated artifacts

Sync options:
  --dotfiles-repo PATH  Defaults to KEYBOARD_DOTFILES_REPO or the current directory
  --qmk-repo PATH       Defaults to KEYBOARD_QMK_REPO
  --zmk-repo PATH       Defaults to KEYBOARD_ZMK_REPO

This command cannot flash, commit, push, or open pull requests.`);
}

function option(name: string): string | undefined {
  const index = process.argv.indexOf(name);
  return index === -1 ? undefined : process.argv[index + 1];
}

function roots(): RepositoryRoots {
  const dotfiles = option("--dotfiles-repo") ?? process.env.KEYBOARD_DOTFILES_REPO ?? process.cwd();
  const qmk = option("--qmk-repo") ?? process.env.KEYBOARD_QMK_REPO;
  const zmk = option("--zmk-repo") ?? process.env.KEYBOARD_ZMK_REPO;
  if (qmk === undefined || zmk === undefined) {
    throw new Error("sync requires --qmk-repo and --zmk-repo (or KEYBOARD_QMK_REPO/KEYBOARD_ZMK_REPO).");
  }
  return { dotfiles: resolve(dotfiles), qmk: resolve(qmk), zmk: resolve(zmk) };
}

function printCompilation(): ReturnType<typeof compileFamily> {
  const compiled = compileFamily(keyboardFamily);
  console.log(
    `${compiled.ok ? "PASS" : "FAIL"} ${compiled.familyId} ${compiled.layoutDigest}: ` +
      `${compiled.manifests.length} devices, ${compiled.artifacts.length} artifacts`,
  );
  for (const diagnostic of compiled.diagnostics) {
    console.log(`${diagnostic.severity.toUpperCase()} ${diagnostic.code}: ${diagnostic.message}`);
  }
  return compiled;
}

async function sync(): Promise<void> {
  const compiled = printCompilation();
  const plan = await planSync(compiled, roots());
  for (const item of plan.items) {
    console.log(`${item.status.toUpperCase().padEnd(6)} ${item.artifact.repository}:${item.artifact.relativePath}`);
  }
  for (const error of plan.errors) console.error(`ERROR ${error}`);
  if (!plan.ok) {
    process.exitCode = 1;
    return;
  }
  const write = process.argv.includes("--write");
  if (write) {
    const changed = await writeSync(plan);
    console.log(`WROTE ${changed.length} generated artifact(s). No firmware was flashed.`);
    return;
  }
  const drift = plan.items.some((item) => item.status !== "clean");
  if (!process.argv.includes("--check")) console.log("Dry run. Pass --write to apply generated artifacts.");
  process.exitCode = drift ? 1 : 0;
}

async function main(): Promise<void> {
  const command = process.argv[2] ?? "check";
  if (command === "check") {
    const compiled = printCompilation();
    process.exitCode = compiled.ok ? 0 : 1;
    return;
  }
  if (command === "manifest") {
    const compiled = compileFamily(keyboardFamily);
    console.log(JSON.stringify(compiled.manifests, null, 2));
    process.exitCode = compiled.ok ? 0 : 1;
    return;
  }
  if (command === "sync") {
    await sync();
    return;
  }
  if (["help", "--help", "-h"].includes(command)) {
    usage();
    return;
  }
  usage();
  process.exitCode = 2;
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
