-- ReplicatedStorage.Shared.Hiring (round 14, 2026-11-09): staff candidates, skill and personality traits.
-- Every hire is a person: a name, a way of talking (Voice), a skill from 1 to 5 stars, one pro and one con.
-- Hotel attributes: StaffCands (JSON { at = os.time() of the last refresh, roles = { [role] = { cand, cand, cand } } })
-- and StaffProfiles (JSON, "janitor1" -> a profile). A profile = { name, voice, skill, pro, con, wage, deep }.
local H = {}
H.REFRESH = 600 -- new faces every 10 minutes
H.PER_ROLE = 3
H.REROLL_PRICE = 150

H.TRAITS = {
	-- pros
	quick = { name = "Quick Feet", pro = true, text = "Walks 20% faster", walk = 1.2 },
	hard = { name = "Hard Worker", pro = true, text = "Jobs take 15% less time", pace = 0.85 },
	tireless = { name = "Tireless", pro = true, text = "Gets tired 40% slower", drain = 0.6 },
	learner = { name = "Fast Learner", pro = true, text = "Levels up 50% faster", xp = 1.5 },
	modest = { name = "Modest", pro = true, text = "Asks for 20% less pay", wage = 0.8 },
	sunny = { name = "Ray of Sunshine", pro = true, text = "Rests 30% quicker on breaks", rest = 1.3 },
	-- cons
	slow = { name = "Slowpoke", text = "Walks 15% slower", walk = 0.85 },
	clumsy = { name = "Butterfingers", text = "Jobs take 15% longer", pace = 1.15 },
	sleepy = { name = "Sleepyhead", text = "Gets tired 40% faster", drain = 1.4 },
	stubborn = { name = "Stubborn", text = "Levels up 40% slower", xp = 0.6 },
	pricey = { name = "Pricey", text = "Asks for 25% more pay", wage = 1.25 },
	chatty = { name = "Chatterbox", text = "Stops to chat: jobs 8% longer", pace = 1.08, talk = 1.8 },
}
H.PROS = { "quick", "hard", "tireless", "learner", "modest", "sunny" }
H.CONS = { "slow", "clumsy", "sleepy", "stubborn", "pricey", "chatty" }
-- a pro and a con never touch the same thing
local STAT = { quick = "walk", slow = "walk", hard = "pace", clumsy = "pace", chatty = "pace", tireless = "drain", sleepy = "drain",
	learner = "xp", stubborn = "xp", modest = "wage", pricey = "wage", sunny = "rest" }

-- how each voice comes across, for the hiring card
H.VOICE_DESC = {
	sunny = "Bubbly", grump = "Grumpy", posh = "Posh", chill = "Laid-back", nervous = "Nervous", chatter = "Talkative",
	dry = "Deadpan", nan = "Sweet", teen = "Teenager", boss = "Bossy", country = "Country", foodie = "Foodie",
	nerd = "Know-it-all", dreamer = "Dreamy", sporty = "Sporty", tourist = "Wide-eyed",
}
H.VOICES = { "sunny", "grump", "posh", "chill", "nervous", "chatter", "dry", "nan", "teen", "boss", "country", "foodie", "nerd", "dreamer", "sporty", "tourist" }
H.DEEP = { grump = true, boss = true, country = true, sporty = true, chill = true }
H.FIRST = {
	"Rosa", "Dev", "Marta", "Gus", "Ines", "Walt", "Priya", "Hank", "Lottie", "Tomas", "Bea", "Otis", "Juno", "Ray",
	"Sana", "Clem", "Nadia", "Rudy", "Elsie", "Pablo", "Wendy", "Ike", "Freya", "Moss", "Daisy", "Kofi", "Agnes", "Vic",
	"Tilly", "Arlo", "Greta", "Benny", "Lena", "Sid", "Mabel", "Hugo", "Pearl", "Remy", "Cass", "Duke", "Nell", "Omar",
}
H.LAST = {
	"Pike", "Moreno", "Hale", "Okafor", "Brandt", "Quill", "Varga", "Penn", "Ashby", "Kwan", "Duarte", "Lowe", "Finch",
	"Abara", "Holm", "Rios", "Tate", "Mercer", "Ito", "Sharma", "Doyle", "Becker", "Nash", "Silva",
}

local function trait(id) return H.TRAITS[id or ""] or {} end
local function mul(p, k)
	if not p then return 1 end
	return (trait(p.pro)[k] or 1) * (trait(p.con)[k] or 1)
end
-- job time multiplier: skill 1 = 1.15, 3 = 0.95, 5 = 0.75, times the traits
function H.pace(p) return p and (1.25 - 0.1 * (p.skill or 2)) * mul(p, "pace") or 1 end
function H.walk(p) return mul(p, "walk") end
function H.drain(p) return mul(p, "drain") end
function H.xp(p) return mul(p, "xp") end
function H.rest(p) return mul(p, "rest") end
function H.talk(p) return mul(p, "talk") end

function H.wageFor(def, skill, pro, con)
	local w = (def.wage or 50) * (0.7 + 0.15 * skill) * (trait(pro).wage or 1) * (trait(con).wage or 1)
	return math.floor(w + 0.5)
end
-- the signing price: the role's usual price for that slot, more for skilled people
function H.priceFor(def, n, skill)
	local base = def.prices[math.clamp(n, 1, #def.prices)] or def.prices[#def.prices]
	return math.floor(base * (0.7 + 0.15 * skill) / 10 + 0.5) * 10
end

function H.make(def, rng, taken)
	local name
	for _ = 1, 20 do
		name = H.FIRST[rng:NextInteger(1, #H.FIRST)]
		if not (taken and taken[name]) then break end
	end
	if taken then taken[name] = true end
	-- most people are 2-3 stars; 5 is rare
	local r = rng:NextNumber()
	local skill = r < 0.12 and 1 or r < 0.48 and 2 or r < 0.8 and 3 or r < 0.95 and 4 or 5
	local pro = H.PROS[rng:NextInteger(1, #H.PROS)]
	local con
	repeat con = H.CONS[rng:NextInteger(1, #H.CONS)] until STAT[con] ~= STAT[pro]
	local voice = H.VOICES[rng:NextInteger(1, #H.VOICES)]
	return {
		name = name, surname = H.LAST[rng:NextInteger(1, #H.LAST)], voice = voice, deep = H.DEEP[voice] or (rng:NextNumber() < 0.4),
		skill = skill, pro = pro, con = con, wage = H.wageFor(def, skill, pro, con), seed = rng:NextInteger(1, 1e6),
	}
end

-- a fresh set of candidates for every role
function H.roll(staffDefs, hiredCounts, seed)
	local rng = Random.new(seed or os.time())
	local roles = {}
	local taken = {}
	for _, def in ipairs(staffDefs) do
		local list = {}
		local n = (hiredCounts and hiredCounts[def.id] or 0) + 1
		for i = 1, H.PER_ROLE do
			local c = H.make(def, rng, taken)
			c.price = H.priceFor(def, n, c.skill)
			list[i] = c
		end
		roles[def.id] = list
	end
	return roles
end

-- someone hired before candidates existed: give them a profile that keeps their name
function H.legacy(def, index, name)
	local rng = Random.new(#name * 131 + index * 17 + #def.id)
	local c = H.make(def, rng)
	c.name = name
	c.skill = 2
	c.wage = H.wageFor(def, 2, c.pro, c.con)
	return c
end

function H.stars(n)
	return string.rep("*", n or 0)
end

return H
