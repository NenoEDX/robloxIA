#!/usr/bin/env node
/**
 * run_batch.mjs — Runner de lote para roblox-36-asset-pipeline (RAASE 2.1)
 *
 * Lee un assets_manifest.json y ejecuta Blender headless por cada asset
 * (plantillas: blender_export_example.py para meshes, blender_flipbook_example.py para flipbooks).
 * Modo --dry-run imprime los comandos sin ejecutar (degradación cuando no hay Blender).
 *
 * Uso:
 *   node run_batch.mjs --manifest assets_manifest.json --out ../../exports/combat
 *   node run_batch.mjs --manifest assets_manifest.json --out ../../exports/combat --dry-run
 *   node run_batch.mjs --manifest assets_manifest.json --out ../../exports/combat --blender "C:\Program Files\Blender Foundation\Blender 4.2\blender.exe"
 *
 * Salida:
 *   <out>/<id>.glb + <out>/<id>_preview.png        (meshes)
 *   <out>/frames/impact_*.png                       (flipbooks)
 *   <out>/ASSETS_HANDOFF.md                         (reporte de handoff — completar previews/ids tras import)
 *
 * Sin dependencias externas (Node 20+). Detección de Blender: --blender > $BLENDER_BIN > "blender" (PATH).
 */

import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const VALID_FLIPBOOK_FRAMES = new Set([4, 16, 64]);

function parseArgs(argv) {
  const args = { dryRun: false, blender: process.env.BLENDER_BIN || "blender" };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--dry-run") args.dryRun = true;
    else if (a === "--manifest" || a === "--out" || a === "--blender") {
      const value = argv[++i];
      if (!value || value.startsWith("--")) fail(`${a} requiere un valor.`);
      if (a === "--manifest") args.manifest = value;
      else if (a === "--out") args.out = value;
      else args.blender = value;
    } else {
      fail(`flag desconocido: ${a} (usar --manifest, --out, --blender, --dry-run).`);
    }
  }
  return args;
}

function fail(msg) {
  console.error(`[RAASE batch] ERROR: ${msg}`);
  process.exit(1);
}

function checkBlender(bin) {
  const probe = spawnSync(bin, ["--version"], { encoding: "utf8" });
  if (probe.error || probe.status !== 0) {
    return null;
  }
  const firstLine = String(probe.stdout || "").split(/\r?\n/)[0].trim();
  return firstLine || "blender (version desconocida)";
}

function buildCommand(asset, outDir, blenderBin) {
  if (typeof asset.id !== "string" || asset.id.trim() === "") {
    fail("cada asset requiere un id string no vacío.");
  }
  if (asset.tipo === "mesh") {
    const dims = asset.dimensionesStuds || [];
    if (!Array.isArray(dims) || dims.length !== 3) {
      fail(`asset "${asset.id}": dimensionesStuds debe ser [x,y,z] en studs.`);
    }
    const meters = dims.map((d) => Number(d));
    if (meters.some((n) => !Number.isFinite(n) || n <= 0)) {
      fail(`asset "${asset.id}": dimensionesStuds debe contener 3 números finitos > 0.`);
    }
    const dimsArg = meters.map((n) => (n * 0.28).toFixed(3)).join(","); // 1 stud ≈ 0.28 m (ratio 25:7)
    return [
      blenderBin,
      "--background",
      "--python-exit-code",
      "1",
      "--python",
      path.join(__dirname, "blender_export_example.py"),
      "--",
      "--name",
      asset.id,
      "--out",
      outDir,
      "--dims",
      dimsArg,
    ];
  }
  if (asset.tipo === "flipbook") {
    const frames = Number(asset.frames || 16);
    if (!VALID_FLIPBOOK_FRAMES.has(frames)) {
      fail(`asset "${asset.id}": frames inválido (${frames}) — el motor acepta 4, 16 o 64.`);
    }
    const size = Math.min(512, Math.floor(1024 / Math.sqrt(frames))); // atlas ≤ 1024
    const flipOut = path.resolve(outDir, asset.id); // frames aislados por asset (sin colisión de nombres)
    return [
      blenderBin,
      "--background",
      "--python-exit-code",
      "1",
      "--python",
      path.join(__dirname, "blender_flipbook_example.py"),
      "--",
      "--out",
      flipOut,
      "--frames",
      String(frames),
      "--size",
      String(size),
    ];
  }
  fail(`asset "${asset.id}": tipo desconocido "${asset.tipo}" (soportados: mesh, flipbook).`);
  return [];
}

function dimsLabel(asset) {
  if (asset.tipo === "mesh" && Array.isArray(asset.dimensionesStuds) && asset.dimensionesStuds.length === 3) {
    return `${asset.dimensionesStuds.join("×")} studs`;
  }
  return "—";
}

function verifyArtifact(asset, outDir) {
  if (asset.tipo === "mesh") {
    return fs.existsSync(path.join(outDir, `${asset.id}.glb`));
  }
  const framesDir = path.join(outDir, asset.id, "frames");
  if (!fs.existsSync(framesDir)) {
    return false;
  }
  return fs.readdirSync(framesDir).some((f) => f.endsWith(".png"));
}

function writeHandoff(outDir, manifest, results, blenderInfo) {
  const lines = [];
  lines.push(`# ASSETS_HANDOFF — Lote "${manifest.batch}"`);
  lines.push("");
  lines.push(`> Generado por run_batch.mjs (RAASE 2.1 / roblox-36-asset-pipeline). Blender: ${blenderInfo}`);
  lines.push("");
  lines.push("## Assets");
  lines.push("");
  lines.push("| id | tipo | rol | dims | artefactos | estado |");
  lines.push("|---|---|---|---|---|---|");
  for (const r of results) {
    const artifacts = r.tipo === "mesh" ? "`<id>.glb` + `<id>_preview.png`" : "`<id>/frames/*.png` (→ atlas, subir como Texture)";
    lines.push(`| ${r.id} | ${r.tipo} | ${r.rol || "-"} | ${r.dims || "—"} | ${artifacts} | ${r.status} |`);
  }
  lines.push("");
  lines.push("## Import en Studio (paso del creador)");
  lines.push("");
  lines.push("1. Meshes: Studio → 3D Importer → **Scale Unit = Meter** (el default Stud produce ~3.57× de diferencia) → CollisionFidelity según el rol (Box/Hull).");
  lines.push("2. Flipbooks: subir el atlas como Texture (≤1024px) → usar su `rbxassetid://` en el `ParticleEmitter`.");
  lines.push("3. Registrar cada `rbxassetid://` en el manifiesto y avisar **LISTO** al agente para la verificación post-import.");
  lines.push("");
  lines.push("## Verificación post-import (agente, vía Companion Plugin)");
  lines.push("");
  lines.push("- `INSPECT_OBJECT` por mesh: escala (size vs objetivo ±5%), posición/orientación, CanCollide.");
  lines.push("- Tri count y CollisionFidelity **no son inspeccionables por RPC** (deuda del plugin): el creador los confirma desde el editor.");
  fs.mkdirSync(outDir, { recursive: true });
  fs.writeFileSync(path.join(outDir, "ASSETS_HANDOFF.md"), lines.join("\n"), "utf8");
}

function main() {
  const args = parseArgs(process.argv);
  if (!args.manifest || !args.out) {
    fail("faltan --manifest y/o --out. Ver el encabezado del archivo para el uso.");
  }
  if (!fs.existsSync(args.manifest)) {
    fail(`no existe el manifiesto: ${args.manifest}`);
  }

  const manifest = JSON.parse(fs.readFileSync(args.manifest, "utf8"));
  const assets = Array.isArray(manifest.assets) ? manifest.assets : [];
  if (assets.length === 0) {
    fail("el manifiesto no contiene assets.");
  }

  const outDir = path.resolve(args.out);
  let blenderInfo = "no verificado (dry-run)";
  if (!args.dryRun) {
    const detected = checkBlender(args.blender);
    if (!detected) {
      console.error("[RAASE batch] Blender no disponible en esta máquina.");
      console.error("[RAASE batch] RECOMENDADO: instalar Blender (blender.org — gratis) para fabricación local de mallas y flipbooks.");
      console.error("[RAASE batch] Alternativas: correr este mismo comando en la PC con Blender (--blender <ruta>) o usar --dry-run para obtener los comandos exactos.");
      process.exit(2);
    }
    blenderInfo = detected;
    console.log(`[RAASE batch] Blender: ${detected}`);
  }

  const results = [];
  for (const asset of assets) {
    const cmd = buildCommand(asset, outDir, args.blender);
    if (args.dryRun) {
      console.log(`[RAASE batch][dry-run] ${cmd.map((a) => (String(a).includes(" ") ? `"${a}"` : String(a))).join(" ")}`);
      results.push({ id: asset.id, tipo: asset.tipo, rol: asset.rol, dims: dimsLabel(asset), status: "dry-run (sin ejecutar)" });
      continue;
    }
    console.log(`[RAASE batch] Generando ${asset.id} (${asset.tipo})...`);
    const run = spawnSync(cmd[0], cmd.slice(1), { encoding: "utf8" });
    const artifactOk = run.status === 0 && verifyArtifact(asset, outDir);
    if (artifactOk) {
      const logLine = String(run.stdout || "").split(/\r?\n/).find((l) => l.includes("[RAASE]")) || "";
      console.log(`  ✅ ${asset.id} ${logLine}`.trim());
      results.push({ id: asset.id, tipo: asset.tipo, rol: asset.rol, dims: dimsLabel(asset), status: "generado" });
    } else {
      const reason = run.status !== 0 ? `exit ${run.status}` : "artefacto no encontrado";
      console.error(`  ❌ ${asset.id} falló (${reason})`);
      results.push({ id: asset.id, tipo: asset.tipo, rol: asset.rol, dims: dimsLabel(asset), status: `falló (${reason})` });
    }
  }

  writeHandoff(outDir, manifest, results, blenderInfo);
  const okCount = results.filter((r) => r.status === "generado" || r.status.startsWith("dry-run")).length;
  console.log(`[RAASE batch] ${okCount}/${results.length} assets procesados. Handoff: ${path.join(outDir, "ASSETS_HANDOFF.md")}`);
}

main();
