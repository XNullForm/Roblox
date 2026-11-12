-- ServerScriptService.Upgrades (round 20): buys hotel upgrades (Shared.Upgrades) for the Upgrades tab.
-- Remotes.Upgrade:InvokeServer(id) -> ok, message. The server owns the cash and the hotel's Upgrades attribute.
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local U = require(Shared:WaitForChild("Upgrades"))
local Remotes = Shared:WaitForChild("Remotes")
local Notify = Remotes:WaitForChild("Notify")
local remote = Remotes:FindFirstChild("Upgrade")
if not remote then
	remote = Instance.new("RemoteFunction")
	remote.Name = "Upgrade"
	remote.Parent = Remotes
end

local function hotelOf(player)
	local plots = workspace:FindFirstChild("Plots")
	local id = player:GetAttribute("Plot")
	return id and plots and plots:FindFirstChild(id)
end

local last = {}
remote.OnServerInvoke = function(player, id, key, value)
	-- round 22: ("style", key, id) picks a floor, wall or roof finish (free)
	if id == "style" then
		local hotel = hotelOf(player)
		if not hotel then return false, "Join your hotel first" end
		if os.clock() - (last[player] or 0) < 0.15 then return false, "Slow down" end
		last[player] = os.clock()
		for _, g in ipairs(U.STYLES) do
			if g.key == key then
				for _, e in ipairs(g.list) do
					if e[1] == value then
						local st = U.style(hotel)
						st[key] = value
						hotel:SetAttribute("Style", U.encode(st))
						return true
					end
				end
			end
		end
		return false, "No such style"
	end
	local def = type(id) == "string" and U.BY[id]
	if not def then return false, "No such upgrade" end
	if os.clock() - (last[player] or 0) < 0.25 then return false, "Slow down" end
	last[player] = os.clock()
	local hotel = hotelOf(player)
	if not hotel then return false, "Join your hotel first" end
	local levels = U.levels(hotel)
	local level = U.level(hotel, id)
	local cost = U.cost(def, level)
	if not cost then return false, "Already at the top level" end
	local cash = player:GetAttribute("Cash") or 0
	if cash < cost then return false, "You need $" .. cost end
	if not player:GetAttribute("InfiniteCash") then player:SetAttribute("Cash", cash - cost) end
	levels[id] = level + 1
	hotel:SetAttribute("Upgrades", U.encode(levels))
	Notify:FireClient(player, "toast", { text = def.name .. " level " .. (level + 1) .. ": " .. U.effect(def, level + 1), icon = "cash", kind = "good" })
	if id == "curb" and U.STORY[level + 1] then
		task.delay(2.5, function()
			if player.Parent then Notify:FireClient(player, "toast", { text = U.STORY[level + 1], icon = "star" }) end
		end)
	end
	return true
end
