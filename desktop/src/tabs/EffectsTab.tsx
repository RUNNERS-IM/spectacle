import { api, type FeedbackSettings, type Settings, type ViewState } from "../api";
import { Row, Section, Segmented, Switch } from "../components";
import { t, type Key } from "../i18n";

export const COLORS: Record<FeedbackSettings["color"], string> = {
  accent: "var(--accent)",
  blue: "#007aff",
  purple: "#af52de",
  pink: "#ff2d55",
  orange: "#ff9500",
  green: "#34c759",
  gray: "#8e8e93",
};

const STYLES: FeedbackSettings["style"][] = ["off", "subtle", "strong"];
const DURATIONS: FeedbackSettings["duration"][] = ["short", "normal", "long"];
const POSITIONS: FeedbackSettings["position"][] = ["bottom", "top", "center"];

export default function EffectsTab({ state, save }: { state: ViewState; save: (s: Settings) => Promise<void> }) {
  const feedback = state.settings.feedback;
  const disabled = !state.status.canShowOverlay;
  const set = async (patch: Partial<FeedbackSettings>) => {
    await save({ ...state.settings, feedback: { ...feedback, ...patch } });
    if (!disabled) api.previewFeedback();
  };

  return (
    <div className={disabled ? "dimmed" : undefined}>
      {disabled && <p className="notice">{t("effects.waylandHint")}</p>}
      <Section>
        <Row title={t("effects.moveFeedback")} hint={t("effects.moveFeedbackHint")}>
          <Segmented
            label={t("effects.moveFeedback")}
            value={feedback.style}
            options={STYLES.map((s) => ({ value: s, label: t(`feedback.${s}` as Key) }))}
            onChange={(style) => set({ style })}
          />
        </Row>
        <Row title={t("effects.color")}>
          <div className="swatches" role="radiogroup" aria-label={t("effects.color")}>
            {(Object.keys(COLORS) as FeedbackSettings["color"][]).map((color) => (
              <button
                key={color}
                type="button"
                role="radio"
                aria-checked={feedback.color === color}
                aria-label={t(`color.${color}` as Key)}
                title={t(`color.${color}` as Key)}
                className={feedback.color === color ? "swatch selected" : "swatch"}
                style={{ background: COLORS[color] }}
                onClick={() => set({ color })}
              />
            ))}
          </div>
        </Row>
        <Row title={t("effects.showShortcut")} hint={t("effects.showShortcutHint")}>
          <Switch
            label={t("effects.showShortcut")}
            checked={feedback.showShortcut}
            onChange={(showShortcut) => set({ showShortcut })}
          />
        </Row>
        <Row title={t("effects.duration")}>
          <Segmented
            label={t("effects.duration")}
            value={feedback.duration}
            options={DURATIONS.map((d) => ({ value: d, label: t(`duration.${d}` as Key) }))}
            onChange={(duration) => set({ duration })}
          />
        </Row>
        {feedback.showShortcut && (
          <Row title={t("effects.position")}>
            <Segmented
              label={t("effects.position")}
              value={feedback.position}
              options={POSITIONS.map((p) => ({ value: p, label: t(`position.${p}` as Key) }))}
              onChange={(position) => set({ position })}
            />
          </Row>
        )}
      </Section>
      <div className="footer-row">
        <span className="hint">{t("effects.tryHint")}</span>
        <button type="button" className="button" disabled={disabled} onClick={() => api.previewFeedback()}>
          {t("effects.try")}
        </button>
      </div>
    </div>
  );
}
