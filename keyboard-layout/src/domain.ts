export const layerIds = [
  "base",
  "numbers",
  "symbols",
  "system",
  "functions",
] as const;

export const positions = [
  "left.top.pinky",
  "left.top.ring",
  "left.top.middle",
  "left.top.index",
  "left.top.inner",
  "right.top.inner",
  "right.top.index",
  "right.top.middle",
  "right.top.ring",
  "right.top.pinky",
  "left.home.pinky",
  "left.home.ring",
  "left.home.middle",
  "left.home.index",
  "left.home.inner",
  "right.home.inner",
  "right.home.index",
  "right.home.middle",
  "right.home.ring",
  "right.home.pinky",
  "left.bottom.pinky",
  "left.bottom.ring",
  "left.bottom.middle",
  "left.bottom.index",
  "left.bottom.inner",
  "right.bottom.inner",
  "right.bottom.index",
  "right.bottom.middle",
  "right.bottom.ring",
  "right.bottom.pinky",
  "left.thumb.outer",
  "left.thumb.middle",
  "left.thumb.inner",
  "right.thumb.inner",
  "right.thumb.middle",
  "right.thumb.outer",
] as const;

export const keyIds = [
  "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
  "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
  "digit0", "digit1", "digit2", "digit3", "digit4", "digit5", "digit6",
  "digit7", "digit8", "digit9", "backspace", "enter", "space", "tab",
  "semicolon", "quote", "comma", "dot", "slash", "backslash", "tilde",
  "grave", "minus", "underscore", "plus", "equals", "pipe", "leftBracket",
  "rightBracket", "leftBrace", "rightBrace", "leftParen", "rightParen",
  "left", "down", "up", "right", "f1", "f2", "f3", "f4", "f5", "f6",
  "f7", "f8", "f9", "f10", "f14", "f15", "f16", "f17", "f21", "f22",
] as const;

export const modifierIds = [
  "leftGui",
  "leftAlt",
  "leftShift",
  "leftControl",
  "rightControl",
  "rightShift",
  "rightAlt",
  "rightGui",
] as const;

export const systemActions = [
  "brightnessDown",
  "brightnessUp",
  "controlCenter",
  "home",
  "lockScreen",
  "mute",
  "notificationCenter",
  "toggleAppearance",
  "volumeDown",
  "volumeUp",
] as const;

export type LayerId = (typeof layerIds)[number];
export type Position = (typeof positions)[number];
export type KeyId = (typeof keyIds)[number];
export type ModifierId = (typeof modifierIds)[number];
export type SystemAction = (typeof systemActions)[number];
export type Target = "qmk" | "zmk" | "karabiner";
export type RepositoryId = "qmk" | "zmk" | "dotfiles";
export type TimingRole = "homeRow" | "thumbLayer" | "shiftTab";

export type Intent =
  | Readonly<{ kind: "key"; key: KeyId }>
  | Readonly<{ kind: "modifier"; modifier: ModifierId }>
  | Readonly<{ kind: "layer"; layer: LayerId }>
  | Readonly<{ kind: "system"; action: SystemAction }>
  | Readonly<{ kind: "hyper" }>
  | Readonly<{ kind: "transparent" }>
  | Readonly<{ kind: "disabled" }>;

export type Binding =
  | Readonly<{ kind: "emit"; intent: Intent }>
  | Readonly<{
      kind: "tapHold";
      tap: Intent;
      hold: Intent;
      timing: TimingRole;
    }>;

export type Layer = Readonly<Partial<Record<Position, Binding>>>;

export interface ErgonomicLayout {
  readonly id: string;
  readonly layers: Readonly<Record<LayerId, Layer>>;
}

export interface TapHoldTiming {
  readonly tappingTermMs: number;
  readonly aloneTimeoutMs?: number;
  readonly quickTapMs?: number;
  readonly flavor: "default" | "balanced" | "tapPreferred";
  readonly permissiveHold?: boolean;
}

export type Capability =
  | Readonly<{ route: "native" }>
  | Readonly<{ route: "host" }>
  | Readonly<{ route: "hostBridge"; key: KeyId }>
  | Readonly<{ route: "unsupported"; reason: string }>;

export interface InputAddress {
  readonly id: string;
  readonly label: string;
  readonly slot?: number;
}

export interface DeviceAdjustment {
  readonly kind: "swapInputs";
  readonly positions: readonly [Position, Position];
  readonly reason: string;
}

export interface LayerTrigger {
  readonly input: string;
  readonly tap?: KeyId;
  readonly mode: "hold" | "chord";
}

export interface DeviceProfile {
  readonly id: string;
  readonly name: string;
  readonly target: Target;
  readonly repository: RepositoryId;
  readonly positionMap: Readonly<Record<Position, InputAddress>>;
  readonly timings: Readonly<Record<TimingRole, TapHoldTiming>>;
  readonly capabilities: Readonly<Record<SystemAction, Capability>>;
  readonly layerTriggers: Readonly<Partial<Record<LayerId, LayerTrigger>>>;
  readonly adjustments: readonly DeviceAdjustment[];
}

export interface KeyboardFamily {
  readonly id: string;
  readonly layout: ErgonomicLayout;
  readonly devices: readonly DeviceProfile[];
}

export interface Diagnostic {
  readonly code: string;
  readonly severity: "error" | "warning";
  readonly message: string;
  readonly deviceId?: string;
  readonly layer?: LayerId;
  readonly position?: Position;
}

export interface ManifestEntry {
  readonly layer: LayerId;
  readonly position: Position;
  readonly input: InputAddress;
  readonly binding: Binding;
  readonly capability?: Capability;
  readonly timing?: TapHoldTiming;
}

export interface DeviceManifest {
  readonly familyId: string;
  readonly layoutDigest: string;
  readonly deviceId: string;
  readonly deviceName: string;
  readonly target: Target;
  readonly adjustments: readonly DeviceAdjustment[];
  readonly entries: readonly ManifestEntry[];
}

export interface Artifact {
  readonly kind: "target" | "manifest";
  readonly repository: RepositoryId;
  readonly target: Target;
  readonly deviceId: string;
  readonly relativePath: string;
  readonly content: string;
}

export interface CompiledFamily {
  readonly ok: boolean;
  readonly familyId: string;
  readonly layoutDigest: string;
  readonly manifests: readonly DeviceManifest[];
  readonly artifacts: readonly Artifact[];
  readonly diagnostics: readonly Diagnostic[];
}

export interface ToolchainCheck {
  readonly artifactPath: string;
  readonly ok: boolean;
  readonly message: string;
}

export interface ToolchainPort {
  verify(artifact: Artifact): Promise<ToolchainCheck>;
}

export interface VerificationReport {
  readonly ok: boolean;
  readonly checks: readonly ToolchainCheck[];
  readonly diagnostics: readonly Diagnostic[];
}

export const key = (value: KeyId): Intent => ({ kind: "key", key: value });
export const modifier = (value: ModifierId): Intent => ({
  kind: "modifier",
  modifier: value,
});
export const layer = (value: LayerId): Intent => ({ kind: "layer", layer: value });
export const system = (value: SystemAction): Intent => ({
  kind: "system",
  action: value,
});
export const hyper = (): Intent => ({ kind: "hyper" });
export const transparent = (): Binding => ({
  kind: "emit",
  intent: { kind: "transparent" },
});
export const disabled = (): Binding => ({
  kind: "emit",
  intent: { kind: "disabled" },
});
export const emit = (intent: Intent): Binding => ({ kind: "emit", intent });
export const tapHold = (
  tap: Intent,
  hold: Intent,
  timing: TimingRole,
): Binding => ({ kind: "tapHold", tap, hold, timing });
