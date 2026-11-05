--!strict
-- Edit-time setup. No source writes, network calls, or asset uploads.
local Setup = {}

local function folder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing:IsA("Folder"), name .. " must be a Folder")
		return existing
	end
	local result = Instance.new("Folder")
	result.Name = name
	result.Parent = parent
	return result
end

function Setup.prepare(): { shared: string, client: string }
	assert(not game:GetService("RunService"):IsRunning(), "Setup requires Edit mode")
	local shared = folder(game:GetService("ReplicatedStorage"), "RAASE_Shared")
	local client = folder(game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"), "RAASE_Client")
	return { shared = shared:GetFullName(), client = client:GetFullName() }
end

function Setup.archiveLegacy(): number
	assert(not game:GetService("RunService"):IsRunning(), "Archive requires Edit mode")
	local archive = folder(game:GetService("ServerStorage"), "SlimePitLegacyArchive")
	local count = 0
	for _, name in { "Lobby_Slimes_Abismales", "JuggernautZombie", "SpawnLocation", "AbyssalAmphitheater" } do
		local item = workspace:FindFirstChild(name)
		if item then
			assert(not archive:FindFirstChild(name), "Archive already contains " .. name)
			item.Parent = archive
			count += 1
		end
	end
	local ambience = game:GetService("ServerScriptService"):FindFirstChild("LobbyAmbienceAnimator")
	if ambience and ambience:IsA("Script") then
		ambience.Enabled = false
		ambience.Parent = archive
		count += 1
	end
	return count
end

function Setup.activateV1(): { disabledLegacyControllers: number }
	assert(not game:GetService("RunService"):IsRunning(), "Activation requires Edit mode")
	local client = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("RAASE_Client")
	assert(client, "Client container missing")
	local count = 0
	for _, name in { "SlimeClientController", "SlimeHUDController" } do
		local scriptInstance = client:FindFirstChild(name)
		if scriptInstance and scriptInstance:IsA("LocalScript") then scriptInstance.Enabled = false; count += 1 end
	end
	local v1 = client:FindFirstChild("SlimePitController")
	assert(v1 and v1:IsA("LocalScript"), "V1 controller missing")
	v1.Enabled = true
	return { disabledLegacyControllers = count }
end

return Setup
