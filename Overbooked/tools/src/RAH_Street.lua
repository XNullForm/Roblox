-- ReplicatedStorage.RAH.Street: the map's layout, shared by the map builder, crowds, traffic and plots (round 9).
-- +X runs along the street. The hotels face +Z (their glass front at z = 30.2); then the front sidewalk,
-- the road and the shops across the street. Ground level is y = 0; sidewalks are y = 0.5 on top.
local S = {}

S.PLOT_W = 220
S.PLOT_COUNT = 6
S.MID = 3 -- plot 3 sits at x = 0 (where the Edit-time hotel lives)
function S.centre(k) return (k - S.MID) * S.PLOT_W end

S.X0, S.X1 = -840, 1060 -- tunnel mouths at both ends of the street
S.Y = 0.5 -- sidewalk top

-- sidewalks: walking lanes (z) for each direction of foot traffic
S.NEAR = { z0 = 57, z1 = 73, walk = { 60.5, 64.5 } } -- the hotels' side
S.FAR = { z0 = 112, z1 = 126, walk = { 118.6, 121.8 } } -- the shops' side
S.ROAD = { z0 = 73, z1 = 112 }
S.LANES = { { z = 86, dir = -1 }, { z = 98.5, dir = 1 } } -- right-hand traffic
S.PARK = { 77, 108 } -- parking lane centres
S.CENTRE_LINE = 92.25
S.CROSS = { -330, 110, 550 } -- signalised crosswalks (x)
S.CROSS_W = 12

-- the front path from each hotel's door to the sidewalk
S.PATH_Z0, S.PATH_Z1 = 31.5, 57
S.PATH_HALF = 5.5

-- traffic signal cycle (seconds, from server time): cars go, amber, then people walk
S.SIGNAL = { go = 22, amber = 3.5, walk = 12 }
function S.signalPhase(t)
	local c = S.SIGNAL
	local total = c.go + c.amber + c.walk
	local u = t % total
	if u < c.go then return "go", c.go - u end
	if u < c.go + c.amber then return "amber", c.go + c.amber - u end
	return "walk", total - u
end

return S
