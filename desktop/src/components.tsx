// Small building blocks shared by the settings tabs, drawn to the Split design standard:
// cards with rows, switches, segmented controls and a floating confirm panel.
import type { ReactNode } from "react";
import { t } from "./i18n";

export function Section({ title, hint, children }: { title?: string; hint?: string; children: ReactNode }) {
  return (
    <section className="section">
      {title && <h2 className="section-header">{title}</h2>}
      <div className="card">{children}</div>
      {hint && <p className="section-hint">{hint}</p>}
    </section>
  );
}

export function Row({ title, hint, children }: { title: string; hint?: string; children?: ReactNode }) {
  return (
    <div className="row">
      <div className="row-text">
        <div className="row-title">{title}</div>
        {hint && <div className="row-hint">{hint}</div>}
      </div>
      {children && <div className="row-control">{children}</div>}
    </div>
  );
}

export function Switch({ checked, onChange, label }: { checked: boolean; onChange: (value: boolean) => void; label: string }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={label}
      className={`switch ${checked ? "on" : ""}`}
      onClick={() => onChange(!checked)}
    >
      <span className="switch-knob" />
    </button>
  );
}

export function Segmented<T extends string | number>({
  value,
  options,
  onChange,
  label,
}: {
  value: T;
  options: { value: T; label: string }[];
  onChange: (value: T) => void;
  label: string;
}) {
  return (
    <div className="segmented" role="radiogroup" aria-label={label}>
      {options.map((option) => (
        <button
          key={String(option.value)}
          type="button"
          role="radio"
          aria-checked={option.value === value}
          className={option.value === value ? "selected" : ""}
          onClick={() => onChange(option.value)}
        >
          {option.label}
        </button>
      ))}
    </div>
  );
}

/** A floating panel that asks before doing something that is hard to undo. */
export function Confirm({
  title,
  message,
  onConfirm,
  onCancel,
  cancellable = true,
}: {
  title: string;
  message: string;
  onConfirm: () => void;
  onCancel: () => void;
  cancellable?: boolean;
}) {
  return (
    <div className="overlay" role="presentation" onClick={onCancel}>
      <div className="panel" role="alertdialog" aria-label={title} onClick={(e) => e.stopPropagation()}>
        <div className="panel-title">{title}</div>
        <div className="panel-message">{message}</div>
        <div className="panel-buttons">
          {cancellable && (
            <button type="button" className="button" onClick={onCancel}>
              {t("button.cancel")}
            </button>
          )}
          <button type="button" className="button primary" onClick={onConfirm} autoFocus>
            {t("button.ok")}
          </button>
        </div>
      </div>
    </div>
  );
}
