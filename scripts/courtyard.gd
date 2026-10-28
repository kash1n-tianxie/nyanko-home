extends Node2D
const GameLocale=preload("res://scripts/game_locale.gd")
## Presentation only: deterministic shapes never touch the combat random streams.
const Data = preload("res://scripts/catalog.gd")
const Art = preload("res://scripts/illustrated_atlas.gd")
const CatPerformance = preload("res://scripts/cat_performance.gd")
const Mutations = preload("res://scripts/cat_mutations.gd")
const WeaponVFX = preload("res://scripts/weapon_vfx.gd")
const FishVFX = preload("res://scripts/fish_vfx.gd")
const Painted = preload("res://scripts/painted_vfx.gd")
const EnemyVFX = preload("res://scripts/enemy_vfx.gd")
const Scenery = preload("res://scripts/story_scenery.gd")
const MAX_POPS: int = 96
const Feedback = preload("res://scripts/feedback_budget.gd")
const BuildArt = preload("res://scripts/build_art.gd")
const ExpansionVFX=preload("res://scripts/expansion_vfx.gd")
const ExpansionArt=preload("res://scripts/expansion_art.gd")
const CatStats=preload("res://scripts/cat_stat_chip.gd")
const Positions=preload("res://scripts/cat_combat_positions.gd")
const Defeat=preload("res://scripts/defeat_feedback.gd")
const Identity=preload("res://scripts/feedback_identity.gd")
const BaseFeedback=preload("res://scripts/base_feedback.gd")
const HitMotion=preload("res://scripts/hit_motion.gd")
const DamageNumbers=preload("res://scripts/damage_numbers.gd")
const Mounts=preload("res://scripts/toy_mounts.gd")
const ReadabilityShader=preload("res://shaders/battle_readability.gdshader")
const Signals=preload("res://scripts/battle_signals.gd")
const LivingStage=preload("res://scripts/living_stage.gd")
const BossPresentation=preload("res://scripts/boss_presentation.gd")
const StageArtDirection=preload("res://scripts/stage_art_direction.gd")
const SkillPresentation=preload("res://scripts/skill_presentation.gd")
var skills_view=SkillPresentation.new()
var stage_life=LivingStage.new()
var boss_view=BossPresentation.new()
var scenery_plate: Sprite2D
var scenery_stage: int=-1
var identity_feedback=Identity.new()
var enemy_visuals: Dictionary={}
var feedback_cache: Dictionary=Feedback.live_cache()
var profile_draw: bool=false
var profile_draw_ms: float=0.0
var live_stats: Dictionary={}
const Paper = preload("res://scripts/collage_theme.gd")
const PLATE: Texture2D = preload("res://art/rebuild/courtyard_plate.png")
const INK: Color = Color("393349")
const CREAM: Color = Color("fff7e8")
var state: Dictionary = {}
var clock: float = 0.0
var reduced: bool = false
var aim_height: float = 452.0
var pops: Array = []
var reactions: Dictionary = {}
var last_primary_x: Dictionary = {}
var max_visible_pops: int = 0
var font: Font = preload("res://theme/main.tres").default_font
const PERCHES: Array[Vector2] = [Vector2(130,350),Vector2(210,245),Vector2(115,160),Vector2(215,410),Vector2(120,310)]
# Feet on the painted platform tops. Presentation coordinates do not affect combat.
const VISUAL_FEET: Array[Vector2] = Positions.FEET
const CAT_HEIGHT: float = 88.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	scenery_plate=Sprite2D.new()
	scenery_plate.name="PaintedDistance"
	scenery_plate.centered=false
	scenery_plate.z_index=-1
	var grade: ShaderMaterial=ShaderMaterial.new()
	grade.shader=ReadabilityShader
	scenery_plate.material=grade
	add_child(scenery_plate)
	_update_scenery(0)

func _update_scenery(stage: int) -> void:
	if scenery_plate==null or scenery_stage==stage: return
	scenery_stage=stage
	scenery_plate.texture=Scenery.texture(Scenery.path_for_stage(stage))
	if scenery_plate.texture!=null:
		scenery_plate.scale=Vector2(1280,548)/scenery_plate.texture.get_size()
		StageArtDirection.configure_material(scenery_plate.material as ShaderMaterial,stage)


func tick(delta: float, current: Dictionary) -> void:
	state = current
	var cinematic: bool=bool(current.get("battle",{}).get("cinematic",{}).get("active",false))
	skills_view.tick(delta,current)
	var ambient: Dictionary=current.duplicate(false) if cinematic else current
	if cinematic: ambient.paused=true
	stage_life.configure(ambient,reduced)
	stage_life.tick(delta)
	boss_view.configure(ambient,reduced)
	if cinematic and not bool(current.get("paused",false)):
		# Boss charge/ordinary motions freeze; genuine impact/departure can finish.
		for reaction: Dictionary in boss_view.reactions.values():
			for key: String in ["hit","stagger"]: reaction[key]=maxf(0,float(reaction.get(key,0))-delta)
		for wreck: Dictionary in boss_view.remains: wreck.age=float(wreck.age)+delta
	else: boss_view.tick(delta)
	_update_scenery(int(state.get("stage",0)))
	if scenery_plate!=null:
		StageArtDirection.configure_material(scenery_plate.material as ShaderMaterial,int(state.get("stage",0)),stage_life.grade_state())
	if state.is_empty() or state.get("phase","") not in ["combat","cleanup"]:
		reactions.clear()
		pops.clear()
		last_primary_x.clear()
	if not bool(state.get("paused",false)):
		delta*=1.0 if cinematic else clampf(float(state.get("combat_speed",1.0)),1.0,2.0)
		if not cinematic: clock += delta
		for effect: Dictionary in pops:
			if not cinematic or effect.get("type","") in ["hit","death","stun","cat_cleanse","shield","critical"]: effect.age += delta
		pops = pops.filter(func(effect: Dictionary) -> bool: return float(effect.age)<maxf(.9,float(effect.get("duration",0))))
		Feedback.reindex(pops,feedback_cache)
		for id: String in reactions.keys():
			if not cinematic or id.begins_with("hit"): reactions[id] = maxf(0,float(reactions[id])-delta)
	queue_redraw()

func event(event_data: Dictionary) -> void:
	skills_view.event(event_data)
	stage_life.event(event_data)
	boss_view.event(event_data)
	var type: String = str(event_data.get("type",""))
	if type=="stage_start":
		identity_feedback.reset()
		enemy_visuals.clear()
		feedback_cache=Feedback.live_cache()
		reactions.clear()
		pops.clear()
		last_primary_x.clear()
		return
	if type=="attack": reactions[str(event_data.get("cat",""))] = CatPerformance.duration(str(event_data.get("cat","")))
	if type=="base_hit":
		reactions["enemy%d" % int(event_data.get("target",0))] = .28
	if type=="base_damage_resolved" and float(event_data.get("hp_damage",0))>0:
		reactions["base"] = .28
	if type=="hit" and float(event_data.get("amount",0))>0:
		var hit_key: String = "hit%d" % int(event_data.get("target",0))
		# Let one squash reach its rebound even during a dense multi-projectile volley.
		if float(reactions.get(hit_key,0)) <= HitMotion.DURATION-HitMotion.RETRIGGER_AFTER:
			reactions[hit_key] = HitMotion.DURATION
	if type in ["boss_counter_warning","boss_counter_success","boss_counter_failure","toy_combo"]:
		if type=="toy_combo":
			if bool(event_data.get("replaces_pending",false)):
				pops=pops.filter(func(effect:Dictionary)->bool:return not (effect.get("type","")=="toy_cast" and effect.get("kind","")=="meteor" and float(effect.get("age",0))<float(effect.get("duration",0))))
				Feedback.reindex(pops,feedback_cache)
			var flight: Dictionary=event_data.duplicate()
			flight.type="toy_cast";flight.kind="meteor";flight.age=0.0
			flight.to_x=event_data.get("x",900);flight.to_y=event_data.get("y",450)
			Feedback.append(pops,flight,feedback_cache)
		var signal_effect: Dictionary=event_data.duplicate()
		signal_effect.age=0.0
		signal_effect.duration=maxf(.85,float(signal_effect.get("duration",0)))
		Feedback.append(pops,signal_effect,feedback_cache)
	if type in ["hit","base_hit","shield","chain","burst","death","freeze","critical","vfx_status","shield_absorb","block","safeguard","enemy_special","innate","stun","cat_buff","bell_return","toy_cast","enemy_debuff_cast","cat_debuff","cat_cleanse","toy_heal","toy_charge","toy_armed","enemy_skill","enemy_skill_warning","base_damage_resolved","base_shield_broken","base_low_hp"]:
		var effect: Dictionary = event_data.duplicate()
		if type=="hit": effect.origin = _origin(str(effect.get("cat","C01")))
		if type=="death":
			effect.duration=Defeat.duration(effect)
			effect.last_visual=enemy_visuals.get(int(effect.get("target",0)),{}).duplicate()
		effect.age = 0.0
		DamageNumbers.prepare(effect,pops,font,reduced)
		Feedback.append(pops,effect,feedback_cache)
	var identity_notice: Dictionary=identity_feedback.notice(event_data,clock)
	if not identity_notice.is_empty():
		identity_notice["mount"]=Mounts.anchor(str(identity_notice.get("identity","")),state.get("toys",{}).keys())
		Feedback.append(pops,identity_notice,feedback_cache)
	max_visible_pops = maxi(max_visible_pops,pops.size())

func cat_position(index: int) -> Vector2:
	return VISUAL_FEET[clampi(index,0,4)]+Vector2(0,-CAT_HEIGHT*.5)

func cat_at(point: Vector2) -> String:
	var active: Array = state.get("active",["C01","C02"])
	for i: int in range(mini(active.size(),5)):
		var id: String = str(active[i])
		var pose: Dictionary = CatPerformance.sample(id,_action_age(id),reduced)
		pose=skills_view.rage_pose(id,SkillPresentation.cat_state(state,id),pose,CAT_HEIGHT)
		var moving_center: Vector2 = VISUAL_FEET[i]+(Vector2(0,-CAT_HEIGHT*.5)*Vector2(pose.scale)).rotated(float(pose.rotation))+Vector2(pose.offset)
		if point.distance_to(cat_position(i))<43 or point.distance_to(moving_center)<43: return id
	# Body centers win before wider weapons, so adjacent perches remain selectable.
	for i: int in range(mini(active.size(),5)):
		var id: String = str(active[i])
		var pose: Dictionary = CatPerformance.sample(id,_action_age(id),reduced)
		pose=skills_view.rage_pose(id,SkillPresentation.cat_state(state,id),pose,CAT_HEIGHT)
		var tex: Texture2D = pose.get("texture",Art.cat(id,str(pose.pose)))
		var width: float = CAT_HEIGHT*tex.get_width()/float(tex.get_height())
		var local: Vector2 = (point-VISUAL_FEET[i]-Vector2(pose.offset)).rotated(-float(pose.rotation))/Vector2(pose.scale)
		var sprite_size: Vector2 = Vector2(width,CAT_HEIGHT)
		var rect: Rect2=pose.get("sprite_rect",Rect2(-sprite_size*Art.cat_pivot(id),sprite_size))
		if rect.has_point(local): return id
	return ""

func _origin(cat: String) -> Vector2:
	var slot: int = state.get("active",[]).find(cat)
	if cat=="C01" and float(SkillPresentation.cat_state(state,cat).get("skill_rage_left",0))>0:
		return Positions.FEET[clampi(slot,0,4)]+Positions.RAGE_RELEASE_OFFSET
	return Positions.origin(clampi(slot,0,4),cat)

func _action_age(id: String) -> float:
	var left: float = float(reactions.get(id,0))
	return CatPerformance.duration(id)-left if left>0 else -1.0

func _draw() -> void:
	var start: int=Time.get_ticks_usec() if profile_draw else 0
	_render_court()
	if profile_draw: profile_draw_ms=(Time.get_ticks_usec()-start)/1000.0

func _render_court() -> void:
	var stage: int = int(state.get("stage",0))
	if scenery_plate==null or scenery_plate.texture==null:
		Scenery.draw_background(self,stage,PLATE)
	stage_life.draw_back(self)
	var battle: Dictionary = state.get("battle",{})
	boss_view.draw_back(self,battle)
	stage_life.draw_tree(self)
	_draw_tree()
	var active: Array = state.get("active",["C01","C02"])
	for i: int in range(mini(active.size(),5)):
		if not (bool(battle.get("cinematic",{}).get("active",false)) and battle.cinematic.cat==active[i]): _draw_cat(str(active[i]),VISUAL_FEET[i],1.0)
	# Ground impacts sit behind silhouettes; narrow chains remain above them.
	for effect: Dictionary in pops:
		if effect.get("type","") in ["burst","innate"]: _draw_pop(effect)
	for enemy: Dictionary in battle.get("enemies",[]):
		if not bool(enemy.get("dead",false)): _draw_enemy(enemy)
	var shown_attacks: Dictionary={}
	for projectile: Dictionary in battle.get("projectiles",[]):
		var attack: int=int(projectile.get("attack",-1))
		var prominent: bool=not shown_attacks.has(attack)
		if float(projectile.get("age",0))>=float(projectile.get("delay",0)): shown_attacks[attack]=true
		_draw_projectile(projectile,prominent)
	boss_view.draw_flights(self,battle)
	# Saved hostile flights stay legible above the friendly projectile stream.
	ExpansionVFX.debuff_flights(self,battle,reduced)
	Signals.draw(self,battle,font,clock,reduced)
	for effect: Dictionary in pops:
		if effect.get("type","") not in ["burst","innate"]: _draw_pop(effect)
	stage_life.draw_front(self)
	skills_view.draw(self,state,reduced)
	# Text is the final combat layer: later explosions cannot paint over hit values.
	for effect: Dictionary in pops:
		DamageNumbers.draw(self,effect,float(effect.get("age",0)),reduced,font)
	if state.get("attack_mode","auto")=="manual" and state.get("phase","") in ["combat","cleanup"]:
		_draw_aim()
	if not state.is_empty() and float(state.get("hp",300))<float(state.get("max_hp",300))*.15:
		# Persistent danger belongs to the damaged tree, never a screen-wide red veil.
		draw_polyline(PackedVector2Array([Vector2(307,448),Vector2(317,434),Vector2(327,448),Vector2(307,448)]),Color("efb280"),2,true)
		draw_line(Vector2(317,440),Vector2(317,444),Color("efb280"),2,true)
	if state.get("phase","")=="failed":
		draw_style_box(Paper.box("strip",Color.WHITE,0),Rect2(389,474,510,42))
		draw_string(font,Vector2(415,502),GameLocale.text("猫咪撤回据点，月亮还在滚筒里。"),HORIZONTAL_ALIGNMENT_LEFT,-1,22,INK)

func _draw_aim() -> void:
	var center: Vector2 = Vector2(float(state.get("aim_x",760)),aim_height)
	var scale_value: float = 1.0 if reduced else 1.0+sin(clock*4)*.035
	var radius: float = 22*scale_value
	# A compact targeting control, visually distinct from the painted combat effects.
	draw_arc(center,radius,0,TAU,40,Color("fff9dc"),5,true)
	draw_arc(center,radius,0,TAU,40,Color("705355"),2,true)
	for axis: Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		draw_line(center+axis*(radius-7),center+axis*(radius+8),Color("fff9dc"),6,true)
		draw_line(center+axis*(radius-7),center+axis*(radius+8),Color("be604d"),3,true)
	draw_circle(center,3,Color("be604d"))

func _draw_garden_lights(period: int) -> void:
	var cable: PackedVector2Array = []
	for i: int in range(25):
		var ratio: float = i/24.0
		cable.append(Vector2(398+ratio*748,129+sin(ratio*PI)*21))
	draw_polyline(cable,Color("746775"),1.4,true)
	for i: int in range(8):
		var ratio: float = (i+.5)/8.0
		var light: Vector2 = Vector2(398+ratio*748,137+sin(ratio*PI)*21)
		draw_line(light-Vector2(0,8),light-Vector2(0,2),Color("746775"),1.5,true)
		if period==2:
			draw_circle(light,15,Color(1,.76,.38,.055))
			draw_circle(light,10,Color(1,.8,.42,.12))
			draw_circle(light,5,Color("ffe8a3"))
			draw_circle(light-Vector2(1,1),2,Color("fff8db"))
		else:
			draw_circle(light,4,Color("f0ddbb"))
			draw_arc(light,4,0,TAU,12,Color("a99380"),.8,true)


func _draw_tree() -> void:
	Mutations.draw_tree(self,state,clock,reduced)
	ExpansionVFX.base_status(self,state.get("battle",{}))
	# Preserve the hand-painted cat tree in PLATE; overlay only live shield/impact feedback.
	var shield: float = 0.0
	for packet: Dictionary in state.get("battle",{}).get("shields",[]): shield += float(packet.get("amount",0))
	if shield>0:
		Painted.sprite(self,"F08",1,Vector2(364,359),Vector2(82,191),0,Color(1,1,1,.23))
		if int(state.get("toys",{}).get("T14",0))>0: ExpansionVFX.base_shield(self,state.get("battle",{}),clock,reduced)
	# Collected toys hang from the actual cat tree, with the full collection in its drawer.
	var held: Array=state.get("toys",{}).keys()
	for i: int in range(mini(4,held.size())):
		var anchor: Vector2=Mounts.anchor(str(held[i]),held)
		draw_line(anchor-Vector2(0,26),anchor-Vector2(0,10),Color("d8c9a6"),1.4,true)
		var performing: bool=pops.any(func(effect:Dictionary)->bool:return effect.get("type","")=="mechanism_identity" and str(effect.get("identity",""))==str(held[i]))
		if not performing:
			ExpansionArt.fit(self,ExpansionArt.picture("toys",str(held[i])),Rect2(anchor-Vector2(14.5,14.5),Vector2(29,29)))
	if held.size()>4:
		var box: Rect2=Rect2(Mounts.BOX-Vector2(23,17),Vector2(46,34))
		draw_style_box(Paper.box("slot",Color("e1c89d"),0),box)
		draw_string(font,Mounts.BOX+Vector2(-15,6),GameLocale.text("+%d" % (held.size()-4)),HORIZONTAL_ALIGNMENT_LEFT,34,18,INK)

func _draw_cat(id: String, p: Vector2, size_scale: float) -> void:
	var age: float = _action_age(id)
	var pose: Dictionary = CatPerformance.sample(id,age,reduced)
	var cat_snapshot: Dictionary=SkillPresentation.cat_state(state,id)
	pose=skills_view.rage_pose(id,cat_snapshot,pose,CAT_HEIGHT*size_scale)
	pose=skills_view.meal_pose(id,pose,reduced)
	var breathe: float = 0.0 if reduced or age>=0 else sin(clock*2.5+int(id.substr(1)))*.012
	pose.scale = Vector2(pose.scale)*Vector2(1-breathe,1+breathe)
	skills_view.draw_cat_back(self,id,cat_snapshot,p,pose,CAT_HEIGHT*size_scale,reduced)
	Mutations.draw(self,state,id,p,CAT_HEIGHT*size_scale,pose,clock,reduced)
	if age>=0: _draw_weapon_motion(id,p,age)
	for snapshot: Dictionary in state.get("battle",{}).get("cats",[]):
		if snapshot.id==id:
			FishVFX.draw_cat_aura(self,snapshot,p+Vector2(0,-13),clock,reduced)
			ExpansionVFX.cat_status(self,snapshot,p,clock,reduced)
			var buff_left: float = float(snapshot.get("buff_left",0))
			if buff_left>0:
				Painted.sprite(self,"C06",0,p+Vector2(28,-72),Vector2(18,18),0,Color("ffe5a0"))
				draw_arc(p+Vector2(28,-72),11,-PI*.5,-PI*.5+TAU*minf(1,buff_left/3),20,Color("ffe39a"),1.8,true)
			break
	skills_view.draw_cat_front(self,id,cat_snapshot,p,font,reduced)
	# Small identity chips stay attached to the painted platforms.
	var caption: String = str(Data.cats().get(id,Data.cats()["C01"]).name)
	draw_style_box(Paper.box("slot",Color.WHITE,0),Rect2(p.x-28,p.y+3,56,24))
	var caption_width: float=font.get_string_size(GameLocale.text(caption),HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
	draw_string(font,p+Vector2(-caption_width*.5,21),GameLocale.text(caption),HORIZONTAL_ALIGNMENT_LEFT,52,14,INK)
	var numbers: Dictionary=live_stats.get(id,{"attack":Data.cats()[id].attack,"rate":1.0/float(Data.cats()[id].interval)})
	var compact_window: bool=get_window().size.x<1120
	CatStats.draw_pair(self,p+Vector2(-72 if compact_window else -65,28),144 if compact_window else 130,float(numbers.attack),float(numbers.rate),font,19 if compact_window else 15)

func _draw_weapon_motion(id: String, feet: Vector2, age: float) -> void:
	if age<CatPerformance.RELEASE: return
	if id=="C01" and float(SkillPresentation.cat_state(state,id).get("skill_rage_left",0))>0:
		WeaponVFX.draw_muzzle(self,id,_origin(id),age-CatPerformance.RELEASE,reduced)
		return
	WeaponVFX.draw_muzzle(self,id,feet+CatPerformance.muzzle(id,age,reduced),age-CatPerformance.RELEASE,reduced)

func _draw_pond() -> void:
	# Pond and wicker basket are painted into the bottom table; line/float respond to casting.
	var casting: bool = float(state.get("cast_left",0))>0
	var wiggle: float = sin(clock*16)*4 if casting and not reduced else 0.0
	var float_pos: Vector2 = Vector2(116+wiggle*.3,608+sin(clock*2)*1.5)
	draw_set_transform(float_pos,0,Vector2(1,.28))
	draw_arc(Vector2.ZERO,17+sin(clock*3)*2,0,TAU,30,Color(.92,1,1,.65),2,true)
	draw_set_transform(Vector2.ZERO)
	# Rod and line belong to the painted portable basin; animate only its float.
	draw_circle(float_pos,5,Color("fff8ed"))
	draw_circle(float_pos+Vector2(0,-3),3.7,Color("ed8b82"))
	if casting:
		for i: int in range(3):
			var bubble: Vector2 = float_pos+Vector2(sin(clock*5+i)*16,-8-i*6)
			draw_circle(bubble,2,Color("d6f2ed"))

func fish_shape(p: Vector2, color: Color, factor: float = 1) -> void:
	draw_set_transform(p,0,Vector2(factor,factor))
	draw_colored_polygon(PackedVector2Array([Vector2(15,0),Vector2(33,-14),Vector2(33,14)]),INK)
	draw_colored_polygon(PackedVector2Array([Vector2(15,0),Vector2(29,-9),Vector2(29,9)]),color)
	draw_set_transform(p,0,Vector2(factor,factor*.55))
	draw_circle(Vector2.ZERO,24,INK)
	draw_circle(Vector2.ZERO,21,color)
	draw_set_transform(p,0,Vector2(factor,factor))
	draw_circle(Vector2(-12,-2),3,INK)
	draw_line(Vector2(2,-8),Vector2(2,8),INK,2)
	draw_set_transform(Vector2.ZERO)

func _draw_enemy(enemy: Dictionary) -> void:
	var id: String = str(enemy.kind)
	var boss: bool = id.begins_with("B")
	if bool(enemy.get("boss_fixed",false)):
		# The body and its connected target part are behind the small creatures.
		var point: Vector2=Vector2(float(enemy.x),float(enemy.get("y",430)))
		FishVFX.draw_status(self,enemy,point+Vector2(0,35),70,clock,reduced)
		ExpansionVFX.enemy_status(self,enemy,point+Vector2(0,35),70,clock,reduced)
		return
	var tex: Texture2D = Art.enemy(id)
	var height: float = float(enemy.get("draw_height",280 if boss else 64))
	var width: float = height*tex.get_width()/float(tex.get_height())
	var p: Vector2 = Vector2(float(enemy.x),float(enemy.get("feet_y",500))+float(int(enemy.id)%5-2)*2)
	p+=skills_view.enemy_offset(enemy,reduced)
	var windup: float = float(enemy.get("windup",0))
	var strike: float = float(reactions.get("enemy%d" % int(enemy.id),0))
	var frozen: bool = float(enemy.get("freeze",0))>0 or float(enemy.get("stun",0))>0
	var hit_left: float = float(reactions.get("hit%d" % int(enemy.id),0))
	var hit_age: float = HitMotion.DURATION-hit_left if hit_left>0 else -1.0
	var hit_flash: float = HitMotion.flash(hit_age)
	var bounce: float = 0.0 if reduced or frozen else sin(clock*(5 if boss else 8)+float(enemy.id))
	var action: float = 0.0 if reduced else sin(strike/.28*PI)
	p.x += minf(9,windup*13)-action*19 if not reduced else 0.0
	draw_set_transform(Vector2(p.x,501),0,Vector2(1,.18))
	draw_circle(Vector2.ZERO,width*.40,Color(.25,.2,.26,.14))
	var stretch: Vector2 = Vector2(1+bounce*.018+action*.07,1-bounce*.023-action*.05)
	stretch *= HitMotion.sample(hit_age,reduced,frozen,boss)
	stretch *= skills_view.enemy_stretch(enemy,state,reduced)
	var tilt: float = bounce*(.025 if boss else .055)-action*.07
	if id=="E05": tilt += bounce*.12
	if bool(enemy.get("air",false)) and not reduced: p.y+=sin(clock*3+float(enemy.id))*5
	# All stretching uses the existing bottom-center pivot; grounded feet never jump.
	draw_set_transform(p,tilt,stretch)
	var sprite_tint: Color = Color("d3eeff") if frozen else Color.WHITE
	var flash_gain: float = hit_flash*(.12 if reduced else .30)
	sprite_tint = Color(sprite_tint.r+flash_gain,sprite_tint.g+flash_gain,sprite_tint.b+flash_gain,1)
	enemy_visuals[int(enemy.id)]={"position":p,"scale":stretch,"angle":tilt,"height":height}
	draw_texture_rect(tex,Rect2(-width*.5,-height,width,height),false,sprite_tint)
	draw_set_transform(Vector2.ZERO)
	if float(enemy.get("shield",0))>0:
		Painted.sprite(self,"F08",1,p-Vector2(0,height*.5),Vector2(width*1.2,height*1.1),0,Color(.8,.92,1,.35))
	FishVFX.draw_status(self,enemy,p,height,clock,reduced)
	EnemyVFX.windup(self,enemy,p,height,reduced)
	ExpansionVFX.enemy_status(self,enemy,p,height,clock,reduced)
	var hp_ratio: float = clampf(float(enemy.hp)/maxf(1,float(enemy.max_hp)),0,1)
	var bar_width: float = 94.0 if boss else clampf(width*.82,34,62)
	var bar_rect: Rect2 = Rect2(p.x-bar_width*.5,p.y-height-12,bar_width,7)
	var hp_style: StyleBoxFlat = StyleBoxFlat.new()
	hp_style.bg_color = Color("fff9ee")
	hp_style.border_color = INK
	hp_style.set_border_width_all(1)
	hp_style.set_corner_radius_all(4)
	draw_style_box(hp_style,bar_rect)
	if hp_ratio>0:
		draw_line(bar_rect.position+Vector2(3,3.5),bar_rect.position+Vector2(3+(bar_width-6)*hp_ratio,3.5),Color("ed9382"),3,true)

func _draw_projectile(projectile: Dictionary, prominent: bool = true) -> void:
	if float(projectile.get("age",0))<float(projectile.get("delay",0)): return
	var cat: String = str(projectile.get("cat","C01"))
	var p: Vector2 = Vector2(float(projectile.get("x",260)),float(projectile.get("y",400)))
	var ratio: float = clampf((float(projectile.get("age",0))-float(projectile.get("delay",0)))/maxf(.001,float(projectile.get("travel",1))),0,1)
	var logical_origin: Vector2 = Vector2(float(projectile.get("origin_x",130)),float(projectile.get("origin_y",350)))
	# A projectile keeps its release point even if its owner's rage expires mid-flight.
	var origin: Vector2 = logical_origin
	if not bool(projectile.get("confused",false)): p += (origin-logical_origin)*(1.0-ratio)
	var lane: float = 0.0 if bool(projectile.get("confused",false)) else float(projectile.get("lane",0.0))
	if not bool(projectile.get("confused",false)): p.y += sin(ratio*PI)*lane
	var target: Vector2 = Vector2(float(projectile.get("target_x",1000)),float(projectile.get("target_y",480)))
	var direction: Vector2 = (target-origin+Vector2(0,cos(ratio*PI)*lane*PI)).normalized()
	var snapshot: Dictionary = {}
	for current: Dictionary in state.get("battle",{}).get("cats",[]):
		if current.id==cat: snapshot=current; break
	var presented: Dictionary = projectile.duplicate()
	presented["visual_emphasis"]=1.0 if prominent else .48
	var context: Dictionary = state.get("battle",{}).get("attacks",{}).get(int(projectile.get("attack",0)),{})
	presented.critical = bool(projectile.get("payload",{}).get("critical",context.get("crit",false)))
	WeaponVFX.draw_projectile(self,presented,p,direction,clock,reduced)
	FishVFX.draw_projectile(self,presented,p,direction,snapshot.get("fish",{}),clock,reduced)

func _battle_arc(center: Vector2, radius: float, color: Color, line_width: float) -> void:
	# Effect geometry stops at the combat area; the contribution dashboard stays clear.
	var segment: PackedVector2Array = []
	for i: int in range(65):
		var point: Vector2 = center+Vector2.from_angle(i*TAU/64.0)*radius
		if point.y>=96 and point.y<=538:
			segment.append(point)
		else:
			if segment.size()>1: draw_polyline(segment,color,line_width,true)
			segment = []
	if segment.size()>1: draw_polyline(segment,color,line_width,true)

func _draw_pop(effect: Dictionary) -> void:
	var age: float = float(effect.age)
	var p: Vector2 = Vector2(float(effect.get("x",260)),float(effect.get("y",478)))
	var type: String = str(effect.get("type",""))
	var kind: String = str(effect.get("kind",""))
	if type in ["boss_counter_warning","boss_counter_success","boss_counter_failure","toy_combo"]:
		Signals.event(self,effect,font,reduced)
		return
	if type in ["toy_charge","toy_armed"] or (type=="toy_cast" and kind in ["shield_cannon","bell_echo"]) or (type=="burst" and kind=="shield_cannon"):
		Mutations.draw_event(self,effect,state,reduced)
		return
	if type=="mechanism_identity":
		Identity.draw(self,effect,_origin(str(effect.get("cat","C01"))),reduced)
		return
	if type in ["base_damage_resolved","base_shield_broken","base_low_hp"]:
		BaseFeedback.draw(self,effect,reduced,font)
		return
	if type=="attack":
		# Instant weapons are shown by their actual hit events, including every split target.
		return
	if type=="hit":
		if kind in ["primary","innate","fur","arc","paw","echo","return","bounce","pierce","horn"]:
			WeaponVFX.draw_impact(self,effect,p,age,reduced,font)
	elif type=="bell_return":
		var duration: float = maxf(.01,float(effect.get("duration",.55)))
		if age<=duration:
			var t: float = age/duration
			var destination: Vector2 = _origin(str(effect.get("to_cat","C01")))
			var start: Vector2 = Vector2(float(effect.get("from_x",p.x)),float(effect.get("from_y",468)))
			var note: Vector2 = start.lerp(destination,t)+Vector2(0,-sin(t*PI)*64)
			Painted.sprite(self,"C06",0,note,Vector2(23,23),sin(t*TAU)*.18,Color("fff0b8"))
			if not reduced: draw_arc(note,14,t*TAU,t*TAU+PI,14,Color(1,.85,.47,.5),1.2,true)
	elif type=="cat_buff":
		if age<.28:
			var destination: Vector2 = _origin(str(effect.get("to_cat","C01")))
			Painted.sprite(self,"C06",2,destination,Vector2.ONE*(23+age*20),0,Color(1,.9,.7,1-age/.28))
	elif type=="innate":
		BuildArt.innate(self,effect,p,age,reduced)
	elif type=="death":
		if not str(effect.get("enemy_kind",effect.get("kind",""))).begins_with("B"):
			_draw_defeat(effect,p,age)
	elif type=="shield" and str(effect.get("fish",""))!="F08":
		var source: String = str(effect.get("cat",""))
		var source_pos: Vector2 = _origin(source) if source in state.get("active",[]) else Vector2(344,375)
		var fade: float = maxf(0,1-age/.6)
		Painted.sprite(self,"C06",3,source_pos,Vector2.ONE*(57+age*20),0,Color(1,1,1,fade*.6))
		if source=="C06": WeaponVFX.draw_muzzle(self,"C06",source_pos,minf(age*.30,.21),reduced)
	elif type=="base_hit":
		if str(effect.get("enemy_kind","")).begins_with("B"):
			BossPresentation.draw_impact(self,effect)
		else: EnemyVFX.strike(self,effect,age,reduced)
	elif type=="enemy_special":
		EnemyVFX.special(self,effect,age,reduced)
	# All fish procs use actual event metadata; the helper ignores non-fish base hits.
	if type in ["shield","shield_absorb","block","safeguard"] or (type=="burst" and kind=="shield_break"): p=Vector2(344,375)
	FishVFX.draw_event(self,effect,p,age,reduced,font)
	var cat_id: String=str(effect.get("to_cat",effect.get("cat","C01")))
	var cat_slot: int=state.get("active",[]).find(cat_id)
	ExpansionVFX.event(self,effect,VISUAL_FEET[clampi(cat_slot,0,4)],reduced)

func _draw_lightning(start: Vector2, end: Vector2, fade: float, gold: bool) -> void:
	Painted.beam(self,"F06" if gold else "C03",1,start,end,7 if reduced else 10,Color(1,1,1,fade))

func _draw_damage_number(effect: Dictionary, p: Vector2, age: float) -> void:
	# Kept as a focused drawing entry point for presentation previews.
	var preview: Dictionary = effect.duplicate()
	preview["x"] = p.x
	preview["y"] = p.y
	DamageNumbers.draw(self,preview,age,reduced,font)

func _draw_defeat(effect: Dictionary, _p: Vector2, age: float) -> void:
	Defeat.draw(self,effect,age,reduced)

func has_death_remainder() -> bool:
	if boss_view.settle_remaining()>0: return true
	for effect: Dictionary in pops:
		if str(effect.get("type",""))=="death" and float(effect.get("age",0))<Defeat.duration(effect): return true
	return false

func death_remainder_seconds() -> float:
	return maxf(maxf(1.1 if has_death_remainder() else 0.0,boss_view.settle_remaining()),stage_life.quiet_remaining())
