--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Prompts = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")
local SharedFolder = ReplicatedStorage:WaitForChild("RAASE_Shared")
local Catalog = require(SharedFolder:WaitForChild("SlimeCatalogs"))
local Registry = require(SharedFolder:WaitForChild("SlimeVisualRegistry"))
local World = require(SharedFolder:WaitForChild("SlimePitWorld"))
local player = Players.LocalPlayer
local connections: { RBXScriptConnection } = {}
local inventoryConnections: { RBXScriptConnection } = {}
local releases: { () -> () } = {}
local companions: { Model } = {}
local navy = Color3.fromRGB(23, 39, 54)
local mint = Color3.fromRGB(165, 246, 117)
local white = Color3.fromRGB(241, 251, 255)
local activeHold: any = nil
local stopped = false

local gui = Instance.new("ScreenGui")
gui.Name = "SlimePitHUD"
gui.ResetOnSpawn = false
gui.DisplayOrder = 20
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
gui.Parent = player:WaitForChild("PlayerGui")
local function text(parent: Instance, name: string, content: string, size: number, color: Color3): TextLabel
	local t = Instance.new("TextLabel")
	t.Name, t.Text, t.TextSize, t.TextColor3 = name, content, size, color
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextWrapped = true
	t.Size = UDim2.fromScale(1, 1)
	t.Parent = parent
	return t
end
local function panel(parent: Instance, name: string, size: UDim2, position: UDim2, color: Color3): Frame
	local p = Instance.new("Frame")
	p.Name, p.Size, p.Position, p.BackgroundColor3 = name, size, position, color
	p.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius, corner.Parent = UDim.new(0, 14), p
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness, stroke.Parent = Color3.fromRGB(8, 20, 31), 3, p
	p.Parent = parent
	return p
end
local title = text(gui, "Title", "SLIME PIT", 32, mint)
title.Size, title.Position = UDim2.fromOffset(210, 42), UDim2.fromOffset(12, 10)
title.TextXAlignment = Enum.TextXAlignment.Left
local bank = text(gui, "Banked", "", 16, white)
bank.Size, bank.Position = UDim2.fromOffset(265, 32), UDim2.fromOffset(12, 49)
bank.TextXAlignment = Enum.TextXAlignment.Left
local tank = panel(gui, "Tank", UDim2.new(0.7, 0, 0, 88), UDim2.new(0.5, 0, 1, -16), navy)
tank.AnchorPoint = Vector2.new(0.5, 1)
local tankLimit = Instance.new("UISizeConstraint")
tankLimit.MaxSize, tankLimit.Parent = Vector2.new(470, 88), tank
local tankTitle = text(tank, "TankTitle", "BACKPACK", 20, mint)
tankTitle.Size = UDim2.new(1, -24, 0, 29)
tankTitle.Position = UDim2.fromOffset(12, 6)
local track = panel(tank, "Track", UDim2.new(1, -28, 0, 32), UDim2.fromOffset(14, 42), Color3.fromRGB(13, 26, 34))
local fill = panel(track, "Fill", UDim2.fromScale(0, 1), UDim2.fromOffset(0, 0), mint)
local gauge = text(track, "Gauge", "", 17, white)
gauge.TextStrokeTransparency = 0.35
local message = text(gui, "Guide", "Walk down the ramp and hold E near a slime.", 17, white)
message.Size, message.Position = UDim2.new(0.9, 0, 0, 54), UDim2.new(0.5, 0, 1, -112)
message.AnchorPoint = Vector2.new(0.5, 1)
message.TextStrokeTransparency = 0.25
local progress = panel(gui, "Extraction", UDim2.fromOffset(280, 65), UDim2.new(0.5, 0, 0.63, 0), navy)
progress.AnchorPoint, progress.Visible = Vector2.new(0.5, 0.5), false
local progressLabel = text(progress, "Label", "PULLING…", 18, white)
progressLabel.Size = UDim2.new(1, 0, 0, 32)
local progressTrack = panel(progress, "Track", UDim2.new(1, -24, 0, 14), UDim2.fromOffset(12, 40), Color3.fromRGB(11, 26, 38))
local progressFill = panel(progressTrack, "Fill", UDim2.fromScale(0, 1), UDim2.new(), mint)

local collection = panel(gui, "Collection", UDim2.new(0.9, 0, 0.7, 0), UDim2.fromScale(0.5, 0.47), navy)
collection.AnchorPoint, collection.Visible = Vector2.new(0.5, 0.5), false
local limit = Instance.new("UISizeConstraint")
limit.MaxSize, limit.Parent = Vector2.new(620, 560), collection
local header = text(collection, "Header", "YOUR DISCOVERIES", 25, mint)
header.Size, header.Position = UDim2.new(1, -64, 0, 54), UDim2.fromOffset(8, 4)
local list = Instance.new("ScrollingFrame")
list.Name, list.BackgroundTransparency = "Items", 1
list.Position, list.Size = UDim2.fromOffset(14, 62), UDim2.new(1, -28, 1, -103)
list.ScrollBarThickness, list.BorderSizePixel = 6, 0
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = collection
local layout = Instance.new("UIListLayout")
layout.Padding, layout.Parent = UDim.new(0, 9), list
local footer = text(collection, "SessionNotice", "Session collection • deposit at the sanctuary to reveal mutations", 14, white)
footer.Size, footer.Position = UDim2.new(1, -20, 0, 33), UDim2.new(0, 10, 1, -36)
local function button(parent: Instance, name: string, value: string, size: UDim2, position: UDim2, callback: () -> ())
	local b = Instance.new("TextButton")
	b.Name, b.Text, b.Size, b.Position = name, value, size, position
	b.BackgroundColor3, b.TextColor3, b.TextSize = mint, navy, 18
	b.Font = Enum.Font.FredokaOne
	local corner = Instance.new("UICorner")
	corner.CornerRadius, corner.Parent = UDim.new(0, 12), b
	b.Parent = parent
	table.insert(connections, b.Activated:Connect(callback))
	return b
end
local bagButton: TextButton
local closeButton: TextButton
local function toggle()
	collection.Visible = not collection.Visible
	GuiService.SelectedObject = if collection.Visible then closeButton else bagButton
end
bagButton = button(gui, "BackpackButton", "COLLECTION", UDim2.fromOffset(132, 48), UDim2.new(1, -146, 0, 14), toggle)
closeButton = button(collection, "Close", "×", UDim2.fromOffset(44, 44), UDim2.new(1, -50, 0, 8), toggle)

local visualRoot = Instance.new("Folder")
visualRoot.Name, visualRoot.Parent = "LocalSlimeCompanions", workspace
local inventory = player:WaitForChild("SlimeInventory")
local scheduled = false
local function refreshCollection()
	scheduled = false
	if stopped then return end
	for _, release in releases do release() end
	table.clear(releases)
	for _, model in companions do model:Destroy() end
	table.clear(companions)
	for _, row in list:GetChildren() do if row:IsA("Frame") then row:Destroy() end end
	local entries = inventory:GetChildren()
	table.sort(entries, function(a, b) return a.Name < b.Name end)
	for i, entry in entries do
		if not entry:IsA("StringValue") then continue end
		local def = Catalog.SLIMES_BY_ID[entry:GetAttribute("SlimeId")]
		if not def then continue end
		local grade = Catalog.RARITY_GRADES[def.rarityGrade]
		if i <= 6 then
			local model = World.slime(visualRoot, entry.Name, Vector3.zero, grade.color, grade.rank)
			model:ScaleTo(0.48)
			table.insert(companions, model)
			table.insert(releases, Registry.register(entry.Name, model))
		end
		if i > 60 then continue end
		local row = panel(list, entry.Name, UDim2.new(1, -8, 0, 93), UDim2.new(), Color3.fromRGB(43, 64, 80))
		row.LayoutOrder = i
		local rarity = text(row, "Name", grade.name .. " • " .. entry.Value, 17, grade.color)
		rarity.Size, rarity.Position = UDim2.new(1, -20, 0, 31), UDim2.fromOffset(10, 3)
		local auraName = ""
		for _, aura in Catalog.AURAS do if aura.id == entry:GetAttribute("Aura") then auraName = aura.name end end
		local banked = entry:GetAttribute("Banked") == true
		local detail = (if banked then "SECURED" else "IN BACKPACK") .. " • " .. auraName
		local mutations = entry:GetAttribute("Mutations")
		detail ..= "\n" .. (if mutations ~= "" then tostring(mutations) else "Deposit to reveal mutations")
		local info = text(row, "Details", detail, 14, white)
		info.Size, info.Position = UDim2.new(1, -18, 0, 54), UDim2.fromOffset(9, 34)
	end
	if #entries == 0 then
		local row = panel(list, "Empty", UDim2.new(1, -8, 0, 100), UDim2.new(), navy)
		text(row, "Hint", "Your first discovery is waiting.\nHold E at a slime burrow!", 20, white)
	end
end
local function schedule()
	if scheduled then return end
	scheduled = true
	task.defer(refreshCollection)
end
local function watchEntry(entry: Instance)
	table.insert(inventoryConnections, entry.AttributeChanged:Connect(schedule))
	schedule()
end
for _, entry in inventory:GetChildren() do watchEntry(entry) end
table.insert(connections, inventory.ChildAdded:Connect(watchEntry))
table.insert(connections, inventory.ChildRemoved:Connect(schedule))
schedule()

local function updateGauge()
	local juice = player:GetAttribute("SlimeJuice") or 0
	local capacity = player:GetAttribute("SlimeCapacity") or 1000
	fill.Size = UDim2.fromScale(math.clamp(juice/capacity, 0, 1), 1)
	gauge.Text = string.format("%d / %d juice", juice, capacity)
	tankTitle.Text = string.format("BACKPACK  %d / %d", player:GetAttribute("SlimePack") or 0, player:GetAttribute("SlimeSlots") or 8)
	bank.Text = string.format("%d secured  •  %d juice banked", player:GetAttribute("SlimeBanked") or 0, player:GetAttribute("SlimeSecured") or 0)
end
for _, name in {"SlimeJuice", "SlimeCapacity", "SlimePack", "SlimeBanked", "SlimeSecured"} do
	table.insert(connections, player:GetAttributeChangedSignal(name):Connect(updateGauge))
end
updateGauge()
table.insert(connections, player:GetAttributeChangedSignal("SlimeNoticeSequence"):Connect(function()
	message.Text = player:GetAttribute("SlimeNotice") or ""
end))
local function stopHold()
	if activeHold and activeHold.model and activeHold.model.Parent then
		activeHold.model:ScaleTo(activeHold.scale)
		activeHold.model:PivotTo(activeHold.pivot)
	end
	activeHold = nil
	progress.Visible = false
end
table.insert(connections, Prompts.PromptButtonHoldBegan:Connect(function(p)
	if not p:GetAttribute("SlimeAction") then return end
	stopHold()
	local model = if p:GetAttribute("SlimeAction") == "Harvest" then p.Parent.Parent else nil
	activeHold = {prompt=p, start=os.clock(), model=model, scale=if model then model:GetScale() else 1, pivot=if model then model:GetPivot() else CFrame.identity}
	progressLabel.Text = if model then "PULLING… KEEP HOLDING" else string.upper(p.ActionText).."…"
	progress.Visible = true
end))
table.insert(connections, Prompts.PromptButtonHoldEnded:Connect(function(p) if activeHold and activeHold.prompt == p then stopHold() end end))
table.insert(connections, Prompts.PromptHidden:Connect(function(p) if activeHold and activeHold.prompt == p then stopHold() end end))
table.insert(connections, player:GetAttributeChangedSignal("SlimeHarvestSequence"):Connect(function()
	local position = player:GetAttribute("SlimeLastHarvest")
	if typeof(position) ~= "Vector3" then return end
	stopHold()
	if GuiService.ReducedMotionEnabled then return end
	for i = 1, 12 do
		local spark = Instance.new("Part")
		spark.Shape, spark.Size = Enum.PartType.Ball, Vector3.new(0.32, 0.32, 0.32)
		spark.Anchored, spark.CanCollide, spark.CanTouch, spark.CanQuery = true, false, false, false
		spark.Color, spark.Material, spark.Position = mint, Enum.Material.Neon, position
		spark.Parent = visualRoot
		local angle = i * math.pi / 6
		TweenService:Create(spark, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position=position+Vector3.new(math.cos(angle)*4, 2+i%3, math.sin(angle)*4), Transparency=1}):Play()
		Debris:AddItem(spark, 0.65)
	end
	-- Optional project-owned SFX hook. No fabricated asset ID or purchase.
	local soundId = workspace:GetAttribute("SlimePopSoundId")
	if type(soundId) == "string" and soundId ~= "" then
		local sound = Instance.new("Sound")
		sound.SoundId, sound.Volume, sound.Parent = soundId, 0.35, gui
		sound:Play()
		Debris:AddItem(sound, 3)
	end
end))
table.insert(connections, RunService.RenderStepped:Connect(function()
	local time = os.clock()
	if activeHold then
		local fraction = math.clamp((time-activeHold.start)/activeHold.prompt.HoldDuration, 0, 1)
		progressFill.Size = UDim2.fromScale(fraction, 1)
		if activeHold.model and activeHold.model.Parent and not GuiService.ReducedMotionEnabled then
			activeHold.model:ScaleTo(activeHold.scale*(1+fraction*0.16))
			activeHold.model:PivotTo(activeHold.pivot*CFrame.new(math.sin(time*36)*0.09*fraction, fraction*0.6, 0)*CFrame.Angles(0,0,math.sin(time*24)*0.04*fraction))
		end
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		for i, model in companions do
			local offset = Vector3.new(((i-1)%3-1)*2.8, -1.6, 4+math.floor((i-1)/3)*2.5)
			local bounce = if GuiService.ReducedMotionEnabled then 0 else math.abs(math.sin(time*3+i))*0.35
			model:PivotTo(root.CFrame*CFrame.new(offset+Vector3.new(0,bounce,0)))
		end
	end
end))
table.insert(connections, script.Destroying:Connect(function()
	stopped = true
	stopHold()
	for _, connection in connections do connection:Disconnect() end
	for _, connection in inventoryConnections do connection:Disconnect() end
	for _, release in releases do release() end
	visualRoot:Destroy()
	gui:Destroy()
end))
print("[SLIME PIT V1] HUD and collection ready")
