# Overbooked (Roblox hotel tycoon)

Everything about **Overbooked** (first called *Run a Hotel*): the design notes, the technical map, every game script, the Blender/Python build tools and the screenshots.
Roblox Studio place id **75953879612667**.

The game was renamed **Overbooked** on 2026-11-03. The note and folder names stay "Run a Hotel" so links keep working.

A Roblox game where you run your own hotel. Guests walk up from the street, you let them in, they check in at reception, use their room (toilet, shower, bed), pay when they check out, and you clean the room for the next guest.

- **Run a Hotel - Design**: progress, tasks, your likes and dislikes, changelog
- **Run a Hotel - Architecture**: scripts, folders and how things fit together
- Media: `Run a Hotel media/`
- Tools: `Run a Hotel tools/`
- Your taste for every game: **My Preferences**

**Studio place:** "Run a Hotel" (rename it to Overbooked on the Creator Hub), placeId 75953879612667 (its own place).


## What is in this repo

| Path | What it is |
|---|---|
| `Overbooked/notes/Run a Hotel - Design.md` | Progress, tasks, every round's changes, the owner's likes and dislikes, changelog (copied in full below) |
| `Overbooked/notes/Run a Hotel - Architecture.md` | Scripts, contracts, remotes, attributes, pipelines and gotchas (copied in full below) |
| `Overbooked/notes/docs/` | Round 9 and Round 10 plans |
| `Overbooked/notes/preferences/` | The owner's taste for every game (animation, SFX, UI, VFX, visuals, gameplay, working style) |
| `Overbooked/tools/src15/` | Current mirrors of the game scripts, named `Service.Path.Name.Class.lua` |
| `Overbooked/tools/live15/`, `live/` | Scripts pulled straight from the live Studio place |
| `Overbooked/tools/src/` | Older (round 1-9) script sources |
| `Overbooked/tools/*.py` | Blender and Python builders (props, faces, UI icons, loading scene, push/relay helpers) |
| `Overbooked/tools/ui/` | UI icon renders |
| `Overbooked/media/` | Screenshots and renders from every round |

Not included: `export/` (156 MB of built meshes/textures, rebuilt by the tools) and `archive/`.

## Script index

| File | Lines | First comment |
|---|---|---|
| `src15/_bub_v2.lua` | 154 | @@HELPERS |
| `src15/_build23.lua` | 527 | key hints (top centre) |
| `src15/_dock21.lua` | 115 | round 21 (2026-11-12): the bottom bar is one strip of dark glass. BUILD is the blue key on the left (green and |
| `src15/_dock_block.lua` | 133 | the bottom dock: build + the menu buttons |
| `src15/_hud21.lua` | 288 | round 21 (2026-11-12): the top of the HUD, rebuilt as dark glass. Left: the hotel plate (level tile, name, stars, |
| `src15/_hud_block.lua` | 336 |  |
| `src15/_hud_fly_v2.lua` | 12 |  |
| `src15/_hud_top_v2.lua` | 195 | round 15 v2 (2026-11-09): the HUD is glossy white pills on deep shadows, each led by a round shaded badge. |
| `src15/_lug_block.lua` | 95 | luggage (round 15) |
| `src15/_mapbuilder16.lua` | 361 | @@BUILDING |
| `src15/_menus24.lua` | 1037 | hotel page |
| `src15/_patch20.lua` | 109 | @@CUT_INTRO |
| `src15/_prompt_block.lua` | 277 | custom prompts (round 15 v2) |
| `src15/_prompt_top_v2.lua` | 158 | custom prompts (round 15 v2) |
| `src15/_ui21_parts.lua` | 620 | @@TOKENS |
| `src15/_UI_old.lua` | 1045 | ReplicatedStorage.Shared.UI: the shared look and motion of every screen (round 9). |
| `src15/_ui_parts.lua` | 750 | @@HEAD |
| `src15/_UI_r15v2_backup.lua` | 1332 | ReplicatedStorage.Shared.UI (round 15 v2, 2026-11-09): the shared look and motion of every screen. |
| `src15/ReplicatedFirst.Loading.LocalScript.lua` | 162 | ReplicatedFirst.Loading (round 21, 2026-11-12): the loading screen, remade plain and calm. |
| `src15/ReplicatedStorage.Shared.Build.ModuleScript.lua` | 497 | ReplicatedStorage.Shared.Build: placement rules shared by the client (live ghost tint) and the server (the real check). |
| `src15/ReplicatedStorage.Shared.BuildKit.ModuleScript.lua` | 1762 | ReplicatedStorage.Shared.BuildKit: build mode's shop, tool rail, selection, groups and placement panel (round 42). |
| `src15/ReplicatedStorage.Shared.Faces.ModuleScript.lua` | 214 | ReplicatedStorage.Shared.Faces (round 16, 2026-11-10): faces that move, now with real variety. |
| `src15/ReplicatedStorage.Shared.NPCAnimLib.ModuleScript.lua` | 1192 | Shared.NPCAnimLib (round 14): hand-keyed procedural animation for every hotel NPC (guests and staff). |
| `src15/ReplicatedStorage.Shared.RoomPlan.ModuleScript.lua` | 390 | ReplicatedStorage.Shared.RoomPlan (round 15): lays a room kit out inside a walled rectangle. |
| `src15/ReplicatedStorage.Shared.Speech.ModuleScript.lua` | 243 | ReplicatedStorage.Shared.Speech (round 15, 2026-11-09): people really talk. |
| `src15/ReplicatedStorage.Shared.UI.ModuleScript.lua` | 1279 | ReplicatedStorage.Shared.UI (round 21, 2026-11-12): the shared look and motion of every screen. |
| `src15/ReplicatedStorage.Shared.Upgrades.ModuleScript.lua` | 118 | ReplicatedStorage.Shared.Upgrades (round 20, 2026-11-11): simple hotel upgrades bought with cash in the menu's |
| `src15/ReplicatedStorage.Shared.VoiceFX.ModuleScript.lua` | 167 | ReplicatedStorage.Shared.VoiceFX (round 16, 2026-11-10): the beeps and boops people talk in. |
| `src15/ServerScriptService.HotelSkin.Script.lua` | 14 | ServerScriptService.HotelSkin (round 16c): keeps every hotel in its resort colours (see ServerStorage.HotelSkin). |
| `src15/ServerScriptService.Upgrades.Script.lua` | 65 | ServerScriptService.Upgrades (round 20): buys hotel upgrades (Shared.Upgrades) for the Upgrades tab. |
| `src15/ServerStorage.Conversations.ModuleScript.lua` | 701 | ServerStorage.Conversations (round 15, 2026-11-09): real conversations with guests and staff. |
| `src15/ServerStorage.DevTools.Tmp_GEStars.ModuleScript.lua` | 245 |  |
| `src15/ServerStorage.HotelSim.ModuleScript.lua` | 5203 | ServerStorage.HotelSim: runs one hotel. Rooms, guests, cleaning, cash, doors, staff, upgrades. |
| `src15/ServerStorage.HotelSkin.ModuleScript.lua` | 325 | ServerStorage.HotelSkin (round 20, 2026-11-11): how a hotel looks for its look stage (Shared.Upgrades.look): |
| `src15/ServerStorage.Kitchen.ModuleScript.lua` | 501 | ServerStorage.Kitchen (round 10c): meals. The kitchen opens at hotel level 3 once the hotel has a Stove |
| `src15/ServerStorage.Upkeep.ModuleScript.lua` | 922 | ServerStorage.Upkeep (round 11): things that go wrong, and the little jobs round the hotel. |
| `src15/StarterPlayer.StarterPlayerScripts.Bubbles.LocalScript.lua` | 486 | StarterPlayerScripts.Bubbles (round 15 v2, 2026-11-09): what floats over people's heads (glossy style). |
| `src15/StarterPlayer.StarterPlayerScripts.BuildClient.LocalScript.lua` | 2941 | StarterPlayerScripts.BuildClient: build mode (round 9 rewrite on Shared.UI). B (or the BUILD button) toggles it. |
| `src15/StarterPlayer.StarterPlayerScripts.Client.LocalScript.lua` | 1549 | StarterPlayerScripts.Client: the HUD (round 15 remake), custom prompt buttons, money popups and toasts. |
| `src15/StarterPlayer.StarterPlayerScripts.CommandsUI.LocalScript.lua` | 91 | StarterPlayerScripts.CommandsUI (round 21): /commands opens a full page that lists every chat command, in groups. |
| `src15/StarterPlayer.StarterPlayerScripts.Cutscene.LocalScript.lua` | 490 | StarterPlayerScripts.Cutscene (round 15, 2026-11-10): short camera cutscenes. |
| `src15/StarterPlayer.StarterPlayerScripts.MainMenu.LocalScript.lua` | 442 | StarterPlayerScripts.MainMenu (round 21, 2026-11-12): the title screen, remade from scratch. |
| `src15/StarterPlayer.StarterPlayerScripts.NPCAnim.LocalScript.lua` | 837 | NPCAnim (round 14, client; round 15: luggage that rolls and swings, faces that change and talk): plays Shared.NPCAnimLib's hand-keyed motion |
| `src15/StarterPlayer.StarterPlayerScripts.ResearchUI.LocalScript.lua` | 743 | StarterPlayerScripts.ResearchUI (round 26 layout): the Research page of the menu, built into Coop's Page_research. |
| `src15/StarterPlayer.StarterPlayerScripts.Talk.LocalScript.lua` | 844 | StarterPlayerScripts.Talk (round 15, 2026-11-09): face-to-face conversations, in first person. |
| `src15/StarterPlayer.StarterPlayerScripts.ToolAim.LocalScript.lua` | 61 | StarterPlayerScripts.ToolAim (round 21): keeps a janitor's mop or broom the right way up. |
| `src15/StarterPlayer.StarterPlayerScripts.UpgradesUI.LocalScript.lua` | 274 | StarterPlayerScripts.UpgradesUI (round 25): the menu's Upgrades page, built into Coop's Page_upgrades. |
| `live15/ReplicatedFirst.Loading.LocalScript.lua` | 521 | ReplicatedFirst.Loading (round 12 remake): the loading screen. Self-contained (it runs before |
| `live15/ReplicatedStorage.Shared.Build.ModuleScript.lua` | 495 | ReplicatedStorage.Shared.Build: placement rules shared by the client (live ghost tint) and the server (the real check). |
| `live15/ReplicatedStorage.Shared.Catalog.ModuleScript.lua` | 304 | ReplicatedStorage.Shared.Catalog: everything you can place in build mode. |
| `live15/ReplicatedStorage.Shared.Clock.ModuleScript.lua` | 104 | ReplicatedStorage.Shared.Clock: the game clock, shared by server and clients (round 9). |
| `live15/ReplicatedStorage.Shared.Config.ModuleScript.lua` | 393 | ReplicatedStorage.Shared.Config: shared numbers, art ids and the guest wardrobe. |
| `live15/ReplicatedStorage.Shared.Grades.ModuleScript.lua` | 65 | ReplicatedStorage.Shared.Grades (round 11): the hotel's grade, 1 (Roadside Inn) to 5 (Palace Hotel). |
| `live15/ReplicatedStorage.Shared.Hiring.ModuleScript.lua` | 125 | ReplicatedStorage.Shared.Hiring (round 14, 2026-11-09): staff candidates, skill and personality traits. |
| `live15/ReplicatedStorage.Shared.Levels.ModuleScript.lua` | 192 | ReplicatedStorage.Shared.Levels: the hotel level (round 10). |
| `live15/ReplicatedStorage.Shared.Looks.ModuleScript.lua` | 169 | ReplicatedStorage.Shared.Looks: what NPCs look like and how they walk (round 9). |
| `live15/ReplicatedStorage.Shared.NPCAnimLib.ModuleScript.lua` | 943 | Shared.NPCAnimLib (round 14): hand-keyed procedural animation for every hotel NPC (guests and staff). |
| `live15/ReplicatedStorage.Shared.NPCGait.ModuleScript.lua` | 264 | Shared.NPCGait (round 14e, 2026-11-09): a hand-keyed procedural walk and idle for every R15 hotel NPC, |
| `live15/ReplicatedStorage.Shared.Quests.ModuleScript.lua` | 167 | ReplicatedStorage.Shared.Quests (round 10c): the goals, in chapters. Shared by the server (QuestServer |
| `live15/ReplicatedStorage.Shared.Research.ModuleScript.lua` | 195 | ReplicatedStorage.Shared.Research: the research tree (round 9). |
| `live15/ReplicatedStorage.Shared.StaffLook.ModuleScript.lua` | 589 | ReplicatedStorage.Shared.StaffLook (round 13): what each staff member looks like, shared by the server (the real |
| `live15/ReplicatedStorage.Shared.Street.ModuleScript.lua` | 39 | ReplicatedStorage.Shared.Street: the map's layout, shared by the map builder, crowds, traffic and plots (round 9). |
| `live15/ReplicatedStorage.Shared.UI.ModuleScript.lua` | 1082 | ReplicatedStorage.Shared.UI (round 15, 2026-11-09): the shared look and motion of every screen. |
| `live15/ReplicatedStorage.Shared.VoiceFX.ModuleScript.lua` | 137 | ReplicatedStorage.Shared.VoiceFX: the sound of people talking (guests, staff and players' chat). |
| `live15/ServerScriptService.BuildServer.Script.lua` | 419 | ServerScriptService.BuildServer: buying, moving and selling furniture (build mode). |
| `live15/ServerScriptService.ChatCommands.Script.lua` | 358 | ServerScriptService.ChatCommands: chat commands, handled on the server via TextChatCommands. |
| `live15/ServerScriptService.Crowds.Script.lua` | 668 | ServerScriptService.Crowds: the people on the street (round 9 rewrite). |
| `live15/ServerScriptService.DayNight.Script.lua` | 35 | ServerScriptService.DayNight: the game's clock (round 9 rewrite). |
| `live15/ServerScriptService.LevelCommands.Script.lua` | 36 | ServerScriptService.LevelCommands: testing commands anyone can use. |
| `live15/ServerScriptService.Plots.Script.lua` | 431 | ServerScriptService.Plots: every player gets their own hotel plot, and friends can co-op. |
| `live15/ServerScriptService.QuestServer.Script.lua` | 176 | ServerScriptService.QuestServer (round 10c): tracks every hotel's chapter goals (defs in Shared.Quests). |
| `live15/ServerScriptService.ResearchServer.Script.lua` | 131 | ServerScriptService.ResearchServer: the research tree (Shared.Research) for each hotel. |
| `live15/ServerScriptService.Save.Script.lua` | 574 | ServerScriptService.Save: keeps each player's money and the owner's hotel between visits. |
| `live15/ServerScriptService.Tutorial.Script.lua` | 68 | ServerScriptService.Tutorial (round 12 remake): the guided first day now runs on the client |
| `live15/ServerScriptService.Weather.Script.lua` | 79 | ServerScriptService.Weather (round 10c): the city's weather. |
| `live15/ServerStorage.Bodies.ModuleScript.lua` | 310 | ServerStorage.Bodies: the shared NPC body builder (guests, staff, street crowds). |
| `live15/ServerStorage.GuestEvents.ModuleScript.lua` | 673 | ServerStorage.GuestEvents: special guests (round 9). HotelSim asks roll() when a guest arrives; |
| `live15/ServerStorage.GuestLife.ModuleScript.lua` | 1472 | ServerStorage.GuestLife (round 10c): the little things guests do between the big ones, so no two stays |
| `live15/ServerStorage.HotelBuilder.ModuleScript.lua` | 2923 | Run a Hotel edit-time builder: the hotel shell, lobby, three rooms and their nav spots. |
| `live15/ServerStorage.HotelSim.ModuleScript.lua` | 4829 | ServerStorage.HotelSim: runs one hotel. Rooms, guests, cleaning, cash, doors, staff, upgrades. |
| `live15/ServerStorage.Kitchen.ModuleScript.lua` | 498 | ServerStorage.Kitchen (round 10c): meals. The kitchen opens at hotel level 3 once the hotel has a Stove |
| `live15/ServerStorage.MapBuilder.ModuleScript.lua` | 794 | ServerStorage.MapBuilder: builds the whole city in Edit (round 9). Run from execute_luau: |
| `live15/ServerStorage.Nav.ModuleScript.lua` | 390 | ServerStorage.Nav: the walk grid for one hotel plot (round 10). It replaces PathfindingService for |
| `live15/ServerStorage.Rooms.ModuleScript.lua` | 292 | ServerStorage.Rooms (round 10d): guest rooms the player makes with Wall and Door items. |
| `live15/ServerStorage.Upkeep.ModuleScript.lua` | 918 | ServerStorage.Upkeep (round 11): things that go wrong, and the little jobs round the hotel. |
| `live15/ServerStorage.Voice.ModuleScript.lua` | 681 | ServerStorage.Voice (round 18): how people talk. Every guest and staff member gets a voice (a way of speaking) |
| `live15/StarterPlayer.StarterPlayerScripts.Audio.LocalScript.lua` | 462 | StarterPlayerScripts.Audio: every sound in the game, played locally. |
| `live15/StarterPlayer.StarterPlayerScripts.Bubbles.LocalScript.lua` | 282 | StarterPlayerScripts.Bubbles (round 14, 2026-11-09): no more speech or thought bubbles, and no names over heads. |
| `live15/StarterPlayer.StarterPlayerScripts.BuildClient.LocalScript.lua` | 2564 | StarterPlayerScripts.BuildClient: build mode (round 9 rewrite on Shared.UI). B (or the BUILD button) toggles it. |
| `live15/StarterPlayer.StarterPlayerScripts.Client.LocalScript.lua` | 1654 | StarterPlayerScripts.Client: the HUD (round 10c remake), custom prompt buttons, money popups and toasts. |
| `live15/StarterPlayer.StarterPlayerScripts.Coop.LocalScript.lua` | 1842 | StarterPlayerScripts.Coop: the Menu (round 10c remake) and the left dock. |
| `live15/StarterPlayer.StarterPlayerScripts.Doors.LocalScript.lua` | 504 | Run a Hotel: hinged doors (round 10). Every model tagged SwingDoor (the room doors and the build-mode |
| `live15/StarterPlayer.StarterPlayerScripts.FX.LocalScript.lua` | 178 | StarterPlayerScripts.FX (round 14): one place for the game's little moments, played locally from Notify. |
| `live15/StarterPlayer.StarterPlayerScripts.Gamepad.LocalScript.lua` | 70 | StarterPlayerScripts.Gamepad (round 10c): PS5 / Xbox controller glue that doesn't belong to one screen. |
| `live15/StarterPlayer.StarterPlayerScripts.Lighting.LocalScript.lua` | 314 | StarterPlayerScripts.Lighting: the look of the world, every frame (round 9). |
| `live15/StarterPlayer.StarterPlayerScripts.MainMenu.LocalScript.lua` | 700 | StarterPlayerScripts.MainMenu: the title screen (round 12 remake). |
| `live15/StarterPlayer.StarterPlayerScripts.Minigames.LocalScript.lua` | 4139 | StarterPlayerScripts.Minigames: the cleaning minigames (round 10b remake) and the front desk (round 10c). |
| `live15/StarterPlayer.StarterPlayerScripts.NPCAnim.LocalScript.lua` | 471 | NPCAnim (round 14, client): plays Shared.NPCAnimLib's hand-keyed motions on every hotel NPC. |
| `live15/StarterPlayer.StarterPlayerScripts.Perf.LocalScript.lua` | 85 | StarterPlayerScripts.Perf (round 10d): client-side savings nobody should notice. |
| `live15/StarterPlayer.StarterPlayerScripts.Phone.LocalScript.lua` | 897 | StarterPlayerScripts.Phone (round 14 remake): your phone and the store. |
| `live15/StarterPlayer.StarterPlayerScripts.Props.LocalScript.lua` | 59 | StarterPlayerScripts.Props: little local motion for guest event props (GuestEvents), on this screen only. |
| `live15/StarterPlayer.StarterPlayerScripts.ResearchUI.LocalScript.lua` | 921 | StarterPlayerScripts.ResearchUI: the Research Lab (round 10 remake; round 10c: a tab of the Menu). |
| `live15/StarterPlayer.StarterPlayerScripts.Roof.LocalScript.lua` | 57 | StarterPlayerScripts.Roof: shows or hides the roof of the hotel you work in, on this screen only. |
| `live15/StarterPlayer.StarterPlayerScripts.RoomStatus.LocalScript.lua` | 109 | StarterPlayerScripts.RoomStatus (round 19): how a room tells you it needs cleaning. |
| `live15/StarterPlayer.StarterPlayerScripts.StaffEdit.LocalScript.lua` | 517 | StarterPlayerScripts.StaffEdit (round 13): the staff wardrobe and job settings. |
| `live15/StarterPlayer.StarterPlayerScripts.Talk.LocalScript.lua` | 346 | StarterPlayerScripts.Talk (round 10c): talking to guests, and the reviews they leave. |
| `live15/StarterPlayer.StarterPlayerScripts.Traffic.LocalScript.lua` | 273 | StarterPlayerScripts.Traffic: cars and buses driving the avenue (round 9). Runs on each client |
| `live15/StarterPlayer.StarterPlayerScripts.TutorialClient.LocalScript.lua` | 596 | StarterPlayerScripts.TutorialClient (round 12): the guided first day. The server (Tutorial) sends |
| `live15/StarterPlayer.StarterPlayerScripts.WeatherFX.LocalScript.lua` | 242 | StarterPlayerScripts.WeatherFX (round 10c): what the weather looks and sounds like on this client. |
| `live/Build.lua` | 495 | ReplicatedStorage.Shared.Build: placement rules shared by the client (live ghost tint) and the server (the real check). |
| `live/BuildClient.lua` | 3094 | StarterPlayerScripts.BuildClient: build mode (round 9 rewrite on Shared.UI). B (or the BUILD button) toggles it. |
| `live/Coop.lua` | 1847 | StarterPlayerScripts.Coop: the Menu (round 10c remake) and the left dock. |
| `live/MeshImporter.lua` | 85 | Run a Hotel edit-time tool: rah_props.py JSON (served on :8790) -> EditableMesh -> uploaded MeshPart. |
| `live/NPCAnim.lua` | 662 | NPCAnim (round 14, client; round 15: luggage that rolls and swings, faces that change and talk): plays Shared.NPCAnimLib's hand-keyed motion |
| `live/NPCAnimLib.lua` | 943 | Shared.NPCAnimLib (round 14): hand-keyed procedural animation for every hotel NPC (guests and staff). |
| `live/RAH_Audio.lua` | 245 | StarterPlayerScripts.RAH_Audio: every sound in the game, played locally. |
| `live/RAH_Bodies.lua` | 57 | ServerStorage.RAH_Bodies: the shared NPC body builder (guests, staff, street crowds). |
| `live/RAH_Build.lua` | 192 | ReplicatedStorage.RAH.Build: placement rules shared by the client (live ghost tint) and the server (the real check). |
| `live/RAH_BuildClient.lua` | 1528 | StarterPlayerScripts.RAH_BuildClient: build mode. B (or the hammer button) toggles it. |
| `live/RAH_BuildServer.lua` | 215 | ServerScriptService.RAH_BuildServer: buying, moving and selling furniture (build mode). |
| `live/RAH_Catalog.lua` | 90 | ReplicatedStorage.RAH.Catalog: everything you can place in build mode. |
| `live/RAH_Client.lua` | 659 | StarterPlayerScripts.RAH_Client: HUD, custom prompt buttons, money popups and toasts. |
| `live/RAH_Config.lua` | 164 | ReplicatedStorage.RAH.Config: shared numbers, art ids and the guest wardrobe. |
| `live/RAH_Coop.lua` | 939 | StarterPlayerScripts.RAH_Coop: the Menu button (top right, or press M) opens a tabbed menu -- Stats, |
| `live/RAH_Crowds.lua` | 278 | ServerScriptService.RAH_Crowds: map-wide street life, purely ambient. |
| `live/RAH_DayNight.lua` | 149 | ServerScriptService.RAH_DayNight: the game's clock. One full day/night cycle |
| `live/RAH_HotelBuilder.lua` | 895 | Run a Hotel edit-time builder: the hotel shell, lobby, three rooms and their nav spots. |
| `live/RAH_HotelSim.lua` | 2178 | ServerStorage.RAH_HotelSim: runs one hotel. Rooms, guests, cleaning, cash, doors, staff, upgrades. |
| `live/RAH_MainMenu.lua` | 432 | StarterPlayerScripts.RAH_MainMenu: the title screen. Home has Play / Tips / Settings; |
| `live/RAH_Minigames.lua` | 407 | StarterPlayerScripts.RAH_Minigames: client-side cleaning minigames. |
| `live/RAH_Plots.lua` | 388 | ServerScriptService.RAH_Plots: every player gets their own hotel plot, and friends can co-op. |
| `live/RAH_Save.lua` | 374 | ServerScriptService.RAH_Save: keeps each player's money and the owner's hotel between visits. |
| `live/RAH_Tutorial.lua` | 114 | ServerScriptService.RAH_Tutorial: walks brand-new players through their first |
| `live/ResearchUI.lua` | 921 | StarterPlayerScripts.ResearchUI: the Research Lab (round 10 remake; round 10c: a tab of the Menu). |
| `live/Roof.lua` | 57 | StarterPlayerScripts.Roof: shows or hides the roof of the hotel you work in, on this screen only. |
| `src/_push.lua` | 54 | Dev helper (not part of the game). In execute_luau (Edit): |
| `src/HotelBuilder.lua` | 2905 | Run a Hotel edit-time builder: the hotel shell, lobby, three rooms and their nav spots. |
| `src/MeshImporter.lua` | 98 | Run a Hotel edit-time tool: rah_props.py JSON (served on :8790) -> EditableMesh -> uploaded MeshPart. |
| `src/NPCGait.lua` | 264 | Shared.NPCGait (round 14e, 2026-11-09): a hand-keyed procedural walk and idle for every R15 hotel NPC, |
| `src/RAH_Audio.lua` | 341 | StarterPlayerScripts.RAH_Audio: every sound in the game, played locally. |
| `src/RAH_Bodies.lua` | 154 | ServerStorage.RAH_Bodies: the shared NPC body builder (guests, staff, street crowds). |
| `src/RAH_Bubbles.lua` | 301 | StarterPlayerScripts.RAH_Bubbles (round 10c): the status bubbles over guests' and staff's heads. |
| `src/RAH_Build.lua` | 426 | ReplicatedStorage.RAH.Build: placement rules shared by the client (live ghost tint) and the server (the real check). |
| `src/RAH_BuildClient.lua` | 2445 | StarterPlayerScripts.RAH_BuildClient: build mode (round 9 rewrite on RAH.UI). B (or the BUILD button) toggles it. |
| `src/RAH_BuildServer.lua` | 369 | ServerScriptService.RAH_BuildServer: buying, moving and selling furniture (build mode). |
| `src/RAH_Catalog.lua` | 306 | ReplicatedStorage.RAH.Catalog: everything you can place in build mode. |
| `src/RAH_Client.lua` | 1481 | StarterPlayerScripts.RAH_Client: the HUD (round 10c remake), custom prompt buttons, money popups and toasts. |
| `src/RAH_Clock.lua` | 53 | ReplicatedStorage.RAH.Clock: the game clock, shared by server and clients (round 9). |
| `src/RAH_Config.lua` | 310 | ReplicatedStorage.RAH.Config: shared numbers, art ids and the guest wardrobe. |
| `src/RAH_Coop.lua` | 1728 | StarterPlayerScripts.RAH_Coop: the Menu (round 10c remake) and the left dock. |
| `src/RAH_Crowds.lua` | 581 | ServerScriptService.RAH_Crowds: the people on the street (round 9 rewrite). |
| `src/RAH_DayNight.lua` | 35 | ServerScriptService.RAH_DayNight: the game's clock (round 9 rewrite). |
| `src/RAH_Doors.lua` | 455 | Run a Hotel: hinged doors (round 10). Every model tagged RAH_SwingDoor (the room doors and the build-mode |
| `src/RAH_Gamepad.lua` | 70 | StarterPlayerScripts.RAH_Gamepad (round 10c): PS5 / Xbox controller glue that doesn't belong to one screen. |
| `src/RAH_Grades.lua` | 75 | ReplicatedStorage.RAH.Grades (round 11): the hotel's grade, 1 (Roadside Inn) to 5 (Palace Hotel). |
| `src/RAH_GuestEvents.lua` | 673 | ServerStorage.RAH_GuestEvents: special guests (round 9). RAH_HotelSim asks roll() when a guest arrives; |
| `src/RAH_GuestLife.lua` | 1454 | ServerStorage.RAH_GuestLife (round 10c): the little things guests do between the big ones, so no two stays |
| `src/RAH_HotelSim.lua` | 4641 | ServerStorage.RAH_HotelSim: runs one hotel. Rooms, guests, cleaning, cash, doors, staff, upgrades. |
| `src/RAH_Kitchen.lua` | 498 | ServerStorage.RAH_Kitchen (round 10c): meals. The kitchen opens at hotel level 3 once the hotel has a Stove |
| `src/RAH_Levels.lua` | 187 | ReplicatedStorage.RAH.Levels: the hotel level (round 10). |
| `src/RAH_Lighting.lua` | 269 | StarterPlayerScripts.RAH_Lighting: the look of the world, every frame (round 9). |
| `src/RAH_Loading.lua` | 408 | ReplicatedFirst.RAH_Loading (round 12 remake): the loading screen. Self-contained (it runs before |
| `src/RAH_Looks.lua` | 114 | ReplicatedStorage.RAH.Looks: what NPCs look like and how they walk (round 9). |
| `src/RAH_MainMenu.lua` | 679 | StarterPlayerScripts.RAH_MainMenu: the title screen (round 12 remake). |
| `src/RAH_MapBuilder.lua` | 794 | ServerStorage.RAH_MapBuilder: builds the whole city in Edit (round 9). Run from execute_luau: |
| `src/RAH_Minigames.lua` | 4066 | StarterPlayerScripts.RAH_Minigames: the cleaning minigames (round 10b remake) and the front desk (round 10c). |
| `src/RAH_Nav.lua` | 390 | ServerStorage.RAH_Nav: the walk grid for one hotel plot (round 10). It replaces PathfindingService for |
| `src/RAH_NPCAnim.lua` | 384 | RAH_NPCAnim (round 14, client): plays RAH.NPCAnimLib's hand-keyed motions on every hotel NPC. |
| `src/RAH_NPCAnimLib.lua` | 775 | RAH.NPCAnimLib (round 14): hand-keyed procedural animation for every hotel NPC (guests and staff). |
| `src/RAH_Perf.lua` | 85 | StarterPlayerScripts.RAH_Perf (round 10d): client-side savings nobody should notice. |
| `src/RAH_Phone.lua` | 894 | StarterPlayerScripts.RAH_Phone (round 14 remake): your phone and the store. |
| `src/RAH_Plots.lua` | 431 | ServerScriptService.RAH_Plots: every player gets their own hotel plot, and friends can co-op. |
| `src/RAH_Props.lua` | 59 | StarterPlayerScripts.RAH_Props: little local motion for guest event props (RAH_GuestEvents), on this screen only. |
| `src/RAH_Quests.lua` | 167 | ReplicatedStorage.RAH.Quests (round 10c): the goals, in chapters. Shared by the server (RAH_QuestServer |
| `src/RAH_QuestServer.lua` | 176 | ServerScriptService.RAH_QuestServer (round 10c): tracks every hotel's chapter goals (defs in RAH.Quests). |
| `src/RAH_Research.lua` | 195 | ReplicatedStorage.RAH.Research: the research tree (round 9). |
| `src/RAH_ResearchServer.lua` | 131 | ServerScriptService.RAH_ResearchServer: the research tree (RAH.Research) for each hotel. |
| `src/RAH_ResearchUI.lua` | 921 | StarterPlayerScripts.RAH_ResearchUI: the Research Lab (round 10 remake; round 10c: a tab of the Menu). |
| `src/RAH_Roof.lua` | 57 | StarterPlayerScripts.RAH_Roof: shows or hides the roof of the hotel you work in, on this screen only. |
| `src/RAH_Rooms.lua` | 292 | ServerStorage.RAH_Rooms (round 10d): guest rooms the player makes with Wall and Door items. |
| `src/RAH_RoomStatus.lua` | 121 | StarterPlayerScripts.RAH_RoomStatus (round 10b): how a room tells you it needs cleaning. |
| `src/RAH_Save.lua` | 543 | ServerScriptService.RAH_Save: keeps each player's money and the owner's hotel between visits. |
| `src/RAH_StaffEdit.lua` | 517 | StarterPlayerScripts.RAH_StaffEdit (round 13): the staff wardrobe and job settings. |
| `src/RAH_StaffLook.lua` | 589 | ReplicatedStorage.RAH.StaffLook (round 13): what each staff member looks like, shared by the server (the real |
| `src/RAH_Street.lua` | 39 | ReplicatedStorage.RAH.Street: the map's layout, shared by the map builder, crowds, traffic and plots (round 9). |
| `src/RAH_Talk.lua` | 345 | StarterPlayerScripts.RAH_Talk (round 10c): talking to guests, and the reviews they leave. |
| `src/RAH_Traffic.lua` | 273 | StarterPlayerScripts.RAH_Traffic: cars and buses driving the avenue (round 9). Runs on each client |
| `src/RAH_Tutorial.lua` | 68 | ServerScriptService.RAH_Tutorial (round 12 remake): the guided first day now runs on the client |
| `src/RAH_TutorialClient.lua` | 550 | StarterPlayerScripts.RAH_TutorialClient (round 12): the guided first day. The server (RAH_Tutorial) sends |
| `src/RAH_UI.lua` | 974 | ReplicatedStorage.RAH.UI: the shared look and motion of every screen (round 9). |
| `src/RAH_Upkeep.lua` | 918 | ServerStorage.RAH_Upkeep (round 11): things that go wrong, and the little jobs round the hotel. |
| `src/RAH_Weather.lua` | 76 | ServerScriptService.RAH_Weather (round 10c): the city's weather. |
| `src/RAH_WeatherFX.lua` | 192 | StarterPlayerScripts.RAH_WeatherFX (round 10c): what the weather looks and sounds like on this client. |

---

## Overbooked - Design

> [!info] The game is now called **Overbooked** (2026-11-03). It used to be "Run a Hotel". The notes and folders keep their old names so links keep working.

Back to **Run a Hotel**

### What it is
You own a hotel. Guests turn up at the front door, you let them in, they check in with Ben at reception, go to their room, use the toilet, shower and bed, then check out and pay. After they leave, the room is a mess and you have to clean it before the next guest can use it.

Inspired by your reference screenshots (a bright, cartoony hotel with lavender walls, wood floors, a red carpet, a glass front, round "Clean" buttons and a cash pile you collect).

### Round 15: everything remade for quality, star guests and cutscenes (2026-11-10)

**The whole UI, again**
- A new UI kit from scratch, then the HUD, menus, prompts and dock rebuilt on it.
- The chat bubbles are back above guests' and staff's heads, like the old ones you liked.

**Talking to people**
- Talks are first person: you look at the person, and they act out what they say.
- Faces change with their mood.
- Lots of choices, so you can have a real back-and-forth with guests and staff.
- Pressing X now really lets them go: they stop staring at you as you walk off.

**Title screen, loading and getting in**
- A new main menu and a 3D loading screen.
- A smoother trip from the menu into your hotel.

**Build mode and the room tool**
- Build mode remade, plus a room tool for making a room in one go.

![2026-11-10 room builder furnished.jpg](Overbooked/media/2026-11-10%20room%20builder%20furnished.jpg)

**Bigger plots, a new hotel and a new city**
- Each plot is a lot longer and wider (not huge).
- The starter hotel and the map were rebuilt, and the garden pool sits at the right height now.

**Guests**
- 8 kinds of luggage, each modelled: spinner case, carry-on, vintage trunk, weekender, briefcase, handbag, backpack (worn on the back with straps) and guitar case. Who carries what fits who they are: business people bring briefcases, tourists backpacks, rock stars guitar cases.
- Outfits: about half the crowd now wears something over their shirt. That can be a jacket, puffer, cardigan, vest, blazer, scarf or tie, in lots of colours.
- **Fixed the wide, flat faces.** Roblox's body scaling was stretching the head on bigger body types. Every face is the normal shape now.

![2026-11-10 guest jacket.jpg](Overbooked/media/2026-11-10%20guest%20jacket.jpg)
![2026-11-10 guest backpack.jpg](Overbooked/media/2026-11-10%20guest%20backpack.jpg)

**Star guests and cutscenes**
- 5 famous guests can turn up once your hotel is grade 2 or level 6, each with their own look and lines:
  - Jett Vega, the rock star
  - Duchess Wilhelmina
  - Margaux Fontaine, the critic
  - the Mystery Guest
  - Sir Reginald Goldworth, the tycoon
- They're rare: about 1 arrival in 14, and never two within 5 minutes.
- Keep them happy and they leave a gift ($600 to $2,500).
- When one arrives, a short cutscene plays:
  - Black bars slide in and the HUD steps aside.
  - The camera opens wide on them, then walks with them while their name card comes in.
  - It ends close on their face with their first line.
  - Skip it with any key, a click or a tap.
- Growing your hotel to a new grade plays a slow orbit shot of the building.

![2026-11-10 star guest cutscene critic.jpg](Overbooked/media/2026-11-10%20star%20guest%20cutscene%20critic.jpg)
![2026-11-10 star guest cutscene tycoon.jpg](Overbooked/media/2026-11-10%20star%20guest%20cutscene%20tycoon.jpg)

**Staff**
- Modelled mop, push broom, wrench and clipboard, replacing the block versions.

**Minigames, research and sound**
- Every minigame has a star clock: three stars that drop one by one as you go past the target time, a timer, and a bar that drains toward the next drop.
- Research trees spread out to fill the page instead of bunching in the middle.
- Sound mix: a compressor on the sound effects so loud ones don't spike, music EQ'd to sit under voices, and payouts that ring and sparkle together.

![2026-11-10 minigame star clock.jpg](Overbooked/media/2026-11-10%20minigame%20star%20clock.jpg)
![2026-11-10 research lab.jpg](Overbooked/media/2026-11-10%20research%20lab.jpg)

### Round 14: a new look, real hiring, voices, weather and sound (2026-11-09)

**A whole new style**
- Everything moved to a warm "hotel stationery" look: cream paper cards, dark walnut outlines, gold trim, chunky rounded fonts. No more dark glassy panels.
- Title screen: wallpaper and a wood wainscot panel, a big outlined OVERBOOKED, and a brass plaque that swings in (instead of the neon sign). Menu rows lift when you hover them.
- Loading screen: a brick hotel at dusk with walkers (suitcases, hats) and cars going by, a brass plaque, a chunky progress bar and a tip card.
- The goal cards and tutorial card use the new paper style too.

![2026-11-09 tutorial card.jpg](Overbooked/media/2026-11-09%20tutorial%20card.jpg)

**Hiring**
- The Staff page now shows **3 candidates per role**, each with a name, a voice, a 1 to 5 star skill, one pro and one con, and their own wage and hire price.
- Pros: Quick Feet, Hard Worker, Tireless, Fast Learner, Modest (cheaper), Ray of Sunshine. Cons: Slowpoke, Butterfingers, Sleepyhead, Stubborn, Pricey, Chatterbox.
- These really change how they work (walk speed, job speed, energy, XP, wage) and stay with that person for good (saved).
- New faces turn up every 10 minutes, or pay $150 to see new ones now.
- The staff room no longer needs research: Staff Lockers, Break Table and Water Cooler are all there from level 1.

**Talking**
- 6 new ways of speaking (country, foodie, nerd, dreamer, sporty, tourist) on top of the old ones, and a lot more lines for guests and staff.
- Each personality has habits: the country folk drop their g's, the sporty ones say "Let's go!", the dreamers trail off...

**Minigames**
- The hand is a proper arm now: sleeve, rolled cuff, elbow, yellow rubber glove with fingers. It no longer balloons at the screen edges.
- Grime looks more solid, with dark mildew specks.
- Check-in shows the actual guest you're checking in.

**Tutorial**
- "Build a staff room" now checks the whole room (walls round it, lockers, a table and a drink) and tells you what's still missing.
- New step: **Hire your first staff member** (opens the Staff page for you).

**Sound**
- Doors: the handle turns, then a creak (7 different creaks) or a soft swish, and a latch when it shuts.
- Sounds with several versions now pick one at random (never the same twice) and vary in volume a little.
- More music: 5 new daytime tracks and 5 new night ones.
- Rain patters on the umbrellas near you.

**Weather**
- Rain has depth now: a second, closer layer of streaks.
- Wind gusts swing the rain and snow about (storms gust hard).
- Low mist drifts along the street in fog and rain.
- Umbrellas swing up and pop open, lean into the walk, drip off the rim, and fold away when the rain stops. They have ribs, a tip and a hooked handle now.

![2026-11-09 rain and bursts.jpg](Overbooked/media/2026-11-09%20rain%20and%20bursts.jpg)

**Effects**
- Getting paid: a gold coin pop and a ring. Cleaning: sparkles and soap bubbles. Placing furniture: a dust puff and a ring. Selling: dust and coins. Upgrades, new rooms and hires: confetti.

**Speed**
- About 3,400 tiny parts no longer cast shadows (they were too small to see anyway), and 316 decorations use simple collision.
- Rain, mist and effects scale down on lower graphics settings.

**/preset**
- Builds a real walled staff room in a corner of the lobby (two built walls and a door, lockers, table, water cooler, coffee bar).
- Hires the full team as 5-star staff with their own names, voices, pros and cons, and tops your cash up to $250,000.

**Part 2 (same day)**
- Three lobby pieces remade by hand:
  - **Palm**: a terracotta pot with pebbles, a ringed trunk and arching fronds of leaves, one of them old and dry.
  - **Coffee table**: round walnut, splayed legs with brass feet, a woven cane shelf, books and a bowl on top.
  - **Floor lamp**: a brass dome base, a slim stem with a switch, and a pleated linen shade.
- Street walkers hold their umbrella in their hand now (it used to float over their head), and they animate when you're near.
- The phone is readable again: light text on its dark screen.
- Research cards: darker, easier-to-read text.

- Four more remade:
  - **Armchair**: rust velvet with rolled arms, a curved button-back, a striped cushion, and walnut legs with brass toes.
  - **Sofa**: the matching three-seater in teal, with plump cushions, two throw pillows and a knit blanket over the arm.
  - **Wardrobe**: a walnut armoire with panelled doors, a drawer, a stepped top and brass knobs.
  - **Bookshelf**: walnut, with banded book spines, leaning books, stacks, a trailing plant, a vase and a photo.

- The room upgrades now look worth buying over the plain starter set:
  - **Deluxe Bed**: a walnut platform with a sage channel-tufted headboard, a crisp white duvet, a charcoal runner and sage shams.
  - **Suite Bed**: a navy velvet wingback with diamond tufting and brass studs, a cream duvet, a navy runner and gold shams.
  - Both have a proper messy version: the duvet shoved down, pillows knocked about, the runner sliding off the end.
  - **Deluxe Toilet**: a sleek one-piece with a soft lid, chrome flush button and a little succulent.
  - **Rain Shower**: a walk-in with white subway tiles, a sage stripe, a slate floor, a teak mat, a big square rain head, black fittings, a glass side and a towel.
  - **Vanity**: walnut drawers, a marble top, a bowl basin, a tall brass tap and a round brass mirror.

![2026-11-09 new lobby furniture.jpg](Overbooked/media/2026-11-09%20new%20lobby%20furniture.jpg)
![2026-11-09 new sofa and armchair.jpg](Overbooked/media/2026-11-09%20new%20sofa%20and%20armchair.jpg)
![2026-11-09 new beds and bathroom.jpg](Overbooked/media/2026-11-09%20new%20beds%20and%20bathroom.jpg)
![2026-11-09 umbrella in hand.jpg](Overbooked/media/2026-11-09%20umbrella%20in%20hand.jpg)

### Round 13: room doors, a staff wardrobe, jobs and a much bigger research tree (2026-11-06)

**Hotel room doors in build mode**
- Three new doors under Structure, first in the list: **Room Door** (walnut, like the starter rooms), **Modern Room Door** (charcoal with a steel bar handle and a warm light strip) and **Suite Door** (cream with gold panels).
- Each has a keycard reader with a green light, a cornice, a kick plate and a peephole. Put one in a ring of walls and it becomes a guest room, with its number plate and status light above.

**Staff take their time now**
- The doorman walks out to the next guest, says hello, takes their bags and shows them in (about 10 seconds a guest, not instant).
- Janitors spend about 6 seconds on each job in a room, receptionists about 6 seconds to check someone in, cooks 16 seconds a dish, handymen 14 seconds a repair.
- Levels, the staff room and research still speed them up.

**Better uniforms**
- Every role has 4 outfits, built from real pieces: greatcoats with gold buttons and epaulettes, tailcoats, blazers with lapels and pocket squares, waistcoats, a tuxedo, double-breasted chef whites, overalls, coveralls, hi-vis vests, a foreman with a clipboard, and more.
- Name badges, belts, shoes, headwear (peaked cap, top hat, toque, hard hat, beanie, headphones, headset, glasses, goggles and more), plus the mop and wrench.
- The 4th outfit for each role (Royal Coat, Tuxedo, Head Chef, Foreman, Housekeeper) unlocks with the new **Tailored Uniforms** research.

**Customise your staff (and they keep it)**
- Menu > Staff > Your team > **Edit** opens a wardrobe with a turning preview: name, outfit, uniform colour (14), buttons and trim, headwear, skin, hair and face.
- Everyone's look is saved with your hotel. New hires get a look that's saved straight away too, so nobody changes face between visits unless you change them.

![2026-11-06 staff wardrobe.jpg](Overbooked/media/2026-11-06%20staff%20wardrobe.jpg)

**Jobs and priorities**
- The same screen has a JOB tab:
  - **Janitors:** pick their rooms, then "My rooms first" or "Only my rooms".
  - **Doormen:** Warm welcome (guests start happier), Quick door (faster), or VIPs first (special guests skip the line).
  - **Receptionists:** check-ins first or check-outs first.
  - **Cooks:** oldest order or big orders first.
  - **Handymen:** rooms first or lobby first.
- **Shifts** for everyone: all day, day shift or night shift. Shift workers rest half the day and cost 40% less.

**Research: 72 projects in 12 branches (was 34 in 7)**
- New branches, each with paths that split and join up, and links into the other branches:
  - **Staff Training** (12): faster janitors, doormen, desk, cooks and handymen, more experience, cheaper wages, Tailored Uniforms, Master Staff.
  - **Guest Experience** (7): happier guests, more patience, bigger tips, up to Luxury Standard.
  - **Marketing** (8): more walk-ins, tips and room prices, up to Famous Brand.
  - **Dining** (6): meals earn more, cooks are faster, diners wait longer.
  - **Maintenance** (6): things break less often and get fixed faster.
- The research tree scrolls now, so the big branches fit.

### Round 12: the desk, a real tutorial, new menus and 26 new items (2026-11-05)

**Working the desk**
- You now sit in the receptionist's chair (F) to check guests in and out. The Check In / Check Out buttons only show while you're seated.
- The check-in minigame sits on the desk monitor, and every minigame fills the whole screen.
- When you hold a tool in a minigame, it's **your own Roblox avatar's arm**, at its real size, reaching in from the edge of the screen.

![2026-11-05 check-in on monitor.jpg](Overbooked/media/2026-11-05%20check-in%20on%20monitor.jpg)
![2026-11-05 avatar arm toilet.jpg](Overbooked/media/2026-11-05%20avatar%20arm%20toilet.jpg)

**Smaller fixes**
- Interaction buttons are smaller (and there's a size setting).
- The toilet's flush button is back on screen. Cleaning games are shorter.
- You can sit on chairs, sofas and benches (F).
- Guests have more things to say, and you get more replies when you talk to them.
- Your Roblox friends can turn up as guests.
- Phone: the left menu and the top bar no longer overlap.
- Build camera: hold the right mouse button and drag to turn. On a phone, twist two fingers to turn and pinch to zoom.

**A new tutorial**
- 10 steps with a coach card at the top, a gold pin and floor ring showing where to go, and an arrow when it's off screen:
  - sit at the desk
  - check a guest in
  - say hello
  - clean a room
  - open build mode
  - look around
  - place something
  - finish building
- Steps you can't do yet (for example, a receptionist already serves the desk) can be skipped. Finishing pays $500 once.
- Replay it any time from the title screen (Tutorial) or Settings.

![2026-11-05 tutorial.jpg](Overbooked/media/2026-11-05%20tutorial.jpg)
![2026-11-05 tutorial build step.jpg](Overbooked/media/2026-11-05%20tutorial%20build%20step.jpg)

**New loading screen and title screen**
- Loading: a hotel at night. Its windows light up as the game loads, the OVERBOOKED sign flickers on, and at the end the doors open and the screen flies through them.
- Title: a slide-in side panel with the logo, a big CONTINUE, Tutorial, Tips, Settings and Credits, and your save card with your avatar.

![2026-11-05 loading screen.jpg](Overbooked/media/2026-11-05%20loading%20screen.jpg)
![2026-11-05 main menu.jpg](Overbooked/media/2026-11-05%20main%20menu.jpg)

**More settings, and they save**
- New settings: field of view, shadows, button size, end-of-day report, money pop-ups, build camera speed and invert, and Replay tutorial.
- Your settings are saved with your profile now.

**26 new things to build**
- **Furniture:** dining chair, tufted bench, beanbag, round table, reading nook, tall bookcase, bar counter
- **Decor:** hedge planter, room divider, tapestry, marble statue, lobby fountain
- **Lighting:** pendant lamp, chandelier, lantern post, neon sign. These glow and light the room.
- **Fun:** gumball machine, mini golf, DJ booth, VR pod
- **Amenities:** key rack, ice machine, phone booth
- **Rooms:** towel shelf, room safe
- **Car park:** park bench, bike rack
- Chairs, benches, the beanbag and the reading nook can be sat on.

![2026-11-05 new build items.png](Overbooked/media/2026-11-05%20new%20build%20items.png)

**Build mode fixes (round 12b)**
- The category tabs scroll sideways now, so every tab is reachable on phones and small screens (Staff and Outdoor were cut off). Swipe them, or tap the arrows on the edges.
- New walls can join the hotel's own walls and the starter rooms' walls, so you can make a room against them. Walls can also cross the hallway, but they still keep a clear way into each room's door.

![2026-11-05 build tabs scroll.jpg](Overbooked/media/2026-11-05%20build%20tabs%20scroll.jpg)

### Round 11: grades, upkeep and 3D minigames (2026-11-05)

**Every minigame is 3D now**
- All 8 jobs are little 3D scenes with their own room, lighting and props. Same rules as before, so they're still easy to finish.
- Sweep the floor: pick up litter and drop it in the bins.

![2026-11-05 3d floor game.jpg](Overbooked/media/2026-11-05%203d%20floor%20game.jpg)
- Make the bed: pull the sheet, fluff the pillows.

![2026-11-05 3d bed game.jpg](Overbooked/media/2026-11-05%203d%20bed%20game.jpg)
- Shower: scrub the grime off the tiles and glass, then turn the tap to rinse it all away.

![2026-11-05 3d shower game.jpg](Overbooked/media/2026-11-05%203d%20shower%20game.jpg)
- Toilet: scrub it with the brush, then press the flush.

![2026-11-05 3d toilet game.jpg](Overbooked/media/2026-11-05%203d%20toilet%20game.jpg)
- Check-in: book the guest on the monitor, take the right key from the cabinet, stamp the card.

![2026-11-05 3d check in.jpg](Overbooked/media/2026-11-05%203d%20check%20in.jpg)
- Check-out: give the exact change from the brass tray.

![2026-11-05 3d check out.jpg](Overbooked/media/2026-11-05%203d%20check%20out.jpg)
- Cook: pick the food, chop it, cook it in the pan, plate it and ring the bell.

![2026-11-05 3d cook.jpg](Overbooked/media/2026-11-05%203d%20cook.jpg)
- Repair: reconnect the wires, screw the bolts back in and pull the lever.

![2026-11-05 3d repair.jpg](Overbooked/media/2026-11-05%203d%20repair.jpg)

**Drag to build**
- In build mode, hold the left mouse button and drag to lay a whole row of walls, windows, doors or furniture in one go. Walls turn to follow your drag and join end to end. The tag shows how many fit and the total price. Let go to place them all; Undo (Z) takes the whole row back for a full refund.

![2026-11-05 drag window walls.jpg](Overbooked/media/2026-11-05%20drag%20window%20walls.jpg)

**Sounds**
- The loud level-up song is gone everywhere: level up, new land, chapters. Only the new soft chime plays now, never two at once.

**Your first hotel is a first hotel**
- Hotels now have 5 grades. You start as a small one-storey **Roadside Inn**. Meet the goals on the Hotel page (level, rooms, staff, rating, cash) to upgrade it: Town Hotel, City Hotel, Grand Hotel and finally a **Palace Hotel** with a neon sign. Each grade adds to the building and raises room prices.
- The "welcome back, your hotel was just as you left it" message is gone.

![2026-11-05 grade 1 inn.jpg](Overbooked/media/2026-11-05%20grade%201%20inn.jpg)
![2026-11-05 grade 3 city hotel.jpg](Overbooked/media/2026-11-05%20grade%203%20city%20hotel.jpg)
![2026-11-05 grade 5 palace night.jpg](Overbooked/media/2026-11-05%20grade%205%20palace%20night.jpg)
![2026-11-05 grade card.jpg](Overbooked/media/2026-11-05%20grade%20card.jpg)

**Things break, bags and lost property**
- Showers, toilets and lobby machines sometimes break: a puddle and mist appear and you get a Repair prompt (the repair minigame). A handyman you can hire fixes them too.

![2026-11-05 broken shower.jpg](Overbooked/media/2026-11-05%20broken%20shower.jpg)
- Guests sometimes leave bags at the desk for you to carry up to their room.
- Guests sometimes leave things behind (like a teddy on the bed). Take it to lost and found.

![2026-11-05 lost teddy.jpg](Overbooked/media/2026-11-05%20lost%20teddy.jpg)
- VIP guests start turning up from grade 3 and pay more the better your hotel is.

### Round 10e: the big list (2026-11-04)

![2026-11-04 main menu.jpg](Overbooked/media/2026-11-04%20main%20menu.jpg)
![2026-11-04 loading screen.jpg](Overbooked/media/2026-11-04%20loading%20screen.jpg)
![2026-11-04 build button and hud.jpg](Overbooked/media/2026-11-04%20build%20button%20and%20hud.jpg)

**Money and pace**
- Research takes about 3 times longer.
- Staff cost about 3.5 times more, and each one is paid a wage every day.
- Levelling up takes more XP and pays less cash.
- A plain starter hotel now gets reviews around 2 stars. Decor, fun things and good service push it up.
- Guests stay longer. A full day is about 7 minutes, so time moves a lot faster.
- Evenings (5 to 10 pm) bring more guests. The middle of the night is quiet.
- In co-op, money a helper earns goes to the hotel's owner, so building someone else's hotel spends their cash, not yours.

**Screens**
- New title screen, loading screen and BUILD button.
- The OPEN tag next to the guest count is gone. The left menu bar is more compact.
- The Talk and Check In/Out buttons no longer sit on top of each other.
- Bubbles over far-away people shrink and fade instead of floating miles off.
- Instead of "Showering..." labels, guests and staff now say things like "I should grab a snack", and sometimes nothing at all.
- A **phone** with messages, reviews and reports.
- A gamepass shop page. Nothing costs anything or does anything yet.
- Phones get a sprint button, and the HUD keeps clear of Roblox's own buttons.

![2026-11-04 phone.jpg](Overbooked/media/2026-11-04%20phone.jpg)

**Build mode**
- Walls snap end to end, so closed rooms are easy to make.
- Items you've unlocked come first in the shop.
- Holding right click and moving the mouse turns the camera again.
- New tools: keep placing, wall snap and undo.
- New kinds of walls, doors and windows, new beds (suite, canopy, bunk, twin), fun objects (pinball, treadmill, hot tub and more), staff lockers and parking spots.

![2026-11-04 build tools.jpg](Overbooked/media/2026-11-04%20build%20tools.jpg)

**Car park**
- Parking spots go in the car park in front of your hotel. About 7 in 10 guests drive and park in a free spot. More spots bring guests a bit faster.

![2026-11-04 car park.jpg](Overbooked/media/2026-11-04%20car%20park.jpg)

**Staff**
- Staff start slow and get faster as they level up (level 1 to 5). It takes a while: they earn XP for each job and for every minute on shift. Their name tag shows the level.
- With 3 or more staff you need a **staff room** (staff lockers). Until then they work slower, and your phone tells you.
- When there's nothing to do, staff dust dirty decor, take a break at the staff table or lockers (more at night), or mop the lobby.
- You can talk to staff. The card shows their level, XP and wage.

**Guests**
- When you talk to a guest, or one comes to talk to you, they stop and face you for a while before leaving.
- Lots more dialogue, depending on what they're doing: waiting in line, checked in, leaving, grumpy, at night, with a partner, with bags.
- Guests act out what they use: point, cheer, dance, run on the treadmill, sit in the hot tub, play pinball.
- Knock while a guest sleeps, has the Do Not Disturb sign up, or you keep knocking, and they get angry.
- Do Not Disturb signs show up a bit more often.
- Happy guests sometimes leave a **tip on the bed**. Take it yourself, or it's added when the room is cleaned.
- About 3 in 4 guests bring luggage: a suitcase they roll beside them, or a duffel bag in hand. They leave it by the bed.
- Couples: two guests can share one room if it has a double bed (suite, canopy). They pay more.

![2026-11-04 luggage.jpg](Overbooked/media/2026-11-04%20luggage.jpg)

**Jobs only you can do**
- **Room service:** a guest calls for food, you take the tray from the service cart and knock on their door. A quick delivery pays $45, a slow one $30. Staff can't do this. Tested: $30 delivered to Room 102.
- **Dusty decor:** lobby decor gets dusty over time and lowers the lobby's appeal until you (or a free janitor) dust it off.

**Saving**
- Rooms you left dirty are still dirty when you come back.
- Staff levels are saved.

**Starter hotel**
- The starter lobby has more to do and look at: an armchair, a bookshelf, a vending machine, the service cart, two potted trees and a rug.
- Each starter room has a new layout with a wardrobe and a second nightstand.
- The bed and rug were remade with sharp edges and patterns (they were blurry).

![2026-11-04 starter lobby.jpg](Overbooked/media/2026-11-04%20starter%20lobby.jpg)
![2026-11-04 starter room.jpg](Overbooked/media/2026-11-04%20starter%20room.jpg)

**Music**
- The loud jingle for level-ups and big moments is replaced by short stings, and the music dips under them.
- A bigger background playlist, shuffled: bossa and swing by day, slow piano jazz at night. It switches at dusk and dawn.

**Other hotels**
- In the PLAY TOGETHER panel you can **Visit** someone's hotel or **Ask to join** it. They get a card with Let in / No thanks.
- Empty plots now show a navy and gold PRIME HOTEL LOT billboard with lamps, a velvet rope, cones and a COMING SOON sign.

![2026-11-04 empty plot.jpg](Overbooked/media/2026-11-04%20empty%20plot.jpg)

### Round 10d: make your own rooms, buy land (2026-11-03)

![2026-11-03 wall room.jpg](Overbooked/media/2026-11-03%20wall%20room.jpg)
![2026-11-03 guest in wall room.jpg](Overbooked/media/2026-11-03%20guest%20in%20wall%20room.jpg)

**Rooms you build yourself**
- You don't buy ready-made rooms any more. In build mode you wall off a space with **Wall** pieces and give it a **Door** that opens onto the lobby.
- The moment it's closed in, it becomes a guest room with its own number (201, 202 and so on). The floor turns to oak, and a number plate and status lamp go up over the door.
- Put in a bed, a shower and a toilet and it opens for guests, just like the old rooms. A guest checked into Room 201 in my test and walked in.
- Walls can now overlap each other, so corners join up easily. Small gaps (under about a stud) still count as closed.
- Take a wall away and the room goes back to being lobby, once nobody is staying in it. Its furniture stays where it is.

**More land**
- The old NEW ROOM card is now **MORE LAND** (in All, Rooms and Structure). Each plot adds an empty 26 x 60 stretch of lobby floor on the side of the hotel, with a new outer wall and windows.
- Prices and level gates are the same as the old rooms ($400, $800, $1500, $2400).
- Rooms you already bought stay as they are.

**Guests and faces**
- A new hotel gets guests slowly now. At level 1 at most 2 wait in line, with about 18 s between arrivals and at most 6 guests inside. It ramps up to the old pace by level 7.
- Guest faces were warping on Roblox's new round heads (eyes slid sideways). Every NPC now has a classic head with a sharp, centred face.

![2026-11-03 guest faces.jpg](Overbooked/media/2026-11-03%20guest%20faces.jpg)

**Other fixes**
- The left menu bar is centred on the screen now (it used to sit high).
- Cash shows in the player list (leaderstats).
- Performance:
  - Lights more than about 140 studs away turn off until you get close.
  - Small city props no longer cast shadows.
  - About 25% fewer street walkers, kept to a tighter ring round the players, with unused walker states turned off.
  - Far-away cars skip their bounce.
  - Studio's fps swings too much (30 to 56 in the same spot) for me to give you a real before and after number.

### Round 10: everything in the hotel, remade (2026-11-03)

![2026-11-03 top bar and goals.jpg](Overbooked/media/2026-11-03%20top%20bar%20and%20goals.jpg)
![2026-11-03 storm.jpg](Overbooked/media/2026-11-03%20storm.jpg)
![2026-11-03 new furniture.jpg](Overbooked/media/2026-11-03%20new%20furniture.jpg)

**The hotel and its people**
- Guests feel alive now. They chat to each other and to staff, sit down, wander the lobby, go out, come back, and stop you with complaints or compliments. Talk to any guest to hear how their stay is going.
- Knock on an occupied room. Sometimes they let you in, sometimes they don't. Guests hang **Do Not Disturb** and **Sleeping** signs, and knocking on those hurts your review.
- When you open a door, your hand goes onto the knob and follows it, then lets go as you walk away.
- Rooms that need cleaning glow on their door instead of a board inside the room. The cleaning minigames were fixed and remade.
- The reception desk is now one small desk with a chair and a monitor, and checking a guest in or out is a quick minigame.
- The queue outside lines up properly, with no shuffling and everyone facing the door.

**The kitchen (hotel level 3)**
- New stoves, prep counters, kitchen fridges, a serving counter and cafe tables.
- Guests order a dish (burger, omelette, pancakes, steak or pasta), wait at the counter, then sit and eat and pay.
- Hire a cook, or cook it yourself in a 4-step minigame: prep, chop, get it golden in the pan, then serve and ring the bell.

**Weather and the street**
- The weather changes on its own: clear, cloudy, fog, rain, thunderstorms and snow.
- Rain and snow fall, puddles splash, clouds roll in and the sky darkens. Storms bring lightning and thunder.
- In the rain, people put up umbrellas, hurry, duck into shops, and more of them want a hotel room. There are fewer people out in bad weather.
- The street gets busier at the morning and evening rush and goes quiet late at night. It no longer empties out the longer you play.
- Trees, lamps and traffic lights now only block you at the trunk or pole, so no more invisible walls.

**Screens**
- A new bar along the top shows your level and XP, cash, rating, guests and free rooms, and the time and weather. Chapter goals sit on the right, 3 at a time.
- New prompts, guest bubbles and menu pages. Achievements replace the old stats page.

**Controllers and phones**
- PS5 and Xbox controllers work everywhere.
  - D-pad up: build. Left: the menu. Right: research. B closes whatever is on top.
  - In build mode, the sticks move and turn the camera, the triggers zoom, and A places what's under the centre ring.
  - In minigames, the stick moves a gold cursor and A presses.
- On phones, key hints are hidden and the left buttons stay clear of the thumbstick.

**Build mode: 12 new items**
- Chesterfield sofa, chess table, dartboard, gramophone, bonsai, painter's easel, telescope, marble column, candelabra, umbrella stand, vanity and clawfoot bath.
- Each one unlocks through research.

![2026-11-03 new furniture renders.png](Overbooked/media/2026-11-03%20new%20furniture%20renders.png)

### Round 9: the big remake (2026-11-02 to 2026-11-03)

![2026-11-03 title screen.jpg](Overbooked/media/2026-11-03%20title%20screen.jpg)
![2026-11-03 title screen saves.jpg](Overbooked/media/2026-11-03%20title%20screen%20saves.jpg)
![2026-11-03 new hud.jpg](Overbooked/media/2026-11-03%20new%20hud.jpg)
![2026-11-03 menu hotel tab.jpg](Overbooked/media/2026-11-03%20menu%20hotel%20tab.jpg)
![2026-11-03 menu staff tab.jpg](Overbooked/media/2026-11-03%20menu%20staff%20tab.jpg)
![2026-11-03 day summary.jpg](Overbooked/media/2026-11-03%20day%20summary.jpg)
![2026-11-03 event guests queue.jpg](Overbooked/media/2026-11-03%20event%20guests%20queue.jpg)
![2026-11-02 research menu.jpg](Overbooked/media/2026-11-02%20research%20menu.jpg)
![2026-11-02 build mode shapes.jpg](Overbooked/media/2026-11-02%20build%20mode%20shapes.jpg)
![2026-11-02 build mode wall art.jpg](Overbooked/media/2026-11-02%20build%20mode%20wall%20art.jpg)
![2026-11-02 guest event birthday.jpg](Overbooked/media/2026-11-02%20guest%20event%20birthday.jpg)
![2026-11-02 guest event dog.jpg](Overbooked/media/2026-11-02%20guest%20event%20dog.jpg)

**Title screen (new)**
- The camera flies slowly along the street in 5 shots, dipping to black between them, with film bars at the top and bottom.
- The logo: **OVER** rises in, then a red **BOOKED** hotel stamp slams down with a thud and a bell. A shine runs across it every few seconds.
- **Play** opens your 3 save files as cards (hotel name, cash, rooms, then Continue or New hotel). **Tips** and **Settings** slide in on the right.
- Picking a save fades to black, puts you at your hotel and hands the camera back.

**All the UI, remade**
- One look everywhere: dark navy glass panels, cream text, brass accents, one font. Panels rise and settle, buttons lift on hover and squash when pressed, lists slide in one by one, numbers count up.
- HUD:
  - a hotel card with the name, stars, day and clock
  - a glowing "guests waiting" pill
  - room chips (ready, busy, dirty)
  - a cash counter that counts up and flies "+$" off it
- The **Menu** (top right, or M) has these tabs, and its burger icon turns into an X:
  - Hotel: rename it, stars, quick numbers and a Research shortcut
  - Staff: hire, with little pips for each hire
  - Co-op, Stats and Settings
- An end-of-day card: guests served, rooms cleaned and money earned.
- Toasts slide in at the top right. Prompts have a gold ring that fills while you hold.

**Build mode, remade**
- Roof toggle (auto, always on, always off) and grid snapping with different grid sizes.
- Turning in any step, stacking things on furniture, hanging things on walls, raising and lowering.
- **Shapes**: blocks and other shapes you can size, colour and give a finish (marble, wood and more) for your own decor.
- A card on placed things: move, turn, copy, paint, sell.
- A shop search, and 98 items in the shop now.

**Research (new)**
- Press R or the flask button on the right.
- 33 things to research, in branches (build tools, decor, guest events, upgrades).
- Each costs cash and takes real time. One runs at a time, and it keeps going while you're away.

**Guest events (new)**: some guests come with a need, a look and a badge over their head. Give them what they need for a bigger payout:
- Baby (needs a cot)
- Accessibility (needs accessible gear, walks slower)
- Pet owner (a dog on a lead that trots and sniffs)
- All-nighter (TV and snacks, no sleep)
- Birthday (party hat, balloon, confetti)
- Business trip
- Honeymoon (rose and balloon, hearts)
- Sick guest (needs a first-aid kit)
- Hotel inspector (checks safety and the lobby, pays a reward)
- Tour group (3 tourists with cameras)
- Celebrity (shades and sparkle, camera flashes, needs 4 stars)

**The street and the city**
- A full avenue: lanes, crosswalks, traffic lights, shops across the road, a skyline, tunnels at both ends, parked cars, lamps and trees.
- Traffic: new car and bus models drive tunnel to tunnel and keep their distance. They stop at red lights and for people in the road, with brake lights, and headlights at night.
- Crowds:
  - they walk the whole sidewalk end to end, even past empty plots
  - they cross at crosswalks and step round lamps and each other
  - some turn into your hotel as guests
- City sounds: a day mix (distant traffic, birds, wind) and a night mix (traffic and crickets). Loudest by the road, quiet indoors.

**People**: 165 first names, many more hairs, hats, shirts and pants, and different walk styles (bouncy, stiff, cartoony...) so the crowd doesn't all move the same.

**Lighting and day/night**
- The bright-hotel bug is fixed: the old clock pushed the light way past daytime.
- Sunrise, morning, noon, golden hour, sunset and dusk each have their own look.
- The inside of the hotel has its own softer light that blends in as you walk in and out.
- Lamps and windows light up at night.

### Your own hotel and co-op (round 8)

![2026-10-30 own hotel.jpg](Overbooked/media/2026-10-30%20own%20hotel.jpg)
![2026-10-30 coop panel.jpg](Overbooked/media/2026-10-30%20coop%20panel.jpg)
![2026-10-30 coop invite.jpg](Overbooked/media/2026-10-30%20coop%20invite.jpg)

- **Everyone gets their own hotel.** There are 5 plots side by side along the street, each with its own hotel, garden, road and guests. When you join you get a free plot and spawn in front of your hotel, which shows your name ("SAM'S HOTEL").
- Your hotel, cash, rooms, furniture, staff and upgrades are all yours and saved to you, wherever your plot ends up next time.
- Guests only come to a hotel while someone is working in it.
- If you walk up to someone else's hotel, its buttons don't show up for you, and you can't build there.
- **Co-op:** the purple **Co-op** button at the top right opens **PLAY TOGETHER**:
  - Everyone in the server is listed with their picture. Press **Invite** to ask them to help run your hotel.
  - They get a card ("Sam invited you! Help run Sam's Hotel") with **Join** and **No thanks**, a bell and a 55 second timer bar.
  - Join and you're taken to their hotel. You can let guests in, clean, collect cash, build, buy rooms, upgrade and hire there. It's paid from your own cash, and the work saves in the owner's hotel.
  - The button says **Helping** while you're away, and the panel has a **My hotel** button to go back.
  - The owner can **Send home** a helper. Up to 4 people per hotel.
  - If the owner leaves, helpers are sent back to their own hotels.
- If all 5 plots are taken, a new player joins the quietest hotel as a helper.

### Room upgrades and stars (round 7)

![2026-10-29 room upgrades.jpg](Overbooked/media/2026-10-29%20room%20upgrades.jpg)
![2026-10-29 upgrade cards.jpg](Overbooked/media/2026-10-29%20upgrade%20cards.jpg)
![2026-10-29 suite sign.jpg](Overbooked/media/2026-10-29%20suite%20sign.jpg)

- Build mode's **Rooms** tab (it also shows in All) has a card for every room. Click it once and it turns green ("Click again to upgrade"), then click again.
- Every room has 3 levels:
  - **Standard**: what you start with.
  - **Deluxe** ($500): +$25 a stay, bigger tips. The room gets cream wall panels with a brass rail, a blue padded feature wall behind the bed, two glowing wall lamps, a darker wood floor and a blue throw on the bed.
  - **Suite** ($1,400 more): +$60 a stay, even bigger tips. Everything turns emerald and gold, with crown moulding round the top of the walls and a marble bathroom.
- You get sparkles, a hammer and fanfare sound, and a "Room 101 is now a Deluxe!" message.
- **Stars:** each room gets 1 to 5 stars:
  - 1 for Standard, 2 for Deluxe, 3 for Suite
  - +1 if its furniture adds 8 appeal, another +1 at 20
- Each room's stars show on a sign over its door, with the level name.
- **Hotel rating:** the stars under your hotel's name at the top of the screen are the average of your rooms. They fill in part by part, like 3.3 stars. A better rating makes guests arrive sooner.
- The throw follows the bed if you move it, and hides while the bed is messy.
- Upgrades are saved with your hotel.

### Staff (round 6)

![2026-10-29 staff tab.jpg](Overbooked/media/2026-10-29%20staff%20tab.jpg)
![2026-10-29 janitors.jpg](Overbooked/media/2026-10-29%20janitors.jpg)

- Build mode has a new **Staff** tab (it also shows in All). Click a card once and it turns green ("Click again to hire"), then click again.
- **Janitors** (up to 3: $350, $750, $1,200):
  - wear a blue uniform and carry a mop
  - wait in the lobby ("Waiting for work"), then walk to the nearest dirty room and do every job themselves: floor, bed, toilet, shower
  - They sweep the mop while they work, with a progress bar, the same cleaning sounds and sparkles, then say "All clean!" or "Spotless!".
  - A room takes them about 20 seconds.
  - Two janitors never take the same room. You can still clean alongside them.
- **Doorman** (1, $600):
  - wears a red coat and cap and stands outside next to the front door
  - when a guest is waiting and a room is clean, waves, says "Come on in!" and lets them in, just like pressing Let In
  - shows "No clean rooms" when there's nowhere to put them
- Each card shows how many you have (like 2/3) and says **All hired** when you're full.
- Your staff are saved with your hotel.

### Sounds (round 5)

The hotel has sound now. Everything in the world comes from where it happens, so it gets quieter as you walk away.

| When | You hear |
|---|---|
| Always | Chill bossa nova lounge music (3 songs, shuffled). **M** turns it off and on. |
| A guest joins the line | a soft ding |
| You let guests in | the glass door sliding |
| Check-in | Ben's desk bell |
| Shower | water running for as long as they shower |
| Toilet | a flush |
| A guest pays | coins dropping |
| Collecting the cash pile | the cash register, then coins |
| Cleaning | sheets whooshing (bed), spray bottle (shower), scrubbing (toilet), broom (floor), each with a little sparkle |
| Room ready | a bright ding |
| Room needs cleaning | a lower ding |
| Something goes wrong | a low "nope" blip |
| Build mode | a whoosh in and out, a wooden thud when you place or move, a turning whoosh, the register when you sell |
| Buying a room | hammering while it rises, then a short fanfare |
| Buttons | a soft click, and a tiny tick on hover |

All of it is from Roblox's licensed sound library (Pro Sound Effects, APM, licensed music), so it plays in the published game.

### Saving (round 4)

![2026-10-29 welcome back.jpg](Overbooked/media/2026-10-29%20welcome%20back.jpg)

- Your hotel is saved now. When you come back, it's **just how you left it**:
  - your cash (and your earned / cleaned / spent totals)
  - every room you bought
  - every piece of furniture, in the same spot and facing the same way
- It saves when you leave, every minute, and a few seconds after you build or sell something.
- When you come back with a save you get a toast: **"Welcome back! Your hotel is just how you left it."**
- Only the first player in a server loads their hotel (there's still one shared hotel per server). Other players keep their own cash.
- If Roblox can't load your save, you get a warning and nothing is saved that visit, so an old save is never wiped by accident.
- Also fixed: the cash counter at the bottom left could stop partway when it changed a lot at once (it showed $4,078 instead of $4,395). It always lands on the right number now.

### New rooms (round 3)

![2026-10-29 room 104 built.jpg](Overbooked/media/2026-10-29%20room%20104%20built.jpg)

- Next to the hotel there's a fenced lot with orange stakes and a yellow sign: **ROOM 104 FOR SALE, $400, Buy it in Build mode**.
- In build mode the shop has a new **Rooms** tab. The next room is also the first card in All: a gold card with a bed and a red NEW tag. Click it once and it turns green ("Click again to buy"), then click again.
- The hotel grows a whole new **wing**:
  - a furnished room at the back (bed, nightstand, shower, toilet, rug, lamp, plant, painting, door number)
  - more lobby in front, with the glass front, red hallway carpet, brick wall, paving and hedges carried on
  - The walls, floor and furniture rise up out of the ground, front to back, then confetti pops.
  - The camera flies over to it, and you get "Room 104 is open!".
- Guests use it straight away like any other room, and you clean it the same way.
- Rooms go on alternate sides and have to be bought in order:

| Room | Side | Price |
|---|---|---|
| 104 | right | $400 |
| 105 | left | $800 |
| 106 | right | $1,500 |
| 107 | left | $2,400 |

![2026-10-29 room for sale.jpg](Overbooked/media/2026-10-29%20room%20for%20sale.jpg)
![2026-10-29 room rising.jpg](Overbooked/media/2026-10-29%20room%20rising.jpg)
![2026-10-29 room 105 west wing.jpg](Overbooked/media/2026-10-29%20room%20105%20west%20wing.jpg)

### Build mode (round 2)

![2026-10-29 build mode.jpg](Overbooked/media/2026-10-29%20build%20mode.jpg)

Press **B** or the yellow **Build** hammer button at the bottom of the screen. Press it again (it turns into a green **Done**) to go back to walking.

**The camera** floats up over the hotel.
- WASD or the arrow keys move it, Q/E turn it, the scroll wheel zooms, and holding right-click and dragging tilts and turns it.
- On a phone: drag to move, pinch to zoom.
- The glass front and the big sign fade out while you build so you can see the lobby.
- Your character stands still until you leave build mode.

**The shop** sits along the bottom.
- Tabs: All / Furniture / Decor / Fun. Your cash is in the top corner of the shop.
- Each card has a little 3D picture, the price, and a star with how much **appeal** it adds.
- Cards you can't afford go dark.
- 14 things to buy:
  - Monstera $60, Rug $50, Floor Lamp $70, Topiary Tree $110
  - Nightstand $80, Coffee Table $90, Flower Table $90, Armchair $120
  - Bookshelf $160, Wardrobe $180, Sofa $250, TV $300
  - Vending Machine $350, Ping-Pong Table $400
- 8 of them are new Blender models: armchair, TV stand, wardrobe, bookshelf full of books, ping-pong table, vending machine with snacks behind the glass, topiary tree, flower side table.

**Placing**
- Click a card and a see-through copy follows your mouse, snapping to a grid. It glows green where it fits and red where it doesn't, and the label over it says why ("Keep the hallway clear", "Too close to the sofa", "Keep it inside one room").
- **R** (or the blue Turn button) spins it. Click or press Place to buy it. It drops in with a little bounce and a puff of dust, and "-$80" floats up.
- Hold **Shift** to keep placing the same thing. Right-click, X or Cancel stops.
- Red zones on the floor are no-build areas: the hallway, the entrance carpet, reception and each room's doorway, so guests can always get through.

![2026-10-29 build zones.jpg](Overbooked/media/2026-10-29%20build%20zones.jpg)

**Changing what's there**: click any furniture and a card pops up over it.
- **Move**: pick it up and put it somewhere else.
- **Turn**: a quarter turn on the spot.
- **Sell**: you get 75% back. It asks "Sure?" first.
- **Close**.

![2026-10-29 build card.jpg](Overbooked/media/2026-10-29%20build%20card.jpg)
![2026-10-29 build moving.jpg](Overbooked/media/2026-10-29%20build%20moving.jpg)

**Bed, shower and toilet**
- You can move and turn these, but only inside their own room. You can't sell them ("Every room needs its bed").
- You can't move them while a guest is in that room.
- Guests find them wherever you put them. I moved Room 101's bed to the other wall, and the next guest walked round to the free side and slept in it. The cleaning buttons and the shower water move with them too.

**Why decorate: appeal**
- Every item has appeal. A room's nightly price is $40 + $3 for each appeal point in it, so the starting rooms are $64 a night. A TV (+8) makes a room $88.
- Lobby appeal makes guests at the door more patient and makes new guests turn up more often.
- In build mode each room and the lobby have a label with their appeal and price.
- You now start with **$300**.

### Round 1

![2026-10-29 overview.jpg](Overbooked/media/2026-10-29%20overview.jpg)

**The hotel**
- A lobby with a big dark-framed glass front and sliding doors that open when anyone walks up.
- A striped canopy over the entrance and a lit sign with your name on it ("OFFSETIC'S HOTEL"). Your name is on the top of the screen too.
- Wood floors, lavender walls, brick outside, a red carpet from the door to the room hallway.
- Reception: a slatted wood wall with a RECEPTION sign, a desk with a computer, a bell and a little plant, and **Ben the receptionist**, who waves and says hi to each guest.
- A waiting corner with two teal sofas, a coffee table, a rug, floor lamps and a painting. Big monstera plants around the lobby.
- Outside: a path with street lamps, hedges in planters, a sidewalk and a road. Guests come from both ends of the street.

![2026-10-29 lobby check-in.jpg](Overbooked/media/2026-10-29%20lobby%20check-in.jpg)
![2026-10-29 outside.jpg](Overbooked/media/2026-10-29%20outside.jpg)

**Three rooms (101, 102, 103)**
Each one has a bed (padded headboard, duvet, pillows, a coloured runner), a nightstand with a lamp, a corner shower (glass, tiles, rain head, bottles on a shelf), a toilet with a roll holder, a grey tiled bathroom floor behind a half wall, a rug, a floor lamp, a plant and a painting.

![2026-10-29 room shower.jpg](Overbooked/media/2026-10-29%20room%20shower.jpg)

**Guests**
- Every guest is different: random name, shirt, pants, hair, sometimes a hat, skin colour, height and build (Roblox's own clothing and hair).
- They walk with real paths around furniture, and have a card over their head: an icon, what they're doing and a progress bar, plus speech bubbles ("Do you have a room?", "Ooh, nice room!", "Five stars!").
- Waiting outside, their bar is their **patience**. It goes green, yellow, red. If you leave them too long they give up and walk off.
- In the room they sit on the toilet, stand in the shower (water and steam turn on), and lie down in bed with floating Zzz's. Bed always comes last.
- Then they check out at the desk, pay ($40 plus a tip) and walk home.

**Your jobs**
- **Let guests in** at the front door ("New Guests (3) / Let In"). Only as many come in as you have clean rooms. With none clean, the button says "No clean rooms".
- **Clean rooms.** When a guest leaves, the room gets a messy bed, a dropped towel, trash on the floor and a yellow NEED CLEANING sign, with dust over each dirty spot. There are 4 jobs: make the bed, scrub the shower, clean the toilet, pick up the trash. Each one is a round yellow button you hold for a second. When all 4 are done the room sparkles and says "Room 102 is ready!".
- **Collect cash.** Payments stack up as bundles of bills on the gold stand next to reception. Walk up and press Collect.

![2026-10-29 room dirty.jpg](Overbooked/media/2026-10-29%20room%20dirty.jpg)

**Screen**
- Bottom left: clean rooms / rooms with guests / dirty rooms (with counts that pop when they change), and your cash, which counts up.
- Top: your hotel's name, and "3 guests waiting" when someone's at the door.
- Toasts for "Room 101 needs cleaning", "Room 103 is ready!", "Emily got tired of waiting".
- Money pops up in the world ("+$52") when a guest pays and when you collect.
- All the buttons in the world (Let In, Clean, Collect) are big round icon buttons with a bobbing animation, a fill while you hold, and the key shown. You can also click or tap them.

**Hand-drawn icons and models**
![2026-10-29 icons.png](Overbooked/media/2026-10-29%20icons.png)
![2026-10-29 props.png](Overbooked/media/2026-10-29%20props.png)
(The props render looks washed out; in game the colours are richer, as in the screenshots above.)

### Tasks
- [x] New place, notes and folders for Run a Hotel
- [x] Hotel building: lobby, glass front, sliding doors, reception, waiting area, outside
- [x] 3 rooms, each with a bed, shower and toilet (plus decor)
- [x] Guest NPCs with random names and outfits that walk around
- [x] Guests use the toilet, shower and bed
- [x] Check-in and check-out at reception, guests pay
- [x] Rooms get dirty after check-out; clean them to reuse
- [x] Let guests in at the door, patience timer
- [x] Cash pile + collect, HUD, toasts, money popups
- [x] Build mode: buy, place, move, turn and sell furniture
- [x] Guests use the bed, shower and toilet wherever they're moved
- [x] Appeal: decor raises room prices and lobby patience
- [x] Buy new rooms (4 more, in wings on each side)
- [x] Build mode sounds (place, sell, error)
- [x] Saving: cash, bought rooms and furniture come back when you rejoin
- [x] Each player gets their own hotel plot
- [x] Co-op: invite friends to help run your hotel
- [x] Sounds and music: door, bell, shower, flush, coins, register, cleaning, build mode, buttons, lounge music
- [x] Staff: janitors clean rooms, a doorman lets guests in
- [x] Room upgrades (Deluxe, Suite) and star ratings
- [x] Round 9: new UI everywhere with animations, new title screen, new Menu
- [x] Round 9: build mode remake (roof toggle, grid snap, free turning, stacking, wall items, shapes with size, colour and finish, many more items)
- [x] Round 9: research menu
- [x] Round 9: guest events (11 kinds)
- [x] Round 9: city map, traffic, cars, crowds end to end, walk-ins, walk styles, more names and clothes
- [x] Round 9: lighting and day/night remake, bright-lobby bug fixed
- [x] Renamed the game to Overbooked (title screen)
- [x] Round 10: hotel level and XP, left dock, research remake, one save per player
- [x] Round 10: guests that chat, sit, go out, complain and compliment; talk to guests; knocking and door signs
- [x] Round 10: hand on the door knob, cleaning minigames fixed and remade, reception minigame
- [x] Round 10: new top bar, chapter goals, achievements, new prompts and bubbles
- [x] Round 10: kitchen, cooks and the cooking minigame
- [x] Round 10: weather (rain, storms, snow, fog) that changes the street and demand; day-time crowds
- [x] Round 10: trees and lamps only block at the trunk and pole
- [x] Round 10: PS5 / Xbox controller support and phone fixes
- [x] Round 10: 12 new build items
- [ ] More ways to spend cash: faster staff, more receptionists, lobby upgrades
- [ ] Star rating for rooms / reviews from guests

- [x] Round 10d: rooms made with walls and doors, land plots, left menu centred, cash leaderstats, performance pass
- [x] Round 10e: economy, wages, staff levels and staff room, phone, gamepass page, title and loading screens, build tools and new items, car park, luggage, couples, tips, room service, dusty decor, new music, visits and join requests, new empty plots
- [ ] Round 10e: a few guests' walk sometimes glitches (not reproduced yet)
- [x] Round 11: loud level-up song removed, only the new sounds play
- [x] Round 11: hotel grades (Roadside Inn to Palace Hotel), starter hotel made plain, welcome-back toast removed
- [x] Round 11: breakdowns and repairs, handyman, bags to rooms, lost and found, VIPs from grade 3
- [x] Round 11: all 8 minigames remade in 3D
- [x] Round 11: drag to build rows of walls, windows and furniture
- [x] Round 12: sit at the desk to check in and out, check-in on the monitor, full-screen minigames, your own avatar's arm
- [x] Round 12: smaller prompts, toilet flush on screen, shorter cleaning, sit on chairs, more talk options, friends as guests
- [x] Round 12: build camera turns with right-drag (and two-finger twist on phones)
- [x] Round 12: new 10-step tutorial including build mode
- [x] Round 12: new loading screen and title screen
- [x] Round 12: more settings, saved with your profile
- [x] Round 12: 26 new build items
- [x] Round 12b: build tabs scroll on phones; walls join existing walls to make new rooms
- [x] Round 13: hotel room doors in build mode (Room, Modern, Suite)
- [x] Round 13: base staff take much longer (the doorman walks out and greets each guest)
- [x] Round 13: better uniforms and accessories (4 outfits a role, headwear, badges)
- [x] Round 13: staff wardrobe that saves for good
- [x] Round 13: staff jobs: janitor rooms, focus per role, shifts
- [x] Round 13: research grows to 72 projects in 12 branches with crossing paths
- [ ] Round 13: look at the new uniforms and the wardrobe preview in game (Studio's 3D captures are blank, so I couldn't screenshot them)
- [ ] Round 12: check the phone layout, two-finger turning and friend guests on a real phone or with friends
- [ ] More UI animation polish and better minigames
- [x] Round 14: new paper-and-walnut style for the title, loading screen, goal cards and tutorial
- [x] Round 14: hiring with 3 candidates a role, skills, pros and cons that stay with each staff member
- [x] Round 14: staff room buildable from level 1
- [x] Round 14: 6 new personalities and many more lines
- [x] Round 14: minigame arm and glove, check-in shows the real guest
- [x] Round 14: tutorial checks the full staff room and teaches hiring
- [x] Round 14: door, music and rain sound variety
- [x] Round 14: better rain, wind, mist and umbrellas
- [x] Round 14: coin, cleaning, build and confetti effects
- [x] Round 14: shadow and collision performance pass
- [x] Round 14: /preset builds a real staff room and a 5-star team
- [x] Round 14b: palm, coffee table and floor lamp remodelled; umbrellas held in the hand; phone and research text readable
- [x] Round 14c: armchair, sofa, wardrobe and bookshelf remodelled
- [x] Round 14d: deluxe and suite beds (clean and messy), deluxe toilet, rain shower and vanity remodelled
- [x] Round 14e: guests and staff walk and stand with a new hand-made gait: heel strike, knee bend, hip sway, arm swing, weight shifts and breathing. Walk style follows the guest (Karens stomp, dashers sneak, party guests bounce, sleepy guests stroll, staff walk brisk)
  ![2026-11-09 new npc walk.jpg](Overbooked/media/2026-11-09%20new%20npc%20walk.jpg)
- [ ] Round 14 still to do: new footstep sounds (the sound library has no good single steps), remodel the rest of the furniture and the map
- [x] Round 15: new UI kit; HUD, prompts, chat bubbles above heads and dock rebuilt
- [x] Round 15: first-person talks with choices, moods, faces; the X fix
- [x] Round 15: new main menu, 3D loading screen, smoother way in
- [x] Round 15: build mode remade, room tool
- [x] Round 15: bigger plots, new starter hotel and map
- [x] Round 15: 8 modelled bags and cases; jackets, puffers, cardigans, vests, blazers, scarves and ties; wide faces fixed
- [x] Round 15: modelled staff mop, broom, wrench and clipboard
- [x] Round 15: 5 star guests with looks, lines and gifts; arrival and grade-up cutscenes
- [x] Round 15: minigame star clock, roomier research trees, sound mix
- [x] Round 15: modelled staff uniforms: greatcoats with long skirts, blazers, chef jackets, aprons, and peaked caps, top hats, chef hats, hard hats, caps and beanies, all with a fabric look
  ![2026-11-10 staff uniforms modelled.jpg](Overbooked/media/2026-11-10%20staff%20uniforms%20modelled.jpg)
- [x] Round 15: the floor-cleaning game sometimes has a compost bin too (food goes in compost)
  ![2026-11-10 minigame compost.jpg](Overbooked/media/2026-11-10%20minigame%20compost.jpg)
  ![2026-11-10 grade up cutscene.jpg](Overbooked/media/2026-11-10%20grade%20up%20cutscene.jpg)
- [ ] Round 15 still to do: bigger gameplay changes for the other minigames (beds, showers, toilets, desk, cooking, repairs). The tailcoat, short jacket, tuxedo, waistcoat, polo and hi-vis vest are still built from parts
- [x] Round 30: guests' hands on the desk, card, duvet, shower tap and flush
- [x] Round 31: first optimisation pass (traffic stubs, roof watcher, far NPCs)
- [x] Round 32: quick fixes (night street lamps and light, build-mode night lift, centre zoom while turning, bubbles, no guest status, room builder walls only, tutorial skip, click-outside close, Rthro walk at 8, chat beeps)
- [x] Round 33: build mode (catalogue on the right, room numbers 101+ with rename, Room Builder reuses walls, click cut-away walls to edit them, floor per room and lobby floor and roof on the build-mode cards)
- [x] Round 34: UI remake in the chapter look (glossy bottom tray with 3D icons back, white HUD plates with 3D cash/guest icons at the very top, toasts, day summary, loading screen, main menu, talk box and replies, tutorial card, upgrades page with 3D icons, smaller menu window, mobile sprint button)
- [x] Round 35: content (story start: clean up Aunt Marigold's mess; world events with a banner; lobby spills; 3D A-frame cleaning sign; smaller safe; busier sidewalks; slimmer outfit layers; star-guest cutscene camera no longer ends up inside the guest)
- [x] Round 36: fun and polish (lost property to return for a reward; janitors mop spills; Doormats upgrade; guest chatter fits where they are and the day's event; sleepers say Zzz; no more "I should start chatting with..." thoughts; staff stop parroting the same line)
- [x] Round 37: more guest types (backpacker, fitness fan, gamer, spa lover, each wanting a snack machine, treadmill, games or a bath; they unlock by level and show on the level road; /event commands for each; fixed "Hey! Gloria!" hello lines and the nan voice's "You?, dear.")
- [x] Round 38: more to do (odd jobs: 3 side goals that never run out; a runaway dog to catch; a seagull to shoo out; tips to grab by the desk; 5 new achievements; /dog and /seagull; lobby spots no longer land on sofas)
- [x] Round 39: tags, dirty rooms you can see, better minigames (earnable tags over your name and in chat; stains, flies and stink on dirty beds, showers, toilets and floors; bonus coins, hot streaks and best times in every minigame)
- [x] Round 40: new icons, all 8 minigames rebuilt, a better arm, work poses, a new HUD and UI style, surprise steps (85 icons re-rendered in the build-mode style with a new electrical spark; Floor, Bed, Shower, Toilet, Check In, Check Out, Cook and Repair remade as multi-step 3D jobs; the glove follows the mouse even without a click; your character plays a cleaning/fixing/cooking pose while you play; raised buttons and tinted panels everywhere; a lost item or a bug sometimes turns up mid-job)
- [x] Round 41: fixes and polish from your big list (save-file bin works on one arm + one press; toasts sit under the clock; small chapter card, hidden during the tutorial; the tutorial unlocks buttons as you go, holds guests until it asks you to wait for one, and turns cleaning into a little pick-up game; a new hotel card top left; bigger text everywhere; Open / Closed switch on the Hotel page; normal-sized, slower NPCs; only the beep voices, no old human voice; a new talk box; brighter night lighting indoors and out; no cleaning lamps on any room door; floor tiles plus lobby floor / room floor / roof style in build mode, not Upgrades; no room labels in build mode; a new build tool bar; the room tool snaps to walls already built; a small closed vault by reception; softer doors and footsteps; no lost items before the hotel has had guests)
- [x] Round 42: build mode remade (new Build Shop with 13 tabs and sub-tabs, a Recent tab and a Styles view; duplicates gone; a tool rail with Select, Box select, Delete, Paint, Pick and Room; select many things and move, turn, copy, paint or sell them together; Delete tool sells with a click or a sweep and Undo buys it back; a Placement panel with exact X / Z / height / angle, nudge arrows, grid and turn steps, wall snap, hug walls, stacking, keep placing and lock spot; a View menu for roof, walls and room colours)
- [x] Round 43: decorate outside the hotel (the whole lot is a "Grounds" build zone), a much bigger lot (reaches back to z -198, about 314 x 229 studs; the hotel itself is the same size), and a grid over the whole plot in build mode
- [x] Round 44: the bottom-left hotel card and the build-mode tool rail are white glossy plates like the rest of the HUD
- [x] Round 45: every build-mode panel (key strip, place bar, selection bar, Placement, View and Paint menus) is a white glossy plate like the HUD
- [ ] 2026-11-12 big request (rounds 32+). Quick fixes: build-mode zoom (right-click + scroll) zooms from the screen centre, not the mouse; build mode too dark at night; street dark at night and street lights give no light; better outside lighting; remove the light on top of doors; remove the status above guests' heads; bigger NPC/staff chat bubbles with a capital first letter, and key words/names coloured and underlined; rooms number 101, 102, 103, 104 (no 201 jump) and are easy to rename; room tool: no presets, walls only; tutorial: no "skip step", only finish it or skip it all; clicking or tapping outside a menu frame closes it; smooth queue in/out; slower guests on a Roblox (Rthro) walk, fix buggy walks; player chat sfx plays fully; car tyres actually spin and better car models.
- [ ] Build mode: catalogue on the right; flooring and roofing in build mode; the room tool can use existing walls; edit what is already built (walls, doors, rooms); new rooms fully empty (no walls inside, no bathroom area, their own flooring).
- [ ] UI remake (don't use the current UI as a reference): every menu far better, with more content, and a few are too big; main menu; loading screen; money and guest HUD moved up and redone; notifications; day summary; talking UI; tutorial (a little smaller) and quest UI; upgrades page (drop features nobody needs); mobile sprint button; less clutter overall; keep the old bottom bar with 3D icons and match the chapter UI.
- [ ] Content: first start = clean your hotel; cutscenes with dialogue at the story start and at milestones; world events (busy days, big storms, more) that change demand, with a notification; rewrite all NPC and staff dialogue so it fits where they are (outside, in their room, etc.); many more guest variants; better clothing (3D shirts with 2D pants look wrong) and accessories; many more people on the sidewalks; better and smaller safe at the reception desk; the "needs cleaning" sign as a real 3D sign; fix door clipping; better door-handle grabbing and more door sfx, used by NPCs, staff and other players; more co-op; PS5, Xbox and mobile controls and content; more game-changing upgrades and mechanics.
- [ ] Next ideas: guests picking up and setting down their own bags; sofas, chairs, tables, TV and vending machine with real contact; footsteps on the heel strike

### Your preferences (this game)
- Round 21 (2026-11-12):
  - "idk why but the game feels really unpolised and stuff maybe because everything looks so ai"
  - "make everything feel and look like and sound like an actual roblox game tat people will enjoy and people wont think everything is ai"
  - Loading screen and main menu: "a lot better and a little less cloudy and kid like"
  - "make the clock look like an actual clock and inside of it will show info"
  - Menus: no tabs to the other menus inside a menu; each opens on its own
  - "return to the normal roblox faces"
  - Smaller: the interact prompt, staff name tags, the dialogue UI. Voices "a little quieter"
  - Night outside the hotel was "way too bright"
  - Wants new saves to start with an empty hotel ("just the walls and roof"), a wider base hotel, and roof and floor customization
- Round 20 (2026-11-11):
  - About the first city remake: "it looks way too similar to the original city. remake it all ... don't use the current city and hotel as a reference make it all brand new"
  - "make the hotel start out looking very bad and poor and overtime gets better and better"
  - "add an upgrades tab where you can buy simple upgrades like make your hotel look better, visitors show up faster, more income"
  - "add a cutscene at the beginning of the game when it's your first time playing to show the \"story\" of the game"
  - "add a lot more content and focus a little on the story and improve quality a lot"
  - Wants test commands for seasons, weather and events, "like all the other commands are added"
- Round 16b (2026-11-10): "remake the whole map and remake all of the models try using not as many credits and make the quality of the models and textures amazing"
- Round 16 (2026-11-10):
  - "make the faces a lot better they look very weird and add a lot of different variants for gender and a bunch of other variants for it"
  - Voices: "they sound way too human and the words are too clear make it sound like beeps and boops or something and make them slightly clear but not too human like"
- Round 15 (2026-11-10):
  - "i liked the old chat bubble for the customers and te staff wherer it appeared above the customer"
  - "remake ALL of the ui and don't use the current ui as a refrence cuz the new ui looks too similar to the old ui"
  - "improve all the animations by 1000x they look very weird especially the walking animation and the suitcase/holdable animations"
  - "make it so when you talk to someone it looks like you are actually looking at them in first person", with "a BUNCH of dialouge options" and "an actual conversation"
  - "make the npcs (staff/customers) faces can change depending on their mood"
  - "make it so each hotel plot is a lot longer and a lot wider but isnt HUGE"
  - "add cutscenes and special customers", "add different types of bags/suitcases", "a lot more variety to customers"
  - "fix some of their body parts like their face being very long/wide"
  - follow-up: "for right now forget about the stuff not looking ai, remake everything u just made and focus on quality instead of not making it look ai"
  - How they work (still): "try using as mininal credits as possible and no uiseless chatting and i dont need an update log at the end"
- Round 14 (2026-11-09):
  - "remake all ui to be like 1000x higher quality with a lot of animations and a whole new style, make it not look like ai made it"
  - "remove the speech bubbles and thought bubbles", "remove the names above their heads", NPCs say their name when they talk
  - talking sounds that change with the message (! ? and length)
  - customers like the farm-game reference (straw hats, plaid, backpacks, happy faces) in this game's style, "fix stretched faces"
  - hiring: several candidates with pay, personality pros and cons and work skill, refreshing "not too often"; the pros and cons stay with each staff member
  - the staff room needs equipment before hiring, but the early game shouldn't be locked behind research
  - "remake all sfx and music with variants and randomization", plus talking, door and footstep sounds
  - better weather, umbrella animations, all VFX remade, "a big performance improvement"
  - remake /preset: everything needed, max level
  - How they work: "use as minimal credits as possible and no useless chatting", no update log at the end
- Round 13 (2026-11-06):
  - "add hotel room doors to the build menu because the user is suppose to custom build rooms using walls and doors"
  - "make the base staff take a lot longer to do stuff like the doorman should take a lot more time rather than it being instant"
  - "make all of the employees have better accessories and clothing"
  - "make it so you can customize your employees and they save thru the whole game unless you change them"
  - "add priority to workers so it could be like you can assign janitors to certain rooms"
  - "expand the research a lot lot more and add different branches that go to other paths in your hotel"
- Round 12 (2026-11-05):
  - "fix build mode on mobile not all the tabs are visible"
  - "fix the walls not being able to build off prob the already placed walls so you can't make new rooms using build mode"
  - "make the prompts smaller", "make it so players have to sit at the receptionist desk to check in or out"
  - "fix the mobile menu bar on the left and the top bar"
  - "add a tutorial that also teaches build mode"
  - "remake the loading screen and main menu to be a lot better", "make all ui a lot better with many ui animations", "add more settings"
  - "add a lot more items to build mode"
  - "friends avatars can appear as customers", "players can sit on chairs and couches", "many dialogue options with customers"
  - "make the minigames cover the full screen", "shorter cleaning minigames"
  - "when i ment show the users hand i ment like show their actual roblox's avatars hand", then "you can keep the original scale"
  - build camera: "fix the user still not able to turn the build mode camera when holding right click and moving their mouse around or on mobile pinching with 2 fingers"
- Round 11 (2026-11-05):
  - "the starter hotel is supposed to be the users first hotel so it shouldn't be that good"
  - didn't want the "welcome back your hotel was just as u left it" notification
  - hates the loud level-up song: "change the loud music whenever you level up, buy a new plot, or all that stuff", and when both played: "make it so only the new ones play"
  - "make all of the minigames 3d"
  - "add a drag feature for building walls and windows and stuff quickly"
- Round 10e (2026-11-04), from their long list:
  - "make research take more time, make staff a lot more expensive", "make it harder to level up", "you get too much money for leveling up"
  - starter reviews "really shouldnt be that high it should be around 2 stars"
  - "make it so the user still has to do some stuff that the staff can't do so the game doesnt get boring and isnt just afk stuff"
  - staff should "start out taking a long time at their job but they can gain xp to level up but it takes a little while"
  - disliked "the loud music whenever you level up"
  - instead of action bubbles, "make them say i should ___ or i should start ____ or sometimes they won't say anything at all"
  - Do Not Disturb: "if it happens rarely dont change it make it just right"
  - gamepass UI "but dont make them actually cost anything or do anything just yet"
  - "remake what an empty plot looks like and make it a lot better"
- "reduce the customers who get in line for your hotel when your hotel level is low cuz its too high and you get too many customers way too fast, fix the customers faces"
- Round 10d: "make it so in build mode instead of buying new rooms you can make rooms by using walls and doors to make a room and you can buy more plots for more land do this quickly"
- "optimize the game a lot, also fix the menu bar on the left being too high and not centered on screen, also add cash to leaderstats"
- 2026-11-12, on what to do next: "animations. the last thing will always be optimizations" (so optimising comes after everything else on the list)
- Asked for: "an npc system that can walk has different outfits and names and can interact with the stuff in the room"
- "each room will start off with a bed, a shower, and a toilet"
- "after the customer checks out you will have to clean the room"
- "just add 3 rooms to start with"; build mode comes later.
- Wanted the look of the reference screenshots (bright cartoony hotel).
- Round 9 (2026-11-02): "i asked roblox's ai to make some changes but they are kinda bad". Wanted:
  - "remake all of the ui to be a lot better and have a lot more animations" and a better main menu
  - build mode with "toggle roof, grid snapping, advanced placement, blocks and shapes for custom decor, custom sizing"
  - "a bunch of npcs on the sidewalk", walking "from the start of the sidewalk to the end"
  - traffic and cars, better lighting and a better day/night cycle
  - NPC events ("an all night stay, accessibility needs, baby room") and a research menu
  - "probably remodel everything it looks very low quality"
- Disliked: the lobby being "very bright" and "the lighting staying on the screen forever".
- 2026-11-03: "the game name is being changed from Run a hotel to Overbooked".
- Round 10 (2026-11-03):
  - The cleaning minigames were "not working and are impossible to finish". Wanted them "a lot more fun and higher quality".
  - "everything is too cluttered in the lobby". For the reception desk: "just make it a chair, monitor, and a desk".
  - NPCs "always first check out the lobby, go to their room... its always the same thing and they dont feel alive".
  - Wanted the queue fixed: guests "shuffle a little bit" and "some npcs face the wrong way".
  - "add weather and make the weather effect how npcs react". Also "the more you play the less npcs are on the sidewalks".
  - "fix the collision for stuff outside like the trees ... for the player too".
  - "add full ps5/xbox support to the game and full mobile support".
  - "add a LOT LOT more content, increase quality a LOT LOT".
  - How they work: "try saying nothing when generating things but do make the plan". Also "try working faster".
- Round 8: "is there co-op support, if not add it and also add own hotel plots".
- Round 7: "Room upgrades".
- Round 6: "Staff".
- Round 5: "Sounds".
- Round 4: "Yes, add saving" (so cash, furniture and bought rooms persist between sessions).
- Round 3: "Yes, new rooms".
- Round 2: picked "Build mode" ("Next add build mode so I can place and buy furniture and new rooms").

### What you must do yourself
- Round 30: the place is saved for you (version 345). Watch a guest check in, shower and go to bed, and tell me if any reach looks off.
- Round 31: saved for you (version 346). Nothing to check unless the roof stops hiding while you build.
- Round 32: saved for you (version 349). Check: a night walk down the street, build mode at night, a long chat line's sound, and how guests walk now.
- Round 33: saved for you (version 354). Check: in build mode click a room's name card and type a new number (Enter); cycle a room's floor and the lobby floor/roof on the cards; draw a room against an existing wall; click a cut-away wall to move it.
- Round 34: saved for you (version 359). Check: main menu and loading screen, a full day to see the day summary, talk to a guest, the Upgrades page (U), and on a phone the RUN button next to jump.
- Round 35: saved for you (version 363). Check: start a new save file to clean up the mess (first tutorial step); in Studio set ReplicatedStorage.Shared attribute TestEvent to festival, cruise, conference, surf, heatwave, storm or inspector to see an event; the yellow sign by a dirty room's door; the smaller safe.
- Round 36: saved for you (version 366). Check: wait for (or in Studio run `require(game.ServerStorage.Mess).lost(workspace.Plots.Hotel3)`) a lost item, pick it up and give it back to its owner; a hired janitor walks to a lobby spill and mops it; buy Doormats on the Upgrades page; listen to guests during an event day.
- Round 37: saved for you (version 368). Check: type /eventbackpacker, /eventfitness, /eventgamer or /eventspa and watch that guest's look and what they ask for (place a treadmill, a game, a bath or hot tub, or a snack machine to make them happy); the level road shows "Backpacker guests" at level 3, "Fitness fan guests" at 4, "Gamer guests" at 5 and "Spa lover guests" at 7.
- Round 38: saved for you (version 371). Check: the goals card on the right now shows ODD JOB cards under the chapter (finish one and a new one slides in); type /dog and catch the dog; type /seagull and shoo it three times; let a guest leave happy and walk over the coins by the desk; the Awards page has Odd Job Hero, Lost and Found, Critter Catcher, Tip Collector and Tidy Lobby.
- Round 39: saved for you (version 374). Check: open Awards (Y) and tap a WEAR TAG chip; the tag shows over your head and in front of your chat messages. Let a guest check out and look at the room: the bed, shower, toilet and floor get stains, flies and green stink until each job is cleaned. In a minigame, a gold $ coin sometimes spins in: tap it. Get three stars twice in a row for a HOT STREAK; the result card shows your best time.
- Round 40: saved for you (version 382). Check: play each job (clean a room's bed, shower, toilet and floor, check a guest in and out, cook an order, fix a leak and a fuse box) and say which steps feel too easy or too fiddly. With a friend in the server, watch their character scrub, make the bed or fix while they play. Open any page (U, T, R) to see the new buttons and panels. In Studio, set your player attribute MGSurprise to "lost" or "bug" to force a surprise step (first step), or "off" to stop them.
- Round 41: saved for you (version 390). Check: on the title screen press a save's bin (it turns red), press it again to delete. Start a new save with the tutorial: no chapter card, buttons appear as the steps reach them, no guests until it says to wait for one, and the cleaning step is a pick-up game. Hotel page (H): flip Open / Closed. Build mode (B): the new bottom bar, the LOBBY FLOOR / ROOM FLOORS / ROOF STYLE chips and the floor tiles in the catalog; draw a room against existing walls and check it lines up. Walk the hotel at night and listen to doors and footsteps.
- Round 42: saved for you (version 395). Check: press B. Try each tool on the left (keys 1-6): click things to select, Shift+click for more, drag a box with Box, click or sweep with Delete then press Z, Paint a block, Pick something to get another. With several selected: Move (M), Turn (R), Copy (C), All alike, Sell. Pick a sofa, turn on Hug walls and slide it along a wall; type exact numbers in the Placement panel; use the arrows to nudge. Open Build > Styles for floors and the roof, and the View button for roof / walls / room colours.
- Round 43: saved for you (version 397). Check: press B and put something on the lawn behind or beside the hotel; scroll the camera back to the new hedge; the blue grid covers the plot (turn Grid off in Placement to hide it). Buying more land hands back anything standing where the new wing goes.
- Round 44: saved for you (version 398). Check: the hotel card bottom-left and the tool rail on the left in build mode (B).
- Round 45: saved for you (version 399). Check: press B, click something (selection bar + Placement panel), open View and Paint, hold an item (place bar).
- Round 21: the place is saved for you. Please look at the game at night and tell me if it's dark enough now.
- Round 20: the place is saved for you. Things only you can judge:
  - Start a **new save** to see the run-down hotel and the intro story as a new player would (or type `/intro` and `/look 0`).
  - Furniture: tell me any item that faces the wrong way or looks off. I checked a sample, not all 100.
- Round 16b: nothing to save by hand, the place was saved for you. Have a look at the street at night and tell me if the windows light up.
- **Save the place** (Ctrl+S / File > Save to Roblox). Round 16 changed Faces, Looks, Bodies, StaffLook, NPCAnim, Speech and VoiceFX.
- Round 16 not checked: how the new beep voices sound (I can't hear them). Tell me if they're too loud, too clear or too robotic.
- **Save the place** (Ctrl+S / File > Save to Roblox). Round 15 changed most scripts and added the Cutscene script, new luggage and staff tool models.
- Round 15 not checked:
  - The new mix and layered sounds (I can't hear them).
  - The grade-up orbit cutscene (no grade-up happened in my tests; the star guest cutscene was tested).
  - A star guest staying all the way to checkout and leaving the gift.
- **Save the place** (Ctrl+S / File > Save to Roblox). Rounds 14b to 14e swapped 12 furniture models, added the NPCGait module and changed the Phone, Crowds, NPCAnim and ResearchUI scripts.
- Round 14b not checked: the floor lamp at night (the shade looks a bit grey in daylight shots), and placed copies of the old palm/table/lamp in saved hotels (new ones use the new models).
- **Save the place** (Ctrl+S / File > Save to Roblox). Round 14 changed many scripts, added the Hiring module and the FX script, and turned off shadows on small parts.
- Round 14 not checked:
  - Every new sound (door creaks, handle, rain patter, new music). They're licensed library sounds, but I can't hear them.
  - The umbrella opening and folding up close (my test didn't catch a walker with one in view).
  - The /preset staff room on a fresh hotel: my test hotel already had one, so it was skipped. A dry run showed the walls fit in two lobby corners.
- **Save the place** (Ctrl+S / File > Save to Roblox). Round 13 changed 13 scripts, added RAH.StaffLook and RAH_StaffEdit, and added 3 door models.
- Round 13 not checked by eye: Studio's 3D view is still blank in every capture, so I couldn't screenshot the new uniforms, the doors or the wardrobe's turning preview. I checked them with code (every staff member is dressed, edits save and re-dress them live). Have a look in game and tell me what to change.
- Your staff now have saved looks. Old research stays done; the new branches start from zero.
- **Save the place** (Ctrl+S / File > Save to Roblox). Round 12 changed lots of scripts and added 26 items to the place.
- Round 12 not checked:
  - The phone layout and two-finger turning. Studio can't fake a phone.
  - Friends turning up as guests (needs real Roblox friends).
  - The new talk replies, beyond the code.
  - The world in my last screenshots. Studio's 3D view went blank for every capture, even in Edit, so I checked placement and seats with code (5 new items placed, the bench's three seats work).
- Your save is back at level 9, $13,657 (my tests placed items and paid wages).
- **Save the place** (Ctrl+S / File > Save to Roblox). Round 11 changed the scripts and the starter hotel.
- Round 11 not checked:
  - The new chime and minigame sounds (they load, but I can't hear them).
  - The handyman fixing things by himself, and carrying a bag all the way to a room.
  - Handing a lost item in at the desk.
  - Floating labels (Studio's screenshots skip them).
- Your save is back at level 9, $13,657 (my tests had pushed it up).
- **Save the place** (Ctrl+S / File > Save to Roblox). Round 10e changed the starter hotel, the empty plots and lots of models in the place itself.
- Round 10e not checked:
  - Visit and Ask to join need two real players (Studio's solo test has one).
  - Couples sharing a bed: the code is in, but no couple got a double room in my tests.
  - The new music and stings. They load, but I can't hear them.
  - The walk glitch and queue zigzag: I couldn't make either happen. The queue already walks in a straight line, so I left it alone. Tell me if you still see it and where.
  - Phone sprint button and HUD spacing on a real phone.
- Your save is back at level 9, $13,657 (my tests paid wages, so I put it back).
- Round 10d not checked: removing a wall from a room someone is staying in (the room waits until they leave). I tested making a room, furnishing it and a guest staying in it.
- Round 10d: the performance changes help most on real phones and low-end PCs. Studio's own fps jumps around too much to measure them.
- **Save the place** (Ctrl+S / File > Save to Roblox) so rounds 1 to 10 are kept.
- Round 10 not checked:
  - A real controller. Studio can't fake one, so I checked the code and made sure mouse and keyboard still work. Plug in a PS5 or Xbox pad and try build mode, the menu and a minigame.
  - A real phone. The touch controls were already there; the new bits are hidden key hints and the left buttons staying above the thumbstick.
  - The rain, thunder and cooking sounds. They load, but I can't hear them.
- **Rename the experience and the place to Overbooked** on the Creator Hub (Experience > Configure > Basic Info). None of my tools can change the published name.
- **Set Max Players to 5** (Game Settings > Places, or on the Creator Hub). There are 5 hotel plots, so a bigger server would put the extra people in as helpers.
- Saving needs **Game Settings > Security > Enable Studio Access to API Services** turned on to work in Studio (it's on now). In a published game it works by itself.
- I wiped my test save, so your next play starts fresh at $300.
- Round 2 not checked: phone controls for build mode (drag/pinch/tap), and the room price labels in build mode (Studio's screenshots skip floating labels).
- Sounds: I checked every sound loads and fires at the right moment in a playtest, but I can't hear them. Tell me if any are too loud, too quiet or just wrong.
- Round 8 not checked: a real invite between two people. Studio's test only gives me one player, so I tested with a fake second hotel and a fake invite card. Try it with a friend in a published game (or Studio's Test > 2 Players) and tell me if anything's off.
- Round 9 not checked:
  - The new city sounds and title-screen sounds. They load and play, but I can't hear them.
  - The full stays of the pet, baby, accessibility, all-nighter, business, honeymoon and celebrity guests. I saw them arrive with their looks and badges, queue and get let in. My test hotel only had 3 rooms, though, so none of them reached a room. Birthday, sick, tour and inspector were tested all the way through.
  - The new UI on a phone screen.
- Not checked: the round prompt buttons don't show in my screenshots (Studio's capture skips them), though I tested pressing all of them.

### Changelog
- **2026-11-13 (round 40): every minigame rebuilt, new icons, a new look.** All 85 interface icons were re-rendered in the build-mode hammer's style, and the broken-electrics icon is now a proper spark. The eight jobs are new multi-step 3D games: Floor (bin the litter with a flick, vacuum the dust, straighten the rug), Bed (strip, laundry, throw the sheet on the beat, fluff, duvet, a mint), Shower (scrub mildew, rinse, squeegee), Toilet (lid, scrub, plunge on the beat, flush, fresh roll), Check In (find the right booking, pick the key, swipe it, hand it over), Check Out (take the cash, count the change, tear the receipt), Cook (pick, chop on the lines, keep the heat in the green and flip, plate, ring the bell) and Repair (a leaking pipe or a fuse box, each with its own steps). A step chip shows where you are. The yellow glove is slimmer, holds the tool properly and follows your mouse all the time. While you play, everyone sees your character scrubbing, making the bed, wiping, fixing, cooking or typing. About one job in three has a surprise: a guest's lost teddy, watch, phone or sunglasses to drop in the lost & found box, or a beetle to shoo; that time doesn't count against your stars. Buttons are now raised with a soft gloss, and panels have a tinted header and coloured rim. Star times were raised for the longer games.
- **2026-11-13 (round 39): tags, grime and better minigames.** Every achievement now unlocks a tag when you claim its first tier (Doorman, Desk Ace, Neat Freak, Tycoon, Pet Whisperer and 12 more). Wear one from the Awards page: it shows as a bronze, silver or gold pill over your name and in front of your name in chat. Your first tag goes on by itself. Dirty rooms now look dirty: stains on the bed, the shower glass, the toilet and the floor, a buzz of flies, and a green whiff over the bed and toilet; each one clears as you clean that job. Minigames: a bonus coin sometimes spins in for a few seconds (tap it for $20 + $3 per hotel level), three stars in a row starts a hot streak that pays $10 per step from x2 (up to $100), and the result card shows your best time for that game, or NEW BEST.
- **2026-11-13 (round 38): always something to do.** Odd jobs: three side goals sit under your chapter goals (check in guests, clean rooms, return a lost item, pick up tips, catch a runaway animal and more). Finish one and it pays cash and XP, and a new one takes its place, so the goals never run out, even after the last chapter. New lobby moments: a dog slips its lead and runs round the lobby (chase it and catch it), and a seagull flies in looking for chips (shoo it three times). Happy guests now leave a tip on the floor by the desk; walk over it to grab it. Five new achievements: Odd Job Hero, Lost and Found, Critter Catcher, Tip Collector and Tidy Lobby. Spills and lost items no longer land on sofas or armchairs.
- **2026-11-13 (round 37): new kinds of guest.** Four new special guests come as your hotel levels up. Backpackers (level 3, bucket hat and a map) want a snack machine. Fitness fans (level 4, headband, wristbands and a towel) want a treadmill. Gamers (level 5, glowing headphones and a hoodie) want something to play. Spa lovers (level 7, a robe and a towel turban) want a bathtub or hot tub. Give them what they want and they pay more; if you can't, they pay a little less. Also fixed two greetings that sounded like the guest was calling their own name, and the grandma voice saying "You?, dear."
- **2026-11-12 (round 36): little stories in the lobby.** Now and then a guest loses something in the lobby (a teddy bear, wallet, phone, sunglasses or sun hat) and asks around for it. Pick it up, find the owner and hand it back for a $50 reward. Janitors now walk over and mop up spills on their own. New upgrade: Doormats (15% fewer spills a level). Guests talk about where they are (their room, the street, the line) and about the day's event (the festival, the cruise ship, the storm...). Sleeping guests just say Zzz. Staff no longer think "I should start chatting with Ines" mid-chat, and nobody repeats the line someone just said.
- **2026-11-12 (round 35): more to do.** A new hotel starts with Aunt Marigold's mess all over the lobby (bags, dust, papers, planks, puddles): the tutorial's first job is cleaning it up, $15 a pile. From day 3, some days bring a world event: Harbour Festival, Cruise Ship in Port, Business Conference, Surf Contest, Heatwave, Big Storm or Inspector in Town. Each changes how many guests come and what rooms fetch, and a storm or heatwave sets the weather. A banner drops in, then folds into a pill under the clock. The street fills up on busy days. During the day guests now and then spill a drink or drop litter in the lobby; clean it for $15. Dirty rooms get a yellow 3D A-frame sign by the door instead of a floating tag. The safe is smaller. Fewer bulky coats over flat trousers. The star-guest cutscene camera swings round to a clear angle instead of ending inside the guest.
- **2026-11-12 (round 34): the UI remake.** Everything now follows the chapter goals' look: white glossy plates, a soft rim, 3D icons and a blue small-caps label over a dark title. The old glossy bottom tray with 3D icons is back. Money and guests sit at the very top on white plates with 3D icons. Toasts are white cards with an accent stripe, a 3D icon and a timer bar. The day summary shows the day's profit counting up, a line per figure (in green, out in red), your rating and what tomorrow brings. New loading screen (sky, sun, sea, sand, a progress bar with a percent) and a white main-menu panel. The talk box shows the speaker's 3D icon (your headshot when you speak) over its edge, and every reply is a white plate with a coloured key and a 3D icon (topics get a stripe). The tutorial card and the Upgrades page match (3D icon per upgrade, LV pills); Room floors left the Upgrades page because build mode picks them per room. The menu window no longer fills the screen. Phones get a RUN button that looks like Roblox's own touch buttons.
- **2026-11-12 (round 30): guests use the real things.** Their hands now land on what they use, like the staff since round 27.
- **2026-11-12 (round 31): first optimisation pass.** Client scripts profiled (about 7 ms a frame before). Traffic cars lost 174 invisible pre-20b parts that were still moved every frame (Traffic 0.60 to 0.24 s per 6 s, BulkMoveTo 0.40 to 0.16). Roof no longer counts its descendants every frame. NPCAnim skips joint reads for far NPCs it already handed back.
- **2026-11-12 (round 33): build mode.** The catalogue slides in from the right. Rooms show numbers 101, 102, 103... in the order they appear and you can rename one by clicking its card in build mode (the door plate follows). The Room Builder reuses walls that are already there. Cut-away walls can be clicked to edit them when nothing is behind. Each room's card picks its own floor; the lobby card picks the lobby floor and the roof.
- **2026-11-12 (round 32): first batch of the big request.** Street lamps now light the street (their SpotLight sat at the ground inside the lamp base); nights are brighter; build mode lifts the light at night; turning with right-drag and scrolling zooms from the centre; NPC bubbles are bigger, start with a capital and colour + underline names, rooms and money; guests lost the status disc; the Room Builder only builds walls and a door; the tutorial has no Skip step (finish it or skip it all) and is 15% smaller; a click or tap outside a menu closes it; guests walk on Roblox's Rthro walk at 8 studs/s; long chat lines keep beeping to the end.
  - [x] **Checking in:** both hands on the desk's counter, a finger drum, a look round the lobby.
  - [x] **Checking out:** a bank card slid across the counter and tapped (left hand, so a bag in the right still works).
  - [x] **Bed:** grabs the duvet, folds it back and pats the pillow before lying down.
  - [x] **Shower:** steps in facing the wall, turns the tap on, washes their hair, turns it off.
  - [x] **Toilet:** stands up, turns round and presses the flush (the flush sound plays on the press).
  - Fixed on the way: the desk's guest ledge sticks out past the panel under it, so guests stopped short; their hands now aim mid-ledge and they stand upright.
  - Checked in a playtest on your save: real guests ran every new pose, no errors. A frozen stand-in at a real desk, bed, shower and toilet: hands land on the counter, the duvet, the tap (0.57 studs) and the flush (0.24 studs).
  - Not checked: a whole stay watched start to finish, the shower on camera (the bathroom is too tight to film), touch and controller.
  ![2026-11-12 guest at desk.jpg](Overbooked/media/2026-11-12%20guest%20at%20desk.jpg)
  ![2026-11-12 guest turndown.jpg](Overbooked/media/2026-11-12%20guest%20turndown.jpg)
- **2026-11-12 (round 29): the hotel front, tidied.**
  - [x] **Car park:** the tall white wall on the street side is now a low kerb with a driveway down to the pavement and a P sign. The dirt trench between the car park and the pavement is paved over.
  - [x] **Beside the entrance path:** the lumpy bare ground is paved level with the path. The benches stand on it.
  - [x] **Lawn edges:** the brown soil showing along the grass is grass now.
  - [x] **Guest cars** are scaled down to fit inside a parking bay.
  - [x] **Dark cars:** the two paint colours that showed up nearly black (dark red, navy) are lighter, on the road and parked.
  - Checked in a playtest on your save: the front, both car parks, no errors.
  - Not checked: a guest car in a bay (your hotel has no parking spots), and the other four plots.
  ![2026-11-12 hotel front paved.jpg](Overbooked/media/2026-11-12%20hotel%20front%20paved.jpg)
  ![2026-11-12 car park driveway.jpg](Overbooked/media/2026-11-12%20car%20park%20driveway.jpg)
- **2026-11-12 (round 28): build mode handles like a real builder.**
  - [x] **Drag an item to move it.** Hold the mouse on any item and drag. It comes with the cursor and drops where you let go. If it doesn't fit, it goes back.
  - [x] **Drag the floor to pan.** The floor stays under the cursor. The middle mouse button pans any time, even with something in hand.
  - [x] **Zoom goes toward the cursor** when you scroll in.
  - [x] **See-through walls.** Walls on your side of what you're looking at fade out, from any angle. New WALLS chip on the tool bar (Cut / Full). Clicks pass through faded walls.
  - [x] **Clearer "can't go here".** The thing in the way gets a red outline, and the item shows its floor space under it.
  - [x] **Undo also puts back moves and turns** (Z).
  - [x] The item in hand no longer bobs up and down.
  - Checked in a playtest on a throwaway save (deleted after): drag to move, undo, pan, zoom, blocked drop, leaving build mode. No errors.
  - Not checked: the middle-button pan (my test mouse has no middle button), touch and controller. Drag-to-move is mouse only for now.
  ![2026-11-12 build drag to move.jpg](Overbooked/media/2026-11-12%20build%20drag%20to%20move.jpg)
- **2026-11-12 (round 27): staff really work on things.** Their hands now land on the object they are working on.
  - [x] **The mop is the right way up.** The old fix never found the mop, so it never ran. Now the head stays on the floor, both hands hold the handle and it wipes from side to side.
  - [x] **Beds:** the janitor leans over and smooths the sheet, snaps the edge, tucks it and pats the pillow.
  - [x] **Toilets:** down on bent knees with a toilet brush on the bowl.
  - [x] **Showers:** steps inside and wipes the wall with a cloth and a spray bottle.
  - [x] **Dusting:** a feather duster on the item itself (it used to mop the air).
  - [x] While doing those, the mop stands beside them, then they pick it up again.
  - [x] **Receptionists** type on the real keyboard and reach for the mouse.
  - [x] **Handymen** crouch at the broken thing with one hand on it and the wrench on it. They no longer "mop" with a wrench when idle.
  - [x] **Cooks** hold a pan over the stove and stir it with a spoon.
  - [x] **Doormen** wave the guest in after the welcome.
  - Checked in a playtest on your save: mop, bed, toilet, shower, dusting and the desk all ran with real staff, no errors.
  - Not checked: the cook at a real stove (your hotel has none, so I tested at a desk), a real repair, and the shower wipe up close.
  ![2026-11-12 staff mop.jpg](Overbooked/media/2026-11-12%20staff%20mop.jpg)
  ![2026-11-12 staff bed.jpg](Overbooked/media/2026-11-12%20staff%20bed.jpg)
  ![2026-11-12 staff toilet.jpg](Overbooked/media/2026-11-12%20staff%20toilet.jpg)
- **2026-11-12 (round 26): Research menu laid out new.** Every menu is now remade.
  - [x] **The lab bar** on top: what's running, a thin bar, the time left and Stop. When nothing runs it shows how much is done.
  - [x] **Branches** down the left in three groups, with a count each and a blue dot when something can start.
  - [x] **Steps** in the middle: flat cards from left to right joined by thin lines (blue once done). No more round nodes, glows, grid or gradients.
  - [x] **The project** on the right: what it does, what you get (furniture still turns in 3D), cost, time and Start.
  - Checked in a playtest: started and stopped a project on a throwaway save (money came back), looked at a finished tree on your save. No errors.
  - Not checked: a project finishing while the page is open.
  ![2026-11-12 research menu.jpg](Overbooked/media/2026-11-12%20research%20menu.jpg)
  ![2026-11-12 research menu running.jpg](Overbooked/media/2026-11-12%20research%20menu%20running.jpg)
- **2026-11-12 (round 25): Upgrades menu laid out new.**
  - [x] **The comeback** on top: the hotel's look as five steps (Run-down to Grand) with its own buy button.
  - [x] **Upgrades** in a two-wide grid: a level tile, what it does, a slim level bar, what you get now and next, and the price.
  - [x] **Hotel style** down the right: a swatch grid for the lobby floor, room floors, walls and roof. The one in use has a blue ring and tick.
  - [x] A price you can't afford yet shows on a white button, not a green one.
  - Checked in a playtest on a throwaway save: bought Curb Appeal and Tip Jar, changed walls and roof, no errors.
  - Not changed yet: Research.
  ![2026-11-12 upgrades menu.jpg](Overbooked/media/2026-11-12%20upgrades%20menu.jpg)
- **2026-11-12 (round 24): four menus laid out new.**
  - [x] **Hotel.** Three columns: your hotel (name, rating, level, grade) on the left, the numbers and what unlocks next in the middle, guest reviews on the right.
  - [x] **Staff.** A status line on top. Left: pick a job, then one of the three people who applied. Right: your team, one compact row each.
  - [x] **Achievements.** One line each (tiers, progress, prize). What you can claim comes first. Filters: All, Ready to claim, In progress, Complete.
  - [x] **Settings.** Categories down the left, rows on the right. The key list now includes T, U and /commands.
  - [x] Flat grey cards, thin one-colour bars, no gradients, gold bands or rims. Each menu shows its own icon in the header (it was stuck on the hotel icon).
  - Checked in a playtest: all four open with no errors.
  - Not changed yet: Research and Upgrades (Upgrades was made in round 20/22).
  ![2026-11-12 menu hotel.jpg](Overbooked/media/2026-11-12%20menu%20hotel.jpg)
  ![2026-11-12 menu staff.jpg](Overbooked/media/2026-11-12%20menu%20staff.jpg)
  ![2026-11-12 menu achievements.jpg](Overbooked/media/2026-11-12%20menu%20achievements.jpg)
  ![2026-11-12 menu settings.jpg](Overbooked/media/2026-11-12%20menu%20settings.jpg)
- **2026-11-11 (round 23): build mode, remade.**
  - [x] **Catalog on the left.** A tall white card: search on top, categories down a rail, items in a two-wide grid. It opens at once (pictures load a few at a time).
  - [x] **One dark tool bar at the bottom.** Room Builder, then a chip each for Grid, Turn, Roof, Zones, Wall Snap and Keep Placing (click a chip to step through its choices), then Undo.
  - [x] **Place bar** sits just above it while you hold something: height, Turn, up, down, Place, Cancel.
  - [x] **Selection pill.** Click an item and a small dark pill floats over it: Move, Turn, Copy, Paint, Sell.
  - [x] **Key strip** on top is one slim dark bar.
  - [x] Room Builder panel moved up and trimmed so it no longer covers Undo.
  - Checked in a playtest: open, pick, place, select, Room Builder, categories, leave. No errors.
  - Not changed: how building works (camera, snapping, drag rows, the shape editor panel). Not checked: touch and controller.
  ![2026-11-11 new build mode.jpg](Overbooked/media/2026-11-11%20new%20build%20mode.jpg)
  ![2026-11-11 new build mode room builder.jpg](Overbooked/media/2026-11-11%20new%20build%20mode%20room%20builder.jpg)
- **2026-11-11 (round 22): the hotel starts empty, and you pick its finishes.**
  - [x] **A new save starts empty.** Just the walls, the roof and the front desk. No furniture, no beds. You get $900 to open your first room.
  - [x] **A wider base.** Every new save gets the land on both sides for free, so the lobby is about 130 studs wide instead of 81.
  - [x] **Floor, wall and roof styles.** Bottom of the Upgrades menu (U): 7 lobby floors, 7 room floors, 6 wall colours, 4 roofs. Free, instant, saved with the file.
  - [x] **New default interior.** Sandstone lobby, oak rooms, white walls, terracotta roof.
  - [x] **Tutorial** has two new steps for the empty start: "Open your first room" and "Close build mode".
  - Old save files keep their furniture and rooms. Checked in a playtest: new file, furnish a room, reload, and an old file.
  - Not checked on screen: the two new tutorial steps (they compile; the room check they use works).
  - Still to do from your list: build mode remake, new menu layouts, the optimisation pass, staff animations, more map polish.
  ![2026-11-11 empty hotel start.jpg](Overbooked/media/2026-11-11%20empty%20hotel%20start.jpg)
  ![2026-11-11 hotel style picker.jpg](Overbooked/media/2026-11-11%20hotel%20style%20picker.jpg)
- **2026-11-12 (round 21): a new UI style, and a long list of fixes.**
  - [x] **New look everywhere.** Flat white cards, one blue accent, the Roblox font, no gloss, sparkles or bubbly letters. Violet is gone from every screen.
  - [x] **New HUD.** Dark glass plates: hotel plate, cash, guests. New flat icons (29 drawn from scratch).
  - [x] **A real clock.** A dial with ticks and two hands. It turns navy at night. Inside it: the weather and the digital time. The day and season sit on a tab beside it.
  - [x] **New bottom bar** with an **Upgrades** button (key U).
  - [x] **Menus open on their own.** The tab row inside the menu is gone.
  - [x] **New notifications.** Dark pills drop in under the top bar. Repeats count up (x2) and you can click one away.
  - [x] **New title screen with 3 save files** (continue, new hotel, delete) over a film of the town. New plain loading screen.
  - [x] `/commands` opens a full page of every command.
  - [x] Classic Roblox faces are back.
  - [x] Smaller prompts, name tags and conversation UI. Quieter voices.
  - [x] Darker nights, dimmer street and hotel lamps.
  - [x] New "Needs cleaning" door tag.
  - [x] Map: the red carpet follows the path, parked cars sit on the road, cars are narrower.
  - [x] `/preset`: every room gets a bed, shower and toilet (so the guest count is right), and a restaurant goes in the lobby.
  - [x] Mops and brooms point at the floor whatever the arm does.
  - [ ] **Not done yet:** empty hotel on a new save, a wider base hotel, a new interior, roof and floor customization, a new build mode UI, new layouts inside each menu, an optimisation pass, staff "using objects" animations.
  - Tested in playtests: title screen, save files (new, continue, delete), HUD, upgrades menu, commands page, a new save's intro. Not checked: night lighting, the mop fix on a working janitor, `/preset` after the change.
  - ![2026-11-12 title screen save files.jpg](Overbooked/media/2026-11-12%20title%20screen%20save%20files.jpg)
  - ![2026-11-12 new HUD.jpg](Overbooked/media/2026-11-12%20new%20HUD.jpg)
  - ![2026-11-12 upgrades menu.jpg](Overbooked/media/2026-11-12%20upgrades%20menu.jpg)
  - ![2026-11-12 commands page.jpg](Overbooked/media/2026-11-12%20commands%20page.jpg)
- **2026-11-11 (round 20b): beds, showers and cars remade.**
  - [x] All 6 beds (plus the old messy bed) have new made and unmade models. Checked in a playtest: only one of the two shows at a time.
  - [x] Both showers and the bathtub are new. The showers are open at the front so you can see the guest.
  - [x] All 7 vehicles are new (sedan, hatchback, SUV, taxi, van, pickup, bus) and still get random colours. Their wheels no longer spin.
  - [x] Also new: the room safe, the TV (it has a screen now) and the street hydrant.
  - [ ] Still old: walls and doors, wall and ceiling items, the reception desk, street lamps, traffic lights, bus stops, the mailbox (its upload failed).
  - ![2026-11-11 new beds.jpg](Overbooked/media/2026-11-11%20new%20beds.jpg)
  - ![2026-11-11 new cars.jpg](Overbooked/media/2026-11-11%20new%20cars.jpg)
  - ![2026-11-11 new room in game.jpg](Overbooked/media/2026-11-11%20new%20room%20in%20game.jpg)
- **2026-11-11 (round 20): a brand-new seaside town, a hotel with a story, upgrades.**
  - [x] **New city.** The shops and towers are gone. Across the road is now a stone promenade with palms, globe lamps, a beach cafe, an ice cream kiosk, a surf shack and bandstands. Steps lead down to a sand beach with parasols, lifeguard towers and rowing boats. Then the sea: a long pier, sailboats, yachts, a lighthouse and far islands. The road has a planted median with small palms.
  - [x] **New hotel look.** White stucco, terracotta tiles and teal, instead of brick and emerald.
  - [x] **The hotel starts run-down.** Grey cracked walls, boarded windows, weeds, bin bags. It gets better in 5 steps: Run-down, Patched up, Fresh paint, Charming (flowers and palms), Grand (lamps and a red carpet). Higher hotel grades lift it too.
  - [x] **Upgrades tab** in the menu, 8 upgrades bought with cash: Curb Appeal (the look), Billboard Ads (guests arrive faster), Better Rates (more income), Tip Jar, Comfy Lobby, Staff Training, Smart Payroll, Welcome Gifts.
  - [x] **Story.** You inherit the old Seabreeze Hotel from Great-aunt Marigold. First-time players get a 25 second intro (four shots with title cards), then the tutorial. Curb Appeal levels add story lines.
  - [x] **About 100 furniture models remade** as textured models (sofas, lamps, games, kitchen, plants and more).
  - [x] **Test commands** (admin): `/seasonspr` `/seasonsum` `/seasonal` (fall) `/seasonwin` `/seasonauto`, `/weatherclear` `/weathercloud` `/weatherfog` `/weatherrain` `/weatherstorm` `/weathersnow`, `/event<name>` (e.g. `/eventpet`, `/eventroyal`), `/intro`, `/look 0-4`, `/upgrades`, `/commands`.
  - [ ] Not remade: beds, showers, bathtub, walls and doors, wall and ceiling items, the reception desk, cars, street lamps, traffic lights, bus stops.
  - Tested in a playtest: the upgrade purchase, the run-down look, the intro cutscene, no script errors.
  - ![2026-11-11 seaside promenade.jpg](Overbooked/media/2026-11-11%20seaside%20promenade.jpg)
  - ![2026-11-11 seaside pier.jpg](Overbooked/media/2026-11-11%20seaside%20pier.jpg)
  - ![2026-11-11 resort hotel.jpg](Overbooked/media/2026-11-11%20resort%20hotel.jpg)
  - ![2026-11-11 intro run-down hotel.jpg](Overbooked/media/2026-11-11%20intro%20run-down%20hotel.jpg)
  - ![2026-11-11 new furniture.jpg](Overbooked/media/2026-11-11%20new%20furniture.jpg)
- **2026-11-10 (round 16b): the city is remade.**
  - [x] Every shop building is rebuilt from modelled pieces: 5 window styles (stone surrounds, arches, shutters with flower boxes, wide steel windows, iron balconies), cornices, piers, shop windows, doors and scalloped awnings.
  - [x] New textures made from scratch: brick, stucco, cut stone, asphalt, pavers, roof gravel, glass towers, leaves and bark. Roads, sidewalks, curbs, tunnels and garden paths use them.
  - [x] New trees and hedges with bark and leaf textures. New water tanks and air units on the roofs.
  - [x] The skyline is stepped glass towers now, not plain boxes.
  - [x] Grass no longer pokes through the sidewalks.
  - [ ] Not remade yet: the furniture (about 140 items), cars, street furniture (lamps, benches, bins), the hotel building itself and the hills.
  - Tested in a playtest (about 35 fps in Studio). Night lighting on the new windows wasn't checked (the test ran in the morning).
  - Before: ![2026-11-10 old city street.jpg](Overbooked/media/2026-11-10%20old%20city%20street.jpg)
  - After: ![2026-11-10 new city overview.jpg](Overbooked/media/2026-11-10%20new%20city%20overview.jpg)
  - ![2026-11-10 new city street.jpg](Overbooked/media/2026-11-10%20new%20city%20street.jpg)
  - ![2026-11-10 new skyline.jpg](Overbooked/media/2026-11-10%20new%20skyline.jpg)
- **2026-11-10 (round 16):**
  - [x] Faces redrawn. Women and men now have their own eyes (4 styles each), and kids and elders get their own looks too. Every style has 11 moods.
  - [x] Brows and beards take the hair colour. Men can grow stubble, a moustache, a goatee, a beard or a handlebar. Some faces get freckles, moles, wrinkles or rosy cheeks, and there are 3 noses. Women get soft rose lips.
  - [x] Gender follows the name, and hair follows the gender.
  - [x] Chat voice remade. Each line is synth beeps and boops (one per syllable, and the vowel picks the note). Under them sit the words, muffled and robotic, so they're only just readable.
  - Tested in a playtest lineup (screenshots: `2026-11-10 new faces 1/2/elders.jpg`). I fixed a voice bug the test found. **I can't hear sound, so give the voices a listen.**
  - ![2026-11-10 new faces 1.jpg](Overbooked/media/2026-11-10%20new%20faces%201.jpg)
  - ![2026-11-10 new faces elders.jpg](Overbooked/media/2026-11-10%20new%20faces%20elders.jpg)
- **2026-11-10 (round 15b):** staff wear modelled coats, jackets, aprons and hats (hair is hidden under hats so it doesn't poke through). The floor game gets a compost bin.
- **2026-11-10 (round 15):**
  - Everything remade for quality: UI, talks, menus, loading, build mode, plots, hotel and map.
  - New: 8 bags and cases, guest outfits, wide faces fixed, staff tools.
  - New: star guests and cutscenes, minigame star clock, roomier research trees, sound mix.
  - Tested in playtests: the star cutscene, the outfits, the backpack, the star clock and the research page (screenshots above).
- **2026-11-09 (round 14e):** NPCs walk and idle with a smooth hand-made gait, with a walk style per personality.
- **2026-11-09 (round 14d):** new deluxe and suite beds, deluxe toilet, rain shower and vanity.
- **2026-11-09 (round 14c):** new armchair, sofa, wardrobe and bookshelf.
- **2026-11-09 (round 14b):** new palm, coffee table and floor lamp; umbrellas in the hand; street walkers animate near you; phone and research text fixed.
- **2026-11-09 (round 14):**
  - New paper-and-walnut style: title screen, loading screen, goal cards, tutorial card, door replies.
  - Hiring with candidates, skills and lasting pros and cons; staff room unlocked from level 1.
  - 6 new voices and many more lines.
  - Minigame arm and glove, stronger grime, the real guest at check-in.
  - Tutorial: a full staff room check and a hiring step.
  - Door, music and rain sound variety; random sound versions.
  - Rain layers, wind gusts, mist, animated umbrellas.
  - New effects for pay, cleaning, building, selling, upgrades and hires.
  - Performance: about 3,400 small parts stop casting shadows, simple collision on 316 decorations.
  - /preset builds a walled staff room and a 5-star team.
  - Tested in a playtest: the tutorial card, the rain and the effects (screenshots above); /preset reached level 30 with 16 staff and their profiles.
- **2026-11-06 (round 13):**
  - Room doors (Room, Modern, Suite) in build mode.
  - Slower base staff: the doorman walks out and greets each guest; longer cleaning, desk, cooking and repairs.
  - Part-built uniforms: 4 outfits per role with headwear and extras; a wardrobe to customise each staff member, saved for good.
  - Jobs: janitor rooms, a focus per role, day and night shifts (40% cheaper).
  - Research: 38 new projects in 5 new branches (72 in all), and the tree scrolls.
  - Tested in a playtest:
    - all 5 staff dressed from their saved looks
    - renaming and restyling the doorman from the wardrobe changed him live
    - assigning a janitor rooms 101 and 102 on the day shift saved and lowered the wage bill ($250 to $232)
    - the doorman let one guest in about every 10 seconds
    - all research requirements point at real projects
  - Your save is put back.
- **2026-11-05 (round 12b):** Build tabs scroll (with edge arrows). Walls can butt into the hotel's walls and the starter rooms, and cross the hallway without blocking a room door.
  - Tested in a playtest:
    - built a room against the starter rooms' fronts with 10 walls and a door, and it became Room 201
    - a wall in front of a room door is refused
    - scrolled the tabs to Outdoor
  - Not checked: on a real phone. Your save is put back.
- **2026-11-05 (round 12):**
  - Sit at the desk to check guests in and out; check-in on the monitor; full-screen minigames with your avatar's own arm.
  - Smaller prompts; the flush button is fixed; shorter cleaning; sitting on chairs and benches; more talk; friends as guests; phone bar fixes; the build camera turns.
  - New 10-step tutorial, loading screen, title screen and settings (now saved).
  - 26 new build items.
  - Tested in playtests:
    - the loading and title screens
    - the tutorial from Replay through sitting at the desk, opening build mode and turning the camera
    - placing a chandelier, dining chair, fountain, bench and neon sign (with seats and lights)
    - all scripts compile
  - Fixed on the way:
    - a loading-screen crash
    - the moon's edge
    - hanging lamps that touched the ceiling and couldn't be placed
    - thick fog at night making build mode too dark
  - Your save is put back.
- **2026-11-05 (round 11):** All 8 minigames remade as 3D scenes. The loud level-up song is gone (one soft chime now). Hotel grades from Roadside Inn to Palace Hotel, with a plain starter hotel. The welcome-back message is gone. Breakdowns and repairs, a handyman, bags to carry, lost and found, VIPs from grade 3. Drag to build whole rows in build mode.
  - Tested in playtests: dragging 3 walls across the lobby and 4 window walls the other way (they turned to follow), and undoing a row with a full refund; every minigame opened in 3D and Bed, Repair, Cook, Check-out, Check-in, Floor and Shower were played to the end; a broken shower with its puddle and Repair prompt; a teddy left on a bed.
  - Fixed on the way: models inside the 3D games sinking or turning sideways, tiny litter and keys, a cut-off monitor and bell, and a test switch that crashed the breakdowns.
  - Your save is put back (level 9, $13,657).
- **2026-11-04 (round 10e):** The big list. Slower research, pricier staff with wages, harder levels, starter reviews near 2 stars, longer stays, 7-minute days. New title, loading screen, BUILD button, phone and gamepass page. Build mode: wall snap, unlocked items first, right-click camera, undo, new walls, doors, windows, beds and fun objects, parking. Staff levels, staff room, idle jobs and talk. Guests stop to talk, say much more, act out what they use, get angry when disturbed, tip, bring luggage and come as couples. Room service and dusty decor as player jobs. Dirty rooms survive a rejoin. New music and stings. Visit and ask to join other hotels; co-op spends the owner's money. A remade starter hotel, sharper bed and rug, new empty plots.
  - Tested in playtests: the hotel starts with no errors, car park and cars, staff levels and talk card, the staff-room message, luggage, a guest playing pinball, dusty decor, tips on the bed, room service from cart to door (+$30), the title and loading screens, build tools.
  - Fixed on the way: a starter-bed bug that stopped the hotel starting, and an error when dirty rooms came back.
  - Your save is put back (level 9, $13,657).
- **2026-11-03 (round 10d, part 2):** Fewer, slower walk-ins at low levels (full pace from level 7). Classic heads, so guest faces no longer warp.
- **2026-11-03 (round 10d):** Rooms are now made with walls and a door. MORE LAND replaces buying rooms. The left menu is centred, cash shows in leaderstats, and the client runs lighter (far lights off, fewer shadows, fewer walkers).
- **2026-11-03 (round 10):** The hotel remake.
  - New guest life, talking and knocking.
  - Door signs, the hand on the knob, fixed cleaning minigames and a reception minigame.
  - New top bar, goals and achievements.
  - The kitchen, weather and day-time crowds.
  - Tree and lamp collisions fixed.
  - Controller and phone support.
  - 12 new build items.
  - Tested in playtests:
    - a guest's whole meal, both with a cook and with me cooking
    - storm and snow on the street, with umbrellas and fewer walkers
    - build mode with the keyboard
    - the new items in the lobby
    - no script errors
  - My test save is put back the way it was.
- **2026-11-03 (round 9, part 2):** Renamed the game to **Overbooked**.
  - New title screen: the camera flies along the street, OVER plus a red BOOKED stamp that slams down, save cards, and tips and settings panels.
  - A new HUD and a new Menu (Hotel, Staff, Co-op, Stats, Settings) in the round 9 style, and an end-of-day card.
  - City sounds (day and night mixes) and a brighter marble lobby floor.
  - Removed two hairs whose textures no longer exist.
  - Tested in a playtest: title screen, save cards, Continue into the game, HUD, every Menu tab, the day card, and 5 event guests arriving and queueing, with no script errors. Test cash put back to $300; test staff and research cleared.
- **2026-11-02 (round 9, part 1):** The big remake.
  - Lighting and day/night fixed and rebuilt.
  - The whole city map, traffic and new cars.
  - Crowds walk end to end, with walk-ins and better paths.
  - NPC walk styles and many more looks, and a new lobby.
  - Build mode remake: roof, grid, shapes, wall art, 98 items.
  - Research menu (33 nodes) and 11 guest events.
- **2026-10-30 (round 8):** Own hotels and co-op. 5 plots along the street; each player gets their own hotel with its own guests, staff and saving, and a sign with their name. Co-op button and PLAY TOGETHER panel: invite people, they get a Join card, helpers work in your hotel with their own cash, Send home, My hotel. Other people's hotels can't be built in and their buttons are hidden. Tested in a playtest: my plot worked (guests, HUD, building), a second fake hotel next door had its own guests, I moved in as a helper and placed a plant, bought Room 104 and upgraded Room 101 there, my own hotel refused building while I was away, My hotel brought me back with a clean HUD, the invite card showed, no script errors. Test save wiped again.
- **2026-10-29 (round 7):** Room upgrades. Every room can go Standard → Deluxe ($500, +$25 a stay) → Suite ($1,400, +$60 a stay), with new decor at each step (wall panels, padded feature wall, wall lamps, darker floor, bed throw; Suite adds emerald and gold, crown moulding and a marble bathroom). Rooms have 1-5 stars shown on a sign over the door, and the hotel's average rating is shown under its name. A better rating brings guests sooner. Upgrade cards in the Rooms tab, upgrades saved. Tested in a playtest: upgraded through the remote and through the real card (two clicks, cash taken, toast shown), a 4th upgrade is refused, stars and prices updated, upgrades came back after a restart, no script errors. Test save wiped again.
- **2026-10-29 (round 6):** Staff. A Staff tab in build mode with janitors (up to 3, $350 / $750 / $1,200) who walk to dirty rooms and clean all 4 jobs with a mop, and a doorman ($600) who lets guests in when a room is clean. Uniforms, a mop and a doorman cap, name and role labels, new icons. Staff are saved. Tested in a playtest: hired through the real card (two clicks, cash taken), a janitor cleaned Room 101 alone in 20 s, the doorman let guests in, staff came back after a restart, a 4th doorman is refused, no script errors. Test save wiped again.
- **2026-10-29 (round 5):** Sounds and music. Lounge music playlist (M to mute), 3D sounds for the door, desk bell, shower (loops while the water runs), flush, coins, register and all 4 cleaning jobs, dings for ready/dirty rooms and errors, build mode whooshes, thuds, sell register, hammering plus a fanfare when a room is built, and soft button clicks. Tested in a playtest: every sound loaded and played at the right moment (place, sell, let in, check-in, shower, flush, pay, 4 cleaning jobs, room ready, collect, room built, error, build open/close); no script errors. Test save wiped again.
- **2026-10-29 (round 4):** Saving. Cash, totals, bought rooms and all furniture (spot and facing) are saved when you leave, every minute, and a few seconds after you build. Rejoining rebuilds your rooms and puts the furniture back, with a "Welcome back" toast. Fixed the cash counter stopping partway. Tested in playtests: built Room 104, sold a plant and placed a sofa, stopped, started again: $4,395, Room 104 (Ready), the lot for 105 and the sofa all came back; no script errors.
- **2026-10-29 (round 3):** Buy new rooms. A fenced for-sale lot with a price sign, a Rooms tab and a NEW card in the shop (click twice to buy), and a new wing that rises out of the ground with confetti: a furnished room plus more lobby, glass front, carpet, paving and hedges. Four more rooms, alternating right and left ($400, $800, $1,500, $2,400). Tested in a playtest: bought 104 through the card, a guest showered, used the toilet and slept there, all 4 cleaning jobs worked, 105 built on the left, buying out of order is refused, no script errors.
- **2026-10-29 (round 2):** Build mode. Free camera over the hotel, a shop with 14 items in 4 tabs (8 new Blender models), a ghost that snaps, turns and glows green or red with the reason, no-build zones, and a card to move, turn or sell (75% back) anything you click. The bed, shower and toilet can move inside their room, and guests, cleaning spots and shower water follow them. Appeal raises room prices ($40 + $3 per point) and lobby appeal makes guests more patient and come more often. Start cash is $300. Tested in a playtest: bought, turned, moved and sold through the real buttons; every placement rule refused the right things; a guest slept in a moved bed; no script errors.
- **2026-10-29 (round 1):** The whole first version. Hotel building with lobby, reception and Ben the receptionist, 3 furnished rooms, 15 custom Blender models, guests with random looks who walk in, check in, use the toilet, shower and bed, pay and leave, dirty rooms you clean with 4 jobs, the front door Let In button with patience, the cash pile, HUD, toasts and hand-drawn icons. Tested in a playtest: 3 guests went through the full loop, cleaning and collecting $145 worked, no script errors.


---

## Overbooked - Architecture (was Run a Hotel)

Back to **Run a Hotel**

Studio place "Run a Hotel", placeId 75953879612667. Get the `studio_id` from `list_roblox_studios` (it changes every Studio launch).

### Pipelines
| Thing | Where |
|---|---|
| Props | `Run a Hotel tools/rah_props.py` (headless Blender: `blender -b --factory-startup -P rah_props.py -- Bed Shower --render`). Each prop is built round its floor centre (1 m = 1 stud, -Y = front = Roblox +Z), painted per piece, AO baked into vertex colours, split into groups `main / chrome / glass / glow`. Writes `export/<Prop>_<group>.json` + `<Prop>.manifest.json` + `_render_<Prop>.png`. Several can run in parallel. |
| Upload | Serve `export/` with `python -m http.server 8790`. `ServerStorage.DevTools.MeshImporter.prop("Bed")` uploads every group (EditableMesh → CreateAssetAsync) into `ServerStorage.HotelProps.Bed` (Model, pivot = floor centre; parts `Body`, `Chrome`, `Glass`, `Glow` with materials from `MeshImporter.LOOKS`). |
| Scripts | Mirrors in `Run a Hotel tools/src/` served with `python -m http.server 8791 --directory src`; push by setting `.Source` from `HttpService:GetAsync` in `execute_luau`. |
| World | `src/HotelBuilder.lua` (copy in `DevTools.HotelBuilder`): `loadstring(GetAsync(".../HotelBuilder.lua"))().build()` rebuilds `Workspace.Hotel`, `Workspace.Outside`, terrain, spawn and lighting. **Rebuilding wipes the hotel**; scripts read everything by name, so keep names. |
| Icons | `Run a Hotel tools/ui_icons.py` (Pillow) → `ui/*.png`, served on 8792 for `upload_image`. Ids in `RAH.Config.ICONS`. |

Props: Bed, BedMessy, Shower, Toilet, Nightstand, Desk, Sofa, CoffeeTable, Plant, FloorLamp, WetSign, CashBundle, Towel, Trash, Rug. Shop props (round 2) live in `rah_props_shop.py`, which `rah_props.py` execs: Armchair, TVStand, Wardrobe, Bookshelf, PingPongTable, VendingMachine, PottedTree, SideTable.

### Workspace
- Floor top is **y = 1**. Hotel x -40..40; lobby z 0..30 (glass front z = 30.2, door gap x -5..5); rooms z -30..-2.
- `Hotel.Shell` walls, floors, carpet, glass front, canopy, `HotelSign` (SurfaceGui `Text`, set to "<NAME>'S HOTEL" by the server).
- `Hotel.Doors.DoorL/DoorR`: attributes `Closed` (CFrame), `Side`. The server slides them 4.6 studs.
- `Hotel.Lobby`: Desk, Backdrop, plants, sofas, `CashStand` (CollectPrompt), `CashPile` (attribute `Origin`, server stacks CashBundle clones, 1 per $20, max 30).
- `Hotel.Nav`: `Street`, `StreetExit`, `PathStart`, `Queue1..6` (attribute `Look`), `Inside`, `DeskGuest`, `DeskGuest2`, `Receptionist`, `DoorPrompt` (LetInPrompt).
- `Hotel.Rooms.Room101..103` (attributes `RoomId`, `State` = Ready / Booked / Dirty, `Guest`, `TasksLeft`):
  - `Props` now only holds the `Painting` (everything else moved to `Hotel.Placed`), `Mess` (Towel, Trash x2, `NeedCleaning` sign; `CanQuery = false` so it never blocks building).
  - Attributes `Appeal`, `Price` (set by RAH_Hotel from the furniture in the room).
  - `Nav`: Door, Enter, Wander are still used. BedSide, BedLie, ShowerIn, ShowerFront, ToiletFront, ToiletSit are **legacy**: guests now use `Catalog.CORE` offsets from the room's core items.
  - `CleanSpots`: Bed, Shower, Toilet, Floor (attributes `Task`, `Label`; each gets a `CleanPrompt` and a `Dust` emitter).
- Terrain is carved to air under the hotel, path and road (grass blades poked through the floors otherwise). Lawn is LeafyGrass.
- `Workspace.Guests`: live guest models.
- **`Hotel.Placed`** (round 2): every movable item. Model named after its item id, pivot = floor centre, attributes `Item`, `Zone` (Lobby / Room101..), `Uid` (8 chars, assigned by RAH_BuildServer). Core items also carry `Core` (Bed / Shower / Toilet) and `Room` (Room10x). The `Bed` item has children `Clean` and `Messy` (Messy never collides).
- **Wings (round 3)**: `Config.ROOM_SLOTS` = `{id, side (1 east / -1 west), k, price}` bought in order. Wing k on side s: interior |x| from `e = 40.5 + 26.5(k-1)` to `o = e + 25.5`, outer wall `o..o+1`, room `cx = s(e + 12.75)`. `HotelBuilder.buildWing(hotel, slot)` destroys that side's `WallRight` / `WallLeft` (+Cap/Base/Brick), builds `Shell.Wing<id>` (Divider, Plinth, LobbyFloor, WallBack, a new `WallRight/Left`, FrontL/R, Lintel, CarpetHall, GlassFront, Painting), carves terrain and adds `Outside.Apron<id>` + planters, adds the `Room<id>` zone + `Doorway<id>` NoBuild, stretches `Lobby` and `Hallway` zones, then `buildRoom` + `convertRoom`. Hotel attributes `MinX`/`MaxX` (interior edges), `NextRoom`, `NextRoomPrice`.
- **`Hotel.ForSale`**: the lot for the next slot (fence, stakes, sign; attributes `RoomId`, `Price`), rebuilt by `HotelBuilder.forSale(hotel)`.
- **`Hotel.BuildZones`**: flat parts `Lobby`, `Room101..103` (an item's footprint must sit in one zone); `NoBuild` parts (Doorway10x, Entrance, Hallway, Reception) with `CanQuery = true` and a `Reason` attribute.
- Hotel attribute `LobbyAppeal`.
- Built by `HotelBuilder.setupBuild()` (= `makeItems` + `makeZones` + `convertPlaced`); `build()` calls it. Running `setupBuild` again resets all furniture to the builder's layout.

### Round 10d (2026-11-03): rooms made with walls, land, performance
- **Land:** `HotelBuilder.buildLand(hotel, slot)` builds an empty wing (`Shell.Wing<id>`, attribute `Land`):
  - floor from z -29.5 to 30, back wall, outer wall and street front
  - a Divider only if a built-in room is next door (otherwise a `LandJoin` floor strip)
  - an extra BuildZones part named **Lobby** with attribute `Land` (z -29.5..-1.5); the main Lobby zone stretches to MinX/MaxX
  - The `room` build action now buys land (same `ROOM_SLOTS`, prices and level gates). `nextSlot` skips slots that have a Wing or a Room.
- **Custom rooms:** `ServerStorage.RAH_Rooms`.
  - `Rooms.scan(hotel, hints?)` works on a 1-stud grid over MinX..MaxX x -29.5..29.6.
    - Blocked cells: Wall/Door items (|x| <= 2.3, |z| <= 0.85 of their centre), tall solid thin Shell parts (+0.3) and built-in Room zones.
    - It floods from (0, 20) to find the lobby.
    - A patch becomes a room when area is 40..1600, each side >= 5, bbox fill >= 0.8, and a Door has the lobby 1.8 studs on one side and the patch on the other.
  - Ids are from 201 (`Rooms.FIRST_ID`). A room is matched by attribute `Sig` (bbox + area). `Rooms.hints(hotel)` = `{[sig] = id}`, which the save stores as `custom` so restored rooms keep their numbers.
  - It builds with `HotelBuilder.customRoom(hotel, id, info)`. The room model gets:
    - attributes `Custom`, `Sig`
    - a thin non-colliding chevron `Floor`
    - Nav (Door outside, Enter inside), CleanSpots, Mess
    - DoorFrame: invisible rotated Threshold, StatusLight / LampPlate / LampGlass, NumberPlate
    - `DoorRef` (ObjectValue to the Placed Door item)
    - a BuildZones `Room<id>` part with `Custom`
  - Then `RoomAdded` fires. Furniture inside joins it (Zone; core kinds get Core/Room).
  - Broken rooms are removed only in state Ready/Unfurnished. `RoomRemoved` (new BindableEvent in RAH_Signals, made by the module) fires first. Items go back to the lobby. Otherwise the hotel gets `RoomsPending` and the sim rescans every 5 s.
  - `Rooms.door(roomModel)` gives the Swing model (its own `Door`, or `DoorRef.Value.Swing`).
- **HotelSim:**
  - scans 0.4 s after ItemsChanged and once at start
  - drops a room on `RoomRemoved`
  - custom `roomBox` comes from the Floor; custom rooms skip the tier wainscot and feature wall (floor tint only)
  - doorKnob and knockOn use `Rooms.door`
  - `Locked` is mirrored on the Door item (RAH_Doors reads the Swing's parent)
  - doorBits' DoorBlock follows the Threshold's rotation
- **Build:**
  - `zoneAt` prefers any non-Lobby zone over a Lobby one
  - validate compares zone names
  - structure items (Wall, Door) may span zones and may overlap each other
- **Save:** `d.land` (slot ids with a Wing but no built-in Room) and `d.custom` (hints). Restore builds wings or land in slot order, places the items, then runs `Rooms.scan` before the tiers.
- `HotelBuilder.materials()` skips variants that already exist while running: game servers can't write `MaterialVariant.BaseMaterial`, which broke `buildWing`/`buildLand` at runtime.
- **Leaderstats:** RAH_Save makes `leaderstats.Cash` (an IntValue that follows the Cash attribute).
- **Left dock:** RAH_Coop `layoutDock` centres on the screen height (phones: the space above the thumbstick), re-fits 0.7 s after showing and on ViewportSize changes.
- **Performance:**
  - `StarterPlayerScripts.RAH_Perf`: lights under City and Plots more than 140 + Range studs from the camera are switched off (attributes `Culled`, `BaseOn`), checked 60 per frame. RAH_Lighting writes `NightOn` and respects `Culled`. City parts with largest side < 2.5 get CastShadow off.
  - `C.CROWD` 76 -> 56; Crowds `NEAR_PLAYER` 220, `FAR_AWAY` 280.
  - Bodies disable Swimming, Flying, StrafingNoPhysics, PlatformStanding, GettingUp and Physics.
  - Traffic skips the bounce for cars more than 260 studs away.
- **Walk-in ramp:** HotelSim `growth()` = clamp((level - 1) / `C.WALKIN_RAMP_LEVELS` (default 6), 0, 1). pedInterest x (0.4 + 0.6k); wantsWalkIn gap = WALKIN_GAP + 14(1 - k); queue max = min(QUEUE_MAX, 2 + round(4k)); guest cap = floor(6 + 8k).
- **Faces:** `Bodies.classicFace` makes the dynamic head invisible (it keeps its attachments) and welds on a `ClassicHead` Part (SpecialMesh Head, scale 1.2) that carries the `face` decal. Backup `DevTools.Faces_Backup_20261103`.
- Backups: `DevTools.Rooms_Backup_20261103`, `DevTools.Perf_Backup_20261103`; disk `archive/*_20261103n.lua`.

### Round 10c (2026-11-03): controllers, weather, colliders, new items
- **Gamepad layer (RAH.UI)**
  - `UI.gamepad()` is true when the last input came from a pad. Don't confuse it with `UI.pad(o, l, t, r, b)`, which is padding.
  - `UI.PadChanged` (BindableEvent), `UI.PAD_KEYS` (key-hint swaps), `UI.closers` with `UI.closeTopmost()` (every `UI.closeButton` registers there), and `UI.padSelect(root)`.
  - `UI.open(o, {noSelect = true})` skips the auto-select.
- **StarterPlayerScripts.RAH_Gamepad:** B (CAS `RAH_PadBack`) closes the topmost panel. `RAH_PadLegend` shows the D-pad shortcuts: up = build (RAH_BuildClient), left = menu (RAH_Coop), right = research (RAH_ResearchUI).
- **RAH_BuildClient**
  - CAS `RAH_BuildPad` (priority High+10) is bound only while building.
  - The left stick pans, the right stick orbits and the triggers zoom (`pad` table, read in `stepCamera`).
  - Buttons: A = `worldClick` at screen centre (`padAim`), B = back, X = turn, Y = drawer (`UI.padSelect(list)`) or move, LB/RB = lower/raise.
  - Reticle gui: `RAH_PadReticle`. Pad hint sets: `PAD_IDLE` / `PAD_GHOST` through `hintsFor()`.
- **RAH_Minigames:** CAS `RAH_MinigamePad` (High+20). The left stick moves `s.padP` (gold ring), A/RT call `onDown`/`onUp`, B gives up.
- **RAH_Coop dock:** on touch-only devices the dock stays in the top 60% of the screen, clear of the thumbstick.
- **Weather**
  - ServerScriptService.RAH_Weather sets RAH attributes:
    - `Weather`: clear / cloudy / fog / rain / storm / snow
    - `WeatherName`
    - `Lightning`, a serial, with `LightningAt`
  - Studio hook: RAH attribute `TestWeather`.
  - Readers:
    - RAH_Lighting: the `WX` blend and the lightning flash
    - RAH_WeatherFX: camera-following rain, snow and splash emitters; Terrain Clouds; the rain loop, muffled indoors; thunder
    - RAH_Crowds: `crowdTarget()` = C.CROWD x `HOURS[hour]` x `WEATHER_CROWD`; umbrellas (`makeUmbrella`); hurrying; shop ducking
    - RAH_HotelSim `wantsWalkIn` (x1.15 to x1.9)
    - RAH_GuestLife
  - Textures: rain 121142287419380, snow 134437018607647, splash 84023424081823 (ui/fx_*.png).
- **Crowds:** the target counts walkers within 260 studs of a player (`nearCount`). Walkers more than 330 studs from every player retire, and tunnel spawns happen only near a player.
- **Colliders:** RAH_MapBuilder `COLLIDE` gives TreeA/B/C, StreetLamp, TrafficLight and CafeTable a non-colliding mesh plus an invisible `Collider` cylinder (group NPCSolid). This was applied in place to workspace.City as well.
- **New items:** `rah_props_r10c.py` (exec'd by rah_props.py), then MeshImporter, then `HotelBuilder.addItems`. The Catalog has research gates. The Candelabra glows (GLOWS9).
- **Sounds:** RAH_Audio DEFS `sizzle`, `chop`, `flip`.
- **Backups:** `DevTools.Weather_Backup_20261103`; archives `*_20261103k` / `*_20261103m`.

### Round 9 (2026-11-02 / 03)
Script prefixes stay `RAH_` (internal; the game is called Overbooked now). Pushing: serve `src/` on 8791 and in Edit run `loadstring(HttpService:GetAsync("http://127.0.0.1:8791/_push.lua"))()({names})`. `_push` compile-checks and writes with `ScriptEditorService:UpdateSourceAsync`. Its `where()` maps names to their parents; unknown names become StarterPlayerScripts LocalScripts.
- **`RAH.UI`** (ModuleScript): the shared look and motion.
  - Palette `UI.T`, fonts `UI.F` (Builder Sans).
  - Helpers: `new`, `corner`, `stroke`, `textStroke`, `pad`, `list`, `grad`, `label`, `icon`, `tween`, `scaleOf` (UIScale `PopScale`), `pop`, `open`, `close`, `stagger`, `countTo`, `commas`, `sound` (fires `RAH_Audio.Play`).
  - Widgets: `panel` → holder, body; `button` → b, label; `setKind`, `setDisabled`, `shake`, `iconButton`, `closeButton`, `tabs` → api, bar; `toggle` → b, set; `segmented`, `slider`, `tooltip`.
  - Screen-wide: `autoScale` (UIScale `AutoScale`, one per object), `blur`, `toast` (ScreenGui `RAH_Toasts`, DisplayOrder 40).
  - `UI.new` writes every prop key, so strip custom keys before passing props.
- **`RAH_MainMenu`** (LocalScript, title screen, DisplayOrder 50):
  - Scriptable camera through `SHOTS` (camera from/to plus look from/to), black dips between shots. Shots must stay over the road (z < 118): the shops at z 121..157 swallow the camera.
  - Hides every other ScreenGui except `RAH_Toasts` while it's up, and restores them afterwards.
  - Menu remote: `("slots")` asks, the server replies `("slots", data)`, and `("play", slot)` starts the game. It waits for `RAH_Slot` + `RAH_Plot`, then sets the camera to Custom on the humanoid.
  - If `RAH_Slot` gets set by something else (tests), it gets out of the way at once.
  - Button names (for MCP clicks): `Root.Buttons.Btn_saves / Btn_tips / Btn_settings`, save buttons `Root.P_saves.Panel.Body.Content.Slot<n>.Go`.
- **`RAH_Client`** (HUD, `RAH_HUD`, DisplayOrder 4): corner `group()`s that slide away while `RAH_Building`, a daySummary on Notify `day {guests, cleans, earned, uncollected}`, and toasts through `UI.toast`. It keeps the `RAH_Toast` BindableEvent.
- **`RAH_Coop`** (the Menu, `RAH_Coop`, DisplayOrder 20):
  - tabs hotel / staff / coop / stats / settings
  - it sets player attribute `RAH_MenuOpen` while open (RAH_ResearchUI hides its launcher)
  - Research shortcut: player attribute `RAH_OpenResearch = true`
  - settings attributes `RAH_MusicOff`, `RAH_SfxOff`, `RAH_Sprint`
  - it keeps the `reboot()` on `RAH_Plot` changes
- **`RAH_ResearchUI`** / **`RAH_ResearchServer`** / **`RAH.Research`**:
  - 33 nodes in branches; hotel attribute `Research` = JSON `{done, cur, ends}`
  - Remotes.Research `("start", id)` / `("cancel")`; Notify `researched {id}`
  - opened by R, the launcher, or `RAH_OpenResearch`
- **`ServerStorage.RAH_GuestEvents`**: `E.DEFS` (11 events: need, payout, look, lines), `roll`, `pickRoom`, `dress` / `undress` (welded `EventProp_*` props), `stay`, `inspect`, `pay`, `burst`. RAH_HotelSim calls it at arrival, room choice, stay and checkout. **`RAH_Props`** (client) animates the dog and balloon welds.
- Studio test hooks on a hotel model:
  - `TestResearchDone` (all research counts as done)
  - `TestEvent = id` (the next guest gets that event)
  - `TestSpawn = true` (spawn a guest now)
  - `TestLetIn = n` (let n guests in)
  - Put `Receptionists` / `Janitors` back to 0 and Cash to 300 after a test: **the test save is real**.
- **City:**
  - `RAH.Street` holds the layout numbers; `ServerStorage.RAH_MapBuilder.build()` makes `workspace.City` (Road z 74.5..110.5, NearWalk, FarWalk, Lots, Shops z 121..157, Skyline, Props, Tunnels, Parked, Signals, BusStops).
  - `RAH_Traffic` (client cars, lights from server time).
  - `RAH_Crowds` (server pedestrians, tunnel to tunnel, `wantsWalkIn` hand-off to a hotel's sim).
- **NPCs:** `RAH.Looks` (`description(rng, kind)`, `walkStyle`) and `ServerStorage.RAH_Bodies`. Bodies carry `WalkAnim`, `IdleAnim`, `WalkStyle`, `WalkSpeedMul`.
- **Light:** `RAH_DayNight` (server clock anchor: RAH attributes `CycleStart`, `Day`, `Night`) and `RAH_Lighting` (client KEYS by ClockTime, an INDOOR profile while the camera is inside, the `RAH_NightLight` tag). `RAH_Roof`: player attribute `RAH_RoofMode` auto / show / hide.
- **Build:** `RAH.Build` (free yaw, stacking, wall items, `B.make` shapes), `RAH.Catalog` (98 items; `shape`, `wall`, `research`, `tags`), `RAH_BuildClient` (shop drawer, tool rail, shape editor), `RAH_BuildServer`.
- **`RAH_Audio`** city ambience: `dayLoop` 9112784918 and `nightLoop` 9112772108 (Pro Sound Effects) in `workspace.RAH_AudioLocal`. Volume = 0.55 × nearness to road z 92 × (1 - 0.75 × indoor), where indoor means a roof within 40 studs above the camera. Day and night crossfade by `Clock.isNight`.
- Backups: `Run a Hotel tools/archive/*_20261102.lua`, `ServerStorage.DevTools.UI_Backup_20261103` (RAH_Client, RAH_Coop, RAH_MainMenu, RAH_Audio).
- Removed hair ids 62234425 and 62745990 (their textures 81504106 / 82186433 are gone from Roblox).

### Plots and co-op (round 8)
- **`ServerScriptService.RAH_Plots`** (Script): moves `Workspace.Hotel` to `ServerStorage.RAH_HotelTemplate` at start, clones `Workspace.Outside` per plot into `workspace.Streets`, copies the terrain block (x +-212, y -64..32, z +-240) with `CopyRegion` and pastes it per plot. 5 plots, `Build.PLOT_W = 420` apart, origin x = `(k-3)*420` (Hotel3 at 0), claimed in order 3, 2, 4, 1, 5.
  - `claim(player)` clones the template into `workspace.Plots.Hotel<k>` (attributes `Origin`, `Plot`, `Owner`, `HotelName`; `ModelStreamingMode = PersistentPerPlayer`, `AddPersistentPlayer` for members), fills missing Uids, publishes `NextRoom`, calls `RAH_HotelSim.start(hotel)` and sets `BuildReady`. `release(k)` stops the sim, destroys the hotel and repastes the terrain (3 s after the owner leaves).
  - Player attributes: `RAH_Home` (own hotel name), `RAH_Plot` (the hotel you're working in). Members of a hotel = players whose `RAH_Plot` is its name.
  - Teleport to `O + (0, 4, 50)` on spawn and on a move (Notify `coopMoved`).
  - **`Remotes.Coop`** (RemoteEvent): `("invite", userId)`, `("respond", fromUserId, accept)`, `("leave")`, `("kick", userId)`. `MAX_MEMBERS = 4`, invites last 60 s. Notify `coopInvite {from, name, hotel}`. Owner leaving sends helpers home. Server full (no plot) = join the quietest hotel.
  - Studio-only test hook `ServerStorage.RAH_PlotsTest` (BindableFunction): `("fake", name)` makes a hotel with no player, `("move", player, hotelName)`, `("home", player)`, `("release", k)`.
- **`ServerStorage.RAH_HotelSim`** (ModuleScript, generated from the old RAH_Hotel by `scratchpad/mksim.py`; the old script is in the backup): `Sim.start(hotel)` → `{hotel, stop}`. All positions offset by `O = Origin`; guests live in `hotel.Guests`; every loop is `while running`; arrivals only with members; prompts check membership (`notMine` toast); toasts go to members only; `nameSign` follows `HotelName`. `stop()` kills guests/staff and the ShowerHead attachments.
- `RAH.Build`: `PLOT_W`, `hotelAt(p)`, position-based `zoneAt`, `placedOf` needs a parent named `Placed`, `appeal(zoneName, hotel)`. `HotelBuilder` offsets everything by `OX` (`useOrigin(hotel)` in `buildWing` / `forSale`).
- RAH_BuildServer builds in `PLOTS[RAH_Plot]` (must have `BuildReady`), refuses zones outside it ("Keep it inside your hotel"); `roomBuilt` carries `hotel`. RAH_Save: `homeOf(player)`, furniture x saved relative to the origin; only the home hotel is saved (LayoutOwner is gone).
- **`StarterPlayerScripts.RAH_Coop`** (LocalScript): Co-op button + PLAY TOGETHER panel + invite cards (`PlayerGui.RAH_Coop`, DisplayOrder 20). When `RAH_Plot` changes it calls `RAH_BuildClient.RAH_Leave` (BindableFunction, exits build mode), then replaces RAH_Client and RAH_BuildClient with fresh clones; both resolve `HOTEL` from `RAH_Plot` and remove their old GUIs.
- Icon `coop` (`ui_icons.py coop`).

### Scripts
- **`ReplicatedStorage.RAH.Items`**: one template per catalog item (anchored, soft items non-colliding, glow parts Neon + PointLight).
- **`ReplicatedStorage.RAH.Catalog`**: `ITEMS` (name, cat, price, appeal, `core`, `flat` = rug, `soft` = guests walk through), `ORDER`, `CATS`, `SELL_BACK = 0.75`, `PRICE_PER_APPEAL = 3`, `CORE` (guest spots relative to core pivots: Bed `lie`/`sides`/`clean`, Shower `inside`/`front`/`clean`/`head`, Toilet `sit`/`front`/`clean`), `price`, `sellValue`.
- **`ReplicatedStorage.RAH.Build`**: shared placement rules. `box(id)`, `zoneAt(p)`, `placedOf(part)`, `snap(id, point, turns)` (1-stud grid, quarter turns, y = FY), `validate(id, cf, ignore)` → ok, reason, zone, `appeal(zoneName)`. Overlap uses `GetPartBoundsInBox` against Shell/Rooms/Lobby/Doors/Placed/NoBuild; flat items only clash with flat items.
- **`ReplicatedStorage.RAH.Remotes.Build`** (RemoteFunction, round 2): `("place", itemId, cf)` → ok, uid; `("move", uid, cf)`; `("sell", uid)` → ok, refund. Owner only, 0.12 s rate limit, the server re-snaps the CFrame and re-validates. Core items: no sell, no leaving their room, no moving while the room is Booked.
- **`ServerStorage.RAH_HotelBuilder`**: a runtime copy of `src/HotelBuilder.lua` (keep it in sync with `DevTools.HotelBuilder`); RAH_BuildServer requires it for `nextSlot`, `buildWing`, `forSale`, `wingGeom`.
- Build remote `("room", roomId)` → ok, id: must be the next slot; charges after the wing is built, fires `RoomAdded`, `ItemsChanged`, Notify `("roomBuilt", {id, pos, price})` + a toast. **`ServerStorage.RAH_Signals.RoomAdded`** (BindableEvent, arg = room model): RAH_Hotel's `addRoom(m)` registers it live.
- **`ServerStorage.RAH_Signals.ItemsChanged`** (BindableEvent): fired by RAH_BuildServer after any change; RAH_Hotel re-syncs clean spots, shower head, room `Appeal`/`Price`, `LobbyAppeal`.
- **`ServerScriptService.RAH_BuildServer`**: the Build remote. Notify `("built", {kind = place/move/sell, item, pos, amount})`.
- **`StarterPlayerScripts.RAH_BuildClient`**: `PlayerGui.RAH_Build` (BuildButton, Shop with Tabs/Items cards, PlaceBar Turn/Place/Cancel, ItemCard Move/Turn/Sell/Close drawn in screen space over the item), the scriptable orbit camera (RenderStep `RAH_BuildCam`), local overlays and ghost in `workspace.RAH_BuildLocal`, room labels (BillboardGui `RAH_ZoneLabel`). Sets player attribute `RAH_Building`, turns ProximityPromptService off, and zeroes WalkSpeed/Jump while building (this place has **no PlayerModule**, so `GetControls` isn't available). World clicks fire on mouse-up, 0.05 s later, and are skipped if a build button took the click.
- RAH_BuildClient: `RoomCard` in the shop (two clicks within 4 s), `riseWing(id, pos)` tweens the wing/room/furniture parts up locally from 16 studs below, then a star confetti burst. The camera clamp widens with `MinX`/`MaxX`; the facade list is rebuilt on every entry.
- RAH_Client exposes `RAH_Toast` (BindableEvent child of the script) so other client scripts can show toasts.
- **`ReplicatedStorage.RAH.Config`**: prices, timings, `ICONS`, wardrobe (`SHIRTS`, `PANTS`, `HAIR`, `HATS`, `FACES`, `SKIN` – Roblox-made catalog ids), `NAMES`, R15 `ANIM` ids, speech `LINES`.
- **`ReplicatedStorage.RAH.Remotes.Notify`** (server → client): `("toast", {text, icon, bad})`, `("paid", {amount, pos})`, `("collect", {amount, pos})`, `("cleaned", {task, pos})`.
- **`ServerScriptService.RAH_Hotel`** (Script): everything server-side. **Round 8: now `ServerStorage.RAH_HotelSim`, one per plot (see above); `Workspace.Hotel` is now `workspace.Plots.Hotel<k>`.**
  - Collision groups `Guests` (no collision with each other or players) and `Players`.
  - Guests: `Players:CreateHumanoidModelFromDescription` (R15), Animate removed, own animator (idle/walk by `Humanoid.Running`, sit, wave). Pathfinding with `AgentRadius 1.6`, direct-MoveTo fallback and stall nudge.
  - Life: street → queue (patience `C.PATIENCE`) → let in (gets a room) → desk check-in → room (optional Wander, Toilet/Shower in random order, Bed last) → room set Dirty when they reach the room's Door → pay at `DeskGuest2` (adds to pending pile) → leave. Poses anchor the HRP at the Nav CFrame (`pose`/`unpose`).
  - Status card: BillboardGui `Status` in the guest's Head (`GuestName`, `Card.Icon/Label/Track.Fill`, `Say`).
  - Hotel attributes for clients: `RoomsReady`, `RoomsBusy`, `RoomsDirty`, `Waiting`, `Pending`, `Owner`, `HotelName`.
  - Player attributes (server-owned): `Cash` (start `C.START_CASH = 300`), `Earned`, `Cleaned`, `Spent`. Saved by `RAH_Save`.
  - Payment = room `Price` + tip. Patience = `PATIENCE * (1 + LobbyAppeal/40)`; arrival gap divided by `(1 + LobbyAppeal/60)`.
  - Prompts are `Style = Custom` with attributes `Icon` (Config.ICONS key) and `Color` (yellow/green/blue).
  - Receptionist "Ben" (anchored, waves at guests reaching the desk).
- **`ServerScriptService.RAH_Save`** (round 4): DataStore `RAH_Save_v1`, key `u_<UserId>`, `UpdateAsync` with 3 retries. Data `{v = 1, cash, earned, cleaned, spent, rooms = {ids}, items = {{i, x, z, r (quarter turns), c (Core), rm (Room)}}, saved}`.
  - Waits for Hotel attributes `HotelReady` (end of RAH_Hotel's setup) and `BuildReady` (end of RAH_BuildServer).
  - The first player whose save loads becomes Hotel `LayoutOwner` (0 once they leave: nobody's save holds the hotel after that). Only the layout owner's save gets `rooms`/`items`; everyone saves their own stats.
  - Restore: `HotelBuilder.buildWing` for saved rooms in slot order (+ `RoomAdded`), then non-core Placed items are replaced by the saved ones (dropped if no zone at the spot), core items move by Core + Room, missing Uids filled, `NextRoom`/`NextRoomPrice` republished, `ItemsChanged` fired.
  - `loaded[player]` guards saving: a failed load never saves over the old data. Player attribute `RAH_Loaded`.
  - Saves on PlayerRemoving, every 60 s, 8 s after `ItemsChanged` (a change counter keeps the dirty flag if something changed mid-save), and in BindToClose.
  - The welcome toast goes 5 s after the character spawns (earlier ones landed before the HUD was ready to show them).
- **Room upgrades (round 7)**: `Config.ROOM_TIERS` = `{name, bonus (per stay), tip (tip multiplier), price (to reach it), icon}` x3, `STAR_APPEAL = {8, 20}`, `STAR_ARRIVALS`. Room model attributes `Tier` (nil = 1), `Stars` (1..5 = tier + appeal steps), `Price` now adds the tier bonus. Hotel attribute `HotelStars` (average, in tenths); `arrivalGap` divides by `1 + (HotelStars - 1) * STAR_ARRIVALS`. Build remote `("upgrade", roomId)` (RAH_BuildServer) charges, sets `Tier`, fires `ItemsChanged`, a toast and Notify `("upgraded", {id, tier, pos, amount})` (RAH_Audio: hammer, fanfare). RAH_Hotel's upgrade section (before `addRoom`): `roomBox(room)` finds the wall faces by raycasting into `Hotel.Shell` (so wings work), and `dressRoom(room)` rebuilds `room.model.Upgrade`. It holds `wainscot`, `featureWall`, `sconce` and `crown` runs, a `Throw` model (`room.throw`, re-pivoted to the bed in `syncRoom` and hidden in `showBed` while messy) and the door `Sign` (SurfaceGui with a tier label and 5 star images, redrawn by `drawSign`). It also recolours `Floor` / `BathFloor` (originals kept in the attributes `BaseColor` / `BaseMat`) and nudges `Props.Painting` forward (`BaseCF`). `onTier` (on a `Tier` change) redresses and sparkles. RAH_Save stores `tiers = {["101"] = 2}` and restores them before the staff. Shop: `upgradeCards` in RAH_BuildClient (LayoutOrder -60 + id; the buy-room card is now -100). HUD: `starRow` under the hotel name (clipped gold stars over `starEmpty`). Icons `roomDeluxe`, `roomSuite`, `starEmpty`, `upgrade` (`ui_icons.py upgrades`).
- **Staff (round 6)**: `Config.STAFF` = `{id, name, attr, icon, max, prices[n], blurb}` (janitor: attr `Janitors`, max 3; doorman: attr `Doormen`, max 1), `STAFF_CLEAN`, `STAFF_WALK`, `DOORMAN_DELAY`. Build remote `("hire", staffId)` (RAH_BuildServer) checks the count and price, charges, bumps the Hotel attribute, fires `ItemsChanged`, a toast and Notify `("hired", {id, count, amount})`. RAH_Hotel's staff section: `syncStaff()` spawns or removes NPCs to match the attributes (one pass at a time); `makeStaff` = a random guest body with clothes removed and uniform part colours, a welded mop (janitor, `g.mopWeld` swung in `mopWork`) or cap (doorman), and a Role label. Models in `workspace.Guests` with attribute `Staff`. `janitorLife` claims the nearest Dirty room (`room.cleaner`), walks to `workSpot(room, task)` and calls `room.clean(task, nil)`. `doormanLife` calls `letIn()` when `queue[1].queuedAt` is older than `DOORMAN_DELAY` and `freeRoom()` exists. Refactors: `room.clean(task, player?)` (player nil = staff: plays the `sfx` instead of Notify `cleaned`), `letIn(maxN?)` (shared with the door prompt), guests get `g.queuedAt`. RAH_Save stores `staff = {janitor, doorman}` for the layout owner and sets the attributes on restore. Shop: `staffCards` in RAH_BuildClient (two clicks within 4 s), Catalog tab `staff`. Icons `janitor`, `doorman`, `staff` (`ui_icons.py staff`).
- **`StarterPlayerScripts.RAH_Audio`** (round 5): all sound, client-side. `DEFS` = name → {assetId, volume, pitch range, playback region?, fade-out at?}. SoundGroups `SoundService.RAH_SFX` (0.9) and `RAH_Music` (0.32). World sounds sit on a temporary Attachment in Terrain (InverseTapered, 14..160 studs). Triggers: Notify `toast` (bad → error, roomReady/star → ready, roomDirty → dirty), `paid`, `collect`, `cleaned` (per task), `built`, `roomBuilt`, and the new **Notify `("sfx", {name, pos})`** sent by RAH_Hotel's `sfx(name, pos)` (arrive, door, bell, flush). Shower loops follow each `Terrain.ShowerHead.Water` emitter's `Enabled` (LoopRegion 8..48 s). Player attribute `RAH_Building` → open/close whoosh. Every GuiButton in PlayerGui gets click + hover. Music: shuffled `MUSIC_IDS` playlist in `workspace.RAH_AudioLocal`, M toggles. Other client scripts play sounds with `RAH_Audio.Play:Fire(name, pos?)` (RAH_BuildClient: select, turn, error on a bad toast).
- **`StarterPlayerScripts.RAH_Client`** (LocalScript): `PlayerGui.RAH_HUD` (room chips, cash, hotel name, waiting pill, toasts), world popups, and the custom prompt renderer (BillboardGui `RAH_Prompt` per shown prompt: CanvasGroup round button, hold fill, key chip, click/tap support).

### Gotchas
- **Parts under `workspace.CurrentCamera` don't show in Studio's `screen_capture`.** Local build visuals go in `workspace.RAH_BuildLocal`.
- With streaming, the client may not have `BuildZones` at startup. Build anything zone-based when build mode opens.
- The MCP mouse tool clicks the wrong spot for buttons inside a BillboardGui (their AbsolutePosition is in the billboard's own space). Keep clickable cards in a ScreenGui.
- `require` of a cloned `RAH.Build` in `execute_luau` must parent the clone into `RAH` first (it reads `script.Parent`).
- `RAH_Hotel` builds a room in `addRoom(m)`; anything that adds a room at runtime must fire `RoomAdded` after its Placed items exist.
- Starting decor (some plants and lamps) sits where the builder put it, which can break the rules. It stays put, but can't be moved back to the same spot.
- `screen_capture` in Edit came back black on this machine (2026-10-29); captures in a **playtest** work. Force the play camera with `BindToRenderStep` (the MCP resets `CameraType` after each call).
- Prompt BillboardGuis in PlayerGui don't show in captures.
- When testing prompts from `execute_luau`, wait ~1.5 s after teleporting before `InputHoldBegin`, or the prompt isn't shown yet and nothing happens.
- The HUD cash counter is driven per frame (RenderStepped) now; the old tween on an unparented NumberValue stalled partway after a big jump (300 to 4,395 on load).
- Backups for round 8: `DevTools.Plots_Backup_20261030` (RAH_Hotel, RAH_BuildServer, RAH_Save, RAH_BuildClient, RAH_Client, Config, Build, HotelBuilder).
- Studio's solo playtest has one player, so co-op is tested with `RAH_PlotsTest` fakes; a real invite needs Test > 2 Players or a live server.
- Backups for round 7: `DevTools.Upgrades_Backup_20261029` (Config, RAH_Hotel, RAH_BuildServer, RAH_Save, RAH_BuildClient, RAH_Audio, RAH_Client).
- Backups for round 6: `DevTools.Staff_Backup_20261029` (Config, Catalog, RAH_Hotel, RAH_BuildServer, RAH_Save, RAH_BuildClient, RAH_Audio).
- Backups for round 5: `DevTools.Sound_Backup_20261029` (RAH_Hotel, RAH_BuildClient).
- Audio: only licensed library sounds (Pro Sound Effects, APMOfficial, DistrokidOfficial music) are safe; user uploads may be private and silently fail in a published game. Ids were checked with `ContentProvider:PreloadAsync` (all `IsLoaded`). Short UI sounds are hard to find with `audioMaxDuration` filters; search `<thing> (SFX)` without one.
- Backups for round 4: `DevTools.Save_Backup_20261029` (RAH_Hotel, RAH_BuildServer, RAH_Client).
- Freshly uploaded images log "Asset content representation is being generated" for a few minutes; harmless.
- Big MeshParts use Box collision. Shower, plants, lamps, rugs, mess and paintings are `CanCollide = false` (set by RAH_Hotel at start) so guests can walk into the shower.

### Round 10e (2026-11-04)
- **RAH_HotelSim is at Luau's 200-locals cap.** New blocks are wrapped as `local a, b do ... a = function ... end end` (see `scope.py` in the scratchpad history). Exported this way: `parkCar`; `holdBag, giveBag, dropBag, anyDoubleRoom, addBuddy, playItem`; `orders, deliverOrder, hasCart, waitOrder`; `staffPace, staffGain, staffTag, idleJob`. Add new code the same way, never as new top-level locals.
- `addCash(player, amount)` pays the hotel's `Owner` when online (co-op helpers earn into the owner's cash).
- Arrivals: `arrivalGap` divides by `(1 + park)` (0.03 per ParkingSpot, max 10 spots) and by `busy` (1.25 from 17:00 to 22:00, 0.55 from 0:30 to 5:48, via `RAH.Clock`).
- **Cars:** `parkCar(g)` (70% of guests) clones a car from `workspace.City.Parked` into a free `ParkingSpot`; `despawn` removes `g.car`, `g.bag`, `g.buddy`. `HotelBuilder.B.parking` digs the lawn terrain (Air at FY-1, h 8; Concrete at FY-7, h 4); tarmac and kerbs from FY-5.
- **Tips:** `leaveTip(room, amount)` puts a note on the bed (raycast) with a "Take Tip" prompt; `takeTip(room, player?)` pays it (nil = onto the pending pile, called by `roomFinishedCleaning`). Left at checkout when `g.mood >= 62` (60%).
- **Dust:** `DUST_MAX = 4`, `setDusty(model, on)` (particles + "Dust Off" prompt, hold 1.2 s, `Levels.award` 2). A loop dusts a lobby item with appeal every 50-80 s. `lobbyAppeal = max(0, appeal - 2 * #dustyItems())`.
- **Dirty rooms:** `setRoomState` writes HOTEL `DirtyRooms` (JSON ids). RAH_Save saves `d.dirty` and on restore sets HOTEL `DirtyRestore`; `restoreDirty()` waits 3 s and marks those Ready rooms Dirty.
- **Talking:** `g.talkUntil` / `g.talkPlayer` pause `follow()`; the NPC stops and faces the player (breaks off past 16 studs). `talkTo` picks `C.TALK` sets by state: hiGrumpy, hiQueue, hiLeaving, hiNight/hiRoom, hiCouple, hiBags, hi. `say(g, text, secs)` shows free text; `think()` only takes mapped "...ing" keys. `C.THOUGHTS` (22% per activity).
- **Disturbing:** sleep / DND / repeat knocks set the bubble attribute `BIcon = "angry"` for 3.5 s and `sfx("grumble")`. `C.DND_CHANCE = 0.15`.
- **Luggage and couples:** `giveBag` (75%; Suitcase 60% welded at the root's right side, Duffel 40% on RightHand, from HotelProps), `dropBag(g, room)` anchors it by the bed, `holdBag(g)` at checkout. `addBuddy(g)` (30% when `anyDoubleRoom()`; not event or tourist guests) adds a follower that lies beside the guest (`g.sleepCF * CFrame.new(2.4, 0, 0)`). `bedSleeps(room)`; `freeRoom` gives couples a bed with `sleeps >= 2` (Catalog: BedSuite, BedCanopy, BedBunk, BedTwin). Couples pay x1.6.
- **Fun items:** `PLAY` table and `playItem(g, entry)`; `lobbyVisit` prefers "play"-tagged items 55% of the time. Config `C.ANIM` adds laugh 507770818, point 507770453, dance 507771019.
- **Room service:** `ORDER_SECS = 75`, `orders[room] = {g, t, carrier}`. Each ServiceCart gets an `OrderPrompt` ("Take Order", F, hold 0.4) enabled while an order waits. `giveTray` welds a tray to the hand and sets player attribute **`RAH_Tray` = room id**. `knockOn` delivers when the knocker carries that room's tray: `deliverOrder` pays $30 (or $45 if quick), mood +5/+9, `Levels.award` 6, `quest("serve")`. Test hook: HOTEL attribute **`TestOrder`** (order chance per activity, default 0.35).
- **Staff:** `STAFF_LV = {0, 60, 160, 320, 560}`, `STAFF_ROOM_AT = 3`, HOTEL **`StaffXP`** JSON (saved as `d.staffxp`). `staffTag` sets `BRole` "Janitor  LV n"; `staffGain(s, xp)` (+1 a minute on shift, janitor +2 a job, doorman +2 a let-in, receptionist +1 a greeting). `needsStaffRoom()` (3+ staff and no StaffLocker) makes pace x1.3 plus a phone message. `staffPace = (1 - 0.07 * (lv - 1)) * roomFactor`. `idleJob`: dust, then a break at StaffTable/lockers (60% at night, 30% by day), then mop the lobby. Talk: `staffInfo`, `talkStaff`, `staffReply`; RAH_Talk shows "STAFF LEVEL" and `info.sub` for staff (`OPTIONS.staffText`).
- **Audio (RAH_Audio):** `MUSIC_DAY` / `MUSIC_NIGHT` shuffled decks, switch at dusk/dawn; `STINGS = {levelUp = 85130118995016, chapter = 1848342733}`; music ducks to 15% for 7 s on Notify `levelUp` / `chapter`.
- **Co-op (RAH_Plots / RAH_Coop):** Coop actions `("visit", userId)`, `("request", userId)` (sets `invites[asker][host] = -now`, Notify **`coopRequest`** `{from, name}`), `("allow", userId, yes)` (host answers; `moveTo` + `tellHotel`). RAH_Coop rows have Visit and Ask to join buttons; `inviteCard(d, request)`.
- **Empty plots:** `RAH_MapBuilder.M.vacant(lot, cx, k)` builds `lot.Vacant` (billboard, lamps, rope, cones, A-frame). Old boards in `DevTools.Big_Backup_20261104` as `Vacant<k>`.
- **Beds:** every bed item must hold `Clean` and `Messy` models (`showBed`). `HotelBuilder.addItems` now wraps Bed / coreKind Bed items that way (Bed's Messy = `PROPS.BedMessy`; others a clone plus a fabric "Heap"). A bed without them stops the hotel starting ("Clean is not a valid member").
- Starter template (`workspace.Hotel.Placed`, attribute `Starter`): lobby Armchair, Bookshelf, VendingMachine, ServiceCart, 2 PottedTrees, Rug; each room a Wardrobe and second Nightstand. Old one in `Big_Backup_20261104.TemplatePlaced`.
- `rah_props.py`: Bed with more cuts (17,044 tris) and a Rug with real-geometry borders, medallion and fringes.
- Backups: Studio `ServerStorage.DevTools.Big_Backup_20261104`; disk `Run a Hotel tools/archive/*_20261104<letter>.lua`.
- **Test save:** the backup key is now **`u_665732195_s1_backup_20261104`** (level 9). Never restore `_backup_20261103` (a stale level-1 state).
- Testing gotcha: the MCP leaves the client camera `Scriptable` after `execute_luau`; prompts only show near the camera's focus, so set `CameraType = Custom` + `CameraSubject` before pressing prompt keys with `user_keyboard_input`.

### Round 11 (2026-11-05): grades, upkeep, 3D minigames
- **Grades:** `ReplicatedStorage.RAH.Grades` (`src/RAH_Grades.lua`). `LIST` (5: Roadside Inn, Town, City, Grand, Palace; each `price`, `level`, `rooms`, `rating`, `staff`, `look`, `perk`), `of(hotel)` (HOTEL attribute **`Grade`**, nil = 1), `priceMul`, `arrivalMul`, `vipChance(g)` (0 below 3, then 0.05 + 0.03*(g-3)), `check(hotel, cash)` → checklist, allOk, def. Build remote `("grade")` in RAH_BuildServer sets `Grade` and sends Notify **`gradeUp`** `{grade, name, hotel, pos}`. RAH_Save stores `d.grade`. `HotelBuilder.B.roof` grows the building from `Grade` (marquee, 2nd and 3rd storey, neon blade sign). The Hotel page (RAH_Coop) shows the checklist.
- The welcome-back toast in RAH_Save is gone.
- **Audio:** RAH_Audio `fanfare` = soft chime 9113849492 (the old loud song 1839881844 is gone). `STINGS` adds `gradeUp`. RAH_Client no longer plays the UI Fanfare at level-up or chapter (that was the double sound).
- **Upkeep:** `ServerStorage.RAH_Upkeep` (`src/RAH_Upkeep.lua`), one per hotel via `Upkeep.new(evCtx)` in RAH_HotelSim (`evCtx.upkeep`).
  - Breakdowns every `BREAK_EVERY` 75..130 s from level 2: `BREAKS` (lobby machines, spark or water) and `CORE_BREAKS` (Shower, Toilet). Item attribute **`Broken`**; HOTEL `BrokenLobby` (appeal penalty). An F prompt opens the Repair minigame (Notify `minigame {task = "Repair", title, room, kind}`, `minigameEnd`).
  - Handyman: `Config.STAFF` entry `handyman` (attr `Handymen`, max 2, $2,600 / $5,600, wage 55), `Levels` unlock `{4, 11}`, `Upkeep:handymanLife(s, pace, gain, idleJob)` (never enters a room with a guest inside).
  - Bags: `BAG_CHANCE 0.5`, `BAG_WAIT 110`; player attribute **`RAH_Bag`** = room id while carrying. Lost & found: `LOST_CHANCE 0.16`, player attribute **`RAH_Found`** = item name; the teddy faces the room door.
  - Test hooks on the hotel: `TestBreakNow` (true or an item name), `TestBreaks`, `TestBags`, `TestLost` (true or a number; `chance(v, default, on)`).
- **VIPs:** `RAH_GuestEvents` `E.roll` returns a clone of `DEFS.celebrity` with `pay * (1 + 0.25*(g-3))` when `rng < Grades.vipChance(g)`.
- **3D minigames:** `RAH_Minigames` holds a `G3` block with the 8 games (Floor, Bed, Shower, Toilet, CheckIn, CheckOut, Cook, Repair). The old 2D games stay as a fallback behind `local FLAT = false`. Task names, Notify payloads and results are unchanged.
  - Each game = a ViewportFrame (ZIndex 2) in `S.area` (620x340 design units) with a WorldModel (so raycasts work) and its own Camera.
  - Helpers: `ray`, `pick`, `onPlane`, `toArea`, `part/ball/cyl/cylX/cylZ/ell`, `model`, `done`, `item(name, cf, scale)` (clones `RAH.Items`), `tweenPivot`, `roomSet`, `tag3`, `overArea`, `scrubSpots`, `grime`.
  - `S.hideCursor` hides the OS cursor without a 2D tool.
  - ViewportFrames draw no particles, beams or shadows, so bursts, bubbles and float text stay 2D over the scene.
  - **Gotcha:** `done(m)` sets `WorldPivot = CFrame.new()` and must not set a PrimaryPart. A PrimaryPart owns the pivot, and models sank or turned sideways.
- **Drag to build:** RAH_BuildClient's "drag to place" `do` block (`S.dragBegin` on mouse down, `S.dragStep` in RenderStepped, `S.dragEnd` on release; mouse only, not touch). A row runs along X or Z from the ghost's spot; structures turn to run along it (spacing = box X), other items space by their footprint rounded up to the grid. Previews sit in `RAH_BuildLocal.RAH_DragGood` / `RAH_DragBad` (one Highlight each), max 30. Build remote `("placeMany", id, {cf...}, opts)` → ok, uids, firstWhy and `("sellMany", {uid...})` → ok, uids (max 40; each step is a normal place/sell called with `inner = true`, which skips the rate limit and the per-item `ItemsChanged`; one `ItemsChanged` at the end). `OnServerInvoke` now returns 3 values. Undo entries can hold `uids` (a whole row).
- Backups: `Run a Hotel tools/archive/RAH_Minigames_20261105b.lua` (and the 2D games behind `FLAT`), `archive/RAH_BuildClient_20261105.lua`, `archive/RAH_BuildServer_20261105.lua`.
- **Test save:** still restore only from `u_665732195_s1_backup_20261104` (level 9, $13,657), in Edit, after any playtest.

### Round 12 (2026-11-05): desk, tutorial, menus, settings, new items
- **Tutorial:** `StarterPlayerScripts.RAH_TutorialClient` (ScreenGui `RAH_Tutorial`, DisplayOrder 12) runs 10 `STEPS` (each has `begin`, `done()`, `waiting()` text, `target()` world point, `button`).
  - It starts on Notify **`tut2`** `{start, replay?}` once RAH_MainMenu and RAH_Loading are gone.
  - It hides while `RAH_Minigame` exists, `RAH_MenuOpen` is set or there's no `RAH_Slot`.
  - The beacon is a BillboardGui on a Terrain attachment, a neon floor ring (parts in the camera) and an edge arrow.
  - The card sits under the TopBar (`PhoneBarBottom` on phones; y = 70 while building).
  - `ServerScriptService.RAH_Tutorial`: `DONE = 5`, `REWARD = 500`. Remote `TutSkip`: `"done"` (Tut = 5, +$500 once), `"replay"` (resends tut2, 3 s limit), anything else = skip. The HUD's old "tut" card is unused.
- **Settings / prefs:** RAH_Save `PREF_KEYS` are saved as `d.prefs`:
  - RAH_MusicVol, SfxVol, MusicOff, SfxOff, UiSfxOff, Sprint
  - HideQuests, HideReviews, HideBubbles, HideRoomSigns, HideDaySummary, HidePops
  - FOV 55-100, ShadowsOff, PromptSize 60-140, LookSens 25-200, LookInvert
  - RemoteEvent `Prefs` (0.5 s limit; nil flags are sent as false). RAH_MainMenu watches the keys and sends them, debounced by 1.5 s.
  - Consumers: RAH_Client (`RAH_HidePops`, `RAH_HideDaySummary`, `RAH_PromptSize`, `RAH_FOV` while the camera is Custom and you're not building, `RAH_ShadowsOff`) and RAH_BuildClient (`RAH_LookSens`, `RAH_LookInvert`).
- **Build camera:** right drag = `RunService:BindToRenderStep("RAH_BuildLook", Camera + 2)`, reading cursor deltas with the cursor unlocked. Touch: two-finger twist turns, vertical tilt pitches, pinch zooms (`input.twoFinger`).
- **Minigame arm:** the avatar's own arm parts keep their size (`BaseLen` attribute). Only the upper arm stretches, to an off-screen shoulder.
- **Phone:** RAH_Coop `layoutDock` keeps below `PhoneBarBottom`. RAH_Client `fit()` / `layoutGroups()` skip on PHONE.
- **New items:**
  - Builder: `Run a Hotel tools/rah_props_r12.py` (exec'd by `rah_props.py`).
  - 26 ids in `Catalog.ITEMS` / `ORDER`, gated by `level`.
  - BikeRack and ParkBench are `outdoor` (car park only).
  - Wall items and their mount heights: NeonSign (5.2), KeyRack (4.2), Tapestry (3.2).
  - `GuestLife.SEATS` adds DiningChair, ReadingNook, LobbyBench (3), Beanbag and ParkBench (2).
  - `HotelBuilder.GLOWS9` adds lights for the glowing ones.
  - **Chandelier / PendantLamp** were built for an 11.6 ceiling, so a brass `Rod` + cap was added in Studio to `HotelProps`, with the top at 13.55.
    - The ceiling underside `B.CEIL` is FY + 13.6, and validate refuses anything over CEIL + 0.05.
    - Re-add the rods if these two are ever re-imported.
- **Lighting:** RAH_Lighting thins the weather by 70% while `RAH_Building` (`buildK`). Fog is now dens 0.24, haze 2.4.
- **Loading screen** (ReplicatedFirst.RAH_Loading): keep every ColorSequence's last keypoint at exactly 1 (0.9999 crashed it). The workspace `RAH_HoldLoading` hold must be set in Edit before Play.
- Backups in `Run a Hotel tools/archive/`: `*_20261105.lua` / `*_20261105b.lua` (BuildClient, Tutorial, Coop, Save, MainMenu, Loading, Client, Catalog, GuestLife, HotelBuilder, Lighting).
- **Studio gotcha:** `screen_capture` can go blank for the 3D view (even in Edit) while the UI still draws. It isn't the game; check the world with code then.
- **Round 12b:**
  - `UI.tabs(..., { scroll = true, fadeColor? })` makes the row a horizontal ScrollingFrame.
    - Edge fades named `Fade` have `<` / `>` buttons.
    - The underline rides inside the picked tab, which scrolls into view.
    - The build shop uses it.
  - `Build.validate` for `structure` items:
    - The zone is checked along the centre line, 1 stud in from each end.
    - Parts of `hotel.Rooms` / `hotel.Shell` don't block.
    - The NoBuild `Hallway` doesn't block.
    - A lane from each `Doorway*` across the hallway does block ("Keep the way into the room clear").
  - Backups: `archive/RAH_UI_20261105.lua`, `RAH_Build_20261105.lua`, `RAH_BuildClient_20261105c.lua`.

### Round 13 (2026-11-06): room doors, staff looks and jobs, research stats
- **Room doors:** `HotelBuilder.structureVariants()` clones `Items.Door` into `RoomDoor`, `RoomDoorModern` and `RoomDoorSuite`.
  - They add a cornice, card reader, kick plate, peephole and (Suite) gilt mouldings or (Modern) a bar pull and LED strip.
  - Catalog: `wallKind = "Door"`, so RAH_Rooms treats them like any door. They are first in the Structure tab.
- **RS.RAH.StaffLook** (shared module):
  - A look is `{ name, skin, hair, face, color, trim, style, acc }`.
  - Data tables: `PALETTE`, `TRIMS`, `ROLES[role] = { color, styles = { {name, premium?} }, acc }`, `FOCUS[role]` and `SHIFTS`.
  - Functions:
    - `default(role, index, name)`
    - `clean(role, look, premiumOk, fallback)`
    - `colors(look)`
    - `dress(model, role, look)`: clears every descendant with attribute `SL`, recolours, builds the part outfit and headwear, and swaps hair (from `StaffParts` when `LookHair` differs) and the face decal. It returns `{ mopWeld, mopRest, toolWeld, toolRest }`.
    - `ensureParts()` (server): fills `RS.RAH.StaffParts` with `Hair_<i>` accessories and `Face_<i>` StringValues via InsertService.
  - The premium (4th) style needs the perk `uniforms`.
- **HotelSim:**
  - `makeStaff` builds a plain body from the look (HumanoidDescription hair, face and skin), then calls `StaffLook.dress`. Models carry `StaffKey` (`def.id..index`) and `LookRev` (bumped on each edit).
  - The old `UNIFORM` / `shade` / `weldTo` / `propPart` are gone.
  - State lives in `evCtx` (the function is at the 200-locals cap):
    - `looks` and `jobs`, saved to the hotel attributes `StaffLooks` and `StaffJobs`
    - `job(s)`, `offShift(s)`, `onShift(role)`
    - `deskPace(action)`: false when nobody is on the desk, so the player serves it
    - `wageBill()`: sets the hotel attribute `WageBill`, which the DayEnded wages use
    - `rmul(stat)`, `staffPace`
  - RemoteEvent `Remotes.StaffEdit`:
    - `("look", key, look)`: the name goes through TextService, then the staff member is re-dressed in place.
    - `("job", key, { focus, shift, rooms })`
  - Doorman: waits `C.DOORMAN_DELAY` (3), walks out to the guest, then `C.DOORMAN_WORK` (6) x pace, then `letIn(1)`. Focus `vip` moves an event guest to the front; `warm` gives +3 mood.
- **Timings (Config):** `CLERK_SLOW = 4` (desk x4 when a receptionist serves), `STAFF_CLEAN = 6.5`, `COOK_SECS = 16`, `DOORMAN_DELAY = 3`, `DOORMAN_WORK = 6`. The Upkeep repair is `14 * pace`.
- **Jobs:**
  - Janitor `rooms` + focus `first` / `only`.
  - Cook `pricey`: `Kitchen:nextOrder(focus)`.
  - Handyman `rooms` / `lobby`: `Upkeep:nextJob(from, focus)`.
  - Receptionist `in` / `out`: x0.75 for the chosen action, x1.3 for the other.
  - Shifts `day` / `night`: off shift they idle, and the wage is x0.6.
- **Research stats:**
  - Nodes may carry `bonus = { stat = mul }` and `add = { stat = n }`. `Research.mul(hotel, stat)` / `Research.add(hotel, stat)` are cached on the Research attribute string.
  - Stats:
    - `janitorTime`, `doormanTime`, `deskTime`, `cookTime`, `handymanTime` (in `staffPace`)
    - `staffXP`, `wages`, `walkins`, `price`, `tips`, `patience`
    - `breakEvery` (Upkeep), `mealPrice` (Kitchen:pay), `mealWait` (GuestLife)
    - add `mood` (check-out)
  - New branches `staff`, `stay`, `market`, `dining`, `upkeep` (72 nodes). `Levels.RESEARCH` has the new ids.
  - The ResearchUI tree sits in a scrolling `Canvas` (columns 172 wide, rows 158 tall).
- **Client:** `StarterPlayerScripts.RAH_StaffEdit` (DisplayOrder 26) opens on the player attribute `RAH_StaffEdit = key`; RAH_Coop's team rows have an Edit button. The preview clones the live body (tags stripped) into a WorldModel and calls `StaffLook.dress` locally.
- **Save:** `d.stafflooks`, `d.staffjobs`.
- **Backups:**
  - Studio: `DevTools.Round13_Backup_20261106`, `HotelBuilder_Backup_20261106`, `Catalog_Backup_20261106`.
  - Files: `archive/*_20261106*.lua`.

### Round 14 (2026-11-09): style, hiring, voices, weather, FX
- `ReplicatedStorage.Shared.Hiring`: TRAITS (pros/cons with pace, walk, drain, xp, wage, rest, talk multipliers), `make(def, rng, taken)`, `roll`, `wageFor(def, skill, pro, con)`, `priceFor(def, n, skill)`, `legacy(def, index, name)`. REFRESH 600 s, PER_ROLE 3, REROLL_PRICE 150.
- Hotel attributes: `StaffCands` (JSON `{at, roles}`, BuildServer refreshes it) and `StaffProfiles` (JSON keyed `def.id .. index`, saved by Save as `d.staffprofiles`). Build remote: `("hire", roleId, candIndex)`, `("cands")`, `("reroll")`.
- HotelSim: `evCtx.Hiring`, `evCtx.profiles()`, `evCtx.setProfile`, `evCtx.shiftProfiles(def, idx)` (on firing). Staff models carry Voice, Deep, StaffSkill, TraitPro, TraitCon, Wage.
- `ServerStorage.Voice`: new styles country, foodie, nerd, dreamer, sporty, tourist, with `V.flavor` habits.
- `StarterPlayerScripts.FX` (new): Notify paid / cleaned / built / upgraded / roomBuilt / hired, pooled burst slots `Terrain.Burst1..10` (coin, sparkle, bubble, dust, confetti emitters) and Neon rings in `workspace.FXLocal`. Counts follow `SavedQualityLevel`.
- Audio: a DEFS id may be a list (random variant, no repeat); new names `doorSoft`, `handle`, `patter`. Doors plays handle + creak/soft on open, latch on shut.
- WeatherFX: LOOK gains `wind` and `mist`; layers `Near.RainNear` and `Ground.Mist`; noise gusts; quality budget.
- Crowds: umbrellas are a `Hub` part on a Weld (C0 tweened U_SHUT to U_OPEN), canopy SpecialMesh scale pop, rib tips, a `Drip` ring emitter; `closeUmbrella(p)` folds and destroys.
- TutorialClient: global `StaffRoomOk()` (wraps `Build.staffRoom`), new hiring step (counts every `C.STAFF` attr).
- ChatCommands /preset: walled staff room in a lobby corner (`Wall` x5 + `Door`, 12-stud square), profiles for every staff slot at skill 5, cash to 250k.
- Catalog: WaterCooler is `cat = "staff"`, no research.
- Backups: `ServerStorage.DevTools.Round14_Backup_20261109` (Coop, Minigames, Crowds, Audio, WeatherFX, TutorialClient).
### Round 14b (2026-11-09): furniture remodels, image-packed mesh import
- **The Assistant's HttpService can't reach 127.0.0.1 any more** ("not in the Assistant HTTP allowlist"). Game scripts in a playtest still can, but `CreateAssetAsync` only works in Edit.
- **Import route now:** pack the mesh JSONs into a PNG (4-byte big-endian length + JSON `{file = meshJson}`, 3 bytes per RGB pixel, alpha 255), serve it on 8790, `upload_image` it, then in Edit: `P = require(ServerStorage.DevTools.ImagePack:Clone())`, `all = P.load(assetId)`, `P.swap(itemId, {{file, group}}, all, backupFolder)`. `swap` replaces `Shared.Items.<id>` MeshParts and keeps each old part's material, colour, flags, children (lights) and attributes. Packing snippet: see the Python in this round's session (PIL `Image.frombytes('RGB', (side, side), data)`).
- New models in `rah_props_r14b.py` (exec'd last by rah_props.py): IndoorPalm (8.7k tris), CoffeeTable, FloorLamp (shade in `main`, only the bulb in `glow`; Glow = Neon 255,226,186 + PointLight). Old item models in `DevTools.Round14_Backup_20261109` as `Item_<id>`; old Phone as `Phone_pre14b`.
- Phone: shadows `UI.T` with a local dark-screen palette (cream/muted light, ink dark) via `setmetatable({...}, {__index = UI.T})`.
- Crowds umbrellas weld to `RightHand` (`U_GRIP`, `U_HAND_OPEN/SHUT`, hub attribute `Hand`, model `Carry = "umbrella"`); NPCAnim tracks `workspace.StreetCrowd` rigs within `STREET_FAR = 75`.
- Round 14c: `rah_props_r14c.py` (exec'd after r14b) remakes Armchair (rust velvet), Sofa (teal velvet, knit throw), Wardrobe (walnut armoire), Bookshelf (walnut, decorated shelves); each now has a `Chrome` part (brass). Helpers there: `_place(ob, loc, rot)` turns a mesh about its own centre (the base `box(... rot)` + later `rotation_euler` turned about the world origin), `_drape` (solidified cloth strip), `_leg`, `_rolled_arm`. Pack asset 111634508406169. Placed copies in `Hotel.Placed` were re-meshed in place.
- Round 14d: `rah_props_r14d.py` (after r14c) remakes the room upgrades: BedDeluxe / BedDeluxeMessy, BedSuite / BedSuiteMessy (built as separate props, swapped into `Items.<bed>.Clean` / `.Messy`), ToiletDeluxe, ShowerRain (new `glass` side panel), Vanity (mirror face is in `main`, so the old Glass part was removed). Use spots unchanged (mattress top 2.35, seat 1.55, rain head at (0, 0.5, 8.0)).
- `ImagePack.swapModel(model, groups, all)` swaps into any model and deletes MeshParts with no new counterpart; `swap(itemId, ...)` wraps it. **After a swap, reset `Color` to white**: the old parts' tint is copied with the look and recolours the vertex colours (it turned the suite duvet lavender). Packs over ~3 MB must be split: keep each PNG at most 1024 px a side (r14d used three: 131283696339430, 140377557329791, 127472987641627).
- Round 14e: `ReplicatedStorage.Shared.NPCGait` (source `Run a Hotel tools/src/NPCGait.lua`) is a procedural walk/idle for R15 NPCs: keyed periodic curves (HIP, KNEE, ANKLE, BOB, SWAY, BREATH), STYLES (normal, brisk, bouncy, stroll, stomp, sneak) picked by `Gait.styleOf(model)` from attribute `GaitStyle`, else GuestType, else BRole (brisk), else Persona. `Gait.new(model, rig, rng)`, `Gait.step(g, dt, root, out, now)` returns the walk weight. Test hooks: model attributes `GaitSpeed` (fake speed) and `GaitPhase` (held phase). `NPCAnim` keeps the stock-track pose in `st.anim`, blends `st.base = anim:Lerp(gait, gaitW)`; gaitW goes to 0 while seated, emoting (a non-core track at weight > 0.3), frozen or in an `ownsBody` pose. Backup `DevTools.Round14_Backup_20261109.NPCAnim_pre14e`.
### Round 15 (2026-11-10): remakes, luggage, star guests, cutscenes
- **Script push route:** source mirrors in `Run a Hotel tools/src15/*.lua`; `python push.py <names>` packs them into `export/code_<n>_0.png` (served on 8790), `upload_image`, then in Edit `require(ServerStorage.DevTools.ImagePack:Clone()).push(assetId)` (compile-checks; creates missing scripts). Small live edits: string-replace `Source` + `ScriptEditorService:UpdateSourceAsync` from `execute_luau` (Edit only). `script_grep` in Play mode searches only the client data model.
- Build: `Shared.RoomPlan`, the Studio-only BuildDev hook in BuildClient, `sellingRoom`, `input.clickDown`. Plots `PLOT_W = 320`; save slots 108-111.
- MapBuilder `garden(lot, cx)` works from `local Y = 2` (terrain surface is y = 2.0); rebuild with `require(MapBuilder:Clone()).build()`.
- **Luggage:** `rah_props_r15.py` (exec'd last by rah_props.py) builds CaseSpinner, CaseCarryOn, CaseVintage, Weekender, Briefcase, Handbag, Backpack, GuitarCase (origin = bottom centre) into `ServerStorage.HotelProps`, with attributes `Kind` (roll / hand / back), `CaseTop`, `CaseHZ`, `CaseWZ` (rollers) and `HangY` (hand bags). HotelSim's `Lug` table: `Lug.LIST` weights, `Lug.BY[eventId or guestType]`, palettes `Lug.COL`, `Lug.pick(w)`. `holdBag`: roll = weld to root (Carry "case"), back = weld to UpperTorso + two `PackStrap` parts (`b.straps`), hand = weld to RightHand at `HangY` (Carry "bag"). NPCAnim's `luggageOf` reads `CaseTop/CaseHZ/CaseWZ/HangY`.
- **Staff tools:** `Shared.StaffGear` (Mop, Broom, Wrench, Clipboard; origin = grip; parts Body/Trim/Chrome/Tint). StaffLook `gear(to, name, c0, tint)` clones and welds them (the first weld is the animated one: `refs.mopWeld`, `refs.toolWeld`).
- **Guest bodies:** `Bodies.classicFace` turns `Humanoid.AutomaticScalingEnabled` off and pins `ClassicHead.Size = (2, 1, 1)`: the humanoid scaler was stretching the classic head by BodyWidth/Depth/Height scale (wide flat faces on broad/round bodies). `Looks.gear` adds `top` (jacket, puffer, cardigan, vest, blazer, scarf, tie), `topColor`, `topColor2` (`Looks.TOP_COLORS`); `Bodies.dress` builds it from parts welded to the torso and arms. The body bag is only ever `cross` now (backpacks are luggage).
- **Star guests** (GuestEvents): `E.STAR_CHANCE = 0.07`, `E.STAR_GAP = 300` (hotel attribute `StarAt`, os.clock); needs grade >= 2 or level >= 6. DEFS rockstar, royal, critic, mystery, tycoon with `star`, `who`, `title`, `icon`, `gift`, `lines`, `happy`, `sad`; `LOOKS[id]` with helpers `shimmer`, `shades`, `coat`, `noHair` (hides hair/hat accessories and the body's `Gear`). HotelSim `adoptGuest`: star guests get `BName = who`, model attribute `Star = id`, and Notify `cutscene {kind = "star", model, name, title, line, icon}`; checkout adds `ev.gift` when met. Studio hook: hotel attribute `TestEvent = "<def id>"`.
- **Cutscene** (`StarterPlayerScripts.Cutscene`, new): Notify `cutscene` (star) and `gradeUp` (orbit). Skips while `Building`, `InTalk` or a Minigame/MainMenu/Loading gui is up; one queued. Sets player attribute `InCutscene`, freezes the humanoid (no PlayerModule in PlayerScripts), hides other ScreenGuis, letterbox, title card, skip on any input; camera clears obstacles with a ray that ignores only the subject. Studio hooks: player attribute `TestCutscene = "star" | "grade"`, `CutsceneHold = n` parks the camera inside shot n.
- Minigames: a star clock card (`Clock`) next to the close button (stars from `C.ICONS.star` / `starEmpty`, the same par and mistake rules as the result). ResearchUI: tree column width `clamp((tw - 24) / maxTier, 124, 210)`. Audio: `CompressorSoundEffect` on the SFX group, `EqualizerSoundEffect` on Music, `LAYERS` (coins, register, place, fixed, jingle play a second sound 0.03 s later).
- Pack assets 89795856691455 / 86461767850450 (luggage and gear meshes).
- Backups in `ServerStorage.DevTools`: BuildServer, Street, Build, Config, Levels, MapBuilder, StaffLook, HotelSim, NPCAnim, GuestEvents, Bodies, Looks, ResearchUI, Audio, Minigames `_Backup_20261110`; BuildClient_Backup_20261110; MainMenu_Backup_20261109.
- **Staff wear (round 15b):** `ReplicatedStorage.Shared.StaffWear` holds 13 modelled pieces (built by `Run a Hotel tools/rah_props_r15b.py`, pack 94929688831727): hats `WearPeakedCap`, `WearTopHat`, `WearToque`, `WearHardHat`, `WearCap`, `WearBeanie` (origin = head centre, built for a 1.16 head); torso shells `WearGreatcoat`, `WearBlazer`, `WearChefJacket`, `WearApronBib` (origin = UpperTorso centre, built for 1.94 x 1.7 x 1.0); waist pieces `WearCoatSkirt` (2.43 long), `WearBlazerSkirt` (0.93), `WearApron` (1.82) with their top at +0.18 of the LowerTorso. Built facing +Z, so StaffLook turns them round. MeshParts `Body` (tinted colour a), `Tint` (colour b), `Trim` / `Chrome` (own colours), Color white = vertex colours.
- StaffLook.dress helpers: `wear(to, name, cf, k, a, b)` (clones, scales Size by the Vector3 `k` about the origin, welds), `shell(name, a, b)` (also pushes `FZ` out so onChest details sit on the jacket), `hang(name, len, full, a, b, dz)`, `hat(name, a, b, ky)` (sets `modelHat`, which hides every hair accessory). Each modelled piece falls back to the old part-built one if `StaffWear` is missing. Still part-built: Tailcoat, Short Jacket, Waistcoat, Polo, Tuxedo, the janitor tops, Hi-Vis Vest, Flannel, Coveralls. Backup `DevTools.StaffLook_Backup_20261110b`.
- Minigames Floor: `compost` (65 %) adds a COMPOST bin at (0, 0, 5.4); `binOf` sends banana and apple there.
- Cutscene: the play loop re-hides ScreenGuis enabled mid-cutscene (not in `KEEP`).

### Round 16 (2026-11-10): faces, gender, beep voices
- `Run a Hotel tools/faces16.py` draws `export/f16/*.png` (sheet `export/face16_sheet.png`). Eye styles: fa fb fc fd (female), ma mb mc md (male), ka (kid), ea (elder), each in 11 states. Brows thin/soft/straight/bushy/kid in 7 kinds. Mouths m/f in 13 shapes. Also nose_1..3, mark_1..5, fhair_1..5 and blush. Brows and facial hair are drawn white and tinted with Decal.Color3.
- `Shared.Faces`:
  - tables `EYES[style][state]`, `BROWS`, `MOUTHS.m/.f`, `NOSE`, `MARK`, `FHAIR`, `TONES`, `BROW_OF`
  - `roll(rng,{female,kind,tone})` and `wear(ch, model, f)`. Decals: FaceNose/FaceMark/FaceExtra z1, FaceHair z2 (beard/stubble Transparency 0.25), FaceUpper z3, FaceBrow/FaceMouth z4
  - model attributes FaceStyle, FaceBrow, FaceLips, BrowColor
  - helpers `eyeTex`, `browTex`, `mouthTex`
  - legacy styles a/b/c are aliased
- Gender:
  - `Looks.isFemale(name, rng)` (unisex names flip a coin); `HAIR_F/M/U`, `ELDER_F/M`, `HAIR_TONE`; `Looks.description(rng, kind, female)`
  - `Bodies.make` sets model attributes Female and HairTone
  - StaffLook rolls the face from the name hash
  - NPCAnim swaps eyes, brows and mouth through the helpers
- Voice:
  - `Shared.VoiceFX`: one beep per syllable (BEEP 6467449877, BOOP 9120232166); `voiceOf(name, deep, female)`; `speak(part, line, base, {volume, dur})`
  - `Shared.Speech` routes the TTS through `robot()`: PitchShifter, Bandpass 1250, Distortion, Tremolo 17 Hz, then Lowpass12dB 3600 (the enum is `Lowpass12dB`, not `Lowpass`). TTS volume x0.8, with the beeps on top
- Backups `DevTools.*_Backup_20261110c`: Looks, Bodies, StaffLook, NPCAnim, Faces, Speech, VoiceFX.

### Round 16b (2026-11-10): city remake
- **Materials:** `tex_r16.py` writes `export/t16/<name>_{c,n,r}.png` (colour, normal, roughness; light and neutral so `Color` tints them). MaterialService variants `R16_Brick` (Brick), `R16_Stucco` (Plaster), `R16_Stone` (Limestone), `R16_Asphalt`, `R16_Paver` (Pavement), `R16_Roof` (Slate), `R16_Tower` (Metal), `R16_Leaf` (LeafyGrass), `R16_Bark` (Wood). Materials project by studs on UV-less MeshParts, and vertex colours multiply them.
- **Kit:** `rah_props_r16.py` (exec'd last by rah_props.py) builds WinA..WinE, Cornice, Belt, Pilaster, ShopWin, ShopDoor, Awning, RoofTank, RoofAC and new TreeA/B/C and Bush. Facade pieces: origin on the wall plane, facing Roblox +Z. Groups: trim, main, glass (part `Window`), paint, paint2, metal, chrome, bark, leaf.
- **Import:** `python pack16.py <tag> <props>` makes `export/_<tag>_<n>.png` (manifests included); `upload_image`; then `K = require(DevTools.Kit16:Clone())`, `K.open(assetId)`, `K.import({names}, "CityProps")` (4 to 6 props per call), `K.close()`. Looks per group are in `Kit16.LOOKS`.
- **MapBuilder:** the new `building`, `skyline` and `restyle` live in `src15/_mapbuilder16.lua` (sections `--@@BUILDING`, `--@@SKYLINE`, `--@@RESTYLE`). Pack it as `{mb16 = text}`, upload, then `require(DevTools.PatchMB16:Clone())(assetId)` splices it in, compile-checks and rebuilds the city. Helpers: `skin(part, kind, color)`, `kit(parent, name, cf, kx, tints)` (kx stretches along X; small groups cast no shadow), `run(...)` tiles 8-stud pieces. Lit windows are the kit's `Window` parts with `LitColor`. `restyle()` also turns the turf under both sidewalks into Ground.
- Backups: `DevTools.Round16_Backup_20261110` (City, MapBuilder, CityProps).

### Round 20 (2026-11-11): seaside city, hotel look stages, upgrades, intro, commands
- **City (replaces round 16b's shops and towers):** `src15/_mapbuilder16.lua` now holds the seaside. `shops()` = `beach()` terrain + the promenade (z 126..150, `PROM_Z`), `skyline()` = pier (`PIER_X = S.CROSS[2]`), boats, lighthouse, buoys; `restyle()` = surfaces, the road median and hill palms (`City.Backdrop`). `Shared.Street` is unchanged. Terrain facts: a water `FillBlock` doesn't replace turf, so clear to Air first; terrain smooths about 2 studs above a block top, so clear over decks.
- **AI meshes:** `generate_mesh` (segmentation none) drops a Model named after its prompt in workspace. `DevTools.Gen16`: `adopt(prefix, name, "CityProps", yaw)` makes a library template (pivot = bottom centre, yaw 180 turns the generated front to +Z); `swap(prefix, itemId)` / `swapAll` put a mesh into `Shared.Items.<id>` as `Body`, stretched to the old item's box. Old non-Body parts stay as invisible stubs (attribute `Stub`) because lights and scripts hang off them; placed copies in `workspace.Hotel.Placed` are renewed. About 8 generations at a time before the rate limit. `HotelProps` was not updated, so `HotelBuilder.makeItems` would bring the old models back.
- CityProps `TreeA/TreeB/TreeC` are now a coconut palm, a royal palm and a flame tree; also `PalmS`, `BeachCafe`, `IceCream`, `SurfShack`, `Gazebo`, `UmbrellaSet`, `Lifeguard`, `Sailboat`, `Yacht`, `Lighthouse`, `RowBoat`, `GlobeLamp`, `PlanterUrn`, `Bench`, `TrashBin`, `Balustrade` (Blender).
- **Upgrades:** `Shared.Upgrades` (`LIST`, `level`, `cost`, `effect`, `fold`, `look`); hotel attribute `Upgrades` (JSON), saved as `d.upgrades`. `Research.totals` folds them in, so `Research.mul/add` return research x upgrades; new stat `arrivals` divides the arrival gap in HotelSim. `ServerScriptService.Upgrades` handles `Remotes.Upgrade:InvokeServer(id)`. `StarterPlayerScripts.UpgradesUI` fills Coop's `Page_upgrades` (new entry in Coop `TABS`).
- **Hotel look:** `ServerStorage.HotelSkin` dresses parts by kind (attribute `SK`, with `SF`/`SC`) for stage `Upgrades.look(hotel)` = curb level + (Grade - 1), 0..4; hotel attribute `Look`; props in `<hotel>.LookDecor`. `ServerScriptService.HotelSkin` watches every plot. HotelBuilder is untouched.
- **Intro:** Cutscene `runIntro` on Notify `cutscene {kind = "intro"}`; Tutorial sends it before `tut2` and waits for `TutSkip "introDone"` (40 s cap).
- **Commands (ChatCommands, admin):** season ones set Shared attribute `SeasonForce` (read in `Clock.date`), weather ones set `TestWeather`, `/event<id>` sets the hotel's `TestEvent` + `TestSpawn` (the Studio-only gate in GuestEvents is gone), `/intro`, `/look n`, `/upgrades`, `/commands`.
- Snippets for Cutscene and ChatCommands: `src15/_patch20.lua`. Backups: `DevTools.Round20_Backup_20261111` (patched scripts), `DevTools.Round16_Backup_20261110` (old City, CityProps, Hotel, Items).

### Round 20b (2026-11-11): beds, showers, cars
- `DevTools.Gen16` additions: `take(prefix)`, `put(target, mesh, yaw)` (mesh becomes the target model's `Body`, others become stubs), `swapBed(cleanPrefix, messyPrefix, itemId)` (fills `Clean` and `Messy`, also in placed copies), `swapCar(prefix, kind)` (yaw -90: cars run along +X; fills `Shared.Cars.<kind>` and `CityProps.<kind>`).
- **Bed facing:** a bed body sits 180 degrees from the item pivot. Replacing every part of a sub-model moves its `WorldPivot`, so check facing on the whole item, never on a cloned `Clean` / `Messy` (that misled one round of checks).
- **Car tint:** a textured MeshPart ignores `Part.Color`. Car bodies carry a `SurfaceAppearance` (ColorMap = the generated texture, white paint) with attribute `Group = "paint"`; Traffic and MapBuilder's `prop()` now set `SurfaceAppearance.Color` as well as `Part.Color`. Old wheels, lamps and glass are invisible stubs (wheels still spin, unseen); `CityProps.CarWheel` is invisible.
- Backups: `Round20_Backup_20261111.Cars` and `.Traffic`; old beds and showers are in `Round16_Backup_20261110.Items`.

### Round 21 (2026-11-12): UI style "Clean", HUD, save files
- **Shared.UI** keeps its API; the look is new. `tools/ui21_apply.py` swaps tokens and 25 functions from `src15/_ui21_parts.lua` into the mirror (old one: `src15/_UI_r15v2_backup.lua`). Tokens: light cards (`ink`, `ink2`, `ink3`, `line`, `cream` = text), `brand` blue, and the HUD's dark glass `hud`, `hud2`, `hudLine`, `hudText`, `hudMuted`. `gloss`, `shine`, `sparkles`, `wordRim` do nothing now. `UI.G` = flat white glyphs (`tools/ui21.py` -> `export/g21`). `UI.toast` is the new notification (merges repeats, max 4).
- A colour pass rewrote every violet / lavender `Color3.fromRGB` literal in the UI scripts to blue / neutral (hue 0.62..0.84).
- **Client** top HUD = `src15/_hud21.lua` (same local names as before, so the rest of Client still works). **BuildClient** dock = `src15/_dock21.lua` (`barButton` still returns 7 values). **Coop**: the tab bar is hidden, pages moved up 42 px.
- **MainMenu** and **Loading** are new scripts (mirrors in src15). **Save files:** `Save.key(player, slot)` -> `u_<id>_s<1..3>`; `lastSlot` keeps the file for a wipe; a file with no data resets Cash and stats. Remotes.Menu: `("slots")` -> `{ ["1".."3"] = summary }`, `("play", n)`, `("delete", n)`.
- New scripts: `CommandsUI` (Notify `commands`), `ToolAim` (re-aims Mop / Broom welds each frame on the client).
- `Faces.wear` now puts one classic Roblox face decal (`F.CLASSIC`, picked by name); no `FaceUpper`, so NPCAnim's face code stays idle.
- Smaller UI: prompts `PS * 0.72`, Bubbles scale `* 0.72`, Talk `BASE = 1880 x 1080`. VoiceFX volume `* 0.55`, TTS `* 0.65`.
- Lighting night keys: brightness 0.6, exposure -0.3. Lamp PointLights are about a third as bright.
- Backups: `DevTools.Round21_Backup_20261112`.

### Round 22 (2026-11-11): empty start, free land, hotel styles
- **Template:** `workspace.Hotel.Placed` is empty now (old contents in `DevTools.Round22_Backup_20261111.TemplatePlaced`). Rooms 101-103 start `Unfurnished`; HotelSim opens a room when it gets a Bed, Shower and Toilet. Old saves rebuild their core items from `data.items` (Save's "not found" branch).
- **Save.load:** when the file has no data, `Builder.buildLand` runs for slots 104 and 105 (free land both sides), then NextRoom / NextRoomPrice and `ItemsChanged`. `C.START_CASH = 900`.
- **Styles:** `Shared.Upgrades.STYLES` / `STYLE_DEFAULT` / `U.style(hotel)`; hotel attribute `Style` (JSON `{lobby, rooms, walls, roof}`), saved as `d.style`. `Remotes.Upgrade:InvokeServer("style", key, id)` sets it (free).
- **HotelSkin:** part kind attribute is `SK3` now. Name-based kinds come first: `LobbyFloor` -> `s_lobby`, `Floor` under `Rooms` -> `s_rooms`, `Paper` / `PierIn` / `HeaderIn` / plaster `Core` -> `s_wall`; `tile` / `roof` kinds take the roof style from look stage 2 up. `Skin.dress(p, stage, style)`, `Skin.apply(root, stage, style)`. `watch` re-applies on `Style`, and again after 3 s and every 25 s (HotelBuilder's starterStyle repaints its parts). Decor rebuilds only when `DecorStage` changes.
- **UpgradesUI:** "HOTEL STYLE" rows (`Style_<key>`) under the upgrade cards. **TutorialClient:** steps 2 and 3 are "Open your first room" and "Close build mode".
- Edits scripted in `Run a Hotel tools/patch22.py`. Backups: `DevTools.Round22_Backup_20261111`.

### Round 23 (2026-11-11): build mode UI
- `BuildClient` keeps its logic; two UI blocks were replaced from `Run a Hotel tools/src15/_build23.lua` (split at `--@@B`): "key hints" up to "shape editor", and "selection pill" + `layout`. Spliced live by section markers; the src15 BuildClient mirror is stale (pull the live script before editing).
- Same local names as before, so the logic is untouched: `hintWrap/setHints/HINTS_*`, `shopWrap/shopHolder/list/cards/tabsApi.select(id, silent)/searchInput/thumb/room/refreshCards`, `toolWrap/toolHolder/S.rbRailBtn/S.setZones/S.undo`, `barWrap/bar/barBtns/heightPill/heightText`, `cardWrap/cardHolder/cardTitle/cardSub/cardBtns/cardActions`, `layout`.
- Catalog = `UI.panel` (light) at the left; tiles in a UIGridLayout; thumbnails are lazy (`wantThumb`, 4 a frame, only for tiles shown while building). Tool bar chips are `toolChip(label, options, current, order, tip, cb)` (click cycles). Bars are dark glass (`T.hud`).
- Slides: catalog from the left (-460), tool bar from below (120). `placeCard` uses 540 x 104. RoomBuilder wrap is 330 x 664 at y 84.
- `user_mouse_input` y is 58 px less than the screenshot's y (top bar inset).
- Backup: `DevTools.Round23_Backup_20261111.BuildClient`.

### Round 24 (2026-11-12): menu pages
- `StarterPlayerScripts.Coop`: everything between the "hotel page" and "tabs + open/close" markers was replaced from `Run a Hotel tools/src15/_menus24.lua`. Each page is a `do` block that fills `pages.<id>` and sets one of the forward locals `refreshHotel`, `refreshAll`, `refreshHire`, `refreshAch`.
- Shared helpers at the top of that block: `block(parent, h, order)` (flat card, h = 0 grows), `caps`, `meter(parent, pos, size, color)` -> fill, `pills(parent, items, current, order, onPick)`, `pageRoot(P)`, `column(root, pos, size, gap)`, `figure(parent, caption, order, color)`.
- The older helpers above it (`row`, `rowIcon`, `heading`, `columns`, `tile`, `stars`, `hotelQuests`) are still there; only `stars` and `hotelQuests` are used by the new pages.
- `showTab` finds the header icon with `FindFirstChildWhichIsA("ImageLabel", true)`.
- Pull a live script to disk: return its Source from `execute_luau` padded past the size limit, so the result is saved to a tool-results file (`live/Coop.lua` was made this way).
- Backup: `DevTools.Round24_Backup_20261112.Coop`.

### Round 25 (2026-11-12): Upgrades page
- `StarterPlayerScripts.UpgradesUI` rewritten (mirror in `src15`, pushed with `push.py`). It builds `Page_upgrades.Root` with `Left` (`Comeback` card for `curb`, then `Grid` with one card per other `U.LIST` entry, named by id, each with a `Buy` button) and `Right` (`Style_<key>.Swatches.<finishId>` buttons).
- Buy buttons are `green` when `player.Cash >= cost`, `ink` when not, disabled at max. Redraws on the hotel's `Upgrades` / `Grade` / `Style` and the player's `Cash`.
- Backup: `DevTools.Round25_Backup_20261112.UpgradesUI`.

### Round 26 (2026-11-12): Research page
- `StarterPlayerScripts.ResearchUI` rewritten (mirror in `src15`; the old one is in `live/ResearchUI.lua`). Logic, remotes and attributes are unchanged (`OpenResearch`, `ResearchOpen`, `Remotes.Research` "start" / "cancel").
- It clears `Page_research` and builds `Lab` (bar, `Stop`), `Branches` (rows named by branch id), `Tree` (`Canvas.Nodes.<nodeId>` cards, `Canvas.Lines` elbows) and `Card` (`Info`, footer with `Start`). The page is laid out for 1240 x 830.
- `showBranch(id, focus)` lays tiers out as columns (width 128..200); `refresh()` runs every 0.5 s while open.
- Backup: `DevTools.Round26_Backup_20261112.ResearchUI`.

### Round 27 (2026-11-12): staff work on the real objects
- **Contract:** with a work pose the server also sets the model attribute `WorkAt` (Vector3, the point on the object). Poses in `Shared.NPCAnimLib` with `anchor = { R, L }` write their hand keys in studs round that point (x = their right, y = up, z = toward them). `NPCAnim` turns them into arm targets each frame (`handTarget`) and leans / crouches the body until the hands reach (`st.lean`; `noLean`, `minCrouch` per pose). With no `WorkAt` the arms are left alone.
- **New poses:** `makebed`, `scrub` (prop `Brush`), `wipe` (prop `CleanKit`), `dust` (prop `Duster`), `fixat`, `cookat` (prop `CookKit`), `deskkeys`. `Lib.ANCHORED.desk` swaps `desk` for `deskkeys` when a part named `Keyboard` is found in the hotel's desks (`findNear`; kit parts don't answer spatial queries). The old `fix` / `cook` / `desk` poses stay as fallbacks.
- **Server (`HotelSim`, all in `evCtx` because of the local limit):** `workPoint(g, model, mode, inset, fallY)` raycasts the model itself (`"top"`, `"face"`, `"low"`), `workStart` steps them to 1.25 studs from its face (1.9 for `"low"`) and sets `WorkAt`, `workEnd` clears it, `workOn` wraps a timed job. Mode `"inside"` (walk-in shower) uses `pose` / `unpose` to stand them inside facing the back wall. `evCtx.WORK` maps Bed / Toilet / Shower to their pose. `Upkeep` (repairs) and `Kitchen` (cooking) call `ctx.workStart` / `ctx.workEnd`. Only janitors take the dust / tidy idle jobs now.
- **Mop:** `Lib.TOOLS` (head and top-hand distance from the grip), `Lib.TOOL_CARRY`. `NPCAnim.toolOf` finds the weld (it is parented to the mop part, with `Part0` = RightHand, which is why the old `ToolAim` never found it; `ToolAim` is now disabled). `stepTool` keeps the head on the floor toward the pose's `hx` / `hz` channels, solves the left hand onto the handle, and for any pose but `mop` stands the mop beside them (the weld's `Part0` is switched to the root locally).
- Mirrors in `src15`: NPCAnimLib, NPCAnim, HotelSim, Upkeep, Kitchen. Backup: `DevTools.Round27_Backup_20261112`.

### Round 28 (2026-11-12): build mode handling
- `BuildClient` (the `src15` mirror is current again; `Run a Hotel tools/live/BuildClient.lua` is the pre-round copy). The script has about 174 top-level locals, so everything new hangs off `S` or `input`.
- **Press modes:** on left press `input.downOn` = the placed model under the cursor. Once the cursor has moved 7 px with no ghost, `S.beginDrag()` sets `input.mode`: `"grab"` (`makeGhost(id, model)` with `ghost.grab` and `ghost.off`, the XZ offset from the press point to the pivot; release commits or cancels), `"pan"` (`S.pan = { anchor }`), or `"none"` (booked room). With a ghost in hand left-drag is still the row drag.
- **Pan:** in the `BuildLook` render step (after `BuildCam`) the grabbed floor point is kept under the cursor by shifting `cam.focus` and `goal.focus`. Middle button sets `S.pan.mid`.
- **Zoom:** scrolling in moves `goal.focus` toward the floor point under the cursor; scrolling out stays centred.
- **Cutaway:** `S.walls` ("cut" / "full"), `S.cutScan()` (every 1.5 s: tall thin parts of Shell / Rooms / Doors behind the facade line, plus placed structure items), `S.cutStep(dt)` fades those on the camera's side of `cam.focus` to `LocalTransparencyModifier` 0.9, `S.cutRestore()` on leave. `placedAt` and `aimHit` skip parts faded past 0.5.
- **Feedback:** `Shared.Build.validate` sets `Build.lastBlocker` (the placed model in the way); `S.blockHL` outlines it; `S.foot` is the footprint part (`ghost.boxOff` / `ghost.boxSize`).
- **Undo:** `S.undo` entries may be `{ move = uid or "desk", cf = oldPivot }` (from a move or a Turn); `S.doUndo` sends the old pivot back.
- Backup: `DevTools.Round28_Backup_20261112` (BuildClient, Build).

### Round 29 (2026-11-12): hotel front
- Heights at a plot front: road 0, pavement 0.5, entrance path 0.5, hotel floor and tarmac `FY` = 1 (0.98), lawn about 2.
- `HotelBuilder.parking` (edited live, no src15 mirror): per lot it now also builds `Verge` (paving from the kerb to z 57.05), `DriveBase` + `Drive` (a 12-stud sloped driveway in the middle of the street side), `Forecourt` (paving between the path edge at x 8.5 and the lot), `SignPost` + `ParkSign`. The street-side and path-side kerbs are `FY + 0.28`; the back and outer kerbs stay `FY + 1.1` (they hold the lawn). Terrain is cleared from `FY - 3` up over the paving, and lot decor standing in the forecourt is lifted onto it.
- Template terrain: `Ground` was replaced with `LeafyGrass` in x -212..212, z 28..64 (the region each plot copies).
- `HotelSim.parkCar` scales a guest car (`ScaleTo`) to at most 14.6 x 6.4 studs.
- Car paints (140,30,40) and (30,60,110) became (206,84,84) and (70,120,200) in `Traffic` and `MapBuilder`; the parked cars in `City.Parked` were repainted.
- Backup: `DevTools.Round29_Backup_20261112` (HotelBuilder, MapBuilder, Traffic, HotelSim).

### Round 30 (2026-11-12): guests on the real things
- Same contract as round 27 (`WorkAt` + anchored poses). New poses in `Shared.NPCAnimLib`: `counter`, `pay` (prop `Card`, welded to the **left** hand so `Lib.CARRY` can keep the right), `turndown`, `tap`, `flush` (anchored) and `wash` (body space, hands on the head).
- **HotelSim:**
  - `deskService` is now `local deskService do ... end` (no new top-level local): the old body is the inner `serve`; the wrapper finds the nearest `Build.desks(HOTEL)` within 7 studs, calls `evCtx.workStart(g, desk, "top", -0.05, 3.4)`, plays `@counter` (check in) or `@pay` (check out) and always ends with `workEnd`.
  - Desk geometry: the guest `Ledge` (front 1.64, top 3.69 above the floor) overhangs the `Inset` panel (front 1.26) that `workPoint`'s floor+1.3 ray hits. Guests stop against the ledge about 0.4 short, so the inset is -0.05 (mid-ledge) and `counter` / `pay` are `noLean` (leaning can't reach a chest-high point; it folds them over the counter).
  - `stayIn` Toilet: unpose facing the toilet, `workStart(..., "top", 1.2, 2.6)` + `@flush`, the flush sfx 0.6 s in. Shower: `workStart(..., "inside")` (falls back to the old `pose`), `@tap`, water on, `@wash`, `@tap`, water off, `workEnd`. Bed: `workStart(..., "top", 0.8, 2.4)` + `@turndown` for 2.6 s before the lie pose.
- `workStart`'s walk stops within 0.45 studs (or 1.8 s), so guests usually stand about 0.5 short; non-`noLean` poses make it up by leaning.
- Pose sheets for checking: clone a guest into a folder under the hotel, anchor it, set `Pose`, `WorkAt` and `AnimT` (freezes the time). Live guests move on too fast to screenshot.
- Studio's Assistant blocks `HttpService` to localhost, so the 8791 push doesn't work from `execute_luau`; `multi_edit` with exact strings does.
- Mirrors in `src15`: HotelSim, NPCAnimLib. Backup: `DevTools.Round30_Backup_20261112` (HotelSim, NPCAnimLib; the folder also holds LevelCommands, Plots and BuildServer from earlier the same day).

### Round 31 (2026-11-12): optimisation pass 1
- Measured on slot 1 in a playtest: about 60 fps, 96.7k instances, 12.4k parts, 306 lights, 2.4 GB, 3.5k Lua threads, 861k triangles.
- Client profile (ScriptProfilerService, 6 s): NPCAnim step about 1.1 s, Traffic 0.6, Doors 0.2, Roof 0.2, Perf 0.1.
- Traffic (live only): spawnCar destroys invisible childless parts except Glow (it carries the SpotLight). The wheel parts were all invisible, so wheel lists are now empty. Cars went from 206 to 32 parts.
- Roof (live only): the RoofStamp attribute and the per-frame `#roof:GetDescendants()` are gone. A `watch(roof)` connects DescendantAdded/Removing to a dirty flag and reconnects when the Roof instance changes.
- NPCAnim: early return before the joint Transform reads when an NPC is past FAR and `st.wrote` is false.
- Backups: ServerStorage.DevTools.Round31_Backup_20261112 (Traffic, Roof, NPCAnim, Doors, Perf).
- Server profile (10 s, slot 1): about 0.35 s of script time in total (Plots 0.17, Crowds 0.13, HotelSim guest/staff loops under 0.1 each), heartbeat 0.33 ms, physics 1.5 ms. Nothing worth fixing.
- Not done yet: NPCAnim's per-joint cost for near NPCs, 306 lights, triangle count.

### Round 45 (2026-11-13): all build-mode panels match the white HUD
- BuildKit (mirror): `glass(f, r)` is now the HUD plate (white to 244,247,250, rim 232,237,244 at 2.5), so the selection bar, Placement panel, View and Paint menus are white. `INK` 34,44,64 is `txt`'s default colour; `MUTED` 96,108,130, `CHIP` 240,244,250, `CHIP_HOVER` 222,232,248, `LINE` 214,222,234 (number field strokes); number fields are white with INK text. The 3D tip over the ghost (`tipFrame`) stays dark.
- BuildClient (mirror): `T` is `UI.T` with white hud colours (`hud` white, `hud2` 240,244,250, `hudLine` 214,222,234, `hudText` 34,44,64, `hudMuted` 96,108,130), so the key strip on top, the place bar and its height pill turn white without touching Shared.UI.

### Round 44 (2026-11-13): hotel card and tool rail match the HUD
- Client (mirror): the level card (`lvBody`) uses the HUD plate (white to 244,247,250 gradient, `CARD_RIM` 2.5 rim, shadow drop 5 / 0.7); name text 34,44,64, empty stars 218,224,234, rating number 226,160,20, XP track 226,231,238, XP text 110,120,138. The blue level column is unchanged.
- BuildKit (mirror): `whitePlate(f, r)` for the tool rail only (other build panels stay dark glass); rail chips `RAIL_CHIP` 240,244,250, hover `RAIL_HOVER` 222,232,248, labels `RAIL_TEXT` 96,108,130, divider 222,228,238; the flat trash glyph is tinted red (white when on).

### Round 43 (2026-11-13): decorate outside, bigger lot, ground grid
- HotelBuilder (mirror): `B.GROUNDS = {x = 157, z0 = -198, z1 = 31}` and `B.grounds(hotel)` (called at the top of `B.parking`, so every plot gets it): a `Grounds` zone part (Outdoor) over the lot. Once per city lot (`lot:GetAttribute("Grounds")`) it carves the terrain lawn to air, lays a LeafyGrass `Lawn` part (in the lot) with its top at FY - 0.05 so outdoor items stand at `Build.FY` like indoors, lowers the lot's trees, garden and benches 1 stud, moves `BackHedge` to z -199.5 and stretches the side `Hedge`s to it.
- Shared.Build (mirror): `B.inHotel(hotel, p)` = the building's footprint (MinX - 2.5 .. MaxX + 2.5, z -32.5 .. 37). `zoneAt`: rooms > Lobby > Grounds, and Grounds only outside `inHotel`. `B.lotOf(hotel)` finds the city lot (by `BackHedge` x, cached); its trees, garden and hedges are blockers. `validate`: no ceiling check on Grounds; core / room items refused there ("That belongs in a guest room"); off-plot message "Keep it on your plot". Parking spots still only in the car park.
- BuildServer (live only): after `buildLand`, Grounds items whose box corners fall `inHotel` are removed and their `PlacedPrice` (or sell value) refunded.
- BuildClient (mirror): `S.groundGrid()` (run every frame) shows `GroundGrid`, a copy of the ghost grid plate over the Grounds zone at FY + 0.03, with 4-stud cells (64 studs per tile; finer lines fade out at camera distance) tinted 30,60,100 at 0.45, edges on multiples of 4. Hidden when not building or Grid is Off. Camera `BOUNDS` = { -157, 157, -198, 58 }.
- Grounds items are inert decor (HotelSim, GuestEvents, Upkeep and Kitchen only look at Lobby / room zones).
- Not mirrored (live only): BuildServer, Plots. Mirrors refreshed: Build, BuildClient, HotelBuilder.

### Round 42 (2026-11-13): build mode remade
- New `ReplicatedStorage.Shared.BuildKit` (mirror): `require(BuildKit)(api)` builds the shop, tool rail, selection, groups, box select, delete sweeps, placement panel and wall hugging, and returns `K` (`K.select/selectMany/clear/replace`, `K.act.move/turn/copy/same/paint/sell`, `K.key(kc)`, `K.worldClick(pos)`, `K.hover(m)`, `K.dragBegin/dragEnd`, `K.grab/groupRelease`, `K.step(dt)`, `K.layout`, `K.show`, `K.placed(id)`, `K.openTab(id)`). Everything lives inside the call (Coop restarts BuildClient); it clears a leftover `workspace.BuildKitLocal` and `PlayerGui.KitTip`.
- BuildClient hands it `api` (S, HOTEL, PLACED, Remote, gui, desk, ED, thumb, ghost/makeGhost/clearGhost/turnGhost/raiseGhost, floorPoint, placedAt, setSelected, startPlacing, buyRoom, lockOf, itemPrice, cash, wrapper, kOf, layout, setHints, HINTS_IDLE). The old catalog, tool bar, item card and card actions are gone. `overGui` ignores a wrapper's own empty frame. The block editor sits left of the shop.
- Catalog (live only): `Catalog.TABS` (all, recent, build[walls doors floors shapes styles land], bedroom[beds storage extras], bath, living[seats tables shelves], lights, decor[plants art pieces], fun[games relax], food, services, staff, outdoor), `TAB_ALIAS` (old cat ids), `TAB_OF[id] = {tab, sub, order}`; `hidden = true` on WallSage, Sculpture, FlowerStand (still placed ones stay; the shop and the server refuse new ones). Desk shows as "Reception Desk".
- Shared.Build: `YAW_STEP` 5; `validate(id, cf, ignore, opts)` takes a group table as `ignore` (`group.main` = the model moved, `group[m] = true` for the rest, so a group's members don't block each other).
- BuildServer (live only): `moveMany {{uid, cframe}...}` and `placeBatch {{itemId, cframe, opts}...}` (max 40, `true, done, why`; one ItemsChanged); place refuses `item.hidden`.
- Undo knows `{moves = {{uid, cf}}}` (moveMany back) and `{rebuy = {{id, cf, opts}}}` (placeBatch); Delete pushes rebuy entries.
- Tools: 1 Select (click, Shift/Ctrl+click toggles, drag an item moves it, dragging one of a selected group moves the group), 2 Box (marquee by item pivots on screen, Shift adds), 3 Delete (red hover with price, click sells, drag marks up to 40 and sells on release), 4 Paint (palette + finishes, paints shapes), 5 Pick (copy of what you click), 6 Room (Room Builder). V also picks Select. Arrows nudge the selection (one grid step, Shift = 0.05) along the camera's axis and send once they settle; T/G raise/lower; Ctrl+A = All alike; Delete sells (click twice); X / Escape / right-click cancel.
- Placement panel (one item selected or something in hand): X / Z from the hotel origin, height, angle (Enter applies; with something in hand it locks the spot), nudge and turn pads, grid Off/.25/.5/1/2/4, turn 5/15/45/90, switches Wall snap, Hug walls (`S.hugWall`: ray 4 ways from the item, nearest structure / shell wall, back (-Z) flush, LookVector into the wall), Stack (`S.stack`), Keep placing, Lock spot (`ghost.locked`: aimGhost leaves it alone).
- Testing note: user_mouse_input y = viewport y - 58 (top bar); GUI buttons only answer to `instance_path` clicks, so chips are named `Chip_<text without spaces>` and the switch grid `Switches`.
- Not mirrored (live only): Catalog, BuildServer. Mirrors refreshed: Build, BuildClient, BuildKit (new).

### Round 41 (2026-11-13): fixes and polish (tutorial, HUD, NPCs, voice, talk box, lighting, build mode, vault, sounds)
- MainMenu: the bin is a solid tile with a red rim (`binRim`) that turns red when armed; the second press within 4 s deletes. Text sizes raised (save names 22, lines 16).
- Shared.UI: labels under 15 are grown by `readable`; toasts stack under the clock and cap how many show. TutorialClient: the chapter card is smaller and hidden while `InTutorial`; HUD buttons unlock (`UI.locked`) as the tutorial reaches them; tutorial text is bigger. Server Tutorial sets `GuestsHeld` on the hotel until the "wait for your first guest" step (HotelSim skips walk-ins while it is set). Mess: the tutorial cleanup is a pick-up minigame; lost items need the hotel to have had a guest.
- Coop / Client: the Hotel page has an Open / Closed switch. Plots action `("closed", bool)` (owner only) sets hotel attribute `Closed`; HotelSim.wantsWalkIn returns false while closed; Client shows a CLOSED caption.
- NPCs: Looks heights 0.97-1.03 (kids 0.78-0.84, elders 0.94-0.98); `C.WALK_SPEED` 6.5, `C.STAFF_WALK` 10, Crowds walkers 6.5-8.5.
- Voice: Shared.Speech plays only VoiceFX beeps (the old TTS-style voice is gone); `voiceFor` maps VoicePick 1..8 to babble pitch; VoiceFX stretch clamped 0.6..1.4.
- Talk: remade as a dark glass box with the speaker's portrait in a coloured ring, a name tab in their colour (`setPlate` tints tab, ring and rim), 26 px white lines, dark reply cards.
- Lighting (StarterPlayerScripts.Lighting, new mirror): brighter night keys (ambient 72,80,118, outdoor 86,100,150); an INDOOR key (ambient 158,146,132, brightness 2.2) blended in by `cameraIndoors()` (1 inside, 0.6 above with the roof hidden).
- Room doors: StatusLight / LampGlass / LampPlate removed from Room101-103 so built and template rooms match.
- Build mode: Catalog has FloorStone/Oak/Walnut/Marble/Terracotta/Concrete/Carpet (structure, flat, 4x4 tiles in Shared.Items and ServerStorage.HotelProps). BuildClient: tool bar remade (white glossy holder, compact `toolChip` with a value pill, `S.toolFit` UIScale so it fits beside the catalog), LOBBY FLOOR / ROOM FLOORS / ROOF STYLE chips call `Upgrades:InvokeServer("style", key, v)`; UpgradesUI only shows the walls style now. Room labels off in build mode. `cornerSnap` also snaps to the lines of placed walls and Shell/Rooms walls.
- HotelBuilder.cashSafe: a closed 2.6 x 2.9 x 2.3 vault (dial door = `CashStand` prompt holder, gold tray on top = CashPile origin); exported as `B.cashSafe`, and the template lobby's safe rebuilt with it.
- Audio: door open/close uses the soft `doorSoft` set (no creaks, Doors.lua), footsteps follow speed with a material factor and 10/60 roll-off.
- Not mirrored (live in the place only): Plots, Audio, Doors, Catalog. Backup: ServerStorage.DevTools.Round41_Backup (24 scripts). Mirrors refreshed: MainMenu, UI, TutorialClient, Coop, Client, Tutorial, HotelSim, Mess, Minigames, ResearchUI, Looks, Config, Crowds, Speech, VoiceFX, Talk, Lighting (new), BuildClient, UpgradesUI, HotelBuilder.

### Round 40 (2026-11-13): icons, minigames, arm, work poses, HUD and UI style, surprises
- Icons: `tools/icons39.py` (Blender, `-b --factory-startup -P icons39.py -- name1 name2`, space-separated) renders `ui39/<name>_raw.png`; `tools/sheet39.py` outlines only raws newer than their PNG and rebuilds `ui39/_sheet.png`. `ui39/ids.txt` / `ids.lua` hold the 85 asset ids; `apply.lua` swapped `C.ICONS` (hammer and gridPlate kept). Console "No asset content representation" warnings on new ids are a missing low-res variant; PreloadAsync reports Success.
- Minigames (StarterPlayerScripts.Minigames, ~180k): the flat 2D games, FLAT, scrubSpots and deskTop are gone. Inside the G3 do-block: the 3D kit, then the round-40 kit (`every`, `later`, `ptr`, `oops`/`nope`/`nice`, `ribbon`, `stages(list)`, `follow`/`letGo`, `marker`, `arc`, `dragStage`, `twistStage`, `beatRing`, `meter`, `card2`, `scrubber`, `stain`, `deskGuest`, `speech`, `deskSet`), then the eight games. `stages` sets `S.stageNo/stageCount/stageName` and calls `win()` after the last.
- dragStage also grabs on a press within 28 area units of the thing's centre (thin washers and fuses). Shower squeegee fog only covers y 1.8..8.2 (what the camera sees); the toilet roll spawns on the floor at (3, 0.6, 1.6); the Cook done-bar moved left of the heat meter.
- Arm: bones sleeve/forearm/hand scaled by `k` so the glove is drawn at the held thing's depth; with nothing held it follows `S.pointer` (or the area centre) at `V.armDepth`.
- Test hook: `PlayerScripts.Minigames.MGTest:Invoke(op, ...)`: "down"/"move"/"up" (area units 620x340), "stage" (name, no, count, mistakes, won), "find" (model/part name -> area x, y), "area" (world x, y, z -> area x, y).
- `C.MINIGAME_PAR` = Floor 24, Bed 30, Shower 26, Toilet 26, CheckIn 16, CheckOut 14, Cook 30, Repair 26.
- Work poses: Minigames fires `Remotes.WorkPose(kind)` on open and `(nil)` on close. ServerScriptService.WorkPose sets the character's Pose (+ WorkAt from the root) and tag `PlayerPose` (Floor/Toilet scrub, Bed makebed, Shower wipe, Repair fixat, Cook cook, desk games desk). NPCAnim tracks `PlayerPose` characters with `st.player` (no face changes, no glances).
- HUD: `card()` in `open()` has a per-job ACCENT (desk sun, Cook orange, Repair red, else brand blue), a gradient, a 2.5 rim and a top tab; the title icon sits in an accent badge; the hint card has a step chip and a thicker bar.
- Shared.UI: `UI.gloss` is live again (a top highlight fading down). `UI.button`: Base is a visible darker lip, Face is 4px shorter with a top-lit gradient and a gloss; `setDisabled` fades Base too. `UI.panel`: body gradient, 2px rim in the panel colour, a header washed in from the colour, a white icon disc with a coloured rim.
- Surprises: `G3._surprise(kind)` (35%, or forced by player attribute MGSurprise "lost"/"bug"/"off"; forced ones go first) returns a Lost & Found or a Bug stage, put on the scene's surface (`SURFACE`: y and whether a bug fits; Shower and Repair have none). The stage flag `surprise` adds its time back to `t0`; `S.found` / `S.shooed` show on the result card.
- Backup: ServerStorage.DevTools.Round40_Backup (Minigames, NPCAnim, UI, Config, WorkPose). Mirrors refreshed: Minigames, NPCAnim, UI, Config, WorkPose (new).

### Round 39 (2026-11-13): tags, grime, minigame extras
- Shared.Quests: `Q.TITLES` (achievement id -> tag text), `Q.TAG_COL` (Bronze, Silver, Gold), `Q.MG = { streak = 10, cap = 10, coinChance = 0.4 }`, `Q.mgCoin(level) = 20 + 3 * min(level, 60)`.
- QuestServer: Achieve `("tag", id)` wears a tag (`""` takes it off; needs `st.ach[id] >= 1`, owner only), saved as `st.title` in the Quests JSON. A tier-1 claim with no tag worn puts it on and returns `info.tag` (Coop toasts it). A 1 s loop sets player attributes `Tag` / `TagTier` from the hotel they own (a co-op member elsewhere keeps theirs) and keeps a BillboardGui `TagGui` in the Head (StudsOffset 1.55 + SizeOffset 1.45, so it stays over the Roblox name at any distance).
- Bubbles: `TextChatService.OnIncomingMessage` puts `<font color=tier>[Tag]</font>` in front of PrefixText.
- Coop achievements page: a chip under the pips per achievement (TAG / WEAR TAG / WEARING, in the claimed tier's colour).
- HotelSim: `grime(room, task, on)` (one local inside a `do` block: the main chunk is at Luau's 200-local limit). Folder `Grime_<task>` in the room model: cylinder stains raycast onto the core model (from above, below 20% over its box centre so no headboard tops, and from the sides for Shower 60% / Toilet 40%), or onto the floor round the Floor spot (flat hits at the floor's height); part `Air` with `Flies` (dark specks) and `Stink` (Bed, Toilet). Called from setRoomState (each pending task), room.clean (off) and syncRoom (rebuilt when furniture moves).
- CleanDone takes a 3rd arg `{ kind, secs, bonus }`; on a counted clean or an ok desk game HotelSim fires Signals.Minigame `(hotel, player, kind, stars, secs, bonus)`. QuestServer: `MGStreak` player attribute (+1 on 3 stars, else 0), pays streak x10 from x2 (cap 10 steps) plus the coin, Notify "paid"; best time per kind in `st.best` (seconds, 0.1).
- Minigames: `bestOf(kind)`, `spawnCoin(s)` (40% per game, between 1.5 s and 55% of par, 3.5 s, tap tested before the game's onDown, mouse and pad), streak badge under the clock, result card 360 x 184 with the extras line. Test hook: player attribute `TestMG` = "coin" / "win".
- Playtest: tag equipped through the remote, pill over the head, chat prefix `[Desk Ace]` in gold; Room 102 got Bed 18, Shower 30, Toilet 27, Floor 26 grime parts and flies/stink show; server path paid $140 (streak x3 $30 + level-30 coin $110), a 2-star reset the streak, best kept; coin grab and the result card checked through TestMG. Not checked: the headboard filter on a fresh dirty room, the phone layout of the chip, a real cleaning session's report (test wins have no server session).
- Backup: ServerStorage.DevTools.Round39_Backup. Mirrors: Quests, QuestServer, Bubbles, Coop, HotelSim, Minigames (new).

### Round 38 (2026-11-13): odd jobs, critters and tips
- Shared.Quests: `Q.SIDE` (pool: key, text with %d, icon, stat, goal range, base cash, `moment`), `Q.SIDE_SLOTS = 3`, `Q.rollSide(level, active, n, rng)` (no duplicate keys, at most one `moment` job; cash x (1 + 0.12 x (level-1)), xp 8 + level). `Q.visible` shows 2 chapter goals plus odd jobs (at most `Q.SHOW + 1` = 4 cards), or 3 chapter goals when there are no odd jobs. New achievements: jobs, finder (stat lost), wrangler (critter), tipped (tip), tidy (spill).
- QuestServer: state `sq` (active odd jobs, ids `s<n>_<key>`, `order = 10 + n`), `sn` (counter), `sold` (last 3 finished ids, kept in `done`/`p` so the client card can play its finish). `completeSide` pays the owner, adds `life.jobs`, frees the slot; the 1-second loop's `fillSide` refills it. Why not daily goals: a game day is 7 real minutes (C.CYCLE 420), too short for goals that reset.
- Client makeCard: `q.side` cards get a pale blue tile and an "ODD JOB" tag; after the last chapter the header reads "Odd Jobs".
- Mess: `quest(plot, stat)` fires Signals.Quest (`spill` on a cleaned spill, `lost` on a give-back). `Mess.tip(plot, pos, amount)`: coins and a note on the floor (max 5 per hotel in `Tips`, gone after 120 s), a 3.2x4 invisible `Grab` part pays the first player of that hotel who touches it (Notify "paid", stat `tip`). `Mess.dog(plot)` / `Mess.gull(plot)`: one critter per hotel (plot attribute `Critter`), parts moved with `workspace:BulkMoveTo` from offsets taken 0.95 under the body; `roam` picks spots with a clear raycast line and lerps Y to the target. Dog: speed 8, runs (11) from a player within 11 studs, "Catch" prompt, wags and trots. Gull: 3 "Shoo!" presses (each flaps it away), then it flies off and fades. Each pays $40 and fires `critter`; both leave on their own after 150 s. Sounds: bark 9113955372 (coyote at 1.5-1.75 speed), squawk 9118858259.
- `spots()` floor tolerance 2.5 -> 0.75 studs from the desk seat height minus 1.5 (sofas at 2.3 and armchairs at 2.5 counted as floor).
- WorldEvents: 25% per tick (70-140 s, 8:00-22:00, a player in the hotel) for a dog or a gull. HotelSim checkout: 60% of 4-5 star stays drop a tip of 12% of the bill (min $5).
- ChatCommands `/dog`, `/seagull` (CommandsUI lists them).
- Playtest: odd jobs fill, count and refill; dog caught and gull shooed through their prompts; tip picked up by walking over it; Awards page shows 51 tiers; both sounds load; console clean apart from the old ContentId warning.
- Backup: ServerStorage.DevTools.Round38_Backup. Mirrors: Mess, WorldEvents, QuestServer (new), Quests (new), ChatCommands, CommandsUI, Client, HotelSim.

### Round 37 (2026-11-13): more guest types
- GuestEvents DEFS: `backpacker` (need snack), `fitness` (gym), `gamer` (play), `spa` (bath); all `where = "any"` (their room, then the lobby), `miss = 0.85`. They use `feature = "guest_<id>"` instead of `gate`: `unlocked()` checks `Levels.featureOk(hotel, d.feature)` first. Their LOOKS sit after `coat`/`noHair` (local functions defined above LOOKS.rockstar); defined earlier they would be nil and `E.dress`'s pcall would hide it.
- Levels.FEATURE: `guest_backpacker` 3, `guest_fitness` 4, `guest_gamer` 5, `guest_spa` 7 (icons walk, run, catFun, shower). `unlocksAt` lists them as "NEW FEATURE" tiles, so the level-up card and level road need no client change.
- `E.stay`: gamer cheers with a small confetti burst; spa and fitness get sparkles at the item.
- Voice: sporty/tourist hello lines say "I'm %s"; `V.flavor` nan strips trailing `.!?` runs and keeps a question a question (", dear?"); dreamer strips `.!` runs before "...".
- ChatCommands COMMANDS and CommandsUI list `/eventbackpacker`, `/eventfitness`, `/eventgamer`, `/eventspa`.
- Playtest: at level 30 the four show up in about 2% of arrivals each; a gamer with no play items says "Needs games to play" and pays 0.85x. The happy path (walking to a lobby item) is the same code as the sick and business guests; not watched this round because three furnished rooms kept a six-guest line.
- Backup: ServerStorage.DevTools.Round37_Backup. Mirrors: GuestEvents, Levels, ChatCommands (new), Voice, CommandsUI.

### Round 36 (2026-11-12): fun and polish
- `Mess.lost(plot)`: one lost item per hotel (plot attribute `LostOwner` = owner model name). Owner = a non-staff guest with BName within 60 studs of DeskSeat; item placed on the first `spots()` point. Pick-up prompt sets player attribute `LostItem`; then a `GiveBack` prompt (UIOffset 0,60) sits on the owner's HumanoidRootPart. Reward $50 to Cash and Earned. The owner says ASK lines every 12-18 s ("Is that my ...?!" every 5 s while the carrier is within 16 studs) through the Say/SaySecs/SayN attributes. Gone after 240 s or when the owner leaves. WorldEvents' spill loop also rolls 22% per tick for `Mess.lost`.
- HotelSim janitor branch: when `HOTEL.Spills` has a child, the janitor walks to it, mops (3-5 s) and destroys it.
- Upgrades: `mats` (Doormats, stat `spills`, mul 0.85, base 300, grow 2.4). WorldEvents multiplies the spill chance by `0.85 ^ U.level(plot, "mats")`. The page's "N OF M LEVELS" excludes curb, so it now reads 40.
- Voice: `PLACE` lines (room, out, one list per event id) and `placeLine(m)` replace the guest "idle" line when BWhat says Waiting (SAY.waitLine), No clean rooms (waitLong), Room.../their room, or market/walk/Heading/legs, or 35% of the time on an event day. BWhat containing "Sleep" only ever says "Zzz..." (30%). `V.say` skips any line in the last 10 said (except Zzz).
- HotelSim `think()`: the "I should start <status>." fallback is gone; only THOUGHTS lists and Voice thoughts remain.
- Checked: cars and tyres look right (all 7 templates); queue code reviewed, not changed (no stutter seen).
- Backup: ServerStorage.DevTools.Round36_Backup. Mirrors: HotelSim, Voice (new), Mess, WorldEvents, Upgrades (shared).

### Round 35 (2026-11-12): content
- ServerScriptService.WorldEvents: on Shared `Day` change, 45% chance (day 3+) of an event; publishes Shared `Event`, `EventName`, `EventText`, `EventIcon`, `EventDemand`, `EventPrice`; Studio hook `TestEvent`. Also runs the spill loop (every 70-140 s, 8:00-22:00, hotels with a player and a busy room).
- `Clock.seasonData()` folds `EventDemand`/`EventPrice` into the season's demand and price for today only, so HotelSim needs no change. Crowds multiplies its target by `EventDemand` (0.6-1.4). `C.CROWD` 56 -> 68.
- ServerStorage.Mess: `Mess.spawn(plot)` (story start, called from Tutorial.offer for a brand-new hotel) and `Mess.spill(plot)` (max 3 in a `Spills` folder). Spots are raycast floor points within 22 studs of DeskSeat with a ceiling overhead. Tag `Mess`; plot attributes `MessLeft`, `CleanedUp`.
- StarterPlayerScripts.EventBanner: the banner and the pill (hidden while building, talking or in the menu screen).
- RoomStatus: `makeSign(room, anchor)` builds the local A-frame (parented to the camera) 2 out and 3.7 sideways of the threshold.
- Cutscene `clear()`: swings the camera offset round the subject (0, ±35, ±70, ±110, 180 degrees, +3 up) and keeps the last clear angle.
- HotelSim is over 200,000 characters: `.Source =` fails, edit it with `multi_edit`.
- `tools/mirror_assemble.py` rebuilds mirror files from the chunked `execute_luau` dumps.

### Round 34 (2026-11-12): UI remake
- Look tokens (Shared.UI `T`): ink white, ink2 245,247,250, cream = dark text 26,32,44, muted, line; gold = brand blue. A chapter plate = white body, UIGradient white to 244,247,250, `UI.rim` 232,237,244 at 2.5, a 3D `C.ICONS` icon overlapping the left edge.
- Never put a UIGradient on a CanvasGroup you want white children in (it tints them); `UI.shadow` under a semi-transparent panel greys it.
- Client: `glass()` is the white plate; `glyphTile` swaps cash/guest glyphs for 3D icons; the top bar clash test uses `GuiService.TopbarInset` as the free area; `daySummary(d)` builds the 520x600 card from Notify "day" (earned, wages, upkeep, guests, cleans, uncollected) plus HotelStars and `Clock.seasonData()`.
- `UI.toast(text, icon, kind)`: icon may be an asset or a `UI.G` glyph name ("close", "check").
- Talk: `who` (ImageLabel in dGroup) is the speaker icon; `setPlate(name, sub, col, img)`; headshots use `rbxthumb://type=AvatarHeadShot`.
- UpgradesUI: `UP_ICON` maps upgrade id to a `C.ICONS` key; the "rooms" style group is skipped.
- Coop `fit()`: window scale capped at `k * 0.82`.
- Mirroring big scripts: `execute_luau` output caps at about 100k characters and anything over about 60k is saved to a tool-results file, so concatenate sources with `@@@FILE` markers in `_G`, return 60k slices padded to 95k, and reassemble with a script.

### Round 33 (2026-11-12): build mode and room numbers
- BuildClient: `shopWrap` anchors bottom-right (404x760 at 1,-16 / 1,-14) and slides in from +460; `edWrap` sits top-left (18,140); layout() centres the view in what is left of the screen.
- Room numbers: RoomId never changes (slots, saves, tiers). ServerStorage.Rooms adds `Rooms.label(hotel, m)` (saved label, else the id when < 200, else the lowest free number from 101) and `Rooms.rename(hotel, m, n)` (whole number 1-9999, unique). Room model attribute `Label`; hotel attribute `RoomLabels` = JSON { [tostring(id)] = label }, saved as `d.labels`. Plates: every TextLabel named Text in the room (and its DoorRef door) showing the id gets `RoomPlate` and shows the label.
- HotelSim addRoom sets `room.label` (follows the Label attribute). Every player-facing "Room N" (toasts, prompts, statuses, check-in keys and minigame data, reviews) uses room.label; Upkeep and GuestLife too. The Bag attribute and the cleaning minigame session still use room.id.
- Save: after setting RoomLabels it clears every standing room's Label and relabels them (the built-in rooms were numbered before the save arrived).
- BuildServer action ("label", roomModelName, n) -> Rooms.rename, fires ItemsChanged. BuildClient room cards: the title is a TextBox (bb.Active), Enter sends the rename.
- Room Builder `sharedWall` checks 2.4 x 3 x 1.4 (was 0.3 deep), so walls just off the edge line, like shell walls past the floor edge, count as shared and are not rebuilt.
- `placedAt`: a cut-away (faded) placed part is remembered and returned when the ray finds nothing solid behind it, so built walls and doors can be selected, moved, painted and sold.
- Floors and roof (reusing round 22's HotelSkin styles): cards are 196x84 with cycle buttons. Lobby card: ("style","lobby",id) and ("style","roof",id). Room card: ("style","room:RoomN",id) on Remotes.Upgrade, stored in hotel attribute `RoomFloors` = JSON { RoomN = floorId } (saved as `d.roomFloors`). HotelSkin.refresh puts it in `style.roomFloors`; dress uses it for that room's Floor; watch() also listens to RoomFloors.
- Custom rooms (HotelBuilder.customRoom) were already empty with their own carpet Floor; the bathrooms and inner walls the player sees are on the old built wing rooms 104-107 in their save, which were left alone.
- Not checked in play: the cards render (Studio's capture skips BillboardGuis; their screen positions and sizes were checked), drawing a new room against a wall, clicking a cut-away wall.
- Backup: ServerStorage.DevTools.Round33_Backup. Mirrors refreshed: BuildClient, HotelSim. Changed live but not mirrored: Rooms, Save, BuildServer, Upgrades (server), HotelSkin, Upkeep, GuestLife.

### Round 32 (2026-11-12): quick fixes from the big request
- Street lamps: the lamp mesh's origin is at its base, so the SpotLight in Glow lit the ground from inside. Each workspace StreetLamp's light moved into an Attachment `Glow.LightAt` at the head (world-aligned, Face Bottom), brightness 3, range 40, angle 130. ServerStorage.CityProps.StreetLamp has no light, so nothing to change there.
- Lighting: the night keys are brighter (amb 46,52,82, out 70,80,122, bright 0.8, expo -0.12). Build mode at night (`bn = buildK * k.stars`) lerps the ambients toward grey and adds brightness and exposure.
- BuildClient: the wheel zoom ignores the cursor while `input.rightDown`. Room Builder: `KITS` is reassigned to just "Just Walls"; the type rows and the furnish toggle are hidden; the panel is 372 tall; default `rb.kit = "empty"`, `furnish = false`.
- Bubbles: SAY_SIZE 22, SAY_W 310, billboards 400x300. `tidy()` capitalises the first letter. `richLine()` (RichText) colours and underlines $ amounts, "Room N", staff first names and player display names. The status disc shows only for staff (`m.staff`).
- Speech babble passes `dur = S.estimate(line)` and clamps at 9 s (was 3.4). VoiceFX thins to 60 beats (was 30).
- TutorialClient: `canSkip = false`; the check-in step also completes when a receptionist is hired; the card scales by 0.85.
- UI.panel: with `onClose` (and `outsideClose ~= false`), a MouseButton1 or Touch outside the holder closes it. The panel must be on screen and every ancestor visible; it does nothing while Building, or when the click lands on another ScreenGui's button or TextBox. Coop's Dim also closes the menu on an outside click.
- Config.ANIM walk/run = Rthro 2510202577 / 2510198475, `C.WALK_SPEED = 8` (pure walk in Looks.moveBlend). Looks walk ids and RUN_ANIM match; NPCAnim CORE_ANIM lists them.
- Deferred: room numbers. Custom rooms take ids from Rooms.FIRST_ID = 201, and ids are tied to wing slots (C.ROOM_SLOTS 104-111) and saves, so the plan is a stored display label (and renaming) in round 33. The queue was measured but not changed (no free rooms in the test, so the line never moved).
- Mirrors refreshed: BuildClient, UI, NPCAnim. Changed live but not mirrored: Lighting, Bubbles, Speech, VoiceFX, TutorialClient, Coop, Config, Looks.

