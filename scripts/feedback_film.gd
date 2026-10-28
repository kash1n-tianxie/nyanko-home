extends Control
const GameLocale=preload("res://scripts/game_locale.gd")
## Before/after are resolved snapshots. Middle is an explicitly labelled event diagram.
## This is a causal receipt, not three consecutive video frames or a combat replay.
const Art = preload("res://scripts/illustrated_atlas.gd")
const Paint = preload("res://scripts/painted_vfx.gd")
const Source = preload("res://scripts/feedback_receipt.gd")
const FontTheme = preload("res://theme/main.tres")
const INK: Color = Color("493a34")
var frame: Dictionary = {}
var highlight: Dictionary = {}
var frame_index: int = 0
var crop: Rect2 = Rect2(500,250,520,300)

static func evidence(item: Dictionary) -> Dictionary:
	var frames: Array = item.get("frames",[])
	var before: Dictionary = frames[0] if not frames.is_empty() else {}
	var after: Dictionary = frames[2] if frames.size()>2 else {}
	var first: Dictionary = {}
	var last: Dictionary = {}
	var alive_before: int = 0
	var alive_after: int = 0
	for enemy: Dictionary in before.get("enemies",[]):
		first[int(enemy.id)] = enemy
		if not bool(enemy.get("dead",false)) and float(enemy.get("hp",0))>0: alive_before+=1
	for enemy: Dictionary in after.get("enemies",[]):
		last[int(enemy.id)] = enemy
		if not bool(enemy.get("dead",false)) and float(enemy.get("hp",0))>0: alive_after+=1
	var changed: Array[int] = []
	var health_before: float = 0.0
	var health_after: float = 0.0
	for id: int in first:
		# Disappearance is not silently converted to a fabricated zero-HP target.
		if not last.has(id): continue
		if absf(float(first[id].hp)-float(last[id].hp))>.001:
			changed.append(id)
			health_before+=maxf(0,float(first[id].hp))
			health_after+=maxf(0,float(last[id].hp))
	return {"alive_before":alive_before,"alive_after":alive_after,"changed":changed,"health_before":health_before,"health_after":health_after,"before":first,"after":last,"source_damage":float(item.get("damage",0)),"target_count":int(item.get("target_count",0)),"source":str(item.get("source",""))}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var proof: Dictionary = evidence(highlight)
	var center: Vector2 = highlight.get("position",Vector2(800,430))
	var min_x: float = 2000.0
	var max_x: float = 0.0
	for id: int in proof.changed:
		min_x=minf(min_x,float(proof.before[id].x))
		max_x=maxf(max_x,float(proof.after[id].x))
	if not proof.changed.is_empty(): center.x=(min_x+max_x)*.5
	var width: float = clampf(max_x-min_x+180,400,960) if not proof.changed.is_empty() else 520.0
	crop=Rect2(Vector2(clampf(center.x-width*.5,280,1280-width),240),Vector2(width,300))

func point(logical: Vector2) -> Vector2:
	return Vector2(8,21)+(logical-crop.position)/crop.size*Vector2(size.x-16,size.y-65)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("d9c6a3"))
	for i: int in range(7): draw_line(Vector2(i*54,0),Vector2(i*54-30,size.y),Color("cdb990"),1,true)
	var proof: Dictionary = evidence(highlight)
	var ground: float = point(Vector2(800,500)).y
	draw_line(Vector2(4,ground),Vector2(size.x-4,ground),Color("9c8160"),2,true)
	for enemy: Dictionary in frame.get("enemies",[]):
		var enemy_position: Vector2 = Vector2(float(enemy.x),float(enemy.get("feet_y",500)))
		if enemy_position.x<crop.position.x-50 or enemy_position.x>crop.end.x+50: continue
		var p: Vector2 = point(enemy_position)
		var height: float = clampf(float(enemy.get("draw_height",60))*(size.y-65)/crop.size.y,23,75)
		var texture: Texture2D = Art.enemy(str(enemy.kind))
		var width: float = height*texture.get_width()/maxf(1,texture.get_height())
		var tint: Color = Color("ffffff66") if bool(enemy.get("dead",false)) or float(enemy.get("hp",0))<=0 else Color.WHITE
		draw_texture_rect(texture,Rect2(p-Vector2(width*.5,height),Vector2(width,height)),false,tint)
		var ratio: float = clampf(float(enemy.hp)/maxf(.01,float(enemy.max_hp)),0,1)
		draw_line(p-Vector2(15,height+3),p+Vector2(15,-height-3),Color("675542"),3,true)
		draw_line(p-Vector2(15,height+3),p-Vector2(15-30*ratio,height+3),Color("a75547"),3,true)
		if int(enemy.id) in proof.changed and frame_index!=1:
			var text: String = "%.0f" % maxf(0,float(enemy.hp))
			draw_string(FontTheme.default_font,p+Vector2(-14,-height-8),GameLocale.text(text),HORIZONTAL_ALIGNMENT_LEFT,52,12,INK)
	if frame_index==1:
		_draw_event_diagram(proof)
	else:
		for projectile: Dictionary in frame.get("projectiles",[]):
			var p: Vector2 = point(Vector2(projectile.x,projectile.y))
			var texture: Texture2D = Paint.texture(str(projectile.get("cat","C01")),0)
			if texture!=null: draw_texture_rect(texture,Rect2(p-Vector2(10,6),Vector2(20,12)),false)
	# A source strip owns its own area, never sits across an enemy face.
	draw_rect(Rect2(0,0,size.x,22),Color("eadcbe"))
	var title: String = Source.source_name(str(proof.source))
	if frame_index==1: title+=" · 发动示意"
	else: title+=" · %.2fs" % float(frame.get("time",0))
	draw_string(FontTheme.default_font,Vector2(7,16),GameLocale.text(title),HORIZONTAL_ALIGNMENT_LEFT,size.x-14,14,INK)
	draw_rect(Rect2(0,size.y-40,size.x,40),Color("eadcb9"))
	var first_line: String
	var second_line: String
	if frame_index==0:
		first_line="存活敌人 %d 只" % int(proof.alive_before)
		second_line="受伤目标合计血量 %.0f" % float(proof.health_before) if not proof.changed.is_empty() else "猫爬架耐久 %.0f" % float(frame.get("hp",0))
	elif frame_index==1:
		first_line="作用 %d 个目标" % int(proof.target_count)
		second_line="效果示意 · 看清这次联动"
	else:
		first_line="存活敌人 %d → %d" % [int(proof.alive_before),int(proof.alive_after)]
		if float(proof.source_damage)>0:
			if proof.changed.is_empty(): second_line="来源伤害 %.0f · %d目标" % [float(proof.source_damage),int(proof.target_count)]
			else: second_line="来源伤害 %.0f · 血量 %.0f→%.0f" % [float(proof.source_damage),float(proof.health_before),float(proof.health_after)]
		elif not proof.changed.is_empty(): second_line="受伤目标血量 %.0f → %.0f" % [float(proof.health_before),float(proof.health_after)]
		else: second_line="耐久 %.0f · %d目标生效" % [float(frame.get("hp",0)),int(proof.target_count)]
	draw_string(FontTheme.default_font,Vector2(7,size.y-23),GameLocale.text(first_line),HORIZONTAL_ALIGNMENT_LEFT,size.x-14,14,INK)
	var font_size: int = 13
	while font_size>10 and FontTheme.default_font.get_string_size(GameLocale.text(second_line),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>size.x-14: font_size-=1
	draw_string(FontTheme.default_font,Vector2(7,size.y-6),GameLocale.text(second_line),HORIZONTAL_ALIGNMENT_LEFT,size.x-14,font_size,INK)

func _draw_event_diagram(proof: Dictionary) -> void:
	var source: String = str(proof.source).split(":")[0]
	var texture: Texture2D = null
	if source.begins_with("C"): texture=Art.cat(source)
	elif source.begins_with("T"): texture=preload("res://scripts/expansion_art.gd").picture("toys",source)
	elif source.begins_with("F"): texture=preload("res://scripts/fish_art.gd").texture(source)
	var from: Vector2 = Vector2(34,57)
	if texture!=null:
		var extent: Vector2 = source_icon_size(texture)
		draw_texture_rect(texture,Rect2(from-extent*.5,extent),false)
	var target: Vector2 = Vector2(size.x*.64,75)
	if not proof.changed.is_empty():
		var id: int = int(proof.changed[0])
		target=point(Vector2(float(proof.before[id].x),float(proof.before[id].get("y",460))))
		target.x=clampf(target.x,84,size.x-22)
		target.y=clampf(target.y,42,size.y-49)
	var direction: Vector2 = (target-from).normalized()
	draw_line(from+direction*28,target,Color("95664b"),2.5,true)
	draw_line(target,target-direction.rotated(.55)*10,Color("95664b"),2.5,true)
	draw_line(target,target-direction.rotated(-.55)*10,Color("95664b"),2.5,true)
	draw_arc(target,16,0,TAU,18,Color("ae7151"),2,true)

static func source_icon_size(texture: Texture2D) -> Vector2:
	if texture==null: return Vector2.ZERO
	var factor: float = minf(48.0/texture.get_width(),45.0/texture.get_height())
	return texture.get_size()*factor
