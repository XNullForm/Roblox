-- ReplicatedStorage.RAH.Catalog: everything you can place in build mode.
-- price = shop cost, appeal = how much nicer it makes the room/lobby it stands in.
-- core = a room's own bed/shower/toilet: can be moved inside its room, never bought or sold.
-- coreKind = a buyable upgrade (deluxe bed, rain shower...): placed in a room it becomes that
--   room's core item of that kind, and the old one turns back into plain furniture.
-- structure = walls and doors: tall, block movement and pathfinding.
-- doorway = a door: guests walk straight through it, so it may sit in a doorway.
-- flat = lies on the floor (rugs): may sit under other furniture. soft = guests walk through it.
local Catalog = {}

Catalog.SELL_BACK = 0.75
Catalog.PRICE_PER_APPEAL = 3 -- room price per stay = Config.ROOM_PRICE + appeal * this

Catalog.CATS = {
	{ id = "all", name = "All", icon = "catAll" },
	{ id = "structure", name = "Structure", icon = "door" },
	{ id = "furniture", name = "Furniture", icon = "catFurniture" },
	{ id = "decor", name = "Decor", icon = "catDecor" },	
	{ id = "fun", name = "Fun", icon = "catFun" },
	{ id = "rooms", name = "Rooms", icon = "bed" },
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
	TVStand = { name = "TV", cat = "furniture", price = 300, appeal = 8 },

	Plant = { name = "Monstera", cat = "decor", price = 60, appeal = 2, soft = true },
	PottedTree = { name = "Topiary Tree", cat = "decor", price = 110, appeal = 3 },
	FloorLamp = { name = "Floor Lamp", cat = "decor", price = 70, appeal = 2, soft = true },
	Rug = { name = "Rug", cat = "decor", price = 50, appeal = 2, flat = true, soft = true },

	PingPongTable = { name = "Ping-Pong Table", cat = "fun", price = 400, appeal = 10 },
	VendingMachine = { name = "Vending Machine", cat = "fun", price = 350, appeal = 8 },

	Wall = { name = "Wall", cat = "structure", price = 40, appeal = 0, structure = true },
	Door = { name = "Door", cat = "structure", price = 90, appeal = 1, structure = true, doorway = true },
	Desk = { name = "Desk", cat = "furniture", price = 500, appeal = 6 },

	BedDeluxe = { name = "Deluxe Bed", cat = "rooms", price = 600, appeal = 12, coreKind = "Bed" },
	BedSuite = { name = "Suite Bed", cat = "rooms", price = 1200, appeal = 24, coreKind = "Bed" },
	ShowerRain = { name = "Rain Shower", cat = "rooms", price = 450, appeal = 9, coreKind = "Shower", soft = true },
	ToiletDeluxe = { name = "Deluxe Toilet", cat = "rooms", price = 300, appeal = 7, coreKind = "Toilet" },
}

Catalog.ORDER = {
	"Plant", "Rug", "FloorLamp", "PottedTree", "Nightstand", "CoffeeTable", "SideTable", "Armchair",
	"Bookshelf", "Wardrobe", "Sofa", "TVStand", "VendingMachine", "PingPongTable",
	"Wall", "Door", "Desk", "Bed", "Shower", "Toilet", "BedDeluxe", "BedSuite", "ShowerRain", "ToiletDeluxe",
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

function Catalog.price(id)
	local it = Catalog.ITEMS[id]
	return it and it.price or 0
end

function Catalog.sellValue(id)
	return math.floor(Catalog.price(id) * Catalog.SELL_BACK)
end

return Catalog
