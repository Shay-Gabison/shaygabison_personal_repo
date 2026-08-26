import { homedir } from "node:os";
import { join } from "node:path";
import { existsSync, readFileSync } from "node:fs";

// Where skills get installed globally
export const SKILLS_DIR = join(homedir(), ".squad", "skills");

// Default registry: the shared team repo
export const DEFAULT_REGISTRY = "https://msazure.visualstudio.com/MCAS/_git/MDA.Platform.Squad.Skills";

// Personal skills repos follow this pattern
export const PERSONAL_REPO_TEMPLATE = "https://github.com/{owner}/shaygabison-personal-skills";

// Config file for overrides
const CONFIG_PATH = join(homedir(), ".config", "mda-skills", "config.json");

export function loadConfig() {
  if (existsSync(CONFIG_PATH)) {
    return JSON.parse(readFileSync(CONFIG_PATH, "utf8"));
  }
  return { registry: DEFAULT_REGISTRY };
}
