--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SharedFolder = ReplicatedStorage:WaitForChild("RAASE_Shared")
local Catalog = require(SharedFolder:WaitForChild("SlimeCatalogs"))
local Rules = require(SharedFolder:WaitForChild("SlimePitRules"))
local World = require(SharedFolder:WaitForChild("SlimePitWorld"))
local Core = require(script.Parent:WaitForChild("SlimeCoreService"))
local Security = require(script.Parent:WaitForChild("NetworkSecurityService"))
local SlimePitService = {}
local connections: { RBXScriptConnection } = {}
local states: { [Player]: any } = {}
local holds: { [Player]: any } = {}
local running = false
local generation = 0
local world: Folder

local function sync(player: Player)
	local state = states[player]
	if not state then return end
	player:SetAttribute("SlimeJuice", Core.getPlayerUnrefinedJuice(player))
	player:SetAttribute("SlimeCapacity", Rules.TANK_CAPACITY)
	player:SetAttribute("SlimePack", state.pending)
	player:SetAttribute("SlimeSlots", Rules.PACK_CAPACITY)
	player:SetAttribute("SlimeBanked", #Core.getPlayerPets(player))
	player:SetAttribute("SlimeSecured", state.secured)
end

local function notice(player: Player, text: string)
	player:SetAttribute("SlimeNotice", text)
	player:SetAttribute("SlimeNoticeSequence", (player:GetAttribute("SlimeNoticeSequence") or 0) + 1)
end

local function valid(player: Player, p: ProximityPrompt): (boolean, number)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local target = p.Parent
	if not running or not states[player] or not p.Enabled or not p:IsDescendantOf(world)
		or not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0
		or not target or not target:IsA("BasePart") then return false, math.huge end
	return Security.validateProximity(player, target.Position, Rules.INTERACTION_DISTANCE), (root.Position-target.Position).Magnitude
end

local function projectPet(player: Player, pet: any, banked: boolean)
	local folder = player:FindFirstChild("SlimeInventory")
	if not folder then return end
	local entry = folder:FindFirstChild(pet.uuid) :: StringValue?
	if not entry then
		entry = Instance.new("StringValue")
		entry.Name = pet.uuid
		entry.Parent = folder
	end
	local def = Catalog.SLIMES_BY_ID[pet.slimeId]
	entry.Value = def.name
	entry:SetAttribute("SlimeId", pet.slimeId)
	entry:SetAttribute("Rarity", def.rarityGrade)
	entry:SetAttribute("Banked", banked)
	entry:SetAttribute("Aura", pet.auraId or "")
	local names = {}
	for _, mutationId in pet.mutations do
		for _, mutation in Catalog.MUTATIONS do
			if mutation.id == mutationId then table.insert(names, mutation.name); break end
		end
	end
	entry:SetAttribute("Mutations", table.concat(names, ", "))
end

local function harvest(player: Player, p: ProximityPrompt)
	local state = states[player]
	local node = (p.Parent :: Instance).Parent :: Model
	local id = node:GetAttribute("SlimeId") :: string
	local reward = node:GetAttribute("Juice") :: number
	local def = Catalog.SLIMES_BY_ID[id]
	if not def or node:GetAttribute("Available") ~= true then return end
	if not Rules.canHarvest(Core.getPlayerUnrefinedJuice(player), Rules.TANK_CAPACITY, state.pending, Rules.PACK_CAPACITY, reward) then
		notice(player, "Backpack full — return to the sanctuary and deposit.")
		return
	end
	-- All validation and ownership changes are synchronous: one winner per node.
	local pet = Core.addPendingDorsalSlime(player, id, def.biomeIndex)
	if not pet then return end
	pet.auraId = Catalog.AURAS[math.clamp(math.ceil(def.biomeIndex/5),1,3)].id
	Core.addUnrefinedJuice(player, reward)
	state.pending += 1
	node:SetAttribute("Available", false)
	p.Enabled = false
	for _, child in node:GetDescendants() do
		if child:IsA("BasePart") then
			child:SetAttribute("RestTransparency", child.Transparency)
			child.Transparency = 1
		end
	end
	projectPet(player, pet, false)
	player:SetAttribute("SlimeLastHarvest", (p.Parent :: BasePart).Position)
	player:SetAttribute("SlimeHarvestSequence", (player:GetAttribute("SlimeHarvestSequence") or 0)+1)
	local grade = Catalog.RARITY_GRADES[def.rarityGrade]
	notice(player, string.format("%s slime rescued! +%d juice", grade.name, reward))
	sync(player)
	local token = generation
	task.delay(Rules.RESPAWN_SECONDS, function()
		if not running or generation ~= token or not node.Parent then return end
		for _, child in node:GetDescendants() do
			if child:IsA("BasePart") then child.Transparency = child:GetAttribute("RestTransparency") or 0 end
		end
		node:SetAttribute("Available", true)
		p.Enabled = true
	end)
end

local function finish(player: Player, p: ProximityPrompt)
	local hold = holds[player]
	local allowed, distance = valid(player, p)
	if not hold or hold.prompt ~= p or hold.character ~= player.Character then return end
	holds[player] = nil
	if not Rules.completed(hold.started, os.clock(), p.HoldDuration, distance, allowed) then return end
	local action = p:GetAttribute("SlimeAction")
	if action == "Harvest" then harvest(player, p)
	elseif action == "Return" then
		(player.Character :: Model):PivotTo(CFrame.new(0, 11, 94))
		notice(player, "Safe return! Hold E at the green vault to secure your slimes.")
	elseif action == "Deposit" then
		local result = Core.extractToCircularLobby(player)
		if not result.success then return end
		local state = states[player]
		state.secured += result.securedJuice
		state.pending = 0
		for _, pet in result.extractedSlimes do projectPet(player, pet, true) end
		sync(player)
		notice(player, string.format("Secured %d slimes and %d juice. Check your collection!", #result.extractedSlimes, result.securedJuice))
	end
end

local function bindPrompt(p: ProximityPrompt)
	table.insert(connections, p.PromptButtonHoldBegan:Connect(function(player)
		local allowed = valid(player, p)
		if allowed and Security.checkRateLimit(player, "SlimeHarvest", 1) then
			holds[player] = {prompt=p, started=os.clock(), character=player.Character}
		end
	end))
	table.insert(connections, p.PromptButtonHoldEnded:Connect(function(player)
		local captured = holds[player]
		-- Triggered and HoldEnded may arrive in the same frame; allow that ordering only.
		task.defer(function() if holds[player] == captured then holds[player] = nil end end)
	end))
	table.insert(connections, p.Triggered:Connect(function(player) finish(player, p) end))
end

local function joined(player: Player)
	if states[player] then return end
	states[player] = { pending=0, secured=0 }
	local inventory = Instance.new("Folder")
	inventory.Name, inventory.Parent = "SlimeInventory", player
	player.RespawnLocation = world:WaitForChild("SlimeSpawn") :: SpawnLocation
	sync(player)
	notice(player, "Walk down the ramp. Hold E near a slime to pull it free.")
	table.insert(connections, player.CharacterAdded:Connect(function()
		holds[player] = nil
		-- The session backpack survives respawn; never silently discard earned items.
		sync(player)
	end))
end

function SlimePitService.start(): boolean
	if running then return false end
	Core.start()
	running = true
	generation += 1
	world = World.build()
	for _, item in world:GetDescendants() do
		if item:IsA("ProximityPrompt") then bindPrompt(item) end
	end
	table.insert(connections, Players.PlayerAdded:Connect(joined))
	table.insert(connections, Players.PlayerRemoving:Connect(function(player) holds[player], states[player] = nil, nil end))
	table.insert(connections, RunService.Heartbeat:Connect(function()
		for player, hold in holds do
			if not valid(player, hold.prompt) or player.Character ~= hold.character then holds[player] = nil end
		end
	end))
	for _, player in Players:GetPlayers() do joined(player) end
	print("[SLIME PIT V1] Ready | 26 harvest nodes | 3 biomes | session inventory")
	return true
end

function SlimePitService.stop()
	running = false
	generation += 1
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	table.clear(holds)
	table.clear(states)
end

return SlimePitService
