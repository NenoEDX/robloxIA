import test from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = fileURLToPath(new URL("../", import.meta.url));
for (const name of ["lifecycle", "slime_events", "slime_service", "slime_client", "slime_hud", "syntax"]) {
  test(`Luau executable framework: ${name}`, { skip: !process.env.LUNE_BIN && "LUNE_BIN unavailable; Luau proof not run" }, () => {
    assert.ok(path.isAbsolute(process.env.LUNE_BIN), "LUNE_BIN must be an explicit absolute executable path");
    const result = spawnSync(process.env.LUNE_BIN, ["run", path.join(root, "tests/lune", `${name}.luau`)], {
      cwd: root, encoding: "utf8", timeout: 30000,
    });
    assert.ifError(result.error);
    assert.equal(result.status, 0, result.stderr + result.stdout);
    assert.match(result.stdout, /PASS/);
  });
}
