-- 10_extract_and_reset.luau — Extrae los 12 meshes originales a Temp_MeshAssets,
-- limpia terreno del área del campamento y elimina el lobby de prueba de Antigravity.
local ws = game:GetService('Workspace')
local lobby = ws:FindFirstChild('Campamento7_Lobby')
if lobby == nil then return 'NO LOBBY' end

local keepNames = {
  'Auto_Quemado', 'Micro_Abandonado', 'Camion_Convoy', 'Sujeto7_Infectado', 'Maniqui_A',
  'Arsenal_Fusil_1', 'Arsenal_Machete_P1', 'Arsenal_Bate_1', 'Taller_Generador',
  'Torre_Ametralladora', 'Arbol_Seco_1', 'Carpa_Militar_A',
}
local temp = Instance.new('Folder')
temp.Name = 'Temp_MeshAssets'
temp.Parent = ws
local moved = {}
for i = 1, #keepNames do
  local m = lobby:FindFirstChild(keepNames[i], true)
  if m then
    m.Parent = temp
    moved[#moved + 1] = keepNames[i]
  else
    moved[#moved + 1] = 'FALTA:' .. keepNames[i]
  end
end

-- Limpiar terreno voxel del footprint del campamento (no-op si no hay terreno)
local terrain = ws:FindFirstChildOfClass('Terrain')
local tCleared = 'sin terrain'
if terrain then
  local ok = pcall(function()
    terrain:FillBlock(CFrame.new(0, 18, 0), Vector3.new(320, 36, 320), Enum.Material.Air)
  end)
  tCleared = ok and 'terreno limpiado (-160..160, y0..36)' or 'fallo al limpiar terreno'
end

-- Eliminar el lobby de prueba completo (Antigravity + instancias viejas de meshes)
lobby:Destroy()

local report = {}
for i = 1, #moved do report[#report + 1] = moved[i] end
return 'EXTRACTED(' .. tostring(#moved) .. '): ' .. table.concat(report, ', ') .. ' || ' .. tCleared .. ' || lobby borrado'
