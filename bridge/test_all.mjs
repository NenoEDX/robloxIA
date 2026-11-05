import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const files = [
  "test_mcp_doctor.mjs", "test_studio_mcp_config.mjs", "test_master_modules.mjs",
  "test_abyssal_slime_core.mjs", "test_zombie_awareness_v4.mjs", "test_open_cloud.mjs",
  "test_rojo_split.mjs", "test_rojo_build.mjs", "test_luau_framework.mjs",
  "test_vault_snapshot.mjs", "test_asset_reference_gate.mjs", "test_asset_ecosystem.mjs",
];
const args = process.argv.slice(2);
if (args.length) {
  process.stdout.write("Usage: node bridge/test_all.mjs\nRuns the selected local regression suite. Missing Lune/Rojo proofs remain skipped.\n");
  process.exitCode = args.length === 1 && args[0] === "--help" ? 0 : 2;
} else {
  const result = spawnSync(process.execPath, ["--test", ...files], {
    cwd: fileURLToPath(new URL("./", import.meta.url)), stdio: "inherit",
  });
  if (result.error) process.stderr.write(result.error.message + "\n");
  process.exitCode = result.status ?? 1;
}
