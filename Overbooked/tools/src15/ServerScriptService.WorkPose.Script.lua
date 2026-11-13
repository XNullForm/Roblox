-- WorkPose (round 40): while a player has a minigame open, their character plays the staff's work pose for it
-- (Shared.NPCAnimLib through every client's NPCAnim, which tracks characters tagged PlayerPose). Cosmetic only:
-- the client says which game it opened (WorkPose(kind)) or that it closed (WorkPose(nil)).
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Remotes = game.ReplicatedStorage.Shared.Remotes

-- the pose for each game and where its hands work, in studs from the root (x right, y up, z forward)
local POSE = {
	Floor = { "scrub", Vector3.new(0, -2.6, -2.2) },
	Toilet = { "scrub", Vector3.new(0, -1.6, -2.0) },
	Bed = { "makebed", Vector3.new(0, -1.2, -2.4) },
	Shower = { "wipe", Vector3.new(0, 0.6, -1.9) },
	Repair = { "fixat", Vector3.new(0, -1.0, -2.0) },
	Cook = { "cook" },
	CheckIn = { "desk" },
	CheckOut = { "desk" },
}

local function set(player, kind)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local p = type(kind) == "string" and POSE[kind]
	if p then
		char:SetAttribute("WorkAt", p[2] and root.CFrame:PointToWorldSpace(p[2]) or nil)
		char:SetAttribute("Pose", p[1])
		CollectionService:AddTag(char, "PlayerPose")
	else
		char:SetAttribute("Pose", nil)
		char:SetAttribute("WorkAt", nil)
		CollectionService:RemoveTag(char, "PlayerPose")
	end
end

local last = {}
Remotes.WorkPose.OnServerEvent:Connect(function(player, kind)
	local now = os.clock()
	if kind ~= nil and last[player] and now - last[player] < 0.2 then return end -- drops open spam; a close always lands
	last[player] = now
	set(player, kind)
end)
Players.PlayerRemoving:Connect(function(player) last[player] = nil end)
