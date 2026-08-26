#!/usr/bin/env node

import { parseArgs } from "node:util";
import { add } from "../src/add.js";
import { list } from "../src/list.js";
import { remove } from "../src/remove.js";

const HELP = `
  @mda/skills-cli — Install and manage Copilot CLI skills

  Usage:
    skills add <source>       Install a skill from a registry or git URL
    skills list               List available skills in the registry
    skills installed          List locally installed skills
    skills remove <name>      Remove an installed skill

  Sources:
    skills add my-work-export                  → from default registry
    skills add shaygabison/my-work-export      → from user's personal skills repo
    skills add https://dev.azure.com/.../repo  → from any git URL

  Options:
    --registry, -r   Override default registry repo
    --help, -h       Show this help
    --version, -v    Show version

  Examples:
    npx @mda/skills-cli add my-work-export
    npx @mda/skills-cli list
    npx @mda/skills-cli remove kusto
`;

const args = process.argv.slice(2);
const command = args[0];

if (!command || command === "--help" || command === "-h") {
  console.log(HELP);
  process.exit(0);
}

if (command === "--version" || command === "-v") {
  const { readFileSync } = await import("node:fs");
  const pkg = JSON.parse(readFileSync(new URL("../package.json", import.meta.url), "utf8"));
  console.log(pkg.version);
  process.exit(0);
}

try {
  switch (command) {
    case "add":
      await add(args.slice(1));
      break;
    case "list":
      await list(args.slice(1));
      break;
    case "installed":
      await list(["--installed"]);
      break;
    case "remove":
      await remove(args.slice(1));
      break;
    default:
      console.error(`Unknown command: ${command}\nRun 'skills --help' for usage.`);
      process.exit(1);
  }
} catch (err) {
  console.error(`\n❌ ${err.message}`);
  process.exit(1);
}
