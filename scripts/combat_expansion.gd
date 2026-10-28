extends RefCounted
## v0.3 encounter skills and finite toy procs. Terminal damage never spawns carriers.
const Data = preload("res://scripts/catalog.gd")
const Positions = preload("res://scripts/cat_combat_positions.gd")
const Feedback = preload("res://scripts/feedback_tuning.gd")
const Ledger = preload("res://scripts/feedback_ledger.gd")
const Difficulty = preload("res://scripts/difficulty_rules.gd")
var _combat: WeakRef
var _toy_hash: int=-1
var _toy_cache: Dictionary={}
var combat: RefCounted:
	get: return _combat.get_ref()
var run: RefCounted:
	get: return combat.run
var b: Dictionary:
	get: return combat.b
func setup(value: RefCounted) -> void: _combat=weakref(value)
func toys() -> Dictionary:
	var fingerprint: int=hash([run.s.get("toys",{}),int(run.s.get("hq",1))])
	if fingerprint!=_toy_hash:
		_toy_hash=fingerprint;_toy_cache=Data.toy_effects(run.s.get("toys",{}))
		var power: float=Difficulty.independent_power(int(run.s.get("hq",1)))
		_toy_cache.meteor_damage=float(_toy_cache.get("meteor_damage",0))*power
		_toy_cache.laser_damage=float(_toy_cache.get("laser_damage",0))*power
		_toy_cache.cannon_damage=float(_toy_cache.get("cannon_damage",0))*power
		_toy_cache.independent_power=power
	return _toy_cache
func initialize_cat(cat: Dictionary) -> void:
	for key: String in ["web_left","web_slow","confuse_left"]:
		if not cat.has(key): cat[key]=0.0
	for pair: Array in [["web_left","web_duration"],["confuse_left","confuse_duration"]]:
		if not cat.has(pair[1]): cat[pair[1]]=maxf(.01,float(cat.get(pair[0],0)))
	if not cat.has("toy_echo_armed"): cat.toy_echo_armed=false
	if not cat.has("toy_echo_cooldown"): cat.toy_echo_cooldown=0.0
	cat.toys=toys()
func tick(delta: float) -> void:
	if delta<=0 or not _reactive_active(): return
	var ledger: Dictionary=Ledger.ensure(run)
	ledger.peak_enemies=maxi(int(ledger.get("peak_enemies",0)),combat.enemies().size())
	for marked: Dictionary in b.enemies:
		if bool(marked.get("counter_mark",false)):
			var owner: Dictionary=combat.get_enemy(int(marked.get("counter_owner",-1)))
			if owner.is_empty() or bool(owner.get("dead",false)):
				marked.counter_mark=false;marked.counter_owner=-1
	independent_toys(delta)
	var config: Dictionary=toys()
	for cat: Dictionary in b.cats:
		initialize_cat(cat)
		if float(cat.get("buff_left",0))>0:
			var covered: float=minf(delta,float(cat.buff_left))
			var teammate: bool=str(cat.get("buff_source",""))=="C06" and str(cat.id)!="C06"
			Ledger.support(run,"C06","benefit_seconds" if teammate else "self_buff_seconds",covered)
			if str(cat.get("buff_toy",""))=="T12": Ledger.support(run,"T12","benefit_seconds",covered)
		for key: String in ["web_left","confuse_left"]: cat[key]=maxf(0.0,float(cat[key])-delta)
		if float(cat.web_left)<=0: cat.web_slow=0.0
		if float(cat.confuse_left)<=0: cat.confuse_strength=0.0
	tick_debuff_flights(delta)
	for pair: Array in [["cleanse_interval","toy_cleanse_left"],["heal_interval","toy_heal_left"]]:
		var interval: float=float(config.get(pair[0],0))
		if interval<=0: continue
		b[pair[1]]=float(b.get(pair[1],interval))-delta
		if float(b[pair[1]])>0: continue
		b[pair[1]]=interval
		if pair[0]=="cleanse_interval":
			for cat: Dictionary in b.cats:
				if float(cat.web_left)>0 or float(cat.confuse_left)>0:
					var before: Dictionary=Ledger.snapshot(run)
					var states: Array=[]
					if float(cat.web_left)>0: states.append("web")
					if float(cat.confuse_left)>0: states.append("confusion")
					cat.web_left=0.0;cat.web_slow=0.0;cat.confuse_left=0.0
					Ledger.debuff_ended(run,cat.id)
					Ledger.toy(run,"T06","cleanses",states.size(),{"cat":cat.id,"states":states,"x":Positions.FEET[clampi(run.s.active.find(cat.id),0,4)].x,"y":Positions.FEET[clampi(run.s.active.find(cat.id),0,4)].y-42})
					for state: String in states: Ledger.support(run,"T06","cleansed_"+state,1)
					Ledger.highlight(run,"cleanse","T06",before,80+states.size(),{"cat":cat.id,"target_count":1,"states":states})
					run.events.append({"type":"cat_cleanse","cat":cat.id,"to_cat":cat.id,"toy":"T06","duration":.4})
		else:
			var amount: float=minf(float(config.get("heal_amount",0)),float(run.s.max_hp)-float(run.s.hp))
			run.s.hp+=amount
			if amount>0:
				Ledger.healed(run,amount)
				Ledger.toy(run,"T11","healed_hp",amount,{"x":combat.BASE_X,"y":370.0})
				run.events.append({"type":"toy_heal","x":combat.BASE_X,"y":370.0,"amount":amount,"toy":"T11"})
func tick_enemy(enemy: Dictionary, delta: float) -> void:
	if enemy.dead or delta<=0: return
	enemy.rally_left=maxf(0.0,float(enemy.get("rally_left",0))-delta)
	var skill: String=str(enemy.get("skill",""))
	if skill=="" or str(enemy.get("rank","small"))=="small": return
	if bool(enemy.get("boss",false)):
		if not combat.BossRules.visible(enemy): return
		_tick_boss_skill(enemy,delta)
		return
	if float(enemy.get("skill_windup",0))>0:
		enemy.skill_windup=maxf(0.0,float(enemy.skill_windup)-delta)
		if float(enemy.skill_windup)<=0:
			cast_skill(enemy)
			enemy.skill_left=float(enemy.get("skill_cd",10))
		return
	enemy.skill_left=float(enemy.get("skill_left",enemy.get("skill_start",5)))-delta
	if float(enemy.skill_left)>0 or float(enemy.x)>combat.VISIBLE_RIGHT: return
	enemy.skill_windup=float(enemy.get("skill_telegraph",.8))
	run.events.append({"type":"enemy_skill_warning","target":enemy.id,"kind":enemy.kind,"skill":skill,"x":enemy.x,"y":enemy.y,"duration":enemy.skill_windup})
func on_damage(enemy: Dictionary, amount: float) -> void:
	var state: Dictionary=enemy.get("counter_state",{})
	if state.is_empty(): return
	if str(state.kind)=="damage": state.damage=float(state.get("damage",0))+maxf(0.0,amount)
	if bool(enemy.get("dead",false)) or float(enemy.get("hp",0))<=0:
		_clear_counter_marks(enemy)
		enemy.counter_state={}

func _tick_boss_skill(enemy: Dictionary, delta: float) -> void:
	var state: Dictionary=enemy.get("counter_state",{})
	if not state.is_empty():
		var success: bool=false
		if str(state.kind)=="damage": success=float(state.damage)>=float(state.threshold)
		else:
			var defeated: int=0
			for id: int in state.targets:
				var target: Dictionary=combat.get_enemy(id)
				if target.is_empty() or bool(target.get("dead",false)) or float(target.get("hp",0))<=0: defeated+=1
			success=defeated>=int(state.required)
		if success:
			_finish_counter(enemy,true)
			return
		state.left=maxf(0,float(state.left)-delta)
		enemy.skill_windup=state.left
		if float(state.left)<=0: _finish_counter(enemy,false)
		return
	enemy.skill_left=maxf(0,float(enemy.get("skill_left",2.4))-delta)
	if float(enemy.skill_left)>0 or float(enemy.x)>combat.VISIBLE_RIGHT: return
	var spec: Dictionary=_counter_spec(str(enemy.kind))
	var targets: Array=[]
	if str(spec.kind)=="guard":
		var choices: Array=combat.enemies().filter(func(e:Dictionary)->bool:
			if bool(e.get("boss",false)): return false
			if str(enemy.kind)=="B01" and (str(e.kind)!="E03" or not bool(e.get("authored_spawn",false)) and int(e.get("boss_reinforcement_owner",-1))!=int(enemy.id)): return false
			return _any_cat_can_target(e))
		choices.sort_custom(func(a:Dictionary,c:Dictionary)->bool:
			if str(enemy.kind)=="B03" and (str(a.kind)=="E07")!=(str(c.kind)=="E07"): return str(a.kind)=="E07"
			return float(a.x)<float(c.x))
		for target: Dictionary in choices.slice(0,mini(int(spec.maximum),choices.size())):
			targets.append(int(target.id))
		if targets.is_empty(): return
	elif not _any_cat_can_target(enemy): return
	var duration: float=float(spec.duration)*float(Difficulty.profile(str(run.s.get("difficulty","easy"))).counter_window)
	enemy.counter_state={"kind":spec.kind,"left":duration,"total":duration,"targets":targets,"required":mini(int(spec.get("required",1)),targets.size()),"damage":0.0,"threshold":float(enemy.max_hp)*float(spec.get("damage_ratio",0)),"label":spec.label}
	enemy.skill_windup=duration
	for id: int in targets:
		var target: Dictionary=combat.get_enemy(id)
		target.counter_mark=true;target.counter_owner=int(enemy.id)
	run.events.append({"type":"boss_counter_warning","target":enemy.id,"kind":enemy.kind,"x":enemy.x,"y":enemy.y,"label":spec.label,"duration":duration,"targets":targets.duplicate()})

func _any_cat_can_target(enemy: Dictionary) -> bool:
	for cat: Dictionary in b.cats:
		if combat.can_target(cat,enemy): return true
	return false

func _counter_spec(kind: String) -> Dictionary:
	return {
		"B01":{"kind":"guard","maximum":2,"required":1,"duration":3.4,"label":"打倒护卫 · 折旗"},
		"B02":{"kind":"damage","duration":3.6,"damage_ratio":.025,"label":"集中攻击 · 堵住吸口"},
		"B03":{"kind":"guard","maximum":3,"required":2,"duration":4.0,"label":"打翻两份晚餐"},
		"B04":{"kind":"damage","duration":3.6,"damage_ratio":.025,"label":"集中攻击 · 切断直播"},
		"B05":{"kind":"guard","maximum":3,"required":2,"duration":4.0,"label":"打倒两只 · 卡住滚筒"}
	}.get(kind,{"kind":"damage","duration":3.6,"damage_ratio":.025,"label":"集中攻击"})

func _clear_counter_marks(enemy: Dictionary) -> void:
	for marked: Dictionary in b.enemies:
		if int(marked.get("counter_owner",-1))==int(enemy.id):
			marked.counter_mark=false;marked.counter_owner=-1

func _finish_counter(enemy: Dictionary, success: bool) -> void:
	var state: Dictionary=enemy.get("counter_state",{})
	if state.is_empty() or bool(enemy.get("dead",false)): return
	var notice: Dictionary={"type":"boss_counter_success" if success else "boss_counter_failure","target":enemy.id,"kind":enemy.kind,"x":enemy.x,"y":enemy.y,"label":"破解成功" if success else "技能发动","duration":.85,"targets":state.targets.duplicate()}
	_clear_counter_marks(enemy)
	enemy.counter_state={};enemy.skill_windup=0.0
	enemy.skill_left=float(enemy.get("skill_cd",12))
	if success:
		enemy.counter_stagger=.65
		enemy.special_windup=0.0;enemy.windup=0.0;enemy.second_bite=-1.0
		enemy.special_left=maxf(3.0,float(enemy.get("special_left",0)))
		notice.label={"B01":"折旗！","B02":"吸口堵住了！","B03":"晚餐打翻！","B04":"断播！","B05":"滚筒卡住！"}.get(str(enemy.kind),"破解成功")
		Ledger.support(run,"counter_"+str(enemy.kind),"success",1)
	else:
		cast_skill(enemy)
		Ledger.support(run,"counter_"+str(enemy.kind),"failure",1)
	run.events.append(notice)

func cast_skill(enemy: Dictionary) -> void:
	if enemy.is_empty() or bool(enemy.get("dead",false)) or float(enemy.get("hp",0))<=0: return
	var skill: String=str(enemy.get("skill",""))
	var duration: float=float(enemy.get("skill_duration",3))
	var strength: float=float(enemy.get("skill_strength",.3))
	var count: int=clampi(int(enemy.get("skill_targets",1)),1,12)
	var targets: Array=b.cats.duplicate()
	if skill in ["web","confusion"]:
		for _i: int in range(mini(count,targets.size())):
			var cat: Dictionary=targets.pop_at(run.rand_index("combat",targets.size()))
			initialize_cat(cat)
			var slot: int=run.s.active.find(cat.id)
			var point: Vector2=Positions.FEET[clampi(slot,0,4)]+Vector2(0,-42)
			var source: Vector2=combat.BossRules.cast_point(str(enemy.kind)) if bool(enemy.get("boss_fixed",false)) else Vector2(float(enemy.x),float(enemy.y))
			var flight_duration: float=Feedback.debuff_flight(source.distance_to(point))
			var flight: Dictionary={"kind":skill,"cat":cat.id,"enemy_kind":enemy.kind,"enemy":enemy.id,"from_x":source.x,"from_y":source.y,"to_x":point.x,"to_y":point.y,"left":flight_duration,"duration":flight_duration,"effect_duration":duration,"strength":strength}
			if not b.has("debuff_projectiles"): b.debuff_projectiles=[]
			b.debuff_projectiles.append(flight)
			var notice: Dictionary=flight.duplicate(true)
			notice.merge({"type":"enemy_debuff_cast","to_cat":cat.id,"x":source.x,"y":source.y},true)
			run.events.append(notice)
	elif skill=="rally":
		for ally: Dictionary in combat.near_at(Vector2(enemy.x,enemy.y),260,count):
			ally.rally_left=duration;ally.rally_strength=clampf(strength,0,.6)
	elif skill=="summon":
		# Each caller owns a finite lifetime summon allowance; summoned enemies pay zero gold.
		var remaining: int=maxi(0,12-int(enemy.get("summoned",0)))
		var amount: int=mini(count,remaining)
		for i: int in range(amount): combat.spawn("E07",combat.BossRules.summon_x(i) if bool(enemy.get("boss_fixed",false)) else minf(1260,float(enemy.x)+45+i*22),true)
		enemy.summoned=int(enemy.get("summoned",0))+amount
	run.events.append({"type":"enemy_skill","skill":skill,"kind":enemy.kind,"target":enemy.id,"x":enemy.x,"y":enemy.y,"duration":duration,"amount":strength})
func tick_debuff_flights(delta: float) -> void:
	# Stored entirely in battle: pause freezes it, 2x uses simulation time, and
	# loading mid-flight resumes the same trajectory without re-rolling a target.
	var flights: Array=b.get("debuff_projectiles",[])
	b.debuff_projectiles=[]
	for flight: Dictionary in flights:
		# Old saves may retain a web after the Boss entity was removed. Ordinary
		# enemy carriers retain their existing rules; Boss death cancels its casts.
		if str(flight.get("enemy_kind","")).begins_with("B"):
			var source: Dictionary=combat.get_enemy(int(flight.get("enemy",-1)))
			if source.is_empty() or bool(source.get("dead",false)) or float(source.get("hp",0))<=0: continue
		flight.left=maxf(0.0,float(flight.left)-delta)
		if float(flight.left)>.000001:
			b.debuff_projectiles.append(flight)
			continue
		var cat: Dictionary=combat.get_cat(str(flight.cat))
		if cat.is_empty(): continue
		initialize_cat(cat)
		var duration: float=float(flight.effect_duration)
		var strength: float=float(flight.strength)
		if str(flight.kind)=="web":
			cat.web_left=maxf(float(cat.web_left),duration)
			cat.web_duration=maxf(float(cat.web_left),duration)
			cat.web_slow=maxf(float(cat.web_slow),clampf(strength,.05,.65))
		else:
			cat.confuse_left=maxf(float(cat.confuse_left),duration)
			cat.confuse_duration=maxf(float(cat.confuse_left),duration)
			cat.confuse_strength=maxf(float(cat.get("confuse_strength",0)),strength)
		var hit: Dictionary=flight.duplicate(true)
		hit.merge({"type":"cat_debuff","skill":flight.kind,"to_cat":cat.id,"target":flight.enemy,"x":flight.to_x,"y":flight.to_y,"duration":Feedback.number("debuff","impact_duration",.42),"status_duration":duration,"amount":strength},true)
		Ledger.debuff(run,hit)
		run.events.append(hit)

func impact(cat: Dictionary, enemy: Dictionary, ctx: Dictionary, payload: Dictionary, scale: float, first: bool) -> void:
	var config: Dictionary=payload.get("toys",{})
	var fish: Dictionary=payload.fish
	var power: float=float(payload.base_attack)*scale
	var meta: Dictionary={"from_x":enemy.x,"from_y":enemy.y,"y":enemy.y,"to_y":enemy.y,"base_attack":float(payload.base_attack),"terminal":true,"attack":ctx.id,"visual_kind":"area"}
	var explosion: float=float(config.get("explosion_ratio",0))
	if explosion>0:
		Ledger.toy(run,"T04","explosions",1,{"cat":cat.id,"target":enemy.id,"x":enemy.x,"y":enemy.y,"radius":config.get("explosion_radius",90)})
		combat.fx.impact_area(cat,enemy.x,float(config.get("explosion_radius",90)),6,explosion*scale,"toy_explosion",meta)
	var cloud: Dictionary=fish.get("F09",{})
	if bool(enemy.get("air",false)) and float(cloud.get("splash_ratio",0))>0:
		combat.fx.impact_area(cat,enemy.x,float(cloud.get("splash_radius",110)),5,float(cloud.splash_ratio)*scale,"cloud_burst",meta)
	if not enemy.dead:
		combat.fx.knockback(enemy,float(config.get("knockback",0)),"T02")
		combat.fx.apply_slow(enemy,float(config.get("slow_pct",0)),float(config.get("slow_duration",0)),cat.id,"T09")
		var every: int=int(config.get("freeze_every",0))
		if every>0 and int(ctx.count)%every==0: combat.fx.apply_freeze(enemy,float(config.get("freeze_duration",.6)),cat.id,"T07")
		var ink: Dictionary=fish.get("F10",{})
		var mark: float=maxf(float(ink.get("mark_pct",0)),float(config.get("mark_pct",0)))
		if mark>0:
			enemy.ink_mark={"pct":minf(.6,mark),"left":float(ink.get("mark_duration",3)),"cat":cat.id,"power":float(payload.base_attack),"burst":float(ink.get("mark_burst",0)),"radius":float(ink.get("mark_radius",110))}
			combat.fx._status_event(enemy,"ink_mark",cat.id,"F10",mark,float(enemy.ink_mark.left))
	var bleed: float=float(config.get("bleed_dps",0))
	if bleed>0 and not enemy.dead:
		enemy.toy_bleed={"left":float(config.get("bleed_duration",2)),"dps":bleed,"cat":cat.id,"tick":0.0}
		Ledger.unique_target(run,"T18","covered_targets",int(enemy.id))
		Ledger.toy(run,"T18","applications",1,{"cat":cat.id,"target":enemy.id,"x":enemy.x,"y":enemy.y})
	var extra_chain: int=clampi(int(config.get("chain_extra",0)),0,4)
	var last: Dictionary=enemy
	var used: Array=[enemy.id]
	for _i: int in range(extra_chain):
		var nexts: Array=combat.near_at(Vector2(last.x,last.y),190,999).filter(func(e: Dictionary)->bool:return e.id not in used)
		if nexts.is_empty(): break
		var next: Dictionary=nexts[0];used.append(next.id)
		var chain_meta: Dictionary={"from_x":last.x,"from_y":last.y,"to_x":next.x,"to_y":next.y,"y":next.y,"terminal":true,"visual_kind":"chain","toy":"T05","attack":ctx.id}
		run.events.append({"type":"chain","cat":cat.id,"kind":"toy_chain","target":next.id,"x":last.x,"from_x":last.x,"from_y":last.y,"to_x":next.x,"to_y":next.y,"terminal":true,"toy":"T05","source_toy":"T05"})
		Ledger.toy(run,"T05","chain_hits",1,{"cat":cat.id,"target":next.id,"x":next.x,"y":next.y,"from_x":last.x,"from_y":last.y})
		combat.fx.damage(next,power*float(config.get("chain_ratio",.35)),cat.id,"toy_chain",0,chain_meta)
		last=next
	if first:
		var bounced: Array=combat.near_at(Vector2(enemy.x,enemy.y),240,int(config.get("bounce_extra",0)),enemy.id)
		for i: int in range(bounced.size()):
			combat.queue_hit(cat,bounced[i],ctx.id,true,float(config.get("bounce_ratio",.55)),.15+i*.08,0,"bounce",i,{"origin_x":enemy.x,"origin_y":enemy.y,"fish":"T03","source_toy":"T03","source_fish":"","carrier_origin":"toy_bounce","ignore_confusion":true})

func independent_toys(delta: float) -> void:
	if delta<=0 or not _reactive_active(): return
	_tick_shield_cannon(delta)
	var config: Dictionary=toys()
	var timers: Array=[["blackhole_interval","blackhole"],["meteor_interval","meteor"],["base_shield_interval","base_shield"],["laser_interval","laser"],["decoy_interval","decoy"]]
	b.toy_combo_cooldown=maxf(0.0,float(b.get("toy_combo_cooldown",0))-delta)
	for pair: Array in timers:
		var interval: float=float(config.get(pair[0],0))
		if interval<=0: continue
		var key: String="toy_timer_"+str(pair[1])
		b[key]=float(b.get(key,interval))-delta
		if float(b[key])>0: continue
		# Combat timers count game seconds. No targets preserves a ready shot.
		var available: Array=combat.enemies().filter(func(e:Dictionary)->bool:return combat.BossRules.visible(e) and float(e.x)<=combat.VISIBLE_RIGHT)
		if pair[1]!="base_shield" and available.is_empty(): b[key]=0.0;continue
		b[key]=interval
		var target: Dictionary={} if available.is_empty() else available[run.rand_index("combat",available.size())]
		var point: Vector2=Vector2(350,350) if target.is_empty() else Vector2(target.x,target.y)
		var cast: Dictionary={"type":"toy_cast","kind":pair[1],"x":point.x,"y":point.y,"to_x":point.x,"to_y":point.y,"from_x":point.x-80,"from_y":70.0,"duration":.55,"radius":float(config.get("meteor_radius",100))}
		match str(pair[1]):
			"meteor":
				cast.toy="T13"
				if not b.has("toy_pending"): b.toy_pending=[]
				b.toy_pending.append({"left":.55,"x":point.x,"y":point.y,"damage":float(config.get("meteor_damage",110)),"combo":false,"radius":float(config.get("meteor_radius",100)),"feedback_before":Ledger.snapshot(run)})
				Ledger.toy(run,"T13","casts",1,{"x":point.x,"y":point.y})
			"base_shield":
				cast.toy="T14";cast.radius=140.0;cast.duration=.5
				var existing: float=0.0
				for shield: Dictionary in b.shields:
					if str(shield.source)=="T14": existing+=float(shield.amount);shield.left=interval+1
				var amount: float=minf(float(config.get("base_shield_amount",12)),maxf(0,float(config.get("base_shield_max",60))-existing))
				if amount>0:
					b.shields.append({"amount":amount,"left":interval+1,"source":"T14"})
					Ledger.toy(run,"T14","shield_added",amount,{"x":350.0,"y":350.0})
			"laser":
				cast.toy="T16";cast.from_x=350.0;cast.from_y=point.y;cast.to_x=1280.0;cast.duration=.30
				var before: Dictionary=Ledger.snapshot(run)
				var before_damage: float=float(Ledger.ensure(run).total_damage)
				var hits: Array=available.filter(func(e:Dictionary)->bool:return absf(float(e.y)-point.y)<70.0)
				for enemy: Dictionary in hits.slice(0,mini(int(config.get("laser_targets",8)),hits.size())):
					combat.fx.damage(enemy,float(config.get("laser_damage",65)),"T16","toy_laser",0,{"terminal":true,"toy":"T16","from_x":350.0,"from_y":point.y,"to_y":enemy.y})
				var count: int=mini(int(config.get("laser_targets",8)),hits.size())
				Ledger.toy(run,"T16","casts",1,{"x":350.0,"y":point.y,"target_count":count})
				Ledger.highlight(run,"laser","T16",before,count*10.0,{"x":350.0,"y":point.y,"target_count":count,"damage":float(Ledger.ensure(run).total_damage)-before_damage})
			"blackhole":
				cast.toy="T19";cast.duration=.8;cast.radius=float(config.get("blackhole_radius",180))
				var captured: int=0
				for enemy: Dictionary in combat.near_at(point,float(cast.radius),int(config.get("blackhole_targets",6))):
					if enemy.boss: continue
					captured+=1
					var previous_x: float=float(enemy.x)
					enemy.x=move_toward(float(enemy.x),point.x,float(config.get("blackhole_pull",90)))
					if not is_equal_approx(previous_x,float(enemy.x)):
						Ledger.toy(run,"T19","pulls",1,{"target":enemy.id,"x":point.x,"y":point.y,"from_x":previous_x,"to_x":enemy.x})
						Ledger.unique_target(run,"T19","pulled_targets",int(enemy.id))
						Ledger.support(run,"T19","pull_distance",absf(float(enemy.x)-previous_x))
					enemy.contact=false
					combat.fx.apply_slow(enemy,.35,.8,"T19","T19")
				if captured>=3 and float(config.get("meteor_interval",0))>0 and float(b.toy_combo_cooldown)<=0:
					_queue_blackhole_meteor(point,config,captured)
			"decoy":
				cast.toy="T20";cast.duration=float(config.get("decoy_duration",3));cast.radius=160
				for enemy: Dictionary in combat.near_at(point,220,int(config.get("decoy_targets",4))):
					enemy.taunt_left=float(cast.duration)*(.5 if enemy.boss else (.7 if enemy.elite else 1.0))
					enemy.taunt_x=point.x
					Ledger.toy(run,"T20","taunts",1,{"target":enemy.id,"x":enemy.x,"y":enemy.y,"duration":enemy.taunt_left})
					Ledger.unique_target(run,"T20","affected_targets",int(enemy.id))
		cast.source_toy=cast.get("toy","")
		run.events.append(cast)
	var pending: Array=b.get("toy_pending",[])
	b.toy_pending=[]
	for meteor: Dictionary in pending:
		meteor.left-=delta
		if float(meteor.left)>0: b.toy_pending.append(meteor);continue
		var targets: Array=combat.near_at(Vector2(meteor.x,meteor.y),float(meteor.radius),8)
		var before_damage: float=float(Ledger.ensure(run).total_damage)
		run.events.append({"type":"burst","kind":"meteor","toy":"T13","x":meteor.x,"y":meteor.y,"radius":meteor.radius,"terminal":true})
		for enemy: Dictionary in targets:
			combat.fx.damage(enemy,float(meteor.damage),"T13","toy_meteor",0,{"terminal":true,"toy":"T13","from_x":meteor.x,"from_y":70.0,"to_y":enemy.y})
		Ledger.support(run,"T13","impact_hits",targets.size())
		if targets.is_empty(): Ledger.support(run,"T13","misses",1)
		Ledger.highlight(run,"meteor","T13",meteor.get("feedback_before",Ledger.snapshot(run)),targets.size()*12.0,{"x":meteor.x,"y":meteor.y,"target_count":targets.size(),"damage":float(Ledger.ensure(run).total_damage)-before_damage})

func _queue_blackhole_meteor(point: Vector2, config: Dictionary, captured: int) -> void:
	# One shared meteor launch slot. An in-flight natural shot is redirected,
	# never duplicated; otherwise this consumes the next scheduled natural shot.
	var pending: Array=b.get("toy_pending",[])
	var reused: bool=not pending.is_empty()
	var meteor: Dictionary=pending[0] if reused else {"feedback_before":Ledger.snapshot(run)}
	meteor.merge({"left":1.0,"x":point.x,"y":point.y,"damage":float(config.get("meteor_damage",110)),"radius":float(config.get("meteor_radius",100)),"combo":true},true)
	b.toy_pending=[meteor]
	b.toy_timer_meteor=float(config.get("meteor_interval",9))
	b.toy_combo_cooldown=12.0
	if not reused: Ledger.toy(run,"T13","casts",1,{"x":point.x,"y":point.y})
	Ledger.support(run,"T19","meteor_combos",1)
	run.events.append({"type":"toy_combo","toy":"T13","source_toy":"T19","kind":"blackhole_meteor","x":point.x,"y":point.y,"to_x":point.x,"to_y":point.y,"from_x":point.x-80,"from_y":70.0,"duration":1.0,"radius":meteor.radius,"targets":captured,"replaces_pending":reused,"label":"吸住，再砸！"})

func _reactive_active() -> bool:
	return not b.is_empty() and float(run.s.get("hp",0))>0 and not bool(run.s.get("paused",false)) and str(run.s.get("phase","")) in ["combat","cleanup"]

func clear_reactive_toys() -> void:
	if b.is_empty(): return
	b.toy_cannon_charge=0.0
	b.toy_cannon_cooldown=0.0
	b.toy_cannon_pending=[]
	for cat: Dictionary in b.get("cats",[]):
		cat.toy_echo_armed=false
		cat.toy_echo_cooldown=0.0
	# A saved terminal echo cannot survive a stage boundary or revive a receipt.
	b.projectiles=b.get("projectiles",[]).filter(func(p:Dictionary)->bool:return str(p.get("source_toy",""))!="T22")

func _tick_shield_cannon(delta: float) -> void:
	var config: Dictionary=toys()
	var absorbed: float=float(Ledger.ensure(run).base.get("shield_absorbed",0))
	var gained: float=maxf(0.0,absorbed-float(b.get("toy_cannon_observed_absorbed",0)))
	b.toy_cannon_observed_absorbed=absorbed
	var threshold: float=float(config.get("cannon_threshold",0))
	if threshold<=0: return
	b.toy_cannon_cooldown=maxf(0.0,float(b.get("toy_cannon_cooldown",0))-delta)
	var charge_before: float=float(b.get("toy_cannon_charge",0))
	b.toy_cannon_charge=minf(threshold,charge_before+gained)
	var charged: float=float(b.toy_cannon_charge)-charge_before
	if charged>0:
		Ledger.support(run,"T21","charge_received",charged)
		run.events.append({"type":"toy_charge","toy":"T21","source_toy":"T21","amount":charged,"charge":b.toy_cannon_charge,"threshold":threshold,"x":350.0,"y":350.0})
	# Existing flights resolve first. A new shot always retains its visible travel.
	var pending: Array=b.get("toy_cannon_pending",[])
	b.toy_cannon_pending=[]
	for shell: Dictionary in pending:
		shell.left-=delta
		if float(shell.left)>0:
			b.toy_cannon_pending.append(shell)
			continue
		var targets: Array=combat.near_at(Vector2(shell.x,shell.y),float(shell.radius),int(shell.targets))
		var damage_before: float=float(Ledger.ensure(run).total_damage)
		run.events.append({"type":"burst","kind":"shield_cannon","toy":"T21","source_toy":"T21","x":shell.x,"y":shell.y,"radius":shell.radius,"terminal":true})
		for target: Dictionary in targets:
			combat.fx.damage(target,float(shell.damage),"T21","toy_cannon",0,{"terminal":true,"toy":"T21","source_toy":"T21","from_x":350.0,"from_y":350.0,"to_y":target.y})
		Ledger.support(run,"T21","impact_hits",targets.size())
		if targets.is_empty(): Ledger.support(run,"T21","misses",1)
		Ledger.highlight(run,"shield_cannon","T21",shell.feedback_before,targets.size()*10.0,{"x":shell.x,"y":shell.y,"target_count":targets.size(),"damage":float(Ledger.ensure(run).total_damage)-damage_before})
	if float(b.toy_cannon_charge)<threshold or float(b.toy_cannon_cooldown)>0: return
	var available: Array=combat.enemies().filter(func(e:Dictionary)->bool:return combat.BossRules.visible(e) and float(e.x)<=combat.VISIBLE_RIGHT)
	if available.is_empty(): return
	available.sort_custom(func(a:Dictionary,c:Dictionary)->bool:return float(a.x)<float(c.x))
	var target: Dictionary=available[0]
	b.toy_cannon_charge=0.0
	b.toy_cannon_cooldown=float(config.cannon_cooldown)
	b.toy_cannon_pending.append({"left":.35,"x":target.x,"y":target.y,"damage":float(config.cannon_damage),"radius":float(config.cannon_radius),"targets":int(config.cannon_targets),"feedback_before":Ledger.snapshot(run)})
	Ledger.toy(run,"T21","casts",1,{"x":350.0,"y":350.0,"target":target.id,"charge_spent":threshold})
	run.events.append({"type":"toy_cast","kind":"shield_cannon","toy":"T21","source_toy":"T21","x":target.x,"y":target.y,"from_x":350.0,"from_y":350.0,"to_x":target.x,"to_y":target.y,"target":target.id,"radius":float(config.cannon_radius),"duration":.35,"charge_spent":threshold,"threshold":threshold,"cooldown":float(config.cannon_cooldown)})

func arm_support_echo(cat: Dictionary,from_cat: String) -> void:
	if not _reactive_active() or from_cat!="C06" or str(cat.id)==from_cat: return
	if float(toys().get("support_echo_ratio",0))<=0 or float(cat.get("toy_echo_cooldown",0))>0: return
	cat.toy_echo_armed=true
	Ledger.support(run,"T22","armed_returns",1)
	run.events.append({"type":"toy_armed","kind":"bell_echo","toy":"T22","source_toy":"T22","cat":cat.id,"to_cat":cat.id,"from_cat":from_cat})

func fire_support_echo(cat: Dictionary,target: Dictionary,attack_id: int) -> void:
	if not _reactive_active() or not bool(cat.get("toy_echo_armed",false)) or float(cat.get("buff_left",0))<=0 or float(cat.get("toy_echo_cooldown",0))>0: return
	var config: Dictionary=toys()
	var ratio: float=float(config.get("support_echo_ratio",0))
	if ratio<=0: return
	cat.toy_echo_armed=false
	cat.toy_echo_cooldown=float(config.support_echo_cooldown)
	combat.queue_hit(cat,target,attack_id,false,ratio,.22,0,"toy_echo",0,{"source_toy":"T22","source_fish":"","carrier_origin":"T22","fish":""})
	var origin: Vector2=combat.cat_origin(cat.id)
	var flight: Dictionary=b.projectiles[-1]
	var duration: float=float(flight.delay)+float(flight.travel)
	Ledger.toy(run,"T22","echoes",1,{"cat":cat.id,"to_cat":cat.id,"target":target.id,"x":origin.x,"y":origin.y})
	run.events.append({"type":"toy_cast","kind":"bell_echo","toy":"T22","source_toy":"T22","cat":cat.id,"buff_source":"C06","x":origin.x,"y":origin.y,"from_x":origin.x,"from_y":origin.y,"to_x":target.x,"to_y":target.y,"target":target.id,"duration":duration,"ratio":ratio,"cooldown":float(config.support_echo_cooldown)})
