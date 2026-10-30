// Runs the macOS app's window position calculations (`Split/Resources/Window Position
// Calculations/*.js`) in a Node `vm` context. The files are read from where the caller says
// they are (the app's resources, or the repository), so there is one copy of the math for
// every platform.

import { readFileSync } from "node:fs";
import { join } from "node:path";
import * as vm from "node:vm";

import { type Action, jsName } from "./actions.ts";
import { Rect } from "./geometry.ts";

/**
 * Every file the macOS bundle loads from "Window Position Calculations". Each file only
 * refers to the others inside functions, so the order does not matter.
 */
export const SCRIPT_FILES: readonly string[] = [
  "SplitWindowCalculationHelpers.js",
  "SplitCenterWindowCalculation.js",
  "SplitNextOrPreviousDisplay.js",
  "SplitNextOrPreviousThirds.js",
  "SplitWindowSizeAdjuster.js",
  "SplitBottomHalfWindowCalculation.js",
  "SplitFullscreenWindowCalculation.js",
  "SplitLargerWindowCalculation.js",
  "SplitLeftHalfWindowCalculation.js",
  "SplitLowerLeftWindowCalculation.js",
  "SplitLowerRightWindowCalculation.js",
  "SplitNextDisplayWindowCalculation.js",
  "SplitNextThirdWindowCalculation.js",
  "SplitPreviousDisplayWindowCalculation.js",
  "SplitPreviousThirdWindowCalculation.js",
  "SplitRightHalfWindowCalculation.js",
  "SplitSmallerWindowCalculation.js",
  "SplitTopHalfWindowCalculation.js",
  "SplitUpperLeftWindowCalculation.js",
  "SplitUpperRightWindowCalculation.js",
];

/**
 * What `SplitWindowPositionCalculator.m` puts into the JavaScriptCore context: the registry
 * and the CoreGraphics helpers the scripts call.
 */
const PRELUDE = `
var __splitCalculations = {};
var windowPositionCalculationRegistry = {
    registerWindowPositionCalculationWithAction: function (calculation, action) {
        __splitCalculations[action] = calculation;
    }
};
function CGRectGetMinX(r) { return r.x; }
function CGRectGetMinY(r) { return r.y; }
function CGRectGetMidX(r) { return r.x + r.width / 2; }
function CGRectGetMidY(r) { return r.y + r.height / 2; }
function CGRectGetMaxX(r) { return r.x + r.width; }
function CGRectGetMaxY(r) { return r.y + r.height; }
function CGRectContainsRect(a, b) {
    return b.x >= a.x && b.y >= a.y && b.x + b.width <= a.x + a.width && b.y + b.height <= a.y + a.height;
}
function CGRectEqualToRect(a, b) {
    return a.x === b.x && a.y === b.y && a.width === b.width && a.height === b.height;
}
`;

export class CalcError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "CalcError";
  }
}

export interface Script {
  file: string;
  source: string;
  compiled: vm.Script;
}

/** The calculation files, read once from `directory` and compiled, ready for `calculate`. */
export type Scripts = readonly Script[];

function compile(file: string, source: string): vm.Script {
  try {
    return new vm.Script(source, { filename: file });
  } catch (error) {
    throw new CalcError(`${file}: ${describe(error)}`);
  }
}

/**
 * Reads every file of `SCRIPT_FILES` from `directory`, such as `process.resourcesPath` joined
 * with "Window Position Calculations" or the repository's `Split/Resources/Window Position
 * Calculations`. Throws when a file is missing.
 */
export function loadScripts(directory: string): Scripts {
  return SCRIPT_FILES.map((file) => {
    let source: string;
    try {
      source = readFileSync(join(directory, file), "utf8");
    } catch (error) {
      throw new CalcError(`${file}: ${describe(error)}`);
    }
    return { file, source, compiled: compile(file, source) };
  });
}

const PRELUDE_SCRIPT = compile("prelude", PRELUDE);

/** Errors thrown inside the context come from its own `Error`, so `instanceof` does not work. */
function describe(error: unknown): string {
  if (typeof error === "object" && error !== null && "message" in error && typeof error.message === "string") {
    return error.message;
  }
  return String(error);
}

function rectFromJson(json: string, name: string): Rect {
  let value: unknown;
  try {
    value = JSON.parse(json);
  } catch (error) {
    throw new CalcError(`${name}: ${describe(error)}: ${json}`);
  }
  if (typeof value !== "object" || value === null) {
    throw new CalcError(`${name}: expected a rect: ${json}`);
  }
  const fields = value as Record<string, unknown>;
  for (const field of ["x", "y", "width", "height"]) {
    if (typeof fields[field] !== "number") {
      throw new CalcError(`${name}: missing or invalid field \`${field}\`: ${json}`);
    }
  }
  return new Rect(fields.x as number, fields.y as number, fields.width as number, fields.height as number);
}

/**
 * Where `action` puts a window. All rectangles are top-left based; they are mirrored into the
 * bottom-left based coordinates the scripts were written for and back.
 *
 * Returns `null` for actions without a calculation (undo, redo, arrange).
 *
 * Why a new context per call: the same as the Rust core, so every calculation starts from
 * the globals the scripts expect and nothing one call leaves behind reaches the next.
 */
export function calculate(
  action: Action,
  window: Rect,
  sourceVisibleFrame: Rect,
  destinationVisibleFrame: Rect,
  scripts: Scripts,
): Rect | null {
  const name = jsName(action);
  if (name === null) {
    return null;
  }
  const toJson = (r: Rect): string => {
    const f = r.flipped();
    return JSON.stringify({ x: f.x, y: f.y, width: f.width, height: f.height });
  };
  const call = `JSON.stringify(__splitCalculations[${JSON.stringify(name)}](${toJson(window)}, ${toJson(sourceVisibleFrame)}, ${toJson(destinationVisibleFrame)}))`;
  const context = vm.createContext({});
  const run = (script: vm.Script, file: string): unknown => {
    try {
      return script.runInContext(context);
    } catch (error) {
      throw new CalcError(`${file}: ${describe(error)}`);
    }
  };
  run(PRELUDE_SCRIPT, "prelude");
  for (const { file, compiled } of scripts) {
    run(compiled, file);
  }
  const json = run(compile(name, call), name);
  if (typeof json !== "string") {
    throw new CalcError(`${name}: the calculation returned ${String(json)}`);
  }
  return rectFromJson(json, name).flipped();
}
