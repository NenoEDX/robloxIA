// bridge/test_mcp_doctor.mjs
import test from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  OFFICIAL_STUDIO_MCP_TOOLS,
  COMMUNITY_WRAPPER_REPLACEMENTS,
  resolveWindowsStudioMcpBat,
  validateMcpConfig,
  checkRojoSovereignty,
  runMcpDoctor,
} from "./mcp_doctor.mjs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const REPO_ROOT = path.resolve(__dirname, "..");

test("StudioMCP official tools catalog matches the 10 verified 2026 tools", () => {
  assert.equal(OFFICIAL_STUDIO_MCP_TOOLS.length, 10);
  for (const requiredTool of [
    "execute_luau",
    "insert_model",
    "generate_mesh",
    "generate_material",
    "start_stop_play",
    "character_navigation",
    "user_keyboard_input",
    "user_mouse_input",
    "get_console_output",
    "screen_capture",
  ]) {
    assert.ok(
      OFFICIAL_STUDIO_MCP_TOOLS.includes(requiredTool),
      `Missing official tool ${requiredTool}`
    );
  }

  for (const nonExistentTool of [
    "insert_asset",
    "generate_procedural_model",
    "store_image",
    "upload_image",
  ]) {
    assert.ok(
      !OFFICIAL_STUDIO_MCP_TOOLS.includes(nonExistentTool),
      `${nonExistentTool} must not be listed as an official StudioMCP tool`
    );
    assert.ok(
      COMMUNITY_WRAPPER_REPLACEMENTS[nonExistentTool],
      `${nonExistentTool} must have a documented replacement`
    );
  }
});

test("validateMcpConfig rejects unexpanded %LOCALAPPDATA% and accepts absolute paths", () => {
  const invalidConfig = {
    mcpServers: {
      StudioMCP: {
        command: "%LOCALAPPDATA%/Roblox/Versions/version-1234/mcp.bat",
        args: ["--studio"],
      },
    },
  };
  const badResult = validateMcpConfig(invalidConfig);
  assert.equal(badResult.valid, false);
  assert.ok(badResult.errors.some((e) => e.includes("variables de entorno sin expandir")));

  const validConfig = {
    mcpServers: {
      StudioMCP: {
        command: "C:/Users/Dev/AppData/Local/Roblox/Versions/version-1234/mcp.bat",
        args: ["--studio"],
      },
    },
  };
  const okResult = validateMcpConfig(validConfig);
  assert.equal(okResult.valid, true);
  assert.equal(okResult.errors.length, 0);
});

test("resolveWindowsStudioMcpBat finds latest version containing mcp.bat", () => {
  const fakeFs = {
    existsSync(target) {
      const norm = target.replace(/\\/g, "/");
      return (
        norm.endsWith("/Roblox/Versions") ||
        norm.endsWith("/version-old/RobloxStudioBeta.exe") ||
        norm.endsWith("/version-new/mcp.bat") ||
        norm.endsWith("/version-new/RobloxStudioBeta.exe")
      );
    },
    readdirSync() {
      return [
        { name: "version-old", isDirectory: () => true },
        { name: "version-new", isDirectory: () => true },
      ];
    },
    statSync(target) {
      const norm = target.replace(/\\/g, "/");
      return { mtimeMs: norm.includes("version-new") ? 2000 : 1000 };
    },
  };

  const resolved = resolveWindowsStudioMcpBat("C:/Users/Test/AppData/Local", fakeFs);
  assert.equal(resolved.found, true);
  assert.equal(
    resolved.mcpBatPath,
    "C:/Users/Test/AppData/Local/Roblox/Versions/version-new/mcp.bat"
  );
});

test("checkRojoSovereignty blocks script .Source mutation in Rojo containers but allows require()", () => {
  const forbiddenSourceMutation = `
    local mod = game:GetService("ReplicatedStorage").RAASE_Shared.WorldAssembler
    mod.Source = "return {}"
  `;
  const check1 = checkRojoSovereignty(forbiddenSourceMutation);
  assert.equal(check1.allowed, false);
  assert.ok(check1.violations.length > 0);

  const forbiddenDestroy = `
    game.ServerScriptService.RAASE_Server.CombatManager:Destroy()
  `;
  const check2 = checkRojoSovereignty(forbiddenDestroy);
  assert.equal(check2.allowed, false);

  const allowedDeclarativeInvocation = `
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local VoxelTerrainBuilder = require(ReplicatedStorage.RAASE_Shared.VoxelTerrainBuilder)
    VoxelTerrainBuilder.GenerateFBM({ Seed = 42, Amplitude = 65 })
  `;
  const check3 = checkRojoSovereignty(allowedDeclarativeInvocation);
  assert.equal(check3.allowed, true);
  assert.equal(check3.violations.length, 0);
});

test("runMcpDoctor validates repository Rojo mappings and mcp_config.example.json", () => {
  const report = runMcpDoctor({
    repoRoot: REPO_ROOT,
    env: {
      ROBLOX_OPEN_CLOUD_API_KEY: "test-key",
      ROBLOX_CREATOR_USER_ID: "123456",
    },
  });

  assert.equal(report.rojo.projectFileExists, true);
  assert.equal(report.rojo.mappingsValid, true);
  assert.equal(report.mcpConfigExample.valid, true);
  assert.equal(report.openCloud.configured, true);
});
