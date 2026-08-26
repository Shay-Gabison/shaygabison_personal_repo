import { existsSync, mkdirSync, cpSync, readFileSync } from "node:fs";
import { join, basename } from "node:path";
import { SKILLS_DIR } from "./config.js";
import { resolveSource, getSkillFromRegistry } from "./registry.js";

export async function add(args) {
  if (args.length === 0) {
    throw new Error("Usage: skills add <skill-name|owner/skill|url>");
  }

  const source = args[0];
  const { repoUrl, skillName } = resolveSource(source);

  if (!skillName) {
    throw new Error(
      "When using a full URL, please specify the skill name: skills add <url> --name <skill-name>"
    );
  }

  console.log(`🔍 Looking for skill "${skillName}"...`);

  const sourceDir = getSkillFromRegistry(skillName, repoUrl);

  if (!sourceDir) {
    throw new Error(
      `Skill "${skillName}" not found in registry.\nRun 'skills list' to see available skills.`
    );
  }

  // Read skill metadata
  const skillMdPath = join(sourceDir, "SKILL.md");
  let description = "";
  if (existsSync(skillMdPath)) {
    const content = readFileSync(skillMdPath, "utf8");
    const descMatch = content.match(/^description:\s*"?([^"\n]+)"?/m);
    if (descMatch) description = descMatch[1].slice(0, 80);
  }

  // Install to global skills dir
  const targetDir = join(SKILLS_DIR, skillName);

  if (existsSync(targetDir)) {
    console.log(`⚠️  Skill "${skillName}" already installed. Updating...`);
  }

  mkdirSync(targetDir, { recursive: true });
  cpSync(sourceDir, targetDir, { recursive: true });

  console.log(`\n✅ Installed "${skillName}" → ${targetDir}`);
  if (description) {
    console.log(`   ${description}`);
  }
  console.log(`\n💡 Try it: say "show my work since last month" to Copilot CLI`);
}
