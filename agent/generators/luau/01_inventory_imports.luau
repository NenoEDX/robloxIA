-- Inventario de meshes importados (Modelos "Scene" en Workspace)
local ws = game:GetService('Workspace')
local report = {}
local snap = ws:GetChildren()
for i = 1, #snap do
  local inst = snap[i]
  if inst.Name == 'Scene' and inst:IsA('Model') then
    local kids = inst:GetChildren()
    for j = 1, #kids do
      local k = kids[j]
      if k:IsA('BasePart') then
        report[#report + 1] = string.format(
          '%s|%s|sz=%.2f,%.2f,%.2f|pos=%.1f,%.1f,%.1f|anchor=%s',
          k.Name, k.ClassName, k.Size.X, k.Size.Y, k.Size.Z,
          k.Position.X, k.Position.Y, k.Position.Z, tostring(k.Anchored)
        )
      else
        report[#report + 1] = k.Name .. '|' .. k.ClassName .. '|noBasePart'
      end
    end
  end
end
return 'COUNT=' .. tostring(#report) .. ' :: ' .. table.concat(report, ' // ')
