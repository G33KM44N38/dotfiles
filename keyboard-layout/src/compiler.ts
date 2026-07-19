import { createHash } from "node:crypto";

import {
  layerIds,
  positions,
  transparent,
  type Artifact,
  type Binding,
  type CompiledFamily,
  type DeviceManifest,
  type DeviceProfile,
  type Diagnostic,
  type KeyboardFamily,
  type KeyId,
  type LayerId,
  type ManifestEntry,
  type Position,
  type SystemAction,
  type ToolchainPort,
  type VerificationReport,
} from "./domain.js";
import { renderQmk, renderZmk } from "./render-firmware.js";
import { renderKarabiner } from "./render-karabiner.js";

function familyDigest(family: KeyboardFamily): string {
  return createHash("sha256").update(JSON.stringify(family)).digest("hex").slice(0, 16);
}

function referencedLayer(binding: Binding): LayerId | undefined {
  if (binding.kind === "emit") {
    return binding.intent.kind === "layer" ? binding.intent.layer : undefined;
  }
  return binding.hold.kind === "layer" ? binding.hold.layer : undefined;
}

function systemAction(binding: Binding): SystemAction | undefined {
  if (binding.kind !== "emit" || binding.intent.kind !== "system") return undefined;
  return binding.intent.action;
}

function validateLayout(family: KeyboardFamily): Diagnostic[] {
  const diagnostics: Diagnostic[] = [];
  for (const position of positions) {
    if (family.layout.layers.base[position] === undefined) {
      diagnostics.push({
        code: "layout.incompleteBase",
        severity: "error",
        message: `Base layer is missing ${position}.`,
        layer: "base",
        position,
      });
    }
  }
  for (const layer of layerIds) {
    for (const [position, binding] of Object.entries(family.layout.layers[layer]) as [Position, Binding][]) {
      if (!positions.includes(position)) {
        diagnostics.push({
          code: "layout.unknownPosition",
          severity: "error",
          message: `${layer}.${position} is outside the shared topology.`,
          layer,
          position,
        });
      }
      const referenced = referencedLayer(binding);
      if (referenced !== undefined && !layerIds.includes(referenced)) {
        diagnostics.push({
          code: "layout.unknownLayer",
          severity: "error",
          message: `${layer}.${position} references ${referenced}.`,
          layer,
          position,
        });
      }
    }
  }
  return diagnostics;
}

function validateDevice(profile: DeviceProfile): Diagnostic[] {
  const diagnostics: Diagnostic[] = [];
  const inputs = new Map<string, Position>();
  const slots = new Map<number, Position>();
  for (const position of positions) {
    const input = profile.positionMap[position];
    if (input === undefined) {
      diagnostics.push({
        code: "device.missingInput",
        severity: "error",
        message: `${profile.name} has no input for ${position}.`,
        deviceId: profile.id,
        position,
      });
      continue;
    }
    const duplicateInput = inputs.get(input.id);
    if (duplicateInput !== undefined) {
      diagnostics.push({
        code: "device.duplicateInput",
        severity: "error",
        message: `${input.id} maps both ${duplicateInput} and ${position}.`,
        deviceId: profile.id,
        position,
      });
    }
    inputs.set(input.id, position);
    if (input.slot !== undefined) {
      const duplicateSlot = slots.get(input.slot);
      if (duplicateSlot !== undefined) {
        diagnostics.push({
          code: "device.duplicateSlot",
          severity: "error",
          message: `Slot ${input.slot} maps both ${duplicateSlot} and ${position}.`,
          deviceId: profile.id,
          position,
        });
      }
      slots.set(input.slot, position);
    }
  }
  return diagnostics;
}

function bridgeKeys(
  family: KeyboardFamily,
  diagnostics: Diagnostic[],
): Partial<Record<SystemAction, KeyId>> {
  const byAction: Partial<Record<SystemAction, KeyId>> = {};
  const byKey = new Map<KeyId, SystemAction>();
  for (const profile of family.devices) {
    for (const [action, capability] of Object.entries(profile.capabilities) as [SystemAction, DeviceProfile["capabilities"][SystemAction]][]) {
      if (capability.route !== "hostBridge") continue;
      const existingKey = byAction[action];
      if (existingKey !== undefined && existingKey !== capability.key) {
        diagnostics.push({
          code: "bridge.inconsistentKey",
          severity: "error",
          message: `${action} uses both ${existingKey} and ${capability.key}.`,
          deviceId: profile.id,
        });
      }
      const existingAction = byKey.get(capability.key);
      if (existingAction !== undefined && existingAction !== action) {
        diagnostics.push({
          code: "bridge.keyCollision",
          severity: "error",
          message: `${capability.key} is reserved for ${existingAction} and ${action}.`,
          deviceId: profile.id,
        });
      }
      byAction[action] = capability.key;
      byKey.set(capability.key, action);
    }
  }
  for (const bindings of Object.values(family.layout.layers)) {
    for (const binding of Object.values(bindings)) {
      if (binding?.kind === "emit" && binding.intent.kind === "key") {
        const action = byKey.get(binding.intent.key);
        if (action !== undefined) {
          diagnostics.push({
            code: "bridge.layoutCollision",
            severity: "error",
            message: `${binding.intent.key} is both a layout key and the bridge for ${action}.`,
          });
        }
      }
    }
  }
  return byAction;
}

function compileManifest(
  family: KeyboardFamily,
  profile: DeviceProfile,
  digest: string,
): DeviceManifest {
  const entries: ManifestEntry[] = [];
  for (const layer of layerIds) {
    for (const position of positions) {
      const binding = family.layout.layers[layer][position] ?? transparent();
      const action = systemAction(binding);
      entries.push({
        layer,
        position,
        input: profile.positionMap[position],
        binding,
        ...(binding.kind === "tapHold" ? { timing: profile.timings[binding.timing] } : {}),
        ...(action === undefined ? {} : { capability: profile.capabilities[action] }),
      });
    }
  }
  return {
    familyId: family.id,
    layoutDigest: digest,
    deviceId: profile.id,
    deviceName: profile.name,
    target: profile.target,
    adjustments: profile.adjustments,
    entries,
  };
}

function targetArtifact(
  profile: DeviceProfile,
  manifest: DeviceManifest,
  bridges: Readonly<Partial<Record<SystemAction, KeyId>>>,
): Artifact {
  if (profile.target === "qmk") {
    return {
      kind: "target", repository: profile.repository, target: profile.target,
      deviceId: profile.id,
      relativePath: "keyboards/crkbd/keymaps/g33km44n38/keymap.c",
      content: renderQmk(manifest, profile),
    };
  }
  if (profile.target === "zmk") {
    return {
      kind: "target", repository: profile.repository, target: profile.target,
      deviceId: profile.id, relativePath: "config/generated/shared-layout.dtsi",
      content: renderZmk(manifest, profile),
    };
  }
  return {
    kind: "target", repository: profile.repository, target: profile.target,
    deviceId: profile.id, relativePath: ".config/karabiner/generated/shared-layout.ts",
    content: renderKarabiner(manifest, profile, bridges),
  };
}

function manifestArtifact(
  profile: DeviceProfile,
  manifest: DeviceManifest,
  generatedArtifact: Artifact,
): Artifact {
  const relativePath = profile.target === "karabiner"
    ? ".config/karabiner/generated/manifest.json"
    : ".keyboard-layout.json";
  const content = {
    ...manifest,
    generatedArtifact: {
      path: generatedArtifact.relativePath,
      sha256: createHash("sha256").update(generatedArtifact.content).digest("hex"),
    },
  };
  return {
    kind: "manifest",
    repository: profile.repository,
    target: profile.target,
    deviceId: profile.id,
    relativePath,
    content: `${JSON.stringify(content, null, 2)}\n`,
  };
}

export function compileFamily(family: KeyboardFamily): CompiledFamily {
  const diagnostics = validateLayout(family);
  const deviceIds = new Set<string>();
  for (const profile of family.devices) {
    if (deviceIds.has(profile.id)) {
      diagnostics.push({
        code: "family.duplicateDevice",
        severity: "error",
        message: `Device ${profile.id} is declared more than once.`,
        deviceId: profile.id,
      });
    }
    deviceIds.add(profile.id);
    diagnostics.push(...validateDevice(profile));
  }
  const bridges = bridgeKeys(family, diagnostics);
  const digest = familyDigest(family);
  const profiles = [...family.devices].sort((left, right) => left.id.localeCompare(right.id));
  const manifests = profiles.map((profile) => compileManifest(family, profile, digest));
  const artifacts: Artifact[] = [];
  if (!diagnostics.some((diagnostic) => diagnostic.severity === "error")) {
    for (const [index, profile] of profiles.entries()) {
      const manifest = manifests[index];
      try {
        if (manifest === undefined) {
          throw new Error(`Missing compiled manifest for ${profile.id}.`);
        }
        const target = targetArtifact(profile, manifest, bridges);
        artifacts.push(target);
        artifacts.push(manifestArtifact(profile, manifest, target));
      } catch (error) {
        diagnostics.push({
          code: "render.failed",
          severity: "error",
          message: error instanceof Error ? error.message : String(error),
          deviceId: profile.id,
        });
      }
    }
  }
  return {
    ok: !diagnostics.some((diagnostic) => diagnostic.severity === "error"),
    familyId: family.id,
    layoutDigest: digest,
    manifests,
    artifacts,
    diagnostics,
  };
}

export async function verifyFamily(
  compiled: CompiledFamily,
  toolchain: ToolchainPort,
): Promise<VerificationReport> {
  const checks = await Promise.all(
    compiled.artifacts
      .filter((artifact) => artifact.kind === "target")
      .map((artifact) => toolchain.verify(artifact)),
  );
  return {
    ok: compiled.ok && checks.every((check) => check.ok),
    checks,
    diagnostics: compiled.diagnostics,
  };
}
