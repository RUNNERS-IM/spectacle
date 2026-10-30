// The Accessibility guide (SplitAccessibilityGuideController.m): icon, title, a picture of the switch
// to turn on, Later / Open System Settings, and a status line that turns green once permission arrives.
import { StrictMode, useEffect, useState } from "react";
import { createRoot } from "react-dom/client";
import type { ViewState } from "../../shared/types";
import "../runners-window.css";
import "./guide.css";

const SPLIT_ICON = new URL("../about/assets/split-icon.png", import.meta.url).href;
const PICTURES: Record<string, string> = {
  "light-en": new URL("./assets/GuideSettings-en.png", import.meta.url).href,
  "light-ko": new URL("./assets/GuideSettings-ko.png", import.meta.url).href,
  "dark-en": new URL("./assets/GuideSettingsDark-en.png", import.meta.url).href,
  "dark-ko": new URL("./assets/GuideSettingsDark-ko.png", import.meta.url).href,
};

const darkQuery = window.matchMedia("(prefers-color-scheme: dark)");

function App({ initial }: { initial: ViewState }) {
  const [state, setState] = useState(initial);
  const [dark, setDark] = useState(darkQuery.matches);
  useEffect(() => window.split.onState(setState), []);
  useEffect(() => {
    const onChange = () => setDark(darkQuery.matches);
    darkQuery.addEventListener("change", onChange);
    return () => darkQuery.removeEventListener("change", onChange);
  }, []);
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") void window.split.guideLater();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);
  const t = (key: string) => state.strings[key] ?? key;
  // The picture shows the System Settings list in Korean or English; other languages get English.
  const picture = PICTURES[`${dark ? "dark" : "light"}-${state.locale.startsWith("ko") ? "ko" : "en"}`];
  return (
    <div className="guide">
      <img className="guide-icon" src={SPLIT_ICON} alt="" draggable={false} />
      <h1>{t("AccessibilityGuide.Title")}</h1>
      <p className="guide-description">{t("AccessibilityGuide.Description")}</p>
      <img className="guide-picture" src={picture} alt="" draggable={false} />
      <div className="buttons">
        <button type="button" className="rw-button" onClick={() => void window.split.guideLater()}>
          {t("AccessibilityGuide.ButtonLater")}
        </button>
        <button type="button" className="rw-button default" autoFocus onClick={() => void window.split.openLink("accessibility")}>
          {t("AccessibilityGuide.ButtonOpenSettings")}
        </button>
      </div>
      <p className={`status ${state.trusted ? "granted" : "waiting"}`} role="status">
        <span className="status-dot" />
        {t(state.trusted ? "AccessibilityGuide.StatusGranted" : "AccessibilityGuide.StatusWaiting")}
      </p>
      {/* Why: the App Store build can't run tccutil, so the reset link only exists in the direct build. */}
      {!state.store && !state.trusted && (
        <button type="button" className="link" onClick={() => void window.split.guideReset()}>
          {t("AccessibilityGuide.ButtonReset")}
        </button>
      )}
    </div>
  );
}

void window.split.getState().then((state) => {
  document.title = state.strings["AccessibilityGuide.WindowTitle"] ?? "Split";
  createRoot(document.getElementById("root")!).render(
    <StrictMode>
      <App initial={state} />
    </StrictMode>,
  );
});
