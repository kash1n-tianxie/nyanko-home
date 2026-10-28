extends RefCounted
## Authored RGBA frames sampled solely from the host's paused simulation age.
## This module never advances time, mutates game state, or creates combat events.
const Paint = preload("res://scripts/painted_vfx.gd")
const FRAME_COUNT: int = 6
const ROOT: String = "res://art/feedback-v032"
static var cache: Dictionary = {}

static func frame_index(age: float, duration: float, count: int = FRAME_COUNT) -> int:
	return clampi(floori(maxf(0.0,age)/maxf(.001,duration)*maxi(1,count)),0,maxi(0,count-1))

static func path(category: String, identity: String, frame: int) -> String:
	return "%s/%s/%s/frame-%02d.png" % [ROOT,category,identity,clampi(frame,0,FRAME_COUNT-1)]

static func texture(category: String, identity: String, frame: int) -> Texture2D:
	var asset: String = path(category,identity,frame)
	if cache.has(asset): return cache[asset]
	# Missing assets are not cached: an editor reimport may supply them later.
	if not ResourceLoader.exists(asset): return null
	var result: Texture2D = load(asset) as Texture2D
	if result!=null: cache[asset]=result
	return result

static func draw(canvas: Node2D, category: String, identity: String, age: float, duration: float, center: Vector2, size: Vector2, angle: float = 0.0, modulate: Color = Color.WHITE) -> bool:
	var tex: Texture2D = texture(category,identity,frame_index(age,duration))
	if tex==null: return false
	# A finished authored clip remains handled, rather than reviving its fallback.
	if age>=0.0 and age<duration:
		Paint.draw_texture(canvas,tex,center,size,angle,modulate)
	return true
