#!/usr/bin/env node
/**
 * too-long-didnt-type (tldt) — short commands for long developer flows.
 */
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");
const COMMANDS_DIR = path.join(ROOT, "commands");

function listCommands() {
  return fs
    .readdirSync(COMMANDS_DIR, { withFileTypes: true })
    .filter((d) => d.isDirectory() && !d.name.startsWith("_") && !d.name.startsWith("."))
    .map((d) => d.name)
    .sort();
}

function readCommandMeta(name) {
  const metaPath = path.join(COMMANDS_DIR, name, "command.json");
  if (!fs.existsSync(metaPath)) return { name, summary: "" };
  try {
    return JSON.parse(fs.readFileSync(metaPath, "utf8"));
  } catch {
    return { name, summary: "" };
  }
}

function printRootHelp() {
  const cmds = listCommands();
  console.log(`too-long-didnt-type (tldt) — short commands for long developer flows

Usage:
  tldt <command> [args...]
  tldt help
  tldt commands

Commands:`);
  for (const name of cmds) {
    const meta = readCommandMeta(name);
    const summary = meta.summary || meta.description || "";
    console.log(`  ${name.padEnd(14)} ${summary}`);
  }
  console.log(`
Examples:
  tldt tree feature/login
  tldt tree --list
  tldt tree rm feature/login

Docs: https://github.com/dougsumner/too-long-didnt-type
Add a shortcut: see docs/ADDING-COMMANDS.md`);
}

function runBashCommand(commandName, args) {
  const script = path.join(COMMANDS_DIR, commandName, "cli.sh");
  if (!fs.existsSync(script)) {
    console.error(`Unknown command: ${commandName}`);
    console.error(`Run \`tldt commands\` to see available shortcuts.`);
    process.exit(1);
  }

  const result = spawnSync("bash", [script, ...args], {
    stdio: "inherit",
    env: {
      ...process.env,
      TLDT_ROOT: ROOT,
      TLDT_COMMAND: commandName,
    },
  });

  if (result.error) {
    console.error(result.error.message);
    process.exit(1);
  }
  process.exit(result.status ?? 1);
}

const argv = process.argv.slice(2);
const [cmd, ...rest] = argv;

if (!cmd || cmd === "help" || cmd === "--help" || cmd === "-h") {
  printRootHelp();
  process.exit(0);
}

if (cmd === "commands" || cmd === "ls" || cmd === "list-commands") {
  for (const name of listCommands()) {
    const meta = readCommandMeta(name);
    console.log(`${name}\t${meta.summary || meta.description || ""}`);
  }
  process.exit(0);
}

runBashCommand(cmd, rest);
