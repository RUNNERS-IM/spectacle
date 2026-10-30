// Screen text for the settings page and the move highlight. The tray menu in Rust reads the same
// files in `locales/`. The macOS app's 18 languages are the long-term target; add a file per
// language next to these two and list it in `tables`.
import en from "../locales/en.json";
import ko from "../locales/ko.json";

export type Key = keyof typeof en;

const tables: Record<string, Record<string, string>> = { en, ko };

function pickLanguage(): string {
  for (const language of navigator.languages ?? [navigator.language]) {
    const base = language.toLowerCase().split("-")[0];
    if (tables[base]) return base;
  }
  return "en";
}

export const language = pickLanguage();
const table = tables[language];

/** Looks up `key` and fills `{{name}}` slots; a missing key shows the key itself so it is easy to spot. */
export function t(key: Key, args: Record<string, string | number> = {}): string {
  let text = table[key] ?? en[key] ?? key;
  for (const [name, value] of Object.entries(args)) {
    text = text.replaceAll(`{{${name}}}`, String(value));
  }
  return text;
}

/** For keys built at run time, such as `action.MoveToLeftHalf`. */
export function tDynamic(key: string, args: Record<string, string | number> = {}): string {
  return t(key as Key, args);
}
