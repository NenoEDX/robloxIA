-- ¿Hacia dónde mira el Sujeto #7? Partes y offsets vs centro de la jaula
local ws = game:GetService('Workspace')
local lobby = ws:FindFirstChild('Campamento7_Lobby')
local sj = lobby:FindFirstChild('Sujeto7_Infectado', true)
if sj == nil then return 'NO SUJETO' end
local out = {}
local desc = sj:GetDescendants()
for i = 1, #desc do
  local d = desc[i]
  if d:IsA('BasePart') then
    out[#out + 1] = string.format('%s ori=%.0f,%.0f,%.0f pos=%.2f,%.2f,%.2f size=%.2f,%.2f,%.2f',
      d.Name, d.Orientation.X, d.Orientation.Y, d.Orientation.Z,
      d.Position.X, d.Position.Y, d.Position.Z,
      d.Size.X, d.Size.Y, d.Size.Z)
  end
end
local bc, bs = sj:GetBoundingBox()
out[#out + 1] = string.format('bbox centro=%.2f,%.2f,%.2f tam=%.2f,%.2f,%.2f (jaula centro -41,1.4,1)', bc.Position.X, bc.Position.Y, bc.Position.Z, bs.X, bs.Y, bs.Z)
return table.concat(out, '\n')
