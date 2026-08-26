import { execSync } from "node:child_process";
import { existsSync, mkdirSync, readdirSync, rmSync, cpSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { loadConfig, DEFAULT_REGISTRY } from "./config.js";

/**
 * Clone a repo (or use cached clone) and return the path to .squad/skills/
 */
function cloneRegistry(repoUrl) {
  const hash = Buffer.from(repoUrl).toString("base64url").slice(0, 16);
  const cacheDir = join(tmpdir(), `mda-skills-cache-${hash}`);

  if (existsSync(cacheDir)) {
    // Pull latest
    try {
      execSync("git pull --quiet", { cwd: cacheDir, stdio: "pipe" });
    } catch {
      // If pull fails, re-clone
      rmSync(cacheDir, { recursive: true, force: true });
    }
  }

  if (!existsSync(cacheDir)) {
    console.log(`📦 Fetching registry from ${repoUrl}...`);
    execSync(`git clone --depth 1 --quiet "${repoUrl}" "${cacheDir}"`, { stdio: "pipe" });
  }

  return cacheDir;
}

/**
 * List all available skills in a registry repo
 */
export function listRegistrySkills(repoUrl) {
  const repoDir = cloneRegistry(repoUrl || loadConfig().registry);
  const skillsDir = join(repoDir, ".squad", "skills");

  if (!existsSync(skillsDir)) {
    return [];
  }

  return readdirSync(skillsDir, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => d.name);
}

/**
 * Get the skill directory from a registry
 */
export function getSkillFromRegistry(skillName, repoUrl) {
  const repoDir = cloneRegistry(repoUrl || loadConfig().registry);
  const skillDir = join(repoDir, ".squad", "skills", skillName);

  if (!existsSync(skillDir)) {
    return null;
  }

  return skillDir;
}

/**
 * Resolve a source string to a repo URL and skill name.
 * Patterns:
 *   "my-work-export"              → default registry, skill = my-work-export
 *   "owner/skill-name"            → owner's personal repo, skill = skill-name
 *   "https://..."                 → git URL, skill = last path segment
 */
export function resolveSource(source) {
  // Full URL
  if (source.startsWith("http://") || source.startsWith("https://") || source.startsWith("git@")) {
    return { repoUrl: source, skillName: null };
  }

  // owner/skill-name pattern
  if (source.includes("/")) {
    const [owner, skillName] = source.split("/", 2);
    // Try ADO personal repo pattern first, then GitHub
    const repoUrl = `https://msazure.visualstudio.com/MCAS/_git/MDA.AI.Tools`;
    // For now we use the shared registry - personal repos can be added later
    return { repoUrl: DEFAULT_REGISTRY, skillName };
  }

  // Simple skill name → default registry
  return { repoUrl: loadConfig().registry, skillName: source };
}
