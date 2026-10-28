extends RefCounted
## Shared runtime art lookup for collection, rewards, route and real combat events.
const ROOT: String="res://art/expansion-v030/"
static var cache: Dictionary={}
static func picture(group: String, id: String) -> Texture2D:
	var key: String=group+"/"+id
	if cache.has(key): return cache[key]
	var path: String=ROOT+key+".png"
	if ResourceLoader.exists(path):
		cache[key]=load(path) as Texture2D
		return cache[key]
	return null

static func fit(canvas: CanvasItem, tex: Texture2D, rect: Rect2, tint: Color=Color.WHITE) -> void:
	if tex==null: return
	var extent: Vector2=tex.get_size()
	var factor: float=minf(rect.size.x/extent.x,rect.size.y/extent.y)
	var dimensions: Vector2=extent*factor
	canvas.draw_texture_rect(tex,Rect2(rect.get_center()-dimensions*.5,dimensions),false,tint)
