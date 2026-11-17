-- BrainrotData: the cast of Brainrot Bazaar, its rarity ladder and its mutations.
-- One module, one job: every number the game economy uses lives here, so the
-- server (income, prices, rebirths) and the client (shop list, HUD labels) agree.

local BrainrotData = {}

-- Rarity ladder, cheapest first. `order` is the climb: each tier costs more
-- than the last and pays more per second. `color` is the label colour in the HUD.
BrainrotData.RARITIES = {
	{ name = "Common", order = 1, color = Color3.fromRGB(200, 200, 200), unlockAt = 0 },
	{ name = "Rare", order = 2, color = Color3.fromRGB(80, 170, 255), unlockAt = 500 },
	{ name = "Epic", order = 3, color = Color3.fromRGB(180, 90, 255), unlockAt = 2500 },
	{ name = "Legendary", order = 4, color = Color3.fromRGB(255, 170, 0), unlockAt = 12000 },
	{ name = "Mythic", order = 5, color = Color3.fromRGB(255, 60, 120), unlockAt = 60000 },
	{ name = "Secret", order = 6, color = Color3.fromRGB(0, 255, 220), unlockAt = 250000 },
}

-- Mutations roll when a brainrot parades down the conveyor. A mutated
-- brainrot keeps its base rate times the multiplier, and costs more to buy.
BrainrotData.MUTATIONS = {
	{ name = "Normal", multiplier = 1, chance = 0.70, color = Color3.fromRGB(255, 255, 255) },
	{ name = "Golden", multiplier = 2, chance = 0.18, color = Color3.fromRGB(255, 215, 0) },
	{ name = "Diamond", multiplier = 5, chance = 0.09, color = Color3.fromRGB(120, 220, 255) },
	{ name = "Rainbow", multiplier = 10, chance = 0.03, color = Color3.fromRGB(255, 120, 255) },
}

-- The cast: twelve absurd originals. `cost` is the buy price, `rate` the
-- dollars per second it earns once placed on a base, `size` its body scale,
-- `bodyColor` / `hatColor` the colours its 3D model is built from.
BrainrotData.CAST = {
	{ id = "noodle-nessie", name = "Noodle Nessie", rarity = "Common", cost = 100, rate = 5, size = 1.0, bodyColor = Color3.fromRGB(90, 200, 120), hatColor = Color3.fromRGB(255, 220, 90), blurb = "A lake monster made of instant noodles." },
	{ id = "sir-spaghetti", name = "Sir Spaghetti III", rarity = "Common", cost = 250, rate = 12, size = 1.0, bodyColor = Color3.fromRGB(240, 200, 120), hatColor = Color3.fromRGB(200, 40, 40), blurb = "Knighted by the Queen of Pasta." },
	{ id = "dj-pickle", name = "DJ Pickle", rarity = "Rare", cost = 800, rate = 35, size = 1.1, bodyColor = Color3.fromRGB(80, 200, 80), hatColor = Color3.fromRGB(255, 0, 200), blurb = "Drops beats. Drops brine. Never both." },
	{ id = "captain-croissant", name = "Captain Croissant", rarity = "Rare", cost = 1500, rate = 60, size = 1.1, bodyColor = Color3.fromRGB(230, 180, 90), hatColor = Color3.fromRGB(40, 80, 200), blurb = "Sails the butter seas at dawn." },
	{ id = "moon-cheese-mouse", name = "Moon Cheese Mouse", rarity = "Epic", cost = 4000, rate = 150, size = 1.2, bodyColor = Color3.fromRGB(240, 240, 200), hatColor = Color3.fromRGB(120, 120, 255), blurb = "Nibbled the moon. It tasted like cheddar." },
	{ id = "turbo-toilet", name = "Turbo Toilet", rarity = "Epic", cost = 7000, rate = 240, size = 1.2, bodyColor = Color3.fromRGB(220, 230, 240), hatColor = Color3.fromRGB(255, 120, 0), blurb = "Flushes at the speed of sound." },
	{ id = "pasta-panda", name = "Pasta Panda", rarity = "Legendary", cost = 16000, rate = 520, size = 1.4, bodyColor = Color3.fromRGB(255, 255, 255), hatColor = Color3.fromRGB(255, 180, 60), blurb = "Eats only noodles. Judges your noodles." },
	{ id = "disco-durian", name = "Disco Durian", rarity = "Legendary", cost = 28000, rate = 850, size = 1.4, bodyColor = Color3.fromRGB(200, 220, 60), hatColor = Color3.fromRGB(255, 0, 150), blurb = "Smells terrible. Dances beautifully." },
	{ id = "wizard-watermelon", name = "Wizard Watermelon", rarity = "Mythic", cost = 75000, rate = 2100, size = 1.6, bodyColor = Color3.fromRGB(60, 180, 80), hatColor = Color3.fromRGB(140, 60, 220), blurb = "Casts seeds. Seeds cast back." },
	{ id = "bacon-ninja", name = "Bacon Ninja", rarity = "Mythic", cost = 120000, rate = 3200, size = 1.5, bodyColor = Color3.fromRGB(200, 90, 70), hatColor = Color3.fromRGB(30, 30, 30), blurb = "You never see it sizzle." },
	{ id = "sushi-samurai", name = "Sushi Samurai", rarity = "Secret", cost = 300000, rate = 7500, size = 1.7, bodyColor = Color3.fromRGB(255, 190, 150), hatColor = Color3.fromRGB(0, 150, 150), blurb = "Slices sashimi. Slices time." },
	{ id = "galaxy-gummy", name = "Galaxy Gummy Bear", rarity = "Secret", cost = 500000, rate = 12000, size = 1.8, bodyColor = Color3.fromRGB(160, 90, 255), hatColor = Color3.fromRGB(255, 220, 0), blurb = "A whole constellation, chewable." },
}

-- How many base slots a player starts with, and how many a rebirth adds.
BrainrotData.START_SLOTS = 8
BrainrotData.SLOTS_PER_REBIRTH = 2
BrainrotData.MAX_SLOTS = 16

-- Rebirth: spend this much lifetime earnings to reset cash to the starter
-- amount, keep your brainrots, and earn +25% income forever per rebirth.
BrainrotData.REBIRTH_COST = 100000
BrainrotData.REBIRTH_BONUS = 0.25
BrainrotData.START_CASH = 500

-- A base lock costs this much and blocks the stealer for one lock duration.
BrainrotData.LOCK_COST = 2000
BrainrotData.LOCK_SECONDS = 60

-- The tsunami: first warning this many seconds after a player joins, then
-- a wave every cycle; the warning counts down before the wave hits.
BrainrotData.TSUNAMI_FIRST_DELAY = 90
BrainrotData.TSUNAMI_CYCLE = 120
BrainrotData.TSUNAMI_WARNING = 15

-- The conveyor parades a new brainrot this often; a parade brainrot that
-- nobody buys walks off the end and is gone.
BrainrotData.CONVEYOR_INTERVAL = 8
BrainrotData.CONVEYOR_WALK_SECONDS = 24

-- A wild Golden-or-better brainrot must be clicked this many times before
-- it escapes; a normal one is bought with a single click.
BrainrotData.WILD_CATCH_CLICKS = 3
BrainrotData.WILD_ESCAPE_SECONDS = 12

--- Look a cast member up by id. Returns nil for an unknown id.
function BrainrotData.getBrainrotById(id: string)
	for _, entry in ipairs(BrainrotData.CAST) do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

--- Look a rarity row up by name. Returns the Common row for an unknown name.
function BrainrotData.getRarity(name: string)
	for _, row in ipairs(BrainrotData.RARITIES) do
		if row.name == name then
			return row
		end
	end
	return BrainrotData.RARITIES[1]
end

--- Roll one mutation, weighted by the chances in MUTATIONS.
function BrainrotData.rollMutation()
	local roll = math.random()
	local running = 0
	for _, mutation in ipairs(BrainrotData.MUTATIONS) do
		running += mutation.chance
		if roll <= running then
			return mutation
		end
	end
	return BrainrotData.MUTATIONS[1]
end

--- Look a mutation up by name. Returns Normal for an unknown name.
function BrainrotData.getMutation(name: string)
	for _, mutation in ipairs(BrainrotData.MUTATIONS) do
		if mutation.name == name then
			return mutation
		end
	end
	return BrainrotData.MUTATIONS[1]
end

--- The buy price of one brainrot with a mutation applied.
function BrainrotData.buyPrice(entry, mutation): number
	return math.floor(entry.cost * mutation.multiplier)
end

--- The dollars per second of one brainrot with a mutation and rebirth bonus.
function BrainrotData.incomePerSecond(entry, mutation, rebirths: number): number
	return entry.rate * mutation.multiplier * (1 + rebirths * BrainrotData.REBIRTH_BONUS)
end

--- The next rarity tier above the one named, or nil at the top.
function BrainrotData.nextRarity(name: string)
	local row = BrainrotData.getRarity(name)
	for _, candidate in ipairs(BrainrotData.RARITIES) do
		if candidate.order == row.order + 1 then
			return candidate
		end
	end
	return nil
end

--- Format a money amount the HUD way: 1,250,000 not 1250000.
function BrainrotData.formatMoney(amount: number): string
	local whole = math.floor(amount + 0.5)
	local text = tostring(whole)
	local out = ""
	while #text > 3 do
		out = "," .. string.sub(text, -3) .. out
		text = string.sub(text, 1, -4)
	end
	return "$" .. text .. out
end

return BrainrotData
