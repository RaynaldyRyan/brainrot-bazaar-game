-- Brainrot Bazaar client: the ScreenGui over the 3D world. It shows the
-- player's money, income per second, rebirths, the tsunami countdown, the
-- shop list of the whole cast, the base slots, and the buttons that ask the
-- server to place a carried brainrot, lock the base, or rebirth. The client
-- never owns money or brainrots: every button fires a RemoteEvent and the
-- server decides. The 3D world itself (character, camera, bazaar) is the
-- default Roblox one — this script is only the interface on top of it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotData"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("BrainrotRemotes")
local PlaceEvent = Remotes:WaitForChild("PlaceBrainrot")
local LockEvent = Remotes:WaitForChild("LockBase")
local RebirthEvent = Remotes:WaitForChild("RebirthPlayer")
local StateEvent = Remotes:WaitForChild("GameState")
local CatchEvent = Remotes:WaitForChild("CatchBrainrot")

-- Latest snapshot from the server; the HUD redraws from this table.
local latestState = {
	money = BrainrotData.START_CASH,
	income = 0,
	rebirths = 0,
	lifetime = 0,
	slots = BrainrotData.START_SLOTS,
	placed = {},
	carried = nil,
	lockedUntil = 0,
	tsunamiIn = BrainrotData.TSUNAMI_FIRST_DELAY,
	tsunamiWarning = false,
	nextTier = "Rare",
	nextTierAt = 500,
}

local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotBazaarGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

--- Make a TextLabel with the game's chunky look.
local function makeLabel(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, textSize: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextSize = textSize
	label.Font = Enum.Font.GothamBold
	label.TextStrokeTransparency = 0.6
	label.Parent = parent
	return label
end

--- Make a button that fires one RemoteEvent when clicked.
local function makeButton(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = color
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 20
	button.Font = Enum.Font.GothamBold
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	return button
end

-- Top bar: money, income, rebirths. Kept clear of the top-left corner,
-- where Roblox's own menu buttons sit over the play view.
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.AnchorPoint = Vector2.new(0.5, 0)
topBar.Position = UDim2.new(0.5, 0, 0, 48)
topBar.Size = UDim2.new(0, 640, 0, 64)
topBar.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
topBar.BackgroundTransparency = 0.25
topBar.BorderSizePixel = 0
topBar.Parent = gui
local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 12)
topCorner.Parent = topBar

local moneyLabel = makeLabel(topBar, "MoneyLabel", "$500", UDim2.new(0.5, 0, 0, 6), UDim2.new(0, 16, 0, 0), 30, Color3.fromRGB(120, 255, 120))
local incomeLabel = makeLabel(topBar, "IncomeLabel", "+$0/s", UDim2.new(0.5, 0, 0, 6), UDim2.new(0.5, 0, 0, 0), 22, Color3.fromRGB(255, 255, 255))
local rebirthLabel = makeLabel(topBar, "RebirthLabel", "Rebirths: 0", UDim2.new(0, 0, 0, 0), UDim2.new(0, 0, 0, 0), 18, Color3.fromRGB(255, 215, 0))
rebirthLabel.Position = UDim2.new(1, -130, 0, 34)
rebirthLabel.Size = UDim2.new(0, 120, 0, 24)
rebirthLabel.TextXAlignment = Enum.TextXAlignment.Right

-- Tsunami banner: hidden until the warning, then big and red.
local tsunamiBanner = Instance.new("Frame")
tsunamiBanner.Name = "TsunamiBanner"
tsunamiBanner.AnchorPoint = Vector2.new(0.5, 0)
tsunamiBanner.Position = UDim2.new(0.5, 0, 0, 122)
tsunamiBanner.Size = UDim2.new(0, 560, 0, 52)
tsunamiBanner.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
tsunamiBanner.Visible = false
tsunamiBanner.Parent = gui
local bannerCorner = Instance.new("UICorner")
bannerCorner.CornerRadius = UDim.new(0, 12)
bannerCorner.Parent = tsunamiBanner
local tsunamiLabel = makeLabel(tsunamiBanner, "TsunamiLabel", "TSUNAMI INCOMING!", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), 26, Color3.fromRGB(255, 255, 255))

-- Carried banner: what the player is carrying home, and the Place button.
local carriedFrame = Instance.new("Frame")
carriedFrame.Name = "CarriedFrame"
carriedFrame.AnchorPoint = Vector2.new(0.5, 1)
carriedFrame.Position = UDim2.new(0.5, 0, 1, -24)
carriedFrame.Size = UDim2.new(0, 520, 0, 64)
carriedFrame.BackgroundColor3 = Color3.fromRGB(20, 60, 90)
carriedFrame.Visible = false
carriedFrame.Parent = gui
local carriedCorner = Instance.new("UICorner")
carriedCorner.CornerRadius = UDim.new(0, 12)
carriedCorner.Parent = carriedFrame
local carriedLabel = makeLabel(carriedFrame, "CarriedLabel", "Carrying: -", UDim2.new(0.7, 0, 1, 0), UDim2.new(0, 12, 0, 0), 20, Color3.fromRGB(255, 255, 255))
local placeButton = makeButton(carriedFrame, "PlaceButton", "PLACE ON BASE", UDim2.new(0.28, 0, 0.7, 0), UDim2.new(0.7, 0, 0.15, 0), Color3.fromRGB(0, 170, 90))
placeButton.MouseButton1Click:Connect(function()
	PlaceEvent:FireServer()
end)

-- Action buttons, bottom right: lock the base, rebirth.
local lockButton = makeButton(gui, "LockButton", "LOCK BASE ($2,000)", UDim2.new(0, 220, 0, 48), UDim2.new(1, -240, 1, -140), Color3.fromRGB(40, 90, 200))
lockButton.MouseButton1Click:Connect(function()
	LockEvent:FireServer()
end)
local rebirthButton = makeButton(gui, "RebirthButton", "REBIRTH ($100K earned)", UDim2.new(0, 220, 0, 48), UDim2.new(1, -240, 1, -84), Color3.fromRGB(170, 60, 200))
rebirthButton.MouseButton1Click:Connect(function()
	RebirthEvent:FireServer()
end)

-- Shop panel, left side: the whole cast, cheapest first, with rarity and rate.
local shopFrame = Instance.new("ScrollingFrame")
shopFrame.Name = "ShopPanel"
shopFrame.Position = UDim2.new(0, 12, 0, 190)
shopFrame.Size = UDim2.new(0, 250, 0, 320)
shopFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
shopFrame.BackgroundTransparency = 0.25
shopFrame.BorderSizePixel = 0
shopFrame.ScrollBarThickness = 6
shopFrame.CanvasSize = UDim2.new(0, 0, 0, #BrainrotData.CAST * 44)
shopFrame.Parent = gui
local shopCorner = Instance.new("UICorner")
shopCorner.CornerRadius = UDim.new(0, 12)
shopCorner.Parent = shopFrame

local shopTitle = makeLabel(shopFrame, "ShopTitle", "BRAINROT SHOP — click one on the belt!", UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 0), 15, Color3.fromRGB(255, 215, 0))
shopTitle.TextWrapped = true

local shopRows: { TextLabel } = {}
for i, entry in ipairs(BrainrotData.CAST) do
	local rarity = BrainrotData.getRarity(entry.rarity)
	local row = makeLabel(
		shopFrame,
		"ShopRow" .. tostring(i),
		entry.name .. "  " .. entry.rarity .. "  " .. BrainrotData.formatMoney(entry.cost) .. "  $" .. tostring(entry.rate) .. "/s",
		UDim2.new(1, -8, 0, 36),
		UDim2.new(0, 4, 0, 28 + (i - 1) * 44),
		14,
		rarity.color
	)
	row.TextXAlignment = Enum.TextXAlignment.Left
	table.insert(shopRows, row)
end

-- Base panel, right side: which slots are filled and what they earn.
local baseFrame = Instance.new("Frame")
baseFrame.Name = "BasePanel"
baseFrame.Position = UDim2.new(1, -262, 0, 190)
baseFrame.Size = UDim2.new(0, 250, 0, 320)
baseFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
baseFrame.BackgroundTransparency = 0.25
baseFrame.BorderSizePixel = 0
baseFrame.Parent = gui
local baseCorner = Instance.new("UICorner")
baseCorner.CornerRadius = UDim.new(0, 12)
baseCorner.Parent = baseFrame
local baseTitle = makeLabel(baseFrame, "BaseTitle", "MY BASE", UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 0), 18, Color3.fromRGB(0, 255, 220))
local baseBody = makeLabel(baseFrame, "BaseBody", "No brainrots yet!", UDim2.new(1, -16, 0, 240), UDim2.new(0, 8, 0, 34), 15, Color3.fromRGB(255, 255, 255))
baseBody.TextWrapped = true
baseBody.TextYAlignment = Enum.TextYAlignment.Top
baseBody.TextXAlignment = Enum.TextXAlignment.Left
local tierLabel = makeLabel(baseFrame, "TierLabel", "Next tier: Rare", UDim2.new(1, -16, 0, 30), UDim2.new(0, 8, 0, 282), 15, Color3.fromRGB(255, 215, 0))

-- Notifications feed, bottom left: the last few server messages.
local noticeFrame = Instance.new("Frame")
noticeFrame.Name = "NoticeFeed"
noticeFrame.Position = UDim2.new(0, 12, 1, -190)
noticeFrame.Size = UDim2.new(0, 380, 0, 160)
noticeFrame.BackgroundTransparency = 1
noticeFrame.Parent = gui
local noticeLabels: { TextLabel } = {}
for i = 1, 4 do
	local label = makeLabel(noticeFrame, "Notice" .. tostring(i), "", UDim2.new(1, 0, 0, 36), UDim2.new(0, 0, 0, (i - 1) * 40), 15, Color3.fromRGB(255, 255, 255))
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	table.insert(noticeLabels, label)
end
local notices: { string } = {}

--- Push a server message onto the notifications feed.
local function pushNotice(text: string)
	table.insert(notices, 1, text)
	while #notices > 4 do
		table.remove(notices)
	end
	for i, label in ipairs(noticeLabels) do
		label.Text = notices[i] or ""
	end
end

--- Redraw every HUD element from the latest server snapshot.
local function refreshHud()
	moneyLabel.Text = BrainrotData.formatMoney(latestState.money)
	incomeLabel.Text = "+$" .. tostring(math.floor(latestState.income + 0.5)) .. "/s"
	rebirthLabel.Text = "Rebirths: " .. tostring(latestState.rebirths)
	if latestState.tsunamiWarning then
		tsunamiBanner.Visible = true
		tsunamiLabel.Text = "TSUNAMI INCOMING — DASH HOME! " .. tostring(latestState.tsunamiIn) .. "s"
	elseif latestState.tsunamiIn <= 20 then
		tsunamiBanner.Visible = true
		tsunamiLabel.Text = "Tsunami in " .. tostring(latestState.tsunamiIn) .. "s — keep your catch on base!"
		tsunamiBanner.BackgroundColor3 = Color3.fromRGB(200, 120, 20)
	else
		tsunamiBanner.Visible = false
	end
	if latestState.carried ~= nil then
		carriedFrame.Visible = true
		carriedLabel.Text = "Carrying: " .. latestState.carried.name .. " (" .. latestState.carried.mutation .. " " .. latestState.carried.rarity .. ")  $" .. tostring(math.floor(latestState.carried.rate + 0.5)) .. "/s"
	else
		carriedFrame.Visible = false
	end
	if #latestState.placed == 0 then
		baseBody.Text = "No brainrots yet!\nBuy one on the conveyor,\nthen carry it home."
	else
		local lines = {}
		for _, placed in ipairs(latestState.placed) do
			table.insert(lines, "Slot " .. tostring(placed.slot) .. ": " .. placed.name .. "  $" .. tostring(math.floor(placed.rate + 0.5)) .. "/s")
		end
		baseBody.Text = table.concat(lines, "\n")
	end
	if latestState.nextTier ~= nil then
		tierLabel.Text = "Next tier: " .. latestState.nextTier .. " (earn " .. BrainrotData.formatMoney(latestState.nextTierAt) .. " lifetime)"
	else
		tierLabel.Text = "Top tier reached — you own the bazaar!"
	end
	lockButton.Text = if latestState.lockedUntil > 0 then "BASE LOCKED" else "LOCK BASE ($2,000)"
end

-- The server sends a full snapshot every second, and notices in between.
StateEvent.OnClientEvent:Connect(function(state)
	if state.notice ~= nil then
		pushNotice(state.notice)
		return
	end
	latestState = state
	refreshHud()
end)

CatchEvent.OnClientEvent:Connect(function(info)
	pushNotice("Wild catch! " .. tostring(info.clicks) .. "/3 clicks — keep clicking it!")
end)

pushNotice("Welcome to Brainrot Bazaar! Walk the 3D bazaar, click a brainrot on the conveyor, carry it home!")
refreshHud()
print("Brainrot Bazaar client ready: HUD, shop, base panel and tsunami banner live.")
