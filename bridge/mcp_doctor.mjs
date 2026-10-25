// bridge/mcp_doctor.mjs
// Diagnóstico y guardia de coexistencia entre StudioMCP oficial, MCPBridge (7843), Rojo y Open Cloud API.

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const REPO_ROOT = path.resolve(__dirname, "..");

/**
 * Las 10 herramientas reales expuestas por el servidor oficial StudioMCP (Roblox Studio).
 * Nota: Requiere invocar list_roblox_studios y pasar studio_id cuando hay múltiples instancias.
 */
export const OFFICIAL_STUDIO_MCP_TOOLS = Object.freeze([
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
]);

/**
 * Herramientas de wrappers comunitarios (ej. Cmmdx256/Roblox-Studio-MCP) que NO existen
 * en el servidor oficial StudioMCP y su reemplazo canónico en RAASE 3.0.
 */
export const COMMUNITY_WRAPPER_REPLACEMENTS = Object.freeze({
  insert_asset:
    "execute_luau con game:GetService('InsertService'):LoadAsset(assetId) o MCPBridge BUILD_BATCH",
  generate_procedural_model:
    "generate_mesh (Cube 3D oficial) o Blender headless + Open Cloud v1/assets",
  store_image: "bridge/open_cloud.mjs (POST /assets/v1/assets con assetType Decal)",
  upload_image: "bridge/open_cloud.mjs (POST /assets/v1/assets con assetType Decal)",
  set_property: "execute_luau o MCPBridge BUILD_BATCH con SmartUpsert (RN-10)",
  get_project_structure:
    "execute_luau inspeccionando game:GetService(...) o lectura directa de project_template/src/",
});

/**
 * Contenedores del DataModel gobernados por Rojo (default.project.json).
 * Ningún snippet de execute_luau debe mutar .Source ni destruir módulos dentro de ellos.
 */
export const ROJO_MANAGED_CONTAINERS = Object.freeze([
  "ServerScriptService.RAASE_Server",
  "ReplicatedStorage.RAASE_Shared",
  "StarterPlayerScripts.RAASE_Client",
  "StarterPlayer.StarterPlayerScripts.RAASE_Client",
]);

/**
 * Busca el ejecutable mcp.bat en %LOCALAPPDATA%/Roblox/Versions/* y devuelve la ruta absoluta resuelta.
 *
 * @param {string} [localAppData] Ruta a LocalAppData (por defecto process.env.LOCALAPPDATA)
 * @param {typeof fs} [fsImpl] Implementación de fs inyectable para tests
 * @returns {{ found: boolean, mcpBatPath: string | null, studioExePath: string | null, versionsDir: string }}
 */
export function resolveWindowsStudioMcpBat(
  localAppData = process.env.LOCALAPPDATA || "",
  fsImpl = fs
) {
  if (!localAppData) {
    return { found: false, mcpBatPath: null, studioExePath: null, versionsDir: "" };
  }

  const versionsDir = path.join(localAppData, "Roblox", "Versions");
  if (!fsImpl.existsSync(versionsDir)) {
    return { found: false, mcpBatPath: null, studioExePath: null, versionsDir };
  }

  let entries = [];
  try {
    entries = fsImpl.readdirSync(versionsDir, { withFileTypes: true });
  } catch {
    return { found: false, mcpBatPath: null, studioExePath: null, versionsDir };
  }

  const candidates = [];
  for (const entry of entries) {
    const isDir = typeof entry.isDirectory === "function" ? entry.isDirectory() : true;
    if (!isDir) continue;
    const folderName = typeof entry === "string" ? entry : entry.name;
    const versionPath = path.join(versionsDir, folderName);
    const mcpBat = path.join(versionPath, "mcp.bat");
    const studioExe = path.join(versionPath, "RobloxStudioBeta.exe");
    const hasMcpBat = fsImpl.existsSync(mcpBat);
    const hasStudioExe = fsImpl.existsSync(studioExe);

    if (hasMcpBat || hasStudioExe) {
      let mtimeMs = 0;
      try {
        const statTarget = hasMcpBat ? mcpBat : studioExe;
        mtimeMs = fsImpl.statSync(statTarget).mtimeMs || 0;
      } catch {
        mtimeMs = 0;
      }
      candidates.push({
        mcpBatPath: hasMcpBat ? mcpBat.replace(/\\/g, "/") : null,
        studioExePath: hasStudioExe ? studioExe.replace(/\\/g, "/") : null,
        mtimeMs,
      });
    }
  }

  candidates.sort((a, b) => b.mtimeMs - a.mtimeMs);
  const best = candidates.find((c) => c.mcpBatPath) || candidates[0];
  if (!best) {
    return { found: false, mcpBatPath: null, studioExePath: null, versionsDir };
  }

  return {
    found: Boolean(best.mcpBatPath),
    mcpBatPath: best.mcpBatPath,
    studioExePath: best.studioExePath,
    versionsDir,
  };
}

/**
 * Valida un objeto de configuración MCP (ej. claude_desktop_config.json o mcp_config.json).
 * Detecta variables de entorno sin expandir (%LOCALAPPDATA%, $env:), rutas relativas y args faltantes.
 *
 * @param {object} configObj
 * @returns {{ valid: boolean, errors: string[], warnings: string[] }}
 */
export function validateMcpConfig(configObj) {
  const errors = [];
  const warnings = [];

  if (!configObj || typeof configObj !== "object") {
    return { valid: false, errors: ["El objeto de configuración MCP es nulo o inválido."], warnings };
  }

  const servers = configObj.mcpServers;
  if (!servers || typeof servers !== "object" || !servers.StudioMCP) {
    errors.push("Falta la entrada 'mcpServers.StudioMCP' en la configuración MCP.");
    return { valid: false, errors, warnings };
  }

  const studioMcp = servers.StudioMCP;
  const cmd = String(studioMcp.command || "").trim();
  if (!cmd) {
    errors.push("'mcpServers.StudioMCP.command' está vacío.");
  } else {
    if (/%[A-Za-z0-9_]+%/.test(cmd) || /\$env:/i.test(cmd) || /\$\{[^}]+\}/.test(cmd)) {
      errors.push(
        `El comando '${cmd}' contiene variables de entorno sin expandir. Los clientes MCP en Windows no expanden %LOCALAPPDATA% en spawn directo; usa una ruta absoluta.`
      );
    }
    const isWindowsAbs = /^[A-Za-z]:[/\\]/.test(cmd);
    const isPosixAbs = cmd.startsWith("/");
    if (!isWindowsAbs && !isPosixAbs) {
      errors.push(`El comando '${cmd}' debe ser una ruta absoluta hacia mcp.bat o el binario StudioMCP.`);
    }
  }

  const args = Array.isArray(studioMcp.args) ? studioMcp.args : [];
  if (!args.includes("--studio")) {
    warnings.push("Se recomienda incluir '--studio' en 'mcpServers.StudioMCP.args'.");
  }

  return {
    valid: errors.length === 0,
    errors,
    warnings,
  };
}

/**
 * Guardia estática de soberanía Rojo vs StudioMCP.
 * Verifica que un snippet destinado a `execute_luau` NO intente reescribir `.Source` ni crear/destruir
 * `Script`/`LocalScript`/`ModuleScript` dentro de los contenedores sincronizados por Rojo (`RAASE_Shared`,
 * `RAASE_Server`, `RAASE_Client`), permitiendo libremente `require(...)` e invocaciones declarativas.
 *
 * @param {string} luauSnippet
 * @returns {{ allowed: boolean, violations: string[] }}
 */
export function checkRojoSovereignty(luauSnippet) {
  const code = String(luauSnippet || "");
  const violations = [];

  const touchesRojoContainer = ROJO_MANAGED_CONTAINERS.some((container) => {
    const parts = container.split(".");
    const leaf = parts[parts.length - 1];
    return code.includes(leaf);
  });

  if (touchesRojoContainer) {
    if (/\.Source\s*=/.test(code)) {
      violations.push(
        "Violación de Soberanía Rojo: prohibido asignar '.Source =' en contenedores sincronizados por Rojo (RAASE_Shared / RAASE_Server / RAASE_Client). Edita los archivos en project_template/src/."
      );
    }
    if (
      /Instance\.new\(\s*["'](Script|LocalScript|ModuleScript)["']/.test(code) &&
      /RAASE_(Shared|Server|Client)/.test(code)
    ) {
      violations.push(
        "Violación de Soberanía Rojo: prohibido instanciar Scripts efímeros dentro de RAASE_Shared / RAASE_Server / RAASE_Client vía execute_luau."
      );
    }
    if (/RAASE_(Shared|Server|Client)[^\n;]*:(Destroy|ClearAllChildren)\s*\(/.test(code)) {
      violations.push(
        "Violación de Soberanía Rojo: prohibido destruir módulos sincronizados por Rojo desde execute_luau."
      );
    }
  }

  return {
    allowed: violations.length === 0,
    violations,
  };
}

/**
 * Ejecuta el diagnóstico integral de la arquitectura híbrida RAASE 3.0.
 *
 * @param {{ repoRoot?: string, env?: Record<string, string | undefined>, localAppData?: string, fsImpl?: typeof fs }} [options]
 */
export function runMcpDoctor(options = {}) {
  const repoRoot = options.repoRoot || REPO_ROOT;
  const env = options.env || process.env;
  const fsImpl = options.fsImpl || fs;
  const localAppData =
    options.localAppData !== undefined ? options.localAppData : env.LOCALAPPDATA || "";

  const studioDiscovery = resolveWindowsStudioMcpBat(localAppData, fsImpl);
  const rojoProjectPath = path.join(repoRoot, "project_template", "default.project.json");
  const hasRojoProject = fsImpl.existsSync(rojoProjectPath);

  let rojoMappingsOk = false;
  if (hasRojoProject) {
    try {
      const rojoJson = JSON.parse(fsImpl.readFileSync(rojoProjectPath, "utf8"));
      const tree = rojoJson?.tree || {};
      rojoMappingsOk = Boolean(
        tree?.ServerScriptService?.RAASE_Server?.$path === "src/server" &&
          tree?.ReplicatedStorage?.RAASE_Shared?.$path === "src/shared" &&
          tree?.StarterPlayer?.StarterPlayerScripts?.RAASE_Client?.$path === "src/client"
      );
    } catch {
      rojoMappingsOk = false;
    }
  }

  const exampleConfigPath = path.join(repoRoot, "mcp_config.example.json");
  let exampleConfigValidation = { valid: false, errors: ["No existe mcp_config.example.json"], warnings: [] };
  if (fsImpl.existsSync(exampleConfigPath)) {
    try {
      const parsed = JSON.parse(fsImpl.readFileSync(exampleConfigPath, "utf8"));
      exampleConfigValidation = validateMcpConfig(parsed);
    } catch (err) {
      exampleConfigValidation = { valid: false, errors: [err.message], warnings: [] };
    }
  }

  const openCloudConfigured = Boolean(
    env.ROBLOX_OPEN_CLOUD_API_KEY && (env.ROBLOX_CREATOR_USER_ID || env.ROBLOX_GROUP_ID)
  );

  return {
    studioMcp: {
      discovered: studioDiscovery.found,
      mcpBatPath: studioDiscovery.mcpBatPath,
      studioExePath: studioDiscovery.studioExePath,
      officialToolsCount: OFFICIAL_STUDIO_MCP_TOOLS.length,
    },
    rojo: {
      projectFileExists: hasRojoProject,
      mappingsValid: rojoMappingsOk,
      managedContainers: ROJO_MANAGED_CONTAINERS,
    },
    mcpConfigExample: exampleConfigValidation,
    openCloud: {
      configured: openCloudConfigured,
      hasApiKey: Boolean(env.ROBLOX_OPEN_CLOUD_API_KEY),
      hasCreatorOrGroupId: Boolean(env.ROBLOX_CREATOR_USER_ID || env.ROBLOX_GROUP_ID),
    },
  };
}

if (process.argv[1] && path.resolve(process.argv[1]) === __filename) {
  const report = runMcpDoctor();
  console.log(JSON.stringify(report, null, 2));
}
