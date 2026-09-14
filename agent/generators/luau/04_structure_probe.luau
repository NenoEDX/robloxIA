-- Estructura interna de Campamento7_Lobby (2 niveles) + localización de geometría vieja
local ws = game:GetService('Workspace')
local lobby = ws:FindFirstChild('Campamento7_Lobby')
if lobby == nil then return 'NO LOBBY' end
local out = {}
local folders = lobby:GetChildren()
for i = 1, #folders do
  local f = folders[i]
  out[#out + 1] = '== ' .. f.Name .. ' [' .. f.ClassName .. '] (' .. tostring(#f:GetChildren()) .. ' hijos) =='
  local kids = f:GetChildren()
  for j = 1, math.min(#kids, 18) do
    local k = kids[j]
    out[#out + 1] = '  - ' .. k.Name .. ' [' .. k.ClassName .. '] (' .. tostring(#k:GetChildren()) .. ')'
  end
end
-- localizar restos de cubos viejos
local probes = { 'Car_Burnt_NS_Chassis', 'Car_Blue_NS_Chassis', 'Bus_Body', 'Truck_Cab', 'Cage_Subj_Torso', 'Workshop_Dummy_A_Torso', 'Arsenal_Rifle_N_0_Barrel', 'Workshop_Generator', 'Tower_MG_Barrel', 'Frente_Body' }
for p = 1, #probes do
  local found = lobby:FindFirstChild(probes[p], true)
  if found then
    out[#out + 1] = 'PROBE ' .. probes[p] .. ' -> parent=' .. found.Parent.Name
  else
    out[#out + 1] = 'PROBE ' .. probes[p] .. ' -> NO ENCONTRADO'
  end
end
return table.concat(out, '\n')
