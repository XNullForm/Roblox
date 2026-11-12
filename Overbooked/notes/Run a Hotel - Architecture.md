---
aliases: [Overbooked - Architecture]
updated: 2026-11-10
---
# Overbooked - Architecture (was Run a Hotel)

Back to [[Run a Hotel]]

Studio place "Run a Hotel", placeId 75953879612667. Get the `studio_id` from `list_roblox_studios` (it changes every Studio launch).

## Pipelines
| Thing | Where |
|---|---|
| Props | `Run a Hotel tools/rah_props.py` (headless Blender: `blender -b --factory-startup -P rah_props.py -- Bed Shower --render`). Each prop is built round its floor centre (1 m = 1 stud, -Y = front = Roblox +Z), painted per piece, AO baked into vertex colours, split into groups `main / chrome / glass / glow`. Writes `export/<Prop>_<group>.json` + `<Prop>.manifest.json` + `_render_<Prop>.png`. Several can run in parallel. |
| Upload | Serve `export/` with `python -m http.server 8790`. `ServerStorage.DevTools.MeshImporter.prop("Bed")` uploads every group (EditableMesh → CreateAssetAsync) into `ServerStorage.HotelProps.Bed` (Model, pivot = floor centre; parts `Body`, `Chrome`, `Glass`, `Glow` with materials from `MeshImporter.LOOKS`). |
| Scripts | Mirrors in `Run a Hotel tools/src/` served with `python -m http.server 8791 --directory src`; push by setting `.Source` from `HttpService:GetAsync` in `execute_luau`. |
| World | `src/HotelBuilder.lua` (copy in `DevTools.HotelBuilder`): `loadstring(GetAsync(".../HotelBuilder.lua"))().build()` rebuilds `Workspace.Hotel`, `Workspace.Outside`, terrain, spawn and lighting. **Rebuilding wipes the hotel**; scripts read everything by name, so keep names. |
| Icons | `Run a Hotel tools/ui_icons.py` (Pillow) → `ui/*.png`, served on 8792 for `upload_image`. Ids in `RAH.Config.ICONS`. |

Props: Bed, BedMessy, Shower, Toilet, Nightstand, Desk, Sofa, CoffeeTable, Plant, FloorLamp, WetSign, CashBundle, Towel, Trash, Rug. Shop props (round 2) live in `rah_props_shop.py`, which `rah_props.py` execs: Armchair, TVStand, Wardrobe, Bookshelf, PingPongTable, VendingMachine, PottedTree, SideTable.

## Workspace
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

## Round 10d (2026-11-03): rooms made with walls, land, performance
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

## Round 10c (2026-11-03): controllers, weather, colliders, new items
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

## Round 9 (2026-11-02 / 03)
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

## Plots and co-op (round 8)
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

## Scripts
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

## Gotchas
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

## Round 10e (2026-11-04)
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

## Round 11 (2026-11-05): grades, upkeep, 3D minigames
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

## Round 12 (2026-11-05): desk, tutorial, menus, settings, new items
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

## Round 13 (2026-11-06): room doors, staff looks and jobs, research stats
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

## Round 14 (2026-11-09): style, hiring, voices, weather, FX
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
## Round 14b (2026-11-09): furniture remodels, image-packed mesh import
- **The Assistant's HttpService can't reach 127.0.0.1 any more** ("not in the Assistant HTTP allowlist"). Game scripts in a playtest still can, but `CreateAssetAsync` only works in Edit.
- **Import route now:** pack the mesh JSONs into a PNG (4-byte big-endian length + JSON `{file = meshJson}`, 3 bytes per RGB pixel, alpha 255), serve it on 8790, `upload_image` it, then in Edit: `P = require(ServerStorage.DevTools.ImagePack:Clone())`, `all = P.load(assetId)`, `P.swap(itemId, {{file, group}}, all, backupFolder)`. `swap` replaces `Shared.Items.<id>` MeshParts and keeps each old part's material, colour, flags, children (lights) and attributes. Packing snippet: see the Python in this round's session (PIL `Image.frombytes('RGB', (side, side), data)`).
- New models in `rah_props_r14b.py` (exec'd last by rah_props.py): IndoorPalm (8.7k tris), CoffeeTable, FloorLamp (shade in `main`, only the bulb in `glow`; Glow = Neon 255,226,186 + PointLight). Old item models in `DevTools.Round14_Backup_20261109` as `Item_<id>`; old Phone as `Phone_pre14b`.
- Phone: shadows `UI.T` with a local dark-screen palette (cream/muted light, ink dark) via `setmetatable({...}, {__index = UI.T})`.
- Crowds umbrellas weld to `RightHand` (`U_GRIP`, `U_HAND_OPEN/SHUT`, hub attribute `Hand`, model `Carry = "umbrella"`); NPCAnim tracks `workspace.StreetCrowd` rigs within `STREET_FAR = 75`.
- Round 14c: `rah_props_r14c.py` (exec'd after r14b) remakes Armchair (rust velvet), Sofa (teal velvet, knit throw), Wardrobe (walnut armoire), Bookshelf (walnut, decorated shelves); each now has a `Chrome` part (brass). Helpers there: `_place(ob, loc, rot)` turns a mesh about its own centre (the base `box(... rot)` + later `rotation_euler` turned about the world origin), `_drape` (solidified cloth strip), `_leg`, `_rolled_arm`. Pack asset 111634508406169. Placed copies in `Hotel.Placed` were re-meshed in place.
- Round 14d: `rah_props_r14d.py` (after r14c) remakes the room upgrades: BedDeluxe / BedDeluxeMessy, BedSuite / BedSuiteMessy (built as separate props, swapped into `Items.<bed>.Clean` / `.Messy`), ToiletDeluxe, ShowerRain (new `glass` side panel), Vanity (mirror face is in `main`, so the old Glass part was removed). Use spots unchanged (mattress top 2.35, seat 1.55, rain head at (0, 0.5, 8.0)).
- `ImagePack.swapModel(model, groups, all)` swaps into any model and deletes MeshParts with no new counterpart; `swap(itemId, ...)` wraps it. **After a swap, reset `Color` to white**: the old parts' tint is copied with the look and recolours the vertex colours (it turned the suite duvet lavender). Packs over ~3 MB must be split: keep each PNG at most 1024 px a side (r14d used three: 131283696339430, 140377557329791, 127472987641627).
- Round 14e: `ReplicatedStorage.Shared.NPCGait` (source `Run a Hotel tools/src/NPCGait.lua`) is a procedural walk/idle for R15 NPCs: keyed periodic curves (HIP, KNEE, ANKLE, BOB, SWAY, BREATH), STYLES (normal, brisk, bouncy, stroll, stomp, sneak) picked by `Gait.styleOf(model)` from attribute `GaitStyle`, else GuestType, else BRole (brisk), else Persona. `Gait.new(model, rig, rng)`, `Gait.step(g, dt, root, out, now)` returns the walk weight. Test hooks: model attributes `GaitSpeed` (fake speed) and `GaitPhase` (held phase). `NPCAnim` keeps the stock-track pose in `st.anim`, blends `st.base = anim:Lerp(gait, gaitW)`; gaitW goes to 0 while seated, emoting (a non-core track at weight > 0.3), frozen or in an `ownsBody` pose. Backup `DevTools.Round14_Backup_20261109.NPCAnim_pre14e`.
## Round 15 (2026-11-10): remakes, luggage, star guests, cutscenes
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

## Round 16 (2026-11-10): faces, gender, beep voices
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

## Round 16b (2026-11-10): city remake
- **Materials:** `tex_r16.py` writes `export/t16/<name>_{c,n,r}.png` (colour, normal, roughness; light and neutral so `Color` tints them). MaterialService variants `R16_Brick` (Brick), `R16_Stucco` (Plaster), `R16_Stone` (Limestone), `R16_Asphalt`, `R16_Paver` (Pavement), `R16_Roof` (Slate), `R16_Tower` (Metal), `R16_Leaf` (LeafyGrass), `R16_Bark` (Wood). Materials project by studs on UV-less MeshParts, and vertex colours multiply them.
- **Kit:** `rah_props_r16.py` (exec'd last by rah_props.py) builds WinA..WinE, Cornice, Belt, Pilaster, ShopWin, ShopDoor, Awning, RoofTank, RoofAC and new TreeA/B/C and Bush. Facade pieces: origin on the wall plane, facing Roblox +Z. Groups: trim, main, glass (part `Window`), paint, paint2, metal, chrome, bark, leaf.
- **Import:** `python pack16.py <tag> <props>` makes `export/_<tag>_<n>.png` (manifests included); `upload_image`; then `K = require(DevTools.Kit16:Clone())`, `K.open(assetId)`, `K.import({names}, "CityProps")` (4 to 6 props per call), `K.close()`. Looks per group are in `Kit16.LOOKS`.
- **MapBuilder:** the new `building`, `skyline` and `restyle` live in `src15/_mapbuilder16.lua` (sections `--@@BUILDING`, `--@@SKYLINE`, `--@@RESTYLE`). Pack it as `{mb16 = text}`, upload, then `require(DevTools.PatchMB16:Clone())(assetId)` splices it in, compile-checks and rebuilds the city. Helpers: `skin(part, kind, color)`, `kit(parent, name, cf, kx, tints)` (kx stretches along X; small groups cast no shadow), `run(...)` tiles 8-stud pieces. Lit windows are the kit's `Window` parts with `LitColor`. `restyle()` also turns the turf under both sidewalks into Ground.
- Backups: `DevTools.Round16_Backup_20261110` (City, MapBuilder, CityProps).

## Round 20 (2026-11-11): seaside city, hotel look stages, upgrades, intro, commands
- **City (replaces round 16b's shops and towers):** `src15/_mapbuilder16.lua` now holds the seaside. `shops()` = `beach()` terrain + the promenade (z 126..150, `PROM_Z`), `skyline()` = pier (`PIER_X = S.CROSS[2]`), boats, lighthouse, buoys; `restyle()` = surfaces, the road median and hill palms (`City.Backdrop`). `Shared.Street` is unchanged. Terrain facts: a water `FillBlock` doesn't replace turf, so clear to Air first; terrain smooths about 2 studs above a block top, so clear over decks.
- **AI meshes:** `generate_mesh` (segmentation none) drops a Model named after its prompt in workspace. `DevTools.Gen16`: `adopt(prefix, name, "CityProps", yaw)` makes a library template (pivot = bottom centre, yaw 180 turns the generated front to +Z); `swap(prefix, itemId)` / `swapAll` put a mesh into `Shared.Items.<id>` as `Body`, stretched to the old item's box. Old non-Body parts stay as invisible stubs (attribute `Stub`) because lights and scripts hang off them; placed copies in `workspace.Hotel.Placed` are renewed. About 8 generations at a time before the rate limit. `HotelProps` was not updated, so `HotelBuilder.makeItems` would bring the old models back.
- CityProps `TreeA/TreeB/TreeC` are now a coconut palm, a royal palm and a flame tree; also `PalmS`, `BeachCafe`, `IceCream`, `SurfShack`, `Gazebo`, `UmbrellaSet`, `Lifeguard`, `Sailboat`, `Yacht`, `Lighthouse`, `RowBoat`, `GlobeLamp`, `PlanterUrn`, `Bench`, `TrashBin`, `Balustrade` (Blender).
- **Upgrades:** `Shared.Upgrades` (`LIST`, `level`, `cost`, `effect`, `fold`, `look`); hotel attribute `Upgrades` (JSON), saved as `d.upgrades`. `Research.totals` folds them in, so `Research.mul/add` return research x upgrades; new stat `arrivals` divides the arrival gap in HotelSim. `ServerScriptService.Upgrades` handles `Remotes.Upgrade:InvokeServer(id)`. `StarterPlayerScripts.UpgradesUI` fills Coop's `Page_upgrades` (new entry in Coop `TABS`).
- **Hotel look:** `ServerStorage.HotelSkin` dresses parts by kind (attribute `SK`, with `SF`/`SC`) for stage `Upgrades.look(hotel)` = curb level + (Grade - 1), 0..4; hotel attribute `Look`; props in `<hotel>.LookDecor`. `ServerScriptService.HotelSkin` watches every plot. HotelBuilder is untouched.
- **Intro:** Cutscene `runIntro` on Notify `cutscene {kind = "intro"}`; Tutorial sends it before `tut2` and waits for `TutSkip "introDone"` (40 s cap).
- **Commands (ChatCommands, admin):** season ones set Shared attribute `SeasonForce` (read in `Clock.date`), weather ones set `TestWeather`, `/event<id>` sets the hotel's `TestEvent` + `TestSpawn` (the Studio-only gate in GuestEvents is gone), `/intro`, `/look n`, `/upgrades`, `/commands`.
- Snippets for Cutscene and ChatCommands: `src15/_patch20.lua`. Backups: `DevTools.Round20_Backup_20261111` (patched scripts), `DevTools.Round16_Backup_20261110` (old City, CityProps, Hotel, Items).

## Round 20b (2026-11-11): beds, showers, cars
- `DevTools.Gen16` additions: `take(prefix)`, `put(target, mesh, yaw)` (mesh becomes the target model's `Body`, others become stubs), `swapBed(cleanPrefix, messyPrefix, itemId)` (fills `Clean` and `Messy`, also in placed copies), `swapCar(prefix, kind)` (yaw -90: cars run along +X; fills `Shared.Cars.<kind>` and `CityProps.<kind>`).
- **Bed facing:** a bed body sits 180 degrees from the item pivot. Replacing every part of a sub-model moves its `WorldPivot`, so check facing on the whole item, never on a cloned `Clean` / `Messy` (that misled one round of checks).
- **Car tint:** a textured MeshPart ignores `Part.Color`. Car bodies carry a `SurfaceAppearance` (ColorMap = the generated texture, white paint) with attribute `Group = "paint"`; Traffic and MapBuilder's `prop()` now set `SurfaceAppearance.Color` as well as `Part.Color`. Old wheels, lamps and glass are invisible stubs (wheels still spin, unseen); `CityProps.CarWheel` is invisible.
- Backups: `Round20_Backup_20261111.Cars` and `.Traffic`; old beds and showers are in `Round16_Backup_20261110.Items`.

## Round 21 (2026-11-12): UI style "Clean", HUD, save files
- **Shared.UI** keeps its API; the look is new. `tools/ui21_apply.py` swaps tokens and 25 functions from `src15/_ui21_parts.lua` into the mirror (old one: `src15/_UI_r15v2_backup.lua`). Tokens: light cards (`ink`, `ink2`, `ink3`, `line`, `cream` = text), `brand` blue, and the HUD's dark glass `hud`, `hud2`, `hudLine`, `hudText`, `hudMuted`. `gloss`, `shine`, `sparkles`, `wordRim` do nothing now. `UI.G` = flat white glyphs (`tools/ui21.py` -> `export/g21`). `UI.toast` is the new notification (merges repeats, max 4).
- A colour pass rewrote every violet / lavender `Color3.fromRGB` literal in the UI scripts to blue / neutral (hue 0.62..0.84).
- **Client** top HUD = `src15/_hud21.lua` (same local names as before, so the rest of Client still works). **BuildClient** dock = `src15/_dock21.lua` (`barButton` still returns 7 values). **Coop**: the tab bar is hidden, pages moved up 42 px.
- **MainMenu** and **Loading** are new scripts (mirrors in src15). **Save files:** `Save.key(player, slot)` -> `u_<id>_s<1..3>`; `lastSlot` keeps the file for a wipe; a file with no data resets Cash and stats. Remotes.Menu: `("slots")` -> `{ ["1".."3"] = summary }`, `("play", n)`, `("delete", n)`.
- New scripts: `CommandsUI` (Notify `commands`), `ToolAim` (re-aims Mop / Broom welds each frame on the client).
- `Faces.wear` now puts one classic Roblox face decal (`F.CLASSIC`, picked by name); no `FaceUpper`, so NPCAnim's face code stays idle.
- Smaller UI: prompts `PS * 0.72`, Bubbles scale `* 0.72`, Talk `BASE = 1880 x 1080`. VoiceFX volume `* 0.55`, TTS `* 0.65`.
- Lighting night keys: brightness 0.6, exposure -0.3. Lamp PointLights are about a third as bright.
- Backups: `DevTools.Round21_Backup_20261112`.

## Round 22 (2026-11-11): empty start, free land, hotel styles
- **Template:** `workspace.Hotel.Placed` is empty now (old contents in `DevTools.Round22_Backup_20261111.TemplatePlaced`). Rooms 101-103 start `Unfurnished`; HotelSim opens a room when it gets a Bed, Shower and Toilet. Old saves rebuild their core items from `data.items` (Save's "not found" branch).
- **Save.load:** when the file has no data, `Builder.buildLand` runs for slots 104 and 105 (free land both sides), then NextRoom / NextRoomPrice and `ItemsChanged`. `C.START_CASH = 900`.
- **Styles:** `Shared.Upgrades.STYLES` / `STYLE_DEFAULT` / `U.style(hotel)`; hotel attribute `Style` (JSON `{lobby, rooms, walls, roof}`), saved as `d.style`. `Remotes.Upgrade:InvokeServer("style", key, id)` sets it (free).
- **HotelSkin:** part kind attribute is `SK3` now. Name-based kinds come first: `LobbyFloor` -> `s_lobby`, `Floor` under `Rooms` -> `s_rooms`, `Paper` / `PierIn` / `HeaderIn` / plaster `Core` -> `s_wall`; `tile` / `roof` kinds take the roof style from look stage 2 up. `Skin.dress(p, stage, style)`, `Skin.apply(root, stage, style)`. `watch` re-applies on `Style`, and again after 3 s and every 25 s (HotelBuilder's starterStyle repaints its parts). Decor rebuilds only when `DecorStage` changes.
- **UpgradesUI:** "HOTEL STYLE" rows (`Style_<key>`) under the upgrade cards. **TutorialClient:** steps 2 and 3 are "Open your first room" and "Close build mode".
- Edits scripted in `Run a Hotel tools/patch22.py`. Backups: `DevTools.Round22_Backup_20261111`.

## Round 23 (2026-11-11): build mode UI
- `BuildClient` keeps its logic; two UI blocks were replaced from `Run a Hotel tools/src15/_build23.lua` (split at `--@@B`): "key hints" up to "shape editor", and "selection pill" + `layout`. Spliced live by section markers; the src15 BuildClient mirror is stale (pull the live script before editing).
- Same local names as before, so the logic is untouched: `hintWrap/setHints/HINTS_*`, `shopWrap/shopHolder/list/cards/tabsApi.select(id, silent)/searchInput/thumb/room/refreshCards`, `toolWrap/toolHolder/S.rbRailBtn/S.setZones/S.undo`, `barWrap/bar/barBtns/heightPill/heightText`, `cardWrap/cardHolder/cardTitle/cardSub/cardBtns/cardActions`, `layout`.
- Catalog = `UI.panel` (light) at the left; tiles in a UIGridLayout; thumbnails are lazy (`wantThumb`, 4 a frame, only for tiles shown while building). Tool bar chips are `toolChip(label, options, current, order, tip, cb)` (click cycles). Bars are dark glass (`T.hud`).
- Slides: catalog from the left (-460), tool bar from below (120). `placeCard` uses 540 x 104. RoomBuilder wrap is 330 x 664 at y 84.
- `user_mouse_input` y is 58 px less than the screenshot's y (top bar inset).
- Backup: `DevTools.Round23_Backup_20261111.BuildClient`.

## Round 24 (2026-11-12): menu pages
- `StarterPlayerScripts.Coop`: everything between the "hotel page" and "tabs + open/close" markers was replaced from `Run a Hotel tools/src15/_menus24.lua`. Each page is a `do` block that fills `pages.<id>` and sets one of the forward locals `refreshHotel`, `refreshAll`, `refreshHire`, `refreshAch`.
- Shared helpers at the top of that block: `block(parent, h, order)` (flat card, h = 0 grows), `caps`, `meter(parent, pos, size, color)` -> fill, `pills(parent, items, current, order, onPick)`, `pageRoot(P)`, `column(root, pos, size, gap)`, `figure(parent, caption, order, color)`.
- The older helpers above it (`row`, `rowIcon`, `heading`, `columns`, `tile`, `stars`, `hotelQuests`) are still there; only `stars` and `hotelQuests` are used by the new pages.
- `showTab` finds the header icon with `FindFirstChildWhichIsA("ImageLabel", true)`.
- Pull a live script to disk: return its Source from `execute_luau` padded past the size limit, so the result is saved to a tool-results file (`live/Coop.lua` was made this way).
- Backup: `DevTools.Round24_Backup_20261112.Coop`.

## Round 25 (2026-11-12): Upgrades page
- `StarterPlayerScripts.UpgradesUI` rewritten (mirror in `src15`, pushed with `push.py`). It builds `Page_upgrades.Root` with `Left` (`Comeback` card for `curb`, then `Grid` with one card per other `U.LIST` entry, named by id, each with a `Buy` button) and `Right` (`Style_<key>.Swatches.<finishId>` buttons).
- Buy buttons are `green` when `player.Cash >= cost`, `ink` when not, disabled at max. Redraws on the hotel's `Upgrades` / `Grade` / `Style` and the player's `Cash`.
- Backup: `DevTools.Round25_Backup_20261112.UpgradesUI`.

## Round 26 (2026-11-12): Research page
- `StarterPlayerScripts.ResearchUI` rewritten (mirror in `src15`; the old one is in `live/ResearchUI.lua`). Logic, remotes and attributes are unchanged (`OpenResearch`, `ResearchOpen`, `Remotes.Research` "start" / "cancel").
- It clears `Page_research` and builds `Lab` (bar, `Stop`), `Branches` (rows named by branch id), `Tree` (`Canvas.Nodes.<nodeId>` cards, `Canvas.Lines` elbows) and `Card` (`Info`, footer with `Start`). The page is laid out for 1240 x 830.
- `showBranch(id, focus)` lays tiers out as columns (width 128..200); `refresh()` runs every 0.5 s while open.
- Backup: `DevTools.Round26_Backup_20261112.ResearchUI`.

## Round 27 (2026-11-12): staff work on the real objects
- **Contract:** with a work pose the server also sets the model attribute `WorkAt` (Vector3, the point on the object). Poses in `Shared.NPCAnimLib` with `anchor = { R, L }` write their hand keys in studs round that point (x = their right, y = up, z = toward them). `NPCAnim` turns them into arm targets each frame (`handTarget`) and leans / crouches the body until the hands reach (`st.lean`; `noLean`, `minCrouch` per pose). With no `WorkAt` the arms are left alone.
- **New poses:** `makebed`, `scrub` (prop `Brush`), `wipe` (prop `CleanKit`), `dust` (prop `Duster`), `fixat`, `cookat` (prop `CookKit`), `deskkeys`. `Lib.ANCHORED.desk` swaps `desk` for `deskkeys` when a part named `Keyboard` is found in the hotel's desks (`findNear`; kit parts don't answer spatial queries). The old `fix` / `cook` / `desk` poses stay as fallbacks.
- **Server (`HotelSim`, all in `evCtx` because of the local limit):** `workPoint(g, model, mode, inset, fallY)` raycasts the model itself (`"top"`, `"face"`, `"low"`), `workStart` steps them to 1.25 studs from its face (1.9 for `"low"`) and sets `WorkAt`, `workEnd` clears it, `workOn` wraps a timed job. Mode `"inside"` (walk-in shower) uses `pose` / `unpose` to stand them inside facing the back wall. `evCtx.WORK` maps Bed / Toilet / Shower to their pose. `Upkeep` (repairs) and `Kitchen` (cooking) call `ctx.workStart` / `ctx.workEnd`. Only janitors take the dust / tidy idle jobs now.
- **Mop:** `Lib.TOOLS` (head and top-hand distance from the grip), `Lib.TOOL_CARRY`. `NPCAnim.toolOf` finds the weld (it is parented to the mop part, with `Part0` = RightHand, which is why the old `ToolAim` never found it; `ToolAim` is now disabled). `stepTool` keeps the head on the floor toward the pose's `hx` / `hz` channels, solves the left hand onto the handle, and for any pose but `mop` stands the mop beside them (the weld's `Part0` is switched to the root locally).
- Mirrors in `src15`: NPCAnimLib, NPCAnim, HotelSim, Upkeep, Kitchen. Backup: `DevTools.Round27_Backup_20261112`.

## Round 28 (2026-11-12): build mode handling
- `BuildClient` (the `src15` mirror is current again; `Run a Hotel tools/live/BuildClient.lua` is the pre-round copy). The script has about 174 top-level locals, so everything new hangs off `S` or `input`.
- **Press modes:** on left press `input.downOn` = the placed model under the cursor. Once the cursor has moved 7 px with no ghost, `S.beginDrag()` sets `input.mode`: `"grab"` (`makeGhost(id, model)` with `ghost.grab` and `ghost.off`, the XZ offset from the press point to the pivot; release commits or cancels), `"pan"` (`S.pan = { anchor }`), or `"none"` (booked room). With a ghost in hand left-drag is still the row drag.
- **Pan:** in the `BuildLook` render step (after `BuildCam`) the grabbed floor point is kept under the cursor by shifting `cam.focus` and `goal.focus`. Middle button sets `S.pan.mid`.
- **Zoom:** scrolling in moves `goal.focus` toward the floor point under the cursor; scrolling out stays centred.
- **Cutaway:** `S.walls` ("cut" / "full"), `S.cutScan()` (every 1.5 s: tall thin parts of Shell / Rooms / Doors behind the facade line, plus placed structure items), `S.cutStep(dt)` fades those on the camera's side of `cam.focus` to `LocalTransparencyModifier` 0.9, `S.cutRestore()` on leave. `placedAt` and `aimHit` skip parts faded past 0.5.
- **Feedback:** `Shared.Build.validate` sets `Build.lastBlocker` (the placed model in the way); `S.blockHL` outlines it; `S.foot` is the footprint part (`ghost.boxOff` / `ghost.boxSize`).
- **Undo:** `S.undo` entries may be `{ move = uid or "desk", cf = oldPivot }` (from a move or a Turn); `S.doUndo` sends the old pivot back.
- Backup: `DevTools.Round28_Backup_20261112` (BuildClient, Build).

## Round 29 (2026-11-12): hotel front
- Heights at a plot front: road 0, pavement 0.5, entrance path 0.5, hotel floor and tarmac `FY` = 1 (0.98), lawn about 2.
- `HotelBuilder.parking` (edited live, no src15 mirror): per lot it now also builds `Verge` (paving from the kerb to z 57.05), `DriveBase` + `Drive` (a 12-stud sloped driveway in the middle of the street side), `Forecourt` (paving between the path edge at x 8.5 and the lot), `SignPost` + `ParkSign`. The street-side and path-side kerbs are `FY + 0.28`; the back and outer kerbs stay `FY + 1.1` (they hold the lawn). Terrain is cleared from `FY - 3` up over the paving, and lot decor standing in the forecourt is lifted onto it.
- Template terrain: `Ground` was replaced with `LeafyGrass` in x -212..212, z 28..64 (the region each plot copies).
- `HotelSim.parkCar` scales a guest car (`ScaleTo`) to at most 14.6 x 6.4 studs.
- Car paints (140,30,40) and (30,60,110) became (206,84,84) and (70,120,200) in `Traffic` and `MapBuilder`; the parked cars in `City.Parked` were repainted.
- Backup: `DevTools.Round29_Backup_20261112` (HotelBuilder, MapBuilder, Traffic, HotelSim).
