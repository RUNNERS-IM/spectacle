// Moving windows when monitors are plugged in or out. Port of `SplitDisplayChangeArranger`
// (`Split/Sources/SplitWindowArranger.m`).
//
// Flow: every 4 seconds (and half a second after Split moves a window) it records which monitor
// and where each window is → a screen event comes → it waits a second for macOS to finish
// moving windows itself → `planDisplayChange` (src/core) works out where they go → they move →
// `onArranged` says how many moved, so the label can offer undo.
import { screen } from "electron";
import {
  type DisplayScreen,
  planDisplayChange,
  recordPlaces,
  sameDisplayIds,
  type WindowPlace,
} from "../core/displays.ts";
import type { Move, Snapshot } from "../core/engine.ts";
import type { Settings } from "../shared/types";
import { t } from "./i18n.ts";

const RECORD_INTERVAL = 4000;
const SETTLE_DELAY = 1000;
const RECORD_SOON_DELAY = 500;

export interface DisplayWatcherOptions {
  /** The settings now; read on every record and change, since they can change at any time. */
  settings: () => Settings;
  /** What is on screen, with `windows` filled. */
  snapshot: () => Snapshot;
  apply: (moves: Move[]) => void;
  /** Where the moved windows were, so the next undo puts all of them back. */
  remember: (previous: Move[]) => void;
  /** How many windows moved and whether they went back to remembered places. */
  onArranged: (movedCount: number, restored: boolean) => void;
  /**
   * Restores a layout saved for exactly these monitors and returns how many windows moved, or
   * null when there is none. It wins over the automatic placing. Saved layouts are not in the
   * Electron version yet, so this can be left out.
   */
  restoreSavedLayout?: (displayIds: ReadonlySet<string>) => number | null;
}

let options: DisplayWatcherOptions | null = null;
let places = new Map<number, WindowPlace>();
let awayPlaces = new Map<number, WindowPlace>();
let displayIds = new Set<string>();
let seenDisplayIds = new Set<string>();
let recordTimer: NodeJS.Timeout | null = null;
let settleTimer: NodeJS.Timeout | null = null;
let soonTimer: NodeJS.Timeout | null = null;
/** True from a screen event until it has been handled. */
let settling = false;

/**
 * Why: Electron's display id is the CGDirectDisplayID on macOS, which stays the same when the
 * same monitor is plugged back in. The macOS app used the display UUID instead.
 */
function currentDisplayIds(): Set<string> {
  return new Set(screen.getAllDisplays().map((d) => String(d.id)));
}

/**
 * The native screens with Electron's id for each. Both are top-left based points from the main
 * monitor on macOS, so the frames match; a screen with no match is named by its frame.
 */
function screensWithIds(snapshot: Snapshot): DisplayScreen[] {
  const displays = screen.getAllDisplays();
  return snapshot.screens.map((s) => {
    const match = displays.find(
      (d) =>
        Math.round(d.bounds.x) === Math.round(s.frame.x) &&
        Math.round(d.bounds.y) === Math.round(s.frame.y) &&
        Math.round(d.bounds.width) === Math.round(s.frame.width) &&
        Math.round(d.bounds.height) === Math.round(s.frame.height),
    );
    const id = match ? String(match.id) : `${s.frame.x},${s.frame.y},${s.frame.width}x${s.frame.height}`;
    return { ...s, id };
  });
}

function takeSnapshot(): Snapshot | null {
  try {
    return options?.snapshot() ?? null;
  } catch (error) {
    console.error("split: display change:", error);
    return null;
  }
}

function record(): void {
  // Right after a change macOS has already moved windows around; those places are not the
  // user's, so nothing is recorded until the change has been handled.
  if (!options || settling || !options.settings().rearrangeOnDisplayChange) return;
  const snapshot = takeSnapshot();
  if (!snapshot) return;
  places = recordPlaces(snapshot.windows, screensWithIds(snapshot));
}

function screensChanged(): void {
  if (settling) return;
  settling = true;
  settleTimer = setTimeout(() => {
    settleTimer = null;
    handleChange();
    settling = false;
    recordSoon();
  }, SETTLE_DELAY);
}

function handleChange(): void {
  if (!options) return;
  const newIds = currentDisplayIds();
  const oldIds = displayIds;
  displayIds = newIds;
  // Same monitors (waking from sleep, a resolution change, the Dock showing): leave everything alone.
  if (sameDisplayIds(newIds, oldIds)) return;
  const saved = options.restoreSavedLayout?.(newIds) ?? null;
  if (saved !== null) {
    seenDisplayIds = new Set([...seenDisplayIds, ...newIds]);
    awayPlaces.clear();
    options.onArranged(saved, true);
    return;
  }
  if (!options.settings().rearrangeOnDisplayChange) return;
  const snapshot = takeSnapshot();
  if (!snapshot) return;
  const result = planDisplayChange({
    oldIds,
    newIds,
    seenIds: seenDisplayIds,
    places,
    awayPlaces,
    windows: snapshot.windows,
    screens: screensWithIds(snapshot),
    gap: options.settings().gap,
  });
  seenDisplayIds = result.seenIds;
  awayPlaces = result.awayPlaces;
  const plan = result.plan;
  if (!plan) return;
  try {
    if (plan.moves.length > 0) options.apply(plan.moves);
  } catch (error) {
    // Why: windows moved before the failing one stay moved, so undo is still offered for all of them.
    console.error("split: display change:", error);
  }
  options.remember(plan.previous);
  options.onArranged(plan.moves.length, plan.restored);
}

/** Starts recording windows and moving them when monitors change. Calling it again restarts it. */
export function startDisplayWatcher(next: DisplayWatcherOptions): void {
  stopDisplayWatcher();
  options = next;
  displayIds = currentDisplayIds();
  seenDisplayIds = new Set([...seenDisplayIds, ...displayIds]);
  record();
  recordTimer = setInterval(record, RECORD_INTERVAL);
  // Why: macOS sends one notification for all three; Electron splits it, and `settling` folds them back into one.
  screen.on("display-added", screensChanged);
  screen.on("display-removed", screensChanged);
  screen.on("display-metrics-changed", screensChanged);
}

export function stopDisplayWatcher(): void {
  screen.off("display-added", screensChanged);
  screen.off("display-removed", screensChanged);
  screen.off("display-metrics-changed", screensChanged);
  for (const timer of [recordTimer, settleTimer, soonTimer]) {
    if (timer) clearTimeout(timer);
  }
  recordTimer = settleTimer = soonTimer = null;
  settling = false;
  options = null;
}

/** Records the windows half a second from now, for example right after Split moved one. */
export function recordSoon(): void {
  if (soonTimer) clearTimeout(soonTimer);
  soonTimer = setTimeout(() => {
    soonTimer = null;
    record();
  }, RECORD_SOON_DELAY);
}

/**
 * The label shown after windows moved, or null when nothing should be shown. Port of
 * `showDisplayChangeFeedbackForCount:restored:` in `SplitAppDelegate.m`.
 */
export function displayChangeLabel(
  settings: Settings,
  movedCount: number,
  restored: boolean,
  undoKeys: string,
): { title: string; tip: string } | null {
  if (settings.feedback.style === "off" || movedCount === 0) return null;
  return {
    title: t(restored ? "DisplayRestored" : "DisplayRearranged", movedCount),
    tip: t("DisplayUndoTip", undoKeys),
  };
}
