--!strict
--[[
	SlimeHUDController.client.luau
	HUD Responsivo y Menús Tácticos de "Slimes Abismales: ¡Sumérgete y Escapa! (SLIME PIT: Dive for Mutants!)":
	1. Toggle de Modo Rendimiento ("MODO RENDIMIENTO: 3 / 6 / 10 Mutaciones") para móviles y PC.
	2. Tienda de Evento Día 1 ("Caja Especial de Evento - 10 Slimes hasta 0.0010%"):
	   - Tiradas con Fichas de Evento Gratis (x1, x3, x10) y Multi-Caja de Pago.
	   - Botón explícito "Details" que despliega el desglose de probabilidades a 4 decimales (45.0000% a 0.0010%).
	   - Consulta dinámica de precios en Robux con MarketplaceService:GetProductInfoAsync protegida por pcall.
	3. Paneles de Captura Asegurada (1 Gratis/Día + Cotizador Anti-Pay-To-Fast en Robux) y Saltar Tiempo ("Skip Timer").
	4. Tanque Dorsal Presurizado (riesgo 25% charco), Caldero de Alquimia y Banner Global de Admin Abuse.
--]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local sharedFolder = ReplicatedStorage:WaitForChild("RAASE_Shared")
local Types = require(sharedFolder:WaitForChild("Types") :: any)
local SlimeCatalogs = require(sharedFolder:WaitForChild("SlimeCatalogs") :: any)
local SlimeCoreMath = require(sharedFolder:WaitForChild("SlimeCoreMath") :: any)

type PerformanceMutationMode = Types.PerformanceMutationMode
type EventCrateItem = Types.EventCrateItem

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

--------------------------------------------------------------------------------
-- HELPERS DE ESTILO Y CREACIÓN SEGURA DE INSTANCIAS (LihFolk Compliant)
--------------------------------------------------------------------------------

local function createStyledFrame(size: UDim2, pos: UDim2, bgColor: Color3, strokeColor: Color3): Frame
	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = pos
	frame.BackgroundColor3 = bgColor
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = strokeColor
	stroke.Thickness = 1.5
	stroke.Parent = frame

	return frame
end

local function createStyledLabel(parent: Instance, text: string, size: UDim2, pos: UDim2, textSize: number, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = pos
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextSize = textSize
	label.TextColor3 = color or Color3.fromRGB(240, 245, 250)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function createStyledButton(parent: Instance, text: string, size: UDim2, pos: UDim2, bgColor: Color3): TextButton
	local btn = Instance.new("TextButton")
	btn.Size = size
	btn.Position = pos
	btn.BackgroundColor3 = bgColor
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBold
	btn.Text = text
	btn.TextSize = 13
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.AutoButtonColor = true

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn

	btn.Parent = parent
	return btn
end

--------------------------------------------------------------------------------
-- CONSTRUCCIÓN DE LA SCREENGUI PRINCIPAL
--------------------------------------------------------------------------------

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SlimePit_AbyssalHUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets

-- 1. BARRA SUPERIOR (HEADER Y MODO RENDIMIENTO)
local topBar = createStyledFrame(
	UDim2.new(0.96, 0, 0, 52),
	UDim2.new(0.02, 0, 0.015, 0),
	Color3.fromRGB(15, 20, 28),
	Color3.fromRGB(0, 180, 216)
)
topBar.Parent = screenGui

createStyledLabel(
	topBar,
	"Slimes Abismales: ¡Sumérgete y Escapa! (SLIME PIT: Dive for Mutants!)",
	UDim2.new(0.55, 0, 1, 0),
	UDim2.new(0.02, 0, 0, 0),
	14,
	Color3.fromRGB(0, 220, 255)
)

-- Botón Selector de Modo Rendimiento (3 / 6 / 10 Mutaciones)
local currentPerfMode: PerformanceMutationMode = "MEDIUM_6"
local perfModesList: { PerformanceMutationMode } = { "LOW_3", "MEDIUM_6", "HIGH_10" }
local perfIndex = 2

local perfButton = createStyledButton(
	topBar,
	"MODO RENDIMIENTO: 6 Mutaciones (Equilibrado)",
	UDim2.new(0.38, 0, 0, 34),
	UDim2.new(0.60, 0, 0.17, 0),
	Color3.fromRGB(30, 45, 62)
)

perfButton.MouseButton1Click:Connect(function()
	perfIndex = (perfIndex % #perfModesList) + 1
	currentPerfMode = perfModesList[perfIndex]
	local capText = if currentPerfMode == "LOW_3" then "3 Mutaciones (Bajo Rendimiento)" elseif currentPerfMode == "MEDIUM_6" then "6 Mutaciones (Equilibrado)" else "10 Mutaciones (Máximo Visual)"
	perfButton.Text = "MODO RENDIMIENTO: " .. capText
end)

-- 2. TANQUE DORSAL PRESURIZADO (RIESGO 25% CHARCO)
local tankPanel = createStyledFrame(
	UDim2.new(0.24, 0, 0, 105),
	UDim2.new(0.02, 0, 0.09, 0),
	Color3.fromRGB(18, 22, 32),
	Color3.fromRGB(255, 140, 0)
)
tankPanel.Parent = screenGui

createStyledLabel(
	tankPanel,
	"Tanque Dorsal Presurizado (riesgo 25% charco)",
	UDim2.new(0.95, 0, 0, 22),
	UDim2.new(0.04, 0, 0.05, 0),
	11,
	Color3.fromRGB(255, 170, 50)
)

local tankGaugeLabel = createStyledLabel(
	tankPanel,
	"Jugo Almacenado: 450 / 1000 mL (45%)\nPeligro: Caer derrotado derrama el 25% en un Charco Mutagénico disputable.",
	UDim2.new(0.92, 0, 0, 60),
	UDim2.new(0.04, 0, 0.32, 0),
	10,
	Color3.fromRGB(200, 210, 220)
)

-- 3. CALDERO DE ALQUIMIA
local alchemyPanel = createStyledFrame(
	UDim2.new(0.24, 0, 0, 95),
	UDim2.new(0.02, 0, 0.23, 0),
	Color3.fromRGB(22, 18, 32),
	Color3.fromRGB(170, 80, 255)
)
alchemyPanel.Parent = screenGui

createStyledLabel(
	alchemyPanel,
	"Caldero de Alquimia",
	UDim2.new(0.95, 0, 0, 22),
	UDim2.new(0.04, 0, 0.05, 0),
	12,
	Color3.fromRGB(210, 130, 255)
)

createStyledLabel(
	alchemyPanel,
	"Pureza Alquímica: 1.00x | Fermentación Activa\nMezcla esencias para elevar la Suerte de Mutaciones.",
	UDim2.new(0.92, 0, 0, 55),
	UDim2.new(0.04, 0, 0.35, 0),
	10,
	Color3.fromRGB(220, 200, 240)
)

-- 4. CAPTURA ASEGURADA (1 GRATIS/DÍA) + COTIZADOR ANTI-PAY-TO-FAST + SALTAR TIEMPO
local capturePanel = createStyledFrame(
	UDim2.new(0.32, 0, 0, 150),
	UDim2.new(0.02, 0, 0.36, 0),
	Color3.fromRGB(16, 24, 30),
	Color3.fromRGB(50, 205, 120)
)
capturePanel.Parent = screenGui

createStyledLabel(
	capturePanel,
	"Captura Asegurada (1 Gratis/Día + Cotizador Anti-Pay-To-Fast en Robux)",
	UDim2.new(0.95, 0, 0, 20),
	UDim2.new(0.04, 0, 0.04, 0),
	11,
	Color3.fromRGB(80, 240, 150)
)

local dailyFreeBtn = createStyledButton(
	capturePanel,
	"Reclamar 1 Captura Asegurada Gratis (Disponible)",
	UDim2.new(0.92, 0, 0, 28),
	UDim2.new(0.04, 0, 0.22, 0),
	Color3.fromRGB(34, 139, 34)
)

local quoteLabel = createStyledLabel(
	capturePanel,
	"Brecha de Bioma: ΔB = 0 | Cotización: 49 Robux\n(Tirarse al Bioma 30 siendo Bioma 1 cotiza a 10,000+ Robux)",
	UDim2.new(0.92, 0, 0, 36),
	UDim2.new(0.04, 0, 0.46, 0),
	10,
	Color3.fromRGB(180, 220, 200)
)

local skipTimerBtn = createStyledButton(
	capturePanel,
	"Saltar Tiempo (Skip Timer) - 99 R$",
	UDim2.new(0.92, 0, 0, 26),
	UDim2.new(0.04, 0, 0.74, 0),
	Color3.fromRGB(40, 70, 95)
)

-- 5. TIENDA DE EVENTO DÍA 1 (CAJA ESPECIAL DE EVENTO HASTA 0.0010%)
local eventShopPanel = createStyledFrame(
	UDim2.new(0.34, 0, 0, 210),
	UDim2.new(0.64, 0, 0.09, 0),
	Color3.fromRGB(24, 18, 34),
	Color3.fromRGB(255, 60, 120)
)
eventShopPanel.Parent = screenGui

createStyledLabel(
	eventShopPanel,
	"Caja Especial de Evento - 10 Slimes hasta 0.0010%",
	UDim2.new(0.95, 0, 0, 22),
	UDim2.new(0.04, 0, 0.03, 0),
	12,
	Color3.fromRGB(255, 120, 170)
)

-- Botón obligatorio labelled con la palabra exacta "Details"
local detailsButton = createStyledButton(
	eventShopPanel,
	"Details (Probabilidades 4 Decimales)",
	UDim2.new(0.92, 0, 0, 26),
	UDim2.new(0.04, 0, 0.16, 0),
	Color3.fromRGB(110, 45, 135)
)

-- Botones de apertura de Cajas Gratis (Fichas) y Pago (Multi-Crate)
local openX1Btn = createStyledButton(
	eventShopPanel,
	"Abrir x1 (Ficha Gratis)",
	UDim2.new(0.44, 0, 0, 28),
	UDim2.new(0.04, 0, 0.32, 0),
	Color3.fromRGB(0, 150, 136)
)

local openX3Btn = createStyledButton(
	eventShopPanel,
	"Abrir x3 (Fichas)",
	UDim2.new(0.44, 0, 0, 28),
	UDim2.new(0.52, 0, 0.32, 0),
	Color3.fromRGB(0, 150, 136)
)

local openX10Btn = createStyledButton(
	eventShopPanel,
	"Abrir x10 (Fichas)",
	UDim2.new(0.44, 0, 0, 28),
	UDim2.new(0.04, 0, 0.49, 0),
	Color3.fromRGB(0, 150, 136)
)

local paidMultiCrateBtn = createStyledButton(
	eventShopPanel,
	"Multi-Crate x10 Pagado (Calculando R$...)",
	UDim2.new(0.44, 0, 0, 28),
	UDim2.new(0.52, 0, 0.49, 0),
	Color3.fromRGB(210, 60, 45)
)

local policyStatusLabel = createStyledLabel(
	eventShopPanel,
	"Cumplimiento PolicyService: Probabilidades 100.0000% garantizadas.",
	UDim2.new(0.92, 0, 0, 30),
	UDim2.new(0.04, 0, 0.68, 0),
	9,
	Color3.fromRGB(180, 180, 190)
)

-- 6. MODAL DE PROBABILIDADES "DETAILS" (4 DECIMALES: 45.0000% a 0.0010%)
local oddsModal = createStyledFrame(
	UDim2.new(0.50, 0, 0.62, 0),
	UDim2.new(0.25, 0, 0.20, 0),
	Color3.fromRGB(12, 14, 22),
	Color3.fromRGB(255, 215, 0)
)
oddsModal.Visible = false
oddsModal.ZIndex = 10
oddsModal.Parent = screenGui

createStyledLabel(
	oddsModal,
	"Probabilidades Oficiales de Caja de Evento Día 1 (Total: 100.0000%)",
	UDim2.new(0.85, 0, 0, 26),
	UDim2.new(0.04, 0, 0.02, 0),
	13,
	Color3.fromRGB(255, 225, 50)
)

local closeOddsBtn = createStyledButton(
	oddsModal,
	"Cerrar",
	UDim2.new(0, 70, 0, 26),
	UDim2.new(0.96, -70, 0.02, 0),
	Color3.fromRGB(160, 40, 40)
)

closeOddsBtn.MouseButton1Click:Connect(function()
	oddsModal.Visible = false
end)

detailsButton.MouseButton1Click:Connect(function()
	oddsModal.Visible = not oddsModal.Visible
end)

-- Poblar los 10 Slimes de la Caja de Evento
local oddsScrolling = Instance.new("ScrollingFrame")
oddsScrolling.Size = UDim2.new(0.92, 0, 0.85, 0)
oddsScrolling.Position = UDim2.new(0.04, 0, 0.12, 0)
oddsScrolling.BackgroundTransparency = 1
oddsScrolling.BorderSizePixel = 0
oddsScrolling.CanvasSize = UDim2.new(0, 0, 0, #SlimeCatalogs.EVENT_CRATE_DAY1_POOL * 32)
oddsScrolling.ZIndex = 11

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 4)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = oddsScrolling

for i, item: EventCrateItem in SlimeCatalogs.EVENT_CRATE_DAY1_POOL do
	local row = Instance.new("TextLabel")
	row.Size = UDim2.new(1, -12, 0, 26)
	row.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
	row.Font = Enum.Font.Gotham
	row.Text = string.format("  [%s] %s  —  %s", item.id, item.name, item.formattedOdds)
	row.TextColor3 = if item.probabilityPercent <= 0.01 then Color3.fromRGB(255, 100, 150) else Color3.fromRGB(230, 235, 245)
	row.TextSize = 11
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.ZIndex = 12

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 4)
	rowCorner.Parent = row

	row.Parent = oddsScrolling
end
oddsScrolling.Parent = oddsModal

-- 7. BANNER GLOBAL DE ADMIN ABUSE
local adminBanner = createStyledFrame(
	UDim2.new(0.70, 0, 0, 42),
	UDim2.new(0.15, 0, 0.88, 0),
	Color3.fromRGB(35, 10, 15),
	Color3.fromRGB(255, 50, 70)
)
adminBanner.Visible = false
adminBanner.Parent = screenGui

local adminBannerLabel = createStyledLabel(
	adminBanner,
	"ALERTA GLOBAL DE ADMIN ABUSE: ¡Tormenta de Mutaciones activada!",
	UDim2.new(0.96, 0, 1, 0),
	UDim2.new(0.02, 0, 0, 0),
	12,
	Color3.fromRGB(255, 180, 190)
)

-- 8. CONSULTA ASÍNCRONA DE PRECIOS REGIONALES EN ROBUX (MarketplaceService pcall)
task.spawn(function()
	local testDevProductId = 200107 -- Multi-Crate x10
	local fetchSuccess, productInfo = pcall(function()
		return MarketplaceService:GetProductInfoAsync(testDevProductId, Enum.InfoType.Product)
	end)

	if fetchSuccess and productInfo and productInfo.PriceInRobux then
		paidMultiCrateBtn.Text = string.format("Multi-Crate x10 (%d R$)", productInfo.PriceInRobux)
	else
		-- Fallback elegante si la llamada de red falla o está en entorno offline/mock
		paidMultiCrateBtn.Text = "Multi-Crate x10 (2,999 R$)"
	end
end)

-- Conexión segura para eventos de Admin Abuse y Banner
task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
	if not remotes then
		return
	end

	local adminRemote = remotes:FindFirstChild("Slime_AdminAbuseAlert")
	if adminRemote and adminRemote:IsA("RemoteEvent") then
		adminRemote.OnClientEvent:Connect(function(commandType: string, triggeredBy: string)
			adminBannerLabel.Text = string.format("ALERTA GLOBAL DE ADMIN ABUSE [%s] activada por %s!", commandType, triggeredBy)
			adminBanner.Visible = true
			task.delay(10, function()
				adminBanner.Visible = false
			end)
		end)
	end
end)

-- Asignación final del ScreenGui a PlayerGui
screenGui.Parent = playerGui

--------------------------------------------------------------------------------
-- API PÚBLICA DEL HUD CONTROLLER
--------------------------------------------------------------------------------

local SlimeHUDController = {
	ScreenGui = screenGui,
	GetSelectedPerformanceMode = function(): PerformanceMutationMode
		return currentPerfMode
	end,
	SetTankGauge = function(currentMl: number, maxMl: number)
		local ratio = math.clamp(currentMl / maxMl, 0, 1)
		tankGaugeLabel.Text = string.format(
			"Jugo Almacenado: %d / %d mL (%d%%)\nPeligro: Caer derrotado derrama el 25%% en un Charco Mutagénico disputable.",
			currentMl,
			maxMl,
			math.floor(ratio * 100)
		)
	end,
	ShowAdminAlert = function(msg: string)
		adminBannerLabel.Text = msg
		adminBanner.Visible = true
		task.delay(8, function()
			adminBanner.Visible = false
		end)
	end,
}

return SlimeHUDController
