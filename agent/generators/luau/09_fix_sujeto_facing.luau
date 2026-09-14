-- 09_fix_sujeto_facing.luau — Girar al Sujeto #7 para que mire al sur (visitantes)
local ws = game:GetService('Workspace')
local lobby = ws:FindFirstChild('Campamento7_Lobby')
if lobby == nil then return 'NO LOBBY' end
local sj = lobby:FindFirstChild('Sujeto7_Infectado', true)
if sj == nil then return 'NO SUJETO' end

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

sj:PivotTo(CFrame.new(-41, 1.4, 1.0) * CFrame.Angles(0, 0, 0))
local b = worldBottomOf(sj)
sj:PivotTo(sj:GetPivot() + Vector3.new(0, 1.42 - b, 0))
return string.format('sujeto girado a yaw 0; bottom %.2f -> %.2f (plataforma 1.40)', b, worldBottomOf(sj))
