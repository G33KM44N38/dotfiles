import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, isAbsolute, relative, resolve } from "node:path";

import type { Artifact, CompiledFamily, RepositoryId } from "./domain.js";

export interface RepositoryRoots {
  readonly dotfiles: string;
  readonly qmk: string;
  readonly zmk: string;
}

export interface SyncItem {
  readonly artifact: Artifact;
  readonly path: string;
  readonly status: "clean" | "create" | "update";
}

export interface SyncPlan {
  readonly ok: boolean;
  readonly items: readonly SyncItem[];
  readonly errors: readonly string[];
}

function artifactPath(root: string, artifact: Artifact): string {
  const path = resolve(root, artifact.relativePath);
  const fromRoot = relative(resolve(root), path);
  if (fromRoot.startsWith("..") || isAbsolute(fromRoot)) {
    throw new Error(`${artifact.relativePath} escapes ${root}`);
  }
  return path;
}

async function existingContent(path: string): Promise<string | undefined> {
  try {
    return await readFile(path, "utf8");
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") return undefined;
    throw error;
  }
}

export async function planSync(
  compiled: CompiledFamily,
  roots: RepositoryRoots,
): Promise<SyncPlan> {
  const items: SyncItem[] = [];
  const errors: string[] = [];
  if (!compiled.ok) errors.push("The keyboard family does not compile.");
  for (const artifact of compiled.artifacts) {
    try {
      const root = roots[artifact.repository as RepositoryId];
      const path = artifactPath(root, artifact);
      const current = await existingContent(path);
      items.push({
        artifact,
        path,
        status: current === undefined ? "create" : current === artifact.content ? "clean" : "update",
      });
    } catch (error) {
      errors.push(error instanceof Error ? error.message : String(error));
    }
  }
  return { ok: errors.length === 0, items, errors };
}

export async function writeSync(plan: SyncPlan): Promise<readonly SyncItem[]> {
  if (!plan.ok) throw new Error(plan.errors.join("\n"));
  const changed = plan.items.filter((item) => item.status !== "clean");
  for (const item of changed) {
    await mkdir(dirname(item.path), { recursive: true });
    await writeFile(item.path, item.artifact.content, "utf8");
  }
  return changed;
}
