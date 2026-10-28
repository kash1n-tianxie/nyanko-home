extends RefCounted
## New, illustrated death frames. Only presentation: no awards, hitboxes or timers.
const Art = preload("res://scripts/illustrated_atlas.gd")
const Expansion = preload("res://scripts/expansion_art.gd")
const Frames = preload("res://scripts/frame_art.gd")
static var _manifest: Dictionary = {}
const LIVE_HOLD: float = .028

static func duration(effect: Dictionary) -> float:
	if bool(effect.get("boss",false)) or str(effect.get("enemy_kind",effect.get("kind",""))).begins_with("B"): return 1.05
	return .50 if bool(effect.get("elite",false)) or str(effect.get("rank","")) in ["elite","large"] else .40

static func origin(effect: Dictionary) -> Vector2:
	return Vector2(float(effect.get("x",600)),float(effect.get("feet_y",500))+float(int(effect.get("target",0))%5-2)*2)

static func metadata(id: String) -> Dictionary:
	if _manifest.is_empty():
		var file: FileAccess = FileAccess.open("res://art/feedback-v032/deaths/manifest.json",FileAccess.READ)
		if file!=null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary: _manifest = parsed
	return _manifest.get("animations",{}).get(id,{})

static func geometry(effect: Dictionary) -> Dictionary:
	var id: String = str(effect.get("enemy_kind",effect.get("kind","E01")))
	var visual: Dictionary = effect.get("last_visual",{})
	var h: float = float(visual.get("height",effect.get("draw_height",64)))
	var foot: Vector2 = Vector2(visual.get("position",origin(effect)))
	var base_scale: Vector2 = Vector2(visual.get("scale",Vector2.ONE))
	var angle: float = float(visual.get("angle",0))
	var info: Dictionary = metadata(id)
	var pivot: Vector2 = Vector2(.5,float(info.get("pivot_y",.875)))
	var tex: Texture2D = Art.enemy(id)
	var live_width: float = h*tex.get_width()/float(tex.get_height())
	var extent: float = minf(h/maxf(.12,float(info.get("first_height_ratio",.68))),live_width/maxf(.12,float(info.get("first_width_ratio",.68))))
	var size: Vector2 = Vector2.ONE*extent*base_scale
	var center: Vector2 = foot+((Vector2(.5,.5)-pivot)*size).rotated(angle)
	return {"id":id,"foot":foot,"height":h,"angle":angle,"scale":base_scale,"size":size,"center":center,"pivot":pivot}

static func draw(canvas: Node2D, effect: Dictionary, age: float, _reduced: bool) -> void:
	var life: float = duration(effect)
	if age<0 or age>=life: return
	var g: Dictionary = geometry(effect)
	var alpha: float = 1.0-smoothstep(life-.075,life,age)
	# Retain the exact last living pose for the first render; no cut-up sprite fragments.
	if age<LIVE_HOLD:
		_draw_living(canvas,g,alpha)
	else:
		var played: bool = Frames.draw(canvas,"deaths",g.id,age-LIVE_HOLD,life-LIVE_HOLD,g.center,g.size,g.angle,Color(1,1,1,alpha))
		if not played: _draw_living(canvas,g,alpha)
	# A small source badge remains independent of the animated artwork.
	if life>=.5 and age<.66:
		var source_toy: String = str(effect.get("source_toy",""))
		var killer: String = str(effect.get("killer_cat",""))
		var badge: Texture2D = Expansion.picture("toys",source_toy) if source_toy!="" else (Art.cat(killer) if killer.begins_with("C") else null)
		if badge!=null:
			var point: Vector2 = g.foot+Vector2(-float(g.height)*.38,-float(g.height)*.72)
			canvas.draw_circle(point,20,Color(.19,.16,.18,alpha*.85))
			Expansion.fit(canvas,badge,Rect2(point-Vector2(18,18),Vector2(36,36)),Color(1,1,1,alpha))

static func _draw_living(canvas: Node2D, g: Dictionary, alpha: float) -> void:
	var tex: Texture2D = Art.enemy(g.id)
	var h: float = float(g.height)
	var w: float = h*tex.get_width()/float(tex.get_height())
	canvas.draw_set_transform(g.foot,g.angle,g.scale)
	canvas.draw_texture_rect(tex,Rect2(-w*.5,-h,w,h),false,Color(1,1,1,alpha))
	canvas.draw_set_transform(Vector2.ZERO)
