extends RefCounted
## Read-only accounting. Never rolls RNG, changes damage, awards gold or replays simulation.
const VERSION: int = 31
const Toys = preload("res://scripts/toy_catalog.gd")
const SOURCE_TOYS: Dictionary = {"toy_explosion":"T04","toy_chain":"T05","toy_meteor":"T13","toy_laser":"T16","toy_bleed":"T18","toy_cannon":"T21","toy_echo":"T22"}

static func begin(run: RefCounted) -> void:
	run.s.feedback = {"version":VERSION,"stage":int(run.s.get("stage",0)),"time":0.0,"total_damage":0.0,"damage_by_source":{},"damage_by_cat":{},"damage_by_toy":{},"damage_by_fish":{},"direct_sources":{},"toys":{},"support":{},"base":{"hp_damage":0.0,"shield_absorbed":0.0,"blocked":0.0,"healed":0.0,"revived":0.0,"damage_events":[]},"highlights":[],"debuffs":[],"low_hp_seen":[],"stats_before":run.s.get("stats",{}).duplicate(true),"observed_from":float(run.s.get("battle",{}).get("time",0)),"peak_enemies":0,"_targets":{},"_toy_notice_times":{}}
	run.s.feedback.recent_toy=str(run.s.get("recent_toy","")) if int(run.s.get("recent_toy_stage",run.s.get("stage",0)))==int(run.s.get("stage",0)) else ""
	for id: String in run.s.get("toys",{}):
		var entry: Dictionary=_toy_entry(run.s.feedback,id)
		var effects: Dictionary=Toys.effects({id:run.s.toys[id]})
		for key: String in ["attack_bonus","speed_bonus","air_bonus","base_damage_taken","projectile_ratio"]:
			if float(effects.get(key,0))!=(1.0 if key in ["base_damage_taken","projectile_ratio"] else 0.0): entry.metrics[key]=effects[key]

static func ensure(run: RefCounted) -> Dictionary:
	if not run.s.get("feedback",{}) is Dictionary or int(run.s.get("feedback",{}).get("version",0))!=VERSION or int(run.s.get("feedback",{}).get("stage",-1))!=int(run.s.get("stage",0)):
		begin(run)
	return run.s.feedback

static func _add(map: Dictionary, key: String, amount: float) -> void:
	map[key]=float(map.get(key,0.0))+amount

static func _toy_entry(ledger: Dictionary, id: String) -> Dictionary:
	if not ledger.toys.has(id): ledger.toys[id]={"triggers":0,"hits":0,"damage":0.0,"metrics":{}}
	return ledger.toys[id]

static func source(meta: Dictionary, cat: String, kind: String) -> Dictionary:
	var toy_id: String=str(meta.get("source_toy",meta.get("toy",SOURCE_TOYS.get(kind,""))))
	var fish_id: String=str(meta.get("source_fish",meta.get("fish","")))
	if fish_id.begins_with("T"):
		if toy_id=="": toy_id=fish_id
		fish_id=""
	return {"source_toy":toy_id,"source_fish":fish_id,"carrier_origin":str(meta.get("carrier_origin",meta.get("carrier","main"))),"source_cat":cat if cat.begins_with("C") else "","damage_kind":kind}

static func damage(run: RefCounted, event: Dictionary) -> void:
	var l: Dictionary=ensure(run)
	var amount: float=maxf(0.0,float(event.get("amount",0)))
	if amount<=0: return
	var meta: Dictionary=source(event,str(event.get("cat","")),str(event.get("kind","")))
	event.merge(meta,true)
	var toy_id: String=meta.source_toy
	var cat_id: String=meta.source_cat
	# An extra kaleidoscope carrier remains its cat's attack, not invented bonus damage.
	var direct: String=toy_id if toy_id in ["T01","T03","T04","T05","T13","T16","T18","T21","T22"] else cat_id
	if direct=="": direct=str(event.get("cat","unknown"))
	var key: String="%s|%s|%s|%s|%s" % [cat_id,toy_id,meta.source_fish,meta.carrier_origin,event.get("kind","")]
	l.total_damage+=amount
	_add(l.damage_by_source,key,amount)
	_add(l.direct_sources,direct,amount)
	if direct.begins_with("C"): _add(l.damage_by_cat,direct,amount)
	else: _add(l.damage_by_toy,direct,amount)
	if str(meta.source_fish)!="": _add(l.damage_by_fish,meta.source_fish,amount)
	if toy_id!="":
		var entry: Dictionary=_toy_entry(l,toy_id)
		entry.hits+=1
		if direct==toy_id: entry.damage+=amount
		_add(entry.metrics,"carrier_hits",1)
	l.time=float(run.s.get("battle",{}).get("time",0))

static func toy(run: RefCounted, id: String, metric: String, amount: float = 1.0, meta: Dictionary = {}, emit: bool = true) -> void:
	if id=="" or amount<=0: return
	var l: Dictionary=ensure(run)
	var entry: Dictionary=_toy_entry(l,id)
	_add(entry.metrics,metric,amount)
	if emit:
		entry.triggers+=1
		var now: float=float(run.s.get("battle",{}).get("time",0))
		if not l.has("_toy_notice_times"): l._toy_notice_times={}
		# Cosmetic pulses are coalesced; real occurrence counts above are never dropped.
		if l._toy_notice_times.has(id) and now-float(l._toy_notice_times[id])<.08: return
		l._toy_notice_times[id]=now
		var event: Dictionary={"type":"toy_trigger","toy":id,"source_toy":id,"metric":metric,"amount":amount,"x":350.0,"y":350.0,"time":float(run.s.get("battle",{}).get("time",0))}
		event.merge(meta,true)
		run.events.append(event)

static func support(run: RefCounted, id: String, metric: String, amount: float, meta: Dictionary = {}) -> void:
	if amount<=0 or id=="": return
	var l: Dictionary=ensure(run)
	if not l.support.has(id): l.support[id]={}
	_add(l.support[id],metric,amount)
	if id.begins_with("T"): toy(run,id,metric,amount,meta,false)

static func unique_target(run: RefCounted, id: String, metric: String, target: int) -> void:
	var l: Dictionary=ensure(run)
	var key: String=id+":"+metric
	if not l._targets.has(key): l._targets[key]=[]
	if target in l._targets[key]: return
	l._targets[key].append(target)
	support(run,id,metric,1)

static func record_base(run: RefCounted, event: Dictionary) -> void:
	var l: Dictionary=ensure(run)
	for pair: Array in [["hp_damage","hp_damage"],["shield_absorbed","shield_absorbed"],["blocked","blocked"],["revived","revive_amount"]]:
		_add(l.base,pair[0],float(event.get(pair[1],0)))
	l.base.damage_events.append(event.duplicate(true))
	while l.base.damage_events.size()>12: l.base.damage_events.pop_front()
	run.events.append(event)

static func healed(run: RefCounted, amount: float) -> void:
	_add(ensure(run).base,"healed",maxf(0.0,amount))

static func debuff(run: RefCounted, event: Dictionary) -> void:
	var l: Dictionary=ensure(run)
	l.debuffs.append({"time":float(run.s.battle.get("time",0)),"cat":event.get("to_cat",event.get("cat","")),"skill":event.get("skill",event.get("kind","")),"duration":event.get("status_duration",0),"end_time":float(run.s.battle.get("time",0))+float(event.get("status_duration",0))})
	while l.debuffs.size()>24: l.debuffs.pop_front()

static func debuff_ended(run: RefCounted, cat_id: String, skill: String = "") -> void:
	var l: Dictionary=ensure(run)
	var now: float=float(run.s.get("battle",{}).get("time",0))
	for event: Dictionary in l.debuffs:
		if str(event.cat)==cat_id and (skill=="" or str(event.skill)==skill): event.end_time=minf(float(event.get("end_time",float(event.time)+float(event.duration))),now)

static func snapshot(run: RefCounted) -> Dictionary:
	var battle: Dictionary=run.s.get("battle",{})
	var frame: Dictionary={"time":float(battle.get("time",0)),"hp":float(run.s.get("hp",0)),"max_hp":float(run.s.get("max_hp",1)),"enemies":[],"cats":[],"projectiles":[]}
	for enemy: Dictionary in battle.get("enemies",[]).slice(0,24):
		frame.enemies.append({"id":enemy.id,"kind":enemy.kind,"x":enemy.x,"y":enemy.get("y",480),"feet_y":enemy.get("feet_y",500),"hp":maxf(0,enemy.hp),"max_hp":enemy.max_hp,"dead":enemy.dead,"draw_height":enemy.get("draw_height",60)})
	for cat: Dictionary in battle.get("cats",[]): frame.cats.append({"id":cat.id,"web":cat.get("web_left",0),"confusion":cat.get("confuse_left",0),"buff":cat.get("buff_left",0)})
	for projectile: Dictionary in battle.get("projectiles",[]).slice(0,24): frame.projectiles.append({"x":projectile.x,"y":projectile.y,"cat":projectile.cat,"kind":projectile.kind})
	return frame

static func would_capture(run: RefCounted, id: String, score: float) -> bool:
	if score<=0: return false
	var highlights: Array=ensure(run).highlights
	for item: Dictionary in highlights:
		if str(item.source)==id: return score>float(item.score)
	return highlights.size()<3 or score>float(highlights[-1].score)

static func highlight(run: RefCounted, kind: String, id: String, before: Dictionary, score: float, meta: Dictionary = {}) -> void:
	if score<=0: return
	var l: Dictionary=ensure(run)
	var after: Dictionary=snapshot(run)
	var impact: Dictionary=before.duplicate(true)
	impact["event"]=meta.duplicate(true)
	impact["time"]=after.time
	var item: Dictionary={"kind":kind,"source":id,"score":score,"frames":[before.duplicate(true),impact,after],"stage_time":after.time,"position":Vector2(float(meta.get("x",350)),float(meta.get("y",350))),"target_count":int(meta.get("target_count",0)),"damage":float(meta.get("damage",0))}
	item.merge(meta,true)
	for i: int in range(l.highlights.size()):
		if l.highlights[i].source==id:
			if float(l.highlights[i].score)>=score: return
			l.highlights.remove_at(i)
			break
	l.highlights.append(item)
	l.highlights.sort_custom(func(a:Dictionary,c:Dictionary)->bool:return float(a.score)>float(c.score))
	if l.highlights.size()>3: l.highlights.resize(3)

static func report(run: RefCounted) -> Dictionary:
	var result: Dictionary=ensure(run).duplicate(true)
	result.time=float(run.s.get("battle",{}).get("time",result.time))
	result.erase("_targets")
	result.erase("_toy_notice_times")
	result.erase("stats_before")
	result.erase("low_hp_seen")
	var remaining: float=0.0
	for shield: Dictionary in run.s.get("battle",{}).get("shields",[]):
		remaining+=float(shield.amount)
		var id: String=str(shield.get("source",""))
		if id.begins_with("T"):
			var entry: Dictionary=_toy_entry(result,id)
			_add(entry.metrics,"shield_remaining",float(shield.amount))
	result.base.shield_remaining=remaining
	result.partial=float(result.get("observed_from",0))>0.001
	return result

static func stats_delta(current: Dictionary, previous: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for key: Variant in current:
		if current[key] is Dictionary: result[key]=stats_delta(current[key],previous.get(key,{}))
		elif current[key] is int or current[key] is float: result[key]=current[key]-previous.get(key,0)
	return result

static func failure(run: RefCounted) -> Dictionary:
	var result: Dictionary=report(run)
	var records: Array=result.base.damage_events
	result.last3=records.slice(maxi(0,records.size()-3))
	var losses: Dictionary={}
	for event: Dictionary in records:
		if result.time-float(event.time)<=5: _add(losses,str(event.enemy_kind),float(event.hp_damage))
	var worst: String=""
	for id: String in losses:
		if worst=="" or float(losses[id])>float(losses[worst]): worst=id
	result.largest_recent_source={"enemy_kind":worst,"hp_damage":float(losses.get(worst,0))}
	result.affected_cats=[]
	for event: Dictionary in result.debuffs:
		if float(event.get("end_time",float(event.time)+float(event.duration)))>=result.time-5 and str(event.cat) not in result.affected_cats: result.affected_cats.append(event.cat)
	var heavy_source: bool=false
	for event: Dictionary in records:
		if str(event.enemy_kind)==worst and str(event.skill_kind)!="contact" and result.time-float(event.time)<=5: heavy_source=true
	result.suggestion="优先集火正在蓄力的敌人" if heavy_source else ("优先集火已经靠近猫爬架的敌人" if worst!="" else "先检查猫咪的射程与鱼干效果")
	if not result.affected_cats.is_empty(): result.suggestion="留意蛛网／混乱施法者，薄荷风车可解除减益"
	return result
