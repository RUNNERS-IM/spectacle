import { fileURLToPath } from "node:url";

import { loadScripts } from "../../src/core/calc.ts";

/** The real calculation files the macOS app ships, read from this repository. */
export const SCRIPTS_DIRECTORY = fileURLToPath(
  new URL("../../../Split/Resources/Window Position Calculations/", import.meta.url),
);

export const SCRIPTS = loadScripts(SCRIPTS_DIRECTORY);
