// The About window (SplitAboutWindowController in SplitPreferencesController.m): app icon, name,
// version, links, the "More apps from RUNNERS" / "Services from RUNNERS" cards, and the
// copyright line with the open source notices link.
import { StrictMode, useEffect, useState } from "react";
import { createRoot } from "react-dom/client";
import type { ViewState } from "../../shared/types";
import runnersApps from "./runners-apps.json";
import noticesText from "./THIRD_PARTY_NOTICES.md?raw";
import "./about.css";

const GITHUB_URL = "https://github.com/RUNNERS-IM/split";

/** Icons of the apps and services in runners-apps.json, by item id. */
const APP_ICONS: Record<string, string> = {
  prompt: new URL("./assets/prompt.png", import.meta.url).href,
  monitor: new URL("./assets/monitor.png", import.meta.url).href,
  sense: new URL("./assets/sense.png", import.meta.url).href,
  pudding: new URL("./assets/pudding.png", import.meta.url).href,
};
const SPLIT_ICON = new URL("./assets/split-icon.png", import.meta.url).href;

type LocalText = string | { ko?: string; en: string };

interface AppItem {
  id: string;
  name: string;
  desc: LocalText;
  url: string;
}

/** The list only has Korean and English text; every other language gets the English line. */
function pick(value: LocalText, locale: string): string {
  if (typeof value === "string") return value;
  return (locale.startsWith("ko") && value.ko) || value.en;
}

/** Split itself and rows without a link are left out, like the macOS app does. */
const GROUPS = runnersApps.groups
  .map((group) => ({
    id: group.id,
    items: (group.items as AppItem[]).filter((item) => item.id !== "split" && item.url),
  }))
  .filter((group) => group.items.length > 0);

function AppIcon({ item }: { item: AppItem }) {
  const src = APP_ICONS[item.id];
  if (src) return <img className="app-icon" src={src} alt="" draggable={false} />;
  // A missing logo should not leave a hole, so the first letter stands in.
  return (
    <span className="app-icon app-letter" aria-hidden>
      {item.name.slice(0, 1)}
    </span>
  );
}

/**
 * The open source notices over the About content, like the sheet the macOS app slides down.
 * The file is Markdown; its "#" lines show as headings without the marks.
 */
function Notices({ title, close, onClose }: { title: string; close: string; onClose: () => void }) {
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape" || event.key === "Enter") onClose();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);
  const lines = noticesText.split("\n");
  return (
    <div className="notices-backdrop" role="presentation">
      <div className="notices" role="dialog" aria-modal="true" aria-labelledby="notices-title">
        <h2 id="notices-title" className="notices-title">
          {title}
        </h2>
        <div className="notices-text">
          {lines.map((line, index) => {
            const heading = /^#+ /.exec(line);
            return heading ? (
              <div key={index} className="notices-heading">
                {line.slice(heading[0].length)}
              </div>
            ) : (
              <div key={index} className="notices-line">
                {line || "\u00a0"}
              </div>
            );
          })}
        </div>
        <div className="notices-actions">
          <button type="button" className="push-button default" onClick={onClose} autoFocus>
            {close}
          </button>
        </div>
      </div>
    </div>
  );
}

/** The main process opens this page as about.html#notices (or sets that hash) to show the notices. */
function useNoticesHash(): [boolean, (open: boolean) => void] {
  const [open, setOpen] = useState(() => location.hash === "#notices");
  useEffect(() => {
    const onHash = () => setOpen(location.hash === "#notices");
    window.addEventListener("hashchange", onHash);
    return () => window.removeEventListener("hashchange", onHash);
  }, []);
  const set = (next: boolean) => {
    if (next) location.hash = "notices";
    else history.replaceState(null, "", location.pathname + location.search);
    setOpen(next);
  };
  return [open, set];
}

function About() {
  const [state, setState] = useState<ViewState | null>(null);
  const [noticesOpen, setNoticesOpen] = useNoticesHash();

  useEffect(() => {
    window.split.getState().then(setState);
    return window.split.onState(setState);
  }, []);

  const strings = state?.strings ?? {};
  const text = (key: string) => strings[key] ?? key;

  useEffect(() => {
    if (!state) return;
    document.title = text("AboutSplit");
    document.documentElement.lang = state.locale;
    // The main process waits for this before sizing the window to the content.
    const images = Array.from(document.images).map((image) => image.decode().catch(() => undefined));
    Promise.all(images).then(() => {
      document.body.dataset.ready = "1";
    });
  }, [state]);

  if (!state) return null;
  const versionLine = text("AboutLine").replace("%@", state.version);
  return (
    <main className="about">
      <div className="drag-strip" />
      <header className="about-header">
        <img className="about-icon" src={SPLIT_ICON} alt="" draggable={false} />
        <h1 className="about-name">Split</h1>
        <p className="about-version">{versionLine}</p>
        <div className="about-links">
          <button type="button" className="push-button" onClick={() => window.split.openLink("website")}>
            {text("Website")}
          </button>
          <a className="push-button" href={GITHUB_URL} target="_blank" rel="noreferrer">
            GitHub
          </a>
        </div>
      </header>

      {GROUPS.map((group) => (
        <section key={group.id} className="apps-group" aria-labelledby={`apps-${group.id}`}>
          <h2 id={`apps-${group.id}`} className="apps-title">
            {text(group.id === "services" ? "RunnersServicesTitle" : "RunnersAppsTitle")}
          </h2>
          <ul className="card">
            {group.items.map((item) => (
              <li key={item.id} className="app-row">
                <AppIcon item={item} />
                <div className="app-text">
                  <div className="app-name">{item.name}</div>
                  <div className="app-desc">{pick(item.desc, state.locale)}</div>
                </div>
                <a
                  className="push-button small"
                  href={item.url}
                  target="_blank"
                  rel="noreferrer"
                  aria-label={`${text("RunnersGet")} ${item.name}`}
                >
                  {text("RunnersGet")}
                </a>
              </li>
            ))}
          </ul>
        </section>
      ))}

      <footer className="credit">
        <span>© 2026 RUNNERS. All rights reserved. ·</span>
        <button type="button" className="link-button" onClick={() => setNoticesOpen(true)}>
          {text("OpenSourceNotices")}
        </button>
      </footer>
      {noticesOpen && (
        <Notices title={text("OpenSourceNotices")} close={text("Close")} onClose={() => setNoticesOpen(false)} />
      )}
    </main>
  );
}

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <About />
  </StrictMode>,
);
