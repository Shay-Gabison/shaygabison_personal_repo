import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { SKILLS_DIR } from "./config.js";
import { listRegistrySkills } from "./registry.js";

export async function list(args) {
  const showInstalled = args.includes("--installed");

  if (showInstalled) {
    listInstalled();
  } else {
    await listAvailable(args);
  }
}

function listInstalled() {
  if (!existsSync(SKILLS_DIR)) {
    console.log("No skills installed yet.\nRun 'skills add <name>' to install one.");
    return;
  }

  const dirs = readdirSync(SKILLS_DIR, { withFileTypes: true }).filter((d) => d.isDirectory());

  if (dirs.length === 0) {
    console.log("No skills installed yet.\nRun 'skills add <name>' to install one.");
    return;
  }

  console.log(`\n📂 Installed skills (${SKILLS_DIR}):\n`);

  for (const dir of dirs) {
    const meta = readSkillMeta(join(SKILLS_DIR, dir.name));
    const desc = meta.description ? ` — ${meta.description.slice(0, 60)}` : "";
    console.log(`  • ${dir.name}${desc}`);
  }

  console.log(`\n  Total: ${dirs.length} skill(s)\n`);
}

async function listAvailable(args) {
  const registryArg = args.find((a) => a.startsWith("--registry="));
  const registry = registryArg ? registryArg.split("=")[1] : null;

  const skills = listRegistrySkills(registry);

  if (skills.length === 0) {
    console.log("No skills found in registry.");
    return;
  }

  console.log(`\n📋 Available skills (${skills.length}):\n`);

  for (const name of skills.sort()) {
    console.log(`  • ${name}`);
  }

  console.log(`\n  Install with: skills add <name>\n`);
}

function readSkillMeta(skillDir) {
  const mdPath = join(skillDir, "SKILL.md");
  if (!existsSync(mdPath)) return {};

  const content = readFileSync(mdPath, "utf8");
  const descMatch = content.match(/^description:\s*"?([^"\n]+)"?/m);
  const nameMatch = content.match(/^name:\s*(.+)/m);

  return {
    name: nameMatch?.[1]?.trim(),
    description: descMatch?.[1]?.trim(),
  };
}
