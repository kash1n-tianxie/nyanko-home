extends RefCounted
## Every weapon carrier shares one recipe; terminal effects never re-enter primary().
const Build = preload("res://scripts/attack_build.gd")
const Ledger = preload("res://scripts/feedback_ledger.gd")
var _combat: WeakRef
var _batch_depth: int = 0
var _death_queue: Array = []
var combat: RefCounted:
	get: return _combat.get_ref()
var run: RefCounted:
	get: return combat.run
var b: Dictionary:
	get: return run.s.battle
func setup(value: RefCounted) -> void:
	_combat = weakref(value)

func primary(cat: Dictionary, enemy: Dictionary, ctx: Dictionary, coef: float, visual: Dictionary = {}, payload: Dictionary = {}) -> void:
	if enemy.dead or float(enemy.hp)<=0.0: return
	if payload.is_empty(): payload=Build.context(cat,ctx)
	var fish: Dictionary=payload.fish
	var previous: int=int(ctx.hits.get(enemy.id,0))
	ctx.hits[enemy.id]=previous+1
	var scale: float=coef*Build.repeat_scale(previous)
	_batch_depth+=1
	var first: bool=not bool(ctx.first)
	ctx.first=true
	var was_frozen: bool=float(enemy.freeze)>0.0
	var pearl: Dictionary=fish.get("F07",{})
	var critical: bool=bool(payload.critical)
	var multiplier: float=float(pearl.get("mult",1.5)) if critical else 1.0
	if bool(enemy.get("air",false)):
		multiplier*=1.0+float(fish.get("F09",{}).get("air_bonus",0))+float(payload.get("toys",{}).get("air_bonus",0))
	var ignore: float=float(pearl.get("ignore",0)) if critical else 0.0
	if first and bool(payload.get("forced",false)): ignore=maxf(ignore,float(pearl.get("first_ignore",0)))
	var mark: Dictionary=enemy.pearl_mark
	if previous==0 and not mark.is_empty() and int(mark.attack)!=int(ctx.id):
		multiplier*=1.15
		enemy.pearl_mark={}
		_status_event(enemy,"pearl_consume",cat.id,"F07",.15,0)
	var hit_visual: Dictionary=visual.duplicate(true)
	hit_visual.merge({"critical":critical,"payload":Build.visual(payload),"attack":ctx.id,"base_attack":float(payload.base_attack),"repeat_scale":Build.repeat_scale(previous),"terminal":false,"y":enemy.get("y",480.0),"to_y":enemy.get("y",480.0)},true)
	if not hit_visual.has("fish"): hit_visual.fish="F01" if fish.has("F01") else ""
	var carrier: String=str(hit_visual.get("carrier","main"))
	var kind: String="echo" if carrier=="echo" else ("return" if carrier in ["return","bounce"] else "primary")
	var dealt: float=damage(enemy,float(payload.base_attack)*scale*multiplier,cat.id,kind,ignore,hit_visual)
	if dealt>0 and str(hit_visual.get("source_toy",hit_visual.get("fish","")))=="T03":
		Ledger.toy(run,"T03","bounce_hits",1,{"cat":cat.id,"target":enemy.id,"x":enemy.x,"y":enemy.get("y",480)})
	if dealt>0 and bool(enemy.get("air",false)) and float(payload.get("toys",{}).get("air_bonus",0))>0:
		Ledger.toy(run,"T08","air_hits",1,{"cat":cat.id,"target":enemy.id,"x":enemy.x,"y":enemy.get("y",480)})
		Ledger.support(run,"T08","eligible_air_damage",dealt)
	var primary_lethal: bool=float(enemy.hp)<=0.0
	if dealt>0 and critical: run.events.append({"type":"critical","x":enemy.x,"target":enemy.id,"cat":cat.id,"amount":dealt,"payload":Build.visual(payload),"attack":ctx.id})
	if first or cat.id in ["C02","C03","C04"]: innate(cat,enemy,ctx,hit_visual)
	# Every main, echo, piercing leg and returning carrier reaches this entry.
	# Statuses refresh normally; finite explosions/chains inherit this contact's scale.
	if not enemy.dead:
		if critical and float(pearl.get("pearl",0))>0:
			enemy.pearl_mark={"attack":ctx.id,"left":2.0}
			_status_event(enemy,"pearl_mark",cat.id,"F07",.15,2)
		var fire: Dictionary=fish.get("F02",{})
		if not fire.is_empty(): apply_burn(enemy,cat,fire,float(fire.duration),true,-1.0,float(payload.base_attack))
		var ice: Dictionary=fish.get("F04",{})
		if not ice.is_empty():
			apply_slow(enemy,float(ice.slow),float(ice.duration),cat.id,"F04")
			if float(ice.get("death_slow",0))>0: enemy.ice_death[cat.id]=true
		var sword: Dictionary=fish.get("F01",{})
		var freeze_time: float=float(sword.get("freeze",0))
		var ice_triggers: bool=int(ice.get("freeze_every",0))>0 and int(ctx.count)%int(ice.get("freeze_every",1))==0
		if ice_triggers: freeze_time=maxf(freeze_time,float(ice.freeze))
		var freeze_fish: String="F04" if ice_triggers and float(ice.freeze)>=float(sword.get("freeze",0)) else "F01"
		var froze: bool=apply_freeze(enemy,freeze_time,cat.id,freeze_fish)
		if froze and not ice.is_empty() and float(cat.ring_cd)<=0:
			if int(ice.get("spread_count",0))>0:
				for other: Dictionary in combat.near(enemy.x,ice.get("radius",120),mini(2,int(ice.spread_count)),enemy.id):
					if apply_freeze(other,float(ice.spread_freeze),cat.id,"F04",{"from_x":enemy.x,"visual_kind":"ring"}) and float(ice.get("frozen_vuln",0))>0: other.freeze_vuln=.1
				cat.ring_cd=3.0
			elif float(ice.get("ring_slow",0))>0:
				for other: Dictionary in combat.near(enemy.x,120,2,enemy.id): apply_slow(other,float(ice.ring_slow),float(ice.ring_duration),cat.id,"F04",{"from_x":enemy.x,"visual_kind":"ring"})
				cat.ring_cd=3.0
		if float(ice.get("frozen_vuln",0))>0 and float(enemy.freeze)>0: enemy.freeze_vuln=.1
		var shatter: float=float(sword.get("iceburst",0))
		if fish.has("F04"): shatter=maxf(shatter,float(ice.get("shatter",.30+.04*int(ice.get("level",1)))))
		if was_frozen and shatter>0 and float(cat.ice_cd)<=0:
			cat.ice_cd=4.0
			var shatter_visual: Dictionary=hit_visual.duplicate(true)
			shatter_visual.fish="F01" if float(sword.get("iceburst",0))>0 else "F04"
			impact_area(cat,enemy.x,100,5,shatter*scale,"iceburst",shatter_visual)
	if carrier in ["return","bounce"]:
		var returning: Dictionary=fish.get("F03",{})
		apply_slow(enemy,float(returning.get("slow",0)),float(returning.get("slow_duration",0)),cat.id,"F03")
	if fish.has("F02"):
		var fire: Dictionary=fish.F02
		impact_area(cat,enemy.x,float(fire.impact_radius),int(fire.impact_count),float(fire.impact)*scale,"fire_impact",hit_visual)
		# Gold's old spark is now part of the per-contact recipe, at the same coefficient.
		if float(fire.get("spark",0))>0: impact_area(cat,enemy.x,float(fire.spark_radius),int(fire.spark_count),float(fire.spark)*scale,"spark",hit_visual,enemy.id)
	if fish.has("F06"): electric_hit(cat,enemy,ctx,payload,scale,hit_visual)
	combat.expansion.impact(cat,enemy,ctx,payload,scale,first)
	if first: first_hit(cat,enemy,ctx,payload)
	if primary_lethal and critical and not ctx.frag and int(pearl.get("kill_frag_count",0))>0:
		ctx.frag=true
		impact_area(cat,enemy.x,160,int(pearl.kill_frag_count),float(pearl.frag_coef),"pearl",hit_visual,enemy.id)
	_batch_depth-=1
	if _batch_depth==0: _flush_deaths()

func innate(cat: Dictionary, enemy: Dictionary, ctx: Dictionary, carrier_meta: Dictionary = {}) -> void:
	var power: float=float(ctx.get("payload",{}).get("base_attack",cat.attack))
	if cat.id in ["C01","C05"]: return
	var kind: String={"C02":"fur","C03":"arc","C04":"paw","C06":"bell"}[cat.id]
	var radius: float=float(cat.get("innate_radius",{"C02":170.0,"C03":190.0,"C04":135.0,"C06":0.0}[cat.id]))
	var count: int=int(cat.get("innate_targets",{"C02":6,"C03":3,"C04":5,"C06":1}[cat.id]))
	run.events.append({"type":"innate","cat":cat.id,"kind":kind,"x":enemy.x,"y":enemy.get("y",480.0),"target":enemy.id,"attack":ctx.id,"radius":radius,"count":count})
	match cat.id:
		"C02": area(cat,enemy.x,radius,count,float(cat.get("innate_ratio",.75)),"fur",enemy.id,power,float(enemy.get("y",480)),carrier_meta)
		"C03":
			var last: Dictionary=enemy
			var used: Array=[enemy.id]
			for _i: int in range(count):
				var choices: Array=combat.near_at(Vector2(last.x,last.get("y",480)),radius,999).filter(func(e:Dictionary)->bool:return e.id not in used and float(e.x)<=combat.BASE_X+float(cat.range))
				if choices.is_empty(): break
				var next: Dictionary=choices[0]
				used.append(next.id)
				var meta: Dictionary={"from_x":last.x,"from_y":last.get("y",480),"to_x":next.x,"to_y":next.get("y",480),"visual_kind":"chain","terminal":true,"attack":ctx.id}
				run.events.append({"type":"chain","cat":cat.id,"kind":"arc","x":last.x,"from_x":last.x,"from_y":last.get("y",480),"to_x":next.x,"to_y":next.get("y",480),"target":next.id,"terminal":true,"fish":"","enemy_kind":next.kind})
				meta.source_toy=carrier_meta.get("source_toy","")
				meta.carrier_origin=carrier_meta.get("carrier_origin","main")
				damage(next,power*float(cat.get("innate_ratio",.70)),cat.id,"arc",0,meta)
				last=next
		"C04":
			apply_stun(enemy,float(cat.get("innate_stun",.70)),cat.id)
			for other: Dictionary in combat.near_at(Vector2(enemy.x,enemy.get("y",480)),radius,count,enemy.id):
				damage(other,power*float(cat.get("innate_ratio",.80)),cat.id,"paw",0,{"from_x":enemy.x,"visual_kind":"area","terminal":true,"source_toy":carrier_meta.get("source_toy",""),"carrier_origin":carrier_meta.get("carrier_origin","main")})
				apply_stun(other,float(cat.get("innate_stun",.70)),cat.id)
		"C06": combat.queue_bell_return(cat,enemy.x)

func first_hit(cat: Dictionary, enemy: Dictionary, ctx: Dictionary, payload: Dictionary = {}) -> void:
	# Only pattern generation stays once per attack. Generated carriers inherit all
	# impact properties, but this entry cannot run again for their impacts.
	if ctx.get("patterns",false): return
	ctx.patterns=true
	ctx.first=true
	if payload.is_empty(): payload=Build.context(cat,ctx)
	var fish: Dictionary=payload.fish
	if not b.attacks.has(ctx.id):
		ctx.pending=int(ctx.get("pending",0))
		b.attacks[ctx.id]=ctx
	var sword: Dictionary=fish.get("F01",{})
	if float(sword.get("return_coef",0))>0:
		combat.queue_hit(cat,enemy,ctx.id,true,float(sword.return_coef),.12,Build.pierce(payload,"return"),"return",0,{"origin_x":float(enemy.x)+90,"origin_y":float(enemy.get("y",480))-40,"ignore_confusion":true,"fish":"F01"})
	var returning: Dictionary=fish.get("F03",{})
	if float(returning.get("return_coef",0))>0:
		var used: Array=[]
		for i: int in range(clampi(int(returning.get("return_count",1)),1,2)):
			combat.queue_hit(cat,enemy,ctx.id,true,float(returning.return_coef),.15+i*.08,Build.pierce(payload,"return"),"return",i,{"origin_x":float(enemy.x)+100,"origin_y":float(enemy.get("y",480))-50+i*30,"ignore_confusion":true,"fish":"F03"})
			var candidates: Array=combat.near(enemy.x,float(returning.get("radius",140)),999,enemy.id).filter(func(e:Dictionary)->bool:return e.id not in used and float(e.x)>=combat.BASE_X and float(e.x)<=combat.BASE_X+float(cat.range))
			for bounced: Dictionary in candidates.slice(0,mini(candidates.size(),clampi(int(returning.get("bounce",0)),0,2))):
				used.append(bounced.id)
				combat.queue_hit(cat,bounced,ctx.id,true,float(returning.bounce_coef),.2+i*.08,0,"bounce",i,{"origin_x":enemy.x,"origin_y":enemy.get("y",480),"ignore_confusion":true,"fish":"F03"})
	var pearl: Dictionary=fish.get("F07",{})
	if bool(payload.critical) and not ctx.frag and int(pearl.get("hit_frag_count",0))>0:
		ctx.frag=true
		area(cat,enemy.x,160,int(pearl.hit_frag_count),float(pearl.frag_coef),"pearl",enemy.id,float(payload.base_attack))

func electric_hit(cat: Dictionary, enemy: Dictionary, ctx: Dictionary, payload: Dictionary, scale: float, visual: Dictionary) -> void:
	var electric: Dictionary=payload.fish.F06
	var last: Dictionary=enemy
	var used: Array=[enemy.id]
	var hops: int=0
	for _i: int in range(clampi(int(electric.chain_count),0,5)):
		var choices: Array=combat.near_at(Vector2(last.x,last.get("y",480)),180,999).filter(func(e:Dictionary)->bool:return e.id not in used and float(e.x)>=combat.BASE_X and float(e.x)<=combat.BASE_X+float(cat.range))
		if choices.is_empty(): break
		var other: Dictionary=choices[0]
		used.append(other.id)
		var meta: Dictionary=visual.duplicate(true)
		meta.merge({"source_toy":"","source_fish":"F06","fish":"F06","from_x":last.x,"from_y":last.get("y",480),"to_y":other.get("y",480),"visual_kind":"chain","critical":false,"terminal":true},true)
		var event: Dictionary={"type":"chain","cat":cat.id,"x":last.x,"y":last.get("y",480),"from_y":last.get("y",480),"to_x":other.x,"to_y":other.get("y",480),"target":other.id,"enemy_kind":other.kind}
		event.merge(meta,true)
		run.events.append(event)
		damage(other,float(payload.base_attack)*float(electric.chain_coef)*scale,cat.id,"chain",0,meta)
		apply_slow(other,float(electric.get("slow",0)),float(electric.get("duration",0)),cat.id,"F06",{"from_x":last.x})
		last=other
		hops+=1
	if hops>0:
		if int(ctx.count)%3==0: apply_freeze(last,float(electric.get("freeze",0)),cat.id,"F06")
		if float(electric.get("last_burst",0))>0: impact_area(cat,last.x,float(electric.radius),int(electric.burst_count),float(electric.last_burst)*scale,"electric_burst",visual)
		if float(electric.get("mark",0))>0 and not last.dead:
			var strength: float=float(payload.base_attack)*float(electric.mark)*scale
			if last.electric_mark.is_empty() or strength>=float(last.electric_mark.damage):
				last.electric_mark={"cat":cat.id,"damage":strength,"left":2.0}
				_status_event(last,"electric_mark",cat.id,"F06",strength,2)
	# Lightning's large beat remains one finite area per attack, independently of the chains.
	if int(ctx.count)%4==0 and float(electric.get("thunder",0))>0 and not ctx.get("thunder",false):
		ctx.thunder=true
		impact_area(cat,enemy.x,120,5,float(electric.thunder),"thunder",visual)

func impact_area(cat: Dictionary, x: float, radius: float, count: int, coef: float, kind: String, visual: Dictionary, exclude: int = -1) -> void:
	var meta: Dictionary=visual.duplicate(true)
	meta.merge({"critical":false,"terminal":true,"from_x":x,"visual_kind":"area","fish":_fish_kind(kind)},true)
	if kind=="iceburst": meta.fish=visual.get("fish","F04")
	meta.source_toy=Ledger.SOURCE_TOYS.get(kind,"")
	meta.source_fish=meta.fish
	if kind=="cloud_burst": meta.source_fish="F09"
	var event: Dictionary={"type":"burst","cat":cat.id,"x":x,"y":float(visual.get("y",480)),"radius":radius,"kind":kind}
	event.merge(meta,true)
	run.events.append(event)
	var targets: Array=combat.near_at(Vector2(x,float(visual.get("y",480))),radius,clampi(count,0,6),exclude)
	var source_id: String=str(meta.source_toy) if str(meta.source_toy)!="" else (str(meta.source_fish) if str(meta.source_fish)!="" else str(cat.id))
	var score: float=targets.size()*10.0
	var capture: bool=Ledger.would_capture(run,source_id,score)
	var before: Dictionary=Ledger.snapshot(run) if capture else {}
	var actual_damage: float=0.0
	for enemy: Dictionary in targets: actual_damage+=damage(enemy,float(meta.get("base_attack",cat.attack))*coef,cat.id,kind,0,meta)
	if capture and actual_damage>0:
		Ledger.highlight(run,kind,source_id,before,score,{"x":x,"y":float(visual.get("y",480)),"target_count":targets.size(),"damage":actual_damage,"source_fish":meta.source_fish,"source_toy":meta.source_toy,"carrier_origin":meta.get("carrier_origin","main"),"cat":cat.id})

func damage(enemy: Dictionary, raw: float, cat_id: String, kind: String, ignore: float = 0.0, visual: Dictionary = {}) -> float:
	if enemy.is_empty() or enemy.dead or float(enemy.hp)<=0.0 or raw<=0.0: return 0.0
	if not combat.BossRules.visible(enemy): return 0.0
	var vulnerability: float = float(enemy.freeze_vuln) if float(enemy.freeze)>0.0 else 0.0
	for burn: Dictionary in enemy.burns: vulnerability = maxf(vulnerability,float(burn.get("vuln",0.0)))
	var guard_reduction: float=0.0
	var guard_id: int=-1
	if not enemy.boss and str(enemy.get("trait",""))!="guard":
		for guard: Dictionary in combat.enemies():
			var protection: float=float(guard.get("guard_reduction",0))
			if protection>guard_reduction and float(guard.x)<=combat.VISIBLE_RIGHT and absf(float(guard.x)-float(enemy.x))<=float(guard.get("guard_radius",0)):
				guard_reduction=minf(.35,protection);guard_id=int(guard.id)
	var amount: float = raw*(1.0+minf(.15,vulnerability))*(1.0+float(enemy.get("ink_mark",{}).get("pct",0)))*(1.0-minf(.6,float(enemy.armor))*(1.0-ignore))*(1.0-guard_reduction)
	var before_hp: float = enemy.hp
	var shield_damage: float = minf(float(enemy.shield),amount)
	enemy.shield -= shield_damage
	amount -= shield_damage
	enemy.hp -= amount
	var actual: float = minf(before_hp,amount)+shield_damage
	if combat.expansion.has_method("on_damage"): combat.expansion.on_damage(enemy,actual)
	var category: String = "primary" if kind=="primary" else "extra"
	run.s.stats[category][cat_id] = float(run.s.stats[category].get(cat_id,0.0))+actual
	if not run.s.stats.has("damage_by_source"): run.s.stats.damage_by_source = {}
	var source: String = cat_id+":"+kind
	run.s.stats.damage_by_source[source] = float(run.s.stats.damage_by_source.get(source,0.0))+actual
	var event_data: Dictionary = {"type":"hit","cat":cat_id,"target":enemy.id,"kind":kind,"x":enemy.x,"y":enemy.get("y",480),"to_x":enemy.x,"to_y":enemy.get("y",480),"from_x":enemy.x,"from_y":enemy.get("y",480),"amount":actual,"enemy_kind":enemy.kind,"boss":enemy.boss,"critical":false,"fish":_fish_kind(kind),"shield_damage":shield_damage,"guard_reduction":guard_reduction,"guard_id":guard_id}
	event_data.merge(visual,true)
	# Cosmetic metadata cannot overwrite measured effective damage.
	event_data.amount=actual
	event_data.shield_damage=shield_damage
	Ledger.damage(run,event_data)
	enemy.last_hit=event_data.duplicate()
	run.events.append(event_data)
	if enemy.boss:
		if enemy.kind=="B02" and 50 not in enemy.thresholds and before_hp>float(enemy.max_hp)*.5 and float(enemy.hp)<=float(enemy.max_hp)*.5:
			enemy.thresholds.append(50)
			if float(enemy.hp)>0.0: enemy.shield += 400.0
		if enemy.kind=="B05" and float(enemy.hp)>0.0:
			for threshold: int in [70,35]:
				if threshold not in enemy.thresholds and before_hp>float(enemy.max_hp)*threshold/100.0 and float(enemy.hp)<=float(enemy.max_hp)*threshold/100.0:
					enemy.thresholds.append(threshold)
					if not enemy.has("boss_pending_summons"): enemy.boss_pending_summons=[]
					enemy.boss_pending_summons.append({"count":6,"threshold":threshold})
		if enemy.kind=="B03" and float(enemy.hp)>0.0:
			for threshold: int in [60,30]:
				if threshold not in enemy.thresholds and before_hp>float(enemy.max_hp)*threshold/100.0 and float(enemy.hp)<=float(enemy.max_hp)*threshold/100.0:
					enemy.thresholds.append(threshold)
					if not enemy.has("boss_pending_summons"): enemy.boss_pending_summons=[]
					enemy.boss_pending_summons.append({"count":6,"threshold":threshold})
	if float(enemy.hp)<=0.0:
		if _batch_depth>0:
			_death_queue.append(enemy)
		else: die(enemy)
	return actual

func _flush_deaths() -> void:
	# Lethal targets are no longer selectable, but retain their hit state until step6.
	while not _death_queue.is_empty():
		var enemy: Dictionary = _death_queue.pop_front()
		die(enemy)

func area(cat: Dictionary, x: float, radius: float, count: int, coef: float, kind: String, exclude: int = -1, source_attack: float = -1.0, origin_y: float = 480.0, carrier_meta: Dictionary = {}) -> void:
	run.events.append({"type":"burst","cat":cat.id,"x":x,"y":origin_y,"radius":radius,"kind":kind,"fish":_fish_kind(kind)})
	var targets: Array=combat.near_at(Vector2(x,origin_y),radius,count,exclude)
	var source_id: String=str(carrier_meta.get("source_toy","")) if str(carrier_meta.get("source_toy",""))!="" else str(cat.id)
	var capture: bool=Ledger.would_capture(run,source_id,targets.size()*10.0)
	var before: Dictionary=Ledger.snapshot(run) if capture else {}
	var actual_damage: float=0.0
	for enemy: Dictionary in targets: actual_damage+=damage(enemy,(source_attack if source_attack>=0.0 else float(cat.attack))*coef,cat.id,kind,0.0,{"from_x":x,"from_y":origin_y,"visual_kind":"area","terminal":true,"source_toy":carrier_meta.get("source_toy",""),"carrier_origin":carrier_meta.get("carrier_origin","main")})
	if capture and actual_damage>0: Ledger.highlight(run,kind,source_id,before,targets.size()*10.0,{"x":x,"y":origin_y,"target_count":targets.size(),"damage":actual_damage,"cat":cat.id})

func die(enemy: Dictionary) -> void:
	if enemy.dead: return
	enemy.dead = true
	if bool(enemy.get("boss_fixed",false)):
		combat.clear_boss_flights(int(enemy.id))
		var departure: Dictionary=combat.BossRules.geometry(enemy)
		departure.type="boss_departure";departure.duration=1.05
		run.events.append(departure)
	run.s.stats.kills += 1
	if int(enemy.gold)>0: run.change_gold(int(enemy.gold),"kill_gold")
	var last_hit: Dictionary=enemy.get("last_hit",{})
	var direction: Vector2=Vector2(float(enemy.x)-float(last_hit.get("from_x",enemy.x-1)),float(enemy.get("y",480))-float(last_hit.get("from_y",enemy.get("y",480)))).normalized()
	var death: Dictionary={"type":"death","target":enemy.id,"x":enemy.x,"y":enemy.get("y",480),"feet_y":enemy.get("feet_y",500),"kind":enemy.kind,"enemy_kind":enemy.kind,"amount":enemy.gold,"draw_height":enemy.get("draw_height",280 if enemy.boss else 64),"boss":enemy.boss,"elite":enemy.elite,"rank":enemy.get("rank","small"),"killer_cat":last_hit.get("cat",""),"cat":last_hit.get("cat",""),"source_toy":last_hit.get("source_toy",""),"source_fish":last_hit.get("source_fish",""),"carrier_origin":last_hit.get("carrier_origin","main"),"damage_kind":last_hit.get("kind",""),"direction_x":direction.x,"direction_y":direction.y,"from_x":last_hit.get("from_x",enemy.x),"from_y":last_hit.get("from_y",enemy.get("y",480)),"last_hit":last_hit}
	run.events.append(death)
	var ink: Dictionary=enemy.get("ink_mark",{})
	if float(ink.get("burst",0))>0:
		# Death marks are terminal. Clear nearby marks before the terminal burst to
		# prevent a dense marked wave from recursively exploding without a bound.
		var victims: Array=combat.near_at(Vector2(enemy.x,enemy.get("y",480)),float(ink.get("radius",110)),6,enemy.id)
		run.events.append({"type":"burst","kind":"ink_burst","cat":ink.cat,"fish":"F10","x":enemy.x,"y":enemy.get("y",480),"radius":ink.radius,"terminal":true})
		for victim: Dictionary in victims:
			victim.ink_mark={}
			damage(victim,float(ink.power)*float(ink.burst),ink.cat,"ink_burst",0,{"terminal":true,"from_x":enemy.x,"from_y":enemy.get("y",480)})
	if enemy.kind=="E04":
		combat.spawn("E07",maxf(combat.BASE_X,float(enemy.x)-12.0),true)
		combat.spawn("E07",float(enemy.x)+12.0,true)
	for burn: Dictionary in enemy.burns.duplicate(true):
		if burn.get("can_spread",false) and int(burn.config.get("spread",0))>0:
			var cat: Dictionary = combat.get_cat(burn.cat)
			if not cat.is_empty():
				for other: Dictionary in combat.near(enemy.x,140.0,int(burn.config.spread),enemy.id): apply_burn(other,cat,burn.config,float(burn.config.spread_duration),false,float(enemy.x),float(burn.get("source_attack",cat.attack)))
	if not enemy.electric_mark.is_empty():
		for other: Dictionary in combat.near(enemy.x,180.0,1,enemy.id): damage(other,float(enemy.electric_mark.damage),enemy.electric_mark.cat,"electric_mark",0.0,{"from_x":enemy.x,"visual_kind":"mark_discharge"})
	if float(enemy.freeze)>0.0:
		for cat_id: String in enemy.ice_death:
			var cat: Dictionary = combat.get_cat(cat_id)
			if not cat.is_empty() and float(cat.death_ice_cd)<=0.0:
				cat.death_ice_cd = 2.0
				for other: Dictionary in combat.near(enemy.x,100.0,5,enemy.id): apply_slow(other,.3,2.0,cat.id,"F04",{"from_x":enemy.x,"visual_kind":"death_ice"})

func apply_slow(enemy: Dictionary, strength: float, duration: float, cat_id: String = "", fish: String = "", visual: Dictionary = {}) -> void:
	if enemy.is_empty() or enemy.dead or strength<=0.0: return
	strength = minf(.6,strength)*(.5 if enemy.boss else 1.0)
	if strength>=float(enemy.slow):
		enemy.feedback_slow_source=fish if fish!="" else cat_id
		enemy.slow = strength
		enemy.slow_left = maxf(duration,float(enemy.slow_left))
		_status_event(enemy,"slow",cat_id,fish,strength,float(enemy.slow_left),visual)
		if fish=="T09":
			Ledger.toy(run,"T09","slow_applications",1,{"cat":cat_id,"target":enemy.id,"x":enemy.x,"y":enemy.get("y",480),"duration":enemy.slow_left})
			Ledger.unique_target(run,"T09","slowed_targets",int(enemy.id))

func apply_weak(enemy: Dictionary, strength: float, duration: float, cat_id: String = "", fish: String = "") -> void:
	if enemy.is_empty() or enemy.dead or strength<=0.0: return
	if strength>=float(enemy.weak):
		enemy.weak = minf(.3,strength)
		enemy.weak_left = maxf(duration,float(enemy.weak_left))
		_status_event(enemy,"weak",cat_id,fish,float(enemy.weak),float(enemy.weak_left))

func apply_stun(enemy: Dictionary, duration: float, cat_id: String = "") -> bool:
	if enemy.is_empty() or enemy.dead or duration<=0.0 or float(enemy.get("stun",0))>0 or float(enemy.get("stun_immune",0))>0: return false
	enemy.stun=duration*(.35 if enemy.boss else (.70 if enemy.elite else 1.0))
	enemy.feedback_stun_source=cat_id
	Ledger.support(run,cat_id,"stuns",1)
	run.events.append({"type":"stun","target":enemy.id,"x":enemy.x,"y":enemy.get("y",480),"from_x":enemy.x,"from_y":enemy.get("y",480),"cat":cat_id,"duration":enemy.stun,"amount":enemy.stun,"enemy_kind":enemy.kind})
	return true

func apply_freeze(enemy: Dictionary, duration: float, cat_id: String = "", fish: String = "", visual: Dictionary = {}) -> bool:
	if enemy.is_empty() or enemy.dead or duration<=0.0 or float(enemy.freeze)>0.0 or float(enemy.immune)>0.0: return false
	enemy.freeze = duration*(.5 if enemy.boss else (.75 if enemy.elite else 1.0))
	enemy.feedback_freeze_source=fish if fish!="" else cat_id
	if fish.begins_with("T"):
		Ledger.toy(run,fish,"freezes",1,{"cat":cat_id,"target":enemy.id,"x":enemy.x,"y":enemy.get("y",480),"duration":enemy.freeze})
	var event_data: Dictionary = {"type":"freeze","target":enemy.id,"x":enemy.x,"y":enemy.get("y",480),"from_x":enemy.x,"from_y":enemy.get("y",480),"amount":enemy.freeze,"duration":enemy.freeze,"cat":cat_id,"fish":fish,"enemy_kind":enemy.kind}
	event_data.merge(visual,true)
	event_data.merge(Ledger.source(event_data,cat_id,"freeze"),true)
	run.events.append(event_data)
	return true

func knockback(enemy: Dictionary, amount: float, source: String = "") -> void:
	if enemy.is_empty() or enemy.dead or enemy.boss or float(enemy.knock_cd)>0.0 or amount<=0.0: return
	var previous_x: float=float(enemy.x)
	enemy.x = minf(1300.0,float(enemy.x)+minf(80.0,amount)*(.5 if str(enemy.get("rank","")) in ["large","elite"] else 1.0))
	if source!="" and float(enemy.x)>previous_x:
		Ledger.toy(run,source,"knockbacks",1,{"target":enemy.id,"x":enemy.x,"y":enemy.get("y",480),"distance":float(enemy.x)-previous_x})
		Ledger.support(run,source,"knockback_distance",float(enemy.x)-previous_x)
	enemy.contact = false
	enemy.knock_cd = .5

func apply_burn(enemy: Dictionary, cat: Dictionary, config: Dictionary, duration: float, can_spread: bool, from_x: float = -1.0, base_attack: float = -1.0) -> void:
	if enemy.dead: return
	for burn: Dictionary in enemy.burns:
		if burn.cat==cat.id:
			burn.left = maxf(float(burn.left),duration)
			burn.can_spread = burn.can_spread or can_spread
			_status_event(enemy,"burn",cat.id,"F02",float(burn.dps),float(burn.left),{"refresh":true,"spread":from_x>=0.0,"from_x":from_x if from_x>=0.0 else enemy.x})
			return
	var value: Dictionary = {"cat":cat.id,"dps":(base_attack if base_attack>=0.0 else float(cat.attack))*float(config.burn),"source_attack":base_attack if base_attack>=0.0 else float(cat.attack),"left":duration,"elapsed":0.0,"tick_left":.5,"accrued":0.0,"explode_left":float(config.get("explode_after",99.0)),"can_spread":can_spread,"config":config.duplicate(true),"vuln":config.get("vuln",0.0)}
	value.source_fish="F02"
	enemy.burns.append(value)
	enemy.burns.sort_custom(func(a: Dictionary,c: Dictionary) -> bool: return float(a.dps)>float(c.dps))
	if enemy.burns.size()>2: enemy.burns.resize(2)
	if value in enemy.burns: _status_event(enemy,"burn",cat.id,"F02",float(value.dps),duration,{"spread":from_x>=0.0,"from_x":from_x if from_x>=0.0 else enemy.x})

func tick_status(enemy: Dictionary, delta: float) -> void:
	# Each status reports its own actual coverage. Overlapping stun/freeze are
	# deliberately separate fields, never added into an invented total delay.
	Ledger.support(run,str(enemy.get("feedback_stun_source","")),"stun_seconds",minf(delta,float(enemy.get("stun",0))))
	Ledger.support(run,str(enemy.get("feedback_freeze_source","")),"freeze_seconds",minf(delta,float(enemy.freeze)))
	Ledger.support(run,str(enemy.get("feedback_slow_source","")),"slow_seconds",minf(delta,float(enemy.slow_left)))
	if float(enemy.get("taunt_left",0))>0:
		# Combat subtracts frozen/stunned time before ticking the taunt clock.
		var taunt_delta: float=maxf(0.0,delta-maxf(float(enemy.freeze),float(enemy.get("stun",0))))
		Ledger.support(run,"T20","delay_seconds",minf(taunt_delta,float(enemy.taunt_left)))
	var bleed: Dictionary=enemy.get("toy_bleed",{})
	if not bleed.is_empty():
		var active: float=minf(delta,float(bleed.left))
		bleed.left=maxf(0.0,float(bleed.left)-active)
		bleed.tick=float(bleed.get("tick",0))+active
		if float(bleed.tick)>=.5 or float(bleed.left)<=0:
			damage(enemy,float(bleed.dps)*float(bleed.tick),bleed.cat,"toy_bleed",0,{"toy":"T18","terminal":true})
			bleed.tick=0.0
		if float(bleed.left)<=0: enemy.toy_bleed={}
	if float(enemy.get("stun",0))>0:
		enemy.stun=maxf(0.0,float(enemy.stun)-delta)
		if float(enemy.stun)<=0: enemy.stun_immune=4.0 if enemy.boss else 1.2
	else: enemy.stun_immune=maxf(0.0,float(enemy.get("stun_immune",0))-delta)
	var was_frozen: bool = float(enemy.freeze)>0.0
	if was_frozen:
		enemy.freeze = maxf(0.0,float(enemy.freeze)-delta)
		if float(enemy.freeze)<=0.0:
			enemy.immune = 5.0 if enemy.boss else 3.0
			enemy.freeze_vuln = 0.0
	else: enemy.immune = maxf(0.0,float(enemy.immune)-delta)
	enemy.knock_cd = maxf(0.0,float(enemy.knock_cd)-delta)
	enemy.slow_left = maxf(0.0,float(enemy.slow_left)-delta)
	if float(enemy.slow_left)<=0.0: enemy.slow = 0.0
	enemy.weak_left = maxf(0.0,float(enemy.weak_left)-delta)
	if float(enemy.weak_left)<=0.0: enemy.weak = 0.0
	for mark_key: String in ["electric_mark","pearl_mark","ink_mark"]:
		if not enemy.get(mark_key,{}).is_empty():
			enemy[mark_key].left -= delta
			if float(enemy[mark_key].left)<=0.0: enemy[mark_key] = {}
	var expired: Array = []
	for burn: Dictionary in enemy.burns.duplicate():
		if enemy.dead: break
		var active_delta: float = minf(delta,float(burn.left))
		burn.left -= active_delta
		burn.elapsed += active_delta
		burn.tick_left -= active_delta
		burn.accrued += active_delta
		burn.explode_left -= active_delta
		if float(burn.tick_left)<=.000001 or float(burn.left)<=.000001:
			damage(enemy,float(burn.dps)*float(burn.accrued),burn.cat,"burn",0,{"source_fish":"F02","carrier_origin":"burn","terminal":true})
			burn.accrued = 0.0
			burn.tick_left += .5
		if not enemy.dead and float(burn.config.get("explode",0.0))>0.0 and float(burn.explode_left)<=.000001:
			var cat: Dictionary = combat.get_cat(burn.cat)
			burn.explode_left = float(burn.config.explode_cd)
			if not cat.is_empty(): area(cat,enemy.x,float(burn.config.explode_radius),int(burn.config.explode_count),float(burn.config.explode),"burn_burst",-1,float(burn.get("source_attack",cat.attack)))
		if float(burn.left)<=.000001: expired.append(burn.cat)
	enemy.burns = enemy.burns.filter(func(burn: Dictionary) -> bool: return burn.cat not in expired)

func shield_total() -> float:
	var total: float = 0.0
	for shield: Dictionary in b.shields: total += float(shield.amount)
	return total

func add_shield(amount: float, source: String, fish: String = "") -> void:
	# The once-per-battle guard is its own layer; it does not consume the
	# pre-existing fish/toy shield allowance. Both absorb through hurt_base().
	var ordinary_total: float=0.0
	for layer: Dictionary in b.shields:
		if not bool(layer.get("active_skill",false)): ordinary_total+=float(layer.amount)
	amount = minf(amount,maxf(0.0,float(run.s.max_hp)*.25-ordinary_total))
	if amount<=0.0: return
	b.shields.append({"amount":amount,"left":8.0,"source":source,"source_fish":fish})
	Ledger.support(run,fish if fish!="" else source,"shield_added",amount)
	run.events.append({"type":"shield","cat":source,"x":combat.BASE_X,"amount":amount,"fish":fish})

func tick_support(delta: float) -> void:
	b.block_cd = maxf(0.0,float(b.block_cd)-delta)
	for shield: Dictionary in b.shields: shield.left -= delta
	b.shields = b.shields.filter(func(shield: Dictionary) -> bool: return float(shield.left)>0.0 and float(shield.amount)>0.0)
	for cat: Dictionary in b.cats:
		for key: String in ["ice_cd","ring_cd","death_ice_cd","break_cd"]: cat[key] = maxf(0.0,float(cat[key])-delta)
		var shell: Dictionary = Build.mechanics(cat).get("F08",{})
		if not shell.is_empty():
			cat.shield_left -= delta
			if float(cat.shield_left)<=0.0:
				add_shield(float(shell.shield),cat.id,"F08")
				cat.shield_left += float(shell.period)
	if b.bond_shield:
		b.bond_shield_left -= delta
		if float(b.bond_shield_left)<=0.0:
			add_shield(12.0,"bond")
			b.bond_shield_left += 15.0

func hurt_base(raw: float, enemy: Dictionary, kind: String) -> void:
	if float(run.s.hp)<=0.0: return
	var amount: float=raw*(1.5 if b.pressure else 1.0)*(1.0-float(enemy.weak))*float(combat.expansion.toys().get("base_damage_taken",1.0))
	run.s.stats.incoming+=amount
	if not run.s.stats.has("incoming_by_enemy"): run.s.stats.incoming_by_enemy={}
	run.s.stats.incoming_by_enemy[enemy.kind]=float(run.s.stats.incoming_by_enemy.get(enemy.kind,0.0))+amount
	run.events.append({"type":"base_hit","target":enemy.id,"x":combat.BASE_X,"y":400.0,"from_x":enemy.x,"from_y":enemy.get("y",480),"to_x":combat.BASE_X,"to_y":400.0,"amount":amount,"kind":kind,"enemy_kind":enemy.kind,"boss":enemy.boss})
	var hp_before: float=float(run.s.hp)
	var shield_before: float=shield_total()
	var resolved: Dictionary={"type":"base_damage_resolved","time":float(b.time),"enemy_instance":enemy.id,"enemy_kind":enemy.kind,"skill_kind":kind,"raw":raw,"adjusted_incoming":amount,"after_reduction":amount*(1.0-float(b.reduction)),"blocked":0.0,"shield_absorbed":0.0,"hp_damage":0.0,"hp_before":hp_before,"hp_after":hp_before,"revive_amount":0.0,"shield_before":shield_before,"shield_after":shield_before,"shield_broken":false,"max_hp":float(run.s.max_hp),"x":combat.BASE_X,"y":400.0,"from_x":enemy.x,"from_y":enemy.get("y",480),"boss":enemy.boss}
	if b.has_block and float(b.block_cd)<=0.0:
		b.block_cd=20.0
		run.events.append({"type":"block","x":combat.BASE_X,"amount":amount,"fish":"F08","target":enemy.id,"enemy_kind":enemy.kind})
		resolved.blocked=resolved.after_reduction
		Ledger.support(run,"F08","blocked",float(resolved.blocked))
		Ledger.record_base(run,resolved)
		return
	amount*=1.0-float(b.reduction)
	b.shields.sort_custom(func(a:Dictionary,c:Dictionary)->bool:return float(a.left)<float(c.left))
	for shield: Dictionary in b.shields:
		var absorb: float=minf(float(shield.amount),amount)
		shield.amount-=absorb
		amount-=absorb
		run.s.stats.absorbed+=absorb
		resolved.shield_absorbed+=absorb
		if absorb>0:
			run.events.append({"type":"shield_absorb","cat":shield.source,"source_toy":shield.source if str(shield.source).begins_with("T") else "","x":combat.BASE_X,"amount":absorb,"fish":shield.get("source_fish",""),"target":enemy.id,"enemy_kind":enemy.kind})
			Ledger.support(run,str(shield.source_fish) if str(shield.get("source_fish",""))!="" else str(shield.source),"shield_absorbed",absorb)
		if not run.s.stats.has("shield_by_cat"): run.s.stats.shield_by_cat={}
		run.s.stats.shield_by_cat[shield.source]=float(run.s.stats.shield_by_cat.get(shield.source,0.0))+absorb
	b.shields=b.shields.filter(func(shield:Dictionary)->bool:return float(shield.amount)>.000001)
	var broke: bool=shield_before>0.0 and shield_total()<=.000001
	resolved.shield_broken=broke
	resolved.shield_after=shield_total()
	# Count durability removed before rescue. Overkill is never reported as lost HP.
	var lost: float=minf(hp_before,maxf(0.0,amount))
	resolved.hp_damage=lost
	var before_rescue: Dictionary=Ledger.snapshot(run) if amount>=hp_before else {}
	run.s.hp-=amount
	var toy_config: Dictionary=combat.expansion.toys()
	if float(run.s.hp)<=0 and int(run.s.get("toy_revives_used",0))<int(toy_config.get("revive_charges",0)):
		run.s.toy_revives_used=int(run.s.get("toy_revives_used",0))+1
		run.s.hp=float(run.s.max_hp)*float(toy_config.get("revive_ratio",.3))
		resolved.revive_amount=float(run.s.hp)
		run.events.append({"type":"toy_cast","kind":"revive","toy":"T17","source_toy":"T17","x":combat.BASE_X,"y":350.0,"duration":1.0,"amount":run.s.hp})
		Ledger.toy(run,"T17","revives",1,{"x":combat.BASE_X,"y":350.0,"restored":run.s.hp})
		Ledger.support(run,"T17","restored_hp",float(run.s.hp))
		Ledger.highlight(run,"revive","T17",before_rescue,1000.0,{"x":combat.BASE_X,"y":350.0,"restored":run.s.hp})
	if float(run.s.hp)<=0.0 and b.has_safeguard and not b.safeguard_used:
		b.safeguard_used=true
		run.s.hp=1.0
		resolved.safeguard_restore=1.0
		add_shield(60.0,"safeguard","F08")
		run.events.append({"type":"safeguard","x":combat.BASE_X,"fish":"F08"})
	run.s.hp=maxf(0.0,float(run.s.hp))
	resolved.hp_after=float(run.s.hp)
	run.s.stats.lost_hp+=lost
	if not run.s.stats.has("hp_loss_by_enemy"): run.s.stats.hp_loss_by_enemy={}
	run.s.stats.hp_loss_by_enemy[enemy.kind]=float(run.s.stats.hp_loss_by_enemy.get(enemy.kind,0.0))+lost
	Ledger.record_base(run,resolved)
	if float(toy_config.get("base_damage_taken",1.0))>1:
		Ledger.support(run,"T15","affected_incoming",float(resolved.after_reduction))
		Ledger.toy(run,"T15","base_hits",1,{"x":combat.BASE_X,"y":400.0,"multiplier":toy_config.base_damage_taken})
	var ledger: Dictionary=Ledger.ensure(run)
	for threshold: int in [35,15]:
		if threshold not in ledger.low_hp_seen and hp_before/float(run.s.max_hp)>threshold/100.0 and float(run.s.hp)/float(run.s.max_hp)<=threshold/100.0:
			ledger.low_hp_seen.append(threshold)
			run.events.append({"type":"base_low_hp","threshold":threshold,"x":combat.BASE_X,"y":400.0,"hp":run.s.hp})
	if broke:
		run.events.append({"type":"base_shield_broken","x":combat.BASE_X,"y":400.0,"shield_before":shield_before,"hp_damage":lost})
		for cat: Dictionary in b.cats:
			var shell: Dictionary=Build.mechanics(cat).get("F08",{})
			if float(shell.get("break_coef",0.0))<=0.0 or float(cat.break_cd)>0.0: continue
			cat.break_cd=4.0
			run.events.append({"type":"burst","kind":"shield_break","fish":"F08","cat":cat.id,"x":combat.BASE_X,"radius":shell.break_range})
			for other: Dictionary in combat.near(combat.BASE_X,float(shell.break_range),int(shell.break_count)):
				damage(other,float(cat.attack)*float(shell.break_coef),cat.id,"shield_break",0.0,{"from_x":combat.BASE_X,"visual_kind":"area"})
				knockback(other,float(shell.get("push",0.0)))
				apply_weak(other,float(shell.get("weak",0.0)),2.0,cat.id,"F08")

# Presentation metadata is kept in the transient event stream, never in saved state.
func _status_event(enemy: Dictionary, kind: String, cat_id: String, fish: String, amount: float, duration: float, visual: Dictionary = {}) -> void:
	var event_data: Dictionary = {"type":"vfx_status","kind":kind,"cat":cat_id,"fish":fish,"target":enemy.id,"x":enemy.x,"y":enemy.get("y",480),"from_x":enemy.x,"from_y":enemy.get("y",480),"enemy_kind":enemy.kind,"amount":amount,"duration":duration,"refresh":false,"spread":false}
	event_data.merge(visual,true)
	event_data.merge(Ledger.source(event_data,cat_id,kind),true)
	run.events.append(event_data)

func _fish_kind(kind: String) -> String:
	match kind:
		"iceburst": return "F01"
		"burn","spark","burn_burst","fire_impact": return "F02"
		"echo": return "F05"
		"chain","electric_burst","electric_mark","thunder": return "F06"
		"pearl": return "F07"
		"shield_break": return "F08"
		"cloud_burst": return "F09"
		"ink_burst": return "F10"
	return ""
