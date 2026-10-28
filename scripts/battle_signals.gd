extends RefCounted
const GameLocale=preload("res://scripts/game_locale.gd")
## Enemy tactics use a single legible paper-sign language, above friendly coats.
const Paper=preload("res://scripts/collage_theme.gd")
const Art=preload("res://scripts/expansion_art.gd")
const BossStage=preload("res://scripts/boss_stage_rules.gd")
const INK: Color=Color("332931")
const DANGER: Color=Color("b9504d")
const GOLD: Color=Color("efc669")
static func draw(canvas: Node2D, battle: Dictionary, font: Font, clock: float, reduced: bool) -> void:
	for enemy: Dictionary in battle.get("enemies",[]):
		if bool(enemy.get("dead",false)): continue
		var point: Vector2=Vector2(float(enemy.x),float(enemy.get("feet_y",500)))
		var height: float=float(enemy.get("draw_height",60))
		if bool(enemy.get("counter_mark",false)):
			var mark: Vector2=Vector2(point.x,maxf(125,point.y-height-30))
			var bob: float=0.0 if reduced else sin(clock*5)*2
			var diamond: PackedVector2Array=PackedVector2Array([mark+Vector2(0,-15+bob),mark+Vector2(13,bob),mark+Vector2(0,15+bob),mark+Vector2(-13,bob)])
			canvas.draw_colored_polygon(diamond,Color("fff1ce"))
			canvas.draw_polyline(PackedVector2Array([diamond[0],diamond[1],diamond[2],diamond[3],diamond[0]]),DANGER,3,true)
			canvas.draw_line(mark+Vector2(0,-6+bob),mark+Vector2(0,3+bob),DANGER,3,true)
			canvas.draw_circle(mark+Vector2(0,8+bob),1.7,DANGER)
		var counter: Dictionary=enemy.get("counter_state",{})
		if counter.is_empty(): continue
		# The independent HUD owns y=84..132 for the boss health bar. Keep the
		# entire warning below that band even when the giant body fills the edge.
		var sign_position: Vector2=Vector2(clampf(point.x,470,1156),clampf(point.y-height-70,163,390))
		if bool(enemy.get("boss_fixed",false)): sign_position=Vector2(1070,169)
		canvas.draw_style_box(Paper.box("strip",Color("fff2cf"),0),Rect2(sign_position-Vector2(110,19),Vector2(220,47)))
		var label: String=str(counter.get("label","打断蓄力"))
		var label_size: int=18
		while label_size>14 and font.get_string_size(GameLocale.text(label),HORIZONTAL_ALIGNMENT_LEFT,-1,label_size).x>194: label_size-=1
		canvas.draw_string(font,sign_position+Vector2(-96,3),GameLocale.text(label),HORIZONTAL_ALIGNMENT_LEFT,194,label_size,INK)
		var ratio: float=clampf(float(counter.get("left",0))/maxf(.01,float(counter.get("total",1))),0,1)
		canvas.draw_line(sign_position+Vector2(-91,16),sign_position+Vector2(91,16),Color("bbaa91"),4,true)
		canvas.draw_line(sign_position+Vector2(-91,16),sign_position+Vector2(-91+182*ratio,16),DANGER,4,true)
		if str(counter.get("kind",""))=="damage":
			var progress: float=clampf(float(counter.get("damage",0))/maxf(1,float(counter.get("threshold",1))),0,1)
			var center: Vector2=BossStage.HIT if bool(enemy.get("boss_fixed",false)) else point-Vector2(0,height*.6)
			var radius: float=43.0 if bool(enemy.get("boss_fixed",false)) else height*.37
			canvas.draw_arc(center,radius,-PI*.5,-PI*.5+TAU*progress,40,GOLD,3,true)

static func event(canvas: Node2D, effect: Dictionary, font: Font, reduced: bool) -> void:
	var type: String=str(effect.get("type",""))
	if type not in ["boss_counter_success","boss_counter_failure","toy_combo"]: return
	var age: float=float(effect.get("age",0))
	var duration: float=maxf(.01,float(effect.get("duration",.85)))
	var t: float=clampf(age/duration,0,1)
	var fade: float=1.0-smoothstep(.65,1,t)
	var point: Vector2=Vector2(clampf(float(effect.get("x",900)),450,1160),clampf(float(effect.get("y",340))-65,150,430))
	var success: bool=type=="boss_counter_success"
	var label: String=str(effect.get("label","打断成功！")) if success else ("联动 · 猫砂吸星" if type=="toy_combo" else "号令生效")
	if type=="boss_counter_failure": label=str(effect.get("label","蓄力完成"))
	var ink: Color=Color("457d75") if success or type=="toy_combo" else DANGER
	canvas.draw_style_box(Paper.box("strip",Color(1,1,1,fade),0),Rect2(point-Vector2(85,16),Vector2(170,35)))
	canvas.draw_string(font,point+Vector2(-70,8),GameLocale.text(label),HORIZONTAL_ALIGNMENT_LEFT,146,20,Color(ink,fade))
	if success:
		# Break the interrupted skill's own painted emblem, rather than showing
		# a captain's flag for unrelated vacuum, summoning or television skills.
		var emblem: String={"B01":"enemy-rally","B02":"enemy-web","B03":"enemy-summon","B04":"enemy-tv","B05":"confusion"}.get(str(effect.get("kind","B01")),"enemy-rally")
		var flag: Texture2D=Art.picture("vfx",emblem)
		if flag==null: return
		var tex_size: Vector2=flag.get_size()
		for side: int in range(2):
			var direction: float=-1 if side==0 else 1
			var fall: Vector2=Vector2(direction*(12+t*(10 if reduced else 36)),32+t*20)
			canvas.draw_set_transform(point+fall,direction*t*(.12 if reduced else .7))
			canvas.draw_texture_rect_region(flag,Rect2(-16,-22,32,44),Rect2(Vector2(side*tex_size.x*.5,0),Vector2(tex_size.x*.5,tex_size.y)),Color(1,1,1,fade))
		canvas.draw_set_transform(Vector2.ZERO)
