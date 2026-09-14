// @ts-check
/**
 * RAASE 2.1 — "CONCIENCIA ZOMBIE" Lobby Builder
 * Post-apocalyptic survivor city block: "Última Zona Segura".
 *
 * Usage:
 *   node build_lobby_zombie.mjs cleanup     -> removes old lobby + spawn + stray props
 *   node build_lobby_zombie.mjs structure   -> model + folders + lighting/atmosphere
 *   node build_lobby_zombie.mjs spawn       -> BATCH_SPAWN all zones
 *   node build_lobby_zombie.mjs signs       -> SurfaceGui signs (Spanish copy)
 *   node build_lobby_zombie.mjs camera      -> focus camera on the plaza
 *   node build_lobby_zombie.mjs capture     -> viewport screenshot
 *   node build_lobby_zombie.mjs all         -> structure + spawn + signs + camera
 *
 * Flags: --upsert (update existing instances instead of skipping)
 */

import process from 'node:process';
import { BRIDGE_URL, getBridgeToken, sendCommand } from '../lib/bridge-client.mjs';
import * as K from './lib/lobby_kit.mjs';

const ROOT = 'ConcienciaZombieLobby';
const FOLDERS = [
  '01_Central_Plaza',
  '02_Checkpoint_Norte',
  '03_Arsenal_Bunker',
  '04_Taller_Mejoras',
  '05_Muro_Caidos',
  '06_Ruinas',
  '07_Detalle_Urbano',
  '08_Jaula_Sujeto7',
];

const argv = process.argv.slice(2);
const phase = argv[0] || 'help';
const UPSERT = argv.includes('--upsert');
const RUN_ID = Date.now().toString(36);

// ===========================================================================
// BRIDGE HELPERS
// ===========================================================================

async function batchSpawn(folder, instances, tag) {
  const headers = { 'Content-Type': 'application/json' };
  const token = getBridgeToken();
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const res = await fetch(`${BRIDGE_URL}/api/command/batch`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      parent: `workspace.${ROOT}.${folder}`,
      instances,
      wait: true,
      upsert: UPSERT,
      idempotencyKey: `cz-${tag}-${RUN_ID}`,
    }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(`batch ${tag} -> HTTP ${res.status}: ${data.error || JSON.stringify(data)}`);
  return data;
}

async function chunkedSpawn(folder, parts, fx, zoneTag) {
  const results = [];
  const CHUNK = 150;
  for (let i = 0; i < parts.length; i += CHUNK) {
    const slice = parts.slice(i, i + CHUNK);
    const r = await batchSpawn(folder, slice, `${zoneTag}-p${Math.floor(i / CHUNK)}`);
    results.push({ chunk: `parts#${Math.floor(i / CHUNK)}`, sent: slice.length, result: r.result, ok: r.success });
  }
  for (let i = 0; i < fx.length; i += CHUNK) {
    const slice = fx.slice(i, i + CHUNK);
    const r = await batchSpawn(folder, slice, `${zoneTag}-f${Math.floor(i / CHUNK)}`);
    results.push({ chunk: `fx#${Math.floor(i / CHUNK)}`, sent: slice.length, result: r.result, ok: r.success });
  }
  return results;
}

async function luau(code, label) {
  const res = await sendCommand('EXECUTE_LUAU', { code }, true, 20000);
  console.log(`[luau:${label}]`, JSON.stringify(res?.report?.details ?? res));
  return res;
}

// ===========================================================================
// ZONE BUILDERS — each returns { parts: [], fx: [] }
// ===========================================================================

const Z = {};

// --- 01 CENTRAL PLAZA -------------------------------------------------------
Z['01_Central_Plaza'] = () => {
  const parts = [], fx = [];
  const rng = K.makeRng(101);
  const B = 0.45; // plaza slab top

  parts.push(K.box('Plaza_Base', [80, 0.45, 80], [0, 0.22, 0], [104, 101, 94], 'Concrete'));
  parts.push(K.cyl('Plaza_Raised_Center', [26, 0.3, 26], [0, 0.6, 2], [86, 83, 76], 'Concrete'));
  for (let i = 0; i < 9; i++) {
    parts.push(K.box(`Plaza_Patch_${i}`, [K.range(rng, 4, 9), 0.05, K.range(rng, 4, 9)],
      [K.range(rng, -34, 34), B + 0.02, K.range(rng, -34, 34)],
      [70, 68, 64], 'Asphalt', { rot: [0, K.range(rng, 0, 360), 0], canCollide: false, transparency: 0.05 }));
  }

  // Spawn platform + SpawnLocation
  parts.push(K.box('Spawn_Platform', [18, 0.8, 18], [0, 0.85, 24], [112, 109, 100], 'Concrete'));
  parts.push(K.P('Spawn_Point', {
    className: 'SpawnLocation', size: [10, 0.4, 10], pos: [0, 1.45, 24],
    color: [62, 64, 68], material: 'Cobblestone', canCollide: true,
  }));
  K.sandbagRing(parts, 'Spawn_Guard', 0, 24, 10.4, rng, 0, B);
  parts.push(K.box('Spawn_Info_Board', [6, 3.2, 0.35], [9.5, 2.4, 30.5], [58, 54, 48], 'WoodPlanks',
    { rot: [0, -38, 0] }));
  parts.push(K.cyl('Spawn_Info_PostL', [0.35, 2.6, 0.35], [8.7, 1.3, 31.4], [70, 55, 38], 'Wood'));
  parts.push(K.cyl('Spawn_Info_PostR', [0.35, 2.6, 0.35], [10.3, 1.3, 29.6], [70, 55, 38], 'Wood'));

  // Monument (faces south / spawn)
  parts.push(K.box('Monument_Base', [40, 1.2, 6], [0, 0.6, -37], [80, 78, 72], 'Concrete'));
  parts.push(K.box('Monument_PillarL', [2.5, 12, 2.5], [-16, 6, -37], [70, 68, 62], 'Concrete'));
  parts.push(K.box('Monument_PillarR', [2.5, 12, 2.5], [16, 6, -37], [70, 68, 62], 'Concrete'));
  parts.push(K.box('Monument_Board', [34, 10, 1.4], [0, 15.5, -37], [52, 49, 46], 'Concrete', { rot: [0, 180, 0] }));
  parts.push(K.box('Monument_BraceL', [10, 1, 0.8], [-13, 10.6, -38], [46, 44, 42], 'Metal', { canCollide: false }));
  parts.push(K.box('Monument_BraceR', [10, 1, 0.8], [13, 10.6, -38], [46, 44, 42], 'Metal', { canCollide: false }));
  parts.push(K.box('Monument_SpikeL', [2.5, 0.5, 2.5], [-16, 12.3, -37], [40, 40, 44], 'Metal', { canCollide: false }));
  parts.push(K.box('Monument_SpikeR', [2.5, 0.5, 2.5], [16, 12.3, -37], [40, 40, 44], 'Metal', { canCollide: false }));
  K.sandbagLine(parts, 'Monument_Bags', -14, -33.5, 14, -33.5, 2, rng, B);
  fx.push(K.light('Monument_Board', 'Monument_FloodL', { color: [255, 214, 170], brightness: 1.6, range: 26, shadows: false }));
  fx.push(K.light('Monument_Base', 'Monument_FloodR', { color: [255, 214, 170], brightness: 1.2, range: 22, shadows: false }));

  // Communal bonfire
  K.makeBarrel(parts, fx, 'Fire_Central', 0, 2, { y: 0.75, fire: true });
  for (let i = 0; i < 4; i++) {
    const a = 45 + i * 90;
    const [lx, lz] = K.rot2(0, 7, a);
    parts.push(K.cyl(`Fire_Log_${i}`, [4.6, 1.3, 1.3], [lx, 1.45, 2 + lz], [88, 60, 36], 'Wood',
      { rot: [0, a + 90, 0] }));
  }

  // Camp: tents, table, supplies, clothesline
  K.tent(parts, 'Camp_Tent_01', 17, 15, -22, [58, 68, 50], B);
  K.tent(parts, 'Camp_Tent_02', 23, 21, 155, [66, 60, 48], B);
  parts.push(K.box('Camp_Table_Top', [6.4, 0.3, 3.4], [9, 2.75, 12], [120, 92, 58], 'WoodPlanks'));
  for (let i = 0; i < 4; i++) {
    const [lx, lz] = [[-2.7, -1.3], [2.7, -1.3], [-2.7, 1.3], [2.7, 1.3]][i];
    parts.push(K.cyl(`Camp_Table_Leg_${i}`, [0.3, 2.6, 0.3], [9 + lx, 1.3, 12 + lz], [92, 68, 42], 'Wood'));
  }
  parts.push(K.box('Camp_Radio', [1.7, 1, 0.9], [7.5, 3.4, 12], [58, 56, 54], 'Metal', { rot: [0, 14, 0] }));
  parts.push(K.cyl('Camp_Radio_Ant', [0.08, 1.6, 0.08], [7.2, 4.6, 12], [180, 180, 185], 'Metal'));
  parts.push(K.box('Camp_Map', [3, 0.06, 2], [10.6, 2.95, 11.6], [225, 215, 190], 'Plastic', { rot: [0, 8, 0], canCollide: false }));
  parts.push(K.box('Camp_Lantern', [0.8, 1.1, 0.8], [11.6, 3.45, 12.4], [48, 46, 44], 'Metal'));
  parts.push(K.box('Camp_Lantern_Glow', [0.5, 0.55, 0.5], [11.6, 3.5, 12.4], [255, 190, 110], 'Neon', { canCollide: false, transparency: 0.15 }));
  fx.push(K.light('Camp_Lantern', 'Camp_Lantern_Light', { color: [255, 195, 120], brightness: 1.6, range: 18, shadows: false }));
  parts.push(K.cyl('Camp_Can_1', [0.35, 0.5, 0.35], [10, 3.15, 13], [150, 60, 50], 'Metal'));
  parts.push(K.cyl('Camp_Can_2', [0.35, 0.5, 0.35], [10.5, 3.15, 12.7], [90, 120, 90], 'Metal'));
  K.crate(parts, 'Camp_Crate_A', -13, B, 20, 2.6, 12);
  K.crate(parts, 'Camp_Crate_B', -14.5, B + 2.6, 19.2, 2.2, -8);
  K.crate(parts, 'Camp_Crate_C', -12.2, B, 17.6, 2.6, 35);
  K.makeBarrel(parts, fx, 'Camp_Barrel_Water', -16.5, 22.5, { y: B, color: [70, 74, 70] });
  parts.push(K.cyl('Camp_Clothes_PoleA', [0.3, 7.5, 0.3], [12, B + 3.75, -10], [80, 60, 40], 'Wood'));
  parts.push(K.cyl('Camp_Clothes_PoleB', [0.3, 7.5, 0.3], [21, B + 3.75, -13], [80, 60, 40], 'Wood'));
  parts.push(K.box('Camp_Clothes_Wire', [9.7, 0.08, 0.08], [16.5, B + 7.1, -11.5], [120, 120, 125], 'Metal',
    { rot: [0, -17, 0], canCollide: false }));
  parts.push(K.box('Camp_Cloth_1', [2, 2.6, 0.06], [13.5, B + 5.8, -10.7], [130, 120, 105], 'Fabric', { rot: [0, -17, 0], canCollide: false }));
  parts.push(K.box('Camp_Cloth_2', [2.2, 2.2, 0.06], [16.6, B + 6.1, -11.7], [95, 100, 110], 'Fabric', { rot: [0, -17, 0], canCollide: false }));
  parts.push(K.box('Camp_Cloth_3', [1.8, 2.8, 0.06], [19.6, B + 5.7, -12.6], [110, 90, 80], 'Fabric', { rot: [0, -17, 0], canCollide: false }));

  // Corner sandbag nests
  for (const [cx, cz, tag] of [[-30, -30, 'NW'], [30, -30, 'NE'], [-30, 30, 'SW'], [30, 30, 'SE']]) {
    K.sandbagLine(parts, `Plaza_Nest_${tag}`, cx - 4, cz - 3, cx + 4, cz - 3, 2, rng, B);
    K.sandbagLine(parts, `Plaza_Nest_${tag}_Side`, cx - 4, cz - 3, cx - 4, cz + 2, 1, rng, B);
  }

  // Plaza lamps (south pair working, north pair broken)
  K.lampPost(parts, fx, 'Plaza_Lamp_SW', -30, 32, { b: B, rotY: 45 });
  K.lampPost(parts, fx, 'Plaza_Lamp_SE', 30, 32, { b: B, rotY: 135 });
  K.lampPost(parts, fx, 'Plaza_Lamp_NW', -30, -32, { b: B, rotY: -45, broken: true, tiltDir: -1 });
  K.lampPost(parts, fx, 'Plaza_Lamp_NE', 30, -32, { b: B, rotY: 225, broken: true, tiltDir: 1 });

  // Flag pole + torn flag
  parts.push(K.cyl('Plaza_Flag_Pole', [0.45, 17, 0.45], [-10, B + 8.5, -24], [90, 92, 96], 'Metal'));
  parts.push(K.box('Plaza_Flag_A', [3.4, 1.6, 0.05], [-8.2, B + 15.6, -24], [120, 42, 38], 'Fabric', { canCollide: false }));
  parts.push(K.box('Plaza_Flag_B', [2.2, 1.2, 0.05], [-8.8, B + 13.9, -24], [110, 38, 34], 'Fabric', { rot: [0, 0, 6], canCollide: false }));

  // Extra props: chair, stool, pallets
  parts.push(K.box('Plaza_Chair_Seat', [1.8, 0.25, 1.8], [-8, B + 1, 8], [96, 70, 44], 'WoodPlanks'));
  parts.push(K.box('Plaza_Chair_Back', [1.8, 1.6, 0.25], [-8, B + 1.9, 8.8], [96, 70, 44], 'WoodPlanks', { rot: [-14, 0, 0] }));
  for (let i = 0; i < 4; i++) {
    const [lx, lz] = [[-0.7, -0.7], [0.7, -0.7], [-0.7, 0.7], [0.7, 0.7]][i];
    parts.push(K.cyl(`Plaza_Chair_Leg_${i}`, [0.16, 1, 0.16], [-8 + lx, B + 0.5, 8 + lz], [70, 50, 32], 'Wood'));
  }
  parts.push(K.cyl('Plaza_Stool_Top', [2, 0.4, 2], [-4, B + 1.4, 6], [110, 82, 50], 'WoodPlanks'));
  parts.push(K.cyl('Plaza_Stool_Leg', [0.5, 1.3, 0.5], [-4, B + 0.65, 6], [70, 50, 32], 'Wood'));
  for (let i = 0; i < 2; i++) {
    const px = -20 + i * 3.4, pz = 26;
    parts.push(K.box(`Plaza_Pallet_${i}_A`, [3, 0.16, 1], [px, B + 0.35, pz - 0.5], [120, 95, 60], 'WoodPlanks', { rot: [0, 6 * i, 0] }));
    parts.push(K.box(`Plaza_Pallet_${i}_B`, [3, 0.16, 1], [px, B + 0.35, pz + 0.5], [120, 95, 60], 'WoodPlanks', { rot: [0, 6 * i, 0] }));
    parts.push(K.box(`Plaza_Pallet_${i}_Run`, [0.3, 0.35, 2.4], [px - 1.2, B + 0.2, pz], [100, 78, 48], 'Wood', { rot: [0, 6 * i, 0] }));
    parts.push(K.box(`Plaza_Pallet_${i}_Run2`, [0.3, 0.35, 2.4], [px + 1.2, B + 0.2, pz], [100, 78, 48], 'Wood', { rot: [0, 6 * i, 0] }));
  }

  // Small side fire near camp
  K.makeBarrel(parts, fx, 'Plaza_Barrel_Fire2', 26, -18, { y: B, fire: true });

  // Dust ambience
  parts.push(K.P('Plaza_Dust_Anchor', { size: [1, 1, 1], pos: [0, 6, 0], color: [200, 200, 200], transparency: 1, canCollide: false }));
  fx.push(K.dust('Plaza_Dust_Anchor', 'Plaza_Dust', { rate: 4 }));

  return { parts, fx };
};

// --- 02 CHECKPOINT ----------------------------------------------------------
Z['02_Checkpoint_Norte'] = () => {
  const parts = [], fx = [];
  const rng = K.makeRng(202);
  const B = 0.35;

  // Apron + gate wall
  parts.push(K.box('Checkpoint_Apron', [64, 0.35, 56], [0, 0.175, -78], [58, 56, 52], 'Asphalt'));
  parts.push(K.box('Gate_WallL', [26, 12, 3], [-19, 6 + B, -78], [96, 92, 85], 'Concrete'));
  parts.push(K.box('Gate_WallR', [26, 12, 3], [19, 6 + B, -78], [96, 92, 85], 'Concrete'));
  parts.push(K.box('Gate_WallL_Top', [26.4, 0.6, 3.4], [-19, 12.3 + B, -78], [78, 75, 70], 'Concrete', { canCollide: false }));
  parts.push(K.box('Gate_WallR_Top', [26.4, 0.6, 3.4], [19, 12.3 + B, -78], [78, 75, 70], 'Concrete', { canCollide: false }));
  parts.push(K.box('Gate_WireA', [26, 0.07, 0.07], [-19, 13 + B, -78], [70, 70, 74], 'Metal', { canCollide: false }));
  parts.push(K.box('Gate_WireB', [26, 0.07, 0.07], [19, 13.35 + B, -78], [70, 70, 74], 'Metal', { canCollide: false }));
  for (let i = 0; i < 10; i++) {
    const wx = i < 5 ? -30 + i * 5.5 : 8 + (i - 5) * 5.5;
    parts.push(K.cyl(`Gate_Barb_${i}`, [0.3, 0.3, 0.3], [wx, 13.4 + B, -78], [80, 80, 84], 'Metal',
      { rot: [90, 0, 0], canCollide: false }));
  }
  // Gate posts + ajar doors
  parts.push(K.box('Gate_PostL', [1.1, 9.5, 1.6], [-6.5, 4.75 + B, -78], [92, 60, 42], 'CorrodedMetal'));
  parts.push(K.box('Gate_PostR', [1.1, 9.5, 1.6], [6.5, 4.75 + B, -78], [92, 60, 42], 'CorrodedMetal'));
  parts.push(K.box('Gate_DoorL', [5.9, 8.6, 0.5], [-3.6, 4.3 + B, -76.6], [104, 58, 42], 'CorrodedMetal',
    { rot: [0, 168, 0] }));
  parts.push(K.box('Gate_DoorR', [5.9, 8.6, 0.5], [3.6, 4.3 + B, -76.6], [104, 58, 42], 'CorrodedMetal',
    { rot: [0, -168, 0], prompt: { action: 'Iniciar Partida', object: 'Salida a la Zona Infectada', hold: 1.2, dist: 14 } }));
  parts.push(K.box('Gate_DoorL_Cross', [5.4, 0.5, 0.56], [-3.6, 5.6 + B, -76.6], [86, 48, 36], 'CorrodedMetal', { rot: [0, 168, 0], canCollide: false }));
  parts.push(K.box('Gate_DoorR_Cross', [5.4, 0.5, 0.56], [3.6, 5.6 + B, -76.6], [86, 48, 36], 'CorrodedMetal', { rot: [0, -168, 0], canCollide: false }));
  // Red beacon lamps on posts
  parts.push(K.cyl('Gate_BeaconL', [0.6, 1.1, 0.6], [-6.5, 10 + B, -78], [255, 60, 50], 'Neon', { canCollide: false }));
  parts.push(K.cyl('Gate_BeaconR', [0.6, 1.1, 0.6], [6.5, 10 + B, -78], [255, 60, 50], 'Neon', { canCollide: false }));
  fx.push(K.light('Gate_BeaconL', 'Gate_BeaconL_Light', { color: [255, 60, 50], brightness: 2.2, range: 16, shadows: false }));
  fx.push(K.light('Gate_BeaconR', 'Gate_BeaconR_Light', { color: [255, 60, 50], brightness: 2.2, range: 16, shadows: false }));
  // Wall warning boards
  parts.push(K.box('Checkpoint_SignA', [7, 3.2, 0.35], [14, 8.6 + B, -76.2], [190, 185, 172], 'Metal', { rot: [0, 180, 0] }));
  parts.push(K.box('Checkpoint_SignB', [7, 3.2, 0.35], [-14, 8.6 + B, -76.2], [170, 52, 44], 'Metal', { rot: [0, 180, 0] }));

  // HESCO lines + jersey barriers + spike strip
  K.hesco(parts, 'Checkpoint_Hesco_A', -26, -62, 8, 10, 2.5, B);
  K.hesco(parts, 'Checkpoint_Hesco_B', -18, -56, 4, 8, 2.5, B);
  K.hesco(parts, 'Checkpoint_Hesco_C', 24, -64, -6, 10, 2.5, B);
  K.hesco(parts, 'Checkpoint_Hesco_D', 16, -58, 2, 8, 2.5, B);
  parts.push(K.box('Checkpoint_Jersey_A', [6, 1.6, 1.4], [10, 0.8 + B, -66], [150, 146, 138], 'Concrete', { rot: [0, 22, 0] }));
  parts.push(K.box('Checkpoint_Jersey_B', [6, 1.6, 1.4], [-12, 0.8 + B, -70], [150, 146, 138], 'Concrete', { rot: [0, -14, 0] }));
  parts.push(K.box('Checkpoint_Jersey_A_Top', [6.2, 0.3, 1.6], [10, 1.7 + B, -66], [130, 126, 118], 'Concrete', { rot: [0, 22, 0], canCollide: false }));
  for (let i = 0; i < 8; i++) {
    parts.push(K.cyl(`Checkpoint_Spike_${i}`, [0.14, 0.9, 0.14], [-3.5 + i, 0.7 + B, -73], [90, 60, 44], 'CorrodedMetal',
      { rot: [K.range(rng, -20, 20), 0, K.range(rng, -20, 20)], canCollide: false }));
  }

  // Watchtower
  const TW = [24, -66];
  for (let i = 0; i < 4; i++) {
    const [lx, lz] = [[-3.2, -3.2], [3.2, -3.2], [-3.2, 3.2], [3.2, 3.2]][i];
    parts.push(K.cyl(`Tower_Leg_${i}`, [0.7, 14, 0.7], [TW[0] + lx * 1.1, 7 + B, TW[1] + lz * 1.1], [74, 66, 54], 'Wood',
      { rot: [lz * 0.55, 0, -lx * 0.55] }));
  }
  parts.push(K.box('Tower_Platform', [9, 0.55, 9], [TW[0], 14 + B, TW[1]], [96, 78, 52], 'WoodPlanks'));
  for (let i = 0; i < 4; i++) {
    const [lx, lz] = [[-4.1, -4.1], [4.1, -4.1], [-4.1, 4.1], [4.1, 4.1]][i];
    parts.push(K.cyl(`Tower_Rail_${i}`, [0.35, 3.2, 0.35], [TW[0] + lx, 15.8 + B, TW[1] + lz], [96, 78, 52], 'WoodPlanks'));
  }
  parts.push(K.box('Tower_RailA', [8.4, 0.3, 0.3], [TW[0], 17.2 + B, TW[1] - 4.1], [108, 88, 58], 'WoodPlanks', { canCollide: false }));
  parts.push(K.box('Tower_RailB', [8.4, 0.3, 0.3], [TW[0], 17.2 + B, TW[1] + 4.1], [108, 88, 58], 'WoodPlanks', { canCollide: false }));
  parts.push(K.box('Tower_RailC', [0.3, 0.3, 8.4], [TW[0] - 4.1, 17.2 + B, TW[1]], [108, 88, 58], 'WoodPlanks', { canCollide: false }));
  parts.push(K.box('Tower_Roof', [10.5, 0.4, 10.5], [TW[0], 20.4 + B, TW[1]], [70, 58, 42], 'WoodPlanks'));
  for (let i = 0; i < 4; i++) {
    const [lx, lz] = [[-4.4, -4.4], [4.4, -4.4], [-4.4, 4.4], [4.4, 4.4]][i];
    parts.push(K.cyl(`Tower_RoofPost_${i}`, [0.28, 3, 0.28], [TW[0] + lx, 18.9 + B, TW[1] + lz], [80, 66, 48], 'Wood'));
  }
  K.sandbagLine(parts, 'Tower_Bags', TW[0] - 3.5, TW[1] - 4.3, TW[0] + 3.5, TW[1] - 4.3, 1, rng, B + 14.25);
  parts.push(K.cyl('Tower_MG_Barrel', [0.3, 3.2, 0.3], [TW[0] + 1, 15.4 + B, TW[1] - 3.4], [40, 40, 42], 'Metal',
    { rot: [80, 0, 0], canCollide: false }));
  parts.push(K.cyl('Tower_MG_Mount', [0.5, 1.2, 0.5], [TW[0] + 1, 14.7 + B, TW[1] - 3], [44, 44, 46], 'Metal'));
  fx.push(K.light('Tower_MG_Mount', 'Tower_SpotA', { className: 'SpotLight', color: [200, 215, 235], brightness: 2.4, range: 44 }));
  parts.push(K.box('Tower_Ladder_RailL', [0.2, 14, 0.2], [TW[0] - 0.9, 7 + B, TW[1] + 4.6], [86, 72, 50], 'Wood'));
  parts.push(K.box('Tower_Ladder_RailR', [0.2, 14, 0.2], [TW[0] - 0.1, 7 + B, TW[1] + 4.6], [86, 72, 50], 'Wood'));
  for (let i = 0; i < 7; i++) {
    parts.push(K.box(`Tower_Ladder_Rung_${i}`, [0.9, 0.14, 0.14], [TW[0] - 0.5, 1.4 + i * 2 + B, TW[1] + 4.6], [96, 82, 58], 'Wood', { canCollide: false }));
  }

  // Guard booth
  parts.push(K.box('Booth_Wall_L', [0.4, 4.6, 8], [-26.2, 2.3 + B, -70], [88, 84, 76], 'Concrete'));
  parts.push(K.box('Booth_Wall_R', [8, 4.6, 0.4], [-22, 2.3 + B, -74], [88, 84, 76], 'Concrete'));
  parts.push(K.box('Booth_Wall_Back', [8, 4.6, 0.4], [-22, 2.3 + B, -66], [88, 84, 76], 'Concrete'));
  parts.push(K.box('Booth_Roof', [9, 0.5, 9], [-22, 4.85 + B, -70], [64, 62, 58], 'Metal'));
  parts.push(K.box('Booth_Window', [0.3, 2, 4], [-26.1, 3 + B, -70], [40, 52, 58], 'Glass', { transparency: 0.45, canCollide: false }));
  parts.push(K.box('Booth_Desk', [3, 1.6, 1.6], [-24.5, 0.8 + B, -70], [96, 82, 58], 'WoodPlanks'));
  parts.push(K.box('Booth_Radio', [1.4, 0.9, 0.8], [-24.3, 2.05 + B, -70], [52, 50, 48], 'Metal', { rot: [0, 30, 0] }));
  parts.push(K.cyl('Booth_Antenna', [0.12, 7, 0.12], [-25.5, 8.3 + B, -72.5], [160, 160, 166], 'Metal'));
  parts.push(K.ball('Booth_AntennaTip', [0.35, 0.35, 0.35], [-25.5, 11.8 + B, -72.5], [220, 60, 50], 'Neon', { canCollide: false }));
  K.sandbagLine(parts, 'Booth_Bags', -26.5, -66.6, -17.5, -66.6, 2, rng, B);

  // Convoy truck
  const TR = [-11, -54], tryaw = -18;
  const tat = (lx, ly, lz, size, col, mat, extra = {}) => {
    const [wx, wz] = K.rot2(lx, lz, tryaw);
    parts.push(K.box(`Truck_${extra.tag}`, size, [TR[0] + wx, ly, TR[1] + wz], col, mat,
      { rot: [0, tryaw, 0], ...extra.opts }));
  };
  tat(-4.4, 3.8, 0, [4.8, 3.6, 4.6], [96, 100, 72], 'CorrodedMetal', { tag: 'Cab' });
  tat(0.4, 4.1, 0, [5.2, 3.9, 4.8], [86, 90, 66], 'CorrodedMetal', { tag: 'Bed' });
  tat(0.4, 6.3, 0, [5.4, 2.2, 5], [70, 74, 56], 'Fabric', { tag: 'Canvas' });
  tat(-6.9, 2.4, 0, [1.2, 1.6, 4.2], [70, 74, 60], 'Metal', { tag: 'Grill' });
  tat(-4.4, 7.3, 0, [0.5, 1.4, 0.5], [60, 60, 62], 'Metal', { tag: 'Stack' });
  [[-4.6, 2.6], [-4.6, -2.6], [3.4, 2.6], [3.4, -2.6]].forEach(([lx, lz], i) => {
    const [wx, wz] = K.rot2(lx, lz, tryaw);
    parts.push(K.cyl(`Truck_Wheel_${i}`, [2.6, 1.1, 2.6], [TR[0] + wx, 1.35, TR[1] + wz], [36, 36, 38], 'Metal',
      { rot: [0, tryaw, 0] }));
  });

  // Floodlight poles
  for (const [px, pz, tag] of [[-30, -74, 'W'], [30, -74, 'E']]) {
    parts.push(K.cyl(`Checkpoint_FloodPole_${tag}`, [0.5, 16, 0.5], [px, 8 + B, pz], [60, 60, 64], 'Metal'));
    parts.push(K.box(`Checkpoint_FloodHead_${tag}`, [1.6, 0.7, 1], [px, 16.2 + B, pz], [48, 48, 52], 'Metal'));
    parts.push(K.box(`Checkpoint_FloodLens_${tag}`, [1.3, 0.3, 0.8], [px, 15.8 + B, pz], [255, 244, 210], 'Neon',
      { canCollide: false, transparency: 0.3 }));
    fx.push(K.light(`Checkpoint_FloodHead_${tag}`, `Checkpoint_Flood_${tag}`, { color: [186, 202, 222], brightness: 2.6, range: 40 }));
  }

  // Beyond the gate: infected front
  parts.push(K.box('Frente_Ground', [40, 0.2, 46], [0, 0.1, -120], [36, 34, 34], 'Asphalt'));
  parts.push(K.P('Frente_Mist_Anchor', { size: [1, 1, 1], pos: [0, 6, -100], color: [200, 200, 200], transparency: 1, canCollide: false }));
  fx.push(K.redMist('Frente_Mist_Anchor', 'Frente_RedMist', { rate: 10 }));
  fx.push(K.redMist('Frente_Mist_Anchor', 'Frente_RedMist2', { rate: 6, speed: [0.3, 0.8] }));
  K.makeCar(parts, fx, 'Frente_CarWreck', 7, -94, 200, null, { burned: true, y: 0.2, tilt: 4 });
  K.makeCar(parts, fx, 'Frente_CarWreck2', -9, -102, 160, [60, 50, 46], { y: 0.2, tilt: -5 });
  K.rebar(parts, 'Frente_Rebar', 12, 0.2, -103, 5, rng);
  K.rebar(parts, 'Frente_Rebar2', -13, 0.2, -90, 4, rng);
  K.rubble(parts, 'Frente_Rubble', 0, -95, 6, 12, rng, 0.2, [[66, 62, 58], [52, 50, 48]]);
  // Dead specimen (storytelling)
  const DZ = [3, -88];
  parts.push(K.box('Frente_Body', [1.1, 0.7, 2.6], [DZ[0], 0.55, DZ[1]], [70, 76, 66], 'Fabric', { rot: [0, 25, 0] }));
  parts.push(K.ball('Frente_Body_Head', [1.05, 1.05, 1.05], [DZ[0] - 1.1, 0.6, DZ[1] + 0.9], [104, 124, 84], 'Plastic',
    { mesh: { type: 'Head', scale: [1.05, 1.05, 1.05] } }));
  parts.push(K.box('Frente_Body_ArmA', [0.5, 0.5, 1.8], [DZ[0] + 1, 0.45, DZ[1] - 0.4], [104, 124, 84], 'Plastic', { rot: [0, 45, 0] }));
  parts.push(K.box('Frente_Body_ArmB', [0.5, 0.5, 1.6], [DZ[0] - 1.3, 0.45, DZ[1] - 1], [104, 124, 84], 'Plastic', { rot: [0, -30, 0] }));
  parts.push(K.cyl('Frente_Body_LegA', [0.55, 0.55, 1.9], [DZ[0] + 0.3, 0.45, DZ[1] + 1.9], [48, 46, 56], 'Fabric', { rot: [0, 12, 0] }));
  parts.push(K.cyl('Frente_Body_LegB', [0.55, 0.55, 1.9], [DZ[0] - 0.3, 0.45, DZ[1] + 1.7], [48, 46, 56], 'Fabric', { rot: [0, -18, 0] }));
  parts.push(K.box('Frente_Blood', [3.2, 0.06, 4.2], [DZ[0], 0.23, DZ[1]], [58, 12, 12], 'Asphalt', { transparency: 0.4, canCollide: false }));
  // Far quarantine billboard
  parts.push(K.box('Billboard_Far_PostL', [0.6, 13, 0.6], [-7, 6.5, -108], [70, 62, 52], 'CorrodedMetal', { rot: [0, 0, 6] }));
  parts.push(K.box('Billboard_Far_PostR', [0.6, 13, 0.6], [3, 6.5, -110], [70, 62, 52], 'CorrodedMetal', { rot: [0, 0, -4] }));
  parts.push(K.box('Billboard_Far', [12, 6, 0.5], [-2, 11, -109], [66, 58, 50], 'CorrodedMetal', { rot: [0, 175, 0] }));

  return { parts, fx };
};

// --- 03 ARSENAL -------------------------------------------------------------
Z['03_Arsenal_Bunker'] = () => {
  const parts = [], fx = [];
  const B = 0.4;

  // Structure (open to the west)
  parts.push(K.box('Arsenal_Apron', [46, 0.4, 50], [72, 0.2, 0], [62, 60, 56], 'Concrete'));
  parts.push(K.box('Arsenal_BackWall', [3, 10, 44], [92, 5 + B, 0], [100, 98, 92], 'Concrete'));
  parts.push(K.box('Arsenal_SideWallN', [36, 10, 3], [74, 5 + B, -21.5], [96, 94, 88], 'Concrete'));
  parts.push(K.box('Arsenal_SideWallS', [36, 10, 3], [74, 5 + B, 21.5], [96, 94, 88], 'Concrete'));
  parts.push(K.box('Arsenal_Roof', [40, 0.9, 48], [74, 10.45 + B, 0], [58, 56, 54], 'Metal',
    { billboard: { text: 'ARSENAL', sizeX: 14, sizeY: 4, offsetY: 12, color: [235, 200, 90] } }));
  parts.push(K.box('Arsenal_FrontWallN', [3, 10, 12], [55, 5 + B, -16], [98, 96, 90], 'Concrete'));
  parts.push(K.box('Arsenal_FrontWallS', [3, 10, 12], [55, 5 + B, 16], [98, 96, 90], 'Concrete'));
  // Counter (prompt target)
  parts.push(K.box('Arsenal_Counter', [3, 3.5, 20], [56, 1.75 + B, 0], [104, 78, 50], 'WoodPlanks',
    { prompt: { action: 'Armas y Munición', object: 'Comerciante', hold: 0.9, dist: 13 } }));
  parts.push(K.box('Arsenal_CounterTop', [4, 0.35, 20.6], [56, 3.65 + B, 0], [126, 96, 60], 'WoodPlanks'));
  parts.push(K.box('Arsenal_CashRegister', [1.2, 1.1, 1.4], [56.4, 4.35 + B, -7.5], [58, 56, 54], 'Metal'));
  parts.push(K.box('Arsenal_RegisterScreen', [0.5, 0.7, 0.9], [56, 4.5 + B, -7.5], [90, 140, 150], 'Glass',
    { transparency: 0.3, canCollide: false, rot: [0, 0, -12] }));
  for (let i = 0; i < 3; i++) {
    parts.push(K.box(`Arsenal_AmmoBox_${i}`, [1.6, 0.9, 1], [56.4, 4.3 + B, 6 + i * 1.6], [86, 92, 68], 'CorrodedMetal',
      { rot: [0, K.range(K.makeRng(31 + i), -12, 12), 0] }));
  }

  // Weapon racks on back wall
  for (const [z0, tag] of [[-11, 'N'], [9, 'S']]) {
    parts.push(K.box(`Arsenal_Rack_${tag}`, [0.45, 3, 9], [90.3, 6 + B, z0], [82, 58, 34], 'WoodPlanks'));
    for (let i = 0; i < 4; i++) {
      const rz = z0 - 3 + i * 2;
      parts.push(K.cyl(`Arsenal_Rifle_${tag}_${i}_Barrel`, [0.18, 3, 0.18], [90, 5.8 + B, rz], [48, 48, 52], 'Metal',
        { rot: [0, 0, 3] }));
      parts.push(K.box(`Arsenal_Rifle_${tag}_${i}_Stock`, [0.24, 1.1, 0.4], [90, 4.35 + B, rz], [96, 64, 36], 'Wood',
        { rot: [0, 0, 3] }));
      parts.push(K.box(`Arsenal_Rifle_${tag}_${i}_Mag`, [0.26, 0.7, 0.5], [89.96, 5.15 + B, rz], [40, 40, 44], 'Metal',
        { rot: [0, 0, 10], canCollide: false }));
    }
  }
  // Machetes on front rack
  parts.push(K.box('Arsenal_Machete_Rack', [0.4, 2.4, 5], [55.6, 5.6 + B, -16.6], [82, 58, 34], 'WoodPlanks'));
  for (let i = 0; i < 3; i++) {
    parts.push(K.box(`Arsenal_Machete_${i}_Blade`, [0.1, 1.9, 0.4], [55.9, 5.9 + B, -18 + i * 1.4], [160, 164, 170], 'Metal'));
    parts.push(K.box(`Arsenal_Machete_${i}_Grip`, [0.14, 0.7, 0.34], [55.9, 4.65 + B, -18 + i * 1.4], [40, 38, 40], 'Plastic'));
  }
  // Bats barrel
  parts.push(K.cyl('Arsenal_BatBarrel', [2.2, 2.6, 2.2], [84, 1.3 + B, 16], [70, 52, 32], 'WoodPlanks'));
  for (let i = 0; i < 3; i++) {
    parts.push(K.cyl(`Arsenal_Bat_${i}`, [0.4, 3.4, 0.4], [84 + (i - 1) * 0.5, 3.4 + B, 16 + (i - 1) * 0.3], [118, 84, 48], 'Wood',
      { rot: [K.range(K.makeRng(41 + i), -14, 14), 0, K.range(K.makeRng(51 + i), -14, 14)] }));
  }
  // Shelves + supplies
  for (let s = 0; s < 2; s++) {
    parts.push(K.box(`Arsenal_Shelf_${s}`, [14, 0.3, 2.5], [74, 4 + s * 2.6 + B, 19.4], [90, 66, 42], 'WoodPlanks'));
    for (let i = 0; i < 4; i++) {
      parts.push(K.box(`Arsenal_ShelfBox_${s}_${i}`, [1.7, 1.3 + (i % 2) * 0.5, 1.4],
        [69 + i * 3.4, 4.3 + s * 2.6 + B + (i % 2) * 0.25, 19.4],
        [K.rangeInt(K.makeRng(s * 10 + i), 90, 150), K.rangeInt(K.makeRng(s * 10 + i + 5), 80, 120), 70], 'CorrodedMetal',
        { rot: [0, K.range(K.makeRng(60 + i), -20, 20), 0] }));
    }
  }
  // Armor crate
  parts.push(K.box('Arsenal_ArmorCrate', [5, 3, 4], [80, 1.9 + B, 8], [72, 76, 70], 'CorrodedMetal'));
  parts.push(K.box('Arsenal_ArmorCrateLid', [5.3, 0.4, 4.3], [80, 3.7 + B, 8], [62, 66, 60], 'CorrodedMetal', { rot: [0, 6, 3], canCollide: false }));
  parts.push(K.box('Arsenal_ArmorStripeA', [5.4, 0.5, 0.5], [80, 1.6 + B, 6.4], [235, 195, 40], 'SmoothPlastic', { canCollide: false }));
  parts.push(K.box('Arsenal_ArmorStripeB', [5.4, 0.5, 0.5], [80, 1.6 + B, 9.6], [235, 195, 40], 'SmoothPlastic', { canCollide: false }));
  // Casings
  for (let i = 0; i < 6; i++) {
    const r2 = K.makeRng(70 + i);
    parts.push(K.cyl(`Arsenal_Casing_${i}`, [0.13, 0.36, 0.13], [60 + K.range(r2, -4, 8), 0.5 + B, K.range(r2, -8, 8)],
      [190, 160, 80], 'Metal', { rot: [90, K.range(r2, 0, 360), 0], canCollide: false }));
  }
  // Hanging lamp
  parts.push(K.cyl('Arsenal_LampCable', [0.1, 2.4, 0.1], [74, 9.2 + B, 0], [40, 40, 42], 'Metal'));
  parts.push(K.cyl('Arsenal_LampShade', [1.6, 0.8, 1.6], [74, 7.9 + B, 0], [52, 50, 48], 'Metal'));
  parts.push(K.ball('Arsenal_LampBulb', [1, 1, 1], [74, 7.45 + B, 0], [255, 214, 150], 'Neon', { canCollide: false, transparency: 0.1 }));
  fx.push(K.light('Arsenal_LampBulb', 'Arsenal_Lamp_Light', { color: [255, 205, 135], brightness: 2, range: 30 }));
  // Exterior + sign
  K.sandbagLine(parts, 'Arsenal_Bags', 53, -20, 53, -8, 2, K.makeRng(303), B);
  K.sandbagLine(parts, 'Arsenal_Bags2', 53, 8, 53, 20, 2, K.makeRng(304), B);
  K.crate(parts, 'Arsenal_Ext_CrateA', 51, B, -23, 2.6, 18);
  K.crate(parts, 'Arsenal_Ext_CrateB', 51.5, B + 2.6, -22.4, 2.2, -12);
  K.makeBarrel(parts, fx, 'Arsenal_Ext_Barrel', 50, 23.5, { y: B, color: [66, 70, 64] });
  parts.push(K.box('Arsenal_Sign', [8, 2.6, 0.4], [54.6, 7.2 + B, 0], [196, 178, 88], 'Metal', { rot: [0, 90, 0] }));
  parts.push(K.box('Arsenal_Sign_PostL', [0.3, 12, 0.3], [55, 6 + B, -3.6], [60, 58, 56], 'Metal'));
  parts.push(K.box('Arsenal_Sign_PostR', [0.3, 12, 0.3], [55, 6 + B, 3.6], [60, 58, 56], 'Metal'));

  return { parts, fx };
};

// --- 04 TALLER --------------------------------------------------------------
Z['04_Taller_Mejoras'] = () => {
  const parts = [], fx = [];
  const B = 0.4;
  const rng = K.makeRng(404);

  // Structure (open-air workshop)
  parts.push(K.box('Workshop_Apron', [46, 0.4, 50], [-72, 0.2, 0], [60, 58, 54], 'Concrete'));
  parts.push(K.box('Workshop_BackWall', [3, 9, 40], [-92, 4.5 + B, 0], [96, 88, 78], 'Brick'));
  parts.push(K.box('Workshop_SideWallN', [32, 9, 3], [-77, 4.5 + B, -19.5], [92, 84, 74], 'Brick'));
  parts.push(K.box('Workshop_SideWallS', [32, 9, 3], [-77, 4.5 + B, 19.5], [92, 84, 74], 'Brick'));
  parts.push(K.box('Workshop_RoofBack', [20, 0.8, 42], [-83, 9.4 + B, 0], [56, 54, 52], 'Metal',
    { billboard: { text: 'TALLER', sizeX: 12, sizeY: 3.6, offsetY: 11, color: [240, 190, 120] } }));
  parts.push(K.box('Workshop_Tarp', [18, 0.25, 40], [-64, 9.2 + B, 0], [64, 78, 60], 'Fabric', { rot: [0, 0, 2], canCollide: false }));
  parts.push(K.box('Workshop_TarpEdgeN', [18.4, 0.3, 0.4], [-64, 8.85 + B, -19.9], [56, 68, 52], 'Fabric', { rot: [0, 0, 2], canCollide: false }));
  parts.push(K.box('Workshop_TarpEdgeS', [18.4, 0.3, 0.4], [-64, 8.85 + B, 19.9], [56, 68, 52], 'Fabric', { rot: [0, 0, 2], canCollide: false }));
  parts.push(K.cyl('Workshop_PostN', [0.8, 9.4, 0.8], [-56.5, 4.7 + B, -15], [70, 62, 52], 'Wood'));
  parts.push(K.cyl('Workshop_PostS', [0.8, 9.4, 0.8], [-56.5, 4.7 + B, 15], [70, 62, 52], 'Wood'));
  // String lights
  parts.push(K.box('Workshop_StringWire', [0.08, 0.08, 30], [-56.5, 8.6 + B, 0], [140, 140, 145], 'Metal', { canCollide: false }));
  for (let i = 0; i < 5; i++) {
    parts.push(K.ball(`Workshop_Bulb_${i}`, [0.5, 0.5, 0.5], [-56.5, 8.3 + B, -12 + i * 6], [255, 216, 150], 'Neon', { canCollide: false, transparency: 0.15 }));
  }
  fx.push(K.light('Workshop_PostN', 'Workshop_String_Light', { color: [255, 205, 140], brightness: 2, range: 30, shadows: false }));

  // Workbench (prompt target)
  parts.push(K.box('Workshop_Bench', [8, 0.35, 3.4], [-80, 3.2 + B, 10], [122, 94, 58], 'WoodPlanks',
    { prompt: { action: 'Mejoras de Equipo', object: 'Ingeniero', hold: 0.9, dist: 13 } }));
  for (let i = 0; i < 4; i++) {
    const [lx, lz] = [[-3.6, -1.4], [3.6, -1.4], [-3.6, 1.4], [3.6, 1.4]][i];
    parts.push(K.box(`Workshop_Bench_Leg_${i}`, [0.5, 3.1, 0.5], [-80 + lx, 1.55 + B, 10 + lz], [88, 64, 40], 'Wood'));
  }
  parts.push(K.box('Workshop_Vise', [1.2, 1, 1.2], [-82.5, 3.9 + B, 10], [72, 74, 78], 'Metal'));
  parts.push(K.box('Workshop_Wrench_Head', [1.3, 0.4, 0.6], [-78.5, 3.5 + B, 9.4], [150, 154, 160], 'Metal', { rot: [0, 20, 0] }));
  parts.push(K.box('Workshop_Wrench_Handle', [2.4, 0.18, 0.3], [-77.4, 3.48 + B, 9.7], [150, 154, 160], 'Metal', { rot: [0, 20, 0] }));
  parts.push(K.box('Workshop_Hammer_Handle', [0.22, 0.22, 1.6], [-80.5, 3.5 + B, 11], [120, 88, 52], 'Wood', { rot: [0, 40, 0] }));
  parts.push(K.box('Workshop_Hammer_Head', [0.4, 0.4, 0.8], [-80.2, 3.55 + B, 11.8], [90, 92, 96], 'Metal', { rot: [0, 40, 0] }));
  // Tool wall
  parts.push(K.box('Workshop_ToolWall', [0.4, 5, 11], [-90.8, 4.4 + B, -6], [110, 82, 48], 'WoodPlanks'));
  for (let i = 0; i < 3; i++) {
    parts.push(K.box(`Workshop_Tool_W_${i}`, [0.15, 1.3, 0.34], [-90.5, 4.6 + B, -10 + i * 1.4], [152, 156, 162], 'Metal'));
  }
  parts.push(K.box('Workshop_Tool_SawBlade', [0.15, 0.4, 2.6], [-90.5, 5.5 + B, -4.4], [158, 162, 168], 'Metal'));
  parts.push(K.box('Workshop_Tool_SawGrip', [0.2, 0.5, 1.2], [-90.5, 5.5 + B, -5.9], [70, 50, 34], 'Wood'));
  parts.push(K.cyl('Workshop_Tool_Tape', [0.1, 0.9, 0.9], [-90.5, 4.5 + B, -1.5], [210, 170, 40], 'Plastic', { rot: [90, 0, 0] }));

  // Armor dummies
  for (const [dx, dz, tag] of [[-76, -2, 'A'], [-76, 3, 'B']]) {
    parts.push(K.cyl(`Workshop_Dummy_${tag}_Post`, [0.5, 5, 0.5], [dx, 2.9 + B, dz], [70, 56, 40], 'Wood'));
    parts.push(K.box(`Workshop_Dummy_${tag}_Torso`, [2, 2.5, 1.2], [dx, 4.6 + B, dz], [66, 72, 82], 'Metal'));
    parts.push(K.ball(`Workshop_Dummy_${tag}_Head`, [1, 1, 1], [dx, 6.6 + B, dz], [74, 80, 90], 'Metal'));
    parts.push(K.box(`Workshop_Dummy_${tag}_ShoulderL`, [0.5, 0.4, 1.8], [dx, 5.6 + B, dz - 0.9], [60, 66, 76], 'Metal', { canCollide: false }));
    parts.push(K.box(`Workshop_Dummy_${tag}_ShoulderR`, [0.5, 0.4, 1.8], [dx, 5.6 + B, dz + 0.9], [60, 66, 76], 'Metal', { canCollide: false }));
  }
  // Welding table + mask
  parts.push(K.box('Workshop_WeldTable', [4, 0.3, 3], [-66, 2.8 + B, 12], [64, 60, 56], 'Metal'));
  parts.push(K.box('Workshop_WeldLegA', [0.4, 2.7, 0.4], [-67.6, 1.35 + B, 12], [54, 52, 50], 'Metal'));
  parts.push(K.box('Workshop_WeldLegB', [0.4, 2.7, 0.4], [-64.4, 1.35 + B, 12], [54, 52, 50], 'Metal'));
  parts.push(K.box('Workshop_WeldMask', [1.1, 1.2, 0.5], [-66.6, 3.6 + B, 11.4], [80, 60, 30], 'Plastic', { rot: [0, 30, -8] }));
  parts.push(K.box('Workshop_WeldMaskVisor', [0.9, 0.5, 0.1], [-66.5, 3.75 + B, 11.1], [30, 60, 90], 'Glass', { rot: [0, 30, -8], transparency: 0.2, canCollide: false }));
  // Generator + fuel barrel
  parts.push(K.box('Workshop_Generator', [4, 3, 2.6], [-59, 1.5 + B, 18], [76, 70, 58], 'CorrodedMetal'));
  parts.push(K.cyl('Workshop_GeneratorPipes', [0.3, 2.6, 0.3], [-58, 4.2 + B, 18.6], [52, 50, 48], 'Metal'));
  parts.push(K.box('Workshop_GeneratorPanel', [0.3, 1.4, 1.6], [-61, 1.8 + B, 18], [56, 62, 66], 'Metal', { canCollide: false }));
  K.makeBarrel(parts, fx, 'Workshop_FuelBarrel', -55, 21, { y: B, color: [96, 70, 40] });
  fx.push(K.light('Workshop_Generator', 'Workshop_Generator_Light', { color: [255, 150, 60], brightness: 1.2, range: 14, shadows: false }));
  // Tire stack
  for (let i = 0; i < 5; i++) {
    parts.push(K.cyl(`Workshop_Tire_${i}`, [3, 0.9, 3], [-88 + i * 0.28, 0.45 + B + i * 0.92, -14 - i * 0.2], [36, 36, 38], 'Metal',
      { rot: [K.range(rng, -4, 4), K.range(rng, 0, 40), K.range(rng, -4, 4)] }));
  }
  // Scrap pile
  for (let i = 0; i < 9; i++) {
    parts.push(K.box(`Workshop_Scrap_${i}`, [K.range(rng, 1, 2.6), 0.18, K.range(rng, 1, 2.4)],
      [-70 + K.range(rng, -4, 4), 0.35 + B + i * 0.1, -16 + K.range(rng, -3, 3)],
      K.pick(rng, [[110, 108, 104], [90, 88, 86], [130, 110, 80]]), 'CorrodedMetal',
      { rot: [K.range(rng, -8, 8), K.range(rng, 0, 360), K.range(rng, -8, 8)], canCollide: false }));
  }
  // Oil stains
  for (let i = 0; i < 4; i++) {
    parts.push(K.cyl(`Workshop_OilStain_${i}`, [K.range(rng, 2, 3.6), 0.05, K.range(rng, 2, 3.6)],
      [-78 + K.range(rng, -8, 8), B + 0.03, 4 + K.range(rng, -6, 6)], [30, 28, 26], 'Asphalt', { transparency: 0.35, canCollide: false }));
  }
  // First aid corner
  parts.push(K.box('Workshop_FirstAid', [2.6, 3, 1.4], [-88.5, 3.6 + B, 14], [230, 228, 224], 'Metal'));
  parts.push(K.box('Workshop_FirstAid_CrossA', [1.3, 0.4, 0.1], [-88.5, 3.8 + B, 13.25], [210, 60, 54], 'SmoothPlastic', { canCollide: false }));
  parts.push(K.box('Workshop_FirstAid_CrossB', [0.4, 1.3, 0.1], [-88.5, 3.8 + B, 13.25], [210, 60, 54], 'SmoothPlastic', { canCollide: false }));
  parts.push(K.box('Workshop_Stretcher_PoleA', [0.2, 6, 0.2], [-84, 2.8 + B, 18], [120, 92, 56], 'Wood', { rot: [0, 0, 60] }));
  parts.push(K.box('Workshop_Stretcher_PoleB', [0.2, 6, 0.2], [-83.2, 2.8 + B, 18], [120, 92, 56], 'Wood', { rot: [0, 0, 60] }));
  parts.push(K.box('Workshop_Stretcher_Canvas', [1.2, 5.2, 0.1], [-83.6, 2.8 + B, 18], [140, 134, 120], 'Fabric', { rot: [0, 0, 60], canCollide: false }));
  // Map table
  parts.push(K.box('Workshop_MapTable', [6, 0.3, 4], [-72, 2.4 + B, -10], [110, 84, 52], 'WoodPlanks'));
  parts.push(K.box('Workshop_MapTable_Base', [1.6, 2.3, 1.6], [-72, 1.15 + B, -10], [92, 70, 44], 'Wood'));
  parts.push(K.box('Workshop_Map', [4.6, 0.05, 3], [-72, 2.6 + B, -10], [228, 218, 190], 'Plastic', { rot: [0, -6, 0], canCollide: false }));
  for (let i = 0; i < 3; i++) {
    parts.push(K.cyl(`Workshop_MapPin_${i}`, [0.14, 0.5, 0.14], [-73.4 + i * 1.4, 2.95 + B, -10.6 + (i % 2) * 1.2],
      [[210, 60, 54], [220, 200, 60], [60, 120, 210]][i], 'SmoothPlastic', { canCollide: false }));
  }
  parts.push(K.box('Workshop_Radio', [1.5, 0.9, 0.9], [-69.6, 3 + B, -9.4], [54, 52, 50], 'Metal', { rot: [0, -22, 0] }));
  parts.push(K.cyl('Workshop_MugA', [0.45, 0.6, 0.45], [-71, 2.95 + B, -8.6], [200, 200, 205], 'Plastic'));
  // Work lamp
  parts.push(K.cyl('Workshop_Lamp_Shade', [1.8, 1, 1.8], [-74, 4.6 + B, 10], [150, 80, 40], 'Metal', { rot: [24, 0, 0] }));
  parts.push(K.ball('Workshop_Lamp_Bulb', [1, 1, 1], [-74, 4.1 + B, 9.6], [255, 220, 160], 'Neon', { canCollide: false, transparency: 0.1 }));
  fx.push(K.light('Workshop_Lamp_Bulb', 'Workshop_Lamp_Light', { color: [255, 210, 145], brightness: 2.2, range: 26 }));
  // Sign + exterior clutter
  parts.push(K.box('Workshop_Sign', [8, 2.6, 0.4], [-54.6, 7.2 + B, 0], [188, 152, 92], 'Metal', { rot: [0, -90, 0] }));
  parts.push(K.box('Workshop_Sign_PostL', [0.3, 12, 0.3], [-55, 6 + B, -3.6], [60, 58, 56], 'Metal'));
  parts.push(K.box('Workshop_Sign_PostR', [0.3, 12, 0.3], [-55, 6 + B, 3.6], [60, 58, 56], 'Metal'));
  K.crate(parts, 'Workshop_Ext_CrateA', -52, B, -20, 2.6, -14);
  K.crate(parts, 'Workshop_Ext_CrateB', -51, B, 21, 2.4, 26);
  K.rebar(parts, 'Workshop_Ext_Rebar', -50.5, B, 0, 4, rng);

  return { parts, fx };
};

// --- 05 MURO DE LOS CAIDOS --------------------------------------------------
Z['05_Muro_Caidos'] = () => {
  const parts = [], fx = [];
  const B = 0.35;
  const rng = K.makeRng(505);

  parts.push(K.box('Memorial_Apron', [70, 0.35, 26], [0, 0.175, 72], [58, 56, 52], 'Asphalt'));
  parts.push(K.box('Memorial_Wall', [56, 9, 3], [0, 4.5 + B, 76], [88, 86, 80], 'Concrete'));
  parts.push(K.box('Memorial_Coping', [58, 0.7, 3.6], [0, 9.35 + B, 76], [72, 70, 66], 'Concrete', { canCollide: false }));
  parts.push(K.box('Memorial_Base', [58, 1, 4.4], [0, 0.5 + B, 76], [78, 76, 70], 'Concrete'));
  for (let i = 0; i < 5; i++) {
    parts.push(K.box(`Memorial_Pilaster_${i}`, [1.5, 9.6, 4], [-28 + i * 14, 4.8 + B, 76], [80, 78, 72], 'Concrete'));
  }
  // Small plaques
  const plaqueIdx = [0, 1, 4, 5];
  for (const i of plaqueIdx) {
    const px = -24 + i * 9.6;
    parts.push(K.box(`Plaque_0${i + 1}`, [6, 4, 0.25], [px, 5.4 + B, 74.35], [128, 124, 116], 'Metal'));
    parts.push(K.box(`Plaque_0${i + 1}_Frame`, [6.6, 4.6, 0.18], [px, 5.4 + B, 74.45], [96, 92, 86], 'Metal', { canCollide: false }));
  }
  // Big sign + graffiti plaque
  parts.push(K.box('Memorial_Sign', [12, 4.6, 0.3], [-15.5, 5.5 + B, 74.35], [110, 106, 98], 'Metal'));
  parts.push(K.box('Plaque_04', [12, 4.6, 0.3], [15.5, 5.5 + B, 74.35], [102, 98, 92], 'Metal'));
  // Candles
  for (let i = 0; i < 8; i++) {
    const cx = -24 + i * 6.8 + K.range(rng, -0.6, 0.6);
    parts.push(K.cyl(`Memorial_Candle_${i}`, [0.32, 0.75, 0.32], [cx, 1.4 + B, 73], [232, 228, 215], 'Plastic'));
    parts.push(K.ball(`Memorial_CandleFlame_${i}`, [0.2, 0.28, 0.2], [cx, 1.85 + B, 73], [255, 190, 90], 'Neon', { canCollide: false, transparency: 0.2 }));
  }
  // Flowers
  for (let i = 0; i < 3; i++) {
    const fx2 = -18 + i * 18;
    parts.push(K.cyl(`Memorial_Flower_${i}_Base`, [1.6, 0.3, 1.6], [fx2, 1.1 + B, 72.6], [70, 90, 55], 'LeafyGrass'));
    parts.push(K.ball(`Memorial_Flower_${i}_A`, [0.5, 0.5, 0.5], [fx2 - 0.3, 1.45 + B, 72.6], [200, 60, 60], 'SmoothPlastic', { canCollide: false }));
    parts.push(K.ball(`Memorial_Flower_${i}_B`, [0.45, 0.45, 0.45], [fx2 + 0.3, 1.4 + B, 72.5], [225, 190, 70], 'SmoothPlastic', { canCollide: false }));
    parts.push(K.ball(`Memorial_Flower_${i}_C`, [0.4, 0.4, 0.4], [fx2, 1.5 + B, 72.9], [230, 230, 235], 'SmoothPlastic', { canCollide: false }));
  }
  fx.push(K.light('Memorial_Candle_2', 'Memorial_CandleLight', { color: [255, 190, 100], brightness: 1.1, range: 12, shadows: false }));
  fx.push(K.light('Memorial_Candle_6', 'Memorial_CandleLight2', { color: [255, 190, 100], brightness: 1.1, range: 12, shadows: false }));
  fx.push(K.light('Memorial_Wall', 'Memorial_Uplight', { color: [255, 214, 170], brightness: 1.3, range: 30, shadows: false }));
  // Fence
  for (let i = 0; i < 5; i++) {
    parts.push(K.cyl(`Memorial_FencePost_${i}`, [0.4, 3.4, 0.4], [-20 + i * 10, 1.7 + B, 68], [88, 70, 48], 'Wood'));
  }
  parts.push(K.box('Memorial_FenceRail', [40, 0.25, 0.25], [0, 2.6 + B, 68], [96, 76, 52], 'Wood', { canCollide: false }));
  parts.push(K.box('Memorial_FenceRail2', [40, 0.2, 0.2], [0, 1.5 + B, 68], [96, 76, 52], 'Wood', { canCollide: false }));
  // Scoreboard mast
  parts.push(K.cyl('Score_Mast', [0.9, 15, 0.9], [26, 7.5 + B, 72], [62, 58, 52], 'Metal'));
  parts.push(K.box('Score_Board', [14, 9, 0.8], [26, 13, 72], [46, 44, 42], 'Metal', { rot: [0, 40, 0] }));
  parts.push(K.box('Score_Board_Top', [14.6, 0.7, 1], [26, 17.8, 72], [60, 56, 52], 'Metal', { rot: [0, 40, 0], canCollide: false }));
  fx.push(K.light('Score_Board_Top', 'Score_Board_Light', { color: [190, 210, 235], brightness: 1.8, range: 26, shadows: false }));
  // Benches
  for (const [bx, bz, tag] of [[-10, 70, 'A'], [10, 70, 'B']]) {
    parts.push(K.box(`Memorial_Bench_${tag}`, [6, 0.3, 1.8], [bx, 1.35 + B, bz], [96, 76, 50], 'WoodPlanks'));
    parts.push(K.box(`Memorial_Bench_${tag}_LegA`, [0.4, 1.2, 1.5], [bx - 2.5, 0.6 + B, bz], [70, 54, 36], 'Wood'));
    parts.push(K.box(`Memorial_Bench_${tag}_LegB`, [0.4, 1.2, 1.5], [bx + 2.5, 0.6 + B, bz], [70, 54, 36], 'Wood'));
  }
  // Photo frames on wall
  for (let i = 0; i < 4; i++) {
    const px = -21 + i * 14;
    parts.push(K.box(`Memorial_Frame_${i}`, [2.2, 2.6, 0.2], [px, 7.8 + B, 74.4], [58, 54, 48], 'WoodPlanks', { canCollide: false }));
    parts.push(K.box(`Memorial_Frame_${i}_Inner`, [1.7, 2.1, 0.12], [px, 7.8 + B, 74.34], [190, 185, 175], 'Plastic', { canCollide: false }));
  }
  K.trash(parts, 'Memorial_Trash', 8, 66, 5, rng, B);

  return { parts, fx };
};

// --- 06 RUINAS --------------------------------------------------------------
Z['06_Ruinas'] = () => {
  const parts = [], fx = [];

  function ruinBuilding(tag, cx, cz, seed, cfg) {
    const rng = K.makeRng(seed);
    const B = 0.3;
    parts.push(K.box(`Ruin_${tag}_Slab`, [46, 0.3, 36], [cx, 0.15, cz], [64, 62, 58], 'Concrete'));
    let wi = 0;
    for (const [lx, lz, w, h] of cfg.walls) {
      parts.push(K.box(`Ruin_${tag}_Wall_${wi}`, [w, h, 2.6], [cx + lx, h / 2 + B, cz + lz],
        cfg.brick ? [118, 86, 70] : [92, 89, 84], cfg.brick ? 'Brick' : 'Concrete'));
      for (let t = 0; t < 3; t++) {
        parts.push(K.box(`Ruin_${tag}_Wall_${wi}_Tooth_${t}`, [K.range(rng, 1.2, 2.4), K.range(rng, 0.7, 2), 2.6],
          [cx + lx + K.range(rng, -Math.max(1, w / 2 - 1.5), Math.max(1, w / 2 - 1.5)), h + B + 0.5, cz + lz],
          [84, 81, 76], 'Concrete', { rot: [0, K.range(rng, -8, 8), 0] }));
      }
      if (w > 6 && h > 6) {
        const isZWall = Math.abs(lz) > Math.abs(lx);
        parts.push(K.box(`Ruin_${tag}_Win_${wi}`, isZWall ? [3, 3, 0.4] : [0.4, 3, 3],
          [cx + lx + (isZWall ? 0 : 1.35), h * 0.62 + B, cz + lz + (isZWall ? 1.35 : 0)],
          [26, 26, 28], 'Plastic', { canCollide: false }));
      }
      wi++;
    }
    let fi = 0;
    for (const [lx, ly, lz, lw, ld] of cfg.floors) {
      parts.push(K.box(`Ruin_${tag}_Floor_${fi}`, [lw, 0.35, ld], [cx + lx, ly + B, cz + lz], [76, 73, 68], 'Concrete'));
      fi++;
    }
    for (let i = 0; i < 3; i++) {
      K.rebar(parts, `Ruin_${tag}_Rebar_${i}`, cx + K.range(rng, -18, 18), 0.5, cz + K.range(rng, -14, 14), 3, rng);
    }
    K.rubble(parts, `Ruin_${tag}_Rubble`, cx + K.range(rng, -12, 12), cz + K.range(rng, -8, 8), 5, 10, rng, B);
    K.rubble(parts, `Ruin_${tag}_Rubble2`, cx + K.range(rng, -12, 12), cz + K.range(rng, -8, 8), 4, 8, rng, B);
    parts.push(K.box(`Ruin_${tag}_Beam`, [12, 0.9, 0.9], [cx + K.range(rng, -8, 8), 1 + B, cz + K.range(rng, -6, 6)],
      [70, 54, 36], 'Wood', { rot: [K.range(rng, -10, 10), K.range(rng, 0, 360), K.range(rng, -10, 10)] }));
    for (let i = 0; i < 2; i++) {
      parts.push(K.box(`Ruin_${tag}_Graffiti_${i}`, [3.6, 2, 0.1], [cx + K.range(rng, -14, 14), K.range(rng, 2, 4), cz + K.range(rng, -12, 12)],
        K.pick(rng, [[110, 40, 90], [40, 90, 110], [90, 110, 40]]), 'SmoothPlastic', { rot: [0, K.range(rng, 0, 360), 0], canCollide: false }));
    }
    if (cfg.smoke) {
      parts.push(K.P(`Ruin_${tag}_SmokeAnchor`, { size: [1, 1, 1], pos: [cx + 8, 6, cz - 6], color: [100, 100, 100], transparency: 1, canCollide: false }));
      fx.push(K.smoke(`Ruin_${tag}_SmokeAnchor`, `Ruin_${tag}_Smoke`, { rate: 5, lifetime: [3, 6], sizeCurve: [[0, 2], [1, 8]], color: [52, 50, 50] }));
    }
  }

  ruinBuilding('NE', 78, -78, 601, {
    walls: [
      [-14, -18, 14, 9], [6, -18, 8, 16], [22, -6, 2.6, 20], [22, 12, 2.6, 8],
      [-20, 18, 20, 5], [2, 18, 10, 12], [-2, 6, 2.6, 22],
    ],
    floors: [[4, 7, 6, 18, 22], [-10, 14, -4, 10, 12]],
    brick: false, smoke: true,
  });
  ruinBuilding('NW', -78, -78, 602, {
    walls: [
      [-22, -10, 2.6, 18], [-22, 8, 2.6, 10], [0, -18, 30, 7], [14, -18, 10, 17],
      [0, 18, 26, 9], [-12, 10, 2, 12],
    ],
    floors: [[-6, 7, -4, 20, 16], [8, 14, 4, 12, 14]],
    brick: true, smoke: true,
  });
  ruinBuilding('SE', 78, 78, 603, {
    walls: [
      [-22, -8, 2.6, 14], [10, -18, 16, 10], [-4, -18, 12, 18],
      [22, 0, 2.6, 22], [-8, 18, 24, 6], [12, 18, 8, 13],
    ],
    floors: [[0, 7, 0, 22, 18], [-8, 14, 8, 12, 10]],
    brick: false, smoke: false,
  });
  ruinBuilding('SW', -78, 78, 604, {
    walls: [
      [-14, -18, 16, 12], [8, -18, 10, 8], [-22, 0, 2.6, 21], [16, -6, 2.6, 16],
      [0, 18, 30, 7], [-10, 12, 2, 10],
    ],
    floors: [[2, 7, 2, 20, 16]],
    brick: true, smoke: false,
  });

  return { parts, fx };
};

// --- 07 DETALLE URBANO ------------------------------------------------------
Z['07_Detalle_Urbano'] = () => {
  const parts = [], fx = [];
  const rng = K.makeRng(707);

  // Ground + streets
  parts.push(K.box('Ground_Main', [420, 0.18, 420], [0, 0.09, 0], [56, 53, 48], 'Ground', { canCollide: false }));
  parts.push(K.box('Street_NS_North', [30, 0.2, 110], [0, 0.1, -96], [48, 48, 52], 'Asphalt'));
  parts.push(K.box('Street_NS_South', [30, 0.2, 110], [0, 0.1, 96], [48, 48, 52], 'Asphalt'));
  parts.push(K.box('Street_EW_East', [110, 0.2, 30], [96, 0.1, 0], [48, 48, 52], 'Asphalt'));
  parts.push(K.box('Street_EW_West', [110, 0.2, 30], [-96, 0.1, 0], [48, 48, 52], 'Asphalt'));
  for (let i = 0; i < 8; i++) {
    const z1 = -146 + i * 13.4;
    if (z1 > -46) break;
    parts.push(K.box(`RoadLine_NS_N_${i}`, [0.6, 0.04, 5], [0, 0.22, z1], [200, 186, 120], 'Plastic', { transparency: 0.3, canCollide: false }));
  }
  for (let i = 0; i < 8; i++) {
    parts.push(K.box(`RoadLine_NS_S_${i}`, [0.6, 0.04, 5], [0, 0.22, 46 + i * 13.4], [200, 186, 120], 'Plastic', { transparency: 0.3, canCollide: false }));
  }
  for (let i = 0; i < 6; i++) {
    parts.push(K.box(`RoadLine_EW_E_${i}`, [5, 0.04, 0.6], [46 + i * 13.4, 0.22, 0], [200, 186, 120], 'Plastic', { transparency: 0.3, canCollide: false }));
    parts.push(K.box(`RoadLine_EW_W_${i}`, [5, 0.04, 0.6], [-46 - i * 13.4, 0.22, 0], [200, 186, 120], 'Plastic', { transparency: 0.3, canCollide: false }));
  }
  for (let i = 0; i < 6; i++) {
    parts.push(K.box(`Crosswalk_N_${i}`, [1.1, 0.05, 6], [-12.5 + i * 5, 0.24, -34], [210, 205, 195], 'Plastic', { transparency: 0.25, canCollide: false }));
    parts.push(K.box(`Crosswalk_S_${i}`, [1.1, 0.05, 6], [-12.5 + i * 5, 0.24, 34], [210, 205, 195], 'Plastic', { transparency: 0.25, canCollide: false }));
  }
  // Sidewalks
  for (const [sx, sz, tag] of [[-18.5, -96, 'NW'], [18.5, -96, 'NE'], [-18.5, 96, 'SW'], [18.5, 96, 'SE']]) {
    parts.push(K.box(`Sidewalk_NS_${tag}`, [7, 0.55, 110], [sx, 0.275, sz], [116, 113, 106], 'Pavement'));
  }
  for (const [sx, sz, tag] of [[-96, -18.5, 'WN'], [-96, 18.5, 'WS'], [96, -18.5, 'EN'], [96, 18.5, 'ES']]) {
    parts.push(K.box(`Sidewalk_EW_${tag}`, [110, 0.55, 7], [sx, 0.275, sz], [116, 113, 106], 'Pavement'));
  }
  for (let i = 0; i < 10; i++) {
    parts.push(K.box(`Sidewalk_Crack_${i}`, [K.range(rng, 1.5, 3.5), 0.06, 0.35],
      [K.pick(rng, [-18.5, 18.5]) + K.range(rng, -2.5, 2.5), 0.56, K.range(rng, -140, 140)], [70, 68, 64], 'Asphalt',
      { rot: [0, K.range(rng, -30, 30), 0], transparency: 0.1, canCollide: false }));
  }

  // Cars
  K.makeCar(parts, fx, 'Car_Burnt_NS', 9.5, -34, 6, null, { burned: true, y: 0.2, tilt: 3, hoodOpen: true });
  K.makeCar(parts, fx, 'Car_Blue_NS', -8.5, -47, -24, [56, 66, 96], { y: 0.2 });
  K.makeCar(parts, fx, 'Car_Silver_EW', 52, 8.5, 97, [138, 138, 143], { y: 0.2 });
  K.makeCar(parts, fx, 'Car_Rust_EW', -44, -8.5, 84, [148, 140, 122], { y: 0.2, burned: true, tilt: -3 });
  K.makeCar(parts, fx, 'Car_Green_EW', 24, -9, 88, [62, 76, 62], { y: 0.2 });
  K.makeCar(parts, fx, 'Car_Gray_NS', -6, 58, 183, [110, 112, 116], { y: 0.2, hoodOpen: true });

  // Bus wreck
  const BUS = [7, 0.2, 62], busYaw = 354;
  parts.push(K.box('Bus_Body', [6, 5.6, 22], [BUS[0], 3.0, BUS[2]], [118, 128, 138], 'CorrodedMetal', { rot: [0, busYaw, 0] }));
  parts.push(K.box('Bus_Stripe', [6.15, 1, 22.1], [BUS[0], 3.4, BUS[2]], [60, 84, 110], 'Metal', { rot: [0, busYaw, 0], canCollide: false }));
  parts.push(K.box('Bus_Roof', [5.7, 0.5, 21.4], [BUS[0], 6, BUS[2]], [100, 110, 120], 'Metal', { rot: [0, busYaw, 2], canCollide: false }));
  for (let i = 0; i < 5; i++) {
    const wl = -8 + i * 4;
    const [wx, wz] = K.rot2(3.15, wl, busYaw);
    parts.push(K.box(`Bus_Window_${i}`, [0.25, 1.8, 3], [BUS[0] + wx, 4.2, BUS[2] + wz], [30, 36, 40], 'Glass',
      { rot: [0, busYaw, 0], transparency: 0.55, canCollide: false }));
    const [wx2, wz2] = K.rot2(-3.15, wl, busYaw);
    parts.push(K.box(`Bus_Window2_${i}`, [0.25, 1.8, 3], [BUS[0] + wx2, 4.2, BUS[2] + wz2], [30, 36, 40], 'Glass',
      { rot: [0, busYaw, 0], transparency: 0.55, canCollide: false }));
  }
  parts.push(K.box('Bus_Door', [0.3, 4.2, 2.6], [BUS[0] - 3.2, 3.2, BUS[2] + 8], [90, 100, 110], 'Metal', { rot: [0, busYaw + 55, 0], canCollide: false }));
  [[-2.5, -7.5], [-2.5, 7.5], [2.5, -7.5], [2.5, 7.5]].forEach(([lx, lz], i) => {
    const [wx, wz] = K.rot2(lx, lz, busYaw);
    parts.push(K.cyl(`Bus_Wheel_${i}`, [2.4, 1, 2.4], [BUS[0] + wx, 1.2, BUS[2] + wz], [30, 30, 32], 'Metal', { rot: [0, busYaw, 0] }));
  });

  // Street lamps (3 working, 3 broken)
  K.lampPost(parts, fx, 'Street_Lamp_1', 19, -60, { b: 0.55, rotY: 180 });
  K.lampPost(parts, fx, 'Street_Lamp_2', -19, -105, { b: 0.55, rotY: 0 });
  K.lampPost(parts, fx, 'Street_Lamp_3', 60, 19, { b: 0.55, rotY: 90 });
  K.lampPost(parts, fx, 'Street_Lamp_4', -19, 60, { b: 0.55, rotY: 0, broken: true, tiltDir: 1 });
  K.lampPost(parts, fx, 'Street_Lamp_5', 105, -19, { b: 0.55, rotY: -90, broken: true, tiltDir: -1 });
  K.lampPost(parts, fx, 'Street_Lamp_6', -60, 19, { b: 0.55, rotY: 90, broken: true, tiltDir: 1 });

  // Traffic lights (dead)
  for (const [tx, tz, tRot, tag] of [[24, 24, 225, 'A'], [-24, -24, 45, 'B']]) {
    parts.push(K.cyl(`Traffic_Pole_${tag}`, [0.55, 12, 0.55], [tx, 6 + 0.45, tz], [58, 58, 62], 'Metal'));
    const [ax, az] = K.rot2(0, -3, tRot);
    parts.push(K.box(`Traffic_Arm_${tag}`, [0.4, 0.4, 6], [tx + ax, 11.4, tz + az], [58, 58, 62], 'Metal', { rot: [0, tRot, 0] }));
    parts.push(K.box(`Traffic_Head_${tag}`, [1.2, 3.2, 1], [tx + K.rot2(0, -5.4, tRot)[0], 9.8, tz + K.rot2(0, -5.4, tRot)[1]], [44, 44, 46], 'Metal', { rot: [0, tRot, 0] }));
    const lensCols = [[80, 30, 30], [80, 70, 30], [30, 70, 40]];
    for (let i = 0; i < 3; i++) {
      parts.push(K.ball(`Traffic_Lens_${tag}_${i}`, [0.6, 0.6, 0.3], [tx + K.rot2(0, -5.4, tRot)[0], 10.8 - i, tz + K.rot2(0, -5.4, tRot)[1]],
        lensCols[i], 'SmoothPlastic', { rot: [0, tRot, 0], canCollide: false }));
    }
  }

  // Hydrant + manhole + debris
  parts.push(K.cyl('Hydrant_Body', [1, 2.2, 1], [19.5, 1.55, 16.5], [150, 52, 40], 'Metal'));
  parts.push(K.ball('Hydrant_Cap', [0.8, 0.8, 0.8], [19.5, 2.75, 16.5], [150, 52, 40], 'Metal'));
  parts.push(K.cyl('Hydrant_NubA', [0.4, 0.6, 0.4], [20.3, 1.9, 16.5], [130, 45, 35], 'Metal', { rot: [0, 0, 90] }));
  parts.push(K.cyl('Hydrant_NubB', [0.4, 0.6, 0.4], [18.7, 1.9, 16.5], [130, 45, 35], 'Metal', { rot: [0, 0, 90] }));
  parts.push(K.cyl('Manhole', [2.6, 0.12, 2.6], [4, 0.24, 30], [44, 43, 41], 'Metal'));
  parts.push(K.cyl('Manhole2', [2.6, 0.12, 2.6], [-52, 0.24, -4], [44, 43, 41], 'Metal'));
  for (let i = 0; i < 14; i++) {
    parts.push(K.box(`Road_Debris_${i}`, [K.range(rng, 0.6, 1.8), K.range(rng, 0.2, 0.5), K.range(rng, 0.6, 1.6)],
      [K.pick(rng, [1, -1]) * K.range(rng, 10, 14), 0.32, K.range(rng, -130, 130)], K.pick(rng, [[90, 88, 84], [70, 68, 64]]), 'Concrete',
      { rot: [K.range(rng, -10, 10), K.range(rng, 0, 360), K.range(rng, -10, 10)], canCollide: false }));
  }

  // Dead trees + trash
  for (const [tx2, tz2] of [[48, -30], [-52, -34], [52, 34], [-48, 38], [30, -46], [-34, 46]]) {
    K.deadTree(parts, `Tree_${tx2}_${tz2}`, tx2, tz2, K.makeRng(700 + tx2 + tz2), 0.18);
  }
  for (let i = 0; i < 8; i++) {
    K.trash(parts, `Street_Trash_${i}`, K.range(rng, -110, 110), K.range(rng, -110, 110), 4, rng, 0.2);
  }
  // Papers + blood stains
  for (let i = 0; i < 14; i++) {
    parts.push(K.box(`Paper_${i}`, [0.8, 0.02, 1.1], [K.range(rng, -60, 60), 0.26, K.range(rng, -60, 60)],
      [215, 210, 200], 'Plastic', { rot: [0, K.range(rng, 0, 360), 0], canCollide: false, transparency: 0.05 }));
  }
  for (let i = 0; i < 7; i++) {
    parts.push(K.cyl(`Blood_${i}`, [K.range(rng, 1.5, 3), 0.06, K.range(rng, 1.5, 3)],
      [K.range(rng, -50, 50), 0.26, K.range(rng, -50, 50)], [58, 12, 12], 'Asphalt', { transparency: 0.4, canCollide: false }));
  }

  // Fence remnants + warning tape
  for (const [fx3, fz3, fRot, tag] of [[-40, -30, 0, 'A'], [40, 30, 0, 'B'], [-30, 40, 90, 'C']]) {
    for (let i = 0; i < 4; i++) {
      const [ox, oz] = K.rot2(0, i * 5 - 7.5, fRot);
      parts.push(K.cyl(`FenceR_${tag}_Post_${i}`, [0.3, 5, 0.3], [fx3 + ox, 2.5 + 0.18, fz3 + oz], [96, 90, 82], 'Metal'));
    }
    for (let i = 0; i < 3; i++) {
      const [ox, oz] = K.rot2(0, i * 5 - 5, fRot);
      parts.push(K.box(`FenceR_${tag}_Panel_${i}`, [0.1, 3.4, 4.8], [fx3 + ox, 2.8, fz3 + oz], [150, 155, 150], 'Glass',
        { rot: [0, fRot, 0], transparency: 0.65, canCollide: false }));
    }
  }
  for (const [wx2, wz2, wRot, tag] of [[0, -44, 0, 'A'], [0, 44, 0, 'B'], [44, 0, 90, 'C'], [-44, 0, 90, 'D']]) {
    const [ox, oz] = K.rot2(0, 0, wRot);
    parts.push(K.box(`WarnTape_${tag}`, [8, 0.06, 0.5], [wx2, 1.5, wz2], [225, 195, 40], 'Fabric', { rot: [0, wRot, 0], canCollide: false, transparency: 0.15 }));
    parts.push(K.cyl(`WarnTape_${tag}_PoleA`, [0.2, 3, 0.2], [wx2 - ox * 3.6, 1.5 + 0.2, wz2 - oz * 3.6], [70, 70, 74], 'Metal'));
    parts.push(K.cyl(`WarnTape_${tag}_PoleB`, [0.2, 3, 0.2], [wx2 + ox * 3.6, 1.5 + 0.2, wz2 + oz * 3.6], [70, 70, 74], 'Metal'));
  }

  // Street signs + bus stop
  parts.push(K.cyl('Street_Sign_1_Pole', [0.25, 8, 0.25], [22, 4, -22], [70, 70, 74], 'Metal'));
  parts.push(K.box('Street_Sign_1', [3.6, 1.1, 0.2], [22, 7.3, -22], [46, 96, 62], 'Metal', { rot: [0, 180, 0] }));
  parts.push(K.cyl('Street_Sign_2_Pole', [0.25, 8, 0.25], [-22, 4, 22], [70, 70, 74], 'Metal'));
  parts.push(K.box('Street_Sign_2', [3.6, 1.1, 0.2], [-22, 7.3, 22], [46, 96, 62], 'Metal', { rot: [0, -45, 0] }));
  parts.push(K.cyl('Bus_Stop_Pole', [0.25, 7, 0.25], [14, 4.05, 50], [70, 70, 74], 'Metal'));
  parts.push(K.box('Bus_Stop_Sign', [2.4, 2, 0.15], [14, 6.4, 50], [190, 186, 174], 'Metal', { rot: [0, -90, 0] }));

  // Perimeter rubble mounds + broken walls
  for (const [px, pz] of [[0, -140], [0, 140], [140, 0], [-140, 0], [100, -100], [-100, -100], [100, 100], [-100, 100]]) {
    K.rubble(parts, `Perimeter_Mound_${px}_${pz}`, px, pz, 12, 10, K.makeRng(900 + px + pz), 0.18,
      [[70, 62, 54], [56, 53, 48], [84, 80, 74]]);
  }
  for (const [wx3, wz3, wRot3, tag] of [
    [115, -40, 10, 'A'], [-115, 40, -8, 'B'], [40, -115, 80, 'C'],
    [-40, 115, 95, 'D'], [115, 40, -12, 'E'], [-115, -40, 6, 'F'],
  ]) {
    parts.push(K.box(`Perimeter_Wall_${tag}`, [20, K.range(rng, 5, 8), 3], [wx3, 3 + 0.18, wz3], [88, 85, 80], 'Concrete', { rot: [0, wRot3, 0] }));
    parts.push(K.box(`Perimeter_Wall_${tag}_Cap`, [20.4, 0.5, 3.4], [wx3, 6.8, wz3], [72, 70, 66], 'Concrete', { rot: [0, wRot3, 0], canCollide: false }));
  }

  // Ambient dust
  parts.push(K.P('Urban_Dust_Anchor', { size: [1, 1, 1], pos: [40, 8, -40], color: [200, 200, 200], transparency: 1, canCollide: false }));
  parts.push(K.P('Urban_Dust_Anchor2', { size: [1, 1, 1], pos: [-40, 8, 40], color: [200, 200, 200], transparency: 1, canCollide: false }));
  fx.push(K.dust('Urban_Dust_Anchor', 'Urban_Dust', { rate: 3 }));
  fx.push(K.dust('Urban_Dust_Anchor2', 'Urban_Dust2', { rate: 3 }));

  return { parts, fx };
};

// --- 08 JAULA SUJETO #7 -----------------------------------------------------
Z['08_Jaula_Sujeto7'] = () => {
  const parts = [], fx = [];
  const rng = K.makeRng(808);
  const CX = -25, CZ = 8, B = 0.45; // on plaza slab
  const PLAT_TOP = 0.95;            // platform top
  const R = 7.8;                    // hexagon radius

  // Platform + hazard ring
  parts.push(K.cyl('Cage_Platform', [17, 0.5, 17], [CX, 0.7, CZ], [70, 68, 66], 'Concrete'));
  K.hazardRing(parts, 'Cage_Hazard', CX, PLAT_TOP + 0.04, CZ, 8.3, 14);
  // 6 posts + rails + glass panels; edge index 1 (mid-angle 90°) is the gate
  const vertex = (deg) => [CX + Math.sin((deg * Math.PI) / 180) * R, CZ + Math.cos((deg * Math.PI) / 180) * R];
  for (let e = 0; e < 6; e++) {
    const a = e * 60;
    const [vx, vz] = vertex(a);
    parts.push(K.cyl(`Cage_Post_${e}`, [0.55, 7.5, 0.55], [vx, PLAT_TOP + 3.75, vz], [58, 56, 54], 'Metal'));
    parts.push(K.ball(`Cage_PostCap_${e}`, [0.7, 0.7, 0.7], [vx, PLAT_TOP + 7.6, vz], [48, 46, 44], 'Metal', { canCollide: false }));
    const am = a + 30;
    const midR = R * Math.cos(Math.PI / 6);
    const mx = CX + Math.sin((am * Math.PI) / 180) * midR;
    const mz = CZ + Math.cos((am * Math.PI) / 180) * midR;
    if (e === 1) continue; // gate edge handled below
    parts.push(K.box(`Cage_RailTop_${e}`, [R, 0.2, 0.24], [mx, PLAT_TOP + 7.1, mz], [58, 56, 54], 'Metal',
      { rot: [0, am, 0], canCollide: false }));
    parts.push(K.box(`Cage_RailBot_${e}`, [R, 0.2, 0.24], [mx, PLAT_TOP + 1.1, mz], [58, 56, 54], 'Metal',
      { rot: [0, am, 0], canCollide: false }));
    parts.push(K.box(`Cage_Glass_${e}`, [R, 6.1, 0.16], [mx, PLAT_TOP + 4.1, mz], [140, 155, 148], 'Glass',
      { rot: [0, am, 0], transparency: 0.58, reflectance: 0.22 }));
  }
  // Gate (east edge, faces plaza center)
  const gx = CX + R * Math.cos(Math.PI / 6);
  parts.push(K.box('Cage_Gate_BarA', [0.22, 6.5, 0.22], [gx, PLAT_TOP + 3.6, CZ + 2.0], [48, 46, 44], 'Metal'));
  parts.push(K.box('Cage_Gate_BarB', [0.22, 6.5, 0.22], [gx, PLAT_TOP + 3.6, CZ], [48, 46, 44], 'Metal'));
  parts.push(K.box('Cage_Gate_BarC', [0.22, 6.5, 0.22], [gx, PLAT_TOP + 3.6, CZ - 2.0], [48, 46, 44], 'Metal'));
  parts.push(K.box('Cage_Gate_Cross', [0.26, 0.26, 7.6], [gx, PLAT_TOP + 4.4, CZ], [48, 46, 44], 'Metal', { canCollide: false }));
  parts.push(K.box('Cage_Gate_Lock', [0.5, 0.7, 0.5], [gx + 0.2, PLAT_TOP + 3.4, CZ], [120, 88, 40], 'CorrodedMetal'));
  parts.push(K.cyl('Cage_Gate_LockBody', [0.4, 0.3, 0.4], [gx + 0.2, PLAT_TOP + 3.0, CZ], [90, 66, 30], 'CorrodedMetal', { rot: [0, 0, 90], canCollide: false }));
  // Placard + beacons
  parts.push(K.box('Cage_Sign', [0.3, 2.2, 3.4], [gx + 0.35, PLAT_TOP + 5.9, CZ], [205, 178, 68], 'Metal', { rot: [0, -90, 0] }));
  parts.push(K.cyl('Cage_BeaconA', [0.5, 0.9, 0.5], [vertex(60)[0], PLAT_TOP + 8.1, vertex(60)[1]], [255, 60, 50], 'Neon', { canCollide: false }));
  parts.push(K.cyl('Cage_BeaconB', [0.5, 0.9, 0.5], [vertex(120)[0], PLAT_TOP + 8.1, vertex(120)[1]], [255, 60, 50], 'Neon', { canCollide: false }));
  fx.push(K.light('Cage_BeaconA', 'Cage_BeaconA_Light', { color: [255, 60, 50], brightness: 2, range: 15, shadows: false }));
  fx.push(K.light('Cage_BeaconB', 'Cage_BeaconB_Light', { color: [255, 60, 50], brightness: 2, range: 15, shadows: false }));

  // Sujeto #7 — built facing +X (toward the plaza)
  const SY = PLAT_TOP;
  parts.push(K.box('Cage_Subj_LegL', [0.75, 2.5, 0.75], [CX + 0.35, SY + 1.25, CZ - 0.5], [52, 48, 58], 'Fabric'));
  parts.push(K.box('Cage_Subj_LegR', [0.75, 2.5, 0.75], [CX + 0.35, SY + 1.25, CZ + 0.5], [52, 48, 58], 'Fabric'));
  parts.push(K.cyl('Cage_Subj_CuffL', [0.95, 0.4, 0.95], [CX + 0.35, SY + 0.35, CZ - 0.5], [56, 56, 60], 'Metal', { canCollide: false }));
  parts.push(K.cyl('Cage_Subj_CuffR', [0.95, 0.4, 0.95], [CX + 0.35, SY + 0.35, CZ + 0.5], [56, 56, 60], 'Metal', { canCollide: false }));
  parts.push(K.cyl('Cage_Subj_AnchorRing', [1.8, 0.2, 1.8], [CX + 1.3, SY + 0.15, CZ], [60, 60, 64], 'Metal', { canCollide: false }));
  for (let i = 0; i < 3; i++) {
    parts.push(K.box(`Cage_Subj_ChainL_${i}`, [0.26, 0.26, 0.26], [CX + 0.7 + i * 0.3, SY + 0.22, CZ - 0.42 + i * 0.08], [72, 72, 76], 'Metal',
      { rot: [0, i % 2 === 0 ? 45 : -45, 0], canCollide: false }));
    parts.push(K.box(`Cage_Subj_ChainR_${i}`, [0.26, 0.26, 0.26], [CX + 0.7 + i * 0.3, SY + 0.22, CZ + 0.42 - i * 0.08], [72, 72, 76], 'Metal',
      { rot: [0, i % 2 === 0 ? -45 : 45, 0], canCollide: false }));
  }
  parts.push(K.box('Cage_Subj_Torso', [1.4, 2.3, 2.3], [CX + 0.15, SY + 3.6, CZ], [78, 84, 74], 'Fabric', { rot: [0, 0, -8] }));
  parts.push(K.box('Cage_Subj_Blood', [0.08, 0.9, 0.8], [CX + 0.87, SY + 3.4, CZ], [70, 16, 16], 'SmoothPlastic', { rot: [0, 0, -8], canCollide: false }));
  parts.push(K.box('Cage_Subj_TearA', [0.08, 1.1, 0.9], [CX + 0.8, SY + 2.35, CZ - 0.5], [72, 78, 68], 'Fabric', { rot: [0, 0, 5], canCollide: false }));
  parts.push(K.box('Cage_Subj_TearB', [0.08, 0.9, 0.8], [CX + 0.82, SY + 2.45, CZ + 0.55], [72, 78, 68], 'Fabric', { rot: [0, 0, 4], canCollide: false }));
  parts.push(K.box('Cage_Subj_ArmL', [2.3, 0.72, 0.72], [CX + 1.45, SY + 4.6, CZ - 0.95], [104, 124, 84], 'Plastic', { rot: [0, 0, -14] }));
  parts.push(K.box('Cage_Subj_ArmR', [2.3, 0.72, 0.72], [CX + 1.45, SY + 4.7, CZ + 0.95], [104, 124, 84], 'Plastic', { rot: [0, 0, -10] }));
  parts.push(K.ball('Cage_Subj_HandL', [0.72, 0.72, 0.72], [CX + 2.62, SY + 4.3, CZ - 0.95], [100, 120, 80], 'Plastic', { canCollide: false }));
  parts.push(K.ball('Cage_Subj_HandR', [0.72, 0.72, 0.72], [CX + 2.62, SY + 4.42, CZ + 0.95], [100, 120, 80], 'Plastic', { canCollide: false }));
  parts.push(K.cyl('Cage_Subj_Neck', [0.6, 0.6, 0.6], [CX + 0.15, SY + 4.9, CZ], [100, 120, 80], 'Plastic'));
  parts.push(K.cyl('Cage_Subj_Collar', [1.05, 0.4, 1.05], [CX + 0.15, SY + 4.75, CZ], [56, 56, 60], 'Metal', { canCollide: false }));
  parts.push(K.P('Cage_Subj_Head', {
    size: [1.3, 1.4, 1.3], pos: [CX + 0.15, SY + 5.75, CZ], color: [104, 124, 84], material: 'Plastic',
    mesh: { type: 'Head', scale: [1.3, 1.4, 1.3] },
  }));
  parts.push(K.ball('Cage_Subj_EyeL', [0.18, 0.18, 0.18], [CX + 0.83, SY + 5.92, CZ - 0.32], [255, 40, 40], 'Neon', { canCollide: false }));
  parts.push(K.ball('Cage_Subj_EyeR', [0.18, 0.18, 0.18], [CX + 0.83, SY + 5.92, CZ + 0.32], [255, 40, 40], 'Neon', { canCollide: false }));
  parts.push(K.box('Cage_Subj_Mouth', [0.08, 0.36, 0.68], [CX + 0.82, SY + 5.35, CZ], [30, 22, 22], 'Plastic', { canCollide: false }));

  // Observation post outside the cage
  K.crate(parts, 'Cage_Obs_CrateA', -15, B, 3, 2.2, 20);
  K.crate(parts, 'Cage_Obs_CrateB', -14.6, B, 5.4, 2.2, -14);
  parts.push(K.box('Cage_Obs_Desk', [3.4, 0.25, 2.4], [-14.8, B + 2.35, 4.2], [116, 90, 56], 'WoodPlanks', { rot: [0, 12, 0] }));
  parts.push(K.box('Cage_Obs_Clipboard', [1.2, 0.08, 1.6], [-15.2, B + 2.55, 4.4], [180, 140, 70], 'Wood', { rot: [0, 20, 0], canCollide: false }));
  parts.push(K.box('Cage_Obs_Note', [0.8, 0.04, 1.1], [-14.4, B + 2.56, 4.0], [225, 220, 210], 'Plastic', { rot: [0, -15, 0], canCollide: false }));
  parts.push(K.cyl('Cage_Obs_Stool', [1.5, 0.4, 1.5], [-13, B + 1.5, 6], [96, 72, 44], 'WoodPlanks'));
  parts.push(K.cyl('Cage_Obs_StoolLeg', [0.4, 1.3, 0.4], [-13, B + 0.75, 6], [70, 50, 32], 'Wood'));
  // Tripod work light aimed at the cage
  parts.push(K.cyl('Cage_Obs_TripodLegA', [0.14, 3.2, 0.14], [-16.5, B + 1.5, 1.2], [60, 60, 64], 'Metal', { rot: [0, 0, 14] }));
  parts.push(K.cyl('Cage_Obs_TripodLegB', [0.14, 3.2, 0.14], [-16.8, B + 1.5, 1.8], [60, 60, 64], 'Metal', { rot: [0, 0, -14] }));
  parts.push(K.cyl('Cage_Obs_TripodLegC', [0.14, 3.2, 0.14], [-16.6, B + 1.5, 0.8], [60, 60, 64], 'Metal', { rot: [10, 0, 0] }));
  parts.push(K.box('Cage_Obs_LightHead', [1.2, 1, 0.8], [-16.6, B + 3.1, 1.3], [70, 60, 40], 'Metal', { rot: [0, 60, 0] }));
  parts.push(K.box('Cage_Obs_LightLens', [0.9, 0.7, 0.2], [-16.6, B + 3.1, 1.3], [255, 240, 200], 'Neon', { rot: [0, 60, 0], canCollide: false, transparency: 0.2 }));
  fx.push(K.light('Cage_Obs_LightHead', 'Cage_Obs_Light', { color: [255, 235, 190], brightness: 2.2, range: 22 }));
  // Blood drag marks from the gate
  for (let i = 0; i < 3; i++) {
    parts.push(K.box(`Cage_BloodDrag_${i}`, [0.9, 0.05, 2.8], [CX + 9.6 + i * 0.4, B + 0.06, CZ - 0.8 + i * 0.9],
      [58, 12, 12], 'Asphalt', { rot: [0, 82 + i * 4, 0], transparency: 0.35, canCollide: false }));
  }
  K.trash(parts, 'Cage_Trash', CX + 9, CZ + 5, 6, rng, B);
  // Dust inside
  parts.push(K.P('Cage_Dust_Anchor', { size: [1, 1, 1], pos: [CX, SY + 3, CZ], color: [200, 200, 200], transparency: 1, canCollide: false }));
  fx.push(K.dust('Cage_Dust_Anchor', 'Cage_Dust', { rate: 2, lifetime: [5, 9] }));

  return { parts, fx };
};

// ===========================================================================
// EXECUTE_LUAU PAYLOADS
// ===========================================================================

const LUAU_CLEANUP = `
local ws = game:GetService('Workspace')
local doomed = { ['MedievalZombieLobby'] = true, ['LobbySpawnLocation'] = true, ['Scene'] = true, ['${ROOT}'] = true }
local removed = {}
local snap = ws:GetChildren()
for i = 1, #snap do
  local inst = snap[i]
  if doomed[inst.Name] then
    removed[#removed + 1] = inst.Name
    inst:Destroy()
  end
end
return 'removed: ' .. table.concat(removed, ', ')
`;

const LUAU_STRUCTURE = `
local ws = game:GetService('Workspace')
local existing = ws:FindFirstChild('${ROOT}')
if existing then existing:Destroy() end
local model = Instance.new('Model')
model.Name = '${ROOT}'
local names = { ${FOLDERS.map((f) => `'${f}'`).join(', ')} }
local created = {}
for i = 1, #names do
  local f = Instance.new('Folder')
  f.Name = names[i]
  f.Parent = model
  created[#created + 1] = names[i]
end
model.Parent = ws

local L = game:GetService('Lighting')
L.ClockTime = 17.3
L.Brightness = 1.9
L.Ambient = Color3.fromRGB(40, 36, 40)
L.OutdoorAmbient = Color3.fromRGB(58, 50, 48)
L.ExposureCompensation = -0.12
L.EnvironmentDiffuseScale = 0.4
L.EnvironmentSpecularScale = 0.35
L.GlobalShadows = true
L.FogEnd = 520
L.FogStart = 70
L.FogColor = Color3.fromRGB(98, 76, 68)

local stale = L:GetChildren()
for i = 1, #stale do
  local ch = stale[i]
  if string.sub(ch.Name, 1, 3) == 'CZ_' then ch:Destroy() end
end

local atm = Instance.new('Atmosphere')
atm.Name = 'CZ_Atmosphere'
atm.Density = 0.42
atm.Haze = 2.6
atm.Glare = 0.25
atm.Color = Color3.fromRGB(122, 104, 96)
atm.Decay = Color3.fromRGB(76, 54, 50)
atm.Parent = L

local cc = Instance.new('ColorCorrectionEffect')
cc.Name = 'CZ_ColorGrade'
cc.TintColor = Color3.fromRGB(255, 236, 224)
cc.Contrast = 0.16
cc.Saturation = -0.22
cc.Brightness = -0.02
cc.Parent = L

local bloom = Instance.new('BloomEffect')
bloom.Name = 'CZ_Bloom'
bloom.Intensity = 0.75
bloom.Size = 28
bloom.Threshold = 1.15
bloom.Parent = L

local dof = Instance.new('DepthOfFieldEffect')
dof.Name = 'CZ_DOF'
dof.FocusDistance = 42
dof.InFocusRadius = 45
dof.NearIntensity = 0.14
dof.FarIntensity = 0.22
dof.Parent = L

local bp = ws:FindFirstChild('Baseplate')
if bp and bp:IsA('BasePart') then
  bp.Color = Color3.fromRGB(48, 48, 52)
  bp.Material = Enum.Material.Asphalt
end

return 'structure ok: ' .. table.concat(created, ', ')
`;

// Tune pass — brighten lighting one notch + fix two mis-rotated boards.
const LUAU_TUNE = `
local L = game:GetService('Lighting')
L.ClockTime = 16.6
L.Brightness = 2.25
L.ExposureCompensation = 0.05
L.FogEnd = 620
local atm = L:FindFirstChild('CZ_Atmosphere')
if atm then
  atm.Density = 0.34
  atm.Haze = 2.2
end
local M = game:GetService('Workspace'):FindFirstChild('${ROOT}')
local info = M and M:FindFirstChild('Spawn_Info_Board', true)
if info then
  info.CFrame = CFrame.new(info.Position) * CFrame.Angles(0, math.rad(56), 0)
end
local busSign = M and M:FindFirstChild('Bus_Stop_Sign', true)
if busSign then
  busSign.CFrame = CFrame.new(busSign.Position) * CFrame.Angles(0, math.rad(90), 0)
end
return 'tune ok'
`;

// Signs — all boards were rotated so their FRONT face looks at the viewer.
const SIGNS = [
  { part: 'Monument_Board', title: 'CONCIENCIA ZOMBIE', sub: 'ÚLTIMA ZONA SEGURA — CAMPAMENTO 7', tc: [255, 60, 48], sc: [235, 225, 210], font: 'Creepster', pps: 55 },
  { part: 'Checkpoint_SignA', title: 'PUESTO DE CONTROL 7', sub: 'SOLO SUPERVIVIENTES AUTORIZADOS', tc: [230, 225, 215], sc: [195, 190, 180], font: 'SpecialElite', pps: 60 },
  { part: 'Checkpoint_SignB', title: 'PELIGRO', sub: 'ZONA INFECTADA — NO PASAR', tc: [255, 70, 55], sc: [255, 130, 115], font: 'SpecialElite', pps: 60 },
  { part: 'Arsenal_Sign', title: 'ARSENAL', sub: 'EL BÚNKER — ARMAS Y MUNICIÓN', tc: [240, 205, 90], sc: [228, 218, 198], font: 'SpecialElite', pps: 60 },
  { part: 'Workshop_Sign', title: 'TALLER DE MEJORAS', sub: 'INGENIERÍA DE SUPERVIVENCIA', tc: [240, 190, 120], sc: [225, 215, 200], font: 'SpecialElite', pps: 60 },
  { part: 'Memorial_Sign', title: 'MURO DE LOS CAÍDOS', sub: 'HONOR ETERNO A NUESTROS HÉROES', tc: [235, 230, 220], sc: [198, 193, 183], font: 'Antique', pps: 65 },
  { part: 'Plaque_01', title: 'EN MEMORIA', sub: 'De los que dieron todo por la colonia', tc: [215, 210, 200], sc: [185, 180, 170], font: 'Antique', pps: 55 },
  { part: 'Plaque_02', title: 'SU NOMBRE VIVE', sub: 'En cada amanecer que logramos ver', tc: [215, 210, 200], sc: [185, 180, 170], font: 'Antique', pps: 55 },
  { part: 'Plaque_04', title: 'SOBREVIVIR ES RESISTIR', sub: null, tc: [150, 215, 160], sc: [100, 100, 100], font: 'SpecialElite', pps: 50 },
  { part: 'Plaque_05', title: 'R.I.P.', sub: 'Descansen en paz', tc: [200, 195, 185], sc: [170, 165, 155], font: 'Antique', pps: 55 },
  { part: 'Plaque_06', title: 'ESPERANZA', sub: 'La última en morir', tc: [200, 195, 185], sc: [170, 165, 155], font: 'Antique', pps: 55 },
  { part: 'Score_Board', title: 'TOP SUPERVIVIENTES', sub: '1.  ——   0 PTS\\n2.  ——   0 PTS\\n3.  ——   0 PTS', tc: [235, 220, 160], sc: [200, 200, 200], font: 'Antique', pps: 50 },
  { part: 'Cage_Sign', title: 'SUJETO #7', sub: 'NO ALIMENTAR — NO TOCAR', tc: [255, 90, 60], sc: [235, 225, 205], font: 'SpecialElite', pps: 60 },
  { part: 'Billboard_Far', title: 'CUARENTENA', sub: 'ÁREA RESTRINGIDA — RIESGO BIOLÓGICO', tc: [200, 80, 70], sc: [140, 92, 86], font: 'SpecialElite', pps: 50 },
  { part: 'Street_Sign_1', title: 'CALLE 7', sub: null, tc: [235, 240, 235], sc: [100, 100, 100], font: 'Antique', pps: 60 },
  { part: 'Street_Sign_2', title: 'AV. CENTRAL', sub: null, tc: [235, 240, 235], sc: [100, 100, 100], font: 'Antique', pps: 60 },
  { part: 'Bus_Stop_Sign', title: 'PARADA', sub: 'SIN SERVICIO', tc: [220, 215, 205], sc: [185, 180, 170], font: 'Antique', pps: 60 },
  { part: 'Spawn_Info_Board', title: 'ÚLTIMA ZONA SEGURA', sub: 'Mejora tu equipo antes de salir. Buena suerte, superviviente.', tc: [255, 200, 110], sc: [228, 220, 205], font: 'SpecialElite', pps: 55 },
];

function buildSignsLuau() {
  const lines = [];
  lines.push(`local M = game:GetService('Workspace'):FindFirstChild('${ROOT}')`);
  lines.push(`if M == nil then return 'MODEL MISSING' end`);
  lines.push(`local function findN(n) return M:FindFirstChild(n, true) end`);
  lines.push(`local function safeFont(name)`);
  lines.push(`  local ok, f = pcall(function() return Enum.Font[name] end)`);
  lines.push(`  if ok and f ~= nil then return f end`);
  lines.push(`  return Enum.Font.Antique`);
  lines.push(`end`);
  lines.push(`local function mkLabel(g, txt, posY, sizeY, col, fontName)`);
  lines.push(`  local t = Instance.new('TextLabel')`);
  lines.push(`  t.BackgroundTransparency = 1`);
  lines.push(`  t.Size = UDim2.new(1, 0, sizeY, 0)`);
  lines.push(`  t.Position = UDim2.new(0, 0, posY, 0)`);
  lines.push(`  t.Text = txt`);
  lines.push(`  t.TextScaled = true`);
  lines.push(`  t.Font = safeFont(fontName)`);
  lines.push(`  t.TextColor3 = Color3.fromRGB(col[1], col[2], col[3])`);
  lines.push(`  t.TextStrokeTransparency = 0.35`);
  lines.push(`  t.TextStrokeColor3 = Color3.fromRGB(10, 8, 8)`);
  lines.push(`  t.TextWrapped = true`);
  lines.push(`  t.Parent = g`);
  lines.push(`  return t`);
  lines.push(`end`);
  lines.push(`local function sign(partName, title, sub, tc, sc, fontName, pps)`);
  lines.push(`  local p = findN(partName)`);
  lines.push(`  if p == nil then return 'missing:' .. partName end`);
  lines.push(`  local old = p:FindFirstChild('CZ_Sign')`);
  lines.push(`  if old then old:Destroy() end`);
  lines.push(`  local g = Instance.new('SurfaceGui')`);
  lines.push(`  g.Name = 'CZ_Sign'`);
  lines.push(`  g.Face = Enum.NormalId.Front`);
  lines.push(`  g.LightInfluence = 0`);
  lines.push(`  g.MaxDistance = 900`);
  lines.push(`  g.PixelsPerStud = pps`);
  lines.push(`  g.Parent = p`);
  lines.push(`  if sub == nil then`);
  lines.push(`    mkLabel(g, title, 0.06, 0.88, tc, fontName)`);
  lines.push(`  else`);
  lines.push(`    mkLabel(g, title, 0.06, 0.58, tc, fontName)`);
  lines.push(`    mkLabel(g, sub, 0.68, 0.26, sc, 'GothamMedium')`);
  lines.push(`  end`);
  lines.push(`  return 'ok:' .. partName`);
  lines.push(`end`);
  lines.push(`local out = {}`);
  for (const s of SIGNS) {
    const sub = s.sub === null ? 'nil' : `'${s.sub}'`;
    lines.push(
      `out[#out + 1] = sign('${s.part}', '${s.title}', ${sub}, {${s.tc.join(',')}}, {${s.sc ? s.sc.join(',') : '180,180,180'}}, '${s.font}', ${s.pps})`
    );
  }
  lines.push(`return table.concat(out, ' | ')`);
  return lines.join('\n');
}

// ===========================================================================
// CAMERA + CAPTURE
// ===========================================================================

async function focusCamera(position, distance, pitch, yaw) {
  const res = await sendCommand('FOCUS_CAMERA', { position, distance, pitch, yaw }, true, 15000);
  console.log('[camera]', JSON.stringify(res?.report?.details ?? res));
}

async function triggerCapture() {
  const headers = { 'Content-Type': 'application/json' };
  const token = getBridgeToken();
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const res = await fetch(`${BRIDGE_URL}/api/capture`, { method: 'POST', headers, body: JSON.stringify({}) });
  const data = await res.json().catch(() => ({}));
  console.log('[capture]', res.status, JSON.stringify(data));
}

// ===========================================================================
// MAIN
// ===========================================================================

async function runSpawn() {
  let totalParts = 0, totalFx = 0;
  for (const folder of FOLDERS) {
    const builder = Z[folder];
    if (!builder) { console.log(`(no builder for ${folder})`); continue; }
    const { parts, fx } = builder();
    totalParts += parts.length;
    totalFx += fx.length;
    console.log(`\n=== ${folder}: ${parts.length} parts + ${fx.length} fx ===`);
    const results = await chunkedSpawn(folder, parts, fx, folder.split('_')[0]);
    for (const r of results) console.log(`  ${r.chunk}: sent=${r.sent} ok=${r.ok}`, JSON.stringify(r.result));
  }
  console.log(`\nTOTAL SENT: ${totalParts} parts, ${totalFx} fx`);
}

async function main() {
  switch (phase) {
    case 'cleanup':
      await luau(LUAU_CLEANUP, 'cleanup');
      break;
    case 'structure':
      await luau(LUAU_STRUCTURE, 'structure');
      break;
    case 'spawn':
      await runSpawn();
      break;
    case 'signs':
      await luau(buildSignsLuau(), 'signs');
      break;
    case 'tune':
      await luau(LUAU_TUNE, 'tune');
      break;
    case 'camera':
      await focusCamera([0, 4, 0], 130, -20, 0);
      break;
    case 'camera2':
      await focusCamera([0, 3, 4], 78, -15, 0);
      break;
    case 'capture':
      await triggerCapture();
      break;
    case 'all':
      console.log('--- structure ---');
      await luau(LUAU_STRUCTURE, 'structure');
      console.log('--- zones ---');
      await runSpawn();
      console.log('--- signs ---');
      await luau(buildSignsLuau(), 'signs');
      console.log('--- camera ---');
      await focusCamera([0, 4, 0], 130, -20, 0);
      break;
    case 'dry': {
      let totalParts = 0, totalFx = 0;
      for (const folder of FOLDERS) {
        const { parts, fx } = Z[folder]();
        const names = new Set();
        let dupes = 0;
        for (const p of parts) { if (names.has(p.name)) dupes++; names.add(p.name); }
        totalParts += parts.length;
        totalFx += fx.length;
        console.log(`${folder}: ${parts.length} parts, ${fx.length} fx, dupes=${dupes}`);
        if (dupes > 0) process.exitCode = 1;
      }
      console.log(`TOTAL: ${totalParts} parts, ${totalFx} fx`);
      break;
    }
    default:
      console.log('Usage: node build_lobby_zombie.mjs <cleanup|structure|spawn|signs|camera|capture|all|dry> [--upsert]');
      break;
  }
}

main().catch((err) => {
  console.error('FATAL:', err.message);
  process.exitCode = 1;
});
