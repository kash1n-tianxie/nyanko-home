extends RefCounted
## Persisted deterministic active skills. Rendering consumes events and never resolves hits.
const Catalog=preload("res://scripts/skill_catalog.gd")
const Ledger=preload("res://scripts/feedback_ledger.gd")
var _combat: WeakRef
var combat: RefCounted:
	get: return _combat.get_ref()
var run: RefCounted:
	get: return combat.run
var b: Dictionary:
	get: return combat.b
func setup(value: RefCounted) -> void: _combat=weakref(value)
func charge_duration(cat: Dictionary) -> float: return Catalog.charge_duration(cat)

func initialize_cat(cat: Dictionary,elapsed: float=0.0) -> void:
	if not cat.has("skills") or not cat.skills is Dictionary:
		var duration: float=charge_duration(cat)
		var charge: float=clampf(elapsed,0.0,duration)
		cat.skills={"charge":charge,"duration":duration,"ready":charge>=duration,"used":false,"active_left":0.0}
	for key: String in ["skill_rage_left","skill_chorus_left"]:
		if not cat.has(key): cat[key]=0.0

func migrate() -> void:
	if b.is_empty(): return
	if not b.has("skill_flights"): b.skill_flights=[]
	if not b.has("next_skill_cast"): b.next_skill_cast=1
	if not b.has("cinematic"): b.cinematic={"active":false}
	for cat: Dictionary in b.get("cats",[]): initialize_cat(cat,float(b.get("time",0)))
	b.skill_version=Catalog.VERSION
	if str(run.s.get("phase","")) not in ["combat","cleanup"]: clear()

func status(cat_id: String) -> Dictionary:
	var cat: Dictionary=combat.get_cat(cat_id)
	if cat.is_empty(): return {}
	var definition: Dictionary=Catalog.definition(cat_id)
	var state: Dictionary=cat.get("skills",{})
	var duration: float=float(state.get("duration",charge_duration(cat)))
	return {"cat":cat_id,"skill_id":definition.id,"name":definition.name,"description":definition.description,"ready":bool(state.get("ready",false)),"used":bool(state.get("used",false)),"charge":float(state.get("charge",0)),"duration":duration,"progress":clampf(float(state.get("charge",0))/maxf(.01,duration),0,1),"active_left":float(state.get("active_left",0))}

func cast(cat_id: String) -> Dictionary:
	if not _active(): return {"ok":false,"message":"战斗中才能使用技能"}
	if cinematic_busy(): return {"ok":false,"message":"请看完这次绝招，再释放下一只猫"}
	if float(run.s.get("meal",{}).get("flight_left",0))>0: return {"ok":false,"message":"餐盒正在送达，稍后释放绝招"}
	var cat: Dictionary=combat.get_cat(cat_id)
	if cat.is_empty() or not Catalog.DEFINITIONS.has(cat_id): return {"ok":false,"message":"没有这位出战猫咪"}
	initialize_cat(cat)
	if bool(cat.skills.used): return {"ok":false,"message":"本场技能已使用"}
	if not bool(cat.skills.ready): return {"ok":false,"message":"技能还在蓄能"}
	var spec: Dictionary=Catalog.definition(cat_id)
	combat._derive_cat_stats(cat)
	var power: float=cat.attack
	cat.skills.used=true;cat.skills.ready=false
	cat.skills.active_left=0.0
	var aim: Vector2=Vector2(900,460)
	var choices: Array=_visible_targets()
	if not choices.is_empty(): aim=Vector2(choices[0].x,choices[0].get("y",480))
	if cat_id=="C06": aim=Vector2(combat.BASE_X,365)
	var origin: Vector2=combat.cat_origin(cat_id)
	var cast_id: int=int(b.get("next_skill_cast",1));b.next_skill_cast=cast_id+1
	var notice: Dictionary={"type":"skill_cast","cat":cat_id,"skill_id":spec.id,"name":spec.name,"description":spec.description,"duration":spec.cinema_duration,"attack":power,"from_x":origin.x,"from_y":origin.y,"target_x":aim.x,"target_y":aim.y,"x":aim.x,"y":aim.y,"impact_delay":spec.delay,"buff_duration":spec.get("buff_duration",0),"radius":spec.get("radius",0),"cast_id":cast_id}
	run.events.append(notice)
	var scheduled: Array=[]
	if cat_id=="C05":
		# The visible front reaches each frozen target at a different time.
		for enemy: Dictionary in choices:
			var arrival: float=float(spec.delay)+clampf((float(enemy.x)-combat.BASE_X)/(combat.VISIBLE_RIGHT-combat.BASE_X),0,1)*float(spec.sweep_duration)
			scheduled.append({"at":arrival,"target":int(enemy.id),"pulse":scheduled.size()})
		if scheduled.is_empty(): scheduled.append({"at":float(spec.delay),"target":-1,"pulse":0})
	else:
		for pulse: int in range(int(spec.get("pulses",1))):
			scheduled.append({"at":float(spec.delay)+pulse*float(spec.get("pulse_interval",0)),"pulse":pulse})
	b.cinematic={"active":true,"cat":cat_id,"age":0.0,"duration":float(spec.cinema_duration),"cast_id":cast_id,"impacts_done":[],"schedule":scheduled,"impact_history":[],"cast":notice.duplicate(true)}
	# Current releases use the cinematic clock. Legacy saved flights remain supported.

	return {"ok":true,"message":str(spec.name)}

func tick(delta: float) -> void:
	if delta<=0.0 or not _active() or cinematic_busy(): return
	for cat: Dictionary in b.get("cats",[]):
		initialize_cat(cat)
		var state: Dictionary=cat.skills
		if not bool(state.used) and not bool(state.ready):
			state.charge=minf(float(state.duration),float(state.charge)+delta)
			if float(state.charge)>=float(state.duration)-.000001:
				state.ready=true
				var origin: Vector2=combat.cat_origin(cat.id)
				run.events.append({"type":"skill_ready","cat":cat.id,"skill_id":Catalog.DEFINITIONS[cat.id].id,"name":Catalog.DEFINITIONS[cat.id].name,"x":origin.x,"y":origin.y})
		for key: String in ["skill_rage_left","skill_chorus_left"]:
			if float(cat.get(key,0))<=0: continue
			var before_speed: float=Catalog.speed_multiplier(cat)
			cat[key]=maxf(0,float(cat[key])-delta)
			if float(cat[key])<=0:
				_rescale_cooldown(cat,before_speed)
				combat._derive_cat_stats(cat)
				if key=="skill_rage_left" or cat.id=="C06":
					run.events.append({"type":"skill_expired","cat":cat.id,"skill_id":"rage" if key=="skill_rage_left" else "sanctuary"})
		state.active_left=maxf(float(cat.get("skill_rage_left",0)),float(cat.get("skill_chorus_left",0)) if cat.id=="C06" else 0.0)
	var pending: Array=b.get("skill_flights",[]);b.skill_flights=[]
	for flight: Dictionary in pending:
		if not _active(): break
		flight.left=float(flight.left)-delta
		if float(flight.left)>.000001: b.skill_flights.append(flight)
		else: _impact(flight)

func cinematic_busy() -> bool:
	return not run.s.is_empty() and not b.is_empty() and bool(b.get("cinematic",{}).get("active",false))

func tick_cinematic(real_delta: float) -> void:
	if not cinematic_busy(): return
	if str(run.s.get("phase","")) not in ["combat","cleanup"] or float(run.s.get("hp",0))<=0:
		clear();return
	if real_delta<=0 or bool(run.s.get("paused",false)): return
	var cinema: Dictionary=b.cinematic
	cinema.age=minf(float(cinema.duration),float(cinema.age)+real_delta)
	for index: int in range(cinema.schedule.size()):
		var beat: Dictionary=cinema.schedule[index]
		if index in cinema.impacts_done or float(cinema.age)+.000001<float(beat.at): continue
		# Persist the consumed beat before resolving its hit, so a saved state cannot replay it.
		cinema.impacts_done.append(index)
		var flight: Dictionary=cinema.cast.duplicate(true)
		flight.pulse=beat.get("pulse",0);flight.cinematic_age=beat.at
		if beat.has("target"): flight.target=beat.target
		_impact(flight)
	if float(cinema.age)>=float(cinema.duration)-.000001:
		cinema.active=false
		run.events.append({"type":"skill_cinematic_end","cat":cinema.cat,"cast_id":cinema.cast_id,"duration":cinema.duration})
		# An end snapshot also persists buffs and all consumed beats together.
		if run.autosave: run.save(run.save_path)

func clear() -> void:
	if b.is_empty(): return
	b.skill_flights=[]
	b.cinematic={"active":false}
	for cat: Dictionary in b.get("cats",[]):
		var before_speed: float=Catalog.speed_multiplier(cat)
		cat.skill_rage_left=0.0;cat.skill_chorus_left=0.0
		if cat.has("skills"): cat.skills.active_left=0.0;cat.skills.ready=false
		_rescale_cooldown(cat,before_speed)
		combat._derive_cat_stats(cat)
	b.shields=b.get("shields",[]).filter(func(layer:Dictionary)->bool:return not bool(layer.get("active_skill",false)))

func _active() -> bool:
	return not run.s.is_empty() and not b.is_empty() and str(run.s.get("phase","")) in ["combat","cleanup"] and not bool(run.s.get("paused",false)) and float(run.s.get("hp",0))>0

func _visible_targets() -> Array:
	var result: Array=combat.enemies().filter(func(enemy:Dictionary)->bool:return combat.BossRules.visible(enemy) and float(enemy.x)>=combat.BASE_X and float(enemy.x)<=combat.VISIBLE_RIGHT)
	result.sort_custom(func(a:Dictionary,c:Dictionary)->bool:
		var a_score: int=combat._threat_score(a);var c_score: int=combat._threat_score(c)
		if a_score!=c_score: return a_score>c_score
		if not is_equal_approx(float(a.x),float(c.x)): return float(a.x)<float(c.x)
		return int(a.id)<int(c.id))
	return result

func _set_buff(cat: Dictionary,key: String,duration: float) -> void:
	var before_speed: float=Catalog.speed_multiplier(cat)
	cat[key]=maxf(float(cat.get(key,0)),duration)
	_rescale_cooldown(cat,before_speed)
	combat._derive_cat_stats(cat)

func _rescale_cooldown(cat: Dictionary,before_speed: float) -> void:
	cat.cooldown=float(cat.get("cooldown",0))*before_speed/Catalog.speed_multiplier(cat)

func _impact(flight: Dictionary) -> void:
	var spec: Dictionary=Catalog.definition(str(flight.cat))
	var notice: Dictionary=flight.duplicate(true)
	notice.type="skill_impact";notice.targets=[];notice.radius=spec.get("radius",0)
	var targets: Array=_visible_targets()
	match str(flight.cat):
		"C01":
			var cat: Dictionary=combat.get_cat("C01")
			_set_buff(cat,"skill_rage_left",float(spec.buff_duration))
			cat.skills.active_left=float(spec.buff_duration)
			notice.buff_duration=spec.buff_duration
		"C02":
			for enemy: Dictionary in targets:
				if Vector2(enemy.x,enemy.get("y",480)).distance_to(Vector2(flight.x,flight.y))<=float(spec.radius): notice.targets.append(_hit(enemy,flight,float(spec.coefficient)))
		"C03":
			if not targets.is_empty():
				var enemy: Dictionary=targets[int(flight.pulse)%targets.size()]
				notice.x=enemy.x;notice.y=enemy.get("y",480)
				notice.targets.append(_hit(enemy,flight,float(spec.coefficient)))
				var used: Array=[enemy.id]
				var origin: Vector2=Vector2(enemy.x,enemy.get("y",480))
				for _chain: int in range(int(spec.chain_count)):
					var chain: Array=combat.near_at(origin,float(spec.chain_radius),999).filter(func(e:Dictionary)->bool:return e.id not in used and float(e.x)>=combat.BASE_X)
					if chain.is_empty(): break
					var next: Dictionary=chain[0];used.append(next.id)
					var hit: Dictionary=_hit(next,flight,float(spec.chain_coefficient));hit.from_x=origin.x;hit.from_y=origin.y;hit.chain=true
					notice.targets.append(hit);origin=Vector2(next.x,next.get("y",480))
		"C04","C05":
			if flight.cat=="C05" and flight.has("target"):
				targets=targets.filter(func(e:Dictionary)->bool:return int(e.id)==int(flight.target))
			for enemy: Dictionary in targets:
				var hit: Dictionary=_hit(enemy,flight,float(spec.coefficient))
				if not bool(enemy.dead):
					if flight.cat=="C04" or enemy.boss:
						var duration: float=float(spec.boss_stun) if enemy.boss else float(spec.elite_stun if enemy.elite else spec.stun)
						_apply_stun(enemy,duration,str(flight.cat));hit.stun=duration
					else:
						var before_x: float=enemy.x
						var reachable: float=combat.BASE_X
						for cat: Dictionary in b.cats: reachable=maxf(reachable,combat.BASE_X+float(cat.range))
						var cap: float=minf(combat.VISIBLE_RIGHT-36.0,reachable-24.0)
						enemy.x=maxf(before_x,minf(cap,before_x+float(spec.elite_push if enemy.elite else spec.push)))
						enemy.contact=false;enemy.knock_cd=.5
						hit.from_x=before_x;hit.to_x=enemy.x;hit.push=float(enemy.x)-before_x
						Ledger.support(run,str(flight.cat),"knockback_distance",hit.push)
				notice.targets.append(hit)
		"C06":
			notice.cleansed=[];notice.allies=[];notice.shield=float(flight.attack)*float(spec.shield_coefficient);notice.buff_duration=spec.buff_duration
			for cat: Dictionary in b.cats:
				if float(cat.get("web_left",0))>0 or float(cat.get("confuse_left",0))>0:
					notice.cleansed.append(cat.id);Ledger.debuff_ended(run,str(cat.id))
					Ledger.support(run,str(flight.cat),"cleanses",1)
					var pos: Vector2=combat.cat_origin(cat.id)
					run.events.append({"type":"cat_cleanse","cat":cat.id,"to_cat":cat.id,"source_skill":"sanctuary","x":pos.x,"y":pos.y,"duration":.65})
				cat.web_left=0.0;cat.web_slow=0.0;cat.confuse_left=0.0;cat.confuse_strength=0.0
				_set_buff(cat,"skill_chorus_left",float(spec.buff_duration));notice.allies.append(cat.id)
				if cat.id=="C06": cat.skills.active_left=spec.buff_duration
			b.shields.append({"amount":notice.shield,"left":spec.shield_duration,"source":flight.cat,"source_fish":"","active_skill":true})
			Ledger.support(run,str(flight.cat),"shield_added",float(notice.shield))
			run.events.append({"type":"shield","cat":flight.cat,"source_skill":"sanctuary","x":combat.BASE_X,"amount":notice.shield})
	if cinematic_busy():
		notice.cinematic_age=float(b.cinematic.age)
		b.cinematic.impact_history.append(notice.duplicate(true))
	run.events.append(notice)

func _hit(enemy: Dictionary,flight: Dictionary,coefficient: float) -> Dictionary:
	var point: Vector2=Vector2(enemy.x,enemy.get("y",480))
	var amount: float=combat.fx.damage(enemy,float(flight.attack)*coefficient,str(flight.cat),"active_"+str(flight.skill_id),0,{"terminal":true,"source_skill":flight.skill_id,"visual_kind":"skill","from_x":flight.from_x,"from_y":flight.from_y,"cast_id":flight.cast_id})
	return {"id":enemy.id,"x":point.x,"y":point.y,"damage":amount,"kind":enemy.kind,"boss":enemy.boss,"stun":0.0,"from_x":point.x,"to_x":point.x}

func _apply_stun(enemy: Dictionary,duration: float,cat_id: String) -> void:
	# A once-per-battle control release may refresh an ordinary stun; its tier
	# durations are already resistance-adjusted and must not be scaled twice.
	enemy.stun=maxf(float(enemy.get("stun",0)),duration)
	enemy.feedback_stun_source=cat_id
	Ledger.support(run,cat_id,"stuns",1)
	run.events.append({"type":"stun","target":enemy.id,"x":enemy.x,"y":enemy.get("y",480),"cat":cat_id,"duration":duration,"amount":duration,"enemy_kind":enemy.kind,"source_skill":Catalog.DEFINITIONS[cat_id].id})
