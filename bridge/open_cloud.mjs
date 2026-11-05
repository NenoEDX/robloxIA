// @ts-check
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);

export const MAX_OPEN_CLOUD_TRIANGLES = 20000;
export const MAX_OPEN_CLOUD_FILE_BYTES = 20 * 1024 * 1024; // 20 MB

/**
 * Resuelve el MIME type exacto requerido por Roblox Open Cloud Assets API (POST /assets/v1/assets)
 * a partir de la extensión del archivo y el assetType.
 *
 * @param {string} filePath
 * @param {'Model' | 'Audio' | 'Decal'} assetType
 * @returns {string}
 */
export function resolveOpenCloudMimeType(filePath, assetType) {
  const ext = path.extname(String(filePath || "")).toLowerCase();

  if (ext === ".rbxm" || ext === ".rbxmx") {
    throw new Error(
      `[OpenCloud] Formato '${ext}' rechazado para ingesta externa: Open Cloud v1/assets rechaza modelos .rbxm/.rbxmx sintetizados fuera de Studio. Exporta como .glb (model/gltf-binary) o .fbx (model/fbx), o construye en Studio vía StudioMCP/MCPBridge.`
    );
  }

  if (assetType === "Model") {
    if (ext === ".fbx") return "model/fbx";
    if (ext === ".glb" || ext === "") return "model/gltf-binary";
    throw new Error(
      `[OpenCloud] Extensión '${ext}' no soportada para assetType='Model'. Usa '.glb' (model/gltf-binary) o '.fbx' (model/fbx).`
    );
  }

  if (assetType === "Audio") {
    if (ext === ".ogg") return "audio/ogg";
    if (ext === ".mp3" || ext === "") return "audio/mpeg";
    throw new Error(
      `[OpenCloud] Extensión '${ext}' no soportada para assetType='Audio'. Usa '.mp3' (audio/mpeg) u '.ogg' (audio/ogg).`
    );
  }

  if (assetType === "Decal") {
    if (ext === ".jpg" || ext === ".jpeg") return "image/jpeg";
    if (ext === ".bmp") return "image/bmp";
    if (ext === ".tga") return "image/tga";
    if (ext === ".png" || ext === "") return "image/png";
    throw new Error(
      `[OpenCloud] Extensión '${ext}' no soportada para assetType='Decal'. Usa '.png', '.jpg', '.bmp' o '.tga'.`
    );
  }

  return "application/octet-stream";
}

/**
 * Valida las invariantes de un archivo antes de subirlo a Open Cloud v1/assets:
 * - Existencia y tamaño <= 20 MB
 * - Presupuesto poligonal <= 20,000 triángulos (cuando se informa triangleCount)
 * - Extensión compatible con el assetType (bloqueando .rbxm/.rbxmx externos)
 *
 * @param {{ filePath: string, assetType: 'Model' | 'Audio' | 'Decal', triangleCount?: number, fsImpl?: typeof fs }} params
 * @returns {{ mimeType: string, sizeBytes: number, triangleCount: number | null }}
 */
export function validateOpenCloudAssetCandidate({
  filePath,
  assetType,
  triangleCount,
  fsImpl = fs,
}) {
  if (!fsImpl.existsSync(filePath)) {
    throw new Error(`File not found: ${filePath}`);
  }

  const mimeType = resolveOpenCloudMimeType(filePath, assetType);
  const stat = fsImpl.statSync(filePath);
  const sizeBytes = Number(stat.size || 0);

  if (sizeBytes > MAX_OPEN_CLOUD_FILE_BYTES) {
    throw new Error(
      `[OpenCloud] El archivo '${path.basename(filePath)}' pesa ${sizeBytes} bytes y excede el límite de 20 MB (${MAX_OPEN_CLOUD_FILE_BYTES} bytes) de Open Cloud v1/assets.`
    );
  }

  if (typeof triangleCount === "number") {
    if (triangleCount > MAX_OPEN_CLOUD_TRIANGLES) {
      throw new Error(
        `[OpenCloud] La malla '${path.basename(filePath)}' tiene ${triangleCount} triángulos y excede el límite de ${MAX_OPEN_CLOUD_TRIANGLES} triángulos de Roblox.`
      );
    }
  }

  return {
    mimeType,
    sizeBytes,
    triangleCount: typeof triangleCount === "number" ? triangleCount : null,
  };
}

/**
 * Upload an asset (audio, model .glb/.fbx, decal texture) using Roblox Open Cloud API
 * Spec: https://create.roblox.com/docs/cloud/reference/Asset
 *
 * @param {Object} options
 * @param {string} options.filePath Local path to the asset (.glb, .fbx, .png, .mp3, .ogg)
 * @param {'Model' | 'Audio' | 'Decal'} options.assetType
 * @param {string} options.displayName Human-readable asset name
 * @param {string} [options.description]
 * @param {number} [options.triangleCount] Optional triangle count for pre-upload budget validation
 * @param {string} [options.apiKey] Roblox Open Cloud API key (falls back to ROBLOX_OPEN_CLOUD_API_KEY or ROBLOX_API_KEY)
 * @param {string} [options.userId] Creator user ID (falls back to ROBLOX_CREATOR_USER_ID or ROBLOX_USER_ID)
 * @param {string} [options.groupId] Optional creator group ID (falls back to ROBLOX_GROUP_ID)
 * @param {string} [options.universeId] Optional universe ID
 * @param {typeof fetch} [options.fetchImpl] Injectable fetch implementation for unit testing
 * @param {number} [options.pollIntervalMs] Polling interval in ms for async operation (default 1000)
 * @returns {Promise<{ assetId: string, operationId?: string, rbxassetid: string, mimeType: string }>}
 */
export async function uploadAssetOpenCloud({
  filePath,
  assetType,
  displayName,
  description = "Uploaded automatically by RAASE 3.0 / robloxIA",
  triangleCount,
  apiKey = process.env.ROBLOX_OPEN_CLOUD_API_KEY || process.env.ROBLOX_API_KEY,
  userId = process.env.ROBLOX_CREATOR_USER_ID || process.env.ROBLOX_USER_ID,
  groupId = process.env.ROBLOX_GROUP_ID,
  universeId = process.env.ROBLOX_UNIVERSE_ID,
  fetchImpl = fetch,
  pollIntervalMs = 1000,
}) {
  const { mimeType } = validateOpenCloudAssetCandidate({
    filePath,
    assetType,
    triangleCount,
  });

  if (!apiKey) {
    if (!userId && !groupId) {
      console.warn("[OpenCloud] Warning: ROBLOX_USER_ID / ROBLOX_CREATOR_USER_ID is not set in mock mode.");
    }
    console.warn("[OpenCloud] ROBLOX_API_KEY is not set. Returning mock asset ID for local testing.");
    const mockId = `mock_${Date.now()}`;
    return {
      assetId: mockId,
      rbxassetid: `rbxassetid://${mockId}`,
      mimeType,
    };
  }

  if (!userId && !groupId) {
    throw new Error(
      "ROBLOX_USER_ID (or ROBLOX_CREATOR_USER_ID / ROBLOX_GROUP_ID) environment variable is required when ROBLOX_API_KEY is provided for Open Cloud asset creation."
    );
  }

  const fileData = fs.readFileSync(filePath);
  const boundary = `----WebKitFormBoundary${Math.random().toString(36).substring(2)}`;

  const creator = groupId ? { groupId: String(groupId) } : { userId: String(userId) };

  const requestMetadata = JSON.stringify({
    assetType,
    displayName,
    description,
    creationContext: {
      creator,
      expectedPrice: 0,
    },
  });

  const bodyParts = [
    `--${boundary}\r\n`,
    `Content-Disposition: form-data; name="request"\r\n`,
    `Content-Type: application/json\r\n\r\n`,
    `${requestMetadata}\r\n`,
    `--${boundary}\r\n`,
    `Content-Disposition: form-data; name="fileContent"; filename="${path.basename(filePath)}"\r\n`,
    `Content-Type: ${mimeType}\r\n\r\n`,
  ];

  const preBuffer = Buffer.from(bodyParts.join(""));
  const postBuffer = Buffer.from(`\r\n--${boundary}--\r\n`);
  const fullBody = Buffer.concat([preBuffer, fileData, postBuffer]);

  const response = await fetchImpl("https://apis.roblox.com/assets/v1/assets", {
    method: "POST",
    headers: {
      "x-api-key": apiKey,
      "Content-Type": `multipart/form-data; boundary=${boundary}`,
    },
    body: fullBody,
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Open Cloud upload failed (${response.status}): ${errText}`);
  }

  const result = await response.json();
  let assetId = result.response?.assetId;

  // If async operation is returned, poll until done
  if (!assetId && result.path) {
    const opPath = String(result.path).replace(/^\/+/, "");
    const opUrl = opPath.startsWith("assets/v1/")
      ? `https://apis.roblox.com/${opPath}`
      : `https://apis.roblox.com/assets/v1/${opPath}`;
    for (let i = 0; i < 10; i++) {
      await new Promise((r) => setTimeout(r, pollIntervalMs));
      const opRes = await fetchImpl(opUrl, { headers: { "x-api-key": apiKey } });
      if (opRes.ok) {
        const opData = await opRes.json();
        if (opData.done) {
          if (opData.error) {
            throw new Error(
              `Open Cloud upload rejected (${opData.error.code}): ${opData.error.message || JSON.stringify(opData.error)}`
            );
          }
          if (opData.response?.assetId) {
            assetId = opData.response.assetId;
            break;
          }
        }
      }
    }
  }

  if (!assetId && result.response?.assetId) {
    assetId = result.response.assetId;
  }

  if (!assetId) {
    throw new Error(
      `Open Cloud upload operation timed out or failed to return assetId: ${result.path || "unknown operation"}`
    );
  }

  return {
    assetId: String(assetId),
    operationId: result.path,
    rbxassetid: `rbxassetid://${assetId}`,
    mimeType,
  };
}

/**
 * Sincroniza un archivo de manifiesto (ej. asset_manifest.json) inyectando el `rbxassetid://<id>`
 * y el estado de ingesta Open Cloud para un asset específico.
 *
 * @param {string} manifestPath
 * @param {{ assetName: string, assetId: string, rbxassetid?: string, format?: string, tris?: number }} entryUpdate
 */
export function updateAssetManifestWithCloudId(manifestPath, entryUpdate) {
  const raw = fs.existsSync(manifestPath) ? fs.readFileSync(manifestPath, "utf8") : '{"assets":{}}';
  const parsed = JSON.parse(raw);
  if (!parsed.assets || typeof parsed.assets !== "object") {
    parsed.assets = {};
  }
  const rbxUri = entryUpdate.rbxassetid || `rbxassetid://${entryUpdate.assetId}`;
  parsed.assets[entryUpdate.assetName] = {
    ...(parsed.assets[entryUpdate.assetName] || {}),
    assetId: String(entryUpdate.assetId),
    rbxassetid: rbxUri,
    format: entryUpdate.format || "GLB",
    ...(typeof entryUpdate.tris === "number" ? { tris: entryUpdate.tris } : {}),
    updatedAt: new Date().toISOString(),
  };
  fs.writeFileSync(manifestPath, JSON.stringify(parsed, null, 2), "utf8");
  return parsed.assets[entryUpdate.assetName];
}

// Simple CLI runner
if (process.argv[1] && path.resolve(process.argv[1]) === __filename) {
  const [, , file, type, name] = process.argv;
  if (!file || !type || !name) {
    console.log("Usage: node open_cloud.mjs <file-path> <Model|Audio|Decal> <display-name>");
    process.exit(0);
  }

  uploadAssetOpenCloud({
    filePath: file,
    assetType: /** @type {any} */ (type),
    displayName: name,
  })
    .then((res) => {
      console.log("[OpenCloud] Success:", res);
    })
    .catch((err) => {
      console.error("[OpenCloud] Error:", err.message);
      process.exit(1);
    });
}
