--!strict
-- Original, reference-led primitive geometry. No imported meshes or paid assets.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedFolder = ReplicatedStorage:WaitForChild("RAASE_Shared")
local Catalog = require(SharedFolder:WaitForChild("SlimeCatalogs"))
local World = {}
local dark = Color3.fromRGB(27, 43, 57)
local cyan = Color3.fromRGB(68, 231, 225)
local mint = Color3.fromRGB(165, 246, 117)

local function part(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?, solid: boolean?): Part
	local p = Instance.new("Part")
	p.Name, p.Size, p.Position = name, size, position
	p.Color, p.Material = color, material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = solid == true
	p.CanTouch = false
	p.CastShadow = solid == true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function ball(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3): Part
	local p = part(parent, name, size, position, color)
	p.Shape = Enum.PartType.Ball
	return p
end

local function disk(parent: Instance, name: string, radius: number, thickness: number, position: Vector3, color: Color3, solid: boolean): Part
	local p = part(parent, name, Vector3.new(thickness, radius * 2, radius * 2), position, color, nil, solid)
	p.Shape = Enum.PartType.Cylinder
	p.Orientation = Vector3.new(0, 0, 90)
	return p
end

local function label(parent: BasePart, text: string, color: Color3, height: number?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = UDim2.fromOffset(260, 60)
	gui.StudsOffset = Vector3.new(0, height or 5, 0)
	gui.MaxDistance = 110
	gui.AlwaysOnTop = false
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = text
	textLabel.TextColor3 = color
	textLabel.TextStrokeTransparency = 0.2
	textLabel.Font = Enum.Font.FredokaOne
	textLabel.TextSize = 22
	textLabel.TextWrapped = true
	textLabel.Parent = gui
	gui.Parent = parent
end

function World.slime(parent: Instance, name: string, position: Vector3, color: Color3, variant: number): Model
	local model = Instance.new("Model")
	model.Name = name
	local body = ball(model, "Body", Vector3.new(4.6, 3.5, 4), position + Vector3.new(0, 1.3, 0), color)
	body.Material = Enum.Material.Glass
	body.Transparency = 0.12
	model.PrimaryPart = body
	ball(model, "Belly", Vector3.new(3.3, 2.5, 2.7), position + Vector3.new(0, 1.15, 0.1), color:Lerp(Color3.new(1, 1, 1), 0.24))
	for _, x in {-0.83, 0.83} do
		ball(model, "Eye", Vector3.new(0.52, 0.68, 0.3), position + Vector3.new(x, 1.8, -1.78), dark)
		ball(model, "EyeShine", Vector3.new(0.17, 0.2, 0.1), position + Vector3.new(x - 0.1, 1.98, -1.94), Color3.new(1, 1, 1))
		ball(model, "Cheek", Vector3.new(0.53, 0.25, 0.14), position + Vector3.new(x * 1.55, 1.25, -1.7), Color3.fromRGB(255, 159, 186))
	end
	ball(model, "Smile", Vector3.new(0.54, 0.23, 0.18), position + Vector3.new(0, 1.13, -1.96), dark)
	ball(model, "Highlight", Vector3.new(0.85, 0.23, 0.35), position + Vector3.new(-0.95, 2.65, -0.9), Color3.new(0.85, 1, 1))
	for i = 1, 3 do
		local crest = part(model, "Crest", Vector3.new(0.45, 1 + i * 0.18, 0.45), position + Vector3.new((i - 2) * 0.65, 3, 0), color:Lerp(cyan, 0.5), Enum.Material.Neon)
		crest.CFrame *= CFrame.Angles(0, 0, math.rad((i - 2) * -20))
		if variant % 3 == 0 then crest.Color = Color3.fromRGB(255, 209, 87) end
	end
	model:SetAttribute("Variant", variant)
	model.Parent = parent
	return model
end

local function prompt(parent: BasePart, action: string, object: string, duration: number, kind: string): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = "SlimePrompt"
	p.ActionText, p.ObjectText = action, object
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p.HoldDuration = duration
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p:SetAttribute("SlimeAction", kind)
	p.Parent = parent
	return p
end

function World.build(): Folder
	local previous = workspace:FindFirstChild("SlimePitV1")
	if previous then return previous :: Folder end
	local root = Instance.new("Folder")
	root.Name = "SlimePitV1"
	root:SetAttribute("Version", 1)
	root.Parent = workspace
	local layout = Instance.new("Folder")
	layout.Name, layout.Parent = "Landscape", root
	disk(layout, "Basin", 124, 6, Vector3.new(0, -3, 0), Color3.fromRGB(56, 79, 83), true)
	disk(layout, "InnerMoss", 102, 0.3, Vector3.new(0, 0.1, 0), Color3.fromRGB(64, 99, 99), true)
	local pool = disk(layout, "CorePool", 20, 0.4, Vector3.new(0, 0.4, 0), cyan, false)
	pool.Material = Enum.Material.Neon
	local core = World.slime(layout, "AncientSlime", Vector3.new(0, 1, 0), cyan, 3)
	core:ScaleTo(4)
	label(core.PrimaryPart :: BasePart, "SLIME PIT\nTHE ABYSS IS ALIVE", Color3.new(1, 1, 1), 14)
	local rng = Random.new(7281)
	for i = 1, 48 do
		local angle = i * math.pi * 2 / 48
		local height = rng:NextNumber(24, 49)
		local cliff = part(layout, "Cliff", Vector3.new(18, height, 20), Vector3.new(math.cos(angle) * 121, height / 2 - 2, math.sin(angle) * 121), dark:Lerp(Color3.fromRGB(58, 75, 91), rng:NextNumber()), Enum.Material.Slate, true)
		cliff.CFrame *= CFrame.Angles(0, -angle, math.rad(rng:NextNumber(-8, 8)))
	end
	local hub = part(root, "Sanctuary", Vector3.new(56, 4, 34), Vector3.new(0, 4, 94), dark, Enum.Material.Slate, true)
	label(hub, "SANCTUARY\nDEPOSIT • DISCOVER • DIVE", mint, 9)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name, spawn.Size = "SlimeSpawn", Vector3.new(10, 1, 8)
	spawn.Position, spawn.Anchored, spawn.Neutral = Vector3.new(0, 6.5, 100), true, true
	spawn.Color, spawn.Material = mint, Enum.Material.Neon
	spawn.Duration = 0
	spawn.Parent = root
	local a, b = Vector3.new(0, 6, 78), Vector3.new(0, 0.5, 53)
	local ramp = part(layout, "SanctuaryRamp", Vector3.new(16, 1, (b-a).Magnitude), (a+b)/2, Color3.fromRGB(107, 145, 143), nil, true)
	ramp.CFrame = CFrame.lookAt((a+b)/2, b)
	local bank = disk(root, "Deposit", 5, 2, Vector3.new(-17, 7, 94), mint, true)
	bank.Material = Enum.Material.Neon
	label(bank, "DEPOSIT\nSecure your discoveries", mint, 6)
	prompt(bank, "Deposit", "Sanctuary vault", 1, "Deposit")
	local nodes = Instance.new("Folder")
	nodes.Name, nodes.Parent = "Nodes", root
	local zones = {
		{name="MOSS GARDEN", center=Vector3.new(-61, 0, 13), color=mint, biome=1},
		{name="CRYSTAL HOLLOW", center=Vector3.new(0, 0, -67), color=cyan, biome=6},
		{name="AMBER RIFT", center=Vector3.new(61, 0, 13), color=Color3.fromRGB(255, 183, 84), biome=11},
	}
	local index = 0
	local function node(position: Vector3, biome: number, variant: number, zone: string)
		index += 1
		local id = string.format("SLIME-%03d", (biome-1)*10+variant)
		local def = Catalog.SLIMES_BY_ID[id]
		local grade = Catalog.RARITY_GRADES[def.rarityGrade]
		local model = World.slime(nodes, string.format("Node_%02d",index), position, grade.color, variant)
		model:SetAttribute("SlimeId", id)
		model:SetAttribute("Zone", zone)
		model:SetAttribute("Juice", 50 + variant * 15)
		model:SetAttribute("Available", true)
		disk(model, "Burrow", 3.5, 0.5, position + Vector3.new(0, -0.1, 0), dark, false)
		prompt(model.PrimaryPart :: BasePart, "Pull slime", grade.name .. " slime", 1.4 + variant * 0.24, "Harvest")
	end
	node(Vector3.new(-8, 0.5, 54), 1, 1, "MOSS GARDEN")
	node(Vector3.new(9, 0.5, 49), 1, 2, "MOSS GARDEN")
	for _, zone in zones do
		local marker = disk(layout, zone.name, 23, 0.25, zone.center + Vector3.new(0, 0.4, 0), zone.color:Lerp(dark, 0.76), true)
		label(marker, zone.name, zone.color, 10)
		for i = 1, 8 do
			local angle = i * math.pi / 4
			node(zone.center + Vector3.new(math.cos(angle)*15, 0.6, math.sin(angle)*15), zone.biome, i, zone.name)
			local crystal = part(layout, "Crystal", Vector3.new(1.8, 5+i%3, 1.8), zone.center + Vector3.new(math.cos(angle)*25, 2, math.sin(angle)*25), zone.color, Enum.Material.Neon)
			crystal.CFrame *= CFrame.Angles(0.2, angle, 0.3)
		end
		local exit = disk(root, "Return_"..zone.biome, 3, 0.5, zone.center+Vector3.new(0,0.8,0), zone.color, false)
		exit.Material = Enum.Material.Neon
		prompt(exit, "Return", "Sanctuary portal", 1, "Return")
	end
	local visuals = Instance.new("Folder")
	visuals.Name, visuals.Parent = "PetVisuals", root
	local lighting = game:GetService("Lighting")
	lighting.ClockTime, lighting.Brightness = 14, 2
	lighting.Ambient = Color3.fromRGB(106, 128, 149)
	lighting.OutdoorAmbient = Color3.fromRGB(130, 150, 165)
	lighting.ExposureCompensation = 0.15
	return root
end

return World
