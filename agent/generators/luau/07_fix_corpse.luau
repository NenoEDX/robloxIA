-- 07_fix_corpse.luau — Re-asentar el cadáver con cálculo de fondo MUNDIAL (8 esquinas)
local ws = game:GetService('Workspace')
local lobby = ws:FindFirstChild('Campamento7_Lobby')
if lobby == nil then return 'NO LOBBY' end
local corpse = lobby:FindFirstChild('Frente_Cadaver', true)
if corpse == nil then return 'NO CADAVER' end

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

corpse:PivotTo(CFrame.new(-24.5, 1.5, -67) * CFrame.Angles(0, math.rad(25), 0) * CFrame.Angles(math.rad(-90), 0, 0))
local b = worldBottomOf(corpse)
corpse:PivotTo(corpse:GetPivot() + Vector3.new(0, 1.02 - b, 0))
local b2 = worldBottomOf(corpse)
return string.format('corpse bottom: %.2f -> %.2f (objetivo 1.02)', b, b2)
