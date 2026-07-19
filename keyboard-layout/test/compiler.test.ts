import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import test from "node:test";

import { compileFamily, verifyFamily } from "../src/compiler.js";
import {
  positions,
  type Artifact,
  type DeviceProfile,
  type InputAddress,
  type KeyboardFamily,
  type Position,
  type ToolchainPort,
} from "../src/domain.js";
import { keyboardFamily } from "../src/family.js";

function entry(deviceId: string, layer: string, position: string) {
  return compileFamily(keyboardFamily).manifests
    .find((manifest) => manifest.deviceId === deviceId)
    ?.entries.find((candidate) => candidate.layer === layer && candidate.position === position);
}

test("compiles deterministic target and manifest artifacts for all three devices", () => {
  const first = compileFamily(keyboardFamily);
  const second = compileFamily(keyboardFamily);

  assert.equal(first.ok, true);
  assert.deepEqual(first.diagnostics, []);
  assert.equal(first.manifests.length, 3);
  assert.equal(first.artifacts.length, 6);
  assert.equal(positions.length, 36);
  assert.deepEqual(first.artifacts, second.artifacts);
  assert.match(first.layoutDigest, /^[a-f0-9]{16}$/);
  assert.deepEqual(
    first.manifests.map((manifest) => manifest.deviceId),
    ["corne-qmk-wired", "corne-zmk-wireless", "macbook-built-in"],
  );

  for (const target of first.artifacts.filter((artifact) => artifact.kind === "target")) {
    const manifestArtifact = first.artifacts.find(
      (artifact) => artifact.kind === "manifest" && artifact.deviceId === target.deviceId,
    );
    assert.ok(manifestArtifact);
    const provenance = JSON.parse(manifestArtifact.content).generatedArtifact;
    assert.equal(provenance.path, target.relativePath);
    assert.equal(
      provenance.sha256,
      createHash("sha256").update(target.content).digest("hex"),
    );
  }
});

test("keeps canonical Corne thumb roles while isolating the wireless input swap", () => {
  const qmkMiddle = entry("corne-qmk-wired", "base", "left.thumb.middle");
  const qmkInner = entry("corne-qmk-wired", "base", "left.thumb.inner");
  const zmkMiddle = entry("corne-zmk-wireless", "base", "left.thumb.middle");
  const zmkInner = entry("corne-zmk-wireless", "base", "left.thumb.inner");

  assert.deepEqual(qmkMiddle?.binding, {
    kind: "tapHold",
    tap: { kind: "key", key: "backspace" },
    hold: { kind: "layer", layer: "system" },
    timing: "thumbLayer",
  });
  assert.deepEqual(qmkInner?.binding, {
    kind: "tapHold",
    tap: { kind: "key", key: "enter" },
    hold: { kind: "layer", layer: "numbers" },
    timing: "thumbLayer",
  });
  assert.equal(qmkMiddle?.input.slot, 37);
  assert.equal(qmkInner?.input.slot, 38);
  assert.equal(zmkMiddle?.input.slot, 38);
  assert.equal(zmkInner?.input.slot, 37);
});

test("preserves target-specific timings without treating them as semantic drift", () => {
  assert.equal(entry("corne-qmk-wired", "base", "left.thumb.middle")?.timing?.flavor, "default");
  assert.equal(entry("corne-zmk-wireless", "base", "left.thumb.middle")?.timing?.flavor, "tapPreferred");
  assert.equal(entry("macbook-built-in", "base", "left.home.pinky")?.timing?.tappingTermMs, 150);
});

test("routes host-only system actions through stable collision-free bridge keys", () => {
  const qmkHome = entry("corne-qmk-wired", "system", "right.home.inner");
  const zmkAppearance = entry("corne-zmk-wireless", "system", "left.top.inner");
  const macHome = entry("macbook-built-in", "system", "right.home.inner");

  assert.deepEqual(qmkHome?.capability, { route: "hostBridge", key: "f14" });
  assert.deepEqual(zmkAppearance?.capability, { route: "hostBridge", key: "f15" });
  assert.deepEqual(macHome?.capability, { route: "host" });
});

test("renders reviewable QMK, ZMK, and Karabiner outputs without secret material", () => {
  const compiled = compileFamily(keyboardFamily);
  const targets = compiled.artifacts.filter((artifact) => artifact.kind === "target");
  const qmk = targets.find((artifact) => artifact.target === "qmk")?.content ?? "";
  const zmk = targets.find((artifact) => artifact.target === "zmk")?.content ?? "";
  const karabiner = targets.find((artifact) => artifact.target === "karabiner")?.content ?? "";

  assert.match(qmk, /LT\(SYSTEM, KC_BSPC\)/);
  assert.match(qmk, /KC_F14/);
  assert.match(qmk, /if \(keycode == KC_F24\)/);
  assert.match(qmk, /case LALT_T\(KC_S\): plain_key = KC_S/);
  assert.match(qmk, /if \(!hyper_bridge_active\) return true/);
  assert.match(zmk, /&shared_lt 3 BACKSPACE/);
  assert.match(zmk, /&kp F15/);
  assert.match(zmk, /shared_hyper: shared_hyper/);
  assert.match(zmk, /&macro_press &kp F24 &mo 8/);
  assert.match(zmk, /hyper_plain \{/);
  assert.match(zmk, /&kp A  &kp S  &kp D  &kp F/);
  assert.match(karabiner, /sharedSystemLayer/);
  assert.match(karabiner, /Keyboard bridge f14 -> home/);
  assert.match(karabiner, /"input": "right_option"[\s\S]*"tap": "tab"[\s\S]*"modifier": "right_shift"/);
  assert.doesNotMatch(targets.map((artifact) => artifact.content).join("\n"), /password|token|credential/i);
});

test("reports missing physical inputs at the compiler boundary", () => {
  const [firstDevice] = keyboardFamily.devices;
  assert.ok(firstDevice);
  const positionMap: Partial<Record<Position, InputAddress>> = { ...firstDevice.positionMap };
  delete positionMap["left.thumb.inner"];
  const broken: KeyboardFamily = {
    ...keyboardFamily,
    devices: [{ ...firstDevice, positionMap: positionMap as DeviceProfile["positionMap"] }],
  };

  const compiled = compileFamily(broken);

  assert.equal(compiled.ok, false);
  assert.equal(compiled.artifacts.length, 0);
  assert.ok(compiled.diagnostics.some((diagnostic) => diagnostic.code === "device.missingInput"));
});

test("rejects host bridge key collisions", () => {
  const [qmk] = keyboardFamily.devices;
  assert.ok(qmk);
  const broken: KeyboardFamily = {
    ...keyboardFamily,
    devices: [{
      ...qmk,
      capabilities: {
        ...qmk.capabilities,
        toggleAppearance: { route: "hostBridge", key: "f14" },
      },
    }],
  };

  const compiled = compileFamily(broken);

  assert.equal(compiled.ok, false);
  assert.ok(compiled.diagnostics.some((diagnostic) => diagnostic.code === "bridge.keyCollision"));
});

test("verification delegates only target artifacts to the toolchain port", async () => {
  const seen: Artifact[] = [];
  const toolchain: ToolchainPort = {
    async verify(artifact) {
      seen.push(artifact);
      return { artifactPath: artifact.relativePath, ok: true, message: "valid" };
    },
  };

  const report = await verifyFamily(compileFamily(keyboardFamily), toolchain);

  assert.equal(report.ok, true);
  assert.equal(seen.length, 3);
  assert.ok(seen.every((artifact) => artifact.kind === "target"));
});
