// @ts-check
/**
 * run_lobby_assets.mjs — Runner del lote "lobby-zombie" (contrato roblox-36-asset-pipeline)
 *
 * Fabricación batch con Blender headless usando geometría dedicada
 * (agent/generators/blender/build_lobby_assets.py) y el manifiesto del lote.
 *
 * Uso:
 *   node agent/generators/run_lobby_assets.mjs --manifest exports/lobby-zombie/assets_manifest.json --out exports/lobby-zombie [--only id1,id2] [--dry-run] [--blender <ruta>]
 *
 * Salidas: <out>/<id>.glb + <out>/<id>_preview.png + <out>/ASSETS_HANDOFF.md + <out>/assets_results.json
 */

import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SCRIPT = path.join(__dirname, 'blender', 'build_lobby_assets.py');
const DEFAULT_BLENDER =
  process.env.BLENDER_BIN || 'C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe';

// Mapa de reemplazo: qué geometría de cubos reemplaza cada malla en Studio.
const REPLACES = {
  mesh_car_sedan: 'Car_Burnt_NS, Car_Blue_NS, Car_Silver_EW, Car_Rust_EW, Car_Green_EW, Car_Gray_NS, Frente_CarWreck, Frente_CarWreck2 (todos los *_Chassis/_Hood/_Cabin/_Wheel/_Hub/_Window/_Bumper)',
  mesh_bus_wreck: 'Bus_Body, Bus_Stripe, Bus_Roof, Bus_Window*, Bus_Window2*, Bus_Door, Bus_Wheel*',
  mesh_truck_military: 'Truck_Cab, Truck_Bed, Truck_Canvas, Truck_Grill, Truck_Stack, Truck_Wheel*',
  mesh_zombie: 'Cage_Subj_Leg*, Cage_Subj_Arm*, Cage_Subj_Torso, Cage_Subj_Head, Cage_Subj_Eye*, Cage_Subj_Mouth, Frente_Body*',
  mesh_mannequin: 'Workshop_Dummy_A_*, Workshop_Dummy_B_*',
  mesh_rifle: 'Arsenal_Rifle_* (todas las piezas de los 8 rifles)',
  mesh_machete: 'Arsenal_Machete_* (blades + grips)',
  mesh_bat: 'Arsenal_Bat_0..2',
  mesh_generator: 'Workshop_Generator, Workshop_GeneratorPipes, Workshop_GeneratorPanel',
  mesh_mg_turret: 'Tower_MG_Barrel, Tower_MG_Mount (la horquilla del mesh reemplaza el afuste)',
  mesh_tree_dead: 'Tree_* (6 árboles × tronco + ramas)',
  mesh_tent_army: 'Camp_Tent_01_*, Camp_Tent_02_*',
};

function fail(msg) {
  console.error(`[lobby-batch] ERROR: ${msg}`);
  process.exit(1);
}

function parseArgs(argv) {
  const args = { blender: DEFAULT_BLENDER, dryRun: false, only: null };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--dry-run') args.dryRun = true;
    else if (['--manifest', '--out', '--blender', '--only'].includes(a)) {
      const v = argv[++i];
      if (!v || v.startsWith('--')) fail(`${a} requiere un valor`);
      if (a === '--only') args.only = v.split(',').map((s) => s.trim());
      else args[a.slice(2)] = v;
    } else fail(`flag desconocido: ${a}`);
  }
  if (!args.manifest || !args.out) fail('faltan --manifest y/o --out');
  return args;
}

function checkBlender(bin) {
  const probe = spawnSync(bin, ['--version'], { encoding: 'utf8' });
  if (probe.error || probe.status !== 0) return null;
  return String(probe.stdout || '').split(/\r?\n/)[0].trim();
}

function main() {
  const args = parseArgs(process.argv);
  if (!fs.existsSync(args.manifest)) fail(`no existe el manifiesto: ${args.manifest}`);
  if (!fs.existsSync(SCRIPT)) fail(`no existe el script Blender: ${SCRIPT}`);
  const manifest = JSON.parse(fs.readFileSync(args.manifest, 'utf8'));
  let assets = Array.isArray(manifest.assets) ? manifest.assets : [];
  if (args.only) {
    assets = assets.filter((a) => args.only.includes(a.id));
    if (assets.length === 0) fail(`--only no coincide con ningún asset del manifiesto`);
  }
  const outDir = path.resolve(args.out);
  fs.mkdirSync(outDir, { recursive: true });

  let blenderInfo = 'no verificado (dry-run)';
  if (!args.dryRun) {
    const detected = checkBlender(args.blender);
    if (!detected) fail(`Blender no disponible en "${args.blender}". Instalar Blender o pasar --blender <ruta>.`);
    blenderInfo = detected;
    console.log(`[lobby-batch] Blender: ${detected}`);
  }

  const results = [];
  for (const asset of assets) {
    const meters = asset.dimensionesStuds.map((d) => Number(d) * 0.28);
    const dimsArg = meters.map((n) => n.toFixed(3)).join(',');
    const cmd = [
      args.blender, '--background', '--python-exit-code', '1', '--python', SCRIPT, '--',
      '--asset', asset.id, '--name', asset.id, '--out', outDir, '--dims', dimsArg,
      '--seed', String(1000 + results.length),
    ];
    if (args.dryRun) {
      console.log(`[dry-run] ${cmd.map((a) => (String(a).includes(' ') ? `"${a}"` : a)).join(' ')}`);
      results.push({ id: asset.id, tipo: asset.tipo, rol: asset.rol, status: 'dry-run', tris: null, dims: null });
      continue;
    }
    console.log(`[lobby-batch] Fabricando ${asset.id}...`);
    const run = spawnSync(cmd[0], cmd.slice(1), { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
    const glbOk = fs.existsSync(path.join(outDir, `${asset.id}.glb`));
    const prevOk = fs.existsSync(path.join(outDir, `${asset.id}_preview.png`));
    const logLine = String(run.stdout || '').split(/\r?\n/).find((l) => l.includes('[RAASE]')) || '';
    const triMatch = logLine.match(/tris=(\d+)/);
    const dimsMatch = logLine.match(/studs=\[([\d.,]+)\]/);
    if (run.status === 0 && glbOk && prevOk) {
      console.log(`  OK ${asset.id} tris=${triMatch ? triMatch[1] : '?'} studs=${dimsMatch ? dimsMatch[1] : '?'}`);
      results.push({
        id: asset.id, tipo: asset.tipo, rol: asset.rol, status: 'generado',
        tris: triMatch ? Number(triMatch[1]) : null,
        dims: dimsMatch ? dimsMatch[1] : null,
      });
    } else {
      const reason = run.status !== 0 ? `exit ${run.status}` : !glbOk ? 'glb no encontrado' : 'preview no encontrada';
      console.error(`  FALLO ${asset.id} (${reason})`);
      const errTail = String(run.stderr || '').split(/\r?\n/).filter(Boolean).slice(-6).join('\n');
      if (errTail) console.error(errTail);
      results.push({ id: asset.id, tipo: asset.tipo, rol: asset.rol, status: `falló (${reason})`, tris: null, dims: null });
    }
  }

  // Resultados JSON
  fs.writeFileSync(
    path.join(outDir, 'assets_results.json'),
    JSON.stringify({ batch: manifest.batch, blender: blenderInfo, generatedAt: new Date().toISOString(), results }, null, 2),
    'utf8'
  );

  // Handoff
  const lines = [];
  lines.push(`# ASSETS_HANDOFF — Lote "${manifest.batch}" (Retry Mesh-First: Conciencia Zombie)`);
  lines.push('');
  lines.push(`> Generado por run_lobby_assets.mjs (RAASE 2.1 / roblox-36-asset-pipeline). Blender: ${blenderInfo}`);
  lines.push('> Doctrina: roblox-12 #266-268 (Mesh-First anti-slop, auditoría contra referencias, anti-geometría flotante).');
  lines.push('> Escala: 1 stud = 0.28 m. Importar con **Scale Unit = Meter**. Frente del modelo hacia **-Z** en Roblox.');
  lines.push('');
  lines.push('## Assets');
  lines.push('');
  lines.push('| id | rol | tris | dims medidas (studs) | artefactos | estado |');
  lines.push('|---|---|---|---|---|---|');
  for (const r of results) {
    lines.push(`| \`${r.id}\` | ${r.rol || '-'} | ${r.tris !== null ? r.tris : '—'} | ${r.dims || '—'} | \`${r.id}.glb\` + \`${r.id}_preview.png\` | ${r.status} |`);
  }
  lines.push('');
  lines.push('## Mapa de reemplazo en Studio (tras importar)');
  lines.push('');
  lines.push('| mesh importado | reemplaza en el lobby |');
  lines.push('|---|---|');
  for (const r of results) {
    if (REPLACES[r.id]) lines.push(`| \`${r.id}\` | ${REPLACES[r.id]} |`);
  }
  lines.push('');
  lines.push('## Pasos del creador (import manual en Studio)');
  lines.push('');
  lines.push('1. Studio → **3D Importer** (o arrastrar el .glb al Viewport).');
  lines.push('2. **Scale Unit = Meter** en las opciones del importer (el default *Stud* produce ~3.57× de diferencia).');
  lines.push('3. CollisionFidelity sugerida: `Box` (vehículos, carpa, árbol) / `Hull` (armas, MG, generador) / `PreciseConvexDecomposition` (zombie solo si hace falta).');
  lines.push('4. Importar todos los .glb del lote en **una sola sesión** del importer si es posible; los previews (`_preview.png`) son la referencia visual.');
  lines.push('5. Avisar **LISTO** al agente: se verifica escala/posición por RPC y se reemplaza la geometría de cubos.');
  lines.push('');
  lines.push('## Verificación post-import (agente, vía Companion Plugin)');
  lines.push('');
  lines.push('- [ ] Escala: `INSPECT_OBJECT.size` vs dims del manifiesto (±5%).');
  lines.push('- [ ] Posición/rotación correctas en el reemplazo (CFrame).');
  lines.push('- [ ] `Anchored = true`, `CanCollide` según rol, `Massless` para decoración.');
  lines.push('- [ ] Tri count y CollisionFidelity: confirmados por el creador desde el editor (no inspeccionables por RPC).');
  lines.push('');
  fs.writeFileSync(path.join(outDir, 'ASSETS_HANDOFF.md'), lines.join('\n'), 'utf8');

  const okCount = results.filter((r) => r.status === 'generado').length;
  console.log(`[lobby-batch] ${okCount}/${results.length} assets generados. Handoff: ${path.join(outDir, 'ASSETS_HANDOFF.md')}`);
  if (okCount !== results.length) process.exitCode = 1;
}

main();
