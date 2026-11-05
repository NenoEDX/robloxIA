// @ts-check
/**
 * asset_ecosystem.mjs — Unified MCP-First Asset Radar, 1.2 GB LihFolk Vault/Pack
 * connector, 1-by-1 Nano Banana 3D Queue, Fighting-Game VFX Recipe Catalog, and
 * Two-Stage Top-Down + Zone-Reference Map Validator.
 *
 * CLI usage:
 *   node bridge/asset_ecosystem.mjs status
 *   node bridge/asset_ecosystem.mjs next-prompt [--registry <path>]
 *   node bridge/asset_ecosystem.mjs search --query <word>
 *   node bridge/asset_ecosystem.mjs vfx-recipes [--intent <word>]
 *   node bridge/asset_ecosystem.mjs register --id <slug> --name <str> --category <cat> --glb <path> [--tris <n>] [--height <n>] [--tags <a,b>] [--registry <path>]
 *   node bridge/asset_ecosystem.mjs validate-map --map <json-path> [--registry <path>]
 */

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(HERE, "..");
const DEFAULT_REGISTRY_PATH = path.join(REPO_ROOT, "assets", "ecosystem_registry.json");
const LOCAL_VAULT_CONFIG_PATH = path.join(REPO_ROOT, "assets", "vault_paths.local.json");

/** Read optional local vault/asset-pack pointer file if configured by the user. */
function readLocalVaultConfig() {
  if (!fs.existsSync(LOCAL_VAULT_CONFIG_PATH)) return { vaultRoot: null, assetPackRoot: null };
  try {
    const data = JSON.parse(fs.readFileSync(LOCAL_VAULT_CONFIG_PATH, "utf8"));
    return {
      vaultRoot: typeof data.vaultRoot === "string" ? data.vaultRoot : null,
      assetPackRoot: typeof data.assetPackRoot === "string" ? data.assetPackRoot : null,
    };
  } catch {
    return { vaultRoot: null, assetPackRoot: null };
  }
}

/** Save custom local paths for LihFolk Vault V2 and LihFolk-Assets (gitignored). */
export function configureLocalVaultPaths({ vaultRoot, assetPackRoot }) {
  const payload = {
    updatedAt: new Date().toISOString(),
    vaultRoot: vaultRoot ? path.resolve(vaultRoot) : null,
    assetPackRoot: assetPackRoot ? path.resolve(assetPackRoot) : null,
  };
  fs.mkdirSync(path.dirname(LOCAL_VAULT_CONFIG_PATH), { recursive: true });
  fs.writeFileSync(LOCAL_VAULT_CONFIG_PATH, `${JSON.stringify(payload, null, 2)}\n`, "utf8");
  return payload;
}

/** Resolve the 1.2 GB LihFolk Vault V2 and LihFolk-Assets directories (optional plug-and-play). */
export function resolveVaultAndPackPaths(customRoot) {
  if (customRoot === "__FORCE_STANDALONE__") {
    return { vaultRoot: null, assetPackRoot: null };
  }
  const localCfg = readLocalVaultConfig();
  const homeDir = process.env.USERPROFILE || process.env.HOME || "";

  const candidates = [
    customRoot,
    process.env.LIHFOLK_ASSETS,
    localCfg.assetPackRoot,
    path.resolve(REPO_ROOT, "LihFolk-Assets"),
    path.resolve(REPO_ROOT, "..", "LihFolk-Assets"),
    path.resolve(REPO_ROOT, "..", "..", "LihFolk-Assets"),
    homeDir ? path.join(homeDir, "LihFolk-Assets") : null,
    homeDir ? path.join(homeDir, "Downloads", "Lihfolk v2", "LihFolk Asset Pack") : null,
  ].filter(Boolean);

  let assetPackRoot = null;
  for (const candidate of candidates) {
    if (fs.existsSync(path.join(candidate, "INDEX.md"))) {
      assetPackRoot = candidate;
      break;
    }
  }

  const vaultCandidates = [
    process.env.LIHFOLK_VAULT,
    localCfg.vaultRoot,
    path.resolve(REPO_ROOT, "LihFolk Vault V2"),
    path.resolve(REPO_ROOT, "..", "LihFolk Vault V2"),
    path.resolve(REPO_ROOT, "..", "..", "LihFolk Vault V2"),
    homeDir ? path.join(homeDir, "LihFolk Vault V2") : null,
    homeDir ? path.join(homeDir, "Downloads", "Lihfolk v2", "LihFolk Vault V2") : null,
  ].filter(Boolean);

  let vaultRoot = null;
  for (const candidate of vaultCandidates) {
    if (fs.existsSync(path.join(candidate, "ROUTER.md"))) {
      vaultRoot = candidate;
      break;
    }
  }

  return { vaultRoot, assetPackRoot };
}

/** Parse a simple CSV file with header row into objects. */
function parseCsvFile(filePath) {
  if (!fs.existsSync(filePath)) return [];
  const lines = fs
    .readFileSync(filePath, "utf8")
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
  if (lines.length < 2) return [];
  const headers = lines[0].split(",").map((h) => h.trim());
  const rows = [];
  for (let i = 1; i < lines.length; i += 1) {
    const cols = lines[i].split(",");
    /** @type {Record<string, string>} */
    const row = {};
    for (let c = 0; c < headers.length; c += 1) {
      row[headers[c]] = (cols[c] ?? "").trim();
    }
    rows.push(row);
  }
  return rows;
}

/** Load shippable rows from the local LihFolk Asset Pack catalogues. */
export function loadLihFolkCatalogs(packRootOption) {
  const { assetPackRoot, vaultRoot } = resolveVaultAndPackPaths(packRootOption);
  if (!assetPackRoot) {
    return {
      connected: false,
      assetPackRoot: null,
      vaultRoot,
      models: [],
      materials: [],
      skies: [],
      animations: [],
      vfx: [],
    };
  }

  const rawModels = parseCsvFile(path.join(assetPackRoot, "Models", "Kits", "CATALOG.csv"));
  const models = rawModels.filter((r) => r.gate === "A1-A18 pass");

  const rawMaterials = parseCsvFile(path.join(assetPackRoot, "Materials", "CATALOG.csv"));
  const materials = rawMaterials.filter((r) => r.family_status === "pass");

  const rawSkies = parseCsvFile(path.join(assetPackRoot, "Skies", "CATALOG.csv"));
  const skies = rawSkies;

  const rawAnimations = parseCsvFile(path.join(assetPackRoot, "Animations", "CATALOG.csv"));
  const animations = rawAnimations.filter(
    (r) => !r.status || r.status === "shipped" || r.status === "approved",
  );

  const rawVfx = parseCsvFile(path.join(assetPackRoot, "VFX", "CATALOG.csv"));
  const vfx = rawVfx.filter(
    (r) => !r.status || r.status === "shipped" || r.status === "approved" || r.status === "pass",
  );

  return {
    connected: true,
    assetPackRoot,
    vaultRoot,
    models,
    materials,
    skies,
    animations,
    vfx,
  };
}

/** Load the project's reusable Ecosystem Registry JSON. */
export function loadEcosystemRegistry(registryPath = DEFAULT_REGISTRY_PATH) {
  if (!fs.existsSync(registryPath)) {
    throw new Error(`Ecosystem registry not found at ${registryPath}`);
  }
  const doc = JSON.parse(fs.readFileSync(registryPath, "utf8"));
  if (doc.schema !== "robloxia.ecosystem-registry/v1") {
    throw new Error(`Invalid ecosystem registry schema: ${doc.schema}`);
  }
  if (!Array.isArray(doc.reusableAssets)) doc.reusableAssets = [];
  if (!Array.isArray(doc.missingQueue)) doc.missingQueue = [];
  return doc;
}

/**
 * Build a 1-by-1 Nano Banana prompt engineered specifically for clean 3D conversion,
 * plus the 3 conversion routes depending on the user's current AI or external tool.
 */
export function buildNanoBanana3DPrompt(item) {
  const dims = Array.isArray(item.targetStuds)
    ? `${item.targetStuds[0]}x${item.targetStuds[1]}x${item.targetStuds[2]} studs`
    : `${item.heightStuds ?? 4} studs tall`;
  const maxTris = item.maxTris ?? 4000;

  const nanoBananaPrompt = [
    `Concept sheet for a 3D Roblox game asset: "${item.name}" (${item.styleBrief || item.category}).`,
    `View: 3/4 front orthographic turnaround view, full object completely inside frame, centered, grounded on a flat invisible plane.`,
    `Style: Stylized chunky low-poly cartoon proportions (LihFolk / Supercell / modern Roblox aesthetic), thick readable silhouette, clean bevelled edges, no fragile paper-thin parts.`,
    `Lighting & Background: Flat neutral light-grey background (#E8E8E8), uniform diffuse studio lighting, ZERO harsh cast shadows, ZERO directional specular blowouts, no smoke or particle overlays obscuring the geometry.`,
    `Target Scale & Budget: ${dims}, max ${maxTris} triangles, single cohesive material atlas.`,
  ].join(" ");

  return {
    assetId: item.assetId,
    name: item.name,
    zone: item.zone || "General",
    category: item.category || "medium",
    targetStuds: item.targetStuds || [4, 4, 4],
    maxTris,
    nanoBananaPrompt,
    routes: {
      routeA_potentAiSameChat: {
        label: "Ruta A (IA Potente en el mismo chat -> Blender 5.2 Headless)",
        whenToUse:
          "Cuando estás usando un modelo potente (Claude Opus, GPT-5.4, Gemini 4 Argon) y quieres que la IA construya el modelo paramétrico y texturizado directamente en Blender 5.2.",
        command: `node agent/generators/run_slime_assets.mjs --only ${item.assetId} --out exports/ecosystem`,
      },
      routeB_studioMcpNative: {
        label: "Ruta B (Directo en Roblox Studio vía MCP Oficial)",
        whenToUse:
          "Cuando quieres generar la malla o modelo procedimental directamente dentro de la escena de Studio usando la imagen de Nano Banana.",
        mcpTool: "Roblox_Studio.generate_mesh / generate_procedural_model (attachedImageUri)",
      },
      routeC_externalAppPlusCleanup: {
        label: "Ruta C (IA Ligera o App Externa Tripo/Meshy/Rodin + Auto-Limpieza Blender 5.2)",
        whenToUse:
          "Cuando usas una IA ligera o pasas la imagen de Nano Banana por Tripo 3D, Meshy o Hyper3D Rodin y descargas el .glb/.fbx crudo.",
        command: `blender -b --factory-startup --python agent/generators/blender/normalize_external_3d.py -- --input <raw.glb> --out exports/ecosystem/${item.assetId}/${item.assetId}.glb --target-tris ${maxTris} --height-studs ${(item.targetStuds && item.targetStuds[2]) || 4.0}`,
      },
    },
  };
}

/** Determine whether an asset is low-detail (accessory, mutation, icon, tiny/small prop) and should be batched in sets of up to 10. */
export function isLowDetailBatchable(item) {
  if (!item || typeof item !== "object") return false;
  if (item.detailTier === "low_batch_10") return true;
  if (item.detailTier === "high_single_1x1") return false;
  const cat = String(item.category || "").toLowerCase();
  if (["accessory", "mutation", "icon", "tiny", "badge", "attachment"].includes(cat)) {
    return true;
  }
  if (Number(item.maxTris ?? 4000) <= 1000) return true;
  return false;
}

/**
 * Build a 10-in-1 Grid Sheet Nano Banana prompt for low-detail assets
 * (accessories, visual mutations, small props, icons) so the user saves tokens and generations.
 */
export function buildNanoBananaBatch10Prompt(items) {
  const batch = items.slice(0, 10);
  const numberedList = batch
    .map((it, idx) => `${idx + 1}. "${it.name}" (${it.styleBrief || it.category})`)
    .join("; ");

  const nanoBananaSheetPrompt = [
    `Concept sheet grid (2 rows x 5 columns, up to 10 separate items) for Roblox 3D accessories & mutations.`,
    `Items in grid order: ${numberedList}.`,
    `Layout & View: Each item isolated in its own cleanly separated cell with generous padding, 3/4 front orthographic view, no overlapping between cells.`,
    `Style: Stylized chunky low-poly cartoon proportions (LihFolk / Supercell / Roblox UGC style), bold readable silhouettes, thick edges.`,
    `Lighting & Background: Solid neutral light-grey background (#E8E8E8), flat diffuse studio lighting, ZERO harsh cast shadows, no text overlays touching the models.`,
  ].join(" ");

  return {
    batchMode: "sheet_10x",
    batchCount: batch.length,
    maxBatchSize: 10,
    items: batch.map((it) => ({
      assetId: it.assetId,
      name: it.name,
      category: it.category,
      maxTris: it.maxTris ?? 600,
      targetStuds: it.targetStuds || [1.2, 1.2, 1.2],
    })),
    nanoBananaPrompt: nanoBananaSheetPrompt,
    routes: {
      routeA_potentAiSameChat: {
        label: "Ruta A (IA Potente en el mismo chat -> Lote de hasta 10 en Blender 5.2 Headless)",
        whenToUse:
          "La IA recorta/interpreta cada celda de tu hoja de 10 accesorios/mutaciones y genera los 10 archivos .glb en lote con pivote en el punto de anclaje (Attachment).",
      },
      routeC_externalAppPlusCleanup: {
        label: "Ruta C (Recorte por celda -> Conversor 3D + normalize_external_3d.py --target-tris 600)",
        whenToUse:
          "Cuando pasas los accesorios por un generador externo y el script de Blender los deja en <= 600-1,000 triángulos listos para soldar al rig.",
      },
    },
  };
}

/** Return the next Nano Banana request: 1-by-1 for complex models, or a batch of up to 10 for accessories/mutations! */
export function getNextNanoBananaRequest(registryPath = DEFAULT_REGISTRY_PATH, options = {}) {
  const registry = loadEcosystemRegistry(registryPath);
  const pending = registry.missingQueue.filter((item) => item.status !== "ready_3d");
  if (pending.length === 0) {
    return {
      hasPending: false,
      batchMode: "none",
      queueLength: 0,
      currentPosition: 0,
      request: null,
    };
  }

  const preferLowDetailBatch = options.mode === "batch10" || isLowDetailBatchable(pending[0]);
  if (preferLowDetailBatch) {
    const lowDetailItems = pending.filter((item) => isLowDetailBatchable(item)).slice(0, 10);
    if (lowDetailItems.length > 0) {
      return {
        hasPending: true,
        batchMode: "sheet_10x",
        queueLength: pending.length,
        currentPosition: 1,
        request: buildNanoBananaBatch10Prompt(lowDetailItems),
      };
    }
  }

  return {
    hasPending: true,
    batchMode: "single_1x1",
    queueLength: pending.length,
    currentPosition: 1,
    request: {
      batchMode: "single_1x1",
      ...buildNanoBanana3DPrompt(pending[0]),
    },
  };
}

/**
 * Audit a list of required assets for a game or zone against both the reusable
 * Ecosystem Registry and the 815-model LihFolk Asset Pack.
 */
export function auditGameAssets({ requiredAssets, registryPath = DEFAULT_REGISTRY_PATH, packRoot }) {
  if (!Array.isArray(requiredAssets)) {
    throw new Error("requiredAssets must be an array");
  }
  const registry = loadEcosystemRegistry(registryPath);
  const lihfolk = loadLihFolkCatalogs(packRoot);

  const resolved = [];
  const missing = [];
  const violations = [];

  for (const req of requiredAssets) {
    const slug = String(req.assetId || "").trim();
    if (!slug) {
      violations.push({ code: "INVALID_ASSET_ID", message: "Asset requirement is missing assetId" });
      continue;
    }

    if (
      req.sourceType === "primitive_blocks" ||
      req.sourceType === "mindless_scatter" ||
      req.allowPrimitivePlaceholder === true
    ) {
      violations.push({
        code: "MINDLESS_DECORATION_FORBIDDEN",
        assetId: slug,
        message: `Asset "${slug}" attempted to use primitive block placeholders ("decoraciones sin criterio"). A real 3D model is mandatory.`,
      });
      continue;
    }

    const inEcosystem = registry.reusableAssets.find(
      (a) => a.assetId === slug && a.status === "ready_3d",
    );
    if (inEcosystem) {
      resolved.push({
        assetId: slug,
        source: "ecosystem_registry",
        path: inEcosystem.glbPath,
        tris: inEcosystem.tris,
      });
      continue;
    }

    const inLihFolk = lihfolk.models.find(
      (m) =>
        m.asset.toLowerCase() === slug.toLowerCase() ||
        `${m.kit}_${m.asset}`.toLowerCase() === slug.toLowerCase(),
    );
    if (inLihFolk) {
      resolved.push({
        assetId: slug,
        source: "lihfolk_asset_pack",
        path: inLihFolk.path,
        tris: Number(inLihFolk.tris),
      });
      continue;
    }

    const queuedSpec = registry.missingQueue.find((q) => q.assetId === slug) || {
      assetId: slug,
      name: req.name || slug,
      category: req.category || "medium",
      zone: req.zone || "General",
      status: "missing_reference",
      targetStuds: req.targetStuds || [4, 4, 4],
      maxTris: req.maxTris || 4000,
      styleBrief: req.styleBrief || `Modelo 3D estilizado para ${req.name || slug}`,
    };
    missing.push(buildNanoBanana3DPrompt(queuedSpec));
  }

  return {
    ok: missing.length === 0 && violations.length === 0,
    vaultConnected: Boolean(lihfolk.vaultRoot),
    assetPackConnected: lihfolk.connected,
    lihFolkModelCount: lihfolk.models.length,
    resolved,
    missing,
    nextNanoBananaPrompt: missing.length > 0 ? missing[0] : null,
    violations,
  };
}

/**
 * Register a new 3D model into `assets/ecosystem_registry.json` for permanent
 * reuse across current and future games, and remove it from `missingQueue` if present.
 */
export function registerEcosystemAsset(registryPath = DEFAULT_REGISTRY_PATH, entry) {
  if (!entry || typeof entry !== "object") {
    throw new Error("Asset entry must be an object");
  }
  const slug = String(entry.assetId || "").trim();
  if (!/^[a-z][a-z0-9_]{2,63}$/.test(slug)) {
    throw new Error(`Invalid assetId "${slug}": must match ^[a-z][a-z0-9_]{2,63}$`);
  }
  if (!entry.name || typeof entry.name !== "string") {
    throw new Error(`Asset "${slug}" requires a human-readable name`);
  }
  if (!entry.glbPath || typeof entry.glbPath !== "string") {
    throw new Error(`Asset "${slug}" requires a valid glbPath`);
  }
  const tris = Number(entry.tris ?? 0);
  if (!Number.isFinite(tris) || tris <= 0 || tris > 20000) {
    throw new Error(`Asset "${slug}" triangle count (${tris}) must be between 1 and 20,000`);
  }

  const registry = loadEcosystemRegistry(registryPath);
  const record = {
    assetId: slug,
    name: entry.name.trim(),
    category: entry.category || "medium",
    gameOrigin: entry.gameOrigin || "shared-ecosystem",
    status: "ready_3d",
    route: entry.route || "route_c_external_plus_blender_cleanup",
    heightStuds: Number(entry.heightStuds ?? 4.0),
    tris,
    glbPath: entry.glbPath.replaceAll("\\", "/"),
    blendPath: entry.blendPath ? entry.blendPath.replaceAll("\\", "/") : null,
    referenceSource: entry.referenceSource || "user_nano_banana_approved",
    tags: Array.isArray(entry.tags) ? entry.tags : [slug],
    reusableInFutureGames: true,
    registeredAt: new Date().toISOString(),
  };

  const existingIndex = registry.reusableAssets.findIndex((a) => a.assetId === slug);
  if (existingIndex >= 0) {
    registry.reusableAssets[existingIndex] = record;
  } else {
    registry.reusableAssets.push(record);
  }

  registry.missingQueue = registry.missingQueue.filter((q) => q.assetId !== slug);
  registry.updatedAt = new Date().toISOString();
  fs.writeFileSync(registryPath, `${JSON.stringify(registry, null, 2)}\n`, "utf8");
  return record;
}

/**
 * Validate a Two-Stage Map Blueprint:
 *   Stage 1: Must provide a top-down layout plan (`topDownPlan`) with valid dimensions & walk speeds.
 *   Stage 2: Every zone must provide per-zone visual references (`zoneReferences[]`) and explicit
 *            3D prop models (`props3d[]`, e.g., `verja_abismal_3d`, `maquina_extractora_3d`).
 *            Forbids mindless primitive block decorations (`MINDLESS_DECORATION_FORBIDDEN`).
 */
export function validateMapBlueprint(blueprint, { registryPath = DEFAULT_REGISTRY_PATH, packRoot } = {}) {
  const errors = [];
  const missingZoneReferences = [];
  const requiredProps = [];

  if (!blueprint || typeof blueprint !== "object") {
    return {
      valid: false,
      stage: "stage_1_top_down_plan",
      errors: [{ code: "INVALID_BLUEPRINT", message: "Map blueprint must be an object" }],
      missingZoneReferences: [],
      assetAudit: null,
    };
  }

  const topDown = blueprint.topDownPlan;
  if (!topDown || typeof topDown !== "object" || !topDown.sourceImageOrGrid || topDown.approved !== true) {
    errors.push({
      code: "MISSING_TOP_DOWN_PLAN",
      message:
        "Falta el Paso 1 del Mapa: Debes entregar y aprobar primero el Plano desde Arriba (Top-Down Layout 2D) y su Topografía antes de construir zonas.",
    });
  } else {
    const mainPathWidth = Number(topDown.mainPathWidthStuds ?? 0);
    if (mainPathWidth < 16) {
      errors.push({
        code: "PATH_TOO_NARROW",
        message: `El camino principal en el plano mide ${mainPathWidth} studs; el mínimo de legibilidad LihFolk es 16-20 studs.`,
      });
    }
    if (topDown.requireTopography === true && (!topDown.topography || typeof topDown.topography !== "object")) {
      errors.push({
        code: "MISSING_TOPOGRAPHY_SPEC",
        message:
          "Falta la Topografía en el Paso 1: Define las alturas/elevaciones, fosos o rampas (topDownPlan.topography) junto al plano visto desde arriba.",
      });
    }
  }

  const zones = Array.isArray(blueprint.zones) ? blueprint.zones : [];
  if (zones.length === 0) {
    errors.push({
      code: "NO_ZONES_DEFINED",
      message: "El plano del mapa debe definir al menos una zona jugable.",
    });
  }

  for (const zone of zones) {
    const zoneId = zone.zoneId || zone.name || "unnamed_zone";
    if (!Array.isArray(zone.zoneReferences) || zone.zoneReferences.length === 0) {
      missingZoneReferences.push(zoneId);
      errors.push({
        code: "MISSING_ZONE_REFERENCE",
        zoneId,
        message: `Falta el Paso 2 para la zona "${zoneId}": debes proporcionar al menos una imagen de referencia visual para esta zona antes de vestirla.`,
      });
    }

    if (
      zone.decorationMode === "primitive_blocks" ||
      zone.decorationMode === "random_scatter" ||
      zone.allowMindlessPrimitives === true
    ) {
      errors.push({
        code: "MINDLESS_DECORATION_FORBIDDEN",
        zoneId,
        message: `La zona "${zoneId}" intenta usar decoraciones sin criterio con bloques básicos. Toda decoración (verjas, máquinas, faroles, arcos) debe ser un modelo 3D real aterrizado con placeOnGround.`,
      });
    }

    if (!Array.isArray(zone.props3d) || zone.props3d.length === 0) {
      errors.push({
        code: "EMPTY_ZONE_3D_PROPS",
        zoneId,
        message: `La zona "${zoneId}" no declara objetos 3D explícitos (ej. verja 3D, máquina 3D, altar 3D).`,
      });
    } else {
      for (const prop of zone.props3d) {
        if (prop.placementRule !== "placeOnGround" && prop.placementRule !== "modularSnap") {
          errors.push({
            code: "UNGROUNDED_PROP_PLACEMENT",
            zoneId,
            assetId: prop.assetId,
            message: `El objeto 3D "${prop.assetId}" en "${zoneId}" debe usar placementRule="placeOnGround" o "modularSnap" para evitar objetos flotando.`,
          });
        }
        requiredProps.push({
          assetId: prop.assetId,
          name: prop.name || prop.assetId,
          category: prop.category || "medium",
          zone: zoneId,
          sourceType: prop.sourceType || "model_3d",
          targetStuds: prop.targetStuds || [4, 4, 4],
          maxTris: prop.maxTris || 4000,
          styleBrief: prop.styleBrief,
        });
      }
    }
  }

  const assetAudit = auditGameAssets({
    requiredAssets: requiredProps,
    registryPath,
    packRoot,
  });

  for (const violation of assetAudit.violations) {
    errors.push(violation);
  }

  return {
    valid: errors.length === 0 && assetAudit.ok,
    stage:
      !topDown || !topDown.approved
        ? "awaiting_stage_1_top_down_plan"
        : missingZoneReferences.length > 0
          ? "awaiting_stage_2_zone_references"
          : !assetAudit.ok
            ? "awaiting_stage_3_missing_3d_models"
            : "ready_for_mcp_build",
    errors,
    missingZoneReferences,
    assetAudit,
  };
}

/**
 * Fighting-Game & Dopamine VFX Recipe Catalog (backed by LihFolkVFX and LihFolkVFX_Abilities).
 * Allows choosing AAA combat/extraction VFX by plain Spanish intent without needing technical references.
 */
export const VFX_RECIPE_CATALOG = [
  {
    recipeId: "combat_slash_heavy",
    name: "Tajo Pesado Frontal (Estilo Fighting / Anime)",
    intentKeywords: ["espada", "corte", "tajo", "slash", "pelea", "ataque pesado"],
    module: "LihFolkVFX",
    preset: "SlashSweep",
    defaultElement: "teal",
    supportedElements: ["teal", "violet", "fire", "ice", "lightning", "void", "holy"],
    threeValueRule: "Borde blanco ardiente + cuerpo saturado del elemento + tinta oscura de contraste (nota 10.0/10)",
    cameraShake: { intensity: 0.45, duration: 0.18 },
    hitStopSeconds: 0.08,
  },
  {
    recipeId: "combat_double_crescent",
    name: "Combo Doble Medialuna Rápida",
    intentKeywords: ["combo", "doble", "rápido", "corte doble", "espadas"],
    module: "LihFolkVFX",
    preset: "CrescentDouble",
    defaultElement: "violet",
    supportedElements: ["teal", "violet", "fire", "ice", "lightning", "void", "holy"],
    threeValueRule: "Dos medialunas escalonadas en el frente (±100° del LookVector) con chispas cuadradas",
    cameraShake: { intensity: 0.3, duration: 0.12 },
    hitStopSeconds: 0.05,
  },
  {
    recipeId: "combat_overhead_slam",
    name: "Golpe Vertical Destructor de Suelo",
    intentKeywords: ["martillo", "slam", "suelo", "grieta", "vertical", "aplastar"],
    module: "LihFolkVFX",
    preset: "OverheadCleave",
    defaultElement: "fire",
    supportedElements: ["fire", "ice", "lightning", "void", "holy", "teal"],
    threeValueRule: "Arco vertical descendente + grieta brillante en el piso + anillo de onda de choque + escombros",
    cameraShake: { intensity: 0.65, duration: 0.24 },
    hitStopSeconds: 0.11,
  },
  {
    recipeId: "combat_thrust_pierce",
    name: "Estocada Perforante Sónica",
    intentKeywords: ["lanza", "estocada", "perforar", "thrust", "aguijón", "puño"],
    module: "LihFolkVFX",
    preset: "ThrustPierce",
    defaultElement: "ice",
    supportedElements: ["ice", "lightning", "void", "holy", "fire", "teal"],
    threeValueRule: "Conos anidados oscuro/elemento/blanco con líneas de viento convergentes y anillos sónicos",
    cameraShake: { intensity: 0.35, duration: 0.14 },
    hitStopSeconds: 0.06,
  },
  {
    recipeId: "combat_dash_afterimage",
    name: "Dash Relámpago con Copias Fantasma",
    intentKeywords: ["dash", "esquivar", "velocidad", "fantasma", "afterimage", "paso"],
    module: "LihFolkVFX",
    preset: "DashTrail",
    defaultElement: "lightning",
    supportedElements: ["lightning", "void", "teal", "violet", "fire", "ice"],
    threeValueRule: "Siluetas de neón del personaje a lo largo del trayecto + líneas de velocidad + anillo de salida",
    cameraShake: { intensity: 0.2, duration: 0.1 },
    hitStopSeconds: 0.0,
  },
  {
    recipeId: "combat_beam_kamehameha",
    name: "Rayo de Energía / Cañón Láser de Pelea",
    intentKeywords: ["rayo", "laser", "kamehameha", "beam", "cañón", "poder"],
    module: "LihFolkVFX_Abilities",
    preset: "BeamLaser",
    defaultElement: "plasma",
    supportedElements: ["plasma", "void", "fire", "ice", "lightning", "holy", "teal", "violet"],
    threeValueRule: "Carga con orbe creciente + 3 haces (borde oscuro, cuerpo elemental, núcleo blanco) + explosión final",
    cameraShake: { intensity: 0.7, duration: 0.35 },
    hitStopSeconds: 0.09,
  },
  {
    recipeId: "combat_ice_crystal_burst",
    name: "Explosión Radial de Cristales",
    intentKeywords: ["explosión", "cristales", "hielo", "burst", "área", "aoe"],
    module: "LihFolkVFX",
    preset: "IceExplosion",
    defaultElement: "ice",
    supportedElements: ["ice", "void", "violet", "teal", "fire", "holy"],
    threeValueRule: "Destello blanco-cian + anillo de escarcha + racimo de cristales 3D que emergen y estallan en fragmentos",
    cameraShake: { intensity: 0.6, duration: 0.25 },
    hitStopSeconds: 0.1,
  },
  {
    recipeId: "dopamine_slime_extract_pop",
    name: "Extracción Dopamínica ySubida de Nivel",
    intentKeywords: ["extraer", "slime", "recompensa", "dopamina", "levelup", "captura"],
    module: "LihFolkVFX_Abilities",
    preset: "LevelUp",
    defaultElement: "holy",
    supportedElements: ["holy", "teal", "violet", "fire", "ice", "void"],
    threeValueRule: "Doble anillo ascendente en los pies + pilar de luz + fuente de destellos + rebote elástico",
    cameraShake: { intensity: 0.35, duration: 0.18 },
    hitStopSeconds: 0.06,
  },
  {
    recipeId: "character_power_aura",
    name: "Aura de Poder y Contorno de Silueta",
    intentKeywords: ["aura", "transformación", "brillo", "mutación", "titánico"],
    module: "LihFolkVFX_Abilities",
    preset: "Aura",
    defaultElement: "void",
    supportedElements: ["void", "fire", "ice", "lightning", "holy", "violet", "teal", "plasma"],
    threeValueRule: "Highlight de borde limpio (sin lavar el cuerpo) + anillo respirando en el suelo + motas oscuras y brillantes",
    cameraShake: { intensity: 0.0, duration: 0.0 },
    hitStopSeconds: 0.0,
  },
];

/** Filter VFX recipes by user intent keyword or return all. */
export function listVfxRecipes(intentQuery = "") {
  const q = String(intentQuery || "").trim().toLowerCase();
  if (!q) return VFX_RECIPE_CATALOG;
  return VFX_RECIPE_CATALOG.filter(
    (r) =>
      r.recipeId.toLowerCase().includes(q) ||
      r.name.toLowerCase().includes(q) ||
      r.preset.toLowerCase().includes(q) ||
      r.intentKeywords.some((k) => k.toLowerCase().includes(q)),
  );
}

/**
 * Choreographed Multi-Phase Storyboards for Ultimate Abilities & World Events (e.g., Meteor Shower),
 * plus 4-Layer Surface Mutation Stacks for Plants/Slimes.
 */
export const VFX_STORYBOARDS = [
  {
    storyboardId: "event_meteor_mutation_shower",
    name: "Evento Climático: Lluvia de Meteoritos de Mutación",
    category: "world_mutation_event",
    totalDurationSeconds: 3.2,
    requiredSmall3DMeshesForBatch10: [
      "vfx_mesh_meteorito_roca",
      "vfx_mesh_crater_anillo",
      "mutacion_esquirlas_meteoro",
    ],
    phases: [
      "1. Aviso Climático (0.0s-1.0s): Cielo y atmósfera cambian de color + estruendo lejano.",
      "2. Telégrafo en Suelo (0.6s-1.8s): Anillo de advertencia brillante en el suelo sobre la planta/slime.",
      "3. Caída Diagonal 3D (1.1s-1.8s): Baja el modelo 3D del meteorito girando con estela de fuego y humo oscuro.",
      "4. Impacto + Cráter + HitStop (1.8s-2.4s): Destello de 1 frame, CameraShake, onda expansiva y escombros.",
      "5. Mutación Persistente en la Planta/Slime (2.1s+): Se aplica el Stack de 4 Capas de Mutación.",
    ],
  },
  {
    storyboardId: "ultimate_abyssal_cataclysm",
    name: "Habilidad Definitiva (Ultimate): Cataclismo Abismal",
    category: "ultimate_ability",
    totalDurationSeconds: 2.8,
    requiredSmall3DMeshesForBatch10: ["vfx_mesh_nucleo_abismal"],
    phases: [
      "1. Enfoque Cinemático (0.0s-0.75s): Cámara hace zoom (FOV 70->52), el mapa se oscurece 30% y carga energía (ChargeUp).",
      "2. Invocación 3D (0.75s-1.30s): Aparece el núcleo/coloso 3D y lanza el haz principal (BeamLaser).",
      "3. Detonación Clímax (1.30s-2.10s): Explosión radial de cristales (IceExplosion) + HitStop + CameraShake.",
      "4. Residuo / Aftermath (2.10s-2.80s): Grietas luminosas y humo que se erosiona suavemente.",
    ],
  },
];

export const MUTATION_SURFACE_STACKS = [
  {
    mutationId: "mut_meteoric_magma",
    name: "Mutación Meteórica Incandescente (Planta / Slime)",
    layers: [
      "Capa 1 (Superficie): Material roca volcánica con venas de neón.",
      "Capa 2 (Injerto 3D - sale de Tanda de 10): Esquirlas de meteorito incrustadas en los tallos/cuerpo.",
      "Capa 3 (Silueta): Highlight de borde naranja ardiente visible a distancia.",
      "Capa 4 (Partícula local): Brasas ascendentes y ceniza oscura suave.",
    ],
  },
  {
    mutationId: "mut_celestial_crystal",
    name: "Mutación Cristalizada Celestial (Planta / Slime)",
    layers: [
      "Capa 1 (Superficie): Cristal facetado translúcido con brillo interior.",
      "Capa 2 (Injerto 3D - sale de Tanda de 10): Racimos de cristales cian brotando de las hojas/cabeza.",
      "Capa 3 (Silueta): Highlight cian-blanco brillante.",
      "Capa 4 (Partícula local): Destellos prismáticos flotantes.",
    ],
  },
];

/**
 * Synthesize an original, fluid, fighting-game-grade 60 Hz VFX Animation & Choreography
 * Blueprint for ANY user request (slash, ultimate, meteor event, or plant/slime mutation).
 */
export function composeOriginalVfx({
  prompt,
  kind = "auto",
  element = "void",
  targetType = "enemy_or_ground",
}) {
  const text = String(prompt || "Efecto Original").trim();
  const lower = text.toLowerCase();

  const resolvedKind =
    kind !== "auto"
      ? kind
      : lower.includes("meteor") || lower.includes("cielo") || lower.includes("lluvia") || lower.includes("evento")
        ? "world_mutation_event"
        : lower.includes("planta") || lower.includes("mutacion") || lower.includes("mutación")
          ? "surface_mutation"
          : lower.includes("definitiva") || lower.includes("ultimate") || lower.includes("ulti") || lower.includes("cataclismo")
            ? "ultimate_ability"
            : "fighting_skill";

  const required3DMeshes = [];
  if (resolvedKind === "world_mutation_event") {
    required3DMeshes.push(
      {
        assetId: "vfx_mesh_proyectil_evento",
        name: `Proyectil 3D (${text})`,
        category: "mutation",
        detailTier: "low_batch_10",
        maxTris: 800,
      },
      {
        assetId: "vfx_mesh_crater_impacto",
        name: "Anillo de Cráter y Escombros 3D",
        category: "mutation",
        detailTier: "low_batch_10",
        maxTris: 900,
      },
      {
        assetId: "mutacion_injerto_planta",
        name: "Injerto 3D de Mutación sobre Planta/Slime",
        category: "mutation",
        detailTier: "low_batch_10",
        maxTris: 600,
      },
    );
  } else if (resolvedKind === "surface_mutation") {
    required3DMeshes.push({
      assetId: "mutacion_injerto_superficie",
      name: `Brotes/Cristales 3D para ${text}`,
      category: "mutation",
      detailTier: "low_batch_10",
      maxTris: 600,
    });
  } else if (resolvedKind === "ultimate_ability") {
    required3DMeshes.push({
      assetId: "vfx_mesh_nucleo_ultimate",
      name: `Núcleo / Geometría 3D de Definitiva (${text})`,
      category: "mutation",
      detailTier: "low_batch_10",
      maxTris: 1000,
    });
  }

  return {
    prompt: text,
    resolvedKind,
    element,
    targetType,
    tickRateHz: 60,
    threeValueRule: {
      layer1_hotCore: "Blanco incandescente en el centro/filo (escala 0.35x, 1-2 frames de destello en impacto)",
      layer2_elementBody: `Cuerpo saturado del elemento '${element}' con gradiente de erosión suave (smoothErode)`,
      layer3_darkInkRim: "Tinta oscura saturada en el borde exterior y charco de suelo para contraste máximo",
    },
    fluidAnimationTimeline: [
      {
        phase: 1,
        name: "Anticipación / Wind-Up (Compresión)",
        windowSeconds: [0.0, 0.28],
        easing: "cubic-bezier(0.22, 1, 0.36, 1)",
        cameraAndLighting: "FOV 70 -> 56, exposición ambiental -25% para destacar el brillo del núcleo",
        vfxAction: "Anillos de suelo implosionan y motas oscuras/brillantes convergen al origen (ChargeUp)",
      },
      {
        phase: 2,
        name: "Telégrafo de Suelo / Trayectoria",
        windowSeconds: [0.18, 0.65],
        easing: "linear_fill_with_hot_leading_edge",
        cameraAndLighting: "Seguimiento suave hacia el punto de impacto",
        vfxAction: "Raycast al suelo alineado a la pendiente (Telegraph) llenándose hasta el borde",
      },
      {
        phase: 3,
        name: "Entrega 3D / Barrido Fluido (Spring Overshoot)",
        windowSeconds: [0.55, 0.90],
        easing: "spring(omega0=28, zeta=0.55)",
        cameraAndLighting: "Luz puntual única sin sombras siguiendo el frente del proyectil/corte",
        vfxAction: "Descenso diagonal o arco frontal (±100°) con malla 3D, estela cónica y copias fantasma",
      },
      {
        phase: 4,
        name: "Frame de Contacto / Clímax de Juego de Pelea",
        windowSeconds: [0.90, 1.02],
        easing: "instant_impulse",
        cameraAndLighting: "Flash de impacto de 1 frame + HitStop (0.09s) + CameraShake cúbico (S = T^3)",
        vfxAction: "Estallido radial de cristales/escombros, anillo de onda de choque y corte de aire",
      },
      {
        phase: 5,
        name: "Erosión Suave y Residuo en Suelo (Aftermath)",
        windowSeconds: [1.02, 1.95],
        easing: "smoothstep_erode_out",
        cameraAndLighting: "Recuperación elástica de cámara a FOV 70 y restauración de atmósfera",
        vfxAction: "Grietas luminosas y humo texturizado se disipan por erosión sin cortes bruscos",
      },
      {
        phase: 6,
        name: "Imbuición de Mutación de 4 Capas (Si aplica a Planta / Slime / Arma)",
        windowSeconds: [1.10, 999.0],
        easing: "continuous_breathing_sine",
        cameraAndLighting: "Highlight de contorno visible hasta 150 studs",
        vfxAction:
          "1) Material reactivo + 2) Injerto 3D (de Tanda de 10) + 3) Highlight Rim + 4) Emisor ambiental local",
      },
    ],
    required3DMeshesForBatch10: required3DMeshes,
  };
}

/** Search across both the Ecosystem Registry and LihFolk 815-model catalog. */
export function searchAllAssets(query, { registryPath = DEFAULT_REGISTRY_PATH, packRoot } = {}) {
  const q = String(query || "").trim().toLowerCase();
  const registry = loadEcosystemRegistry(registryPath);
  const lihfolk = loadLihFolkCatalogs(packRoot);

  const customMatches = registry.reusableAssets.filter(
    (a) =>
      !q ||
      a.assetId.toLowerCase().includes(q) ||
      a.name.toLowerCase().includes(q) ||
      (a.tags || []).some((t) => t.toLowerCase().includes(q)),
  );

  const lihfolkMatches = lihfolk.models
    .filter(
      (m) =>
        !q ||
        m.kit.toLowerCase().includes(q) ||
        m.asset.toLowerCase().includes(q) ||
        m.type.toLowerCase().includes(q) ||
        m.tags.toLowerCase().includes(q),
    )
    .slice(0, 25);

  return {
    query: q,
    customMatches,
    lihfolkMatches,
  };
}

/**
 * Generate a 5-layer Modular Luau Framework blueprint whenever the user asks
 * for a system that creates/manages new things (e.g. Pets, Forge, Quests, Relics, Combat).
 */
export function generateFrameworkBlueprint(systemName, itemFields = ["id", "name", "rarity", "assetId", "vfxRecipeId"]) {
  const clean = String(systemName || "Custom")
    .replace(/[^a-zA-Z0-9]/g, "")
    .replace(/^[a-z]/, (c) => c.toUpperCase());

  return {
    systemName: clean,
    architecture: "5-Layer Data-Driven Luau Framework (--!strict, MCP-deployable)",
    extensibilityRule:
      "Adding a new item/creature/upgrade requires ONLY adding one entry to Catalogs.luau and registering its 3D asset in ecosystem_registry.json.",
    modules: [
      {
        layer: "1_Catalog",
        file: `project_template/src/shared/${clean}Catalogs.luau`,
        studioPath: `game.ReplicatedStorage.RAASE_Shared.${clean}Catalogs`,
        responsibility: `Pure data table of all ${clean} items (${itemFields.join(", ")}), rarities, and VFX/3D bindings.`,
      },
      {
        layer: "2_Rules",
        file: `project_template/src/shared/${clean}Rules.luau`,
        studioPath: `game.ReplicatedStorage.RAASE_Shared.${clean}Rules`,
        responsibility: `Pure deterministic validation, capacity, cooldown, and math functions (testable without yields).`,
      },
      {
        layer: "3_ServerService",
        file: `project_template/src/server/${clean}Service.luau`,
        studioPath: `game.ServerScriptService.RAASE_Server.${clean}Service`,
        responsibility: `Server-authoritative state owner, remote rate-limiting, proximity checks, and reward granting.`,
      },
      {
        layer: "4_ClientController",
        file: `project_template/src/client/${clean}Controller.client.luau`,
        studioPath: `game.StarterPlayer.StarterPlayerScripts.RAASE_Client.${clean}Controller`,
        responsibility: `Responsive HUD, input prompts, 3D model attachment, and VFXRecipeCatalog playback.`,
      },
      {
        layer: "5_RuntimeTests",
        file: `project_template/src/shared/${clean}RulesTests.luau`,
        studioPath: `game.ReplicatedStorage.RAASE_Shared.${clean}RulesTests`,
        responsibility: `Automated RED/GREEN assertions callable via official Studio MCP execute_luau.`,
      },
    ],
  };
}

function runCli() {
  const argv = process.argv.slice(2);
  const cmd = argv[0] || "status";

  const getFlag = (name, fallback = null) => {
    const idx = argv.indexOf(name);
    if (idx >= 0 && idx + 1 < argv.length) return argv[idx + 1];
    return fallback;
  };

  if (cmd === "status") {
    const registryPath = getFlag("--registry", DEFAULT_REGISTRY_PATH);
    const registry = loadEcosystemRegistry(registryPath);
    const lihfolk = loadLihFolkCatalogs();
    const nextPrompt = getNextNanoBananaRequest(registryPath);
    console.log(
      JSON.stringify(
        {
          vaultConnected: Boolean(lihfolk.vaultRoot),
          vaultRoot: lihfolk.vaultRoot,
          assetPackConnected: lihfolk.connected,
          assetPackRoot: lihfolk.assetPackRoot,
          counts: {
            lihFolkShippableModels: lihfolk.models.length,
            lihFolkMaterials: lihfolk.materials.length,
            lihFolkSkies: lihfolk.skies.length,
            lihFolkAnimations: lihfolk.animations.length,
            customReusableModels3D: registry.reusableAssets.length,
            pendingNanoBananaQueue: registry.missingQueue.length,
            vfxFightingRecipes: VFX_RECIPE_CATALOG.length,
          },
          nextInQueue: nextPrompt.request ? nextPrompt.request.assetId : null,
        },
        null,
        2,
      ),
    );
    return;
  }

  if (cmd === "next-prompt") {
    const registryPath = getFlag("--registry", DEFAULT_REGISTRY_PATH);
    const mode = getFlag("--mode", "auto");
    const next = getNextNanoBananaRequest(registryPath, { mode });
    console.log(JSON.stringify(next, null, 2));
    return;
  }

  if (cmd === "scaffold-framework") {
    const name = getFlag("--name", "Forge");
    console.log(JSON.stringify(generateFrameworkBlueprint(name), null, 2));
    return;
  }

  if (cmd === "vfx-recipes") {
    const intent = getFlag("--intent", "");
    console.log(JSON.stringify(listVfxRecipes(intent), null, 2));
    return;
  }

  if (cmd === "compose-vfx") {
    const prompt = getFlag("--prompt", "Evento de meteoritos sobre planta");
    const element = getFlag("--element", "fire");
    const kind = getFlag("--kind", "auto");
    console.log(JSON.stringify(composeOriginalVfx({ prompt, element, kind }), null, 2));
    return;
  }

  if (cmd === "link-vault") {
    const vaultRoot = getFlag("--vault", null);
    const assetPackRoot = getFlag("--assets", null);
    const saved = configureLocalVaultPaths({ vaultRoot, assetPackRoot });
    const check = loadLihFolkCatalogs();
    console.log(
      JSON.stringify(
        {
          saved,
          vaultConnected: Boolean(check.vaultRoot),
          assetPackConnected: check.connected,
          modelsLoaded: check.models.length,
        },
        null,
        2,
      ),
    );
    return;
  }

  if (cmd === "search") {
    const q = getFlag("--query", "");
    const registryPath = getFlag("--registry", DEFAULT_REGISTRY_PATH);
    console.log(JSON.stringify(searchAllAssets(q, { registryPath }), null, 2));
    return;
  }

  if (cmd === "register") {
    const registryPath = getFlag("--registry", DEFAULT_REGISTRY_PATH);
    const assetId = getFlag("--id");
    const name = getFlag("--name");
    const category = getFlag("--category", "medium");
    const glbPath = getFlag("--glb");
    const tris = Number(getFlag("--tris", "2500"));
    const heightStuds = Number(getFlag("--height", "4.0"));
    const tagsRaw = getFlag("--tags", "");
    const tags = tagsRaw ? tagsRaw.split(",").map((s) => s.trim()).filter(Boolean) : [assetId];
    const record = registerEcosystemAsset(registryPath, {
      assetId,
      name,
      category,
      glbPath,
      tris,
      heightStuds,
      tags,
    });
    console.log(JSON.stringify({ registered: true, record }, null, 2));
    return;
  }

  if (cmd === "validate-map") {
    const mapFile = getFlag("--map");
    const registryPath = getFlag("--registry", DEFAULT_REGISTRY_PATH);
    if (!mapFile || !fs.existsSync(mapFile)) {
      console.error("ERROR: --map <json-path> is required and must exist");
      process.exit(2);
    }
    const blueprint = JSON.parse(fs.readFileSync(mapFile, "utf8"));
    const result = validateMapBlueprint(blueprint, { registryPath });
    console.log(JSON.stringify(result, null, 2));
    process.exit(result.valid ? 0 : 1);
  }

  console.error(`Unknown command: ${cmd}`);
  process.exit(2);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  runCli();
}
