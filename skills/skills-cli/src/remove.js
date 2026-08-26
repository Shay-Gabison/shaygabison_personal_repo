import { existsSync, rmSync } from "node:fs";
import { join } from "node:path";
import { SKILLS_DIR } from "./config.js";

export async function remove(args) {
  if (args.length === 0) {
    throw new Error("Usage: skills remove <skill-name>");
  }

  const skillName = args[0];
  const targetDir = join(SKILLS_DIR, skillName);

  if (!existsSync(targetDir)) {
    throw new Error(`Skill "${skillName}" is not installed.`);
  }

  rmSync(targetDir, { recursive: true, force: true });
  console.log(`🗑️  Removed "${skillName}" from ${targetDir}`);
}
