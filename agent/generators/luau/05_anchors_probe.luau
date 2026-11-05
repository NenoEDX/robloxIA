-- Posiciones de anclajes del diseño nuevo del usuario (para colocar los meshes)
local ws = game:GetService('Workspace')
local lobby = ws:FindFirstChild('Campamento7_Lobby')
if lobby == nil then return 'NO LOBBY' end
local anchors = {
  'AsphaltBaseplate', 'Camp7_Spawn', 'FirePitRim', 'CharredEmbers',
  'GatePostLeft', 'GatePostRight', 'Camp7MainSign',
  'BlastWallLeft', 'BlastWallRight', 'ArmoredDoorLeft', 'InfectedZoneWarningSign', 'NecroticMistFloorPad',
  'ArsenalSlab', 'ArsenalBackWall', 'WallArmoryBoard', 'TargetBaseStand',
  'WorkshopSlab', 'WorkbenchCounter', 'TallerSignBoard',
  'CageFloorPlatform', 'CageRoofGrid', 'QuarantineStrobeBeacon', 'BiohazardSign',
  'RuinsFloorSlab', 'RuinsRoofSlab',
  'PerimeterConcreteWall',
}
local out = {}
for i = 1, #anchors do
  local a = lobby:FindFirstChild(anchors[i], true)
  if a and a:IsA('BasePart') then
    out[#out + 1] = string.format('%s sz=%.1f,%.1f,%.1f pos=%.1f,%.1f,%.1f rot=%.0f,%.0f,%.0f',
      anchors[i], a.Size.X, a.Size.Y, a.Size.Z,
      a.Position.X, a.Position.Y, a.Position.Z,
      a.Orientation.X, a.Orientation.Y, a.Orientation.Z)
  else
    out[#out + 1] = anchors[i] .. ' -> N/A'
  end
end
-- bbox total del lobby + conteo
local total = 0
local bc, bs = lobby:GetBoundingBox()
local desc = lobby:GetDescendants()
for i = 1, #desc do
  if desc[i]:IsA('BasePart') then total = total + 1 end
end
out[#out + 1] = string.format('LOBBY bbox sz=%.1f,%.1f,%.1f center=%.1f,%.1f,%.1f parts=%d',
  bs.X, bs.Y, bs.Z, bc.Position.X, bc.Position.Y, bc.Position.Z, total)
return table.concat(out, '\n')
