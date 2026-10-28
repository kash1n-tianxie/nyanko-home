extends RefCounted
## Painted payloads are composited around the actual weapon; no simulation or random calls.
const Paint = preload("res://scripts/painted_vfx.gd")
static var cache: Dictionary = {}

static func texture(key: String) -> Texture2D:
	if cache.has(key): return cache[key]
	var path: String = "res://art/parchment-v027/"+key+".png"
	if not ResourceLoader.exists(path): return null
	cache[key] = load(path) as Texture2D
	return cache[key]

static func sprite(canvas: Node2D, key: String, pos: Vector2, bounds: Vector2, angle: float = 0.0, alpha: float = 1.0) -> void:
	var tex: Texture2D = texture(key)
	if tex==null: return
	var dimensions: Vector2 = tex.get_size()
	var scale_value: float = minf(bounds.x/dimensions.x,bounds.y/dimensions.y)
	Paint.draw_texture(canvas,tex,pos,dimensions*scale_value,angle,Color(1,1,1,clampf(alpha,0,1)))

static func innate(canvas: Node2D, event: Dictionary, pos: Vector2, age: float, reduced: bool) -> void:
	# No giant mascot cutouts over enemies. Native traits use small contact marks.
	if age<0 or age>.22: return
	var cat: String=str(event.get("cat","C01"))
	if cat not in ["C02","C04","C05"]: return
	var progress: float=age/.22
	var bounds: Vector2=Vector2(50,24) if cat=="C04" else Vector2(37,25)
	var scale_value: float=1.0 if reduced else .82+progress*.25
	Paint.sprite(canvas,cat,3,pos+Vector2(0,10),bounds*scale_value,0,Color(1,1,1,(1-progress)*.58))
