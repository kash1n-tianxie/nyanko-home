extends RefCounted
## Non-destructive atlas crops of generated production artwork. Source PNGs retain alpha.
const CatSprites = preload("res://scripts/cat_sprite_art.gd")
const ENEMY_SHEET: Texture2D = preload("res://art/rebuild/enemies-source.png")
const BOSS_SHEET: Texture2D = preload("res://art/rebuild/bosses-source.png")
const ENEMY_REGIONS: Dictionary = {
	"E01":Rect2(17,171,290,270), "E02":Rect2(325,212,273,227),
	"E03":Rect2(605,212,321,232), "E04":Rect2(932,198,286,247),
	"E05":Rect2(1260,244,241,198), "E06":Rect2(5,536,301,313),
	"E07":Rect2(318,645,204,205)}
const BOSS_REGIONS: Dictionary = {
	"B01":Rect2(239,134,406,471), "B02":Rect2(862,212,451,383),
	"B03":Rect2(1558,134,452,481)}
static var _cache: Dictionary = {}

static func cat(id: String, pose: String = "idle") -> AtlasTexture:
	return CatSprites.texture(id,pose)

static func cat_pivot(id: String) -> Vector2:
	return CatSprites.pivot(id)

static func cat_muzzle(id: String, pose: String = "attack", height: float = 88.0) -> Vector2:
	return CatSprites.muzzle(id,pose,height)

static func enemy(id: String) -> AtlasTexture:
	var generated: String="res://art/expansion-v030/enemies/"+id+".png"
	if ResourceLoader.exists(generated):
		var source: Texture2D=load(generated) as Texture2D
		return _texture("expansion_"+id,source,Rect2(Vector2.ZERO,source.get_size()))
	if id=="B05":
		var machine: Texture2D=load("res://art/story-v026/boss.png") as Texture2D
		return _texture(id,machine,Rect2(Vector2.ZERO,machine.get_size()))
	if BOSS_REGIONS.has(id): return _texture(id,BOSS_SHEET,BOSS_REGIONS[id])
	return _texture(id,ENEMY_SHEET,ENEMY_REGIONS.get(id,ENEMY_REGIONS.E01))

static func _texture(id: String, sheet: Texture2D, region: Rect2) -> AtlasTexture:
	if not _cache.has(id):
		var cropped: AtlasTexture = AtlasTexture.new()
		cropped.atlas = sheet
		cropped.region = region
		cropped.filter_clip = true
		_cache[id] = cropped
	return _cache[id]
