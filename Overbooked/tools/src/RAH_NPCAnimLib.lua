-- RAH.NPCAnimLib (round 14): hand-keyed procedural animation for every hotel NPC (guests and staff).
--
-- The server only publishes what an NPC is doing, as attributes on its model:
--   Pose  = "mop" | "desk" | "cook" | "fix" | "door" | "break" | "phone" | "text" | "photo" | "read" | "eat"
--           | "angry" | "wait" | "dance" | "clean" | "inspect" | "sitchat" | nil     (a looping activity)
--   Act   = "name:serial"  a one-shot gesture (wave, nod, bow, shrug, point, clap, cheer, facepalm, stomp, ...)
--   Carry = "case" | "bag" | nil                                                          (an arm override)
-- Every client animates them locally (StarterPlayerScripts.RAH_NPCAnim), on top of the Animator's walk/idle/sit.
--
-- How a motion is written: key poses at times. A key pose may set
--   R / L       : a hand target relative to that shoulder, in units of the arm's reach. x = outward from the
--                 body (mirrored for the left), y = up, z = backward (negative is in front). Solved by 2-bone IK.
--   rw*, lw*    : wrist angles (x flex, y twist, z side), absolute
--   n*, w*, t*  : neck / waist / root rotation, ADDED to the walk/idle underneath
--   px, py, pz  : root offset in studs, added
--   crouch      : 0..1, bends both legs so the feet stay planted (solved from the rig's leg lengths)
--   rh*, rk*, ra*, lh*, lk*, la* : hip / knee / ankle angles, absolute (overrides the legs)
-- Channels are interpolated with monotone cubic curves (no overshoot unless it's keyed), so anticipation and
-- overshoot are written in by hand, the way the Straight Away idles are.

local Lib = {}

local CF, V3 = CFrame.new, Vector3.new
local ANG = CFrame.Angles
local clamp, abs, sqrt, acos, cos, sin, pi, atan2 = math.clamp, math.abs, math.sqrt, math.acos, math.cos, math.sin, math.pi, math.atan2

local REST = { 0.04, -0.98, 0.03 }

---------------------------------------------------------------- the motions

-- shorthand: a hand target
local function h(x, y, z) return { x, y, z } end

Lib.ACTS = {
	-- a proper friendly wave: dip, swing up past the mark, settle, waves that shrink, a lazy drop
	wave = { len = 2.0, pole = { R = { 0.5, -1, 0.6 } }, keys = {
		{ 0.00, { R = REST } },
		{ 0.18, { R = h(0.2, -0.62, -0.1), wz = -0.03, nx = 0.02 } },
		{ 0.42, { R = h(0.49, 0.5, -0.05), wz = 0.06, nz = -0.09, nx = 0.06, rwz = 0.1 } },
		{ 0.55, { R = h(0.48, 0.41, -0.03), wz = 0.05, nz = -0.07 } },
		{ 0.72, { R = h(0.61, 0.4, 0.01), rwz = 0.38 } },
		{ 0.93, { R = h(0.35, 0.45, -0.05), rwz = -0.32, nz = -0.05 } },
		{ 1.13, { R = h(0.58, 0.41, 0.0), rwz = 0.3 } },
		{ 1.33, { R = h(0.39, 0.43, -0.04), rwz = -0.18, nz = -0.06 } },
		{ 1.5, { R = h(0.51, 0.39, -0.02), rwz = 0.08, wz = 0.04 } },
		{ 1.76, { R = h(0.2, -0.6, -0.08), rwz = 0, wz = 0, nz = 0, nx = 0 } },
		{ 2.0, { R = REST } },
	} },
	-- a small hand raise at the waist (staff to a player, guests in passing)
	wave_small = { len = 1.3, pole = { R = { 0.7, -1, 0.1 } }, keys = {
		{ 0.00, { R = REST } },
		{ 0.25, { R = h(0.22, -0.38, -0.46), rwz = 0.05, nx = -0.04, nz = -0.05 } },
		{ 0.45, { R = h(0.28, -0.34, -0.44), rwz = 0.35 } },
		{ 0.62, { R = h(0.22, -0.36, -0.46), rwz = -0.25 } },
		{ 0.8, { R = h(0.26, -0.36, -0.45), rwz = 0.15, nz = -0.02 } },
		{ 1.05, { R = h(0.08, -0.7, -0.1), rwz = 0, nx = 0, nz = 0 } },
		{ 1.3, { R = REST } },
	} },
	nod = { len = 0.95, keys = {
		{ 0.00, { nx = 0, wx = 0 } },
		{ 0.12, { nx = 0.07 } },
		{ 0.3, { nx = -0.3, wx = -0.04 } },
		{ 0.5, { nx = 0.03, wx = 0 } },
		{ 0.66, { nx = -0.15 } },
		{ 0.95, { nx = 0 } },
	} },
	-- the doorman's and receptionist's welcome: hand to the chest, a real bow from the waist
	bow = { len = 1.7, pole = { R = { 1, -0.3, 0.4 }, L = { 1, 0, 0.6 } }, keys = {
		{ 0.00, { R = REST, L = REST, wx = 0, nx = 0 } },
		{ 0.18, { wx = 0.05, nx = 0.04 } },
		{ 0.4, { R = h(-0.44, -0.34, -0.34), L = h(-0.12, -0.8, 0.3) } },
		{ 0.62, { wx = -0.52, nx = -0.24 } },
		{ 0.95, { wx = -0.47, nx = -0.2 } },
		{ 1.3, { wx = 0.04, nx = 0.03 } },
		{ 1.42, { R = h(-0.42, -0.36, -0.33) } },
		{ 1.7, { R = REST, L = REST, wx = 0, nx = 0 } },
	} },
	shrug = { len = 1.3, pole = { R = { 0.2, -0.4, 1 }, L = { 0.2, -0.4, 1 } }, keys = {
		{ 0.00, { R = REST, L = REST, py = 0, nz = 0 } },
		{ 0.35, { R = h(0.38, -0.7, -0.42), L = h(0.36, -0.72, -0.4), rwy = 1.1, lwy = -1.1, py = 0.07, nz = 0.15, nx = 0.04 } },
		{ 0.75, { R = h(0.36, -0.72, -0.4), L = h(0.35, -0.74, -0.38), py = 0.05, nz = 0.12 } },
		{ 1.05, { R = h(0.1, -0.85, -0.1), L = h(0.1, -0.86, -0.1), rwy = 0, lwy = 0, py = 0, nz = 0, nx = 0 } },
		{ 1.3, { R = REST, L = REST } },
	} },
	point = { len = 1.5, pole = { R = { 0.6, -1, 0.3 } }, keys = {
		{ 0.00, { R = REST, wy = 0, ny = 0 } },
		{ 0.16, { R = h(0.1, -0.7, -0.2) } },
		{ 0.4, { R = h(0.13, 0.1, -0.98), wy = -0.14, ny = -0.12, nx = 0.04 } },
		{ 0.52, { R = h(0.12, 0.05, -0.96) } },
		{ 1.1, { R = h(0.12, 0.04, -0.95), wy = -0.12, ny = -0.1 } },
		{ 1.32, { R = h(0.1, -0.7, -0.15), wy = 0, ny = 0, nx = 0 } },
		{ 1.5, { R = REST } },
	} },
	clap = { len = 1.7, pole = { R = { 1, -0.6, 0.3 }, L = { 1, -0.6, 0.3 } }, keys = {
		{ 0.00, { R = REST, L = REST, nx = 0, py = 0 } },
		{ 0.22, { R = h(-0.12, -0.44, -0.5), L = h(-0.14, -0.46, -0.5), nx = 0.06 } },
		{ 0.34, { R = h(-0.4, -0.41, -0.45), L = h(-0.4, -0.42, -0.45), py = 0.03 } },
		{ 0.5, { R = h(-0.14, -0.44, -0.5), L = h(-0.16, -0.44, -0.5), py = 0 } },
		{ 0.62, { R = h(-0.4, -0.41, -0.45), L = h(-0.4, -0.42, -0.45), py = 0.03 } },
		{ 0.78, { R = h(-0.14, -0.44, -0.5), L = h(-0.18, -0.45, -0.5), py = 0 } },
		{ 0.9, { R = h(-0.4, -0.41, -0.45), L = h(-0.4, -0.42, -0.45), py = 0.04 } },
		{ 1.06, { R = h(-0.16, -0.45, -0.5), L = h(-0.19, -0.46, -0.49), py = 0 } },
		{ 1.18, { R = h(-0.4, -0.41, -0.45), L = h(-0.4, -0.42, -0.45), py = 0.02 } },
		{ 1.45, { R = h(0.0, -0.8, -0.2), L = h(0.0, -0.82, -0.2), nx = 0, py = 0 } },
		{ 1.7, { R = REST, L = REST } },
	} },
	cheer = { len = 1.8, pole = { R = { 1, -0.3, 0.2 }, L = { 1, -0.3, 0.2 } }, keys = {
		{ 0.00, { R = REST, L = REST, py = 0, nx = 0 } },
		{ 0.16, { R = h(0.2, -0.75, -0.15), L = h(0.18, -0.78, -0.12), py = -0.08, wx = -0.05 } },
		{ 0.38, { R = h(0.24, 0.97, -0.06), L = h(0.26, 0.95, -0.04), py = 0.16, wx = 0.08, nx = 0.18 } },
		{ 0.6, { R = h(0.32, 0.55, -0.12), L = h(0.3, 0.6, -0.1), py = 0 } },
		{ 0.82, { R = h(0.24, 0.96, -0.06), L = h(0.27, 0.93, -0.05), py = 0.1 } },
		{ 1.04, { R = h(0.34, 0.5, -0.12), L = h(0.32, 0.56, -0.1), py = 0 } },
		{ 1.24, { R = h(0.25, 0.9, -0.07), L = h(0.27, 0.88, -0.05), py = 0.05 } },
		{ 1.55, { R = h(0.12, -0.7, -0.08), L = h(0.12, -0.72, -0.08), py = 0, wx = 0, nx = 0 } },
		{ 1.8, { R = REST, L = REST } },
	} },
	facepalm = { len = 2.2, pole = { R = { 0.6, -1, 0.2 } }, keys = {
		{ 0.00, { R = REST, nx = 0, ny = 0 } },
		{ 0.3, { R = h(-0.3, 0.2, -0.35) } },
		{ 0.48, { R = h(-0.48, 0.47, -0.32), nx = -0.3, wx = -0.06 } },
		{ 0.8, { ny = 0.12 } },
		{ 1.05, { ny = -0.12 } },
		{ 1.3, { ny = 0.08 } },
		{ 1.55, { ny = 0, R = h(-0.47, 0.45, -0.32) } },
		{ 1.9, { R = h(0.0, -0.75, -0.15), nx = 0, wx = 0 } },
		{ 2.2, { R = REST } },
	} },
	stomp = { len = 1.35, pole = { R = { 1, 0, 0.2 }, L = { 1, 0, 0.2 } }, keys = {
		{ 0.00, { R = REST, L = REST, rhx = 0, rkx = 0, py = 0, wx = 0 } },
		{ 0.28, { rhx = 0.95, rkx = -1.15, R = h(0.24, -0.84, 0.1), L = h(0.24, -0.84, 0.1), wx = 0.06, nx = 0.05 } },
		{ 0.44, { rhx = -0.04, rkx = -0.08, py = -0.14, wx = -0.14, nx = -0.12 } },
		{ 0.6, { py = 0.02 } },
		{ 0.9, { py = 0, rhx = 0, rkx = 0 } },
		{ 1.1, { R = h(0.1, -0.92, 0.05), L = h(0.1, -0.92, 0.05), wx = 0, nx = 0 } },
		{ 1.35, { R = REST, L = REST } },
	} },
	thumbs = { len = 1.3, pole = { R = { 1, -1, 0.3 } }, keys = {
		{ 0.00, { R = REST } },
		{ 0.32, { R = h(0.01, -0.42, -0.66), rwy = -1.3, nx = 0.05 } },
		{ 0.42, { R = h(0.02, -0.38, -0.67), nx = -0.08 } },
		{ 0.9, { R = h(0.01, -0.41, -0.66), nx = 0 } },
		{ 1.1, { R = h(0.05, -0.8, -0.1), rwy = 0 } },
		{ 1.3, { R = REST } },
	} },
	look_watch = { len = 2.1, pole = { L = { 1, -1, 0.4 } }, keys = {
		{ 0.00, { L = REST, nx = 0, ny = 0 } },
		{ 0.38, { L = h(-0.3, -0.41, -0.5), lwy = 1.2, nx = -0.38, ny = 0.14 } },
		{ 0.5, { L = h(-0.29, -0.39, -0.5) } },
		{ 1.35, { L = h(-0.29, -0.4, -0.5), nx = -0.36 } },
		{ 1.6, { nx = 0.05, ny = 0, wx = -0.05 } },
		{ 1.8, { L = h(0.05, -0.85, -0.05), lwy = 0, wx = 0, nx = 0 } },
		{ 2.1, { L = REST } },
	} },
	stretch = { len = 2.9, pole = { R = { 1, 0, 0.3 }, L = { 1, 0, 0.3 } }, keys = {
		{ 0.00, { R = REST, L = REST, py = 0, wx = 0, nx = 0 } },
		{ 0.22, { R = h(0.1, -0.6, -0.12), L = h(0.1, -0.62, -0.1), py = -0.05 } },
		{ 0.62, { R = h(-0.05, 0.97, 0.06), L = h(-0.05, 0.97, 0.06), py = 0.07, wx = 0.13, nx = 0.22 } },
		{ 1.2, { wz = 0.11 } },
		{ 1.6, { wz = -0.09 } },
		{ 1.85, { R = h(-0.04, 0.96, 0.05), L = h(-0.05, 0.96, 0.05), wz = 0, py = 0.05 } },
		{ 2.4, { R = h(0.25, -0.5, 0.05), L = h(0.24, -0.52, 0.05), py = 0, wx = 0, nx = 0 } },
		{ 2.9, { R = REST, L = REST } },
	} },
	yawn = { len = 2.4, pole = { R = { 0.6, -1, 0.2 }, L = { 1, 0, 0.3 } }, keys = {
		{ 0.00, { R = REST, L = REST, nx = 0, wx = 0 } },
		{ 0.48, { R = h(-0.47, 0.3, -0.35), L = h(0.55, -0.2, -0.08), nx = 0.26, wx = 0.07 } },
		{ 1.2, { R = h(-0.46, 0.31, -0.36), L = h(0.6, -0.15, -0.06), nx = 0.3 } },
		{ 1.6, { nx = -0.06, wx = -0.02 } },
		{ 1.95, { R = h(0.05, -0.8, -0.1), L = h(0.1, -0.85, -0.05), nx = 0, wx = 0 } },
		{ 2.4, { R = REST, L = REST } },
	} },
	laugh = { len = 1.9, pole = { R = { 1, 0, 0.3 } }, keys = {
		{ 0.00, { R = REST, L = REST, wx = 0, nx = 0, py = 0 } },
		{ 0.25, { wx = 0.13, nx = 0.24, R = h(-0.32, -0.74, -0.32) } },
		{ 0.48, { wx = -0.17, nx = -0.1, py = -0.04, L = h(0.25, -0.76, -0.2) } },
		{ 0.66, { wx = -0.07, py = 0.01 } },
		{ 0.84, { wx = -0.16, py = -0.03 } },
		{ 1.02, { wx = -0.06, py = 0.01 } },
		{ 1.2, { wx = -0.12, py = -0.02 } },
		{ 1.55, { wx = 0, nx = 0, py = 0, R = h(0.0, -0.85, -0.1), L = h(0.06, -0.92, 0.0) } },
		{ 1.9, { R = REST, L = REST } },
	} },
	dust_hands = { len = 1.25, pole = { R = { 1, -0.5, 0.4 }, L = { 1, -0.5, 0.4 } }, keys = {
		{ 0.00, { R = REST, L = REST, nx = 0 } },
		{ 0.28, { R = h(-0.32, -0.52, -0.44), L = h(-0.32, -0.54, -0.38), nx = -0.2 } },
		{ 0.42, { R = h(-0.32, -0.52, -0.36), L = h(-0.32, -0.54, -0.48) } },
		{ 0.56, { R = h(-0.32, -0.52, -0.47), L = h(-0.32, -0.54, -0.37) } },
		{ 0.7, { R = h(-0.32, -0.53, -0.38), L = h(-0.32, -0.55, -0.46) } },
		{ 1.0, { R = h(0.05, -0.85, -0.05), L = h(0.05, -0.85, -0.05), nx = 0 } },
		{ 1.25, { R = REST, L = REST } },
	} },
	present = { len = 1.4, pole = { R = { 1, -1, 0.4 } }, keys = {
		{ 0.00, { R = REST, wx = 0 } },
		{ 0.4, { R = h(0.18, -0.52, -0.76), rwy = 1.2, wx = -0.13, nx = -0.05 } },
		{ 0.52, { R = h(0.18, -0.54, -0.74) } },
		{ 1.0, { wx = 0, nx = 0 } },
		{ 1.15, { R = h(0.06, -0.8, -0.15), rwy = 0 } },
		{ 1.4, { R = REST } },
	} },
	-- talking: picked automatically whenever an NPC says something
	talk1 = { len = 1.45, pole = { R = { 1, -1, 0.4 } }, keys = {
		{ 0.00, { R = REST, nx = 0 } },
		{ 0.35, { R = h(0.21, -0.6, -0.46), rwy = 0.9, nx = -0.07 } },
		{ 0.62, { R = h(0.31, -0.64, -0.42), nx = 0.04 } },
		{ 0.85, { R = h(0.26, -0.62, -0.45), nx = 0 } },
		{ 1.2, { R = h(0.05, -0.85, -0.08), rwy = 0 } },
		{ 1.45, { R = REST } },
	} },
	talk2 = { len = 1.6, pole = { R = { 1, -1, 0.4 }, L = { 1, -1, 0.4 } }, keys = {
		{ 0.00, { R = REST, L = REST, ny = 0 } },
		{ 0.4, { R = h(0.18, -0.64, -0.45), L = h(0.2, -0.64, -0.44), rwy = 0.8, lwy = -0.8, ny = 0.1 } },
		{ 0.78, { R = h(0.36, -0.61, -0.42), L = h(0.34, -0.62, -0.42), nx = -0.05 } },
		{ 1.05, { ny = -0.04, nx = 0 } },
		{ 1.35, { R = h(0.05, -0.85, -0.08), L = h(0.05, -0.86, -0.08), rwy = 0, lwy = 0, ny = 0 } },
		{ 1.6, { R = REST, L = REST } },
	} },
	talk3 = { len = 1.25, pole = { L = { 1, -1, 0.4 } }, keys = {
		{ 0.00, { L = REST, ny = 0, nz = 0 } },
		{ 0.34, { L = h(0.24, -0.56, -0.45), lwy = -0.9, ny = -0.1, nz = 0.06 } },
		{ 0.6, { L = h(0.18, -0.59, -0.47) } },
		{ 1.0, { L = h(0.05, -0.85, -0.08), lwy = 0, ny = 0, nz = 0 } },
		{ 1.25, { L = REST } },
	} },
	head_shake = { len = 1.2, keys = {
		{ 0.00, { ny = 0, nx = 0 } },
		{ 0.18, { ny = 0.3, nx = -0.05 } },
		{ 0.38, { ny = -0.27 } },
		{ 0.58, { ny = 0.18 } },
		{ 0.78, { ny = -0.1 } },
		{ 1.2, { ny = 0, nx = 0 } },
	} },
	scratch_head = { len = 1.9, pole = { R = { 1, -0.6, 0.1 } }, keys = {
		{ 0.00, { R = REST, nz = 0 } },
		{ 0.45, { R = h(-0.16, 0.52, -0.04), nz = -0.12, nx = -0.04 } },
		{ 0.65, { R = h(-0.12, 0.53, -0.05) } },
		{ 0.85, { R = h(-0.18, 0.51, -0.03) } },
		{ 1.05, { R = h(-0.12, 0.53, -0.05) } },
		{ 1.25, { R = h(-0.16, 0.52, -0.04) } },
		{ 1.6, { R = h(0.04, -0.8, -0.05), nz = 0, nx = 0 } },
		{ 1.9, { R = REST } },
	} },
	-- a Karen jabbing a finger at you
	point_angry = { len = 1.7, pole = { R = { 0.6, -1, 0.3 }, L = { 1, 0.3, 0.2 } }, keys = {
		{ 0.00, { R = REST, L = REST, wx = 0 } },
		{ 0.3, { R = h(0.04, -0.08, -0.96), L = h(0.0, -0.68, -0.06), wx = -0.13, nx = -0.06 } },
		{ 0.46, { R = h(0.04, -0.12, -0.68) } },
		{ 0.6, { R = h(0.04, -0.08, -0.97), wx = -0.15 } },
		{ 0.76, { R = h(0.04, -0.12, -0.7) } },
		{ 0.92, { R = h(0.04, -0.07, -0.97), wx = -0.16, nx = -0.1 } },
		{ 1.4, { R = h(0.08, -0.8, -0.1), wx = 0, nx = 0 } },
		{ 1.7, { R = REST, L = REST } },
	} },
	arms_out = { len = 1.6, pole = { R = { 1, -0.6, 0.3 }, L = { 1, -0.6, 0.3 } }, keys = {
		{ 0.00, { R = REST, L = REST, nx = 0, ny = 0 } },
		{ 0.4, { R = h(0.66, -0.48, -0.36), L = h(0.64, -0.5, -0.34), rwy = 1.1, lwy = -1.1, nx = 0.16 } },
		{ 0.7, { ny = 0.14 } },
		{ 0.95, { ny = -0.12 } },
		{ 1.15, { ny = 0 } },
		{ 1.35, { R = h(0.15, -0.8, -0.1), L = h(0.15, -0.8, -0.1), rwy = 0, lwy = 0, nx = 0 } },
		{ 1.6, { R = REST, L = REST } },
	} },
	sip = { len = 2.1, pole = { R = { 0.7, -1, 0.3 } }, keys = {
		{ 0.00, { R = REST, nx = 0 } },
		{ 0.35, { R = h(-0.09, -0.59, -0.46) } },
		{ 0.7, { R = h(-0.46, 0.27, -0.38), nx = 0.16, rwx = -0.4 } },
		{ 1.25, { R = h(-0.46, 0.28, -0.37), nx = 0.18 } },
		{ 1.55, { R = h(-0.09, -0.59, -0.46), nx = 0, rwx = 0 } },
		{ 2.1, { R = REST } },
	} },
	-- crouch to pick something up (a dropped bag, rubbish)
	pickup = { len = 1.6, pole = { R = { 1, 0, 0.4 } }, keys = {
		{ 0.00, { crouch = 0, wx = 0, R = REST, nx = 0 } },
		{ 0.5, { crouch = 0.75, wx = -0.4, R = h(0.05, -0.8, -0.45), nx = -0.3 } },
		{ 0.8, { crouch = 0.72, R = h(0.05, -0.78, -0.42) } },
		{ 1.25, { crouch = 0, wx = 0, nx = 0, R = h(0.06, -0.9, -0.05) } },
		{ 1.6, { R = REST } },
	} },
	-- hand on the chest, sorry (receptionist when you complain)
	apologise = { len = 1.6, pole = { R = { 1, -0.3, 0.4 } }, keys = {
		{ 0.00, { R = REST, nx = 0, nz = 0 } },
		{ 0.38, { R = h(-0.44, -0.34, -0.34), nx = -0.18, nz = 0.08, wx = -0.06 } },
		{ 1.1, { R = h(-0.43, -0.36, -0.34), nx = -0.14 } },
		{ 1.35, { R = h(0.0, -0.8, -0.15), nx = 0, nz = 0, wx = 0 } },
		{ 1.6, { R = REST } },
	} },
}

-- looping activities. `len` is the period; the last key should match the first.
local function typing(len, step)
	local keys = {}
	local t, i = 0, 0
	while t <= len + 1e-6 do
		local up = (i % 2 == 0)
		local glance = t > 3.3 and t < 4.4
		keys[#keys + 1] = { t, {
			R = h(-0.14 + (up and 0.02 or -0.01), -0.6 + (up and 0.03 or 0), -0.6),
			L = h(-0.15 + (up and -0.01 or 0.02), -0.61 + (up and 0 or 0.03), -0.59),
			nx = glance and 0.02 or -0.24, ny = glance and 0.12 or 0,
		} }
		t = t + step * (0.8 + ((i * 7) % 5) / 10)
		i = i + 1
	end
	keys[#keys] = { len, keys[1][2] }
	keys[#keys][1] = len
	return keys
end

local function circle(cx, cy, cz, rx, rz, n, len, extra)
	local keys = {}
	for i = 0, n do
		local a = (i / n) * pi * 2
		local k = { R = h(cx + cos(a) * rx, cy, cz + sin(a) * rz) }
		if extra then extra(k, i, a) end
		keys[#keys + 1] = { len * i / n, k }
	end
	return keys
end

local POLE_FRONT = { 1, -1, 0.4 }

Lib.POSES = {
	-- the doorman at ease: hands behind the back, chest up, rocking on the toes, watching the street
	door = { len = 7.2, pole = { R = { 0.8, 0, 0.7 }, L = { 0.8, 0, 0.7 } }, keys = {
		{ 0.0, { R = h(-0.16, -0.78, 0.33), L = h(-0.16, -0.78, 0.33), wx = 0.04, py = 0, ny = 0 } },
		{ 1.4, { py = 0.04, nx = 0.03 } },
		{ 2.0, { py = 0 } },
		{ 2.6, { ny = 0.52, wy = 0.06 } },
		{ 3.5, { ny = 0.5 } },
		{ 4.2, { ny = 0, wy = 0, nx = 0 } },
		{ 4.8, { py = 0.035 } },
		{ 5.3, { py = 0, ny = -0.46, wy = -0.05 } },
		{ 6.3, { ny = -0.44 } },
		{ 7.2, { R = h(-0.16, -0.78, 0.33), L = h(-0.16, -0.78, 0.33), wx = 0.04, py = 0, ny = 0, wy = 0 } },
	} },
	desk = { len = 6, pole = { R = POLE_FRONT, L = POLE_FRONT }, keys = typing(6, 0.17) },
	-- sweeping a mop: the whole body turns into each stroke
	mop = { len = 1.7, crouchLegs = true, pole = { R = { 1, -0.6, 0.5 }, L = { 1, -0.6, 0.5 } }, keys = {
		{ 0.0, { R = h(-0.22, -0.42, -0.55), L = h(-0.5, -0.7, -0.5), wy = 0.3, wx = -0.18, crouch = 0.12, nx = -0.25, ny = -0.12 } },
		{ 0.2, { wy = 0.34 } },
		{ 0.75, { R = h(-0.14, -0.44, -0.58), L = h(-0.44, -0.72, -0.52), wy = -0.28, crouch = 0.18, ny = 0.12 } },
		{ 0.85, { wy = -0.32 } },
		{ 1.0, { wy = -0.31 } },
		{ 1.55, { wy = 0.27, crouch = 0.12 } },
		{ 1.7, { R = h(-0.22, -0.42, -0.55), L = h(-0.5, -0.7, -0.5), wy = 0.3, wx = -0.18, crouch = 0.12, nx = -0.25, ny = -0.12 } },
	} },
	-- stirring a pan, the other hand on the handle, a toss now and then
	cook = { len = 2.4, pole = { R = POLE_FRONT, L = POLE_FRONT }, keys = circle(-0.18, -0.58, -0.58, 0.07, 0.06, 8, 2.4, function(k, i)
		k.L = h(-0.1, -0.5 + ((i == 6) and 0.1 or 0), -0.56)
		k.nx = -0.3
		k.wx = -0.08
		k.wz = (i < 4) and 0.02 or -0.02
	end) },
	-- crouched at a repair, knocking with the wrench
	fix = { len = 1.3, pole = { R = { 1, -0.4, 0.6 }, L = { 1, -0.4, 0.6 } }, keys = {
		{ 0.0, { crouch = 0.85, wx = -0.3, nx = -0.3, R = h(-0.04, -0.7, -0.72), L = h(-0.06, -0.7, -0.6) } },
		{ 0.32, { R = h(-0.04, -0.64, -0.68) } },
		{ 0.44, { R = h(-0.1, -0.67, -0.74), nx = -0.34 } },
		{ 0.62, { R = h(-0.04, -0.69, -0.72), nx = -0.3 } },
		{ 0.9, { R = h(-0.08, -0.74, -0.74), ny = 0.08 } },
		{ 1.3, { crouch = 0.85, wx = -0.3, nx = -0.3, ny = 0, R = h(-0.04, -0.7, -0.72), L = h(-0.06, -0.7, -0.6) } },
	} },
	-- on a break: coffee in hand, a sip every so often, shifting weight
	["break"] = { len = 8, prop = "Cup", pole = { R = POLE_FRONT }, keys = {
		{ 0.0, { R = h(-0.09, -0.59, -0.46), L = h(0.06, -0.92, 0.06), tz = 0.03, nx = 0 } },
		{ 1.8, { tz = -0.03, ny = 0.25 } },
		{ 2.8, { R = h(-0.09, -0.59, -0.46), ny = 0 } },
		{ 3.3, { R = h(-0.46, 0.27, -0.38), nx = 0.16, rwx = -0.4 } },
		{ 4.4, { R = h(-0.46, 0.28, -0.37), nx = 0.17 } },
		{ 4.9, { R = h(-0.09, -0.59, -0.46), nx = 0, rwx = 0 } },
		{ 6.2, { tz = 0.035, ny = -0.2 } },
		{ 8.0, { R = h(-0.09, -0.59, -0.46), L = h(0.06, -0.92, 0.06), tz = 0.03, nx = 0, ny = 0 } },
	} },
	phone = { len = 6, prop = "PhoneL", pole = { R = POLE_FRONT, L = { 0.3, -1, 0.5 } }, keys = {
		{ 0.0, { L = h(-0.18, 0.44, -0.06), R = REST, nz = 0.12, ny = 0, tz = 0.02 } },
		{ 1.2, { R = h(0.24, -0.64, -0.4), rwy = 0.9, ny = 0.15 } },
		{ 2.2, { R = h(0.08, -0.8, -0.1), rwy = 0, tz = -0.02 } },
		{ 3.2, { ny = -0.18, nx = -0.06 } },
		{ 4.3, { R = REST, nx = 0.04 } },
		{ 6.0, { L = h(-0.18, 0.44, -0.06), R = REST, nz = 0.12, ny = 0, tz = 0.02, nx = 0 } },
	} },
	text = { len = 3, prop = "PhoneR", pole = { R = POLE_FRONT, L = POLE_FRONT }, keys = {
		{ 0.0, { R = h(-0.24, -0.54, -0.45), L = h(-0.25, -0.56, -0.44), rwx = 0, nx = -0.45 } },
		{ 0.25, { rwx = 0.08 } },
		{ 0.5, { rwx = -0.04 } },
		{ 0.8, { rwx = 0.07 } },
		{ 1.3, { rwx = 0, ny = 0.06 } },
		{ 1.6, { rwx = 0.08 } },
		{ 1.9, { rwx = -0.03 } },
		{ 2.4, { rwx = 0.06, ny = 0 } },
		{ 3.0, { R = h(-0.24, -0.54, -0.45), L = h(-0.25, -0.56, -0.44), rwx = 0, nx = -0.45 } },
	} },
	photo = { len = 3, prop = "PhoneR", pole = { R = { 1, -1, 0.3 }, L = { 1, -1, 0.3 } }, keys = {
		{ 0.0, { R = h(-0.37, 0.16, -0.74), L = h(-0.37, 0.15, -0.74), nx = 0.04, wy = 0 } },
		{ 1.4, { wy = 0.06 } },
		{ 3.0, { R = h(-0.37, 0.16, -0.74), L = h(-0.37, 0.15, -0.74), nx = 0.04, wy = 0 } },
	} },
	read = { len = 7, prop = "Book", pole = { R = POLE_FRONT, L = POLE_FRONT }, keys = {
		{ 0.0, { R = h(-0.24, -0.54, -0.55), L = h(-0.24, -0.55, -0.55), nx = -0.36, ny = 0 } },
		{ 2.5, { ny = 0.05 } },
		{ 4.5, { ny = -0.05 } },
		{ 5.2, { R = h(-0.36, -0.5, -0.56) } },
		{ 5.5, { R = h(-0.12, -0.52, -0.55) } },
		{ 5.9, { R = h(-0.24, -0.54, -0.55) } },
		{ 7.0, { R = h(-0.24, -0.54, -0.55), L = h(-0.24, -0.55, -0.55), nx = -0.36, ny = 0 } },
	} },
	eat = { len = 4.5, pole = { R = POLE_FRONT, L = POLE_FRONT }, keys = {
		{ 0.0, { R = h(-0.14, -0.76, -0.62), L = h(-0.1, -0.78, -0.56), nx = -0.25 } },
		{ 0.9, { R = h(-0.46, 0.27, -0.38), nx = 0.02 } },
		{ 1.25, { R = h(-0.45, 0.25, -0.38), nx = 0.06 } },
		{ 1.8, { R = h(-0.14, -0.76, -0.62), nx = -0.12 } },
		{ 2.6, { nx = -0.05 } },
		{ 3.2, { nx = -0.2 } },
		{ 4.5, { R = h(-0.14, -0.76, -0.62), L = h(-0.1, -0.78, -0.56), nx = -0.25 } },
	} },
	-- hands on hips, tapping a foot (never folded arms)
	angry = { len = 3.2, pole = { R = { 1, 0.3, 0.2 }, L = { 1, 0.3, 0.2 } }, keys = {
		{ 0.0, { R = h(0.0, -0.68, -0.06), L = h(0.0, -0.69, -0.05), rax = 0, wx = -0.03, ny = 0 } },
		{ 0.2, { rax = 0.35 } }, { 0.4, { rax = 0 } },
		{ 0.6, { rax = 0.35 } }, { 0.8, { rax = 0 } },
		{ 1.0, { rax = 0.35 } }, { 1.2, { rax = 0 } },
		{ 1.7, { ny = 0.22 } },
		{ 2.3, { ny = -0.2 } },
		{ 2.8, { ny = 0, rax = 0 } },
		{ 3.2, { R = h(0.0, -0.68, -0.06), L = h(0.0, -0.69, -0.05), rax = 0, wx = -0.03, ny = 0 } },
	} },
	-- waiting in a line: hands loosely clasped, weight shifts, glances around
	wait = { len = 6.5, pole = { R = { 1, -0.2, 0.6 }, L = { 1, -0.2, 0.6 } }, keys = {
		{ 0.0, { R = h(-0.4, -0.75, -0.26), L = h(-0.4, -0.76, -0.25), tz = 0.03, ny = 0 } },
		{ 1.8, { tz = -0.03, ny = 0.3 } },
		{ 2.6, { ny = 0.28 } },
		{ 3.3, { ny = 0, nx = 0.04 } },
		{ 4.6, { tz = 0.035, ny = -0.25, nx = 0 } },
		{ 5.4, { ny = -0.22 } },
		{ 6.5, { R = h(-0.4, -0.75, -0.26), L = h(-0.4, -0.76, -0.25), tz = 0.03, ny = 0 } },
	} },
	dance = { len = 1.1, pole = { R = { 1, -0.8, 0.3 }, L = { 1, -0.8, 0.3 } }, keys = {
		{ 0.0, { py = 0, wz = 0.1, R = h(0.3, -0.54, -0.35), L = h(0.3, -0.6, -0.32), nx = 0.05 } },
		{ 0.27, { py = -0.11, wz = 0.02, R = h(0.32, -0.62, -0.34), L = h(0.28, -0.54, -0.34), nx = -0.06 } },
		{ 0.55, { py = 0, wz = -0.1, R = h(0.3, -0.6, -0.32), L = h(0.3, -0.54, -0.35), nx = 0.05 } },
		{ 0.82, { py = -0.11, wz = -0.02, R = h(0.28, -0.54, -0.34), L = h(0.32, -0.62, -0.34), nx = -0.06 } },
		{ 1.1, { py = 0, wz = 0.1, R = h(0.3, -0.54, -0.35), L = h(0.3, -0.6, -0.32), nx = 0.05 } },
	} },
	-- wiping a surface in circles, the other hand braced
	clean = { len = 1.6, pole = { R = POLE_FRONT, L = POLE_FRONT }, keys = circle(-0.1, -0.66, -0.68, 0.12, 0.09, 8, 1.6, function(k, i)
		k.L = h(-0.05, -0.74, -0.56)
		k.wx = -0.34
		k.nx = -0.3
		k.wy = (i < 4) and 0.05 or -0.05
	end) },
	-- the hotel inspector: clipboard, pen, looking around
	inspect = { len = 6, prop = "Clipboard", pole = { R = POLE_FRONT, L = POLE_FRONT }, keys = {
		{ 0.0, { L = h(-0.24, -0.54, -0.46), R = h(-0.38, -0.51, -0.47), nx = -0.4, ny = 0 } },
		{ 0.4, { R = h(-0.36, -0.52, -0.48) } }, { 0.8, { R = h(-0.39, -0.5, -0.46) } },
		{ 1.2, { R = h(-0.35, -0.52, -0.47) } },
		{ 1.9, { nx = 0.06, ny = 0.45, R = h(-0.24, -0.64, -0.4) } },
		{ 3.0, { ny = 0.42 } },
		{ 3.6, { ny = -0.4 } },
		{ 4.6, { ny = -0.38, nx = 0.04 } },
		{ 5.2, { nx = -0.4, ny = 0, R = h(-0.38, -0.51, -0.47) } },
		{ 6.0, { L = h(-0.24, -0.54, -0.46), R = h(-0.38, -0.51, -0.47), nx = -0.4, ny = 0 } },
	} },
	-- seated and chatting: hands on the lap, gestures now and then
	sitchat = { len = 5, pole = { R = POLE_FRONT, L = POLE_FRONT }, keys = {
		{ 0.0, { R = h(-0.25, -0.72, -0.5), L = h(-0.25, -0.73, -0.5), ny = 0 } },
		{ 1.2, { R = h(0.16, -0.62, -0.5), rwy = 0.9, ny = 0.12 } },
		{ 1.9, { R = h(0.24, -0.64, -0.48), nx = -0.05 } },
		{ 2.6, { R = h(-0.25, -0.72, -0.5), rwy = 0, nx = 0 } },
		{ 3.8, { ny = -0.06 } },
		{ 5.0, { R = h(-0.25, -0.72, -0.5), L = h(-0.25, -0.73, -0.5), ny = 0 } },
	} },
}

-- the arm overrides for luggage (they win over a pose's right hand)
Lib.CARRY = {
	case = { R = h(0.14, -0.84, 0.42), pole = { 1, 0, -0.3 }, wz = 0.035, rwx = 0.15 },
	bag = { R = h(0.17, -0.97, 0.03), pole = { 1, 0, 0.3 }, wz = 0.075, nz = -0.03 },
	box = { R = h(-0.22, -0.48, -0.5), L = h(-0.22, -0.48, -0.5), pole = { 1, -0.6, 0.4 }, wx = 0.05 },
}

---------------------------------------------------------------- curves

-- monotone cubic (Fritsch-Carlson) on one channel
local function buildChannel(ts, vs)
	local n = #ts
	local m = table.create(n, 0)
	if n >= 2 then
		local d = table.create(n - 1, 0)
		for i = 1, n - 1 do
			local dt = ts[i + 1] - ts[i]
			d[i] = dt > 1e-6 and (vs[i + 1] - vs[i]) / dt or 0
		end
		m[1], m[n] = d[1], d[n - 1]
		for i = 2, n - 1 do
			if d[i - 1] * d[i] <= 0 then m[i] = 0 else m[i] = (d[i - 1] + d[i]) / 2 end
		end
		for i = 1, n - 1 do
			if d[i] == 0 then
				m[i], m[i + 1] = 0, 0
			else
				local a, b = m[i] / d[i], m[i + 1] / d[i]
				local s = a * a + b * b
				if s > 9 then
					local k = 3 / sqrt(s)
					m[i], m[i + 1] = k * a * d[i], k * b * d[i]
				end
			end
		end
		-- the ends of a motion ease in and out
		m[1], m[n] = 0, 0
	end
	return { t = ts, v = vs, m = m, n = n }
end

local function evalChannel(c, t)
	local ts, n = c.t, c.n
	if n == 1 or t <= ts[1] then return c.v[1] end
	if t >= ts[n] then return c.v[n] end
	local lo, hi = 1, n
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if ts[mid] <= t then lo = mid else hi = mid end
	end
	local t0, t1 = ts[lo], ts[hi]
	local dt = t1 - t0
	local s = (t - t0) / dt
	local s2, s3 = s * s, s * s * s
	return (2 * s3 - 3 * s2 + 1) * c.v[lo] + (s3 - 2 * s2 + s) * dt * c.m[lo]
		+ (-2 * s3 + 3 * s2) * c.v[hi] + (s3 - s2) * dt * c.m[hi]
end

-- key poses -> channels
local function compile(def)
	local chans = {}
	local acc = {}
	local function push(name, t, v)
		local a = acc[name]
		if not a then a = { {}, {} } acc[name] = a end
		table.insert(a[1], t)
		table.insert(a[2], v)
	end
	for _, key in ipairs(def.keys) do
		local t, p = key[1], key[2]
		for k, v in pairs(p) do
			if k == "R" or k == "L" then
				push(k .. "x", t, v[1]); push(k .. "y", t, v[2]); push(k .. "z", t, v[3])
			else
				push(k, t, v)
			end
		end
	end
	for name, a in pairs(acc) do chans[name] = buildChannel(a[1], a[2]) end
	def.chans = chans
	def.useR = chans.Rx ~= nil
	def.useL = chans.Lx ~= nil
	local legs = false
	for name in pairs(chans) do
		if name:match("^[rl][hka][xyz]$") then legs = true end
	end
	def.useLegs = legs
	def.useCrouch = chans.crouch ~= nil
	return def
end
for name, d in pairs(Lib.ACTS) do d.name = name; compile(d) end
for name, d in pairs(Lib.POSES) do d.name = name; d.loop = true; compile(d) end

-- channels that a lag delays (follow-through): forearm and hand behind the shoulder, head behind the body
local LAG = { rwx = 0.07, rwy = 0.07, rwz = 0.07, lwx = 0.07, lwy = 0.07, lwz = 0.07, nx = 0.12, ny = 0.12, nz = 0.12 }

-- sample a motion at time t into `out` (a flat table of channel values)
function Lib.sample(def, t, out)
	for name, c in pairs(def.chans) do
		local tt = t - (LAG[name] or 0)
		if def.loop then tt = tt % def.len elseif tt < 0 then tt = 0 end
		out[name] = evalChannel(c, tt)
	end
	return out
end

---------------------------------------------------------------- the rig

local JOINTS = {
	root = { "LowerTorso", "Root" }, waist = { "UpperTorso", "Waist" }, neck = { "Head", "Neck" },
	rs = { "RightUpperArm", "RightShoulder" }, re = { "RightLowerArm", "RightElbow" }, rw = { "RightHand", "RightWrist" },
	ls = { "LeftUpperArm", "LeftShoulder" }, le = { "LeftLowerArm", "LeftElbow" }, lw = { "LeftHand", "LeftWrist" },
	rh = { "RightUpperLeg", "RightHip" }, rk = { "RightLowerLeg", "RightKnee" }, ra = { "RightFoot", "RightAnkle" },
	lh = { "LeftUpperLeg", "LeftHip" }, lk = { "LeftLowerLeg", "LeftKnee" }, la = { "LeftFoot", "LeftAnkle" },
}
Lib.JOINTS = JOINTS

-- Motor6D and the newer AnimationConstraint joints read the same way: C0/C1 = the two attachment frames
local function jc0(m) if m:IsA("Motor6D") then return m.C0 end return m.Attachment0 and m.Attachment0.CFrame or CFrame.identity end
local function jc1(m) if m:IsA("Motor6D") then return m.C1 end return m.Attachment1 and m.Attachment1.CFrame or CFrame.identity end
local function jp1(m) if m:IsA("Motor6D") then return m.Part1 end return m.Attachment1 and m.Attachment1.Parent end
local function J(m) return { C0 = jc0(m), C1 = jc1(m), Part1 = jp1(m) } end

local function armInfo(j, side)
	local sh, el, wr = j[side .. "s"], j[side .. "e"], j[side .. "w"]
	if not (sh and el and wr) then return nil end
	sh, el, wr = J(sh), J(el), J(wr)
	-- E: shoulder joint -> elbow joint (upper arm space). F: elbow joint -> the middle of the hand (forearm space).
	-- R15 shoulder joints sit at the inner top of the arm, so E leans outward; the solve keeps that geometry.
	local E = el.C0.Position - sh.C1.Position
	local hand = wr.Part1
	local F = (wr.C0.Position - el.C1.Position) + (hand and (-wr.C1.Position + V3(0, -hand.Size.Y * 0.25, 0)) or V3())
	local elRot = el.C0.Rotation * el.C1.Rotation:Inverse()
	F = elRot * F
	local info = {
		E = E, F = F, c0r = sh.C0.Rotation, c1r = sh.C1.Rotation, elC0r = el.C0.Rotation, elC1r = el.C1.Rotation,
		side = side == "r" and 1 or -1,
	}
	local best = 0
	for i = 0, 28 do
		local th = i * 0.1
		local hp = E + ANG(th, 0, 0) * F
		if hp.Magnitude > best then best = hp.Magnitude end
	end
	info.reach = best
	return info
end

local function legInfo(j, side)
	local hip, knee, ank = j[side .. "h"], j[side .. "k"], j[side .. "a"]
	if not (hip and knee and ank) then return nil end
	hip, knee, ank = J(hip), J(knee), J(ank)
	local Lt = (knee.C0.Position - hip.C1.Position).Magnitude
	local Ls = (ank.C0.Position - knee.C1.Position).Magnitude
	if Lt < 0.05 or Ls < 0.05 then return nil end
	return { Lt = Lt, Ls = Ls }
end

function Lib.rig(model)
	local j = {}
	for key, pair in pairs(JOINTS) do
		local part = model:FindFirstChild(pair[1])
		local m = part and part:FindFirstChild(pair[2])
		if m and (m:IsA("Motor6D") or m:IsA("AnimationConstraint")) then j[key] = m end
	end
	if not (j.root and j.waist and j.neck) then return nil end
	return {
		model = model, j = j,
		armR = armInfo(j, "r"), armL = armInfo(j, "l"),
		legR = legInfo(j, "r"), legL = legInfo(j, "l"),
	}
end

-- two-bone IK for an arm. target: hand position relative to the shoulder (reach units, x mirrored to outward).
-- The elbow bends about its own X axis; the back of the upper arm (+Z) turns toward `pole` (where the elbow points).
-- Returns the shoulder and elbow Transforms.
local BACK = V3(0, 0, 1)
function Lib.solveArm(arm, tx, ty, tz, pole)
	local s = arm.side
	local d = V3(tx * s, ty, tz) * arm.reach
	local E, F = arm.E, arm.F
	-- elbow angle: |E + Rx(th) F| = D, written as A cos th + B sin th = C
	local D = d.Magnitude
	local A = E.Y * F.Y + E.Z * F.Z
	local B = -E.Y * F.Z + E.Z * F.Y
	local C = (D * D - E:Dot(E) - F:Dot(F)) / 2 - E.X * F.X
	local Rr = sqrt(A * A + B * B)
	local th = 0
	if Rr > 1e-5 then
		local base = atan2(B, A)
		local q = acos(clamp(C / Rr, -1, 1))
		local t1, t2 = base + q, base - q
		-- the bend lives in [0, 2.7]; pick the root that does
		local function fit(t)
			t = (t + pi) % (2 * pi) - pi
			return t
		end
		t1, t2 = fit(t1), fit(t2)
		if t1 >= -0.05 and t1 <= 2.7 then th = t1 elseif t2 >= -0.05 and t2 <= 2.7 then th = t2
		else th = (math.abs(t1) < math.abs(t2)) and t1 or t2 end
		th = clamp(th, 0, 2.6)
	end
	local elbowT = ANG(th, 0, 0)
	local H = E + arm.elC0r * elbowT * arm.elC0r:Inverse() * F
	-- shoulder: H -> d, the arm's back -> pole
	local dh = D > 1e-4 and d.Unit or V3(0, -1, 0)
	local hh = H.Unit
	local b1 = BACK - hh * hh:Dot(BACK)
	if b1.Magnitude < 1e-3 then b1 = V3(1, 0, 0) - hh * hh.X end
	b1 = b1.Unit
	local p = pole and V3(pole[1] * s, pole[2], pole[3]) or V3(0.2 * s, -0.1, 1)
	local b2 = p - dh * p:Dot(dh)
	if b2.Magnitude < 1e-3 then
		b2 = BACK - dh * dh.Z
		if b2.Magnitude < 1e-3 then b2 = V3(1, 0, 0) end
	end
	b2 = b2.Unit
	local from = CFrame.fromMatrix(V3(), hh, b1, hh:Cross(b1))
	local to = CFrame.fromMatrix(V3(), dh, b2, dh:Cross(b2))
	local M = to * from:Inverse()
	local shoulder = arm.c0r:Inverse() * M * arm.c1r
	return shoulder.Rotation, elbowT
end

-- a crouch: hip, knee and ankle angles plus the root drop so the feet stay planted
function Lib.solveCrouch(leg, c)
	local Lt, Ls = leg.Lt, leg.Ls
	local full = Lt + Ls
	local D = full * (1 - 0.42 * clamp(c, 0, 1))
	D = clamp(D, abs(Lt - Ls) + 0.05, full * 0.999)
	-- the foot stays under the hip but a little forward; the knee goes forward
	local a = acos(clamp((Lt * Lt + D * D - Ls * Ls) / (2 * Lt * D), -1, 1))
	local k = pi - acos(clamp((Lt * Lt + Ls * Ls - D * D) / (2 * Lt * Ls), -1, 1))
	local lean = 0.12 * c
	local hip = a + lean
	local knee = -k
	local ankle = -(hip + knee)
	return hip, knee, ankle, full - D
end

---------------------------------------------------------------- props (client only)

local function part(name, size, color, mat, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.Anchored = false, false, false, true, false
	p.CastShadow = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function weld(a, b, c0)
	local w = Instance.new("Weld")
	w.Part0, w.Part1, w.C0 = a, b, c0
	w.Parent = b
	return w
end

-- builds a prop welded to the given hand; returns the model
function Lib.prop(kind, model)
	local handName = (kind == "PhoneL" or kind == "Clipboard") and "LeftHand" or "RightHand"
	local hand = model:FindFirstChild(handName)
	if not hand then return nil end
	local m = Instance.new("Model")
	m.Name = "RAH_AnimProp"
	if kind == "PhoneL" or kind == "PhoneR" then
		local body = part("Phone", V3(0.34, 0.66, 0.07), Color3.fromRGB(28, 30, 36), Enum.Material.SmoothPlastic, m)
		local scr = part("Screen", V3(0.3, 0.58, 0.01), Color3.fromRGB(120, 170, 230), Enum.Material.Neon, m)
		weld(body, scr, CF(0, 0, -0.04))
		local c0 = kind == "PhoneL" and (CF(0.05, -0.2, -0.05) * ANG(0, math.rad(80), 0)) or (CF(0, -0.18, -0.12) * ANG(math.rad(-70), 0, 0))
		weld(hand, body, c0)
	elseif kind == "Cup" then
		local cup = part("Cup", V3(0.36, 0.3, 0.3), Color3.fromRGB(240, 236, 226), Enum.Material.SmoothPlastic, m)
		cup.Shape = Enum.PartType.Cylinder
		local coffee = part("Coffee", V3(0.02, 0.26, 0.26), Color3.fromRGB(70, 42, 24), Enum.Material.SmoothPlastic, m)
		coffee.Shape = Enum.PartType.Cylinder
		weld(cup, coffee, CF(0.16, 0, 0))
		weld(hand, cup, CF(0, -0.22, -0.2) * ANG(0, 0, math.rad(90)))
	elseif kind == "Book" then
		local cover = part("Cover", V3(0.95, 1.25, 0.16), Color3.fromRGB(122, 40, 42), Enum.Material.Leather, m)
		local pages = part("Pages", V3(0.88, 1.18, 0.13), Color3.fromRGB(246, 238, 218), Enum.Material.SmoothPlastic, m)
		weld(cover, pages, CF(0, 0, -0.02))
		weld(hand, cover, CF(-0.4, -0.2, -0.25) * ANG(math.rad(-60), 0, 0))
	elseif kind == "Clipboard" then
		local board = part("Board", V3(0.85, 1.15, 0.06), Color3.fromRGB(150, 104, 62), Enum.Material.Wood, m)
		local paper = part("Paper", V3(0.75, 0.95, 0.01), Color3.fromRGB(248, 246, 240), Enum.Material.SmoothPlastic, m)
		weld(board, paper, CF(0, -0.06, -0.035))
		local clip = part("Clip", V3(0.34, 0.12, 0.06), Color3.fromRGB(190, 192, 198), Enum.Material.Metal, m)
		weld(board, clip, CF(0, 0.54, -0.05))
		weld(hand, board, CF(0.35, -0.2, -0.25) * ANG(math.rad(-60), 0, 0))
	else
		m:Destroy()
		return nil
	end
	m.Parent = model
	return m
end

return Lib
