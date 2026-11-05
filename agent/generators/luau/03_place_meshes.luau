-- 03_place_meshes.luau (v2 — adaptado al diseño nuevo del usuario: Campamento7_Lobby)
-- Escala 1/0.28 (= importar con Scale Unit = Meter), coloca los 12 assets,
-- limpia wrappers "Scene" y restos viejos. Front del mesh = -Z. Ground-snap #268.

local ws = game:GetService('Workspace')
local lobby = ws:FindFirstChild('Campamento7_Lobby')
if lobby == nil then return 'FATAL: no existe Campamento7_Lobby' end
local fPlaza = lobby:FindFirstChild('00_Plaza_Spawn')
local fGate = lobby:FindFirstChild('02_Checkpoint_Norte')
local fArs = lobby:FindFirstChild('03_Bunker_Arsenal')
local fTaller = lobby:FindFirstChild('04_Taller_Mejoras')
local fCage = lobby:FindFirstChild('05_Jaula_Cuarentena')
if fPlaza == nil or fGate == nil or fArs == nil or fTaller == nil or fCage == nil then
  return 'FATAL: faltan carpetas base del usuario'
end
local fCalles = lobby:FindFirstChild('08_Calles_Vehiculos')
if fCalles == nil then
  fCalles = Instance.new('Folder')
  fCalles.Name = '08_Calles_Vehiculos'
  fCalles.Parent = lobby
end

-- 1) Reunir modelos importados
local imports = {}
local snap = ws:GetChildren()
for i = 1, #snap do
  local s = snap[i]
  if s.Name == 'Scene' and s:IsA('Model') then
    local kids = s:GetChildren()
    for j = 1, #kids do
      if kids[j]:IsA('Model') then
        imports[kids[j].Name] = kids[j]
      end
    end
  end
end
local function take(id)
  local m = imports[id]
  if m == nil then error('FALTA import: ' .. id) end
  return m
end

-- 2) Helpers
local SCALE = 1.0 / 0.28
local report = {}

local function setupParts(model, fidelity)
  local p = model:GetDescendants()
  for i = 1, #p do
    local d = p[i]
    if d:IsA('BasePart') then
      d.Anchored = true
      d.CanCollide = true
      if d:IsA('MeshPart') and fidelity then
        d.CollisionFidelity = Enum.CollisionFidelity[fidelity]
      end
    end
  end
end

local function place(model, pos, yaw, pitch, roll, doSnap)
  local cf = CFrame.new(pos)
    * CFrame.Angles(0, math.rad(yaw or 0), 0)
    * CFrame.Angles(math.rad(pitch or 0), 0, math.rad(roll or 0))
  model:PivotTo(cf)
  if doSnap then
    local bc, bs = model:GetBoundingBox()
    local bottom = bc.Position.Y - bs.Y / 2
    model:PivotTo(cf * CFrame.new(0, pos.Y - bottom, 0))
  end
end

local function tint(model, col)
  local p = model:GetDescendants()
  for i = 1, #p do
    if p[i]:IsA('BasePart') then
      p[i].Color = Color3.fromRGB(col[1], col[2], col[3])
    end
  end
end

local function addSmoke(model, rate)
  local p = model:GetDescendants()
  for i = 1, #p do
    if p[i]:IsA('BasePart') then
      local em = Instance.new('ParticleEmitter')
      em.Name = 'BurnSmoke'
      em.Rate = rate
      em.Lifetime = NumberRange.new(2.5, 5)
      em.Speed = NumberRange.new(0.8, 1.6)
      em.Color = ColorSequence.new(Color3.fromRGB(48, 46, 46))
      em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 4.6) })
      em.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
      em.LightEmission = 0.1
      em.SpreadAngle = Vector2.new(0, 14)
      em.Acceleration = Vector3.new(0, 2.2, 0)
      em.Parent = p[i]
      return
    end
  end
end

local function finalize(model, name, parent, fidelity)
  model.Name = name
  setupParts(model, fidelity or 'Box')
  local first = nil
  local p = model:GetDescendants()
  for i = 1, #p do
    if p[i]:IsA('BasePart') then first = p[i] break end
  end
  model.PrimaryPart = first
  model.Parent = parent
  local bc, bs = model:GetBoundingBox()
  report[#report + 1] = string.format('%s sz=%.2f,%.2f,%.2f pos=%.1f,%.1f,%.1f',
    name, bs.X, bs.Y, bs.Z, bc.Position.X, bc.Position.Y, bc.Position.Z)
end

-- 3) Escalar los 12 originales
local car = take('mesh_car_sedan')
local bus = take('mesh_bus_wreck')
local truck = take('mesh_truck_military')
local zomb = take('mesh_zombie_Node')
local manq = take('mesh_mannequin')
local rifle = take('mesh_rifle')
local mach = take('mesh_machete')
local bat = take('mesh_bat')
local gen = take('mesh_generator')
local mg = take('mesh_mg_turret')
local tree = take('mesh_tree_dead')
local tent = take('mesh_tent_army')
local all = { car, bus, truck, zomb, manq, rifle, mach, bat, gen, mg, tree, tent }
for i = 1, #all do
  all[i]:ScaleTo(SCALE)
end

-- 4) AUTOS (6 en el campamento + 2 en la zona infectada)
local carPos = {
  { 'Auto_Quemado', fCalles, 14, 14, 15, { 42, 40, 40 }, true, 0 },
  { 'Auto_Azul', fCalles, -52, 2, -30, nil, false, 0 },
  { 'Auto_Plateado', fCalles, 16, -48, 100, nil, false, 0 },
  { 'Auto_Oxidado', fCalles, -56, -48, 80, { 64, 56, 48 }, true, 0 },
  { 'Auto_Verde', fCalles, 22, 18, 95, nil, false, 0 },
  { 'Auto_Gris', fCalles, -58, 12, -10, nil, false, 0 },
  { 'Auto_Destrozado_Frente1', fGate, -12, -68, 200, { 42, 40, 40 }, true, 4 },
  { 'Auto_Destrozado_Frente2', fGate, -23, -74, 160, { 60, 50, 46 }, true, -5 },
}
for i = 1, #carPos do
  local c = carPos[i]
  local m = (i == 1) and car or car:Clone()
  place(m, Vector3.new(c[3], 1.0, c[4]), c[5], 0, c[8], true)
  if c[6] then tint(m, c[6]) end
  if c[7] then addSmoke(m, 3.5) end
  finalize(m, c[1], c[2], 'Box')
end

-- 5) BUS + CAMION
place(bus, Vector3.new(24, 1.0, -2), 92, 0, 2, true)
finalize(bus, 'Micro_Abandonado', fCalles, 'Box')
place(truck, Vector3.new(-40, 1.0, -50), 150, 0, 0, true)
finalize(truck, 'Camion_Convoy', fGate, 'Box')

-- 6) SUJETO #7 (en la jaula de cuarentena, mirando al sur) + cadáver en el frente
place(zomb, Vector3.new(-41, 1.4, 1.0), 180, 0, 0, true)
finalize(zomb, 'Sujeto7_Infectado', fCage, 'Hull')
local corpse = zomb:Clone()
place(corpse, Vector3.new(-23, 1.0, -66), 25, -90, 0, true)
finalize(corpse, 'Frente_Cadaver', fGate, 'Hull')

-- 7) MANIQUÍES (2)
place(manq, Vector3.new(-46, 1.4, -31), 15, 0, 0, true)
finalize(manq, 'Maniqui_A', fTaller, 'Hull')
local manq2 = manq:Clone()
place(manq2, Vector3.new(-46, 1.4, -26), -20, 0, 0, true)
finalize(manq2, 'Maniqui_B', fTaller, 'Hull')

-- 8) RIFLES (8, verticales sobre el WallArmoryBoard)
local rifleX = { 7.4, 8.09, 8.77, 9.46, 10.14, 10.83, 11.51, 12.2 }
for i = 1, #rifleX do
  local r = (i == 1) and rifle or rifle:Clone()
  place(r, Vector3.new(rifleX[i], 6.9, -34.8), 0, 90, 0, false)
  finalize(r, 'Arsenal_Fusil_' .. tostring(i), fArs, 'Hull')
end

-- 9) MACHETES (3) + BATES (3)
for i = 1, 3 do
  local m = (i == 1) and mach or mach:Clone()
  place(m, Vector3.new(5.4 + (i - 1) * 0.6, 6.9, -34.8), 0, 90, 0, false)
  finalize(m, 'Arsenal_Machete_P' .. tostring(i), fArs, 'Hull')
end
for i = 1, 3 do
  local b = (i == 1) and bat or bat:Clone()
  place(b, Vector3.new(3.4 + (i - 1) * 0.5, 2.2, -31.5 + (i - 1) * 0.4), 10 - (i - 1) * 12, 75, 0, false)
  finalize(b, 'Arsenal_Bate_' .. tostring(i), fArs, 'Hull')
end

-- 10) GENERADOR + MG (sobre el BlastWall izquierdo del checkpoint)
place(gen, Vector3.new(-47, 1.4, -33), 0, 0, 0, true)
finalize(gen, 'Taller_Generador', fTaller, 'Hull')
place(mg, Vector3.new(-33, 11.0, -58), 0, 0, 0, true)
finalize(mg, 'Torre_Ametralladora', fGate, 'Hull')

-- 11) ÁRBOLES (6)
local treePos = {
  { 30, -12, 20 }, { -64, -6, -35 }, { 26, 26, 70 },
  { -60, 22, -15 }, { 2, 28, 45 }, { -6, -44, 110 },
}
for i = 1, #treePos do
  local t = (i == 1) and tree or tree:Clone()
  local tp = treePos[i]
  place(t, Vector3.new(tp[1], 1.0, tp[2]), tp[3], 0, 0, true)
  finalize(t, 'Arbol_Seco_' .. tostring(i), fCalles, 'Box')
end

-- 12) CARPAS (2, campamento en la plaza)
place(tent, Vector3.new(0, 1.0, -14), -30, 0, 0, true)
finalize(tent, 'Carpa_Militar_A', fPlaza, 'Box')
local tent2 = tent:Clone()
place(tent2, Vector3.new(-33, 1.0, -12), 150, 0, 0, true)
finalize(tent2, 'Carpa_Militar_B', fPlaza, 'Box')

-- 13) Borrar wrappers "Scene" (originales ya clonados)
local snap2 = ws:GetChildren()
for i = 1, #snap2 do
  local s = snap2[i]
  if s.Name == 'Scene' and s:IsA('Model') then
    s:Destroy()
  end
end

-- 14) Borrar restos viejos si existen (no-op en el diseño nuevo)
local killPrefixes = {
  'Car_Burnt_NS', 'Car_Blue_NS', 'Car_Silver_EW', 'Car_Rust_EW', 'Car_Green_EW', 'Car_Gray_NS',
  'Frente_CarWreck', 'Bus_Body', 'Bus_Stripe', 'Bus_Roof', 'Bus_Window', 'Bus_Door', 'Bus_Wheel',
  'Truck_', 'Cage_Subj_', 'Frente_Body',
  'Workshop_Dummy_', 'Arsenal_Rifle_', 'Arsenal_Machete_0_', 'Arsenal_Machete_1_', 'Arsenal_Machete_2_',
  'Arsenal_Bat_0', 'Arsenal_Bat_1', 'Arsenal_Bat_2',
  'Workshop_Generator', 'Tower_MG_', 'Tree_',
}
local killed = 0
local desc = lobby:GetDescendants()
for i = 1, #desc do
  local d = desc[i]
  for k = 1, #killPrefixes do
    if string.sub(d.Name, 1, #killPrefixes[k]) == killPrefixes[k] then
      d:Destroy()
      killed = killed + 1
      break
    end
  end
end

-- 15) Foco de vigilancia sobre la nueva MG
local mgPart = nil
local mgDesc = mg:GetDescendants()
for i = 1, #mgDesc do
  if mgDesc[i]:IsA('BasePart') then mgPart = mgDesc[i] break end
end
if mgPart then
  local spot = Instance.new('SpotLight')
  spot.Name = 'Tower_Spot'
  spot.Color = Color3.fromRGB(200, 215, 235)
  spot.Brightness = 2.4
  spot.Range = 44
  spot.Shadows = true
  spot.Parent = mgPart
end

return 'PLACED=' .. tostring(#report) .. ' KILLED=' .. tostring(killed) .. ' :: ' .. table.concat(report, ' // ')
