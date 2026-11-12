# Round 10: remake everything in the hotel (working plan)

Back to [[Run a Hotel - Design]]

The user's request (2026-11-03), in their words:
> decrease the time customers wait in line for the hotel, remake the entire base hotel to look a lot better, make the pathfinding 100x better, remove all of the custom animations just use the robloxian walk animation for all of the npcs, fix the collisions on all the models because once you play the game long enough all the npcs will be colliding with things and npcs will get stuck making te game unplayable, fix the ui in te top left getting blocked by roblox's ui, instead of having a menu add something similar to this, it will be on the left and it will be like the menu but different buttons, add all of the buttons from the menu to this and make it fit the game style and current ui while not making pc and mobile screens cluttered up, something feels missing from the game please make te quality a lot better and add more features, make the roof slightly taller, make the doors look like actual doors like this picture and make them have similar sizes, remove the room rankings above the hotel rooms, change the reception desks to look something like these ones but not with the staff until you hire them, some things in the lobby like the plants are really big could you make them smaller, make it so you can hire multiple of the same staff members, add a kitchen and all of the items and objects that cooks will need and customers will need to get food, add a lot more features, make it so in build mode i can old right click and move my mouse around to change the camera angle, make the research ui a lot better, add a hotel level so when you level up you can unlock items and object and also unlock research options and new features, on the right of the hotel remove the "build room 104" sign and the fencing, improve the city a lot more, make it so when you reset progress it brings you back to the main menu and when you start it resets your whole hotel, remove save files, the hotel looks really bland and low quality and looks too similar to the original one, remake EVERYTHING and i mean EVERYTIHNG in the hotel and models

Reference pictures they sent:
- a left-side vertical dock: a cream rounded pill holding big round green buttons (icon + chunky outlined label), one gold "Premium" button with a red "!" badge
- a wooden door: brown frame, horizontal plank panel, a dark number plate ("109"), a brass side plate and knob, about 1.4x as tall as a player
- reception desks: a grey stone counter and a wood-and-slate counter with "RECEPTION" carved in big letters, a monitor and keyboard on top

## Order of work
1. [x] NPCs: the stock Roblox (Robloxian) walk for every NPC; NPCs never collide with furniture (collision groups); a new waypoint-graph pathfinder with unstick
2. [x] One save per player (no slots); Reset goes back to the title screen and the next Play starts a fresh hotel; shorter queues; hire several of each staff type
3. [x] Hotel level + XP: levels unlock items, research and features
4. [x] UI: a left dock replacing the Menu button; the top-left HUD clears Roblox's buttons; a research UI remake
5. [x] Hotel shell remake: taller roof, real doors, reception desks, smaller lobby plants, no room star signs, no for-sale sign or fence
6. [x] Remodel all hotel furniture and props (new Blender set)
7. [x] Kitchen: cooks, stoves, fridges, prep counters, a serving counter and dining tables; guests get food
8. [x] Build mode: hold right click to turn the camera; city upgrades
9. [x] Full playtest, notes

## Progress log
- 2026-11-03: step 1 done. RAH_Nav (grid A* with clearance) replaces PathfindingService; NPCs only use Roblox's default walk/run blend; collision group NPCSolid so NPCs never hit furniture. Playtested: nobody stuck.
- 2026-11-03: step 2 done. One save per player, Reset goes back to the title and the next Play starts fresh, shorter queues, several hires of each staff type.
- 2026-11-03: step 3 done. RAH.Levels (30 levels, XP from check-ins, stays, cleaning, research, events, rooms, meals); level locks in the shop, rooms, staff and research; HUD level badge + XP bar; level-up celebration.
- 2026-11-03: step 4 done. Left dock (RAH_Dock in RAH_Coop) replaces the Menu button and the research flask; the hotel card sits under Roblox's top bar; the Research Lab remake (node tree, 3D previews, live lab strip). New icons from ui_icons_r10.py.
- 2026-11-03: steps 5 to 8 done (shell, furniture, kitchen, right-drag camera, city). The second big request (10c) also done:
  - guest life, talk, knocking, door signs, door-knob hand
  - minigames fixed and remade, a reception minigame
  - top bar, goals and achievements
- 2026-11-03 (10c, last part):
  - PS5 / Xbox controller support (RAH_UI pad layer, build-mode pad camera, minigame pad cursor, RAH_Gamepad) and phone fixes
  - weather (RAH_Weather, RAH_WeatherFX, Lighting blend), crowds by hour and weather, umbrellas, walk-ins by weather
  - trunk and pole colliders on street props
  - 12 new build items (rah_props_r10c.py)
  - step 9 playtest done; the test save was restored from its backup
- 10d (2026-11-03): wall-and-door rooms (RAH_Rooms), land plots instead of rooms, left dock centred, cash leaderstats, performance pass (RAH_Perf, fewer walkers). Playtested: land bought, room 201 detected, furnished, a guest stayed. Test save restored.
- 10d part 2: walk-ins ramp with hotel level; classic heads fix the warped guest faces. Tested at level 1 (the line stays at 2) and on a lineup of five fresh NPCs. Save restored.
- 10e (2026-11-04): the user's big list (economy, HUD, phone, gamepass page, title/loading, build tools and items, parking, staff levels and staff room, guest talk/dialogue/anims/luggage/couples/anger/tips, room service, dusty decor, dirty rooms saved, music, visits/requests, empty plots, starter hotel). Playtested; room service delivered end to end. Not reproduced: the walk glitch and queue zigzag. Save restored from `u_665732195_s1_backup_20261104`.
