# Round 9: the big remake (working plan)

Back to [[Run a Hotel - Design]]

The user's request (2026-11-02), in their words:
> remake all of the ui to be a lot better and have a lot more animations, remake build mode with new features like toggle roof, grid snapping, advanced placement, blocks and shapes for custom decor, custom sizing, a lot more items to build mode and more. Make the npcs have a couple of different walk animations assigned to them, add a lot more names, clothes, hairs, accessories, etc. Remake the main menu to be a lot better, fix the lighting when entering the hotel being very bright and the lighting staying on the screen forever, make the npc sidewalk and hotel entry a lot better basically i want there to be a bunch of npcs on the sidewalk and some of them will turn into your hotel make them walk from the start of the sidewalk to the end even if some plots are not taken, remake the whole base lobby and remake the whole entire map to be a lot better, add traffic and cars and a bunch of stuff. Make the game a lot more fun with more content and a lot higher quality, make the lighting system a lot better make the day and night cycle a lot better, add custom npc events like an all night stay, accessibility needs, baby room, etc. add a lot of these, add a research menu so the player can research new decor, items, stuff for the hotel, neesesaties, upgrades, and allow certain npc events to happen, remake the cars to be a lot better, make the pathfinding a lot better, and probably remodel everything it looks very low quality.

## What Roblox's AI had changed (found 2026-11-02)
- Plots: 6, `PLOT_W = 220`, plot 3 at x = 0. Sidewalk z = 66, front path z = 46, road lanes z = 79 / 93.
- New scripts: `RAH_Crowds` (pedestrians + box cars), `RAH_DayNight`, `RAH_Tutorial`, `RAH_MainMenu` (Play / Tips / Settings, 3 save slots), `RAH_Minigames` (cleaning minigames), `ServerStorage.RAH_Bodies`.
- Menu button (M) replaced the Co-op button: tabs Stats / Staff / Co-op / Settings.
- Build: Wall, Door, movable reception Desk, buyable bed/shower/toilet upgrades (`coreKind`), unfurnished new rooms.
- Config: offline earnings, `SAVE_SLOTS = 3`, pedestrian walk-in chances, `DAY_LENGTH = 480`, receptionist staff.
- **The lighting bug:** `RAH_DayNight.nightness()` returns a negative number all day (its dawn branch catches every hour after 5.5), so the lighting is extrapolated past day: OutdoorAmbient 1.39, a tint of 1.4, negative bloom. Everything is blown out.
- Local mirrors of these live scripts: `Run a Hotel tools/live/` (as pulled) and `src/` (now the working copies). Old mirrors: `tools/archive/src_20261030/`.

## Order of work
1. [x] Lighting + day/night (client look by ClockTime keyframes, interior profile, night lights)
2. [x] Map: road with lanes, sidewalks, crosswalks, city across the street, props, per-plot lots
3. [x] Cars (Blender models) + traffic
4. [x] Sidewalk crowds end to end, walk-ins, better pathfinding
5. [x] NPC variety: walk styles, names, clothes, hair, accessories
6. [x] Lobby remake + remodelled props
7. [x] Build mode remake (roof toggle, grid sizes, height/free rotate, shapes + sizing + paint, many items)
8. [x] Research menu + guest events
9. [x] UI remake + main menu
10. [x] Full playtest, notes

## Progress log
- 2026-11-02: steps 1 to 8 done (lighting, map, cars and traffic, crowds and walk-ins, NPC variety, lobby, build mode, research and 11 guest events).
- 2026-11-03: step 9 done (HUD, Menu and title screen on RAH.UI; game renamed Overbooked). Step 10: playtested the title screen, save cards, HUD, Menu tabs, day card and event guests' arrival; city ambience added. Full stays for 7 of the event kinds are still untested (the test hotel only had 3 rooms).
