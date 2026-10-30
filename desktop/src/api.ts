// Calls into the Rust side (`src-tauri/src/lib.rs`). The shapes match the Rust structs.
import { invoke } from "@tauri-apps/api/core";

export type FeedbackSettings = {
  style: "off" | "subtle" | "strong";
  color: "accent" | "blue" | "purple" | "pink" | "orange" | "green" | "gray";
  showShortcut: boolean;
  duration: "short" | "normal" | "long";
  position: "bottom" | "top" | "center";
};

export type Settings = {
  gap: number;
  launchAtLogin: boolean;
  showTrayIcon: boolean;
  feedback: FeedbackSettings;
  /** Action name → shortcut such as "alt+super+left"; a missing action uses the default, null means cleared. */
  shortcuts: Record<string, string | null>;
};

export type Status = {
  kind: "windows" | "x11" | "gnome" | "kde" | "unsupported";
  ready: boolean;
  desktop: string;
  ownsShortcuts: boolean;
  canShowOverlay: boolean;
};

export type ViewState = {
  settings: Settings;
  defaults: Record<string, string>;
  sections: [string, string[]][];
  status: Status;
  failures: string[];
  version: string;
  platform: "windows" | "linux";
};

export const api = {
  getState: () => invoke<ViewState>("get_state"),
  saveSettings: (settings: Settings) => invoke<ViewState>("save_settings", { settings }),
  restoreDefaultShortcuts: () => invoke<ViewState>("restore_default_shortcuts"),
  setRecording: (recording: boolean) => invoke<void>("set_recording", { recording }),
  previewFeedback: () => invoke<void>("preview_feedback"),
  openLink: (kind: "website" | "help" | "releases" | "issues") => invoke<void>("open_link", { kind }),
};

/** The shortcut in effect for `action`. */
export function shortcutFor(state: ViewState, action: string): string | null {
  const value = state.settings.shortcuts[action];
  return value === undefined ? (state.defaults[action] ?? null) : value;
}
