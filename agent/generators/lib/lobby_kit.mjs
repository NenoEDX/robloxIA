// @ts-check
/**
 * RAASE 2.1 — Lobby Construction Kit
 * Reusable helpers that emit BATCH_SPAWN-compatible instance descriptors.
 *
 * Descriptor fields consumed by the companion plugin:
 *   Part-like : name, className, size, position, rotation, color, material,
 *               transparency, reflectance, anchored, canCollide, shape,
 *               specialMesh{meshType,scale}, proximityPrompt{...}, billboardGui{...}
 *   Lights    : className PointLight|SpotLight|SurfaceLight, name, parentPart,
 *               color, brightness, range, shadows
 *   Particles : className ParticleEmitter, name, parentPart, rate, lifetime,
 *               speed, color, sizeCurve, transparencyCurve, lightEmission,
 *               lightInfluence, spreadAngle, acceleration
 *
 * Instance names MUST be unique within their folder (plugin skips existing).
 * All helpers accept a `b` base-height offset so props sit on raised surfaces.
 */

// ---------------------------------------------------------------------------
// Descriptor factories
// ---------------------------------------------------------------------------

export function P(name, o) {
  const d = { name, className: o.className || 'Part' };
  if (o.size) d.size = o.size;
  if (o.pos) d.position = o.pos;
  if (o.rot) d.rotation = o.rot;
  if (o.color) d.color = o.color;
  if (o.material) d.material = o.material;
  if (o.transparency !== undefined) d.transparency = o.transparency;
  if (o.reflectance !== undefined) d.reflectance = o.reflectance;
  if (o.anchored !== undefined) d.anchored = o.anchored;
  if (o.canCollide !== undefined) d.canCollide = o.canCollide;
  if (o.shape) d.shape = o.shape;
  if (o.mesh) d.specialMesh = { meshType: o.mesh.type || 'Sphere', scale: o.mesh.scale };
  if (o.prompt) {
    d.proximityPrompt = {
      actionText: o.prompt.action || 'Interactuar',
      objectText: o.prompt.object || name,
      holdDuration: o.prompt.hold !== undefined ? o.prompt.hold : 0.7,
      maxDistance: o.prompt.dist !== undefined ? o.prompt.dist : 12,
    };
  }
  if (o.billboard) {
    d.billboardGui = {
      text: o.billboard.text || '',
      sizeX: o.billboard.sizeX || 8,
      sizeY: o.billboard.sizeY || 2.4,
      offsetY: o.billboard.offsetY !== undefined ? o.billboard.offsetY : 3,
      textColor: o.billboard.color || [255, 235, 160],
      alwaysOnTop: o.billboard.alwaysOnTop !== false,
    };
  }
  return d;
}

export const box = (name, size, pos, color, material = 'Concrete', extra = {}) =>
  P(name, { size, pos, color, material, ...extra });

export const cyl = (name, size, pos, color, material = 'Metal', extra = {}) =>
  P(name, { size, pos, color, material, shape: 'Cylinder', ...extra });

export const ball = (name, size, pos, color, material = 'Metal', extra = {}) =>
  P(name, { size, pos, color, material, shape: 'Ball', ...extra });

export const wedge = (name, size, pos, color, material = 'Concrete', extra = {}) =>
  P(name, { className: 'WedgePart', size, pos, color, material, ...extra });

export const light = (parentPart, name, o = {}) => ({
  className: o.className || 'PointLight',
  name,
  parentPart,
  color: o.color || [255, 150, 60],
  brightness: o.brightness !== undefined ? o.brightness : 2,
  range: o.range !== undefined ? o.range : 22,
  shadows: o.shadows !== false,
});

export const particles = (parentPart, name, o = {}) => ({
  className: 'ParticleEmitter',
  name,
  parentPart,
  rate: o.rate !== undefined ? o.rate : 6,
  lifetime: o.lifetime || [1.6, 3.2],
  speed: o.speed || [1.4, 2.6],
  color: o.color || [70, 70, 70],
  sizeCurve: o.sizeCurve || [[0, 1.2], [1, 4.2]],
  transparencyCurve: o.transparencyCurve || [[0, 0.55], [1, 1]],
  lightEmission: o.lightEmission !== undefined ? o.lightEmission : 0.1,
  lightInfluence: o.lightInfluence !== undefined ? o.lightInfluence : 1,
  spreadAngle: o.spreadAngle || [0, 12],
  acceleration: o.acceleration || [0, 2.2, 0],
});

export const smoke = (parentPart, name = 'Smoke', o = {}) =>
  particles(parentPart, name, {
    rate: 7, lifetime: [1.8, 3.6], speed: [1.2, 2.2], color: [62, 60, 58],
    sizeCurve: [[0, 1.4], [0.5, 3.6], [1, 5.5]], transparencyCurve: [[0, 0.5], [1, 1]],
    spreadAngle: [0, 14], acceleration: [0, 2.6, 0], ...o,
  });

export const embers = (parentPart, name = 'Embers', o = {}) =>
  particles(parentPart, name, {
    rate: 12, lifetime: [0.9, 1.8], speed: [3.2, 5.2], color: [255, 140, 40],
    sizeCurve: [[0, 0.32], [1, 0.06]], transparencyCurve: [[0, 0.15], [1, 0.6]],
    lightEmission: 0.85, lightInfluence: 0, spreadAngle: [4, 16],
    acceleration: [0, 4.5, 0], ...o,
  });

export const redMist = (parentPart, name = 'RedMist', o = {}) =>
  particles(parentPart, name, {
    rate: 9, lifetime: [3.5, 6], speed: [0.6, 1.3], color: [130, 34, 30],
    sizeCurve: [[0, 6], [1, 15]], transparencyCurve: [[0, 0.72], [0.5, 0.6], [1, 0.95]],
    lightEmission: 0, lightInfluence: 1, spreadAngle: [0, 40],
    acceleration: [0, 0.5, 0], ...o,
  });

export const dust = (parentPart, name = 'Dust', o = {}) =>
  particles(parentPart, name, {
    rate: 3, lifetime: [6, 10], speed: [0.2, 0.5], color: [190, 175, 160],
    sizeCurve: [[0, 0.6], [1, 1.6]], transparencyCurve: [[0, 0.85], [0.5, 0.7], [1, 0.95]],
    lightEmission: 0, lightInfluence: 1, spreadAngle: [0, 180],
    acceleration: [0.2, 0.1, 0.1], ...o,
  });

// ---------------------------------------------------------------------------
// Seeded RNG — deterministic layouts across re-runs
// ---------------------------------------------------------------------------

export function makeRng(seed) {
  let a = seed >>> 0;
  return function rng() {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export const range = (rng, lo, hi) => lo + rng() * (hi - lo);
export const rangeInt = (rng, lo, hi) => Math.floor(range(rng, lo, hi + 1));
export const pick = (rng, arr) => arr[Math.floor(rng() * arr.length)];

/** Rotate a local [x, z] offset around Y by deg degrees (matches Roblox yaw). */
export function rot2(lx, lz, deg) {
  const r = (deg * Math.PI) / 180;
  const c = Math.cos(r), s = Math.sin(r);
  return [lx * c + lz * s, -lx * s + lz * c];
}

// ---------------------------------------------------------------------------
// Composite props — every helper takes `b` (base height) where relevant
// ---------------------------------------------------------------------------

/** Sandbag wall/line between two points. */
export function sandbagLine(out, prefix, x1, z1, x2, z2, rows = 2, rng = Math.random, b = 0) {
  const dx = x2 - x1, dz = z2 - z1;
  const len = Math.hypot(dx, dz);
  const ang = (Math.atan2(dx, dz) * 180) / Math.PI;
  const step = 2.05;
  const count = Math.max(1, Math.round(len / step));
  for (let row = 0; row < rows; row++) {
    const rowCount = row === 0 ? count : Math.max(1, count - 1);
    const off = row === 0 ? 0 : step / 2;
    for (let i = 0; i < rowCount; i++) {
      const t = (i + 0.5) / count;
      const px = x1 + dx * t + Math.sin((ang * Math.PI) / 180) * off;
      const pz = z1 + dz * t + Math.cos((ang * Math.PI) / 180) * off;
      const jitter = (rng() - 0.5) * 0.16;
      out.push(
        box(`${prefix}_Bag_R${row}_${i}`, [2.15, 0.92, 1.12],
          [px, b + 0.55 + row * 0.88, pz], [128 + rangeInt(rng, -10, 8), 116, 82], 'Fabric',
          { rot: [0, ang + jitter, (rng() - 0.5) * 3], canCollide: true })
      );
    }
  }
}

/** Sandbag ring (circle of bags). */
export function sandbagRing(out, prefix, cx, cz, radius, rng = Math.random, bagCount = 0, b = 0) {
  const count = bagCount || Math.max(6, Math.round((2 * Math.PI * radius) / 2.1));
  for (let i = 0; i < count; i++) {
    const a = (i / count) * Math.PI * 2;
    const px = cx + Math.sin(a) * radius;
    const pz = cz + Math.cos(a) * radius;
    const face = (a * 180) / Math.PI;
    const jitter = (rng() - 0.5) * 0.2;
    out.push(
      box(`${prefix}_Bag_${i}`, [2.15, 0.92, 1.12], [px, b + 0.55, pz],
        [130 + rangeInt(rng, -12, 8), 116, 82], 'Fabric', { rot: [0, face + 90 + jitter, 0] })
    );
  }
}

/** Barrels (optional burning). */
export function makeBarrel(out, fx, name, x, z, o = {}) {
  const y = o.y !== undefined ? o.y : 0;
  const col = o.color || [58, 52, 48];
  out.push(cyl(`${name}_Body`, [3, 3.4, 3], [x, y + 1.7, z], col, 'CorrodedMetal'));
  out.push(cyl(`${name}_RimLow`, [3.18, 0.22, 3.18], [x, y + 0.75, z], [44, 40, 38], 'CorrodedMetal'));
  out.push(cyl(`${name}_RimHigh`, [3.18, 0.22, 3.18], [x, y + 2.75, z], [44, 40, 38], 'CorrodedMetal'));
  if (o.fire) {
    out.push(cyl(`${name}_Glow`, [2.5, 2.9, 2.5], [x, y + 2.1, z], [255, 110, 25], 'Neon',
      { canCollide: false, transparency: 0.12 }));
    out.push(ball(`${name}_FlameCore`, [1.7, 1.7, 1.7], [x, y + 3.9, z], [255, 150, 45], 'Neon',
      { canCollide: false, transparency: 0.1 }));
    out.push(ball(`${name}_FlameTop`, [1.05, 1.05, 1.05], [x, y + 4.8, z], [255, 200, 80], 'Neon',
      { canCollide: false, transparency: 0.25 }));
    fx.push(light(`${name}_Body`, `${name}_Light`, { color: [255, 150, 55], brightness: 2.6, range: 30 }));
    fx.push(smoke(`${name}_Body`, `${name}_Smoke`, { rate: 8, color: [70, 66, 62] }));
    fx.push(embers(`${name}_Body`, `${name}_Embers`));
  }
}

/** Crate. `y` is the base height. */
export function crate(out, name, x, y, z, s = 2.4, rotY = 0, o = {}) {
  out.push(box(`${name}_Body`, [s, s, s], [x, y + s / 2, z], o.color || [115, 82, 50],
    o.material || 'WoodPlanks', { rot: [0, rotY, 0] }));
  if (!o.plain) {
    out.push(box(`${name}_RibA`, [s + 0.08, 0.16, s * 0.22], [x, y + s * 0.78, z], [86, 60, 36], 'Wood',
      { rot: [0, rotY, 0], canCollide: false }));
    out.push(box(`${name}_RibB`, [s + 0.08, 0.16, s * 0.22], [x, y + s * 0.24, z], [86, 60, 36], 'Wood',
      { rot: [0, rotY, 0], canCollide: false }));
  }
}

/** Tent (two sloped wedges + back + bed). */
export function tent(out, name, x, z, rotY = 0, color = [62, 72, 52], b = 0) {
  const [dxA, dzA] = rot2(-1.6, 0, rotY);
  const [dxB, dzB] = rot2(1.6, 0, rotY);
  out.push(wedge(`${name}_SlopeL`, [3.6, 4.6, 7.2], [x + dxA, b + 2.3, z + dzA], color, 'Fabric',
    { rot: [0, rotY + 180, 0] }));
  out.push(wedge(`${name}_SlopeR`, [3.6, 4.6, 7.2], [x + dxB, b + 2.3, z + dzB], color, 'Fabric',
    { rot: [0, rotY, 180] }));
  out.push(wedge(`${name}_Back`, [4.4, 4.4, 1.2], [x, b + 2.2, z + rot2(0, 3.4, rotY)[1]], color, 'Fabric',
    { rot: [0, rotY, 0] }));
  out.push(box(`${name}_Floor`, [4.6, 0.12, 6.8], [x, b + 0.1, z], [70, 64, 54], 'Fabric',
    { rot: [0, rotY, 0], canCollide: false }));
  out.push(P(`${name}_Bed`, { size: [2.6, 0.5, 5], pos: [x, b + 0.35, z], rot: [0, rotY, 0],
    color: [95, 88, 70], material: 'Fabric', canCollide: false }));
  out.push(cyl(`${name}_PoleF`, [0.18, 4.4, 0.18], [x + rot2(2.1, 3.3, rotY)[0], b + 2.2, z + rot2(2.1, 3.3, rotY)[1]],
    [70, 55, 38], 'Wood'));
}

/** Dead tree. */
export function deadTree(out, name, x, z, rng = Math.random, b = 0) {
  const h = range(rng, 5.5, 8.5);
  out.push(cyl(`${name}_Trunk`, [1.15, h, 1.15], [x, b + h / 2, z], [58, 47, 36], 'Wood'));
  const branches = rangeInt(rng, 4, 6);
  for (let i = 0; i < branches; i++) {
    const a = range(rng, 0, 360);
    const tilt = range(rng, 35, 60);
    const bl = range(rng, 2, 3.4);
    const [ox, oz] = rot2(Math.sin((a * Math.PI) / 180), Math.cos((a * Math.PI) / 180), 0);
    out.push(cyl(`${name}_Branch_${i}`, [0.42, bl, 0.42],
      [x + ox * (bl / 2.4), b + h - range(rng, 0.2, 1.6), z + oz * (bl / 2.4)],
      [52, 42, 32], 'Wood',
      { rot: [tilt * Math.cos((a * Math.PI) / 180), a, tilt * Math.sin((a * Math.PI) / 180)] }));
  }
}

/** Street lamp (working or broken). Lamp arm points toward +X before rotY. */
export function lampPost(out, fx, name, x, z, o = {}) {
  const b = o.b !== undefined ? o.b : 0;
  const rotY = o.rotY || 0;
  const broken = !!o.broken;
  const tilt = broken ? (o.tiltDir || 1) * 9 : 0;
  out.push(cyl(`${name}_Pole`, [0.62, 11, 0.62], [x, b + 5.5, z], [52, 52, 56], 'Metal', { rot: [0, rotY, tilt] }));
  const armY = broken ? 10.6 : 11;
  const [ax, az] = rot2(2.2, 0, rotY);
  out.push(box(`${name}_Arm`, [2.6, 0.28, 0.32], [x + rot2(1.1, 0, rotY)[0], b + armY - 0.2, z + rot2(1.1, 0, rotY)[1]],
    [52, 52, 56], 'Metal', { rot: [0, rotY, broken ? tilt * 2.2 : 0] }));
  out.push(box(`${name}_Head`, [1.3, 0.36, 0.62], [x + ax, b + armY - (broken ? 0.9 : 0.32), z + az], [40, 40, 44], 'Metal',
    { rot: [0, rotY, broken ? tilt * 3.4 : 0] }));
  if (!broken) {
    out.push(box(`${name}_Lens`, [0.95, 0.14, 0.4], [x + ax, b + armY - 0.52, z + az], [255, 238, 200], 'Neon',
      { canCollide: false, transparency: 0.25, rot: [0, rotY, 0] }));
    fx.push(light(`${name}_Head`, `${name}_Light`, { color: [188, 202, 218], brightness: 1.3, range: 20, shadows: false }));
  }
}

/** Wrecked car. rotY degrees. `o.y` is the wheel-contact base height. */
export function makeCar(out, fx, name, x, z, rotY, color, o = {}) {
  const y = o.y !== undefined ? o.y : 0;
  const burned = !!o.burned;
  const tilt = o.tilt || 0;
  const at = (lx, ly, lz, size, col, mat, extra = {}) => {
    const [wx, wz] = rot2(lx, lz, rotY);
    out.push(box(`${name}_${extra.tag}`, size, [x + wx, y + ly, z + wz], col, mat,
      { rot: [extra.rx || 0, rotY + (extra.ry || 0), extra.rz !== undefined ? extra.rz : tilt], ...extra.opts }));
  };
  const bodyCol = burned ? [42, 40, 40] : color;
  const bodyMat = burned ? 'CorrodedMetal' : 'Metal';
  at(0, 1.9, 0, [4.6, 1.7, 10], bodyCol, bodyMat, { tag: 'Chassis' });
  at(0, 3.0, 2.6, [4.4, 0.8, 4.2], bodyCol, bodyMat, { tag: 'Hood', rx: o.hoodOpen ? -22 : 0 });
  at(0, 4.45, -0.9, [4.3, 1.9, 4.6], bodyCol, bodyMat, { tag: 'Cabin' });
  at(0, 4.35, 2.35, [4.0, 1.2, 0.36], burned ? [28, 28, 28] : [120, 150, 160], 'Glass',
    { tag: 'Windshield', opts: { transparency: burned ? 0.75 : 0.45, canCollide: false } });
  at(0, 4.35, -3.15, [4.0, 1.2, 0.36], burned ? [28, 28, 28] : [120, 150, 160], 'Glass',
    { tag: 'RearGlass', opts: { transparency: burned ? 0.75 : 0.45, canCollide: false } });
  at(2.32, 4.35, -0.9, [0.3, 1.2, 3.6], burned ? [26, 26, 26] : [110, 140, 150], 'Glass',
    { tag: 'WindowR', opts: { transparency: burned ? 0.8 : 0.5, canCollide: false } });
  at(-2.32, 4.35, -0.9, [0.3, 1.2, 3.6], burned ? [26, 26, 26] : [110, 140, 150], 'Glass',
    { tag: 'WindowL', opts: { transparency: burned ? 0.8 : 0.5, canCollide: false } });
  at(0, 1.0, 5.15, [4.2, 0.5, 0.3], [70, 66, 60], 'Metal', { tag: 'BumperF' });
  at(0, 1.0, -5.15, [4.2, 0.5, 0.3], [70, 66, 60], 'Metal', { tag: 'BumperR' });
  const wheels = [[2.55, 3.1], [-2.55, 3.1], [2.55, -3.1], [-2.55, -3.1]];
  wheels.forEach(([wx, wz], i) => {
    const [ax, az] = rot2(wx, wz, rotY);
    const flat = burned && i % 2 === 0;
    out.push(cyl(`${name}_Wheel_${i}`, [2.05, 0.95, 2.05],
      [x + ax, y + 1.05 - (flat ? 0.14 : 0), z + az], [30, 30, 32], 'Metal',
      { rot: [0, rotY, flat ? 8 : 0] }));
    out.push(cyl(`${name}_Hub_${i}`, [1.1, 1.02, 1.1], [x + ax, y + 1.05 - (flat ? 0.14 : 0), z + az],
      burned ? [50, 48, 46] : [120, 122, 126], 'Metal', { rot: [0, rotY, flat ? 8 : 0], canCollide: false }));
  });
  if (burned && fx) {
    fx.push(smoke(`${name}_Chassis`, `${name}_Smoke`, { rate: 3.5, lifetime: [2.5, 5], speed: [0.8, 1.6],
      color: [48, 46, 46], sizeCurve: [[0, 1.2], [1, 4.6]] }));
  }
}

/** Bent rebar cluster. */
export function rebar(out, name, x, y, z, count, rng = Math.random) {
  for (let i = 0; i < count; i++) {
    const a = range(rng, 0, 360);
    const tilt = range(rng, 20, 55);
    const h = range(rng, 2.5, 5.5);
    out.push(cyl(`${name}_Bar_${i}`, [0.16, h, 0.16], [x + range(rng, -0.8, 0.8), y + h / 2 - 0.4, z + range(rng, -0.8, 0.8)],
      [75, 60, 50], 'CorrodedMetal',
      { rot: [tilt * Math.cos((a * Math.PI) / 180), a, tilt * Math.sin((a * Math.PI) / 180)] }));
  }
}

/** Rubble mound. */
export function rubble(out, name, cx, cz, r, count, rng = Math.random, b = 0, colors = null) {
  const cols = colors || [[95, 92, 86], [84, 80, 74], [72, 68, 64]];
  for (let i = 0; i < count; i++) {
    const a = range(rng, 0, 360);
    const d = range(rng, 0, r);
    const [ox, oz] = rot2(Math.sin((a * Math.PI) / 180) * d, Math.cos((a * Math.PI) / 180) * d, 0);
    const s = range(rng, 0.7, 2.6);
    const isWedge = rng() > 0.72;
    out.push(isWedge
      ? wedge(`${name}_Chunk_${i}`, [s, s * 0.8, s * 1.2], [cx + ox, b + 0.3 + s * 0.3, cz + oz], pick(rng, cols), 'Concrete',
          { rot: [range(rng, -18, 18), range(rng, 0, 360), range(rng, -18, 18)], canCollide: false })
      : box(`${name}_Chunk_${i}`, [s, s * 0.7, s * 1.1], [cx + ox, b + 0.28 + s * 0.25, cz + oz], pick(rng, cols), 'Concrete',
          { rot: [range(rng, -14, 14), range(rng, 0, 360), range(rng, -14, 14)], canCollide: false }));
  }
}

/** HESCO barrier. */
export function hesco(out, name, x, z, rotY = 0, len = 10, h = 2.5, b = 0) {
  out.push(box(`${name}_Body`, [len, h, 2.5], [x, b + h / 2, z], [138, 124, 88], 'Fabric', { rot: [0, rotY, 0] }));
  out.push(box(`${name}_Top`, [len + 0.3, 0.24, 2.7], [x, b + h + 0.08, z], [120, 106, 74], 'Fabric',
    { rot: [0, rotY, 0], canCollide: false }));
}

/** Small trash scatter. */
export function trash(out, name, cx, cz, count, rng = Math.random, b = 0) {
  const stuff = [[190, 186, 176], [140, 120, 90], [110, 108, 104], [160, 150, 120]];
  for (let i = 0; i < count; i++) {
    const [ox, oz] = [range(rng, -2.4, 2.4), range(rng, -2.4, 2.4)];
    const s = range(rng, 0.5, 1.2);
    out.push(box(`${name}_Bit_${i}`, [s, 0.16, s * range(rng, 0.7, 1.4)], [cx + ox, b + 0.26, cz + oz],
      pick(rng, stuff), 'Plastic',
      { rot: [range(rng, -6, 6), range(rng, 0, 360), range(rng, -6, 6)], canCollide: false }));
  }
}

/** Hazard stripe ring (alternating yellow/black flats). */
export function hazardRing(out, name, cx, cy, cz, radius, count = 12) {
  for (let i = 0; i < count; i++) {
    const a = (i / count) * Math.PI * 2;
    const px = cx + Math.sin(a) * radius;
    const pz = cz + Math.cos(a) * radius;
    out.push(box(`${name}_Stripe_${i}`, [2.3, 0.1, 0.9], [px, cy, pz],
      i % 2 === 0 ? [235, 195, 40] : [32, 32, 34], 'SmoothPlastic',
      { rot: [0, (a * 180) / Math.PI + 90, 0], canCollide: false }));
  }
}
