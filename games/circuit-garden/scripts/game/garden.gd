class_name CGGarden
extends RefCounted
## Garden progression data: cosmetic plants, decorations, themes and milestones.
## Pure data and rules; persistence is a plain dictionary owned by CGGame.

const PLANTS := [
	{"id": "daisy", "name": "Volt Daisy", "cost": 10, "petals": 8, "color": "f2efe6", "height": 0.55},
	{"id": "tulip", "name": "Spark Tulip", "cost": 20, "petals": 3, "color": "e69f00", "height": 0.6},
	{"id": "bluebell", "name": "Ohm Bluebell", "cost": 30, "petals": 5, "color": "56b4e9", "height": 0.5},
	{"id": "sunflower", "name": "Solar Sunflower", "cost": 40, "petals": 14, "color": "f0e442", "height": 0.85},
	{"id": "orchid", "name": "Circuit Orchid", "cost": 55, "petals": 5, "color": "cc79a7", "height": 0.65},
	{"id": "fern", "name": "Fiber Fern", "cost": 70, "petals": 0, "color": "009e73", "height": 0.7},
	{"id": "poppy", "name": "Pulse Poppy", "cost": 100, "petals": 4, "color": "d55e00", "height": 0.6},
	{"id": "lily", "name": "Lumen Lily", "cost": 120, "petals": 6, "color": "ffffff", "height": 0.75},
	{"id": "cactus", "name": "Capacitor Cactus", "cost": 140, "petals": 0, "color": "7fd17f", "height": 0.5},
	{"id": "lotus", "name": "Logic Lotus", "cost": 190, "petals": 9, "color": "f7b6d2", "height": 0.45},
	{"id": "aster", "name": "Arc Aster", "cost": 250, "petals": 12, "color": "9b8cff", "height": 0.7},
	{"id": "willow", "name": "Wire Willow", "cost": 400, "petals": 0, "color": "a7d46f", "height": 0.95},
]
## Cosmetic pack plants: only from the optional "garden_pack" purchase.
const PACK_PLANTS := [
	{"id": "aurora", "name": "Aurora Bloom", "cost": 0, "petals": 10, "color": "6ef0d0", "height": 0.8, "pack": true},
	{"id": "ember", "name": "Ember Rose", "cost": 0, "petals": 7, "color": "ff7a59", "height": 0.65, "pack": true},
	{"id": "frost", "name": "Frost Bell", "cost": 0, "petals": 5, "color": "cfe8ff", "height": 0.6, "pack": true},
	{"id": "nova", "name": "Nova Star", "cost": 0, "petals": 5, "color": "ffd166", "height": 0.7, "pack": true},
]
const DECOR := [
	{"id": "stones", "name": "Path Stones", "cost": 85},
	{"id": "lantern", "name": "Firefly Lantern", "cost": 165},
	{"id": "pond", "name": "Little Pond", "cost": 220},
	{"id": "bench", "name": "Garden Bench", "cost": 350},
]
const THEMES := [
	{"id": "meadow", "name": "Sunny Meadow", "levels": 0, "sky": "1d3b4f", "ground": "2f5d3a"},
	{"id": "greenhouse", "name": "Glass Greenhouse", "levels": 25, "sky": "24413a", "ground": "3a5a40"},
	{"id": "moonlight", "name": "Moonlight Garden", "levels": 60, "sky": "141a33", "ground": "1f3a33"},
	{"id": "fireflies", "name": "Firefly Grove", "levels": 90, "sky": "0f2420", "ground": "203f2c"},
]
## Tuned with tests/test_garden_economy.gd: a reward (purchase, milestone or theme) at least
## every 10 levels for 1-, 2- and 3-star players; 2-star players finish the collection near
## level 90 and 3-star players near 80, so the Expert levels still pay off.
const MILESTONES := [
	{"levels": 5, "seeds": 15, "text": "First sprouts: +15 seeds"},
	{"levels": 10, "seeds": 25, "text": "Ten gardens powered: +25 seeds"},
	{"levels": 18, "seeds": 25, "text": "Green thumb: +25 seeds"},
	{"levels": 25, "seeds": 40, "text": "Greenhouse unlocked, +40 seeds"},
	{"levels": 33, "seeds": 35, "text": "Bridge builder: +35 seeds"},
	{"levels": 40, "seeds": 45, "text": "Forty gardens: +45 seeds"},
	{"levels": 50, "seeds": 60, "text": "Halfway bloom: +60 seeds"},
	{"levels": 60, "seeds": 60, "text": "Moonlight Garden unlocked, +60 seeds"},
	{"levels": 68, "seeds": 60, "text": "Deep roots: +60 seeds"},
	{"levels": 75, "seeds": 80, "text": "Expert gardener: +80 seeds"},
	{"levels": 83, "seeds": 80, "text": "Wildwood walker: +80 seeds"},
	{"levels": 90, "seeds": 100, "text": "Firefly Grove unlocked, +100 seeds"},
	{"levels": 100, "seeds": 150, "text": "Master Gardener: +150 seeds"},
]


static func all_plants() -> Array:
	return PLANTS + PACK_PLANTS


static func find(list: Array, id: String) -> Dictionary:
	for item in list:
		if item.id == id:
			return item
	return {}


static func themes_unlocked(levels_done: int) -> Array:
	return THEMES.filter(func(t): return levels_done >= t.levels).map(func(t): return t.id)


## Milestones newly reached when the completed count goes from `before` to `after`.
static func milestones_between(before: int, after: int) -> Array:
	return MILESTONES.filter(func(m): return before < m.levels and after >= m.levels)
