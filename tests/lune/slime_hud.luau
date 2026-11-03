--!strict
-- Execute the actual HUD with inert Roblox/UI boundaries; no Studio or network.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Lifecycle = require("../../project_template/src/shared/GameLifecycle")
local Contract = require("../../project_template/src/shared/SlimeEventContract")
local checks = 0
local function ok(condition, message) checks += 1; assert(condition, message) end
local function signal()
	local listeners = {}
	return {
		Connect = function(_, callback)
			table.insert(listeners, callback)
			return { Disconnect = function() local i = table.find(listeners, callback); if i then table.remove(listeners, i) end end }
		end,
		Fire = function(_, ...) for _, callback in table.clone(listeners) do callback(...) end end,
		Count = function() return #listeners end,
	}
end
local created = {}
local function newInstance(class)
	local object = { ClassName = class, _children = {}, _signals = {} }
	table.insert(created, object)
	local methods = {
		Destroy = function(self) self._destroyed = true end,
		FindFirstChild = function(self, name) for _, child in self._children do if child.Name == name then return child end end return nil end,
		GetChildren = function(self) return table.clone(self._children) end,
		WaitForChild = function(self, name) for _, child in self._children do if child.Name == name then return child end end return nil end,
	}
	return setmetatable(object, {
		__index = function(t, key)
			if methods[key] then return methods[key] end
			if type(key) == "string" and (key:match("Click$") or key:match("Activated$") or key:match("Down$") or key:match("Up$")) then
				if not t._signals[key] then t._signals[key] = signal() end
				return t._signals[key]
			end
			return nil
		end,
		__newindex = function(t, key, value)
			if key == "Parent" and type(value) == "table" and rawget(value, "_children") then table.insert(value._children, t) end
			rawset(t, key, value)
		end,
	})
end
local warnings = {}
local remotes = {}
local children = {}
for key, name in Contract.Names do
	remotes[key] = { Name = name, OnClientEvent = signal(), IsA = function(_, class) return class == "RemoteEvent" end }
	table.insert(children, remotes[key])
end
local folder = { ChildAdded = signal(), GetChildren = function() return table.clone(children) end }
local destroying = signal()
local pool = {}
for i = 1, 10 do pool[i] = { id = "EV-" .. i, name = "Item " .. i, formattedOdds = "1.0000%", probabilityPercent = 1 } end
local modules = {
	Types = {}, GameLifecycle = Lifecycle, SlimeEventContract = Contract,
	SlimeCatalogs = { EVENT_CRATE_DAY1_POOL = pool, RARITY_GRADES = {} }, SlimeCoreMath = {},
}
local playerGui = { ClassName = "PlayerGui", _children = {} }
local services = {
	MarketplaceService = { GetProductInfoAsync = function() error("offline") end },
	Players = { LocalPlayer = { WaitForChild = function(_, name) assert(name == "PlayerGui"); return playerGui end } },
	ReplicatedStorage = { WaitForChild = function(_, name)
		if name == "Remotes" then return folder end
		return { WaitForChild = function(_, moduleName) return moduleName end }
	end },
}
local hud = luau.load(fs.readFile("project_template/src/client/SlimeHUDController.client.luau"), {
	debugName = "SlimeHUDController", environment = {
		game = { GetService = function(_, name) return services[name] or {} end },
		script = { Destroying = destroying }, require = function(name) return assert(modules[name], name) end,
		Instance = { new = newInstance }, task = { spawn = function(callback) callback() end, delay = function() end },
		warn = function(message) table.insert(warnings, tostring(message)) end,
		UDim2 = { new = function(...) return { ... } end }, UDim = { new = function(...) return { ... } end },
		Color3 = { fromRGB = function(...) return { ... } end }, Vector2 = { new = function(...) return { ... } end },
		Enum = setmetatable({}, { __index = function(t, key)
			local value = setmetatable({}, { __index = function(_, item) return { name = item } end }); t[key] = value; return value
		end }),
	},
})()
ok(type(hud.Stop) == "function", "HUD cleanup exists")
ok(hud.ScreenGui.ClassName == "ScreenGui", "HUD creates its ScreenGui")
ok(hud.GetSelectedPerformanceMode() == "MEDIUM_6", "Default performance mode preserved")
ok(remotes.AdminAbuseBroadcast.OnClientEvent:Count() == 1, "Canonical admin event binds once")
ok(remotes.DynamicCapturePrompt.OnClientEvent:Count() == 0, "Capture prompt does not initiate purchases")
local function findText(value)
	for _, object in created do if object.ClassName == "TextLabel" and object.Text == value then return object end end
	return nil
end
local expected = "ALERTA GLOBAL DE ADMIN ABUSE [HostBroadcast] activada por Creator!"
remotes.AdminAbuseBroadcast.OnClientEvent:Fire({ commandType = "HostBroadcast", triggeredByName = "Creator", durationSec = 5 })
local label = findText(expected)
ok(label ~= nil and label.Parent.Visible == true, "Valid wire table updates and displays the banner")
ok(#warnings == 0, "Valid packet does not warn")
remotes.AdminAbuseBroadcast.OnClientEvent:Fire({ commandType = "HostBroadcast" })
ok(#warnings == 1 and label.Text == expected, "Malformed payload warns without modifying the banner")
hud.ShowAdminAlert("manual alert")
ok(findText("manual alert") ~= nil, "Existing manual alert behavior preserved")
hud.SetTankGauge(500, 1000)
local gauge = nil
for _, object in created do
	if object.ClassName == "TextLabel" and type(object.Text) == "string" and string.find(object.Text, "Jugo Almacenado: 500 / 1000 mL", 1, true) then gauge = object end
end
ok(gauge ~= nil, "Existing tank gauge behavior preserved")
local before = label.Text
hud.Stop()
ok(hud.ScreenGui._destroyed == true, "Stop destroys the ScreenGui")
ok(remotes.AdminAbuseBroadcast.OnClientEvent:Count() == 0 and folder.ChildAdded:Count() == 0, "Stop disconnects listeners")
remotes.AdminAbuseBroadcast.OnClientEvent:Fire({ commandType = "HostBroadcast", triggeredByName = "AfterStop" })
ok(label.Text == before, "Stopped HUD does not mutate its banner")
hud.Stop(); destroying:Fire()
ok(folder.ChildAdded:Count() == 0, "Repeated stop/destruction is safe")
print(string.format("PASS HUD execution: %d assertions", checks))
