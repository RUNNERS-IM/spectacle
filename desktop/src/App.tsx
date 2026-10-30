// The settings window ("Split 설정"): General, Effects and Shortcuts tabs like the macOS app.
import { useEffect, useState } from "react";
import { Keyboard, Settings2, Sparkles } from "lucide-react";
import { api, type Settings, type ViewState } from "./api";
import { t, type Key } from "./i18n";
import GeneralTab from "./tabs/GeneralTab";
import EffectsTab from "./tabs/EffectsTab";
import ShortcutsTab from "./tabs/ShortcutsTab";

type Tab = "general" | "effects" | "shortcuts";

const TABS: { id: Tab; label: Key; Icon: typeof Keyboard }[] = [
  { id: "general", label: "tab.general", Icon: Settings2 },
  { id: "effects", label: "tab.effects", Icon: Sparkles },
  { id: "shortcuts", label: "tab.shortcuts", Icon: Keyboard },
];

export default function App() {
  const [tab, setTab] = useState<Tab>("general");
  const [state, setState] = useState<ViewState | null>(null);

  useEffect(() => {
    document.title = t("settings.title");
    api.getState().then(setState);
    // The GNOME extension or KWin script may be turned on while the window is open.
    const refresh = () => api.getState().then(setState);
    window.addEventListener("focus", refresh);
    return () => window.removeEventListener("focus", refresh);
  }, []);

  if (!state) return null;

  const save = async (settings: Settings) => {
    setState({ ...state, settings });
    setState(await api.saveSettings(settings));
  };

  return (
    <div className="app">
      <nav className="tabs" role="tablist" aria-label={t("settings.title")}>
        {TABS.map(({ id, label, Icon }) => (
          <button
            key={id}
            type="button"
            role="tab"
            aria-selected={tab === id}
            className={tab === id ? "tab selected" : "tab"}
            onClick={() => setTab(id)}
          >
            <Icon size={18} strokeWidth={1.5} aria-hidden />
            <span>{t(label)}</span>
          </button>
        ))}
      </nav>
      <main className="content">
        {tab === "general" && <GeneralTab state={state} save={save} />}
        {tab === "effects" && <EffectsTab state={state} save={save} />}
        {tab === "shortcuts" && <ShortcutsTab state={state} save={save} setState={setState} />}
      </main>
    </div>
  );
}
