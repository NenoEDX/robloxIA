--!strict
--[[
	HUDController.client.luau
	Interfaz Táctica y Mapa de Conciencia para Zombie Awareness (v4.0) (Secciones 1, 2.2 y 4.1):
	- Panel de Bóveda Segura vs. Mochila Táctica No Asegurada (Chatarra, Componentes, Núcleos).
	- Mapa de Conciencia en tiempo real (Amenaza de Z1 a Z7 y Crisoles Oeste/Este con bloqueo Mutex).
	- Barra Global de Jefe Supremo (Z-BOSS-01 Dios Zombi Troll / M-BOSS-01 Coloso Mutante Supremo).
	- Banner de Eventos Procedurales (E-01 a E-16) y Controles de Armería Modular (Lv1–Lv10 + Refundición 80%).
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("RAASE_Shared")
local Types = require(sharedFolder:WaitForChild("Types") :: any)
local ZombieCatalogs = require(sharedFolder:WaitForChild("ZombieCatalogs") :: any)

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local combatActionRemote = remotesFolder:WaitForChild("ZA_CombatAction") :: RemoteEvent
local arsenalActionRemote = remotesFolder:WaitForChild("ZA_ArsenalAction") :: RemoteEvent
local eventAlertRemote = remotesFolder:WaitForChild("ZA_EventAlert") :: RemoteEvent

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ZA_TacticalHUD_v4"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
screenGui.Parent = playerGui

local function styleFrame(frame: Frame, bgColor: Color3, strokeColor: Color3, radiusPx: number)
	frame.BackgroundColor3 = bgColor
	frame.BackgroundTransparency = 0.14
	frame.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radiusPx)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = strokeColor
	stroke.Thickness = 1.5
	stroke.Parent = frame
end

local function makeLabel(
	parent: Instance,
	name: string,
	size: UDim2,
	pos: UDim2,
	text: string,
	color: Color3,
	textSize: number
): TextLabel
	local lbl = Instance.new("TextLabel")
	lbl.Name = name
	lbl.Size = size
	lbl.Position = pos
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.BuilderSansBold
	lbl.Text = text
	lbl.TextColor3 = color
	lbl.TextSize = textSize
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = parent
	return lbl
end

--------------------------------------------------------------------------------
-- 1. PANEL SUPERIOR IZQUIERDO: BÓVEDA SEGURA VS. MOCHILA TÁCTICA
--------------------------------------------------------------------------------

local economyPanel = Instance.new("Frame")
economyPanel.Name = "EconomyAndBackpackPanel"
economyPanel.Size = UDim2.new(0.28, 0, 0.14, 0)
economyPanel.Position = UDim2.new(0.015, 0, 0.02, 0)
styleFrame(economyPanel, Color3.fromRGB(14, 18, 24), Color3.fromRGB(56, 178, 172), 10)
economyPanel.Parent = screenGui

local vaultLabel = makeLabel(
	economyPanel,
	"VaultResourcesLabel",
	UDim2.new(0.94, 0, 0.32, 0),
	UDim2.new(0.03, 0, 0.06, 0),
	"BÓVEDA: 250 Chatarra | 15 Comp | 1 Núcleos",
	Color3.fromRGB(236, 201, 75),
	15
)

local backpackLabel = makeLabel(
	economyPanel,
	"TacticalBackpackLabel",
	UDim2.new(0.94, 0, 0.30, 0),
	UDim2.new(0.03, 0, 0.38, 0),
	"MOCHILA INCURSIÓN (Riesgo 50%): +0 Chat | +0 Comp | +0 Núc",
	Color3.fromRGB(129, 230, 217),
	13
)

local statusSubLabel = makeLabel(
	economyPanel,
	"StatusSubLabel",
	UDim2.new(0.94, 0, 0.28, 0),
	UDim2.new(0.03, 0, 0.68, 0),
	"Emisor G-20: Bloqueado (Lab A-06) | Lealtad Humana: +25",
	Color3.fromRGB(160, 174, 192),
	13
)

--------------------------------------------------------------------------------
-- 2. PANEL SUPERIOR CENTRAL: CRISOLES ZVM, MUTEX Y BARRA DE MEGA BRUTO LÍDER
--------------------------------------------------------------------------------

local centerBanner = Instance.new("Frame")
centerBanner.Name = "CrucibleAndBossBanner"
centerBanner.Size = UDim2.new(0.40, 0, 0.13, 0)
centerBanner.Position = UDim2.new(0.30, 0, 0.02, 0)
styleFrame(centerBanner, Color3.fromRGB(20, 16, 24), Color3.fromRGB(229, 62, 62), 10)
centerBanner.Parent = screenGui

local eventTickerLabel = makeLabel(
	centerBanner,
	"EventTickerLabel",
	UDim2.new(0.94, 0, 0.34, 0),
	UDim2.new(0.03, 0, 0.05, 0),
	"[EVENTO ACTIVO] E-01 Choque de Patrullas (Z1)",
	Color3.fromRGB(254, 215, 215),
	14
)

local crucibleMutexLabel = makeLabel(
	centerBanner,
	"CrucibleMutexLabel",
	UDim2.new(0.94, 0, 0.30, 0),
	UDim2.new(0.03, 0, 0.38, 0),
	"CRISOLES ZvM — Oeste (Troll): 0/1000 | Este (Coloso): 0/1000 | Mutex: LIBRE",
	Color3.fromRGB(246, 173, 85),
	13
)

local bossHpLabel = makeLabel(
	centerBanner,
	"MegaBossHpLabel",
	UDim2.new(0.94, 0, 0.28, 0),
	UDim2.new(0.03, 0, 0.68, 0),
	"MEGA BRUTO LÍDER: Ninguno activo en el servidor",
	Color3.fromRGB(104, 211, 145),
	13
)

--------------------------------------------------------------------------------
-- 3. PANEL DERECHO: MAPA DE CONCIENCIA (AMENAZA Z1 A Z7 EN TIEMPO REAL)
--------------------------------------------------------------------------------

local mapPanel = Instance.new("Frame")
mapPanel.Name = "ConsciousnessMapPanel"
mapPanel.Size = UDim2.new(0.24, 0, 0.42, 0)
mapPanel.Position = UDim2.new(0.745, 0, 0.02, 0)
styleFrame(mapPanel, Color3.fromRGB(15, 20, 28), Color3.fromRGB(66, 153, 225), 10)
mapPanel.Parent = screenGui

makeLabel(
	mapPanel,
	"MapTitle",
	UDim2.new(0.92, 0, 0.10, 0),
	UDim2.new(0.04, 0, 0.02, 0),
	"MAPA DE CONCIENCIA (Z0–Z7)",
	Color3.fromRGB(99, 179, 237),
	15
)

local districtLabels: { [Types.DistrictId]: TextLabel } = {}
local orderedZones: { Types.DistrictId } = { "Z1", "Z2", "Z3", "Z4", "Z5", "Z6", "Z7" }

for idx, distId in ipairs(orderedZones) do
	local cfg = ZombieCatalogs.Districts[distId]
	local yPos = 0.12 + (idx - 1) * 0.115
	districtLabels[distId] = makeLabel(
		mapPanel,
		"ZoneRow_" .. distId,
		UDim2.new(0.92, 0, 0.10, 0),
		UDim2.new(0.04, 0, yPos, 0),
		string.format("%s: Amenaza %d / %d", distId, cfg.initialThreat, cfg.maxThreat),
		Color3.fromRGB(226, 232, 240),
		13
	)
end

--------------------------------------------------------------------------------
-- 4. BARRA INFERIOR: ARMERÍA MODULAR (LV1–10), EXTRACCIÓN Y HABILIDADES
--------------------------------------------------------------------------------

local bottomBar = Instance.new("Frame")
bottomBar.Name = "TacticalHolsterBar"
bottomBar.Size = UDim2.new(0.68, 0, 0.11, 0)
bottomBar.Position = UDim2.new(0.16, 0, 0.86, 0)
styleFrame(bottomBar, Color3.fromRGB(16, 20, 26), Color3.fromRGB(72, 187, 120), 10)
bottomBar.Parent = screenGui

local activeWeaponLabel = makeLabel(
	bottomBar,
	"ActiveWeaponLabel",
	UDim2.new(0.46, 0, 0.45, 0),
	UDim2.new(0.02, 0, 0.08, 0),
	"ARMA ACTIVA [Q]: Rifle de Asalto AK-74 / M4 (G-05) — Lv.1",
	Color3.fromRGB(255, 255, 255),
	15
)

local controlsHintLabel = makeLabel(
	bottomBar,
	"ControlsHintLabel",
	UDim2.new(0.46, 0, 0.40, 0),
	UDim2.new(0.02, 0, 0.54, 0),
	"[Z] Pulso Conciencia | [Shift] Dash 0.3s | [G] Emisor G-20 | [F] Melee/QTE",
	Color3.fromRGB(160, 174, 192),
	12
)

local function createActionButton(
	name: string,
	text: string,
	pos: UDim2,
	bgColor: Color3,
	onClick: () -> ()
): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(0.15, 0, 0.72, 0)
	btn.Position = pos
	btn.BackgroundColor3 = bgColor
	btn.Font = Enum.Font.BuilderSansExtraBold
	btn.Text = text
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextSize = 13
	btn.Parent = bottomBar

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = btn

	btn.Activated:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundTransparency = 0.3 }):Play()
		task.delay(0.1, function()
			TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundTransparency = 0 }):Play()
		end)
		onClick()
	end)
	return btn
end

createActionButton("UpgradeWeaponBtn", "MEJORAR ARMA", UDim2.new(0.50, 0, 0.14, 0), Color3.fromRGB(49, 130, 206), function()
	local wId = (localPlayer:GetAttribute("ZA_ActiveWeaponId") :: string?) or "G-05"
	arsenalActionRemote:FireServer("UpgradeWeapon", wId)
end)

createActionButton("SalvageWeaponBtn", "REFUNDIR 80%", UDim2.new(0.665, 0, 0.14, 0), Color3.fromRGB(214, 158, 46), function()
	local wId = (localPlayer:GetAttribute("ZA_ActiveWeaponId") :: string?) or "G-05"
	arsenalActionRemote:FireServer("SalvageWeapon", wId)
end)

createActionButton("ExtractOrLabBtn", "EXTRAER / LAB A06", UDim2.new(0.83, 0, 0.14, 0), Color3.fromRGB(56, 161, 105), function()
	combatActionRemote:FireServer("ExtractVault")
	arsenalActionRemote:FireServer("UpgradeBuilding", "A-06")
end)

--------------------------------------------------------------------------------
-- 5. SINCRONIZACIÓN REACTIVA DE ATRIBUTOS Y EVENTOS
--------------------------------------------------------------------------------

eventAlertRemote.OnClientEvent:Connect(function(payload: any)
	if type(payload) == "table" then
		eventTickerLabel.Text = string.format(
			"[%s] %s (%s): %s",
			tostring(payload.eventId),
			tostring(payload.name),
			tostring(payload.districtId),
			tostring(payload.message)
		)
	end
end)

local lastHudUpdate = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if (now - lastHudUpdate) < 0.25 then
		return
	end
	lastHudUpdate = now

	local scrap = (localPlayer:GetAttribute("ZA_Scrap") :: number?) or 250
	local comp = (localPlayer:GetAttribute("ZA_Components") :: number?) or 15
	local cores = (localPlayer:GetAttribute("ZA_Cores") :: number?) or 1
	local unScrap = (localPlayer:GetAttribute("ZA_UnsecuredScrap") :: number?) or 0
	local unComp = (localPlayer:GetAttribute("ZA_UnsecuredComponents") :: number?) or 0
	local unCores = (localPlayer:GetAttribute("ZA_UnsecuredCores") :: number?) or 0
	local g20Tier = (localPlayer:GetAttribute("ZA_G20Tier") :: number?) or 0
	local loyalty = (localPlayer:GetAttribute("ZA_HumanLoyalty") :: number?) or 25

	vaultLabel.Text = string.format("BÓVEDA SEGURA: %d Chatarra | %d Componentes | %d Núcleos", scrap, comp, cores)
	backpackLabel.Text = string.format(
		"MOCHILA TÁCTICA (Extraer en Z0/Puesto): +%d Chat | +%d Comp | +%d Núc",
		unScrap,
		unComp,
		unCores
	)
	statusSubLabel.Text = string.format(
		"Emisor G-20: %s | Lealtad Humana: %d | Semilla: %s",
		if g20Tier > 0 then ("Mk." .. tostring(g20Tier) .. " Activo") else "Bloqueado (Mejorar Lab A-06)",
		loyalty,
		tostring(Workspace:GetAttribute("ZA_ActiveSeed") or "ZA40SEED")
	)

	-- Actualizar Crisoles y Mega Bruto Líder
	local westPts = (Workspace:GetAttribute("ZA_WestCruciblePoints") :: number?) or 0
	local eastPts = (Workspace:GetAttribute("ZA_EastCruciblePoints") :: number?) or 0
	local mutexLocked = Workspace:GetAttribute("ZA_ServerBossMutex") == true
	local bossId = (Workspace:GetAttribute("ZA_ActiveMegaBossId") :: string?) or ""
	local bossHp = (Workspace:GetAttribute("ZA_ActiveMegaBossHp") :: number?) or 0
	local bossMaxHp = (Workspace:GetAttribute("ZA_ActiveMegaBossMaxHp") :: number?) or 0

	crucibleMutexLabel.Text = string.format(
		"CRISOLES ZvM — Oeste: %d/1000 | Este: %d/1000 | Mutex: %s",
		westPts,
		eastPts,
		if mutexLocked then "BLOQUEO 99% ACTIVO" else "LIBRE"
	)

	if bossId ~= "" and bossHp > 0 then
		bossHpLabel.Text = string.format("MEGA BRUTO ACTIVO [%s]: %d / %d HP", bossId, bossHp, bossMaxHp)
		bossHpLabel.TextColor3 = Color3.fromRGB(252, 129, 129)
	else
		bossHpLabel.Text = "MEGA BRUTO LÍDER: Ninguno activo en el servidor"
		bossHpLabel.TextColor3 = Color3.fromRGB(104, 211, 145)
	end

	-- Actualizar Mapa de Conciencia (Z1..Z7)
	for _, distId in ipairs(orderedZones) do
		local lbl = districtLabels[distId]
		local cfg = ZombieCatalogs.Districts[distId]
		local threat = (Workspace:GetAttribute("ZA_Threat_" .. distId) :: number?) or cfg.initialThreat
		local liberated = Workspace:GetAttribute("ZA_Liberated_" .. distId) == true
		if lbl then
			if liberated then
				lbl.Text = string.format("%s (%s): [LIBERADO — AMENAZA 0]", distId, string.sub(cfg.name, 1, 18))
				lbl.TextColor3 = Color3.fromRGB(104, 211, 145)
			else
				lbl.Text = string.format("%s: Amenaza %d / %d (+5/min)", distId, threat, cfg.maxThreat)
				lbl.TextColor3 = if threat >= cfg.maxThreat * 0.75
					then Color3.fromRGB(252, 129, 129)
					else Color3.fromRGB(226, 232, 240)
			end
		end
	end

	-- Actualizar etiqueta de arma activa
	local wId = (localPlayer:GetAttribute("ZA_ActiveWeaponId") :: string?) or "G-05"
	local wDef = ZombieCatalogs.Weapons[wId]
	if wDef then
		activeWeaponLabel.Text = string.format(
			"ARMA ACTIVA [Q]: %s (%s) — Daño Base %d | Alcance %d st",
			wDef.name,
			wDef.id,
			wDef.baseDamage,
			wDef.rangeStuds
		)
	end
end)
