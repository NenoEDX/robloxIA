-- Inventario profundo: todos los BaseParts dentro de cada modelo "Scene" importado
local ws = game:GetService('Workspace')
local lines = {}
local si = 0
local snap = ws:GetChildren()
for i = 1, #snap do
  local inst = snap[i]
  if inst.Name == 'Scene' and inst:IsA('Model') then
    si = si + 1
    local desc = inst:GetDescendants()
    local rootName = 'sinModel'
    for j = 1, #desc do
      local d = desc[j]
      if d:IsA('Model') then rootName = d.Name end
    end
    for j = 1, #desc do
      local d = desc[j]
      if d:IsA('BasePart') then
        lines[#lines + 1] = string.format('S%d[%s] %s %s sz=%.2f,%.2f,%.2f pos=%.1f,%.1f,%.1f anch=%s',
          si, rootName, d.Name, d.ClassName,
          d.Size.X, d.Size.Y, d.Size.Z,
          d.Position.X, d.Position.Y, d.Position.Z, tostring(d.Anchored))
      end
    end
  end
end
return 'N=' .. tostring(#lines) .. ' :: ' .. table.concat(lines, ' // ')
