// Shortcut text, the same format as `split-core/src/shortcuts.rs`: modifiers in the order
// ctrl, alt, shift, super, then one key, joined with "+".

const KEY_BY_CODE: Record<string, string> = {
  ArrowLeft: "left",
  ArrowRight: "right",
  ArrowUp: "up",
  ArrowDown: "down",
  Space: "space",
  Enter: "enter",
  Tab: "tab",
  Backspace: "backspace",
  Delete: "delete",
  Insert: "insert",
  Home: "home",
  End: "end",
  PageUp: "pageup",
  PageDown: "pagedown",
  Minus: "minus",
  Equal: "equal",
  BracketLeft: "bracketleft",
  BracketRight: "bracketright",
  Semicolon: "semicolon",
  Quote: "quote",
  Comma: "comma",
  Period: "period",
  Slash: "slash",
  Backslash: "backslash",
  Backquote: "grave",
};

const KEY_LABEL: Record<string, string> = {
  left: "←",
  right: "→",
  up: "↑",
  down: "↓",
  space: "Space",
  enter: "Enter",
  tab: "Tab",
  backspace: "Backspace",
  delete: "Delete",
  insert: "Insert",
  home: "Home",
  end: "End",
  pageup: "PageUp",
  pagedown: "PageDown",
  minus: "-",
  equal: "=",
  bracketleft: "[",
  bracketright: "]",
  semicolon: ";",
  quote: "'",
  comma: ",",
  period: ".",
  slash: "/",
  backslash: "\\",
  grave: "`",
};

/** The key name for a keyboard event, or null for a modifier on its own or an unknown key. */
function keyName(code: string): string | null {
  if (/^Key[A-Z]$/.test(code)) return code.slice(3).toLowerCase();
  if (/^Digit[0-9]$/.test(code)) return code.slice(5);
  if (/^F([1-9]|1[0-9]|2[0-4])$/.test(code)) return code.toLowerCase();
  return KEY_BY_CODE[code] ?? null;
}

/** Turns a key press into shortcut text, or null when it is not a usable shortcut yet. */
export function shortcutFromEvent(event: KeyboardEvent): string | null {
  const key = keyName(event.code);
  if (!key) return null;
  // Like the Rust side: a shortcut needs ctrl, alt or super, or it would swallow normal typing.
  if (!(event.ctrlKey || event.altKey || event.metaKey)) return null;
  const parts: string[] = [];
  if (event.ctrlKey) parts.push("ctrl");
  if (event.altKey) parts.push("alt");
  if (event.shiftKey) parts.push("shift");
  if (event.metaKey) parts.push("super");
  parts.push(key);
  return parts.join("+");
}

/** How a shortcut is written on this platform, for example "Win+Alt+←" or "Super+Alt+←". */
export function displayShortcut(text: string | null, platform: "windows" | "linux"): string {
  if (!text) return "";
  const parts = text.split("+");
  const key = parts[parts.length - 1];
  const has = (name: string) => parts.includes(name);
  const out: string[] = [];
  if (has("super")) out.push(platform === "windows" ? "Win" : "Super");
  if (has("ctrl")) out.push("Ctrl");
  if (has("alt")) out.push("Alt");
  if (has("shift")) out.push("Shift");
  out.push(KEY_LABEL[key] ?? key.toUpperCase());
  return out.join("+");
}
