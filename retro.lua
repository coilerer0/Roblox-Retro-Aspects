-- Combined LocalScript (fixed & merged)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local lp = Players.LocalPlayer

-- ===== limb / head / fake-face system =====
local limbNames = {
	"Left Arm","Right Arm","Left Leg","Right Leg","Torso",
	"UpperTorso","LowerTorso",
	"LeftUpperArm","LeftLowerArm","LeftHand",
	"RightUpperArm","RightLowerArm","RightHand",
	"LeftUpperLeg","LeftLowerLeg","LeftFoot",
	"RightUpperLeg","RightLowerLeg","RightFoot",
}
local limbSet = {}
for _, n in ipairs(limbNames) do limbSet[n] = true end

local function isLimb(part) return limbSet[part.Name] == true end

local function ensureLimbMesh(limb)
	local sm = limb:FindFirstChildOfClass("SpecialMesh")
	if not sm then
		sm = Instance.new("SpecialMesh")
		sm.MeshType = Enum.MeshType.Brick
		sm.Parent = limb
	else
		sm.MeshType = Enum.MeshType.Brick
	end
end

local function addOrUpdateTexture(limb, faceName, textureId)
	local key = faceName .. "_SurfaceTexture"
	local t = limb:FindFirstChild(key)
	if not t then
		t = Instance.new("Texture")
		t.Name = key
		t.Face = Enum.NormalId[faceName]
		t.StudsPerTileU = 1
		t.StudsPerTileV = 1
		t.Parent = limb
	end
	t.Texture = textureId
	return t
end

local limbTextures = {}   -- [part] = {top = Texture, bottom = Texture}
local fakeFaces = {}      -- [head] = {part = Part, tex = Texture}

local function applySurfaces(limb)
	if not limb or not limb:IsA("BasePart") then return end
	ensureLimbMesh(limb)

	-- make all surfaces smooth by default
	for _, s in ipairs({"TopSurface","BottomSurface","FrontSurface","BackSurface","LeftSurface","RightSurface"}) do
		pcall(function() limb[s] = Enum.SurfaceType.Smooth end)
	end

	if limb.Name:find("Torso") then
		-- torso left/right = glue
		pcall(function()
			limb.LeftSurface = Enum.SurfaceType.Glue
			limb.RightSurface = Enum.SurfaceType.Glue
		end)
	end

	local top = addOrUpdateTexture(limb, "Top", "http://www.roblox.com/asset/?id=15829969")
	local bottom = addOrUpdateTexture(limb, "Bottom", "http://www.roblox.com/asset/?id=15830139")
	limbTextures[limb] = {top = top, bottom = bottom}
end

local function cleanupGlobalFakeFaces()
	for _, v in ipairs(Workspace:GetChildren()) do
		if v:IsA("BasePart") and v.Name == "FakeFacePart" then
			pcall(function() v:Destroy() end)
		end
	end
end

local function createFakeFaceForHead(head)
	if not head or not head:IsA("BasePart") then return end

	-- remove previous for this head
	if fakeFaces[head] then
		local old = fakeFaces[head].part
		if old and old.Parent then pcall(function() old:Destroy() end) end
		fakeFaces[head] = nil
	end

	-- global cleanup first (robust)
	cleanupGlobalFakeFaces()

	local part = Instance.new("Part")
	part.Name = "FakeFacePart"
	part.Size = Vector3.new(1.25, 1.25, 0)
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Parent = Workspace

	local tex = Instance.new("Texture")
	tex.Name = "FakeFaceTexture"
	tex.Texture = "rbxassetid://129006361089647"
	tex.Face = Enum.NormalId.Front
	tex.StudsPerTileU = 1.25
	tex.StudsPerTileV = 1.25
	tex.Parent = part

	fakeFaces[head] = {part = part, tex = tex}
end

local function replaceHead(head)
	if not head or not head:IsA("BasePart") then return end

	-- aggressively remove face decals
	for _, obj in ipairs(head:GetChildren()) do
		if obj:IsA("Decal") and (string.lower(obj.Name) == "face" or obj.Face == Enum.NormalId.Front) then
			pcall(function() obj:Destroy() end)
		end
	end

	-- replace mesh (file mesh)
	local oldMesh = head:FindFirstChildOfClass("SpecialMesh")
	if oldMesh then pcall(function() oldMesh:Destroy() end) end

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = "rbxassetid://102204446147778"
	mesh.Scale = Vector3.new(1.2, 1.2, 1.2)
	mesh.Parent = head

	-- create fake face (tracked)
	createFakeFaceForHead(head)
end

local function applyMods(char)
	if not char then return end
	for _, part in ipairs(char:GetChildren()) do
		if part:IsA("BasePart") then
			if isLimb(part) then
				applySurfaces(part)
			elseif part.Name == "Head" then
				replaceHead(part)
			end
		end
	end
end

-- single RenderStepped updater: sync transparencies, fakeface positions, and remove real face decal
RunService.RenderStepped:Connect(function()
	-- update limb textures' transparency
	for limb, tbl in pairs(limbTextures) do
		if not limb or not limb.Parent then
			limbTextures[limb] = nil
		else
			local t = limb.Transparency or 0
			if tbl.top and tbl.top.Parent then pcall(function() tbl.top.Transparency = t end) end
			if tbl.bottom and tbl.bottom.Parent then pcall(function() tbl.bottom.Transparency = t end) end
		end
	end

	-- update fake faces
	for head, data in pairs(fakeFaces) do
		local part = data.part
		local tex  = data.tex
		if not head or not head.Parent or not part or not part.Parent then
			if part and part.Parent then pcall(function() part:Destroy() end) end
			fakeFaces[head] = nil
		else
			-- remove any reappearing Roblox face decal
			for _, obj in ipairs(head:GetChildren()) do
				if obj:IsA("Decal") and (string.lower(obj.Name) == "face" or obj.Face == Enum.NormalId.Front) then
					pcall(function() obj:Destroy() end)
				end
			end

			-- position fake face -0.6175 on Z relative to head
			pcall(function()
				part.CFrame = head.CFrame * CFrame.new(0, 0, -0.6175)
				if tex and tex.Parent then tex.Transparency = head.Transparency end
			end)
		end
	end
end)

-- character wiring for limb/head modifications
local function onCharacterAdded_mods(char)
	if not char then return end
	char:WaitForChild("Humanoid", 5)
	task.wait(0.25)
	applyMods(char)

	char.ChildAdded:Connect(function(c)
		if c:IsA("BasePart") then
			if isLimb(c) then
				applySurfaces(c)
			elseif c.Name == "Head" then
				replaceHead(c)
			end
		end
	end)
end

-- ===== selection box rainbow + old forcefield visual (from merged code) =====
local function addOldForcefield(char)
	if not char then return end
	local boxes = {}
	for _, part in ipairs(char:GetChildren()) do
		if part:IsA("BasePart") and part.Transparency < 1 then
			local sb = Instance.new("SelectionBox")
			sb.Adornee = part
			sb.LineThickness = 0.08
			sb.SurfaceTransparency = 1
			sb.Color3 = Color3.fromRGB(255,0,0)
			sb.Parent = char
			table.insert(boxes, sb)
		end
	end

	local t = 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		t = t + dt*3
		local r = (math.sin(t)+1)/2
		local g = (math.sin(t+2)+1)/2
		local b = (math.sin(t+4)+1)/2
		for i = #boxes, 1, -1 do
			local sb = boxes[i]
			if sb and sb.Parent then
				sb.Color3 = Color3.new(r,g,b)
			else
				table.remove(boxes, i)
			end
		end
		if #boxes == 0 and conn then
			conn:Disconnect()
			conn = nil
		end
	end)

	-- cleanup after 10s
	task.delay(10, function()
		for _, sb in ipairs(boxes) do
			if sb and sb.Parent then sb:Destroy() end
		end
		if conn and conn.Connected then conn:Disconnect() end
	end)
end

-- ===== player movement helpers: mid-air no-turn, jump cooldown, bounce =====
local function setupMovementHelpers(char)
	if not char then return end
	local humanoid = char:FindFirstChildWhichIsA("Humanoid")
	local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
	if not humanoid or not torso then return end

	-- mid-air no turn via BodyGyro
	local bodyGyro
	local function ensureBodyGyro()
		if not bodyGyro then
			bodyGyro = Instance.new("BodyGyro")
			bodyGyro.CFrame = torso.CFrame
			bodyGyro.MaxTorque = Vector3.new(0, 99999, 0)
			bodyGyro.P = 99999
			bodyGyro.Parent = torso
		end
	end
	local function removeBodyGyro()
		if bodyGyro then
			pcall(function() bodyGyro:Destroy() end)
			bodyGyro = nil
		end
	end

	humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
		if humanoid.FloorMaterial == Enum.Material.Air then
			ensureBodyGyro()
		else
			removeBodyGyro()
		end
	end)
	humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
		if humanoid.Sit then removeBodyGyro() end
	end)
	humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
		if humanoid.PlatformStand then removeBodyGyro() end
	end)

	-- jump cooldown
	local jumping = false
	humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
		if humanoid.Jump then
			if jumping then
				humanoid.Jump = false
				return
			end
			jumping = true
			task.delay(1, function() jumping = false end)
		end
	end)

	-- bounce effect on heavy impact
	local bounceThreshold = -130
	local bounceMultiplier = -0.65
	local lastMaterial
	humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
		local material = humanoid.FloorMaterial
		if lastMaterial == Enum.Material.Air and material ~= Enum.Material.Air then
			if torso.AssemblyLinearVelocity.Y < bounceThreshold then
				torso.AssemblyLinearVelocity = Vector3.new(
					torso.AssemblyLinearVelocity.X,
					torso.AssemblyLinearVelocity.Y * bounceMultiplier,
					torso.AssemblyLinearVelocity.Z
				)
			end
		end
		lastMaterial = material
	end)
end

-- ===== lighting conversion (client-side) =====
do
	-- core lighting values (client-side)
	Lighting.Ambient = Color3.new(0.49803921580314636, 0.49803921580314636, 0.49803921580314636)
	Lighting.Brightness = 1.8415838479995728
	Lighting.ColorShift_Bottom = Color3.new(0,0,0)
	Lighting.ColorShift_Top = Color3.new(0,0,0)
	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0
	Lighting.ExposureCompensation = 0
	Lighting.FogColor = Color3.new(0.7529411911964417, 0.7529411911964417, 0.7529411911964417)
	Lighting.FogStart = math.huge
	Lighting.FogEnd = math.huge
	Lighting.GeographicLatitude = 41.72999954223633
	Lighting.GlobalShadows = false
	Lighting.OutdoorAmbient = Color3.new(0.501960813999176, 0.501960813999176, 0.501960813999176)
	Lighting.Outlines = false
	Lighting.ShadowSoftness = 0
	Lighting.TimeOfDay = "14:00:00"

	local sky = Lighting:FindFirstChildOfClass("Sky")
	if not sky then
		sky = Instance.new("Sky")
		sky.Name = "Sky2006"
		sky.Parent = Lighting
	end
	sky.SkyboxBk = "rbxasset://Sky/null_plainsky512_bk.jpg"
	sky.SkyboxDn = "rbxasset://Sky/null_plainsky512_dn.jpg"
	sky.SkyboxFt = "rbxasset://Sky/null_plainsky512_ft.jpg"
	sky.SkyboxLf = "rbxasset://Sky/null_plainsky512_lf.jpg"
	sky.SkyboxRt = "rbxasset://Sky/null_plainsky512_rt.jpg"
	sky.SkyboxUp = "rbxasset://Sky/null_plainsky512_up.jpg"

	local cg = Lighting:FindFirstChildOfClass("ColorGradingEffect")
	if not cg then
		cg = Instance.new("ColorGradingEffect")
		cg.Parent = Lighting
	end
	pcall(function() cg.TonemapperPreset = Enum.TonemapperPreset.Retro end)

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0
	bloom.Size = 0
	bloom.Threshold = 0

	Lighting:SetAttribute("UniversalSynSaveInstance_Converted", true)
end

-- ===== explosion visualizer (client) =====
local function makeBall(exp)
	if not exp then return end
	exp.Visible = false
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Color = Color3.new(1,0,0)
	ball.Material = Enum.Material.Neon
	ball.Anchored = true
	ball.CanCollide = true
	ball.Size = Vector3.new(8,8,8)
	ball.CFrame = CFrame.new(exp.Position)
	ball.Parent = Workspace

	local conn
	conn = RunService.RenderStepped:Connect(function()
		if exp.Parent then
			ball.CFrame = CFrame.new(exp.Position)
		else
			if conn then conn:Disconnect() end
			pcall(function() ball:Destroy() end)
		end
	end)
end

for _, v in ipairs(Workspace:GetDescendants()) do
	if v:IsA("Explosion") then
		pcall(function() makeBall(v) end)
	end
end
Workspace.DescendantAdded:Connect(function(obj)
	if obj:IsA("Explosion") then
		pcall(function() makeBall(obj) end)
	end
end)

-- ===== forcefield hiding + FF visual replacement =====
local ffPart -- visual ball following HRP when forcefield exists
local function createFFPart()
	if ffPart and ffPart.Parent then return ffPart end
	ffPart = Instance.new("Part")
	ffPart.Name = "FF"
	ffPart.Size = Vector3.new(8,8,8)
	ffPart.Shape = Enum.PartType.Ball
	ffPart.BrickColor = BrickColor.new("Steel blue")
	ffPart.Material = Enum.Material.Plastic
	ffPart.Transparency = 0.5
	ffPart.Anchored = true
	ffPart.CanCollide = false
	ffPart.CanTouch = false
	ffPart.Massless = true
	ffPart.Parent = Workspace
	return ffPart
end
local function destroyFFPart()
	if ffPart and ffPart.Parent then pcall(function() ffPart:Destroy() end) end
	ffPart = nil
end

local function hideForceFields(char)
	if not char then return end
	for _, v in ipairs(char:GetChildren()) do
		if v:IsA("ForceField") then
			pcall(function() v.Visible = false end)
		end
	end
	char.ChildAdded:Connect(function(c)
		if c:IsA("ForceField") then
			pcall(function() c.Visible = false end)
		end
	end)
end

-- RunService update for FF part
RunService.RenderStepped:Connect(function()
	local char = lp and lp.Character
	if not char then
		destroyFFPart()
		return
	end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hasFF = char:FindFirstChildOfClass("ForceField")

	if hasFF and hrp then
		createFFPart()
		if ffPart and ffPart.Parent then
			pcall(function() ffPart.CFrame = hrp.CFrame end)
		end
	else
		destroyFFPart()
	end
end)

-- ===== character binding: mods + movement helpers + forcefield visuals + selection boxes =====
local function onCharacter(char)
	if not char then return end
	-- run separate setups
	onCharacterAdded_mods(char)
	setupMovementHelpers(char)
	hideForceFields(char)
	addOldForcefield(char)
end

lp.CharacterAdded:Connect(onCharacter)
if lp.Character then
	-- tiny delay to allow parts to exist
	task.defer(function() onCharacter(lp.Character) end)
end

-- CornerClip Fix (StarterPlayerScripts)
local player = game:GetService("Players").LocalPlayer
local runService = game:GetService("RunService")

local function setupCornerClip(char)
	local torso = char:WaitForChild("Torso")
	local humanoid = char:WaitForChild("Humanoid")

	local lastLook = torso.CFrame.LookVector
	local busy = false

	local function clip()
		if humanoid.SeatPart then return end

		for _, part in pairs(torso:GetTouchingParts()) do
			if part.Parent ~= torso.Parent and part.CanCollide and part:IsA("BasePart") then
				local dirToWall = (part.Position - torso.Position).Unit
				local dot = dirToWall:Dot(torso.CFrame.LookVector)
				if dot > 0.5 then
					local size = part.Size
					local offset = math.clamp(math.max(size.X, size.Z) * 0.75, 1, 5)
					torso.CFrame += dirToWall * offset
					break
				end
			end
		end
	end

	runService.Stepped:Connect(function()
		local current = torso.CFrame.LookVector
		if current:Dot(lastLook) < -0.5 and not busy then
			busy = true
			clip()
			task.wait(1)
			busy = false
		end
		lastLook = current
	end)
end

if player.Character then
	setupCornerClip(player.Character)
end
player.CharacterAdded:Connect(setupCornerClip)

-- CustomClimbing.lua (StarterPlayerScripts)
-- climb system that works only on TrussParts, and keeps player stuck midair if idle

local Players2 = game:GetService("Players")
local RunService2 = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local lp2 = Players2.LocalPlayer
local char2 = lp2.Character or lp2.CharacterAdded:Wait()
local hum2 = char2:WaitForChild("Humanoid")
local hrp2 = char2:WaitForChild("HumanoidRootPart")

hum2:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)

local bodyVel = Instance.new("BodyVelocity")
bodyVel.MaxForce = Vector3.new(25000, 25000, 25000)
bodyVel.P = 100000
bodyVel.Velocity = Vector3.zero
bodyVel.Parent = script

CollectionService:AddTag(script, "Hidden")
CollectionService:AddTag(bodyVel, "Hidden")

local climbing = false
local climbConn

local function onHeartbeat()
	if not char2 or not hrp2 or not hum2 then return end

	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = {char2}
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local origin = hrp2.Position
	local dir = hrp2.CFrame.LookVector * 2.5
	local result = workspace:Raycast(origin, dir, rayParams)

	if result and result.Instance and result.Instance:IsA("TrussPart") then
		if not climbing then
			climbing = true
			_G.isClimbing = true
			bodyVel.Parent = hrp2
		end

		-- if moving, go up; if not, stay still midair
		if hum2.MoveDirection.Magnitude > 0 then
			bodyVel.Velocity = Vector3.new(0, 11.2, 0)
		else
			bodyVel.Velocity = Vector3.zero
		end
	else
		if climbing then
			climbing = false
			_G.isClimbing = false
			bodyVel.Parent = script
			bodyVel.Velocity = Vector3.zero
		end
	end
end

hum2:GetPropertyChangedSignal("MoveDirection"):Connect(function()
	if hum2.MoveDirection.Magnitude > 0 then
		if not climbConn then
			climbConn = RunService2.Heartbeat:Connect(onHeartbeat)
		end
	else
		if not climbConn then
			climbConn = RunService2.Heartbeat:Connect(onHeartbeat)
		end
	end
end)

lp2.CharacterAdded:Connect(function(newChar)
	char2 = newChar
	hum2 = char2:WaitForChild("Humanoid")
	hrp2 = char2:WaitForChild("HumanoidRootPart")
	hum2:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
end)

-- Overhead GUI for all players (custom bars + hides default healthbars)

local Players3 = game:GetService("Players")
local RunService3 = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

-- hide Roblox's default name + health display
pcall(function()
	Players3.PlayerAdded:Connect(function(p)
		p.CharacterAppearanceLoaded:Connect(function()
			pcall(function()
				p:SetAttribute("DisplayNameVisible", false)
			end)
		end)
	end)
	StarterGui:SetCore("PlayerHealthDisplayDistance", 0)
	StarterGui:SetCore("PlayerNameDisplayDistance", 0)
end)

local function createOverhead(player)
	local BillboardGui = Instance.new("BillboardGui")
	BillboardGui.Name = "PlayerOverheadGui"
	BillboardGui.Active = true
	BillboardGui.MaxDistance = 30
	BillboardGui.Size = UDim2.new(0, 96, 0, 24)
	BillboardGui.StudsOffsetWorldSpace = Vector3.new(0, 1.5, 0)
	BillboardGui.AlwaysOnTop = true
	BillboardGui.ResetOnSpawn = false

	local PlayerName = Instance.new("TextLabel")
	PlayerName.Name = "PlayerName"
	PlayerName.AnchorPoint = Vector2.new(0.5, 0.75)
	PlayerName.Position = UDim2.new(0.5, 0, 0, 0)
	PlayerName.Size = UDim2.new(10, 0, 1, 0)
	PlayerName.BackgroundTransparency = 1
	PlayerName.FontFace = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
	PlayerName.Text = player.DisplayName or player.Name
	PlayerName.TextScaled = true
	PlayerName.TextStrokeTransparency = 0
	PlayerName.TextColor3 = Color3.fromRGB(255, 255, 255)
	PlayerName.TextWrapped = true
	PlayerName.Parent = BillboardGui

	local RedBar = Instance.new("Frame")
	RedBar.Name = "RedBar"
	RedBar.AnchorPoint = Vector2.new(0.5, 0.5)
	RedBar.Position = UDim2.new(0.5, 0, 0.5, 0)
	RedBar.Size = UDim2.new(0.6, 0, 0.3, 0)
	RedBar.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
	RedBar.BorderSizePixel = 0
	RedBar.Parent = BillboardGui

	local GreenBar = Instance.new("Frame")
	GreenBar.Name = "GreenBar"
	GreenBar.BackgroundColor3 = Color3.fromRGB(129, 197, 22)
	GreenBar.BorderSizePixel = 0
	GreenBar.Size = UDim2.new(1, 0, 1, 0)
	GreenBar.Parent = RedBar

	return BillboardGui, GreenBar
end

local function applyOverheadToPlayer(player)
	local function apply()
		local char = player.Character or player.CharacterAdded:Wait()
		local head = char:WaitForChild("Head")
		local hum = char:WaitForChild("Humanoid")

		-- disable default Roblox overheads (the health name GUI)
		pcall(function()
			local tag = char:FindFirstChild("Head"):FindFirstChildWhichIsA("BillboardGui")
			if tag then tag.Enabled = false end
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end)

		local BillboardGui, GreenBar = createOverhead(player)
		BillboardGui.Adornee = head
		BillboardGui.Parent = head

		RunService3.RenderStepped:Connect(function()
			if hum and hum.Parent then
				local ratio = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
				GreenBar.Size = UDim2.new(ratio, 0, 1, 0)
			end
		end)
	end

	apply()
	player.CharacterAdded:Connect(apply)
end

Players3.PlayerAdded:Connect(applyOverheadToPlayer)
for _, p in ipairs(Players3:GetPlayers()) do
	applyOverheadToPlayer(p)
end
