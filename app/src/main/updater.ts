// Updates for the direct-download build (not the App Store one): check once a day, download in
// the background, then ask before installing, the same as every RUNNERS app.
import { app, dialog, systemPreferences } from "electron";
import updater, { type UpdateInfo } from "electron-updater";
import type { UpdatePayload } from "../shared/types";
import { currentLanguage, t } from "./i18n.ts";
import { askToInstall, setUpdateProgress } from "./overlay.ts";

const { autoUpdater } = updater;
const DAY = 24 * 60 * 60 * 1000;
let timer: NodeJS.Timeout | null = null;
let wired = false;
/** True while a check started from the menu, so "you're up to date" is only said when asked. */
let manual = false;
/** The day "Later" was chosen; the daily check stays quiet for the rest of that day. */
let postponedOn = "";
/** The window was closed while still downloading; it comes back once the download is done. */
let reopenWhenReady = false;
let downloaded = false;

function today(): string {
  return new Date().toDateString();
}

type Notes = string | { note: string | null }[] | null | undefined;

/**
 * The "What's new" lines for one language from the GitHub release text, which has a "## 한국어"
 * and a "## English" heading, each over a "- " list (see _docs/작업 가이드/공통.md).
 * GitHub hands the text over as HTML, so tags are turned back into lines first.
 * Anything that does not follow that shape gives no lines, and the window leaves the box out.
 */
export function releaseNotes(notes: Notes, language: "ko" | "en"): string[] {
  const raw = Array.isArray(notes) ? (notes[0]?.note ?? "") : (notes ?? "");
  const text = raw
    .replace(/<h\d[^>]*>/gi, "\n## ")
    .replace(/<li[^>]*>/gi, "\n- ")
    .replace(/<\/(h\d|li|p|ul)>|<br\s*\/?>/gi, "\n")
    .replace(/<[^>]+>/g, "")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&amp;/g, "&");
  const heading = language === "ko" ? "한국어" : "english";
  const lines: string[] = [];
  let inside = false;
  for (const line of text.split("\n").map((value) => value.trim())) {
    if (line.startsWith("#")) {
      inside = line.replace(/^#+\s*/, "").toLowerCase() === heading;
    } else if (inside && line.startsWith("- ") && line.length > 2) {
      lines.push(line.slice(2).trim());
    }
  }
  return lines;
}

function payload(info: UpdateInfo, downloading: boolean): UpdatePayload {
  return {
    title: t("UpdateAvailableTitle"),
    body: t("UpdateAvailableBody", info.version.replace("+", ".")),
    changesTitle: t("UpdateChanges"),
    changes: releaseNotes(info.releaseNotes, currentLanguage().startsWith("ko") ? "ko" : "en"),
    install: t("UpdateInstall"),
    later: t("UpdateLater"),
    downloading,
    downloadingText: t("UpdateDownloading"),
    installingText: t("UpdateInstalling"),
    accent: process.platform === "darwin" ? `#${systemPreferences.getAccentColor().slice(0, 6)}` : "",
  };
}

/** Waits for the window's answer: install, or remember "Later" for the rest of the day. */
async function ask(info: UpdateInfo, downloading: boolean): Promise<void> {
  const install = await askToInstall(payload(info, downloading));
  if (install) autoUpdater.quitAndInstall();
  else if (!downloaded) reopenWhenReady = true;
  else postponedOn = today();
}

function wire(): void {
  if (wired) return;
  wired = true;
  autoUpdater.autoDownload = true;
  autoUpdater.autoInstallOnAppQuit = false;
  // Why: a check from the menu shows the window right away with a progress bar; the daily check
  // stays quiet until the download is done.
  autoUpdater.on("update-available", (info) => {
    if (!manual) return;
    manual = false;
    void ask(info, true);
  });
  autoUpdater.on("download-progress", (progress) => setUpdateProgress(progress.percent));
  autoUpdater.on("update-downloaded", (info) => {
    downloaded = true;
    if (setUpdateProgress("ready")) return;
    if (reopenWhenReady) {
      reopenWhenReady = false;
      void ask(info, false);
      return;
    }
    const asked = manual;
    manual = false;
    if (!asked && postponedOn === today()) return;
    void ask(info, false);
  });
  autoUpdater.on("update-not-available", () => {
    if (manual) void dialog.showMessageBox({ type: "info", message: t("UpdateNone"), detail: app.getVersion().replace("+", ".") });
    manual = false;
  });
  autoUpdater.on("error", (error) => {
    if (manual) void dialog.showMessageBox({ type: "warning", message: t("UpdateFailed"), detail: String(error?.message ?? error) });
    manual = false;
  });
}

/** Turns the daily check on or off; also checks once right away when turned on. */
export function startUpdater(enabled: boolean): void {
  if (!app.isPackaged) return;
  wire();
  if (timer) clearInterval(timer);
  timer = null;
  if (!enabled) return;
  void autoUpdater.checkForUpdates().catch(() => {});
  timer = setInterval(() => void autoUpdater.checkForUpdates().catch(() => {}), DAY);
}

export function checkForUpdatesNow(): void {
  if (!app.isPackaged) return;
  wire();
  manual = true;
  void autoUpdater.checkForUpdates().catch(() => {});
}
