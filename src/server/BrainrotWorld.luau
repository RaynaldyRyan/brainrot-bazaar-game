-- BrainrotWorld: builds the moving 3D pieces of Brainrot Bazaar at run time.
-- The static world (plaza, stalls, bases, conveyor hall) is built by
-- WorldBuilder; this module builds everything that appears, moves or
-- vanishes while the game runs: the brainrot characters parading on the
-- conveyor, the base slot pads, the rival stealer, and the tsunami wave.
-- One module, one job: 3D models from data.

local BrainrotWorld = {}

local Workspace = game:GetService("Workspace")

local BRAINROT_FOLDER_NAME = "ParadeBrainrots"
local SLOTS_FOLDER_NAME = "BaseSlots"
local WAVE_NAME = "TsunamiWave"
local STEALER_NAME = "SneakySteve"

--- The folder that holds every brainrot currently on the conveyor.
function BrainrotWorld.getParadeFolder(): Folder
	local folder = Workspace:FindFirstChild(BRAINROT_FOLDER_NAME)
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = BRAINROT_FOLDER_NAME
		folder.Parent = Workspace
	end
	return folder
end

--- A floating label over a brainrot: name, rarity and dollars per second.
local function attachBrainrotLabel(model: Model, displayName: string, rarityName: string, rate: number, labelColor: Color3)
	local head = model:FindFirstChild("Head")
	if head == nil then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BrainrotLabel"
	-- Small and near: round 1's big always-on-top labels stacked into an
	-- unreadable wall on the short conveyor. Nearer labels now occlude
	-- farther ones, and distant ones stop drawing entirely.
	billboard.Size = UDim2.new(0, 140, 0, 56)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 100
	billboard.Parent = head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0.4, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = displayName
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = billboard

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "RarityLabel"
	rarityLabel.Position = UDim2.new(0, 0, 0.4, 0)
	rarityLabel.Size = UDim2.new(1, 0, 0.3, 0)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = rarityName
	rarityLabel.TextColor3 = labelColor
	rarityLabel.TextScaled = true
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.Parent = billboard

	local rateLabel = Instance.new("TextLabel")
	rateLabel.Name = "RateLabel"
	rateLabel.Position = UDim2.new(0, 0, 0.7, 0)
	rateLabel.Size = UDim2.new(1, 0, 0.3, 0)
	rateLabel.BackgroundTransparency = 1
	rateLabel.Text = "$" .. tostring(math.floor(rate + 0.5)) .. "/s"
	rateLabel.TextColor3 = Color3.fromRGB(120, 255, 120)
	rateLabel.TextScaled = true
	rateLabel.Font = Enum.Font.GothamBold
	rateLabel.Parent = billboard
end

--- Build one brainrot character as a Model: a round body, a head, a hat and
-- feet, coloured from its cast entry, standing on the conveyor or a base slot.
-- `mutationName` tints the body: Golden glows yellow, Diamond cyan, Rainbow cycles.
function BrainrotWorld.buildBrainrotModel(entry, mutation, position: Vector3): Model
	local scale = entry.size
	local model = Instance.new("Model")
	model.Name = entry.name

	local bodyColor = entry.bodyColor
	if mutation.name == "Golden" then
		bodyColor = Color3.fromRGB(255, 215, 0)
	elseif mutation.name == "Diamond" then
		bodyColor = Color3.fromRGB(140, 225, 255)
	end

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(3 * scale, 3 * scale, 3 * scale)
	body.Color = bodyColor
	body.Material = if mutation.name == "Rainbow" then Enum.Material.Neon else Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.Position = position + Vector3.new(0, 1.6 * scale, 0)
	body.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(2 * scale, 2 * scale, 2 * scale)
	head.Color = bodyColor
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = true
	head.CanCollide = false
	head.Position = position + Vector3.new(0, 3.6 * scale, 0)
	head.Parent = model

	local hat = Instance.new("Part")
	hat.Name = "Hat"
	hat.Shape = Enum.PartType.Cylinder
	hat.Size = Vector3.new(1 * scale, 2.4 * scale, 2.4 * scale)
	hat.Color = entry.hatColor
	hat.Material = Enum.Material.SmoothPlastic
	hat.Anchored = true
	hat.CanCollide = false
	hat.Position = position + Vector3.new(0, 4.8 * scale, 0)
	hat.Parent = model

	for _, side in ipairs({ -1, 1 }) do
		local foot = Instance.new("Part")
		foot.Name = if side < 0 then "LeftFoot" else "RightFoot"
		foot.Size = Vector3.new(1 * scale, 0.6 * scale, 1.4 * scale)
		foot.Color = Color3.fromRGB(40, 40, 40)
		foot.Material = Enum.Material.SmoothPlastic
		foot.Anchored = true
		foot.CanCollide = false
		foot.Position = position + Vector3.new(0.8 * scale * side, 0.3 * scale, 0)
		foot.Parent = model
	end

	local click = Instance.new("ClickDetector")
	click.Name = "BuyClick"
	click.MaxActivationDistance = 40
	click.Parent = body

	attachBrainrotLabel(model, entry.name, mutation.name .. " " .. entry.rarity, entry.rate * mutation.multiplier, entry.bodyColor)
	model.Parent = BrainrotWorld.getParadeFolder()
	return model
end

--- Move a brainrot model so its feet sit at `position`, keeping its shape.
function BrainrotWorld.moveBrainrotModel(model: Model, position: Vector3)
	local body = model:FindFirstChild("Body")
	if body == nil or not body:IsA("BasePart") then
		return
	end
	local offset = (body :: BasePart).Position - model:GetPivot().Position
	model:PivotTo(CFrame.new(position + offset))
end

--- Build the eight slot pads on a base platform: glowing plates a placed
-- brainrot stands on. Returns the pad parts, one per slot, in slot order.
function BrainrotWorld.buildBaseSlots(baseCenter: Vector3, baseSize: Vector3, slotCount: number): { BasePart }
	local folder = Workspace:FindFirstChild(SLOTS_FOLDER_NAME)
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = SLOTS_FOLDER_NAME
		folder.Parent = Workspace
	end
	local pads = {}
	local cols = 4
	local rows = math.ceil(slotCount / cols)
	for slot = 1, slotCount do
		local col = (slot - 1) % cols
		local row = math.floor((slot - 1) / cols)
		local pad = Instance.new("Part")
		pad.Name = "SlotPad" .. tostring(slot)
		pad.Size = Vector3.new(4, 0.3, 4)
		pad.Color = Color3.fromRGB(255, 255, 255)
		pad.Material = Enum.Material.Neon
		pad.Transparency = 0.35
		pad.Anchored = true
		pad.CanCollide = true
		local x = baseCenter.X - baseSize.X / 2 + 4 + col * 5.6
		local z = baseCenter.Z - baseSize.Z / 2 + 4 + row * 5.6
		pad.Position = Vector3.new(x, baseCenter.Y + 0.65, z)
		pad.Parent = folder
		table.insert(pads, pad)
	end
	return pads
end

--- Build Sneaky Steve, the rival stealer: a lanky figure in a striped shirt
-- who walks to a player's base and tries to carry a brainrot away.
function BrainrotWorld.buildStealer(position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = STEALER_NAME

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2, 3, 1.2)
	body.Color = Color3.fromRGB(40, 40, 40)
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.Position = position + Vector3.new(0, 2.5, 0)
	body.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.8, 1.8, 1.8)
	head.Color = Color3.fromRGB(240, 200, 150)
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = true
	head.CanCollide = false
	head.Position = position + Vector3.new(0, 5, 0)
	head.Parent = model

	local mask = Instance.new("Part")
	mask.Name = "Mask"
	mask.Size = Vector3.new(1.9, 0.6, 0.4)
	mask.Color = Color3.fromRGB(20, 20, 20)
	mask.Material = Enum.Material.SmoothPlastic
	mask.Anchored = true
	mask.CanCollide = false
	mask.Position = position + Vector3.new(0, 5.2, 0.9)
	mask.Parent = model

	for _, side in ipairs({ -1, 1 }) do
		local leg = Instance.new("Part")
		leg.Name = if side < 0 then "LeftLeg" else "RightLeg"
		leg.Size = Vector3.new(0.8, 2, 0.8)
		leg.Color = Color3.fromRGB(30, 30, 30)
		leg.Material = Enum.Material.SmoothPlastic
		leg.Anchored = true
		leg.CanCollide = false
		leg.Position = position + Vector3.new(0.5 * side, 1, 0)
		leg.Parent = model
	end

	local click = Instance.new("ClickDetector")
	click.Name = "SlapClick"
	click.MaxActivationDistance = 40
	click.Parent = body

	model.Parent = Workspace
	return model
end

--- Move Sneaky Steve so his feet sit at `position`, part by part from the
-- exact offsets buildStealer used: no pivot math, so he never sinks into
-- the floor while walking to the player's base.
function BrainrotWorld.moveStealer(model: Model, position: Vector3)
	local offsets = {
		Body = Vector3.new(0, 2.5, 0),
		Head = Vector3.new(0, 5, 0),
		Mask = Vector3.new(0, 5.2, 0.9),
		LeftLeg = Vector3.new(-0.5, 1, 0),
		RightLeg = Vector3.new(0.5, 1, 0),
	}
	for name, offset in pairs(offsets) do
		local part = model:FindFirstChild(name)
		if part ~= nil and part:IsA("BasePart") then
			(part :: BasePart).Position = position + offset
		end
	end
end

--- Build (or return) the tsunami wave: a tall translucent wall of water
-- that sweeps from the north gate across the whole plaza. `width` spans
-- the playfield; `startZ` is the north fence line it sweeps out from.
function BrainrotWorld.getTsunamiWave(width: number, startZ: number): Part
	local wave = Workspace:FindFirstChild(WAVE_NAME)
	if wave ~= nil and wave:IsA("BasePart") then
		return wave
	end
	wave = Instance.new("Part")
	wave.Name = WAVE_NAME
	wave.Size = Vector3.new(width, 16, 4)
	wave.Color = Color3.fromRGB(20, 90, 230)
	wave.Material = Enum.Material.Neon
	wave.Transparency = 0.3
	wave.Anchored = true
	wave.CanCollide = false
	wave.Position = Vector3.new(0, 8, startZ)
	wave.Parent = Workspace
	return wave
end

return BrainrotWorld
