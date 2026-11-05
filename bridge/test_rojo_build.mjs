import test from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));
const rojo = process.env.ROJO_BIN;

// Opt-in executable supplied by the operator. Never download or install a tool.
for (const game of ["zombie", "slime"]) {
  test(`${game} composition builds with the real Rojo CLI`, {
    skip: rojo ? false : "ROJO_BIN is not set; real build proof is unavailable",
  }, () => {
    const scratch = mkdtempSync(path.join(os.tmpdir(), "rojo-build-"));
    try {
      const output = path.join(scratch, `${game}.rbxlx`);
      execFileSync(rojo, ["build", `project_template/${game}.project.json`, "-o", output], {
        cwd: root,
        timeout: 30_000,
        stdio: "pipe",
      });
      const xml = readFileSync(output, "utf8");
      assert.match(xml, /<roblox\b[^>]*version="4"/);
      assert.doesNotMatch(xml, /<!DOCTYPE|<!ENTITY/i);
      assert.equal((xml.match(/<Item class="Script"(?=\s|>)/g) ?? []).length, 1,
        "Each game must contain one server bootstrap");
      assert.equal((xml.match(/<string name="Name">RAASE_Server<\/string>/g) ?? []).length, 1,
        "The bootstrap must retain its shared import parent name");
    } finally {
      rmSync(scratch, { recursive: true, force: true });
    }
  });
}
