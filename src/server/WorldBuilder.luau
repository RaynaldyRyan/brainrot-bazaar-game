-- WorldBuilder: builds the whole Brainrot Bazaar map at run time, in Luau.
-- Round 1 shipped a flat sand plain with a narrow 92-stud play area; the
-- playtester called it cramped and ugly. This rebuild makes a much bigger,
-- wider bazaar on a 160-stud playfield with distinct zones: a spawn plaza
-- in the south, a raised central plaza with a fountain and market stalls, a
-- roofed conveyor hall in the north with a belt twice as long, four roomy
-- base plots in the corners, wide cobblestone paths between them, a pond,
-- hills and trees for terrain variety, and lamps, banners, crates and
-- archways for decoration. One module, one job: the 3D world, from data.
--
-- The LAYOUT table is the single source of truth for the coordinates the
-- game logic needs (base centres, conveyor ends, tsunami sweep); the server
-- script reads it instead of hard-coding the same numbers twice.

local WorldBuilder = {}

local Workspace = game:GetService("Workspace")

WorldBuilder.LAYOUT = {
	fenceHalf = 80,
	spawnPosition = Vector3.new(0, 3, 64),
	myBaseCenter = Vector3.new(-58, 0.5, 58),
	myBaseSize = Vector3.new(30, 1, 26),
	rivalBaseCenters = {
		Vector3.new(58, 0.5, 58),
		Vector3.new(-58, 0.5, -58),
		Vector3.new(58, 0.5, -58),
	},
	conveyorStartX = -44,
	conveyorEndX = 44,
	conveyorZ = -32,
	stealerSpawn = Vector3.new(58, 0, -44),
	stealerTarget = Vector3.new(-46, 0, 46),
	waveStartZ = -78,
	waveEndZ = 78,
	waveWidth = 170,
}

local WORLD_FOLDER_NAME = "BazaarWorld"
local world: Folder? = nil

--- The folder every world part lives under, created on first use.
local function worldFolder(): Folder
	if world == nil then
		local folder = Workspace:FindFirstChild(WORLD_FOLDER_NAME)
		if folder == nil then
			folder = Instance.new("Folder")
			folder.Name = WORLD_FOLDER_NAME
			folder.Parent = Workspace
		end
		world = folder
	end
	return world :: Folder
end

--- One anchored part. `opts` may carry canCollide, transparency, shape
-- (Ball/Cylinder/Wedge) and cframe (used instead of position, for rotation).
local function newPart(
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material?,
	opts: any?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	if opts ~= nil and opts.cframe ~= nil then
		part.CFrame = opts.cframe
	else
		part.Position = position
	end
	if opts ~= nil and opts.canCollide ~= nil then
		part.CanCollide = opts.canCollide
	end
	if opts ~= nil and opts.transparency ~= nil then
		part.Transparency = opts.transparency
	end
	if opts ~= nil and opts.shape ~= nil then
		part.Shape = opts.shape
	end
	part.Parent = worldFolder()
	return part
end

--- A vertical cylinder (a post, a barrel, a spout): Roblox cylinders lie
-- along local X, so rotate 90 degrees about Z to stand one upright.
local function newPost(name: string, position: Vector3, height: number, diameter: number, color: Color3, material: Enum.Material?): Part
	return newPart(name, Vector3.new(height, diameter, diameter), position, color, material, {
		cframe = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
	})
end

--- A text sign glued to one face of a part. Front is -Z, Back is +Z.
local function addSign(part: Part, face: Enum.NormalId, text: string, textColor: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = face
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Name = "SignText"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
	label.BackgroundTransparency = 0.15
	label.Text = text
	label.TextColor3 = textColor
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
	return gui
end

--- The ground: a wide grass field with sand patches, ringed by a wooden
-- fence. The playfield inside the fence is 160 by 160 studs, nearly twice
-- the round-1 area, and the ground runs past the fence so the horizon is
-- green, not void.
local function buildGroundAndFences()
	newPart("Ground", Vector3.new(340, 2, 340), Vector3.new(0, -1, 0), Color3.fromRGB(95, 175, 80), Enum.Material.Grass)
	for _, patch in ipairs({
		{ pos = Vector3.new(46, 0.05, 30), size = Vector3.new(24, 0.2, 16) },
		{ pos = Vector3.new(-46, 0.05, -10), size = Vector3.new(24, 0.2, 20) },
		{ pos = Vector3.new(10, 0.05, -52), size = Vector3.new(30, 0.2, 14) },
		{ pos = Vector3.new(-30, 0.05, 46), size = Vector3.new(24, 0.2, 14) },
	}) do
		newPart("SandPatch", patch.size, patch.pos, Color3.fromRGB(220, 195, 130), Enum.Material.Sand, { canCollide = false })
	end
	local half = WorldBuilder.LAYOUT.fenceHalf
	local fenceColor = Color3.fromRGB(165, 125, 70)
	newPart("FenceNorth", Vector3.new(162, 3, 1), Vector3.new(0, 1.5, -half), fenceColor, Enum.Material.Wood)
	newPart("FenceSouth", Vector3.new(162, 3, 1), Vector3.new(0, 1.5, half), fenceColor, Enum.Material.Wood)
	newPart("FenceWest", Vector3.new(1, 3, 162), Vector3.new(-half, 1.5, 0), fenceColor, Enum.Material.Wood)
	newPart("FenceEast", Vector3.new(1, 3, 162), Vector3.new(half, 1.5, 0), fenceColor, Enum.Material.Wood)
	for _, corner in ipairs({ { -half, -half }, { half, -half }, { -half, half }, { half, half } }) do
		newPart("FencePost", Vector3.new(2, 4.5, 2), Vector3.new(corner[1], 2.25, corner[2]), Color3.fromRGB(120, 85, 40), Enum.Material.Wood)
	end
end

--- Wide cobblestone paths: the east-west cross route and the four corner
-- paths from the plaza to the base plots. The north-south route runs over
-- the plaza's own steps, so it needs no separate path parts.
local function buildPaths()
	local stone = Color3.fromRGB(175, 160, 140)
	newPart("PathWest", Vector3.new(26, 0.15, 12), Vector3.new(-45, 0.08, 12), stone, Enum.Material.Cobblestone)
	newPart("PathEast", Vector3.new(26, 0.15, 12), Vector3.new(45, 0.08, 12), stone, Enum.Material.Cobblestone)
	newPart("PathSouthWest", Vector3.new(16, 0.15, 8), Vector3.new(-39, 0.08, 45), stone, Enum.Material.Cobblestone)
	newPart("PathSouthEast", Vector3.new(16, 0.15, 8), Vector3.new(39, 0.08, 45), stone, Enum.Material.Cobblestone)
	newPart("PathNorthWest", Vector3.new(12, 0.15, 26), Vector3.new(-39, 0.08, -32), stone, Enum.Material.Cobblestone)
	newPart("PathNorthEast", Vector3.new(12, 0.15, 26), Vector3.new(39, 0.08, -32), stone, Enum.Material.Cobblestone)
end

--- Two low steps up to a raised platform edge. `outward` is the direction
-- away from the platform (a unit Vector3 on the XZ plane).
local function buildSteps(center: Vector3, outward: Vector3, wide: number, alongX: boolean)
	local upperSize = if alongX then Vector3.new(wide, 0.25, 2) else Vector3.new(2, 0.25, wide)
	local upperPos = center + Vector3.new(0, 0.375, 0)
	local lowerPos = center + outward * 2 + Vector3.new(0, 0.125, 0)
	newPart("StepUpper", upperSize, upperPos, Color3.fromRGB(150, 150, 160), Enum.Material.Slate)
	newPart("StepLower", upperSize, lowerPos, Color3.fromRGB(150, 150, 160), Enum.Material.Slate)
end

--- The spawn plaza in the south: a stone deck under the spawn pad, a
-- welcome arch carrying the game's name, and crates and plants to arrive to.
local function buildSpawnPlaza()
	newPart("SpawnDeck", Vector3.new(44, 0.3, 26), Vector3.new(0, 0.15, 64), Color3.fromRGB(140, 140, 150), Enum.Material.Slate)
	for _, side in ipairs({ -1, 1 }) do
		newPart("ArchPillar", Vector3.new(2, 7, 2), Vector3.new(side * 10, 3.5, 54), Color3.fromRGB(230, 220, 190), Enum.Material.Marble)
	end
	local beam = newPart("ArchBeam", Vector3.new(24, 2, 2), Vector3.new(0, 7.5, 54), Color3.fromRGB(230, 220, 190), Enum.Material.Marble)
	addSign(beam, Enum.NormalId.Back, "BRAINROT BAZAAR", Color3.fromRGB(255, 215, 0))
	for _, spot in ipairs({
		{ pos = Vector3.new(-16, 1, 56), size = Vector3.new(2, 2, 2) },
		{ pos = Vector3.new(-14, 1, 58), size = Vector3.new(1.6, 2, 1.6) },
		{ pos = Vector3.new(16, 1, 56), size = Vector3.new(2, 2, 2) },
		{ pos = Vector3.new(15, 1, 72), size = Vector3.new(1.6, 2, 1.6) },
	}) do
		newPart("SpawnCrate", spot.size, spot.pos, Color3.fromRGB(165, 125, 70), Enum.Material.Wood)
	end
end

--- The raised central plaza: a 64-stud stone platform with steps on all
-- four sides, a fountain at its heart, and market stalls around its edge.
local function buildCentralPlaza()
	newPart("Plaza", Vector3.new(64, 1, 64), Vector3.new(0, 0, 12), Color3.fromRGB(145, 145, 155), Enum.Material.Slate)
	buildSteps(Vector3.new(0, 0, -20), Vector3.new(0, 0, -1), 16, true)
	buildSteps(Vector3.new(0, 0, 44), Vector3.new(0, 0, 1), 16, true)
	buildSteps(Vector3.new(32, 0, 12), Vector3.new(1, 0, 0), 16, false)
	buildSteps(Vector3.new(-32, 0, 12), Vector3.new(-1, 0, 0), 16, false)
	-- Fountain: a square stone rim, glowing water, and a spout.
	local rim = Color3.fromRGB(170, 170, 180)
	newPart("FountainRimN", Vector3.new(11, 1.2, 1), Vector3.new(0, 1.1, 7), rim, Enum.Material.Concrete)
	newPart("FountainRimS", Vector3.new(11, 1.2, 1), Vector3.new(0, 1.1, 17), rim, Enum.Material.Concrete)
	newPart("FountainRimW", Vector3.new(1, 1.2, 11), Vector3.new(-5, 1.1, 12), rim, Enum.Material.Concrete)
	newPart("FountainRimE", Vector3.new(1, 1.2, 11), Vector3.new(5, 1.1, 12), rim, Enum.Material.Concrete)
	newPart("FountainWater", Vector3.new(9, 0.4, 9), Vector3.new(0, 0.9, 12), Color3.fromRGB(40, 150, 240), Enum.Material.Neon, { canCollide = false })
	newPost("FountainSpout", Vector3.new(0, 2.2, 12), 3, 1, Color3.fromRGB(200, 200, 210), Enum.Material.Marble)
	newPart("FountainTop", Vector3.new(1.6, 1.6, 1.6), Vector3.new(0, 4.2, 12), Color3.fromRGB(120, 200, 255), Enum.Material.Neon, { shape = Enum.PartType.Ball, canCollide = false })
end

--- One market stall: a wooden counter, four posts, a two-tier fabric roof
-- in its own colour, and a name board. `y` is the floor it stands on.
local function makeStall(x: number, z: number, y: number, roofColor: Color3, stallName: string)
	local wood = Color3.fromRGB(150, 105, 55)
	newPart("StallCounter", Vector3.new(8, 2.5, 3), Vector3.new(x, y + 1.25, z), wood, Enum.Material.Wood)
	for _, dx in ipairs({ -3.6, 3.6 }) do
		for _, dz in ipairs({ -1.8, 1.8 }) do
			newPart("StallPost", Vector3.new(0.5, 4.5, 0.5), Vector3.new(x + dx, y + 2.25, z + dz), wood, Enum.Material.Wood)
		end
	end
	newPart("StallRoof", Vector3.new(10, 0.4, 6), Vector3.new(x, y + 4.7, z), roofColor, Enum.Material.Fabric, { canCollide = false })
	newPart("StallRoofTop", Vector3.new(6, 0.4, 4), Vector3.new(x, y + 5.3, z), roofColor, Enum.Material.Fabric, { canCollide = false })
	local board = newPart("StallSign", Vector3.new(7, 1.6, 0.3), Vector3.new(x, y + 3.6, z + 2.2), Color3.fromRGB(60, 40, 20), Enum.Material.Wood, { canCollide = false })
	addSign(board, Enum.NormalId.Back, stallName, Color3.fromRGB(255, 255, 255))
end

--- Stalls around the plaza edge, plus a shop row of four stalls on the
-- walk between the plaza and the spawn deck.
local function buildShopRow()
	local plazaY = 0.5
	makeStall(-26, -8, plazaY, Color3.fromRGB(230, 60, 70), "NOODLE STALL")
	makeStall(26, -8, plazaY, Color3.fromRGB(60, 130, 240), "PICKLE STAND")
	makeStall(-26, 32, plazaY, Color3.fromRGB(60, 200, 80), "MELON MART")
	makeStall(26, 32, plazaY, Color3.fromRGB(240, 200, 40), "PASTA PALACE")
	makeStall(-18, 50, 0, Color3.fromRGB(200, 90, 220), "DURIAN DEN")
	makeStall(-6, 50, 0, Color3.fromRGB(255, 140, 40), "CROISSANT CO.")
	makeStall(6, 50, 0, Color3.fromRGB(40, 200, 200), "SUSHI SPOT")
	makeStall(18, 50, 0, Color3.fromRGB(240, 90, 140), "GUMMY GARDEN")
end

--- The conveyor hall in the north: a 90-stud belt (twice round 1's
-- length, so parading brainrots spread out instead of bunching up),
-- marble pillars, open roof beams that never block the camera, hanging
-- banners, and an arched entrance at each end.
local function buildConveyorHall()
	local beltA = Color3.fromRGB(50, 50, 58)
	local beltB = Color3.fromRGB(65, 65, 75)
	for i = 0, 5 do
		local cx = -37.5 + i * 15
		newPart("ConveyorBelt", Vector3.new(15, 0.5, 6), Vector3.new(cx, 0.25, -32), if i % 2 == 0 then beltA else beltB, Enum.Material.Metal)
	end
	local railColor = Color3.fromRGB(230, 190, 30)
	newPart("ConveyorRailN", Vector3.new(92, 0.4, 0.6), Vector3.new(0, 0.7, -35.2), railColor, Enum.Material.Metal)
	newPart("ConveyorRailS", Vector3.new(92, 0.4, 0.6), Vector3.new(0, 0.7, -28.8), railColor, Enum.Material.Metal)
	local pillarColor = Color3.fromRGB(225, 215, 185)
	for _, px in ipairs({ -45, -27, -9, 9, 27, 45 }) do
		for _, pz in ipairs({ -36.5, -27.5 }) do
			newPart("HallPillar", Vector3.new(1.6, 8, 1.6), Vector3.new(px, 4, pz), pillarColor, Enum.Material.Marble)
		end
	end
	for _, bz in ipairs({ -36.5, -32, -27.5 }) do
		newPart("HallBeam", Vector3.new(94, 1, 1), Vector3.new(0, 8.5, bz), Color3.fromRGB(150, 105, 55), Enum.Material.Wood, { canCollide = false })
	end
	local bannerColors = {
		Color3.fromRGB(230, 60, 70),
		Color3.fromRGB(60, 130, 240),
		Color3.fromRGB(60, 200, 80),
		Color3.fromRGB(240, 200, 40),
		Color3.fromRGB(200, 90, 220),
	}
	for i, bx in ipairs({ -36, -18, 0, 18, 36 }) do
		newPart("HallBanner", Vector3.new(3.5, 4, 0.2), Vector3.new(bx, 6, -32), bannerColors[i], Enum.Material.Fabric, { canCollide = false })
	end
	for _, side in ipairs({ -1, 1 }) do
		local ex = side * 47
		for _, pz in ipairs({ -36.5, -27.5 }) do
			newPart("HallEndPillar", Vector3.new(2, 9, 2), Vector3.new(ex, 4.5, pz), pillarColor, Enum.Material.Marble)
		end
		local beam = newPart("HallEndBeam", Vector3.new(2, 2, 11), Vector3.new(ex, 9.5, -32), pillarColor, Enum.Material.Marble)
		addSign(beam, Enum.NormalId.Back, "BRAINROT PARADE", Color3.fromRGB(255, 215, 0))
	end
end

--- One base plot in a corner: a 30 by 26 platform with walls on its two
-- outer edges, corner posts with glowing tips, a gate banner on the inner
-- corner, a name sign on the back wall, crates, and steps up from the
-- corner path. `signX`/`signZ` are +1/-1 from the plot's centre.
local function makeBasePlot(center: Vector3, accent: Color3, wallColor: Color3, labelText: string)
	local signX = if center.X > 0 then 1 else -1
	local signZ = if center.Z > 0 then 1 else -1
	newPart("BasePlatform", Vector3.new(30, 1, 26), Vector3.new(center.X, 0, center.Z), accent, Enum.Material.Concrete)
	newPart("BaseWallX", Vector3.new(1, 5, 26), Vector3.new(center.X + signX * 14.5, 3, center.Z), wallColor, Enum.Material.Concrete)
	local backWall = newPart("BaseWallZ", Vector3.new(30, 5, 1), Vector3.new(center.X, 3, center.Z + signZ * 12.5), wallColor, Enum.Material.Concrete)
	addSign(backWall, if signZ > 0 then Enum.NormalId.Front else Enum.NormalId.Back, labelText, Color3.fromRGB(255, 255, 255))
	for _, dx in ipairs({ -14, 14 }) do
		for _, dz in ipairs({ -12, 12 }) do
			newPart("BasePost", Vector3.new(1.5, 4, 1.5), Vector3.new(center.X + dx, 2.5, center.Z + dz), wallColor, Enum.Material.Concrete)
			newPart("BasePostTip", Vector3.new(1.8, 0.5, 1.8), Vector3.new(center.X + dx, 4.7, center.Z + dz), accent, Enum.Material.Neon, { canCollide = false })
		end
	end
	-- Gate banner on the inner corner, facing the plaza.
	local gx = center.X - signX * 13
	local gz = center.Z - signZ * 11
	newPost("BaseBannerPole", Vector3.new(gx, 3.5, gz), 7, 0.5, Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
	newPart("BaseBannerFlag", Vector3.new(3, 4, 0.2), Vector3.new(gx, 5.5, gz), accent, Enum.Material.Fabric, { canCollide = false })
	-- Steps up from the corner path, on the edge nearest the plaza.
	local sx = center.X - signX * 10
	local sz = center.Z - signZ * 13
	buildSteps(Vector3.new(sx, 0, sz), Vector3.new(0, 0, -signZ), 8, true)
	-- Crates stacked by the back wall.
	for _, crate in ipairs({
		{ pos = Vector3.new(center.X - signX * 10, 1.5, center.Z + signZ * 10), size = Vector3.new(2, 2, 2) },
		{ pos = Vector3.new(center.X - signX * 7.5, 1.5, center.Z + signZ * 10.5), size = Vector3.new(1.6, 2, 1.6) },
	}) do
		newPart("BaseCrate", crate.size, crate.pos, Color3.fromRGB(165, 125, 70), Enum.Material.Wood)
	end
end

--- The four base plots: the player's teal base in the south-west, rivals
-- in the other corners, each with clear space around it.
local function buildBasePlots()
	local layout = WorldBuilder.LAYOUT
	makeBasePlot(layout.myBaseCenter, Color3.fromRGB(25, 180, 180), Color3.fromRGB(15, 115, 115), "MY BASE")
	makeBasePlot(layout.rivalBaseCenters[1], Color3.fromRGB(205, 50, 50), Color3.fromRGB(130, 25, 25), "RIVAL BASE")
	makeBasePlot(layout.rivalBaseCenters[2], Color3.fromRGB(150, 75, 215), Color3.fromRGB(100, 40, 150), "RIVAL BASE")
	makeBasePlot(layout.rivalBaseCenters[3], Color3.fromRGB(240, 140, 25), Color3.fromRGB(165, 90, 15), "RIVAL BASE")
end

--- A pond in the east: shallow glowing water in a stone rim, with rocks
-- and plants beside it, breaking up the flat ground.
local function buildPond()
	local rim = Color3.fromRGB(170, 170, 180)
	newPart("PondWater", Vector3.new(20, 0.4, 14), Vector3.new(52, 0.1, -8), Color3.fromRGB(40, 150, 240), Enum.Material.Neon, { canCollide = false })
	newPart("PondRimN", Vector3.new(22, 0.6, 1), Vector3.new(52, 0.3, -15.5), rim, Enum.Material.Concrete)
	newPart("PondRimS", Vector3.new(22, 0.6, 1), Vector3.new(52, 0.3, -0.5), rim, Enum.Material.Concrete)
	newPart("PondRimW", Vector3.new(1, 0.6, 16), Vector3.new(41.5, 0.3, -8), rim, Enum.Material.Concrete)
	newPart("PondRimE", Vector3.new(1, 0.6, 16), Vector3.new(62.5, 0.3, -8), rim, Enum.Material.Concrete)
	newPart("PondRock", Vector3.new(3, 2, 3), Vector3.new(44, 0.8, -14), Color3.fromRGB(130, 130, 140), Enum.Material.Slate, { shape = Enum.PartType.Ball })
	newPart("PondRock2", Vector3.new(2, 1.6, 2), Vector3.new(60, 0.6, -2), Color3.fromRGB(130, 130, 140), Enum.Material.Slate, { shape = Enum.PartType.Ball })
end

--- Grassy hills beyond the fence and trees of several sizes inside it,
-- so the horizon has shape instead of one flat plane.
local function buildHillsAndTrees()
	for _, hill in ipairs({
		{ pos = Vector3.new(-95, -6, -60), size = 30 },
		{ pos = Vector3.new(95, -6, 60), size = 30 },
		{ pos = Vector3.new(-60, -5, 95), size = 26 },
		{ pos = Vector3.new(60, -5, -95), size = 26 },
	}) do
		newPart("Hill", Vector3.new(hill.size, hill.size, hill.size), hill.pos, Color3.fromRGB(85, 160, 70), Enum.Material.Grass, { shape = Enum.PartType.Ball, canCollide = false })
	end
	local function makeTree(x: number, z: number, scale: number)
		local trunkH = 4 * scale
		newPart("TreeTrunk", Vector3.new(1.2 * scale, trunkH, 1.2 * scale), Vector3.new(x, trunkH / 2, z), Color3.fromRGB(115, 75, 35), Enum.Material.Wood)
		local leafY = trunkH + 1.5 * scale
		newPart("TreeLeaves", Vector3.new(5 * scale, 4 * scale, 5 * scale), Vector3.new(x, leafY, z), Color3.fromRGB(40, 150, 55), Enum.Material.Grass, { shape = Enum.PartType.Ball, canCollide = false })
		newPart("TreeTop", Vector3.new(3 * scale, 2.5 * scale, 3 * scale), Vector3.new(x, leafY + 2.5 * scale, z), Color3.fromRGB(60, 180, 70), Enum.Material.Grass, { shape = Enum.PartType.Ball, canCollide = false })
	end
	for _, tree in ipairs({
		{ x = -44, z = 20, s = 1.2 }, { x = 44, z = 20, s = 1.0 }, { x = -44, z = -44, s = 1.0 }, { x = 44, z = -44, s = 1.3 },
		{ x = -70, z = 0, s = 1.1 }, { x = 70, z = 0, s = 1.2 }, { x = 0, z = -56, s = 1.0 }, { x = -20, z = -56, s = 1.3 },
		{ x = 20, z = -56, s = 1.1 }, { x = -70, z = 40, s = 1.0 }, { x = 70, z = 40, s = 1.0 }, { x = 30, z = 64, s = 1.2 },
		{ x = -30, z = 64, s = 1.0 }, { x = -90, z = 0, s = 1.5 }, { x = 90, z = 0, s = 1.5 }, { x = 0, z = -90, s = 1.5 },
		{ x = 0, z = 90, s = 1.5 },
	}) do
		makeTree(tree.x, tree.z, tree.s)
	end
end

--- Lamp posts along the paths and around the spawn deck, each with a
-- warm point light, plus tall banners at the plaza corners.
local function buildLampsAndBanners()
	local function makeLamp(x: number, z: number)
		newPart("LampPole", Vector3.new(0.6, 6, 0.6), Vector3.new(x, 3, z), Color3.fromRGB(40, 40, 45), Enum.Material.Metal)
		local bulb = newPart("LampBulb", Vector3.new(1.6, 1.6, 1.6), Vector3.new(x, 6.6, z), Color3.fromRGB(255, 220, 100), Enum.Material.Neon, { canCollide = false })
		local light = Instance.new("PointLight")
		light.Name = "LampLight"
		light.Color = Color3.fromRGB(255, 220, 130)
		light.Range = 20
		light.Brightness = 1.5
		light.Parent = bulb
	end
	for _, lamp in ipairs({
		{ x = -8, z = -23 }, { x = 8, z = -23 }, { x = -8, z = 48 }, { x = 8, z = 48 },
		{ x = -45, z = 6 }, { x = -45, z = 18 }, { x = 45, z = 6 }, { x = 45, z = 18 },
		{ x = -20, z = 56 }, { x = 20, z = 56 }, { x = -20, z = 72 }, { x = 20, z = 72 },
	}) do
		makeLamp(lamp.x, lamp.z)
	end
	local bannerColors = {
		Color3.fromRGB(230, 60, 70),
		Color3.fromRGB(60, 130, 240),
		Color3.fromRGB(60, 200, 80),
		Color3.fromRGB(240, 200, 40),
	}
	for i, spot in ipairs({ { -34, -22 }, { 34, -22 }, { -34, 46 }, { 34, 46 } }) do
		newPost("BannerPole", Vector3.new(spot[1], 3.5, spot[2]), 7, 0.5, Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
		newPart("BannerFlag", Vector3.new(3, 4, 0.2), Vector3.new(spot[1], 5.5, spot[2]), bannerColors[i], Enum.Material.Fabric, { canCollide = false })
	end
end

--- The tsunami gate on the north fence: a tall translucent wall of water
-- the wave sweeps out from, with a red warning sign facing the map.
local function buildTsunamiGate()
	newPart("TsunamiGate", Vector3.new(160, 14, 1), Vector3.new(0, 7, -78), Color3.fromRGB(25, 100, 240), Enum.Material.Neon, { transparency = 0.6, canCollide = false })
	for _, side in ipairs({ -1, 1 }) do
		newPart("TsunamiGatePost", Vector3.new(2, 15, 2), Vector3.new(side * 80, 7.5, -78), Color3.fromRGB(200, 200, 210), Enum.Material.Marble)
	end
	local sign = newPart("TsunamiSign", Vector3.new(14, 4, 0.5), Vector3.new(0, 6, -76), Color3.fromRGB(200, 30, 30), Enum.Material.SmoothPlastic, { canCollide = false })
	addSign(sign, Enum.NormalId.Back, "TSUNAMI GATE - RUN HOME!", Color3.fromRGB(255, 255, 255))
end

--- Build the entire map, zone by zone. Called once by the server script
-- before any game loop starts.
function WorldBuilder.buildWorld()
	buildGroundAndFences()
	buildPaths()
	buildSpawnPlaza()
	buildCentralPlaza()
	buildShopRow()
	buildConveyorHall()
	buildBasePlots()
	buildPond()
	buildHillsAndTrees()
	buildLampsAndBanners()
	buildTsunamiGate()
	print("Brainrot Bazaar world built: 160-stud bazaar, plaza, conveyor hall, 4 bases.")
end

return WorldBuilder
