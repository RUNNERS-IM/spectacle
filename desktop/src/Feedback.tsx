// The move highlight. Rust sizes this transparent, click-through window to the moved window
// and sends a "feedback" event; this draws the frame and the shortcut label, then fades out.
import { useEffect, useState, type CSSProperties } from "react";
import { listen } from "@tauri-apps/api/event";
import { COLORS } from "./tabs/EffectsTab";
import type { FeedbackSettings } from "./api";

type Show = {
  style: FeedbackSettings["style"];
  color: FeedbackSettings["color"];
  title: string;
  shortcut: string;
  position: FeedbackSettings["position"];
  durationMs: number;
};

export default function Feedback() {
  const [show, setShow] = useState<(Show & { key: number }) | null>(null);

  useEffect(() => {
    let count = 0;
    const unlisten = listen<Show>("feedback", (event) => {
      count += 1;
      setShow({ ...event.payload, key: count });
    });
    return () => {
      unlisten.then((stop) => stop());
    };
  }, []);

  if (!show) return null;
  const color = COLORS[show.color] ?? COLORS.accent;
  const label = show.shortcut || show.title;

  return (
    <div
      key={show.key}
      className={`feedback feedback-${show.style}`}
      style={{ "--feedback-color": color, "--feedback-duration": `${show.durationMs}ms` } as CSSProperties}
    >
      {label && (
        <div className={`feedback-label at-${show.position}`}>
          {show.shortcut && <span className="feedback-keys">{show.shortcut}</span>}
          {show.title && <span className="feedback-title">{show.title}</span>}
        </div>
      )}
    </div>
  );
}
