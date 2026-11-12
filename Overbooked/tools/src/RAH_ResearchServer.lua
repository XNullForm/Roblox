-- ServerScriptService.RAH_ResearchServer: the research tree (RAH.Research) for each hotel.
-- Remotes.Research (RemoteFunction): ("start", nodeId) / ("cancel") -> ok, message.
-- One node runs at a time per hotel; it costs cash up front and finishes after its time, even while
-- everyone is away (ends is os.time). State lives in the hotel attribute "Research" (JSON), which RAH_Save keeps.
-- Anyone working in the hotel (owner or a co-op friend) can research; the one who starts it pays.
-- Notify: "researched" { id } to everyone in the hotel when a node finishes.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local RAH = RS:WaitForChild("RAH")
local Research = require(RAH:WaitForChild("Research"))
local Levels = require(RAH:WaitForChild("Levels"))
local Notify = RAH.Remotes:WaitForChild("Notify")
local ItemsChanged = game.ServerStorage:WaitForChild("RAH_Signals"):WaitForChild("ItemsChanged")
local PLOTS = workspace:WaitForChild("Plots")

local remote = RAH.Remotes:FindFirstChild("Research") or Instance.new("RemoteFunction")
remote.Name = "Research"
remote.Parent = RAH.Remotes

local CANCEL_BACK = 0.5 -- share of the cost you get back if you stop a node

local function tell(hotel, kind, data)
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("RAH_Plot") == hotel.Name then Notify:FireClient(p, kind, data) end
	end
end

local function write(hotel, st)
	hotel:SetAttribute("Research", Research.encode(st))
	ItemsChanged:Fire() -- so the save picks it up (and rooms re-price for perks)
end

local function finish(hotel, st)
	local id = st.cur
	st.done[id] = true
	st.cur, st.ends, st.len = nil, nil, nil
	write(hotel, st)
	local n = Research.BY_ID[id]
	tell(hotel, "researched", { id = id })
	tell(hotel, "toast", { text = "Research done: " .. (n and n.name or id) .. "!", icon = "research" })
	Levels.award(hotel, Levels.XP.research, "Research")
	local qs = game.ServerStorage.RAH_Signals:FindFirstChild("Quest")
	if qs then qs:Fire(hotel, "research", 1) end
end

local lastCall = {}

local function handle(player, action, id)
	local now = os.clock()
	if lastCall[player] and now - lastCall[player] < 0.25 then return false, "Slow down" end
	lastCall[player] = now
	local hotel = PLOTS:FindFirstChild(player:GetAttribute("RAH_Plot") or "")
	if not hotel or not hotel:GetAttribute("BuildReady") then return false, "You don't have a hotel yet" end
	local st = Research.state(hotel)
	-- round 10e: the owner pays, even when a co-op partner presses the button
	local payer = Players:GetPlayerByUserId(hotel:GetAttribute("Owner") or 0) or player
	if action == "start" then
		local n = typeof(id) == "string" and Research.BY_ID[id]
		if not n then return false, "Nothing to research" end
		if st.done[id] then return false, "Already researched" end
		if not Levels.researchOk(hotel, id) then return false, "Reach hotel level " .. Levels.researchLevel(id) .. " first" end
		if st.cur then
			local c = Research.BY_ID[st.cur]
			return false, "Finish " .. (c and c.name or "the current research") .. " first"
		end
		if not Research.available(st, id) then
			for _, r in ipairs(n.req or {}) do
				if not st.done[r] then return false, "Research " .. Research.BY_ID[r].name .. " first" end
			end
		end
		local cash = payer:GetAttribute("Cash") or 0
		if cash < n.cost then return false, "Not enough cash" end
		payer:SetAttribute("Cash", cash - n.cost)
		payer:SetAttribute("Spent", (payer:GetAttribute("Spent") or 0) + n.cost)
		local len = Research.duration(st, id)
		st.cur, st.ends, st.len = id, os.time() + len, len
		write(hotel, st)
		tell(hotel, "toast", { text = "Researching " .. n.name .. "...", icon = "research" })
		return true, st.ends
	elseif action == "cancel" then
		if not st.cur then return false, "Nothing is being researched" end
		local n = Research.BY_ID[st.cur]
		local back = math.floor((n and n.cost or 0) * CANCEL_BACK)
		payer:SetAttribute("Cash", (payer:GetAttribute("Cash") or 0) + back)
		st.cur, st.ends, st.len = nil, nil, nil
		write(hotel, st)
		return true, back
	end
	return false, "Unknown action"
end

remote.OnServerInvoke = function(player, action, id)
	local ok, a, b = pcall(handle, player, action, id)
	if not ok then
		warn("RAH research: " .. tostring(a))
		return false, "Something went wrong"
	end
	return a, b
end

Players.PlayerRemoving:Connect(function(p) lastCall[p] = nil end)

-- finish whatever is due, once a second
task.spawn(function()
	while true do
		task.wait(1)
		local t = os.time()
		for _, hotel in ipairs(PLOTS:GetChildren()) do
			local s = hotel:GetAttribute("Research")
			if s and string.find(s, "\"cur\"", 1, true) then
				local st = Research.decode(s)
				if st.cur and (st.ends or 0) <= t then finish(hotel, st) end
			end
		end
	end
end)

-- Studio test hook: set a hotel's TestResearchDone attribute to finish its running node now
if game:GetService("RunService"):IsStudio() then
	local function hook(hotel)
		hotel:GetAttributeChangedSignal("TestResearchDone"):Connect(function()
			if not hotel:GetAttribute("TestResearchDone") then return end
			hotel:SetAttribute("TestResearchDone", nil)
			local st = Research.state(hotel)
			if st.cur then finish(hotel, st) end
		end)
	end
	for _, h in ipairs(PLOTS:GetChildren()) do hook(h) end
	PLOTS.ChildAdded:Connect(hook)
end
