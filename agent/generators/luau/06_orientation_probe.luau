-- Diagnóstico: orientación real de rifles/cadáver + pivotes
local ws = game:GetService('Workspace')
local lobby = ws:FindFirstChild('Campamento7_Lobby')
local out = {}
local function probe(name)
  local m = lobby:FindFirstChild(name, true)
  if m == nil then out[#out + 1] = name .. ' NO EXISTE' return end
  out[#out + 1] = '--- ' .. name .. ' pivot=' .. tostring(m:GetPivot())
  local desc = m:GetDescendants()
  local n = 0
  for i = 1, #desc do
    local d = desc[i]
    if d:IsA('BasePart') and n < 3 then
      n = n + 1
      out[#out + 1] = string.format('  %s ori=%.0f,%.0f,%.0f pos=%.2f,%.2f,%.2f size=%.2f,%.2f,%.2f anchored=%s',
        d.Name, d.Orientation.X, d.Orientation.Y, d.Orientation.Z,
        d.Position.X, d.Position.Y, d.Position.Z,
        d.Size.X, d.Size.Y, d.Size.Z, tostring(d.Anchored))
    end
  end
end
probe('Arsenal_Fusil_1')
probe('Frente_Cadaver')
out[#out + 1] = '--- WorldPivot raw de un rifle (via modelo original ya borrado; usar primary)'
return table.concat(out, '\n')
