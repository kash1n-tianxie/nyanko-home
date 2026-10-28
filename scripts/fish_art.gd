extends RefCounted
## Generated family; atlas regions preserve original RGBA and per-kind silhouettes.
const SHEET: Texture2D = preload("res://art/rebuild/fish.png")
const REGIONS: Dictionary = {
	"F01": Rect2(27,193,416,231),
	"F02": Rect2(473,137,351,283),
	"F03": Rect2(897,139,303,290),
	"F04": Rect2(1275,182,357,239),
	"F05": Rect2(27,561,381,245),
	"F06": Rect2(441,594,420,205),
	"F07": Rect2(898,559,336,250),
	"F08": Rect2(1274,563,368,233)
}
static var cache: Dictionary = {}

static func texture(kind: String) -> Texture2D:
	if kind in ["F09","F10"]:
		var path: String="res://art/expansion-v030/fish/"+kind+".png"
		if ResourceLoader.exists(path):
			if not cache.has(kind): cache[kind]=load(path) as Texture2D
			return cache[kind]
	var key: String = kind if REGIONS.has(kind) else "F01"
	if not cache.has(key):
		var icon: AtlasTexture = AtlasTexture.new()
		icon.atlas = SHEET
		icon.region = REGIONS[key]
		icon.filter_clip = true
		cache[key] = icon
	return cache[key] as Texture2D
