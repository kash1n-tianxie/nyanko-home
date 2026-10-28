extends RefCounted
## Authored toy art, motion and hostile status feedback use resolved simulation data.
const Art=preload("res://scripts/expansion_art.gd")
const Paint=preload("res://scripts/painted_vfx.gd")
const BuildArt=preload("res://scripts/build_art.gd")
const Tune=preload("res://scripts/feedback_tuning.gd")
const Frames=preload("res://scripts/frame_art.gd")
static func sprite(canvas: Node2D, key: String, pos: Vector2, bounds: Vector2, angle: float=0, alpha: float=1) -> void:
	var tex: Texture2D=Art.picture("vfx",key)
	if tex==null: return
	var dimensions: Vector2=tex.get_size()
	var factor: float=minf(bounds.x/dimensions.x,bounds.y/dimensions.y)
	Paint.draw_texture(canvas,tex,pos,dimensions*factor,angle,Color(1,1,1,clampf(alpha,0,1)))
static func value(group: String, key: String, fallback: float) -> float:
	return Tune.number(group,key,fallback)
static func debuff_point(flight: Dictionary, progress: float) -> Vector2:
	var start: Vector2=Vector2(float(flight.from_x),float(flight.from_y))
	var target: Vector2=Vector2(float(flight.to_x),float(flight.to_y))
	var t: float=clampf(progress,0,1)
	return start.lerp(target,t)+Vector2(0,-sin(t*PI)*value("debuff","arc_height",46))
static func debuff_flights(canvas: Node2D, battle: Dictionary, reduced: bool) -> void:
	for flight: Dictionary in battle.get("debuff_projectiles",[]):
		var duration: float=maxf(.01,float(flight.duration))
		var progress: float=clampf(1.0-float(flight.left)/duration,0,1)
		var web: bool=str(flight.kind)=="web"
		var color: Color=Color("eee2c4") if web else Color("df98ff")
		var point: Vector2=debuff_point(flight,progress)
		var count: int=3 if reduced else int(value("debuff","trail_points",9))
		for i: int in range(count):
			var end_t: float=maxf(0,progress-float(i)*.025)
			var start_t: float=maxf(0,end_t-.025)
			var trail_color: Color=Color(color, (.72 if web else .58)*(1.0-float(i)/count))
			canvas.draw_line(debuff_point(flight,start_t),debuff_point(flight,end_t),trail_color,3.5 if web else 4.5,true)
		var size: float=value("debuff","missile_size",57)*(value("debuff","reduced_scale",.82) if reduced else 1.0)
		sprite(canvas,"enemy-web" if web else "confusion",point,Vector2.ONE*size,0.0 if reduced else progress*TAU*.7)
		# The destination ring is attached to the intended cat, never an arbitrary HUD marker.
		var target: Vector2=Vector2(float(flight.to_x),float(flight.to_y))
		canvas.draw_arc(target,25,progress*TAU,progress*TAU+PI*1.35,25,Color(color,.6),2.5,true)
static func base_shield(canvas: Node2D, battle: Dictionary, clock: float, reduced: bool) -> void:
	var amount: float=0
	for shield: Dictionary in battle.get("shields",[]):
		if str(shield.get("source",""))=="T14": amount+=float(shield.get("amount",0))
	if amount<=0: return
	var alpha: float=value("toy","shield_alpha",.30)
	if not reduced: alpha+=sin(clock*2.0)*.035
	sprite(canvas,"barrier",Vector2(233,321),Vector2(value("toy","shield_width",322),value("toy","shield_height",402)),0,alpha)
	# A compact source emblem makes an active toy shield different from a fish shield.
	Art.fit(canvas,Art.picture("toys","T14"),Rect2(329,307,34,34),Color(1,1,1,.9))
static func cat_status(canvas: Node2D, cat: Dictionary, p: Vector2, clock: float, reduced: bool) -> void:
	var web_left: float=float(cat.get("web_left",0))
	var confuse_left: float=float(cat.get("confuse_left",0))
	if web_left>0:
		var size: Vector2=Vector2(value("debuff","web_width",102),value("debuff","web_height",98))
		if reduced: size*=value("debuff","reduced_scale",.82)
		sprite(canvas,"web",p+Vector2(0,-42),size,0,value("debuff","body_alpha",.88))
		_status_badge(canvas,"web",p+Vector2(-39,-92),web_left/maxf(.01,float(cat.get("web_duration",web_left))),Color("e7c784"))
	if confuse_left>0:
		var marker: Vector2=p+Vector2(33,-101)
		sprite(canvas,"confusion",marker,Vector2(55,43),0.0 if reduced else sin(clock*5)*.14,.95)
		_status_badge(canvas,"confusion",p+Vector2(43,-77),confuse_left/maxf(.01,float(cat.get("confuse_duration",confuse_left))),Color("d68aff"))

static func base_curse_active(battle: Dictionary) -> bool:
	for cat: Dictionary in battle.get("cats",[]):
		if float(cat.get("toys",{}).get("base_damage_taken",1))>1: return true
	return false

static func base_status(canvas: Node2D, battle: Dictionary) -> void:
	# The drawback belongs to the home, not five separate enemy debuffs on cats.
	# Each beneficiary's sewn costume cue and the full toy tooltip remain intact.
	if base_curse_active(battle):
		sprite(canvas,"curse",Vector2(211,461),Vector2(25,30),0,.83)
static func _status_badge(canvas: Node2D, key: String, point: Vector2, ratio: float, color: Color) -> void:
	var icon: float=value("debuff","status_icon",31)
	canvas.draw_circle(point,icon*.58,Color("392b42"))
	sprite(canvas,key,point,Vector2.ONE*icon)
	canvas.draw_arc(point,icon*.62,-PI*.5,-PI*.5+TAU*clampf(ratio,0,1),28,color,3,true)
static func enemy_status(canvas: Node2D, enemy: Dictionary, p: Vector2, height: float, _clock: float, _reduced: bool) -> void:
	if not enemy.get("toy_bleed",{}).is_empty() and Frames.texture("effects","ghost_claw",0)==null:
		sprite(canvas,"ghost_claw",p+Vector2(3,-height*.38),Vector2(38,47),0,.70)
	if not enemy.get("ink_mark",{}).is_empty(): sprite(canvas,"curse",p+Vector2(-height*.25,-height*.55),Vector2(28,34),0,.9)
	if float(enemy.get("taunt_left",0))>0:
		var marker: Vector2=p+Vector2(0,-height-31)
		Art.fit(canvas,Art.picture("toys","T20"),Rect2(marker-Vector2(18,18),Vector2(36,36)),Color(1,1,1,.95))
	if float(enemy.get("rally_left",0))>0:
		sprite(canvas,"enemy-rally",p+Vector2(-17,-height-17),Vector2(34,32),0,.92)
	var windup: float=float(enemy.get("skill_windup",0))
	if windup>0:
		var key: String="web" if str(enemy.get("skill",""))=="web" else "confusion"
		if str(enemy.get("skill","")) in ["web","confusion"]: sprite(canvas,key,p+Vector2(0,-height-35),Vector2(45,45))
		else: sprite(canvas,"enemy-rally" if str(enemy.get("skill",""))=="rally" else "enemy-summon",p+Vector2(0,-height-35),Vector2(45,45))
		var ratio: float=clampf(windup/maxf(.01,float(enemy.get("skill_telegraph",1))),0,1)
		canvas.draw_arc(p+Vector2(0,-height-35),28,-PI*.5,-PI*.5+TAU*ratio,28,Color("df855c"),3,true)
static func _source(canvas: Node2D, effect: Dictionary, point: Vector2, age: float, reduced: bool) -> void:
	var duration: float=value("toy","source_duration",.42)
	var toy: String=str(effect.get("toy",""))
	if toy=="" or age>duration: return
	# Authored activation already plays once at its tree anchor. Do not stamp
	# the item a second time at the damage point as if it were another projectile.
	if Frames.texture("toys",toy,0)!=null: return
	var t: float=age/duration
	var size: float=value("toy","source_icon",46)*(1.0 if reduced else 1.0+sin(t*PI)*.22)
	var alpha: float=1.0-smoothstep(.55,1.0,t)
	canvas.draw_circle(point,size*.51,Color(.13,.10,.19,alpha*.65))
	canvas.draw_arc(point,size*.56,-PI*.5,-PI*.5+TAU*(1-t),28,Color(1,.83,.38,alpha),2.5,true)
	Art.fit(canvas,Art.picture("toys",toy),Rect2(point-Vector2.ONE*size*.5,Vector2.ONE*size),Color(1,1,1,alpha))
static func event(canvas: Node2D, effect: Dictionary, cat_point: Vector2, reduced: bool) -> void:
	var age: float=float(effect.get("age",0))
	var type: String=str(effect.get("type",""))
	var kind: String=str(effect.get("kind",""))
	var p: Vector2=Vector2(float(effect.get("x",600)),float(effect.get("y",460)))
	var duration: float=maxf(.01,float(effect.get("duration",.5)))
	var scale: float=value("toy","reduced_scale",.78) if reduced else 1.0
	if type=="toy_cast":
		var t: float=clampf(age/duration,0,1)
		var alpha: float=1-smoothstep(.6,1,t)
		var from: Vector2=Vector2(float(effect.get("from_x",p.x)),float(effect.get("from_y",70)))
		var target: Vector2=Vector2(float(effect.get("to_x",p.x)),float(effect.get("to_y",p.y)))
		match kind:
			"meteor":
				if age<=duration:
					var falling: Vector2=from.lerp(target,t*t)
					var radius: float=float(effect.get("radius",100))
					sprite(canvas,"meteor",falling,Vector2(value("toy","meteor_width",111),value("toy","meteor_height",160))*scale,.25,1)
					canvas.draw_arc(target,radius*(.95-.25*t),0,TAU,40,Color(.94,.58,.30,.65),2.5,true)
					canvas.draw_arc(target,17+12*t,0,TAU,28,Color(1,.87,.48,.8),2,true)
				_source(canvas,effect,from+Vector2(-26,4),age,reduced)
			"laser":
				if age<=duration:
					var tex: Texture2D=Art.picture("vfx","laser")
					if tex!=null: Paint.draw_texture(canvas,tex,(from+target)*.5,Vector2(from.distance_to(target),value("toy","laser_width",46)*scale),(target-from).angle(),Color(1,1,1,alpha))
					canvas.draw_line(from,target,Color(1,.96,.72,alpha*.7),2.5,true)
				_source(canvas,effect,from+Vector2(-23,-34),age,reduced)
			"blackhole":
				if not Frames.draw(canvas,"effects","blackhole",age,duration,p,Vector2.ONE*174*scale,0,Color(1,1,1,alpha)):
					var size: float=value("toy","blackhole_size",160)*(.85+sin(t*PI)*.25)
					sprite(canvas,"black_hole",p,Vector2.ONE*size*scale,0.0 if reduced else age*2.4,alpha*.88)
				if not reduced:
					for i: int in range(7):
						var angle: float=i*TAU/7-age*3.4
						var outer: Vector2=p+Vector2.from_angle(angle)*(float(effect.get("radius",180))*(1-t*.6))
						canvas.draw_line(outer,outer.lerp(p,.24),Color(.70,.47,.91,alpha*.48),2.3,true)
				_source(canvas,effect,p+Vector2(-78,-53),age,reduced)
			"decoy":
				var loop_age: float=fmod(age,.72)
				if age<duration and not Frames.draw(canvas,"effects","decoy",loop_age,.72,p,Vector2.ONE*120*scale,0,Color(1,1,1,alpha)):
					var bounce: float=0.0 if reduced else -absf(sin(age*6))*11
					sprite(canvas,"decoy",p+Vector2(0,bounce),Vector2(value("toy","decoy_width",106),value("toy","decoy_height",84))*scale,0,alpha)
				_source(canvas,effect,p+Vector2(-57,-48),age,reduced)
			"base_shield":
				if not Frames.draw(canvas,"effects","shield_build",age,duration,Vector2(236,326),Vector2(315,350),0,Color(1,1,1,alpha*.64)):
					sprite(canvas,"barrier",Vector2(236,326),Vector2(value("toy","shield_width",322),value("toy","shield_height",402))*(1.0+sin(t*PI)*.07),0,alpha*.48)
				_source(canvas,effect,Vector2(332,276),age,reduced)
			"revive":
				if not Frames.draw(canvas,"effects","revive",age,duration,Vector2(240,319),Vector2.ONE*215*scale,0,Color(1,1,1,alpha)):
					sprite(canvas,"revive",Vector2(240,319),Vector2(value("toy","revive_width",182),value("toy","revive_height",238))*scale*(.9+sin(t*PI)*.16),0,alpha)
				if not reduced: canvas.draw_arc(Vector2(240,330),45+t*75,0,TAU,40,Color(.99,.79,.40,alpha*.7),3,true)
				_source(canvas,effect,Vector2(336,260),age,reduced)
	elif type=="enemy_debuff_cast":
		if age<.18:
			sprite(canvas,"enemy-web" if kind=="web" else "confusion",p,Vector2.ONE*(39+age*90),0,1-age/.18)
	elif type=="cat_debuff":
		var impact: float=value("debuff","impact_duration",.42)
		if age<impact:
			var t: float=age/impact
			var target: Vector2=Vector2(float(effect.get("to_x",cat_point.x)),float(effect.get("to_y",cat_point.y-42)))
			var color: Color=Color("f4dfac") if kind=="web" else Color("d997ff")
			var radius: float=value("debuff","impact_radius",56)*(value("debuff","reduced_scale",.82) if reduced else 1.0)
			canvas.draw_arc(target,20+t*radius,0,TAU,36,Color(color,(1-t)*.9),4*(1-t)+1,true)
			sprite(canvas,"web" if kind=="web" else "confusion",target,Vector2.ONE*(radius*(1.0+sin(t*PI)*.65)),0,(1-t)*.9)
	elif type=="cat_cleanse":
		if age<.4 and not Frames.draw(canvas,"effects","cleanse",age,.4,cat_point+Vector2(0,-35),Vector2.ONE*106*scale):
			sprite(canvas,"cleanse",cat_point+Vector2(0,-35),Vector2.ONE*(73+age*27)*scale,0,1-age/.4)
	elif type=="toy_heal":
		if age<.6:
			if not Frames.draw(canvas,"effects","cleanse",age,.6,Vector2(268,310),Vector2.ONE*106*scale):
				sprite(canvas,"cleanse",Vector2(268,324-age*25),Vector2(67,75)*scale,0,1-age/.6)
			_source(canvas,effect,Vector2(323,316),age,reduced)
	elif type=="hit" and kind=="toy_bleed" and float(effect.get("amount",0))>0:
		Frames.draw(canvas,"effects","ghost_claw",age,.42,p,Vector2.ONE*70*scale)
	elif type=="enemy_skill":
		if age>.65: return
		var skill: String=str(effect.get("skill",""))
		if skill=="rally": sprite(canvas,"enemy-rally",p+Vector2(0,-45-age*22),Vector2(77,75),0,1-age/.65)
		elif skill=="summon": sprite(canvas,"enemy-summon",p+Vector2(37,8),Vector2(111,62)*(1+age*.2),0,1-age/.65)
	elif type=="burst":
		var life: float=value("toy","meteor_impact_duration",.48) if kind=="meteor" else value("toy","explosion_duration",.35)
		if age>life: return
		var t: float=age/life
		var alpha: float=1-smoothstep(.22,1,t)
		# The authored final poses already disperse. Keep their main silhouettes
		# opaque long enough to read instead of fading the new frame art twice.
		var frame_alpha: float=1-smoothstep(.82,1,t)
		if kind=="meteor":
			if not Frames.draw(canvas,"effects","meteor_impact",age,life,p,Vector2.ONE*178*scale,0,Color(1,1,1,frame_alpha)):
				sprite(canvas,"meteor_impact",p,Vector2.ONE*value("toy","meteor_impact_size",157)*scale*(.7+.4*t),0,alpha*.95)
			canvas.draw_arc(p,float(effect.get("radius",100))*(.35+.65*t),0,TAU,40,Color(.97,.69,.35,alpha*.75),3,true)
		elif kind=="toy_explosion":
			# Let the cloud billow above the hit point: drawing its entire face
			# behind a ground enemy hides the authored action almost completely.
			if not Frames.draw(canvas,"effects","popcorn_burst",age,life,p+Vector2(0,-26),Vector2.ONE*122*scale,0,Color(1,1,1,frame_alpha)):
				BuildArt.sprite(canvas,"fire_burst",p,Vector2.ONE*value("toy","explosion_size",76)*scale*(.7+.7*t),0,alpha*.88)
		elif kind in ["cloud_burst","ink_burst"]: sprite(canvas,"cleanse" if kind=="cloud_burst" else "curse",p,Vector2.ONE*(65+age*56)*scale,0,alpha*.78)
