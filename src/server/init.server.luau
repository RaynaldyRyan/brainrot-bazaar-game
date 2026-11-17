-- Brainrot Bazaar server: the whole game loop. A player joins with starter
-- cash, brainrots parade down the central conveyor, the player clicks one to
-- buy it, carries it home to their base, places it on a slot, and it earns
-- money every second. A tsunami sweeps the plaza on a timer, a rival stealer
-- tries to snatch placed brainrots, and rebirths multiply all income.
-- Client talks to this script only through the RemoteEvents in
-- ReplicatedStorage.BrainrotRemotes; all money and ownership live here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local BrainrotData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotData"))
local BrainrotWorld = require(script:WaitForChild("BrainrotWorld"))
local WorldBuilder = require(script:WaitForChild("WorldBuilder"))
local LAYOUT = WorldBuilder.LAYOUT

-- Build the map first: every zone, base and path below is placed by it.
WorldBuilder.buildWorld()

local Remotes = ReplicatedStorage:WaitForChild("BrainrotRemotes")
local BuyEvent = Remotes:WaitForChild("BuyBrainrot")
local CatchEvent = Remotes:WaitForChild("CatchBrainrot")
local PlaceEvent = Remotes:WaitForChild("PlaceBrainrot")
local LockEvent = Remotes:WaitForChild("LockBase")
local RebirthEvent = Remotes:WaitForChild("RebirthPlayer")
local SlapEvent = Remotes:WaitForChild("SlapStealer")
local StateEvent = Remotes:WaitForChild("GameState")

-- Gameplay coordinates, all read from the world builder's LAYOUT so the
-- logic and the map can never drift apart again.
local MY_BASE_CENTER = LAYOUT.myBaseCenter
local MY_BASE_SIZE = LAYOUT.myBaseSize
local SPAWN_POSITION = LAYOUT.spawnPosition
local CONVEYOR_START_X = LAYOUT.conveyorStartX
local CONVEYOR_END_X = LAYOUT.conveyorEndX
local CONVEYOR_Z = LAYOUT.conveyorZ

-- One state table per player: cash, lifetime earnings, rebirths, the
-- brainrot they are carrying home, the ones placed on their base, and
-- when their base lock runs out (0 = unlocked).
local playerStates: { [Player]: any } = {}
local parade: { [Model]: any } = {}
local slotPads: { BasePart } = {}
local placedModels: { [number]: Model } = {}
local stealer: Model? = nil
local tsunamiCountdown = BrainrotData.TSUNAMI_FIRST_DELAY
local tsunamiWarning = false

--- How many base slots this player has unlocked right now.
local function slotCountFor(state): number
	return math.min(
		BrainrotData.START_SLOTS + state.rebirths * BrainrotData.SLOTS_PER_REBIRTH,
		BrainrotData.MAX_SLOTS
	)
end

--- The first empty slot number, or nil when the base is full.
local function firstFreeSlot(state): number?
	for slot = 1, slotCountFor(state) do
		if state.placed[slot] == nil then
			return slot
		end
	end
	return nil
end

--- The dollars per second all of a player's placed brainrots earn together.
local function totalIncomePerSecond(state): number
	local total = 0
	for _, placed in pairs(state.placed) do
		local mutation = BrainrotData.getMutation(placed.mutation)
		total += BrainrotData.incomePerSecond(placed.entry, mutation, state.rebirths)
	end
	return total
end

--- The next rarity tier the player has not unlocked yet, or nil at the top.
local function nextTier(state): any
	local best = 1
	for _, placed in pairs(state.placed) do
		local row = BrainrotData.getRarity(placed.entry.rarity)
		best = math.max(best, row.order)
	end
	for _, row in ipairs(BrainrotData.RARITIES) do
		if row.order == best + 1 then
			return row
		end
	end
	return nil
end

--- Send one player their full state snapshot for the HUD.
local function sendStateTo(player: Player)
	local state = playerStates[player]
	if state == nil then
		return
	end
	local placedList = {}
	for slot, placed in pairs(state.placed) do
		table.insert(placedList, {
			slot = slot,
			id = placed.entry.id,
			name = placed.entry.name,
			rarity = placed.entry.rarity,
			mutation = placed.mutation,
			rate = BrainrotData.incomePerSecond(placed.entry, BrainrotData.getMutation(placed.mutation), state.rebirths),
		})
	end
	table.sort(placedList, function(a, b)
		return a.slot < b.slot
	end)
	local carried = nil
	if state.carried ~= nil then
		carried = {
			id = state.carried.entry.id,
			name = state.carried.entry.name,
			rarity = state.carried.entry.rarity,
			mutation = state.carried.mutation,
			rate = BrainrotData.incomePerSecond(state.carried.entry, BrainrotData.getMutation(state.carried.mutation), state.rebirths),
		}
	end
	local tier = nextTier(state)
	StateEvent:FireClient(player, {
		money = math.floor(state.money),
		income = totalIncomePerSecond(state),
		rebirths = state.rebirths,
		lifetime = math.floor(state.lifetime),
		slots = slotCountFor(state),
		placed = placedList,
		carried = carried,
		lockedUntil = state.lockedUntil,
		tsunamiIn = tsunamiCountdown,
		tsunamiWarning = tsunamiWarning,
		nextTier = if tier ~= nil then tier.name else nil,
		nextTierAt = if tier ~= nil then tier.unlockAt else nil,
	})
end

--- Tell one player something in their notifications feed.
local function notify(player: Player, text: string)
	StateEvent:FireClient(player, { notice = text })
end

--- Set up a fresh player: starter cash, empty base, leaderstats.
local function setupPlayer(player: Player)
	local state = {
		money = BrainrotData.START_CASH,
		lifetime = 0,
		rebirths = 0,
		carried = nil,
		placed = {},
		lockedUntil = 0,
	}
	playerStates[player] = state

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	local moneyValue = Instance.new("IntValue")
	moneyValue.Name = "Money"
	moneyValue.Value = BrainrotData.START_CASH
	moneyValue.Parent = leaderstats
	local rebirthValue = Instance.new("IntValue")
	rebirthValue.Name = "Rebirths"
	rebirthValue.Value = 0
	rebirthValue.Parent = leaderstats
	state.moneyValue = moneyValue
	state.rebirthValue = rebirthValue

	task.spawn(function()
		task.wait(1)
		sendStateTo(player)
	end)
	notify(player, "Welcome to Brainrot Bazaar! Click a brainrot on the conveyor to buy it, then carry it home!")
end

--- Remove a player and hand their placed brainrots back to the parade pool.
local function teardownPlayer(player: Player)
	local state = playerStates[player]
	if state ~= nil then
		for slot, _ in pairs(state.placed) do
			local model = placedModels[slot]
			if model ~= nil then
				model:Destroy()
				placedModels[slot] = nil
			end
		end
	end
	playerStates[player] = nil
end

--- Place a carried brainrot on the first free slot of the player's base.
local function placeBrainrotOnBase(player: Player)
	local state = playerStates[player]
	if state == nil or state.carried == nil then
		return
	end
	local slot = firstFreeSlot(state)
	if slot == nil then
		notify(player, "Your base is full! Rebirth to unlock more slots.")
		return
	end
	local carried = state.carried
	state.carried = nil
	state.placed[slot] = carried
	local pad = slotPads[slot]
	local spot = MY_BASE_CENTER
	if pad ~= nil then
		-- Feet on the pad's top face: round 1 added 1.8 and left every
		-- placed brainrot floating a head-height above its pad.
		spot = pad.Position + Vector3.new(0, 0.15, 0)
	end
	local model = BrainrotWorld.buildBrainrotModel(carried.entry, BrainrotData.getMutation(carried.mutation), spot)
	local click = model:FindFirstChild("Body")
	if click ~= nil then
		local detector = click:FindFirstChild("BuyClick")
		if detector ~= nil then
			detector:Destroy()
		end
	end
	model.Parent = Workspace
	placedModels[slot] = model
	notify(player, carried.entry.name .. " placed on slot " .. tostring(slot) .. " — earning $" .. tostring(math.floor(carried.rate + 0.5)) .. "/s!")
	sendStateTo(player)
end

--- Buy the brainrot a player clicked on the conveyor, if they can afford it.
local function buyBrainrot(player: Player, model: Model)
	local state = playerStates[player]
	local info = parade[model]
	if state == nil or info == nil then
		return
	end
	if state.carried ~= nil then
		notify(player, "Carry your " .. state.carried.entry.name .. " home first! Press Place on your base.")
		return
	end
	local price = BrainrotData.buyPrice(info.entry, info.mutation)
	if state.money < price then
		notify(player, "Not enough cash! " .. info.entry.name .. " costs " .. BrainrotData.formatMoney(price) .. ".")
		return
	end
	-- Wild brainrots (Diamond or Rainbow) must be clicked three times fast.
	if info.mutation.multiplier >= 5 then
		info.clicks += 1
		if info.clicks < BrainrotData.WILD_CATCH_CLICKS then
			notify(player, "Wild " .. info.entry.name .. "! Click it " .. tostring(BrainrotData.WILD_CATCH_CLICKS - info.clicks) .. " more time(s) to catch it!")
			CatchEvent:FireClient(player, { id = info.entry.id, clicks = info.clicks })
			return
		end
	end
	state.money -= price
	state.carried = { entry = info.entry, mutation = info.mutation.name, rate = BrainrotData.incomePerSecond(info.entry, info.mutation, state.rebirths) }
	parade[model] = nil
	model:Destroy()
	notify(player, "You bought " .. info.mutation.name .. " " .. info.entry.name .. "! Dash home to your teal base and place it!")
	sendStateTo(player)
end

--- Spawn one brainrot on the conveyor: pick a random cast member, roll its
-- mutation, build its model at the west end, and let it walk east.
local function spawnBrainrotOnConveyor()
	local entry = BrainrotData.CAST[math.random(1, #BrainrotData.CAST)]
	local mutation = BrainrotData.rollMutation()
	local position = Vector3.new(CONVEYOR_START_X, 0.5, CONVEYOR_Z)
	local model = BrainrotWorld.buildBrainrotModel(entry, mutation, position)
	parade[model] = {
		entry = entry,
		mutation = mutation,
		clicks = 0,
		bornAt = os.clock(),
	}
	local body = model:FindFirstChild("Body")
	if body ~= nil then
		local detector = body:FindFirstChild("BuyClick")
		if detector ~= nil then
			detector.MouseClick:Connect(function(player)
				buyBrainrot(player, model)
			end)
		end
	end
	task.spawn(function()
		local start = os.clock()
		while model.Parent ~= nil and parade[model] ~= nil do
			local elapsed = os.clock() - start
			if elapsed > BrainrotData.CONVEYOR_WALK_SECONDS then
				break
			end
			local x = CONVEYOR_START_X + (CONVEYOR_END_X - CONVEYOR_START_X) * (elapsed / BrainrotData.CONVEYOR_WALK_SECONDS)
			BrainrotWorld.moveBrainrotModel(model, Vector3.new(x, 0.5, CONVEYOR_Z))
			task.wait(0.1)
		end
		if parade[model] ~= nil then
			parade[model] = nil
			model:Destroy()
		end
	end)
end

--- The tsunami: warn, then sweep the wave across the plaza. Any player not
-- standing on their own base loses the brainrot they are carrying and is
-- sent back to the spawn pad. Placed brainrots are safe on their base.
local function startTsunamiWave()
	tsunamiWarning = true
	tsunamiCountdown = BrainrotData.TSUNAMI_WARNING
	for _, player in ipairs(Players:GetPlayers()) do
		notify(player, "TSUNAMI INCOMING! Dash home to your base in " .. tostring(BrainrotData.TSUNAMI_WARNING) .. " seconds!")
		sendStateTo(player)
	end
	task.wait(BrainrotData.TSUNAMI_WARNING)
	tsunamiWarning = false
	local wave = BrainrotWorld.getTsunamiWave(LAYOUT.waveWidth, LAYOUT.waveStartZ)
	local sweep = (LAYOUT.waveEndZ - LAYOUT.waveStartZ) / 40
	wave.Position = Vector3.new(0, 8, LAYOUT.waveStartZ)
	for step = 1, 40 do
		wave.Position = Vector3.new(0, 8, LAYOUT.waveStartZ + step * sweep)
		task.wait(0.12)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local state = playerStates[player]
		local character = player.Character
		if state == nil or character == nil then
			continue
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if root == nil or not root:IsA("BasePart") then
			continue
		end
		local pos = root.Position
		local onBase = math.abs(pos.X - MY_BASE_CENTER.X) <= MY_BASE_SIZE.X / 2
			and math.abs(pos.Z - MY_BASE_CENTER.Z) <= MY_BASE_SIZE.Z / 2
		if not onBase then
			if state.carried ~= nil then
				notify(player, "The tsunami swept your " .. state.carried.entry.name .. " away! Buy another and dash home faster!")
				state.carried = nil
			end
			character:PivotTo(CFrame.new(SPAWN_POSITION))
			sendStateTo(player)
		else
			notify(player, "Safe on your base! The wave passed.")
		end
	end
	wave.Position = Vector3.new(0, 8, LAYOUT.waveStartZ)
	tsunamiCountdown = BrainrotData.TSUNAMI_CYCLE
end

--- Sneaky Steve walks in from a rival base and tries to steal a placed
-- brainrot. A locked base turns him away; a click (slap) sends him packing.
local function sendStealer()
	if stealer ~= nil then
		return
	end
	local victim: Player? = nil
	for _, player in ipairs(Players:GetPlayers()) do
		local state = playerStates[player]
		if state ~= nil and next(state.placed) ~= nil then
			victim = player
			break
		end
	end
	if victim == nil then
		return
	end
	local state = playerStates[victim]
	if state == nil then
		return
	end
	if os.clock() < state.lockedUntil then
		notify(victim, "Sneaky Steve eyed your base, but your lock scared him off!")
		return
	end
	local model = BrainrotWorld.buildStealer(LAYOUT.stealerSpawn)
	stealer = model
	notify(victim, "Sneaky Steve is sneaking toward your base! Click him to slap him away!")
	local body = model:FindFirstChild("Body")
	if body ~= nil then
		local detector = body:FindFirstChild("SlapClick")
		if detector ~= nil then
			detector.MouseClick:Connect(function(player)
				SlapEvent:FireClient(player, { slapped = true })
				notify(player, "SLAP! Sneaky Steve fled!")
				if stealer == model then
					stealer = nil
				end
				model:Destroy()
			end)
		end
	end
	task.spawn(function()
		local from = LAYOUT.stealerSpawn
		local to = LAYOUT.stealerTarget
		for step = 1, 60 do
			if model.Parent == nil then
				return
			end
			local t = step / 60
			local x = from.X + (to.X - from.X) * t
			local z = from.Z + (to.Z - from.Z) * t
			BrainrotWorld.moveStealer(model, Vector3.new(x, 0, z))
			task.wait(0.2)
		end
		if model.Parent == nil then
			return
		end
		-- Steve arrived: snatch a random placed brainrot and run.
		local slots = {}
		for slot, _ in pairs(state.placed) do
			table.insert(slots, slot)
		end
		if #slots > 0 then
			local slot = slots[math.random(1, #slots)]
			local stolen = state.placed[slot]
			state.placed[slot] = nil
			local placedModel = placedModels[slot]
			if placedModel ~= nil then
				placedModel:Destroy()
				placedModels[slot] = nil
			end
			notify(victim, "Sneaky Steve stole your " .. stolen.entry.name .. "! Lock your base next time!")
			sendStateTo(victim)
		end
		if stealer == model then
			stealer = nil
		end
		model:Destroy()
	end)
end

--- Lock the player's base against the stealer for LOCK_SECONDS.
local function lockBase(player: Player)
	local state = playerStates[player]
	if state == nil then
		return
	end
	if os.clock() < state.lockedUntil then
		notify(player, "Your base is already locked!")
		return
	end
	if state.money < BrainrotData.LOCK_COST then
		notify(player, "A base lock costs " .. BrainrotData.formatMoney(BrainrotData.LOCK_COST) .. ".")
		return
	end
	state.money -= BrainrotData.LOCK_COST
	state.lockedUntil = os.clock() + BrainrotData.LOCK_SECONDS
	notify(player, "Base locked for " .. tostring(BrainrotData.LOCK_SECONDS) .. " seconds! Sneaky Steve can't touch it.")
	sendStateTo(player)
end

--- Rebirth: spend lifetime earnings for a permanent +25% income bonus.
local function rebirthPlayer(player: Player)
	local state = playerStates[player]
	if state == nil then
		return
	end
	if state.lifetime < BrainrotData.REBIRTH_COST then
		notify(player, "Rebirth needs " .. BrainrotData.formatMoney(BrainrotData.REBIRTH_COST) .. " lifetime earnings. You have " .. BrainrotData.formatMoney(state.lifetime) .. ".")
		return
	end
	state.rebirths += 1
	state.lifetime = 0
	state.money = BrainrotData.START_CASH
	state.rebirthValue.Value = state.rebirths
	notify(player, "REBIRTH #" .. tostring(state.rebirths) .. "! All income +" .. tostring(math.floor(BrainrotData.REBIRTH_BONUS * 100 + 0.5)) .. "% forever, and +" .. tostring(BrainrotData.SLOTS_PER_REBIRTH) .. " base slots!")
	sendStateTo(player)
end

-- Remote wiring: the client may only ask; the server decides.
PlaceEvent.OnServerEvent:Connect(placeBrainrotOnBase)
LockEvent.OnServerEvent:Connect(lockBase)
RebirthEvent.OnServerEvent:Connect(rebirthPlayer)

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(teardownPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

-- Build the base slot pads and a few display brainrots on the rival bases.
slotPads = BrainrotWorld.buildBaseSlots(MY_BASE_CENTER, MY_BASE_SIZE, BrainrotData.MAX_SLOTS)
local displayCast = { 3, 5, 7 }
for i, base in ipairs(LAYOUT.rivalBaseCenters) do
	local display = BrainrotWorld.buildBrainrotModel(BrainrotData.CAST[displayCast[i]], BrainrotData.MUTATIONS[1], base)
	local body = display:FindFirstChild("Body")
	if body ~= nil then
		local detector = body:FindFirstChild("BuyClick")
		if detector ~= nil then
			detector:Destroy()
		end
	end
end

-- Money ticks every second: every placed brainrot pays its rate.
task.spawn(function()
	while true do
		task.wait(1)
		for player, state in pairs(playerStates) do
			local income = totalIncomePerSecond(state)
			if income > 0 then
				state.money += income
				state.lifetime += income
				state.moneyValue.Value = math.floor(state.money)
			end
			sendStateTo(player)
		end
		if tsunamiCountdown > 0 then
			tsunamiCountdown -= 1
		end
	end
end)

-- The conveyor parades a new brainrot every few seconds.
task.spawn(function()
	while true do
		task.wait(BrainrotData.CONVEYOR_INTERVAL)
		spawnBrainrotOnConveyor()
	end
end)

-- The tsunami cycle: countdown, warning, wave, repeat.
task.spawn(function()
	task.wait(BrainrotData.TSUNAMI_FIRST_DELAY)
	while true do
		startTsunamiWave()
		task.wait(BrainrotData.TSUNAMI_CYCLE)
	end
end)

-- Sneaky Steve drops by every minute or so to try his luck.
task.spawn(function()
	while true do
		task.wait(75)
		sendStealer()
	end
end)

print("Brainrot Bazaar server ready: conveyor, tsunami and stealer loops running.")
