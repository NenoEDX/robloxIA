// @ts-check
// Sincroniza las dimensiones del manifiesto con las medidas reales de Blender.
import fs from 'node:fs';

const p = new URL('../../exports/lobby-zombie/assets_manifest.json', import.meta.url);
const m = JSON.parse(fs.readFileSync(p, 'utf8'));
const measured = {
  mesh_car_sedan: [6.7, 4.9, 16.5],
  mesh_bus_wreck: [9.1, 12.1, 43.2],
  mesh_truck_military: [10.0, 7.2, 24.5],
  mesh_zombie: [2.0, 6.4, 4.0],
  mesh_mannequin: [2.2, 6.3, 2.2],
  mesh_rifle: [0.2, 1.2, 3.7],
  mesh_machete: [0.2, 0.3, 2.9],
  mesh_bat: [0.3, 0.3, 3.0],
  mesh_generator: [1.6, 1.9, 2.2],
  mesh_mg_turret: [1.0, 3.7, 4.3],
  mesh_tree_dead: [10.9, 27.4, 10.8],
  mesh_tent_army: [11.7, 6.7, 14.7],
};
for (const a of m.assets) {
  if (measured[a.id]) a.dimensionesStuds = measured[a.id];
}
m.nota = `${m.nota} | dims sincronizadas a medición real de Blender (2026-09-14).`;
fs.writeFileSync(p, JSON.stringify(m, null, 2), 'utf8');
console.log('dims synced to measured values');
