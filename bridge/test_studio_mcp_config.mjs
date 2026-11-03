import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const configPath = new URL("../.opencode/opencode.json", import.meta.url);

test("the isolated workspace connects through the built-in Windows launcher only", () => {
  const config = JSON.parse(readFileSync(configPath, "utf8"));
  assert.deepEqual(Object.keys(config.mcp.servers), ["roblox_studio"]);
  assert.deepEqual(config.mcp.servers.roblox_studio, {
    type: "local",
    command: ["cmd.exe", "/d", "/c", "{env:LOCALAPPDATA}/Roblox/mcp.bat"],
    timeout: { startup: 15000, catalog: 15000, execution: 30000 },
  });
});

test("the workspace hard-denies Studio tools except explicit session discovery", () => {
  const config = JSON.parse(readFileSync(configPath, "utf8"));
  assert.deepEqual(config.policies, [
    { action: "tool.use", resource: "roblox_studio_*:*", effect: "deny" },
    { action: "tool.use", resource: "roblox_studio_list_roblox_studios:*", effect: "allow" },
  ]);
  assert.deepEqual(config.permissions, [
    { action: "roblox_studio_*", resource: "*", effect: "deny" },
    { action: "roblox_studio_list_roblox_studios", resource: "*", effect: "allow" },
  ]);
  assert.equal(config.instructions, undefined, "External documents are not instruction imports");
  assert.equal(config.plugins, undefined, "No external plugin code is loaded by this integration");
});

test("the integration configuration excludes alternate permission and instruction sources", () => {
  const config = JSON.parse(readFileSync(configPath, "utf8"));
  for (const key of ["agents", "tools", "permission", "experimental", "plugins", "instructions"]) {
    assert.equal(config[key], undefined, `${key} is outside this minimal integration`);
  }
  assert.equal(config.mcp.servers.roblox_studio.disabled, undefined);
});
