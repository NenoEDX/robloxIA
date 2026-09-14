// @ts-check
/**
 * run_luau.mjs — Ejecuta un archivo .luau en Roblox Studio vía EXECUTE_LUAU del bridge.
 * Uso: node agent/generators/run_luau.mjs <ruta.luau>
 */
import fs from 'node:fs';
import process from 'node:process';
import { sendCommand } from '../lib/bridge-client.mjs';

const file = process.argv[2];
if (!file) {
  console.error('Uso: node agent/generators/run_luau.mjs <ruta.luau>');
  process.exit(1);
}
const code = fs.readFileSync(file, 'utf8');
const res = await sendCommand('EXECUTE_LUAU', { code }, true, 30000);
console.log(JSON.stringify(res?.report?.details ?? res, null, 2));
