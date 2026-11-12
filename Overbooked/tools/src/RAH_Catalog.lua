-- ReplicatedStorage.RAH.Catalog: everything you can place in build mode.
-- price = shop cost, appeal = how much nicer it makes the room/lobby it stands in.
-- core = a room's own bed/shower/toilet: can be moved inside its room, never bought or sold.
-- coreKind = a buyable upgrade (deluxe bed, rain shower...): placed in a room it becomes that
--   room's core item of that kind, and the old one turns back into plain furniture.
-- structure = walls and doors: tall, block movement and pathfinding.
-- doorway = a door: guests walk straight through it, so it may sit in a doorway.
-- flat = lies on the floor (rugs): may sit under other furniture. soft = guests walk through it.
-- research = the RAH.Research node that unlocks it. wall = hangs on a wall (build mode snaps it flush).
-- mount = default height above the floor for wall items.
-- room = only makes sense in a guest room; tags = what guest events look for (RAH.Events).
-- shape = a custom block (round 9): any size, colour and material; price scales with its volume.
local Catalog = {}

Catalog.SELL_BACK = 0.75
Catalog.PRICE_PER_APPEAL = 3 -- room price per stay = Config.ROOM_PRICE + appeal * this

Catalog.CATS = {
	{ id = "all", name = "All", icon = "catAll" },
	{ id = "furniture", name = "Furniture", icon = "catFurniture" },
	{ id = "decor", name = "Decor", icon = "catDecor" },
	{ id = "lighting", name = "Lighting", icon = "lamp" },
	{ id = "fun", name = "Fun", icon = "catFun" },
	{ id = "amenities", name = "Amenities", icon = "bell" },
	{ id = "kitchen", name = "Kitchen", icon = "food" },
	{ id = "rooms", name = "Rooms", icon = "bed" },
	{ id = "shapes", name = "Shapes", icon = "shapes" },
	{ id = "structure", name = "Structure", icon = "door" },
	{ id = "staff", name = "Staff", icon = "staff" },
	{ id = "outdoor", name = "Outdoor", icon = "sun" },
}

Catalog.ITEMS = {
	Bed = { name = "Bed", cat = "rooms", price = 200, appeal = 5, core = "Bed" },
	Shower = { name = "Shower", cat = "rooms", price = 150, appeal = 4, core = "Shower", soft = true },
	Toilet = { name = "Toilet", cat = "rooms", price = 100, appeal = 3, core = "Toilet" },

	Sofa = { name = "Sofa", cat = "furniture", price = 250, appeal = 6 },
	Armchair = { name = "Armchair", cat = "furniture", price = 120, appeal = 3 },
	CoffeeTable = { name = "Coffee Table", cat = "furniture", price = 90, appeal = 2 },
	SideTable = { name = "Flower Table", cat = "furniture", price = 90, appeal = 3 },
	Nightstand = { name = "Nightstand", cat = "furniture", price = 80, appeal = 2 },
	Wardrobe = { name = "Wardrobe", cat = "furniture", price = 180, appeal = 4 },
	Bookshelf = { name = "Bookshelf", cat = "furniture", price = 160, appeal = 4 },
	TVStand = { name = "TV", cat = "furniture", price = 300, appeal = 8, tags = { "tv" } },

	Plant = { name = "Monstera", cat = "decor", price = 60, appeal = 2, soft = true },
	PottedTree = { name = "Topiary Tree", cat = "decor", price = 110, appeal = 3 },
	FloorLamp = { name = "Floor Lamp", cat = "lighting", price = 70, appeal = 2, soft = true },
	Rug = { name = "Rug", cat = "decor", price = 50, appeal = 2, flat = true, soft = true },

	PingPongTable = { name = "Ping-Pong Table", cat = "fun", price = 400, appeal = 10 },
	VendingMachine = { name = "Vending Machine", cat = "fun", price = 350, appeal = 8, tags = { "snack" } },

	Wall = { name = "Wall", cat = "structure", price = 40, appeal = 0, structure = true, wallKind = "Wall" },
	Door = { name = "Door", cat = "structure", price = 90, appeal = 1, structure = true, doorway = true, wallKind = "Door" },
	-- round 10e: more walls, windows and doors (wallKind = what they count as when rooms are found)
	WallBrick = { name = "Brick Wall", cat = "structure", price = 70, appeal = 1, structure = true, wallKind = "Wall" },
	WallWood = { name = "Panelled Wall", cat = "structure", price = 90, appeal = 2, structure = true, wallKind = "Wall" },
	WallSage = { name = "Sage Wall", cat = "structure", price = 50, appeal = 1, structure = true, wallKind = "Wall" },
	WallWindow = { name = "Window Wall", cat = "structure", price = 120, appeal = 3, structure = true, wallKind = "Wall" },
	WallWindowBrick = { name = "Brick Window", cat = "structure", price = 150, appeal = 3, structure = true, wallKind = "Wall", level = 2 },
	WallGlass = { name = "Glass Partition", cat = "structure", price = 220, appeal = 4, structure = true, wallKind = "Wall", level = 3 },
	HalfWall = { name = "Half Wall", cat = "structure", price = 60, appeal = 1, structure = true },
	DoorWhite = { name = "White Door", cat = "structure", price = 130, appeal = 2, structure = true, doorway = true, wallKind = "Door" },
	DoorGlass = { name = "Glass Door", cat = "structure", price = 260, appeal = 4, structure = true, doorway = true, wallKind = "Door", level = 3 },
	-- round 13: hotel room doors (card reader, cornice, kick plate). They close a room like any Door
	RoomDoor = { name = "Room Door", cat = "structure", price = 160, appeal = 3, structure = true, doorway = true, wallKind = "Door" },
	RoomDoorSuite = { name = "Suite Door", cat = "structure", price = 340, appeal = 5, structure = true, doorway = true, wallKind = "Door", level = 4 },
	RoomDoorModern = { name = "Modern Room Door", cat = "structure", price = 300, appeal = 5, structure = true, doorway = true, wallKind = "Door", level = 3 },
	Desk = { name = "Desk", cat = "furniture", price = 500, appeal = 6 },

	BedDeluxe = { name = "Deluxe Bed", cat = "rooms", price = 600, appeal = 12, coreKind = "Bed" },
	BedSuite = { name = "Suite Bed", cat = "rooms", price = 1200, appeal = 24, coreKind = "Bed", sleeps = 2 },
	ShowerRain = { name = "Rain Shower", cat = "rooms", price = 450, appeal = 9, coreKind = "Shower", soft = true },
	ToiletDeluxe = { name = "Deluxe Toilet", cat = "rooms", price = 300, appeal = 7, coreKind = "Toilet" },

	-- round 9: furniture
	Loveseat = { name = "Velvet Loveseat", cat = "furniture", price = 320, appeal = 7, research = "comfort1" },
	Ottoman = { name = "Pouf", cat = "furniture", price = 90, appeal = 2, research = "comfort1" },
	LoungeChair = { name = "Lounge Chair", cat = "furniture", price = 260, appeal = 6, research = "comfort1" },
	DiningSet = { name = "Dining Set", cat = "furniture", price = 520, appeal = 10, research = "comfort2" },
	BarStool = { name = "Bar Stool", cat = "furniture", price = 80, appeal = 2, research = "comfort2" },
	Sectional = { name = "Corner Sofa", cat = "furniture", price = 900, appeal = 16, research = "comfort3" },
	ConsoleTable = { name = "Console Table", cat = "furniture", price = 340, appeal = 7, research = "decor3" },
	Dresser = { name = "Dresser", cat = "rooms", price = 260, appeal = 6, research = "rooms1", room = true },
	LuggageRack = { name = "Luggage Rack", cat = "rooms", price = 90, appeal = 2, research = "rooms1", room = true },
	MiniFridge = { name = "Mini Fridge", cat = "rooms", price = 180, appeal = 4, research = "rooms1", room = true, tags = { "snack" } },
	WorkDesk = { name = "Work Desk", cat = "rooms", price = 420, appeal = 8, research = "rooms2", room = true, tags = { "work" } },
	-- decor
	WallArt = { name = "Wall Art", cat = "decor", price = 140, appeal = 4, research = "decor1", wall = true, mount = 4 },
	Mirror = { name = "Sunburst Mirror", cat = "decor", price = 160, appeal = 4, research = "decor1", wall = true, mount = 3.6 },
	FloorVase = { name = "Blossom Vase", cat = "decor", price = 120, appeal = 3, research = "decor1" },
	Sculpture = { name = "Brass Sculpture", cat = "decor", price = 380, appeal = 8, research = "decor2" },
	FlowerStand = { name = "Flower Stand", cat = "decor", price = 220, appeal = 5, research = "decor2" },
	SnakePlant = { name = "Snake Plant", cat = "decor", price = 90, appeal = 2, research = "decor2" },
	IndoorPalm = { name = "Indoor Palm", cat = "decor", price = 260, appeal = 5, research = "decor3" },
	Aquarium = { name = "Aquarium", cat = "decor", price = 900, appeal = 15, research = "decor3" },
	Fireplace = { name = "Fireplace", cat = "decor", price = 1100, appeal = 18, research = "decor3" },
	GrandfatherClock = { name = "Grandfather Clock", cat = "decor", price = 600, appeal = 10, research = "decor3" },
	GrandPiano = { name = "Grand Piano", cat = "decor", price = 2400, appeal = 30, research = "decor4" },
	DeskGlobe = { name = "Globe", cat = "decor", price = 300, appeal = 6, research = "decor4" },
	CoatRack = { name = "Coat Rack", cat = "decor", price = 150, appeal = 3, research = "decor4" },
	-- lighting
	TableLamp = { name = "Table Lamp", cat = "lighting", price = 80, appeal = 2, research = "decor1", soft = true },
	ArcLamp = { name = "Arc Lamp", cat = "lighting", price = 240, appeal = 5, research = "decor2", soft = true },
	WallSconce = { name = "Wall Sconce", cat = "lighting", price = 110, appeal = 3, research = "decor2", wall = true, mount = 5.4, soft = true },
	-- fun
	Arcade = { name = "Arcade Cabinet", cat = "fun", price = 700, appeal = 12, research = "fun1" },
	Foosball = { name = "Foosball", cat = "fun", price = 550, appeal = 10, research = "fun1" },
	ClawMachine = { name = "Claw Machine", cat = "fun", price = 900, appeal = 14, research = "fun2" },
	Jukebox = { name = "Jukebox", cat = "fun", price = 1000, appeal = 15, research = "fun2" },
	PoolTable = { name = "Pool Table", cat = "fun", price = 2200, appeal = 26, research = "fun3" },
	MassageChair = { name = "Massage Chair", cat = "fun", price = 1300, appeal = 18, research = "comfort3" },
	-- amenities
	FireExtinguisher = { name = "Fire Extinguisher", cat = "amenities", price = 60, appeal = 1, research = "safety", tags = { "safety" } },
	FirstAid = { name = "First-Aid Kit", cat = "amenities", price = 70, appeal = 1, research = "safety", wall = true, mount = 3.8, tags = { "safety" } },
	LobbyBin = { name = "Lobby Bin", cat = "amenities", price = 50, appeal = 1, research = "safety", tags = { "safety" } },
	CoffeeBar = { name = "Coffee Bar", cat = "amenities", price = 650, appeal = 12, research = "service1", tags = { "snack" } },
	WaterCooler = { name = "Water Cooler", cat = "amenities", price = 160, appeal = 3, research = "service1", tags = { "snack" } },
	BrochureStand = { name = "Brochure Stand", cat = "amenities", price = 120, appeal = 3, research = "service1" },
	LuggageCart = { name = "Luggage Cart", cat = "amenities", price = 380, appeal = 7, research = "service2" },
	ATM = { name = "ATM", cat = "amenities", price = 800, appeal = 9, research = "service2" },
	-- round 10c: more to build with
	Chesterfield = { name = "Chesterfield", cat = "furniture", price = 780, appeal = 14, research = "comfort2" },
	ChessTable = { name = "Chess Table", cat = "fun", price = 640, appeal = 11, research = "fun1", tags = { "play" } },
	Dartboard = { name = "Dartboard", cat = "fun", price = 380, appeal = 7, research = "fun1", tags = { "play" } },
	Gramophone = { name = "Gramophone", cat = "decor", price = 520, appeal = 9, research = "decor2" },
	Bonsai = { name = "Bonsai", cat = "decor", price = 180, appeal = 4, research = "decor1" },
	Easel = { name = "Painter's Easel", cat = "decor", price = 260, appeal = 5, research = "decor2" },
	Telescope = { name = "Telescope", cat = "decor", price = 900, appeal = 13, research = "decor4" },
	Column = { name = "Marble Column", cat = "decor", price = 450, appeal = 7, research = "decor3" },
	Candelabra = { name = "Candelabra", cat = "lighting", price = 340, appeal = 7, research = "decor3", soft = true },
	UmbrellaStand = { name = "Umbrella Stand", cat = "amenities", price = 140, appeal = 3, research = "service1", tags = { "rain" } },
	Vanity = { name = "Vanity", cat = "rooms", price = 480, appeal = 9, research = "rooms1", room = true },
	Bathtub = { name = "Clawfoot Bath", cat = "rooms", price = 1200, appeal = 18, research = "rooms2", room = true, tags = { "bath" } },
	-- the kitchen (round 10c, hotel level 3): a Stove and a Serving Counter open it; guests eat at cafe tables
	Stove = { name = "Stove", cat = "kitchen", price = 600, appeal = 6, level = 3, tags = { "stove" } },
	PrepCounter = { name = "Prep Counter", cat = "kitchen", price = 280, appeal = 4, level = 3 },
	KitchenFridge = { name = "Kitchen Fridge", cat = "kitchen", price = 450, appeal = 4, level = 3 },
	ServingCounter = { name = "Serving Counter", cat = "kitchen", price = 700, appeal = 8, level = 3, tags = { "serve" } },
	CafeTable = { name = "Cafe Table", cat = "kitchen", price = 320, appeal = 6, level = 3 },
	-- event gear
	Crib = { name = "Crib", cat = "rooms", price = 240, appeal = 4, research = "ev_family", room = true, tags = { "baby" } },
	ShowerChair = { name = "Shower Chair", cat = "rooms", price = 160, appeal = 2, research = "ev_access", room = true, soft = true, tags = { "access" } },
	GrabBar = { name = "Grab Bar", cat = "rooms", price = 80, appeal = 1, research = "ev_access", room = true, wall = true, mount = 2.6, soft = true, tags = { "access" } },
	PetBed = { name = "Pet Bed", cat = "rooms", price = 140, appeal = 3, research = "ev_pets", room = true, flat = true, tags = { "pet" } },
	PartyKit = { name = "Party Kit", cat = "rooms", price = 300, appeal = 6, research = "ev_party", room = true, tags = { "party" } },
	ChampagneBucket = { name = "Champagne Bucket", cat = "rooms", price = 360, appeal = 7, research = "ev_romance", room = true, tags = { "romance" } },

	-- round 10e: more beds (sleeps = how many guests of a group share it), fun for guests, players and staff,
	-- the staff room, room service and the car park (outdoor = only in the Parking zones out front)
	BedBunk = { name = "Bunk Bed", cat = "rooms", price = 450, appeal = 6, coreKind = "Bed", sleeps = 2, level = 2 },
	BedTwin = { name = "Twin Beds", cat = "rooms", price = 700, appeal = 10, coreKind = "Bed", sleeps = 2, level = 4 },
	BedCanopy = { name = "Four-Poster Bed", cat = "rooms", price = 2200, appeal = 30, coreKind = "Bed", sleeps = 2, level = 11 },
	Pinball = { name = "Pinball", cat = "fun", price = 600, appeal = 10, level = 3, tags = { "play" } },
	Treadmill = { name = "Treadmill", cat = "fun", price = 500, appeal = 7, level = 3, tags = { "play", "gym" } },
	AirHockey = { name = "Air Hockey", cat = "fun", price = 750, appeal = 12, level = 4, tags = { "play" } },
	PhotoBooth = { name = "Photo Booth", cat = "fun", price = 900, appeal = 13, level = 5, tags = { "play" } },
	KaraokeStage = { name = "Karaoke Stage", cat = "fun", price = 1400, appeal = 18, level = 6, tags = { "play", "party" } },
	HotTub = { name = "Hot Tub", cat = "fun", price = 2600, appeal = 28, level = 9, tags = { "play", "bath" } },
	StaffLocker = { name = "Staff Lockers", cat = "staff", price = 300, appeal = 0, tags = { "staffroom" } },
	StaffTable = { name = "Break Table", cat = "staff", price = 200, appeal = 0, tags = { "staffbreak" } },
	ServiceCart = { name = "Room Service Cart", cat = "amenities", price = 350, appeal = 4, tags = { "roomservice" } },
	ParkingSpot = { name = "Parking Spot", cat = "outdoor", price = 150, appeal = 2, outdoor = true, flat = true, soft = true },

	-- round 12: a lot more to build with
	DiningChair = { name = "Dining Chair", cat = "furniture", price = 110, appeal = 3, level = 2 },
	LobbyBench = { name = "Tufted Bench", cat = "furniture", price = 240, appeal = 5, level = 2 },
	Beanbag = { name = "Beanbag", cat = "furniture", price = 120, appeal = 3, level = 2 },
	RoundTable = { name = "Round Table", cat = "furniture", price = 200, appeal = 4, level = 2 },
	ReadingNook = { name = "Reading Nook", cat = "furniture", price = 480, appeal = 9, level = 4 },
	Bookcase = { name = "Tall Bookcase", cat = "furniture", price = 380, appeal = 7, level = 3 },
	BarCounter = { name = "Bar Counter", cat = "furniture", price = 1200, appeal = 16, level = 6, tags = { "snack" } },
	RoomDivider = { name = "Room Divider", cat = "decor", price = 180, appeal = 3, level = 2 },
	Planter = { name = "Hedge Planter", cat = "decor", price = 160, appeal = 4, level = 1 },
	Statue = { name = "Marble Statue", cat = "decor", price = 850, appeal = 13, level = 5 },
	Fountain = { name = "Lobby Fountain", cat = "decor", price = 1800, appeal = 24, level = 7 },
	Tapestry = { name = "Tapestry", cat = "decor", price = 260, appeal = 5, level = 3, wall = true, mount = 3.2 },
	NeonSign = { name = "Neon Sign", cat = "lighting", price = 420, appeal = 8, level = 4, wall = true, mount = 5.2, soft = true },
	PendantLamp = { name = "Pendant Lamp", cat = "lighting", price = 180, appeal = 4, level = 2, soft = true },
	Chandelier = { name = "Chandelier", cat = "lighting", price = 1500, appeal = 20, level = 6, soft = true },
	LanternPost = { name = "Lantern Post", cat = "lighting", price = 220, appeal = 4, level = 2 },
	DJBooth = { name = "DJ Booth", cat = "fun", price = 1600, appeal = 20, level = 7, tags = { "play", "party" } },
	VRPod = { name = "VR Pod", cat = "fun", price = 2000, appeal = 24, level = 8, tags = { "play" } },
	MiniGolf = { name = "Mini Golf Hole", cat = "fun", price = 800, appeal = 12, level = 4, tags = { "play" } },
	Gumball = { name = "Gumball Machine", cat = "fun", price = 200, appeal = 4, level = 2, tags = { "snack" } },
	PhoneBooth = { name = "Phone Booth", cat = "amenities", price = 650, appeal = 9, level = 5 },
	IceMachine = { name = "Ice Machine", cat = "amenities", price = 400, appeal = 5, level = 3, tags = { "snack" } },
	KeyRack = { name = "Key Rack", cat = "amenities", price = 150, appeal = 3, level = 2, wall = true, mount = 4.2 },
	TowelStack = { name = "Towel Shelf", cat = "rooms", price = 140, appeal = 3, level = 2, room = true },
	RoomSafe = { name = "Room Safe", cat = "rooms", price = 260, appeal = 4, level = 3, room = true },
	BikeRack = { name = "Bike Rack", cat = "outdoor", price = 180, appeal = 2, level = 2, outdoor = true },
	ParkBench = { name = "Park Bench", cat = "outdoor", price = 200, appeal = 3, level = 1, outdoor = true },

	-- shapes: any size (studs), colour and material
	ShapeBlock = { name = "Block", cat = "shapes", shape = "Block", price = 4, appeal = 0, research = "shapes1" },
	ShapeWedge = { name = "Wedge", cat = "shapes", shape = "Wedge", price = 4, appeal = 0, research = "shapes1" },
	ShapeCylinder = { name = "Cylinder", cat = "shapes", shape = "Cylinder", price = 5, appeal = 0, research = "shapes1" },
	ShapeBall = { name = "Ball", cat = "shapes", shape = "Ball", price = 5, appeal = 0, research = "shapes2" },
	ShapeCorner = { name = "Corner Wedge", cat = "shapes", shape = "CornerWedge", price = 4, appeal = 0, research = "shapes2" },
}

Catalog.ORDER = {
	"Plant", "Rug", "FloorLamp", "PottedTree", "Nightstand", "CoffeeTable", "SideTable", "Armchair",
	"Bookshelf", "Wardrobe", "Sofa", "TVStand", "VendingMachine", "PingPongTable",
	"Loveseat", "Ottoman", "LoungeChair", "DiningSet", "BarStool", "Sectional", "ConsoleTable",
	"WallArt", "Mirror", "FloorVase", "SnakePlant", "Sculpture", "FlowerStand", "IndoorPalm", "Aquarium",
	"Fireplace", "GrandfatherClock", "DeskGlobe", "CoatRack", "GrandPiano",
	"Chesterfield", "Bonsai", "Easel", "Gramophone", "Column", "Telescope", "Candelabra",
	"TableLamp", "ArcLamp", "WallSconce",
	"Dartboard", "ChessTable", "Arcade", "Foosball", "ClawMachine", "Jukebox", "MassageChair", "PoolTable",
	"FireExtinguisher", "FirstAid", "LobbyBin", "WaterCooler", "BrochureStand", "CoffeeBar", "LuggageCart", "ATM", "UmbrellaStand",
	"ParkingSpot", "StaffLocker", "StaffTable", "ServiceCart",
	"Pinball", "Treadmill", "AirHockey", "PhotoBooth", "KaraokeStage", "HotTub",
	"Stove", "PrepCounter", "KitchenFridge", "ServingCounter", "CafeTable",
	"Dresser", "LuggageRack", "MiniFridge", "WorkDesk", "Vanity", "Bathtub", "Crib", "ShowerChair", "GrabBar", "PetBed", "PartyKit", "ChampagneBucket",
	"ShapeBlock", "ShapeWedge", "ShapeCylinder", "ShapeBall", "ShapeCorner",
	"RoomDoor", "RoomDoorModern", "RoomDoorSuite", "Wall", "WallSage", "WallBrick", "WallWood", "WallWindow", "WallWindowBrick", "WallGlass", "HalfWall", "Door", "DoorWhite", "DoorGlass", "Desk", "Bed", "Shower", "Toilet", "BedDeluxe", "BedSuite", "ShowerRain", "ToiletDeluxe",
	"BedBunk", "BedTwin", "BedCanopy",
	"DiningChair", "LobbyBench", "Beanbag", "RoundTable", "ReadingNook", "Bookcase", "BarCounter",
	"Planter", "RoomDivider", "Tapestry", "Statue", "Fountain",
	"PendantLamp", "LanternPost", "NeonSign", "Chandelier",
	"Gumball", "MiniGolf", "DJBooth", "VRPod",
	"KeyRack", "IceMachine", "PhoneBooth", "TowelStack", "RoomSafe", "ParkBench", "BikeRack",
}

-- shapes: limits, finishes (research gates some) and the swatch palette
Catalog.SHAPE_MIN, Catalog.SHAPE_MAX = 0.2, 24
Catalog.SHAPE_DEFAULT = Vector3.new(4, 4, 4)
Catalog.MATERIALS = {
	{ id = "SmoothPlastic", name = "Matte" },
	{ id = "Plastic", name = "Plastic" },
	{ id = "Wood", name = "Wood" },
	{ id = "WoodPlanks", name = "Planks" },
	{ id = "Fabric", name = "Fabric" },
	{ id = "Concrete", name = "Concrete" },
	{ id = "Metal", name = "Metal" },
	{ id = "Marble", name = "Marble", research = "shapes2" },
	{ id = "Granite", name = "Granite", research = "shapes2" },
	{ id = "Brick", name = "Brick", research = "shapes2" },
	{ id = "Slate", name = "Slate", research = "shapes2" },
	{ id = "Glass", name = "Glass", research = "glassneon" },
	{ id = "Neon", name = "Neon", research = "glassneon" },
}
Catalog.MAT_BY_ID = {}
for _, m in ipairs(Catalog.MATERIALS) do Catalog.MAT_BY_ID[m.id] = m end
Catalog.SWATCHES = {
	Color3.fromRGB(250, 248, 244), Color3.fromRGB(214, 208, 198), Color3.fromRGB(140, 138, 134), Color3.fromRGB(46, 48, 56),
	Color3.fromRGB(20, 20, 24), Color3.fromRGB(122, 74, 46), Color3.fromRGB(196, 146, 96), Color3.fromRGB(232, 190, 106),
	Color3.fromRGB(176, 40, 52), Color3.fromRGB(236, 96, 80), Color3.fromRGB(246, 160, 60), Color3.fromRGB(250, 214, 90),
	Color3.fromRGB(150, 200, 90), Color3.fromRGB(56, 140, 90), Color3.fromRGB(70, 160, 160), Color3.fromRGB(110, 190, 240),
	Color3.fromRGB(52, 100, 200), Color3.fromRGB(40, 50, 110), Color3.fromRGB(150, 110, 230), Color3.fromRGB(230, 130, 200),
	Color3.fromRGB(250, 196, 206), Color3.fromRGB(196, 230, 210), Color3.fromRGB(210, 226, 250), Color3.fromRGB(255, 236, 200),
}

-- where guests stand / lie / sit, relative to a core item's pivot (floor centre, front = +Z)
Catalog.CORE = {
	Bed = {
		lie = CFrame.fromMatrix(Vector3.new(0, 3.3, -0.35), Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1)),
		sides = { Vector3.new(4.4, 3, 1.5), Vector3.new(-4.4, 3, 1.5), Vector3.new(0, 3, 6.3) },
		clean = Vector3.new(0, 3.2, 3.75),
	},
	Shower = {
		inside = CFrame.lookAt(Vector3.new(-0.2, 3.34, 0.2), Vector3.new(-0.2, 3.34, 10)),
		front = Vector3.new(0, 2.94, 5.4),
		clean = Vector3.new(0, 3.14, 3.0),
		head = Vector3.new(0, 7.75, -0.5),
	},
	Toilet = {
		sit = CFrame.lookAt(Vector3.new(0, 2.49, 0.35), Vector3.new(0, 2.49, 10)),
		front = Vector3.new(0, 2.94, 3.7),
		clean = Vector3.new(0, 2.54, 2.0),
	},
}

-- a shape's price: its base price per 64 cubic studs, never under $2
function Catalog.shapePrice(id, size)
	local it = Catalog.ITEMS[id]
	if not it or not it.shape then return 0 end
	size = size or Catalog.SHAPE_DEFAULT
	local v = size.X * size.Y * size.Z
	if it.shape == "Ball" then v = size.X ^ 3 * 0.52 end
	if it.shape == "Cylinder" then v = size.X * size.X * size.Y * 0.79 end
	if it.shape == "Wedge" or it.shape == "CornerWedge" then v *= 0.5 end
	return math.max(2, math.floor(it.price * v / 64 + 0.5))
end

function Catalog.price(id, size)
	local it = Catalog.ITEMS[id]
	if not it then return 0 end
	if it.shape then return Catalog.shapePrice(id, size) end
	return it.price or 0
end

function Catalog.sellValue(id, size)
	return math.floor(Catalog.price(id, size) * Catalog.SELL_BACK)
end

function Catalog.hasTag(id, tag)
	local it = Catalog.ITEMS[id]
	if not it or not it.tags then return false end
	return table.find(it.tags, tag) ~= nil
end

return Catalog
