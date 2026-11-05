-- 11_place_meshes_v3.luau — Coloca los 12 meshes (desde Temp_MeshAssets) en el layout
-- del Campamento 7 reconstruido, elimina la geometría de cubos reemplazada y el temp.
-- Front del mesh = +Z (verificado empíricamente). Ground-snap por esquinas (mundo real).

local ws = game:GetService('Workspace')
local lobby = ws:FindFirstChild('Campamento7_Lobby')
local temp = ws:FindFirstChild('Temp_MeshAssets')
if lobby == nil or temp == nil then return 'FATAL: falta lobby o temp' end
local fPlaza = lobby:FindFirstChild('01_Central_Plaza')
local fGate = lobby:FindFirstChild('02_Checkpoint_Norte')
local fArs = lobby:FindFirstChild('03_Arsenal_Bunker')
local fTaller = lobby:FindFirstChild('04_Taller_Mejoras')
local fUrb = lobby:FindFirstChild('07_Detalle_Urbano')
local fCage = lobby:FindFirstChild('08_Jaula_Sujeto7')
if fPlaza == nil or fGate == nil or fArs == nil or fTaller == nil or fUrb == nil or fCage == nil then
  return 'FATAL: faltan carpetas'
end

local function take(id)
  local m = temp:FindFirstChild(id)
  if m == nil then error('FALTA temp: ' .. id) end
  return m
end

local report = {}

local function worldBottomOf(model)
  local minY = math.huge
  local desc = model:GetDescendants()
  for i = 1, #desc do
    local p = desc[i]
    if p:IsA('BasePart') then
      local hs = p.Size / 2
      for sx = -1, 1, 2 do
        for sy = -1, 1, 2 do
          for sz = -1, 1, 2 do
            local w = p.CFrame:PointToWorldSpace(Vector3.new(hs.X * sx, hs.Y * sy, hs.Z * sz))
            if w.Y < minY then minY = w.Y end
          end
        end
      end
    end
  end
  return minY
end

local function place(model, pos, yaw, pitch, roll, doSnap)
  local cf = CFrame.new(pos)
    * CFrame.Angles(0, math.rad(yaw or 0), 0)
    * CFrame.Angles(math.rad(pitch or 0), 0, math.rad(roll or 0))
  model:PivotTo(cf)
  if doSnap then
    local b = worldBottomOf(model)
    model:PivotTo(cf * CFrame.new(0, pos.Y - b, 0))
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
  local p = model:GetDescendants()
  local first = nil
  for i = 1, #p do
    local d = p[i]
    if d:IsA('BasePart') then
      d.Anchored = true
      d.CanCollide = true
      if d:IsA('MeshPart') and fidelity then
        d.CollisionFidelity = Enum.CollisionFidelity[fidelity]
      end
      if first == nil then first = d end
    end
  end
  model.PrimaryPart = first
  model.Parent = parent
end

-- Fuentes
local car = take('Auto_Quemado')
local bus = take('Micro_Abandonado')
local truck = take('Camion_Convoy')
local zomb = take('Sujeto7_Infectado')
local manq = take('Maniqui_A')
local rifle = take('Arsenal_Fusil_1')
local mach = take('Arsenal_Machete_P1')
local bat = take('Arsenal_Bate_1')
local gen = take('Taller_Generador')
local mg = take('Torre_Ametralladora')
local tree = take('Arbol_Seco_1')
local tent = take('Carpa_Militar_A')

-- AUTOS (8)
local carPos = {
  { 'Auto_Quemado', fUrb, 9.5, -34, 6, { 42, 40, 40 }, true, 0, 0.2 },
  { 'Auto_Azul', fUrb, -8.5, -47, -24, nil, false, 0, 0.2 },
  { 'Auto_Plateado', fUrb, 52, 8.5, 97, nil, false, 0, 0.2 },
  { 'Auto_Oxidado', fUrb, -44, -8.5, 84, { 64, 56, 48 }, true, 0, 0.2 },
  { 'Auto_Verde', fUrb, 24, -9, 88, nil, false, 0, 0.2 },
  { 'Auto_Gris', fUrb, -6, 58, 183, nil, false, 0, 0.2 },
  { 'Auto_Destrozado_Frente1', fGate, 7, -94, 200, { 42, 40, 40 }, true, 4, 0.2 },
  { 'Auto_Destrozado_Frente2', fGate, -9, -102, 160, { 60, 50, 46 }, true, -5, 0.2 },
}
for i = 1, #carPos do
  local c = carPos[i]
  local m = (i == 1) and car or car:Clone()
  place(m, Vector3.new(c[3], c[9], c[4]), c[5], 0, c[8], true)
  if c[6] then tint(m, c[6]) end
  if c[7] then addSmoke(m, 3.5) end
  finalize(m, c[1], c[2], 'Box')
  report[#report + 1] = c[1]
end

-- BUS + CAMION
place(bus, Vector3.new(7, 0.2, 62), 354, 0, 2, true)
finalize(bus, 'Micro_Abandonado', fUrb, 'Box')
report[#report + 1] = 'Micro_Abandonado'
place(truck, Vector3.new(-11, 0.35, -54), -18, 0, 0, true)
finalize(truck, 'Camion_Convoy', fGate, 'Box')
report[#report + 1] = 'Camion_Convoy'

-- SUJETO #7 (mira al este, hacia la plaza) + CADÁVER (boca abajo en el frente)
place(zomb, Vector3.new(-25, 0.95, 8), 90, 0, 0, true)
finalize(zomb, 'Sujeto7_Infectado', fCage, 'Hull')
report[#report + 1] = 'Sujeto7_Infectado'
local corpse = zomb:Clone()
place(corpse, Vector3.new(3, 0.2, -88), 25, 90, 0, true)
finalize(corpse, 'Frente_Cadaver', fGate, 'Hull')
report[#report + 1] = 'Frente_Cadaver'

-- MANIQUÍES (2)
place(manq, Vector3.new(-76, 0.4, -2), 15, 0, 0, true)
finalize(manq, 'Maniqui_A', fTaller, 'Hull')
report[#report + 1] = 'Maniqui_A'
local manq2 = manq:Clone()
place(manq2, Vector3.new(-76, 0.4, 3), -20, 0, 0, true)
finalize(manq2, 'Maniqui_B', fTaller, 'Hull')
report[#report + 1] = 'Maniqui_B'

-- RIFLES (8)
local rifleZ = { -14, -12, -10, -8, 6, 8, 10, 12 }
for i = 1, #rifleZ do
  local r = (i == 1) and rifle or rifle:Clone()
  place(r, Vector3.new(90.0, 4.8, rifleZ[i]), 0, 90, 0, false)
  finalize(r, 'Arsenal_Fusil_' .. tostring(i), fArs, 'Hull')
end
report[#report + 1] = 'Arsenal_Fusil x8'

-- MACHETES (3) + BATES (3)
for i = 1, 3 do
  local m = (i == 1) and mach or mach:Clone()
  place(m, Vector3.new(55.85, 6.0, -18 + (i - 1) * 1.4), 0, 90, 0, false)
  finalize(m, 'Arsenal_Machete_P' .. tostring(i), fArs, 'Hull')
end
report[#report + 1] = 'Arsenal_Machete x3'
for i = 1, 3 do
  local b = (i == 1) and bat or bat:Clone()
  place(b, Vector3.new(84 + (i - 2) * 0.55, 4.1, 16 + (i - 2) * 0.35), (i - 2) * 22, 75, 0, false)
  finalize(b, 'Arsenal_Bate_' .. tostring(i), fArs, 'Hull')
end
report[#report + 1] = 'Arsenal_Bate x3'

-- GENERADOR + MG (torre del checkpoint)
place(gen, Vector3.new(-59, 0.4, 18), 0, 0, 0, true)
finalize(gen, 'Taller_Generador', fTaller, 'Hull')
report[#report + 1] = 'Taller_Generador'
place(mg, Vector3.new(25, 14.65, -69), 0, 0, 0, true)
finalize(mg, 'Torre_Ametralladora', fGate, 'Hull')
report[#report + 1] = 'Torre_Ametralladora'

-- ÁRBOLES (6)
local treePos = {
  { 48, -30, 20 }, { -52, -34, -35 }, { 52, 34, 70 },
  { -48, 38, -15 }, { 30, -46, 45 }, { -34, 46, 110 },
}
for i = 1, #treePos do
  local t = (i == 1) and tree or tree:Clone()
  local tp = treePos[i]
  place(t, Vector3.new(tp[1], 0.18, tp[2]), tp[3], 0, 0, true)
  finalize(t, 'Arbol_Seco_' .. tostring(i), fUrb, 'Box')
end
report[#report + 1] = 'Arbol_Seco x6'

-- CARPAS (2)
place(tent, Vector3.new(17, 0.45, 15), -22, 0, 0, true)
finalize(tent, 'Carpa_Militar_A', fPlaza, 'Box')
report[#report + 1] = 'Carpa_Militar_A'
local tent2 = tent:Clone()
place(tent2, Vector3.new(23, 0.45, 21), 155, 0, 0, true)
finalize(tent2, 'Carpa_Militar_B', fPlaza, 'Box')
report[#report + 1] = 'Carpa_Militar_B'

-- Borrar geometría de cubos reemplazada
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

-- Foco de vigilancia (si el modelo no trae uno)
local hasSpot = false
local mgDesc = mg:GetDescendants()
for i = 1, #mgDesc do
  if mgDesc[i]:IsA('SpotLight') then hasSpot = true break end
end
if not hasSpot then
  local first = nil
  for i = 1, #mgDesc do
    if mgDesc[i]:IsA('BasePart') then first = mgDesc[i] break end
  end
  if first then
    local spot = Instance.new('SpotLight')
    spot.Name = 'Tower_Spot'
    spot.Color = Color3.fromRGB(200, 215, 235)
    spot.Brightness = 2.4
    spot.Range = 44
    spot.Shadows = true
    spot.Parent = first
  end
end

-- Limpiar temp
temp:Destroy()

return 'PLACED=' .. tostring(#report) .. ' KILLED=' .. tostring(killed) .. ' :: ' .. table.concat(report, ', ')
