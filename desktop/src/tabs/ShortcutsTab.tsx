import { useEffect, useState } from "react";
import { CircleAlert, X } from "lucide-react";
import { api, shortcutFor, type Settings, type ViewState } from "../api";
import { Confirm, Section } from "../components";
import { t, tDynamic } from "../i18n";
import { displayShortcut, shortcutFromEvent } from "../shortcut";

type Problem = { title: string; message: string };

function Recorder({
  action,
  state,
  recording,
  setRecording,
  onRecord,
}: {
  action: string;
  state: ViewState;
  recording: boolean;
  setRecording: (action: string | null) => void;
  onRecord: (action: string, shortcut: string | null) => void;
}) {
  const value = shortcutFor(state, action);
  const editable = state.status.ownsShortcuts;

  useEffect(() => {
    if (!recording) return;
    const onKey = (event: KeyboardEvent) => {
      event.preventDefault();
      event.stopPropagation();
      if (event.key === "Escape") {
        setRecording(null);
        return;
      }
      const shortcut = shortcutFromEvent(event);
      if (shortcut) {
        setRecording(null);
        onRecord(action, shortcut);
      }
    };
    window.addEventListener("keydown", onKey, true);
    return () => window.removeEventListener("keydown", onKey, true);
  }, [recording, action, onRecord, setRecording]);

  return (
    <div className="recorder">
      <button
        type="button"
        className={recording ? "chip recording" : "chip"}
        disabled={!editable}
        onClick={() => setRecording(recording ? null : action)}
        onBlur={() => recording && setRecording(null)}
      >
        {recording
          ? t("recorder.enterShortcut")
          : value
            ? displayShortcut(value, state.platform)
            : t("recorder.clickToRecord")}
      </button>
      {editable && value && !recording && (
        <button type="button" className="clear" aria-label={t("recorder.clear")} onClick={() => onRecord(action, null)}>
          <X size={12} strokeWidth={1.5} />
        </button>
      )}
    </div>
  );
}

export default function ShortcutsTab({
  state,
  save,
  setState,
}: {
  state: ViewState;
  save: (s: Settings) => Promise<void>;
  setState: (s: ViewState) => void;
}) {
  const [recording, setRecordingAction] = useState<string | null>(null);
  const [problem, setProblem] = useState<Problem | null>(null);
  const [confirmRestore, setConfirmRestore] = useState(false);

  // While recording, Split lets go of its own shortcuts so the keys reach this page.
  const setRecording = (action: string | null) => {
    setRecordingAction(action);
    api.setRecording(action !== null);
  };
  useEffect(() => () => void api.setRecording(false), []);

  const onRecord = (action: string, shortcut: string | null) => {
    if (shortcut) {
      const owner = Object.keys(state.defaults).find((other) => other !== action && shortcutFor(state, other) === shortcut);
      if (owner) {
        const shown = displayShortcut(shortcut, state.platform);
        setProblem({
          title: t("shortcuts.inUse", { shortcut: shown }),
          message: t("shortcuts.inUseHint", { shortcut: shown }),
        });
        return;
      }
    }
    save({ ...state.settings, shortcuts: { ...state.settings.shortcuts, [action]: shortcut } });
  };

  return (
    <>
      {!state.status.ownsShortcuts && <p className="notice">{t("shortcuts.kdeManaged")}</p>}
      {state.sections.map(([section, actions]) => {
        const hintKey = `section.${section}Hint`;
        const hint = tDynamic(hintKey);
        return (
          <Section key={section} title={tDynamic(`section.${section}`)} hint={hint === hintKey ? undefined : hint}>
            {actions.map((action) => {
              const failed = state.failures.includes(action);
              return (
                <div className="row" key={action}>
                  <div className="row-text">
                    <div className="row-title">{tDynamic(`action.${action}`)}</div>
                    {failed && (
                      <div className="row-hint warn">
                        <CircleAlert size={11} strokeWidth={1.5} aria-hidden /> {t("shortcuts.taken")}
                      </div>
                    )}
                  </div>
                  <div className="row-control">
                    <Recorder
                      action={action}
                      state={state}
                      recording={recording === action}
                      setRecording={setRecording}
                      onRecord={onRecord}
                    />
                  </div>
                </div>
              );
            })}
          </Section>
        );
      })}
      <div className="footer-row">
        <span className="hint">{t("shortcuts.hint")}</span>
        {state.status.ownsShortcuts && (
          <button type="button" className="button" onClick={() => setConfirmRestore(true)}>
            {t("shortcuts.restoreDefaults")}
          </button>
        )}
      </div>

      {problem && (
        <Confirm
          title={problem.title}
          message={problem.message}
          cancellable={false}
          onCancel={() => setProblem(null)}
          onConfirm={() => setProblem(null)}
        />
      )}
      {confirmRestore && (
        <Confirm
          title={t("shortcuts.restoreConfirm")}
          message={t("shortcuts.restoreConfirmHint")}
          onCancel={() => setConfirmRestore(false)}
          onConfirm={async () => {
            setConfirmRestore(false);
            setState(await api.restoreDefaultShortcuts());
          }}
        />
      )}
    </>
  );
}
