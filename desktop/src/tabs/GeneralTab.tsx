import { useState } from "react";
import { CircleAlert, CircleCheck } from "lucide-react";
import { api, type Settings, type ViewState } from "../api";
import { Confirm, Row, Section, Segmented, Switch } from "../components";
import { t, type Key } from "../i18n";

const GAPS: { value: number; label: Key }[] = [
  { value: 0, label: "gap.none" },
  { value: 8, label: "gap.narrow" },
  { value: 16, label: "gap.normal" },
  { value: 24, label: "gap.wide" },
];

/** One sentence about how Split reaches the windows in this session. */
function statusText(state: ViewState): string {
  const { kind, ready, desktop } = state.status;
  switch (kind) {
    case "windows":
      return t("backend.windows");
    case "x11":
      return t("backend.x11");
    case "gnome":
      return t(ready ? "backend.gnome.ready" : "backend.gnome.missing");
    case "kde":
      return t(ready ? "backend.kde.ready" : "backend.kde.missing");
    default:
      return t("backend.unsupported", { desktop });
  }
}

export default function GeneralTab({ state, save }: { state: ViewState; save: (s: Settings) => void }) {
  const { settings, status } = state;
  const [confirmHide, setConfirmHide] = useState(false);
  const set = (patch: Partial<Settings>) => save({ ...settings, ...patch });

  return (
    <>
      <Section>
        <Row title={t("general.launchAtLogin")} hint={t("general.launchAtLoginHint")}>
          <Switch
            label={t("general.launchAtLogin")}
            checked={settings.launchAtLogin}
            onChange={(launchAtLogin) => set({ launchAtLogin })}
          />
        </Row>
        <Row title={t("general.showTrayIcon")} hint={t("general.showTrayIconHint")}>
          <Switch
            label={t("general.showTrayIcon")}
            checked={settings.showTrayIcon}
            onChange={(showTrayIcon) => (showTrayIcon ? set({ showTrayIcon }) : setConfirmHide(true))}
          />
        </Row>
        <Row title={t("general.windowGap")} hint={t("general.windowGapHint")}>
          <Segmented
            label={t("general.windowGap")}
            value={settings.gap}
            options={GAPS.map((g) => ({ value: g.value, label: t(g.label) }))}
            onChange={(gap) => set({ gap })}
          />
        </Row>
      </Section>

      <Section title={t("general.connection")}>
        <div className="row">
          <div className={`status-icon ${status.ready ? "ok" : "warn"}`} aria-hidden>
            {status.ready ? <CircleCheck size={18} strokeWidth={1.5} /> : <CircleAlert size={18} strokeWidth={1.5} />}
          </div>
          <div className="row-text">
            <div className="row-title">{status.desktop}</div>
            <div className="row-hint">{statusText(state)}</div>
          </div>
          {!status.ready && (
            <div className="row-control">
              <button type="button" className="button" onClick={() => api.openLink("help")}>
                {t("backend.howTo")}
              </button>
            </div>
          )}
        </div>
      </Section>

      <footer className="about">
        <div className="about-title">Split</div>
        <div className="about-line">{t("general.aboutLine", { version: state.version })}</div>
        <button type="button" className="link" onClick={() => api.openLink("website")}>
          {t("general.website")}
        </button>
      </footer>

      {confirmHide && (
        <Confirm
          title={t("general.hideTrayConfirm")}
          message={t("general.hideTrayConfirmHint")}
          onCancel={() => setConfirmHide(false)}
          onConfirm={() => {
            setConfirmHide(false);
            set({ showTrayIcon: false });
          }}
        />
      )}
    </>
  );
}
