extends RefCounted
## Deterministic 60 Hz simulation. Rendering never determines hits or RNG.
const BASE_X: float = 350.0
const VISIBLE_RIGHT: float = 1280.0
const Data = preload("res://scripts/catalog.gd")
const Effects = preload("res://scripts/effects.gd")
const Build = preload("res://scripts/attack_build.gd")
const Expansion = preload("res://scripts/combat_expansion.gd")
const Ledger = preload("res://scripts/feedback_ledger.gd")
const Positions = preload("res://scripts/cat_combat_positions.gd")
const Difficulty = preload("res://scripts/difficulty_rules.gd")
const Director = preload("res://scripts/battle_director.gd")
const BossRules = preload("res://scripts/boss_stage_rules.gd")
const BossEncounter = preload("res://scripts/boss_encounter.gd")
const EncounterChoice = preload("res://scripts/encounter_choice.gd")
const SkillCatalog = preload("res://scripts/skill_catalog.gd")
const CatSkills = preload("res://scripts/cat_skills.gd")
var _owner: WeakRef
var run: RefCounted:
	get: return _owner.get_ref()
var fx: RefCounted
var expansion: RefCounted
var skills: RefCounted
var b: Dictionary:
	get: return run.s.battle

func setup(value: RefCounted) -> void:
	_owner = weakref(value)
	fx = Effects.new()
	fx.setup(self)
	expansion=Expansion.new()
	expansion.setup(self)
	skills=CatSkills.new()
	skills.setup(self)

func start_stage() -> void:
	var stage: Dictionary = Data.stages()[int(run.s.stage)]
	run.s.battle = {"time":0.0,"duration":float(stage.duration),"enemies":[],"cats":[],"projectiles":[],"shields":[],"attacks":{},"schedule":[],"next_spawn":0,"next_enemy":1,"next_attack":1,"next_projectile":1,"pressure":false,"warned":false,"block_cd":0.0,"has_block":false,"has_safeguard":false,"safeguard_used":false,"bond_shield_left":0.0,"bond_shield":false,"reduction":0.0,"bond_speed":0.0,"support_returns":[],"reward_spawn_index":0}
	Ledger.begin(run)
	var active: Array = run.s.active
	b.bond_speed = .08 if "C01" in active and "C03" in active else 0.0
	b.bond_shield = "C02" in active and "C05" in active
	b.reduction = .08 if "C04" in active and "C06" in active else 0.0
	for cat_id: String in active:
		var cat: Dictionary = Data.cats()[cat_id].duplicate(true)
		cat.merge({"id":cat_id,"fish":{},"cooldown":.25,"attacks":0,"noncrit":0,"ice_cd":0.0,"ring_cd":0.0,"death_ice_cd":0.0,"break_cd":0.0,"shield_left":0.0,"buff_left":0.0,"buff_attack":0.0,"buff_speed":0.0,"buff_source":""},true)
		for value: Dictionary in run.equipped(cat_id):
			if not value.is_empty(): cat.fish[value.kind] = Data.fish(value.kind,value.quality,run.effective(value,cat_id))
		_derive_cat_stats(cat)
		skills.initialize_cat(cat)
		b.cats.append(cat)
		var shell: Dictionary = Build.mechanics(cat).get("F08",{})
		b.has_block = b.has_block or shell.get("block",false)
		b.has_safeguard = b.has_safeguard or shell.get("safeguard",false)
		b.reduction += float(shell.get("reduction",0.0))
	b.reduction = minf(.30,b.reduction)
	b.difficulty = Difficulty.profile(str(run.s.get("difficulty","easy")))
	b.schedule = Director.schedule(int(run.s.stage))
	EncounterChoice.augment_schedule(run,b.schedule)
	b.wave_seen = []
	b.boss_stage_version=BossRules.VERSION
	b.hostile_boss_flights=[];b.next_boss_flight=1
	b.skill_flights=[];b.next_skill_cast=1;b.skill_version=SkillCatalog.VERSION
	fx.tick_support(0.0)

func migrate_fixed_bosses() -> void:
	if b.is_empty(): return
	if not b.has("hostile_boss_flights"): b.hostile_boss_flights=[]
	if not b.has("next_boss_flight"): b.next_boss_flight=1
	for enemy: Dictionary in b.get("enemies",[]):
		if not bool(enemy.get("boss",false)): continue
		if int(enemy.get("boss_stage_version",0))<BossRules.VERSION: BossRules.initialize(enemy,true)
		BossEncounter.initialize(enemy,true)
	b.boss_stage_version=BossRules.VERSION
	if str(run.s.get("phase","")) not in ["combat","cleanup"]: clear_boss_flights()

func clear_boss_flights(boss_id: int = -1) -> void:
	if b.is_empty(): return
	if boss_id<0: b.hostile_boss_flights=[]
	else: b.hostile_boss_flights=b.get("hostile_boss_flights",[]).filter(func(f:Dictionary)->bool:return int(f.boss_id)!=boss_id)
	if b.has("debuff_projectiles"):
		b.debuff_projectiles=b.debuff_projectiles.filter(func(f:Dictionary)->bool:
			return not str(f.get("enemy_kind","")).begins_with("B") if boss_id<0 else int(f.get("enemy",-1))!=boss_id)

func launch_boss_attack(enemy: Dictionary, damage: float, action: String) -> void:
	if enemy.dead or float(enemy.hp)<=0 or not BossRules.visible(enemy) or float(run.s.hp)<=0: return
	if not b.has("hostile_boss_flights"): b.hostile_boss_flights=[]
	var duration: float=BossRules.flight_duration(action)
	var source: Vector2=BossRules.cast_point(str(enemy.kind))
	var flight: Dictionary={"id":int(b.get("next_boss_flight",1)),"boss_id":enemy.id,"kind":enemy.kind,"action":action,"damage":damage,"from_x":source.x,"from_y":source.y,"to_x":BASE_X,"to_y":400.0,"duration":duration,"left":duration}
	b.next_boss_flight=int(flight.id)+1
	b.hostile_boss_flights.append(flight)
	var notice: Dictionary=flight.duplicate(true);notice.type="boss_cast";notice.target=enemy.id
	run.events.append(notice)

func tick_boss_flights(delta: float) -> void:
	if delta<=0 or b.is_empty() or bool(run.s.get("paused",false)): return
	if str(run.s.get("phase","")) not in ["combat","cleanup"] or float(run.s.hp)<=0:
		clear_boss_flights();return
	var current: Array=b.get("hostile_boss_flights",[])
	b.hostile_boss_flights=[]
	for flight: Dictionary in current:
		var enemy: Dictionary=get_enemy(int(flight.boss_id))
		if enemy.is_empty() or enemy.dead or float(enemy.hp)<=0 or float(run.s.hp)<=0: continue
		flight.left=maxf(0.0,float(flight.left)-delta)
		if float(flight.left)>.000001:
			b.hostile_boss_flights.append(flight);continue
		# Use the actual launch point in the resolved-damage receipt, without moving the boss.
		var source: Dictionary=enemy.duplicate(false)
		source.x=flight.from_x;source.y=flight.from_y
		var lost_before: float=float(run.s.stats.lost_hp)
		fx.hurt_base(float(flight.damage),source,str(flight.action))
		var notice: Dictionary=flight.duplicate(true)
		notice.type="boss_impact";notice.target=enemy.id;notice.x=BASE_X;notice.y=400.0
		notice.hp_damage=float(run.s.stats.lost_hp)-lost_before
		run.events.append(notice)

func add_cat(cat_id: String) -> void:
	if b.is_empty() or not Data.cats().has(cat_id) or not get_cat(cat_id).is_empty(): return
	var cat: Dictionary=Data.cats()[cat_id].duplicate(true)
	cat.merge({"id":cat_id,"fish":{},"cooldown":.25,"attacks":0,"noncrit":0,"ice_cd":0.0,"ring_cd":0.0,"death_ice_cd":0.0,"break_cd":0.0,"shield_left":0.0,"buff_left":0.0,"buff_attack":0.0,"buff_speed":0.0,"buff_source":""},true)
	_derive_cat_stats(cat)
	skills.initialize_cat(cat)
	b.cats.append(cat)
	_refresh_bonds()

func _derive_cat_stats(cat: Dictionary) -> void:
	expansion.initialize_cat(cat)
	if not cat.has("base_attack"): cat.base_attack=float(Data.cats()[cat.id].attack)
	var attack_bonus: float=float(cat.toys.get("attack_bonus",0))
	var speed_bonus: float=float(cat.toys.get("speed_bonus",0))
	for config: Dictionary in cat.fish.values():
		attack_bonus+=float(config.get("attack_bonus",0))
		speed_bonus+=float(config.get("speed_bonus",0))
	cat.stat_attack_bonus=attack_bonus
	cat.stat_speed_bonus=speed_bonus
	cat.attack=float(cat.base_attack)*(1.0+attack_bonus+float(cat.get("buff_attack",0)))*SkillCatalog.attack_multiplier(cat)

func skill_status(cat_id: String) -> Dictionary:
	return skills.status(cat_id)

func refresh_cat_equipment(cat_id: String) -> void:
	# Hot-swap only this cat: in-flight attacks keep their original payload snapshot.
	var cat: Dictionary=get_cat(cat_id)
	if cat.is_empty(): return
	var old_rate: float=float(cat_display_stats(cat_id).rate)
	var state: Dictionary=cat.get("skills",{})
	var fraction: float=clampf(float(state.get("charge",0))/maxf(.001,float(state.get("duration",18))),0,1)
	cat.fish={}
	for value: Dictionary in run.equipped(cat_id):
		if not value.is_empty(): cat.fish[value.kind]=Data.fish(value.kind,value.quality,run.effective(value,cat_id))
	_derive_cat_stats(cat)
	_refresh_bonds()
	var new_rate: float=float(cat_display_stats(cat_id).rate)
	cat.cooldown=float(cat.get("cooldown",0))*old_rate/maxf(.001,new_rate)
	if not state.is_empty():
		state.duration=skills.charge_duration(cat)
		state.charge=float(state.duration)*(1.0 if bool(state.get("ready",false)) else fraction)

func rebuild_cat_stats(refresh_equipment: bool = true) -> void:
	if b.is_empty(): return
	if not b.has("support_returns"): b.support_returns=[]
	for cat: Dictionary in b.cats:
		var spec: Dictionary=Data.cats()[cat.id]
		cat.base_attack=float(spec.attack)
		for key: String in ["interval","range","speed"]: cat[key]=spec[key]
		for key: String in ["buff_left","buff_attack","buff_speed"]:
			if not cat.has(key): cat[key]=0.0
		if not cat.has("buff_source"): cat.buff_source=""
		if refresh_equipment:
			cat.fish={}
			for item: Dictionary in run.equipped(cat.id):
				if not item.is_empty(): cat.fish[item.kind]=Data.fish(item.kind,item.quality,run.effective(item,cat.id))
		_derive_cat_stats(cat)
	# Old combat snapshots cannot keep pre-unlock payloads or support effects alive.
	b.projectiles=[]
	b.attacks={}
	b.support_returns=[]
	b.shields=b.shields.filter(func(shield:Dictionary)->bool:return str(shield.get("source",""))=="bond" and "C02" in run.s.active and "C05" in run.s.active)
	for enemy: Dictionary in b.enemies:
		enemy.burns=[];enemy.pearl_mark={};enemy.electric_mark={};enemy.ice_death={}
		enemy.freeze=0.0;enemy.freeze_vuln=0.0;enemy.slow=0.0;enemy.slow_left=0.0
		enemy.stun=0.0;enemy.stun_immune=0.0
	_refresh_bonds()

func queue_bell_return(cat: Dictionary, from_x: float) -> void:
	if not b.has("support_returns"): b.support_returns=[]
	var teammates: Array=b.cats.filter(func(other:Dictionary)->bool:return other.id!=cat.id)
	var target: Dictionary=cat if teammates.is_empty() else teammates[run.rand_index("combat",teammates.size())]
	var self_return: bool=target.id==cat.id
	var spec: Dictionary=Data.cats()[cat.id]
	var attack_bonus: float=float(spec.get("solo_attack_pct",.10) if self_return else spec.get("attack_pct",.20))
	var speed_bonus: float=float(spec.get("solo_speed_pct",.10) if self_return else spec.get("speed_pct",.20))
	attack_bonus+=float(expansion.toys().get("bell_bonus",0))
	speed_bonus+=float(expansion.toys().get("bell_bonus",0))
	var flight: Dictionary={"from_cat":cat.id,"to_cat":target.id,"from_x":from_x,"left":.55,"duration":.55,"buff_duration":float(spec.get("duration",3.0)),"attack_bonus":attack_bonus,"speed_bonus":speed_bonus}
	b.support_returns.append(flight)
	var event: Dictionary=flight.duplicate(true);event.type="bell_return"
	run.events.append(event)

func tick_buffs(delta: float) -> void:
	if delta<=0 or not expansion._reactive_active(): return
	for cat: Dictionary in b.cats:
		cat.toy_echo_cooldown=maxf(0.0,float(cat.get("toy_echo_cooldown",0))-delta)
		if float(cat.get("buff_left",0))>0:
			cat.buff_left=maxf(0.0,float(cat.buff_left)-delta)
			if float(cat.buff_left)<=0:
				run.events.append({"type":"cat_buff_expired","from_cat":cat.get("buff_source","C06"),"to_cat":cat.id,"duration":0.0})
				cat.buff_attack=0.0;cat.buff_speed=0.0
				cat.toy_echo_armed=false
				_derive_cat_stats(cat)
	if not b.has("support_returns"): b.support_returns=[]
	var returns: Array=b.support_returns;b.support_returns=[]
	for flight: Dictionary in returns:
		flight.left-=delta
		if float(flight.left)>0:
			b.support_returns.append(flight)
			continue
		var cat: Dictionary=get_cat(flight.to_cat)
		if cat.is_empty(): continue
		cat.buff_left=float(flight.buff_duration)
		cat.buff_attack=maxf(float(cat.get("buff_attack",0)),float(flight.attack_bonus))
		cat.buff_speed=maxf(float(cat.get("buff_speed",0)),float(flight.speed_bonus))
		cat.buff_source=flight.from_cat
		cat.buff_toy=""
		if str(flight.from_cat)=="C06" and str(cat.id)!="C06":
			Ledger.support(run,"C06","buffs",1)
			Ledger.unique_target(run,"C06","buffed_allies",int(str(cat.id).trim_prefix("C")))
		expansion.arm_support_echo(cat,str(flight.from_cat))
		if float(expansion.toys().get("bell_bonus",0))>0:
			cat.buff_toy="T12"
			Ledger.toy(run,"T12","buffs",1,{"to_cat":cat.id,"cat":cat.id})
		_derive_cat_stats(cat)
		run.events.append({"type":"cat_buff","from_cat":flight.from_cat,"to_cat":cat.id,"duration":cat.buff_left,"attack_bonus":cat.buff_attack,"speed_bonus":cat.buff_speed,"amount":cat.buff_attack})

func refresh_team_bonuses() -> void:
	if not b.is_empty(): _refresh_bonds()

func _refresh_bonds() -> void:
	var active: Array=[]
	for cat: Dictionary in b.cats: active.append(cat.id)
	b.bond_speed=.08 if "C01" in active and "C03" in active else 0.0
	var had_shield: bool=bool(b.bond_shield)
	b.bond_shield="C02" in active and "C05" in active
	b.reduction=.08 if "C04" in active and "C06" in active else 0.0
	b.has_block=false
	b.has_safeguard=false
	for cat: Dictionary in b.cats:
		var shell: Dictionary=Build.mechanics(cat).get("F08",{})
		b.reduction+=float(shell.get("reduction",0))
		b.has_block=b.has_block or bool(shell.get("block",false))
		b.has_safeguard=b.has_safeguard or bool(shell.get("safeguard",false))
	b.reduction=minf(.30,b.reduction)
	if b.bond_shield and not had_shield:
		fx.add_shield(12.0,"bond")
		b.bond_shield_left=15.0

func enemies() -> Array:
	return b.get("enemies",[]).filter(func(enemy: Dictionary) -> bool: return not enemy.dead and float(enemy.hp)>0.0)

func get_enemy(id: int) -> Dictionary:
	for enemy: Dictionary in b.get("enemies",[]):
		if int(enemy.id)==id: return enemy
	return {}

func get_cat(id: String) -> Dictionary:
	for cat: Dictionary in b.get("cats",[]):
		if cat.id==id: return cat
	return {}

func spawn(kind: String, x: float = -1.0, zero_gold: bool = false) -> Dictionary:
	var enemy: Dictionary = Data.enemies()[kind].duplicate(true)
	var scaling: Dictionary = Data.chapter_scaling(int(run.s.stage))
	var boss: bool = kind.begins_with("B")
	var difficulty: Dictionary=Difficulty.profile(str(run.s.get("difficulty","easy")))
	if not boss:
		enemy.hp = ceilf(float(enemy.hp)*float(scaling.hp)*float(Data.stage_pressure(int(run.s.stage)).hp))
		enemy.speed *= float(Data.stage_pressure(int(run.s.stage)).pace)
		enemy.damage = ceilf(float(enemy.damage)*float(scaling.damage))
	enemy.hp=ceilf(float(enemy.hp)*float(difficulty.hp))
	enemy.damage=ceilf(float(enemy.damage)*float(difficulty.damage))
	enemy.speed=float(enemy.speed)*float(difficulty.pace)
	for damage_key: String in ["heavy_damage","heavy_followup_damage","heavy_alternate_damage"]:
		if enemy.has(damage_key): enemy[damage_key]=float(enemy[damage_key])*float(difficulty.damage)
	for cooldown_key: String in ["skill_cd","heavy_interval"]:
		if float(enemy.get(cooldown_key,0))>0: enemy[cooldown_key]=float(enemy[cooldown_key])/float(difficulty.skill_rate)
	enemy.merge({"id":int(b.next_enemy),"kind":kind,"x":x if x>=0 else enemy.get("spawn_x",1300.0),"max_hp":enemy.hp,"dead":false,"freeze":0.0,"immune":0.0,"stun":0.0,"stun_immune":0.0,"slow":0.0,"slow_left":0.0,"weak":0.0,"weak_left":0.0,"attack_left":.5 if kind=="E02" else (.8 if kind=="E05" else .6),"contact":false,"windup":0.0,"shield":0.0,"burns":[],"knock_cd":0.0,"first_contact":true,"boss":boss,"elite":kind.begins_with("X"),"thresholds":[],"special_left":float(enemy.get("heavy_start",2.0)) if boss else 8.0,"special_windup":0.0,"second_bite":-1.0,"electric_mark":{},"pearl_mark":{},"ice_death":{},"freeze_vuln":0.0},true)
	enemy["special_cycle"] = 0
	enemy["heavy_engaged"] = false
	enemy["feet_y"]=500.0-float(enemy.get("air_height",170.0) if bool(enemy.get("air",false)) else 0.0)
	enemy["y"]=float(enemy.feet_y)-float(enemy.get("draw_height",60.0))*.42
	enemy["ink_mark"]={}
	enemy["skill_left"]=float(enemy.get("skill_start",5.0))
	enemy["skill_windup"]=0.0
	enemy["rally_left"]=0.0
	enemy["authored_spawn"]=not zero_gold
	enemy["difficulty_id"]=difficulty.id
	if boss:
		BossRules.initialize(enemy)
		BossEncounter.initialize(enemy)
	if zero_gold: enemy.gold = 0
	else:
		var stage: Dictionary=Data.stages()[int(run.s.stage)]
		if stage.has("gold_budget"):
			var total: int=(1 if str(stage.boss)!="" else 0)+(1 if str(stage.get("elite",""))!="" else 0)
			for count: int in stage.counts: total+=count
			var index: int=int(b.get("reward_spawn_index",b.get("next_spawn",0)))
			var budget: int=int(stage.gold_budget)
			enemy.gold=maxi(0,floori(float(mini(index+1,total)*budget)/maxi(1,total))-floori(float(mini(index,total)*budget)/maxi(1,total)))
			b.reward_spawn_index=index+1
	b.next_enemy += 1
	b.enemies.append(enemy)
	run.s.stats.spawned += 1
	if run.has_method("discover_enemy"): run.discover_enemy(kind)
	run.s.stats.max_enemies = maxi(run.s.stats.max_enemies,enemies().size())
	run.events.append({"type":"spawn","kind":kind,"x":enemy.x,"y":enemy.y,"target":enemy.id})
	if boss:
		var arrival: Dictionary=BossRules.geometry(enemy)
		arrival.type="boss_arrival";arrival.duration=BossRules.ENTER_SECONDS
		run.events.append(arrival)
	return enemy

func tick(delta: float) -> void:
	if skills.cinematic_busy(): return
	if delta<=0 or b.is_empty() or bool(run.s.get("paused",false)) or str(run.s.get("phase","")) not in ["combat","cleanup"]: return
	var old_time: float = float(b.time)
	b.time += delta
	var stage: Dictionary = Data.stages()[int(run.s.stage)]
	if stage.boss!="" and not b.warned and float(b.time)>=float(b.duration)*.6-1.0:
		b.warned = true
		run.events.append({"type":"boss_warning","kind":stage.boss,"x":Data.enemies()[stage.boss].spawn_x})
	if not b.pressure and float(b.time)>=float(b.duration)+30.0:
		b.pressure = true
		run.events.append({"type":"pressure"})
	while int(b.next_spawn)<b.schedule.size() and float(b.schedule[int(b.next_spawn)].time)<=float(b.time)+.000001:
		var entry: Dictionary = b.schedule[int(b.next_spawn)]
		if entry.has("wave") and int(entry.wave) not in b.get("wave_seen",[]):
			if not b.has("wave_seen"): b.wave_seen=[]
			b.wave_seen.append(int(entry.wave))
			run.events.append({"type":"wave_start","wave":int(entry.wave),"name":entry.wave_name,"stage":run.s.stage,"duration":1.6})
		var enemy: Dictionary = spawn(entry.kind,float(entry.get("x",-1.0)),bool(entry.get("free",false)))
		enemy["first_tick"] = maxf(0.0,float(b.time)-maxf(old_time,float(entry.time)))
		b.next_spawn += 1
	if float(b.time)>=float(b.duration): run.s.phase = "cleanup"
	fx.tick_support(delta)
	tick_boss_flights(delta)
	# Advance existing hostile flights before enemies can launch a new one.
	expansion.tick(delta)
	for enemy: Dictionary in b.enemies.duplicate():
		if enemy.dead: continue
		if not enemy.has("y"):
			enemy.y=480.0;enemy.feet_y=500.0
		var enemy_delta: float = float(enemy.get("first_tick",delta))
		enemy.erase("first_tick")
		var frozen_before: float = maxf(float(enemy.freeze),float(enemy.get("stun",0)))
		fx.tick_status(enemy,enemy_delta)
		if not enemy.dead: _tick_enemy(enemy,maxf(0.0,enemy_delta-frozen_before))
	tick_buffs(delta)
	skills.tick(delta)
	for cat: Dictionary in b.cats:
		cat.cooldown = maxf(0.0,float(cat.cooldown)-delta)
		if float(cat.cooldown)<=.000001:
			var targets: Array = targets_for(cat)
			if not targets.is_empty(): attack(cat,targets)
	_tick_projectiles(delta)
	b.enemies = b.enemies.filter(func(enemy: Dictionary) -> bool: return not enemy.dead)
	if float(run.s.hp)<=0.0:
		run.settle_stage()
		if run.autosave: run.save(run.save_path)
	elif int(b.next_spawn)>=b.schedule.size() and b.enemies.is_empty() and float(b.time)>=float(b.duration): run.settle_stage()

func _tick_enemy(enemy: Dictionary, delta: float) -> void:
	if enemy.is_empty() or bool(enemy.get("dead",false)) or float(enemy.get("hp",0))<=0: return
	if bool(enemy.get("boss_fixed",false)):
		var entered: float=float(enemy.get("entrance_age",0))
		enemy.entrance_age=entered+delta
		if entered<BossRules.ENTER_SECONDS:
			delta=maxf(0.0,entered+delta-BossRules.ENTER_SECONDS)
			if delta<=.000001: return
	if float(enemy.get("counter_stagger",0))>0:
		enemy.counter_stagger=maxf(0,float(enemy.counter_stagger)-delta)
		return
	if float(enemy.get("taunt_left",0))>0:
		enemy.taunt_left=maxf(0.0,float(enemy.taunt_left)-delta)
		return
	if float(enemy.freeze)>0.0 or float(enemy.get("stun",0))>0.0 or delta<=0.0: return
	if bool(enemy.get("boss_fixed",false)):
		BossEncounter.tick(self,enemy,delta)
		return
	expansion.tick_enemy(enemy,delta)
	if enemy.kind=="B05" and _tick_washer(enemy,delta): return
	if enemy.boss and enemy.kind!="B05" and _tick_approaching_boss(enemy,delta): return
	var pace: float = float(enemy.speed)*(1.0-float(enemy.slow))*(1.5 if b.pressure else 1.0)*(1.0+float(enemy.get("rally_strength",0)) if float(enemy.get("rally_left",0))>0 else 1.0)
	if bool(enemy.get("boss_fixed",false)):
		_tick_fixed_boss_contact(enemy,delta,pace)
		return
	if not enemy.boss and not enemy.elite:
		for other: Dictionary in b.enemies:
			if not other.dead and other.elite and absf(float(other.x)-float(enemy.x))<=160.0:
				pace *= 1.15
				break
	if float(enemy.x)>BASE_X:
		var previous_x: float = enemy.x
		enemy.x = maxf(BASE_X,float(enemy.x)-pace*delta)
		if float(enemy.x)>BASE_X+.00001: return
		enemy.contact = true
		var remaining: float = delta-(previous_x-BASE_X)/maxf(.001,pace)
		if remaining<=.000001: return
		delta = remaining
	if not enemy.contact: enemy.contact = true
	enemy.attack_left -= delta
	enemy.windup = maxf(0.0,float(enemy.attack_left)) if float(enemy.attack_left)<=.6 else 0.0
	if float(enemy.attack_left)<=0.0:
		var damage: float = enemy.damage
		if enemy.kind=="E05" and enemy.first_contact: damage = ceilf(12.0*float(Data.chapter_scaling(int(run.s.stage)).damage)*float(Difficulty.profile(str(run.s.get("difficulty","easy"))).damage))
		fx.hurt_base(damage,enemy,"contact")
		enemy.first_contact = false
		enemy.attack_left += float(enemy.interval)

func _tick_fixed_boss_contact(enemy: Dictionary, delta: float, pace: float) -> void:
	# This clock mirrors only the old movement branch: heavy windups, freeze,
	# stagger and taunt pause it; slow/rally/late pressure keep their old effect.
	if not bool(enemy.get("legacy_contact_ready",false)):
		var remaining: float=maxf(0.0,float(enemy.legacy_approach_duration)-float(enemy.legacy_approach_elapsed))
		var rate: float=pace/maxf(.001,float(enemy.speed))
		var consumed: float=minf(delta,remaining/maxf(.001,rate))
		enemy.legacy_approach_elapsed=minf(float(enemy.legacy_approach_duration),float(enemy.legacy_approach_elapsed)+consumed*rate)
		if float(enemy.legacy_approach_elapsed)+.000001<float(enemy.legacy_approach_duration): return
		enemy.legacy_contact_ready=true
		delta=maxf(0.0,delta-consumed)
	if delta<=.000001: return
	enemy.attack_left-=delta
	enemy.windup=maxf(0.0,float(enemy.attack_left)) if float(enemy.attack_left)<=.6 else 0.0
	if float(enemy.attack_left)<=.000001:
		launch_boss_attack(enemy,float(enemy.damage),"contact")
		enemy.attack_left+=float(enemy.interval)

func _tick_approaching_boss(enemy: Dictionary, delta: float) -> bool:
	if not _heavy_engagement_ready(enemy): return false
	# Bosses announce and execute their existing heavy attack while approaching,
	# giving a build pressure before contact without scaling to the player's HQ.
	if float(enemy.second_bite)>=0.0:
		enemy.second_bite -= delta
		if float(enemy.second_bite)<=0.0:
			launch_boss_attack(enemy,float(enemy.get("heavy_followup_damage",18.0)),"double_bite")
			enemy.second_bite = -1.0
		return true
	if float(enemy.special_windup)>0.0:
		enemy.special_windup -= delta
		enemy.windup = maxf(0.0,enemy.special_windup)
		if float(enemy.special_windup)<=0.0:
			launch_boss_attack(enemy,float(enemy.get("heavy_damage",30.0)),"heavy")
			if float(enemy.get("heavy_followup_damage",0))>0: enemy.second_bite = float(enemy.get("heavy_followup_delay",.4))
			enemy.attack_left = enemy.interval
			enemy.special_left = float(enemy.get("heavy_interval",9.0))
		return true
	enemy.special_left -= delta
	if float(enemy.special_left)<=0.0:
		enemy.special_windup = float(enemy.get("heavy_windup",1.0))
		enemy.windup = enemy.special_windup
		run.events.append({"type":"enemy_windup","target":enemy.id,"x":enemy.x,"kind":enemy.kind})
		return true
	return false

func _tick_washer(enemy: Dictionary, delta: float) -> bool:
	if not _heavy_engagement_ready(enemy): return false
	# Ranged attacks work while approaching; actual damage follows the full windup.
	# The washer alternates sock shots and a lunar tide instead of waiting to touch HQ.
	if float(enemy.special_windup)>0.0:
		enemy.special_windup = maxf(0.0,float(enemy.special_windup)-delta)
		enemy.windup = enemy.special_windup
		if float(enemy.special_windup)<=0.0:
			var tide: bool = int(enemy.get("special_cycle",0))%2==1
			launch_boss_attack(enemy,float(enemy.get("heavy_alternate_damage",28.0) if tide else enemy.get("heavy_damage",18.0)),"moon_tide" if tide else "alien_sock_wave")
			enemy.special_cycle = int(enemy.get("special_cycle",0))+1
			enemy.special_left = float(enemy.get("heavy_interval",7.0))
		return true
	enemy.special_left -= delta
	if float(enemy.special_left)<=0.0:
		var tide: bool = int(enemy.get("special_cycle",0))%2==1
		enemy.special_windup = float(enemy.get("heavy_alternate_windup",1.3) if tide else enemy.get("heavy_windup",1.0))
		enemy.windup = enemy.special_windup
		run.events.append({"type":"enemy_windup","target":enemy.id,"x":enemy.x,"to_x":BASE_X,"kind":"B05","action":"moon_tide" if tide else "sock_wave","duration":enemy.special_windup})
		return true
	return false

func _heavy_engagement_ready(enemy: Dictionary) -> bool:
	if not BossRules.visible(enemy): return false
	# Engage once, on the same legal target geometry used by the cats. Waiting
	# freezes only the first heavy countdown, never the boss's normal approach.
	if bool(enemy.get("heavy_engaged",false)): return true
	# An already launched attack or an old save's ongoing cycle must finish;
	# this migration must not cancel windups, follow-ups, or restart cooldowns.
	var ongoing: bool=float(enemy.get("special_windup",0))>0 or float(enemy.get("second_bite",-1))>=0
	var legacy_cycle: bool=not enemy.has("heavy_engaged") and (int(enemy.get("special_cycle",0))>0 or float(enemy.get("special_left",0))>float(enemy.get("heavy_start",2.0))+.0001)
	if ongoing or legacy_cycle:
		enemy.heavy_engaged=true
		return true
	if float(enemy.x)>VISIBLE_RIGHT: return false
	for cat: Dictionary in b.cats:
		if can_target(cat,enemy):
			enemy.heavy_engaged=true
			return true
	return false

func cat_origin(cat_id: String) -> Vector2:
	var slot: int=clampi(run.s.active.find(cat_id),0,4)
	if cat_id=="C01" and float(get_cat(cat_id).get("skill_rage_left",0))>0:
		return Positions.FEET[slot]+Positions.RAGE_RELEASE_OFFSET
	return Positions.origin(slot,cat_id)

func can_target(cat: Dictionary, enemy: Dictionary, attack_snapshot: Dictionary = {}) -> bool:
	if not BossRules.visible(enemy): return false
	if enemy.dead or float(enemy.x)<BASE_X or float(enemy.x)>minf(VISIBLE_RIGHT,BASE_X+float(cat.range)): return false
	if cat.id=="C04" and bool(enemy.get("air",false)):
		# Meal changes affect new attacks, never eligibility of an existing volley.
		var fish: Dictionary=Build.mechanics(cat) if attack_snapshot.is_empty() else attack_snapshot.get("fish",{})
		var toys: Dictionary=cat.get("toys",{}) if attack_snapshot.is_empty() else attack_snapshot.get("toys",{})
		return float(fish.get("F09",{}).get("air_bonus",0))>0 or float(toys.get("air_bonus",0))>0
	return true

func near_at(point: Vector2, radius: float, count: int, exclude: int = -1) -> Array:
	var result: Array=enemies().filter(func(enemy: Dictionary)->bool:return int(enemy.id)!=exclude and BossRules.visible(enemy) and float(enemy.x)<=VISIBLE_RIGHT and Vector2(enemy.x,float(enemy.get("y",480))).distance_to(point)<=radius)
	result.sort_custom(func(a: Dictionary,c: Dictionary)->bool:return Vector2(a.x,a.get("y",480)).distance_squared_to(point)<Vector2(c.x,c.get("y",480)).distance_squared_to(point))
	return result.slice(0,mini(count,result.size()))

func targets_for(cat: Dictionary) -> Array:
	var result: Array = enemies().filter(func(enemy: Dictionary) -> bool: return can_target(cat,enemy))
	var aim_x: float = float(run.s.get("aim_x",600.0))
	var aim_point: Vector2=Vector2(aim_x,float(run.s.get("aim_y",480.0)))
	var manual: bool = run.s.get("attack_mode","auto")=="manual" and aim_x<=BASE_X+float(cat.range)
	var priority: String=str(run.s.get("cat_priorities",{}).get(cat.id,"nearest"))
	result.sort_custom(func(a: Dictionary,c: Dictionary) -> bool:
		if manual:
			var a_distance: float = Vector2(a.x,a.get("y",480.0)).distance_squared_to(aim_point)
			var c_distance: float = Vector2(c.x,c.get("y",480.0)).distance_squared_to(aim_point)
			if not is_equal_approx(a_distance,c_distance): return a_distance<c_distance
		if not manual:
			if priority=="air" and bool(a.get("air",false))!=bool(c.get("air",false)): return bool(a.get("air",false))
			if priority=="threat":
				var aa: int=_threat_score(a)
				var cc: int=_threat_score(c)
				if aa!=cc: return aa>cc
		if not is_equal_approx(float(a.x),float(c.x)): return float(a.x)<float(c.x)
		if a.hp!=c.hp: return float(a.hp)<float(c.hp)
		return int(a.id)<int(c.id))
	return result

func _threat_score(enemy: Dictionary) -> int:
	if bool(enemy.get("counter_mark",false)): return 5
	if float(enemy.get("skill_windup",0))>0 or float(enemy.get("special_windup",0))>0 or float(enemy.get("counter_left",0))>0: return 4
	if str(enemy.get("skill",""))!="": return 3
	if bool(enemy.get("boss",false)) or bool(enemy.get("elite",false)): return 2
	if str(enemy.get("rank","small"))=="large": return 1
	return 0

func near(x: float, radius: float, count: int, exclude: int = -1) -> Array:
	var result: Array = enemies().filter(func(enemy: Dictionary) -> bool: return int(enemy.id)!=exclude and BossRules.visible(enemy) and float(enemy.x)<=VISIBLE_RIGHT and absf(float(enemy.x)-x)<=radius)
	result.sort_custom(func(a: Dictionary,c: Dictionary) -> bool:
		var da: float = absf(float(a.x)-x)
		var dc: float = absf(float(c.x)-x)
		return da<dc if not is_equal_approx(da,dc) else int(a.id)<int(c.id))
	return result.slice(0,mini(count,result.size()))

func attack(cat: Dictionary, targets: Array) -> void:
	if cat.id=="C05":
		targets=targets_for(cat)
	else: targets=targets.filter(func(e:Dictionary)->bool:return can_target(cat,e))
	if targets.is_empty(): return
	_derive_cat_stats(cat)
	cat.attacks += 1
	var mechanism: Dictionary=Build.mechanics(cat)
	var mint: Dictionary = mechanism.get("F05",{})
	var speed: float = float(cat.get("stat_speed_bonus",0))+float(cat.get("buff_speed",0))+float(mint.get("speed",0.0))+float(b.bond_speed)
	if float(b.time)<8.0: speed += float(mint.get("opening_speed",0.0))
	cat.cooldown = maxf(.18,float(cat.interval)/((1.0+speed)*(1.0-float(cat.get("web_slow",0)))))/SkillCatalog.speed_multiplier(cat)
	var pearl: Dictionary = mechanism.get("F07",{})
	var critical: bool = run.roll("combat")<minf(.75,float(pearl.get("crit",0.0)))
	var guarantee: int = int(pearl.get("guaranteed_every",0))
	if guarantee>0 and int(cat.attacks)%guarantee==0: critical = true
	if int(pearl.get("pity",0))>0 and int(cat.noncrit)>=int(pearl.pity): critical = true
	cat.noncrit = 0 if critical else int(cat.noncrit)+1
	var aid: int = b.next_attack
	b.next_attack += 1
	var ctx: Dictionary = {"id":aid,"cat":cat.id,"count":cat.attacks,"crit":critical,"first":false,"hits":{},"frag":false,"pending":0,"forced":guarantee>0 and int(cat.attacks)%guarantee==0}
	b.attacks[aid] = ctx
	var payload: Dictionary=Build.context(cat,ctx)
	var sword: Dictionary = mechanism.get("F01",{})
	var main_count: int = clampi(int(sword.get("count",1))+int(cat.toys.get("projectile_bonus",0)),1,Build.MAX_MAIN)
	var toy_ratio: float=float(cat.toys.get("projectile_ratio",1))
	if int(cat.toys.get("projectile_bonus",0))>0:
		Ledger.toy(run,"T10","extra_carriers",maxi(0,main_count-int(sword.get("count",1))),{"cat":cat.id,"x":cat_origin(cat.id).x,"y":cat_origin(cat.id).y})
	for i: int in range(main_count):
		queue_hit(cat,targets[0] if cat.id=="C05" else targets[i%targets.size()],aid,true,float(sword.get("coef",1.0))*toy_ratio,.12,Build.pierce(payload,"main"),"main",i,{"volley_count":main_count,"source_toy":"T10" if i>=int(sword.get("count",1)) else "","source_fish":"F01" if mechanism.has("F01") else "","carrier_origin":"T10" if i>=int(sword.get("count",1)) else "main"})
	var echo_every: int = int(mint.get("echo_every",0))
	if echo_every>0 and int(cat.attacks)%echo_every==0:
		var echo_count: int=clampi(int(mint.get("echo_count",1)),1,Build.MAX_ECHO)
		for i: int in range(echo_count): queue_hit(cat,targets[0] if cat.id=="C05" else targets[i%targets.size()],aid,true,float(mint.echo_coef),.12+.08*(i+1),Build.pierce(payload,"echo"),"echo",i,{"volley_count":echo_count,"source_fish":"F05","carrier_origin":"F05"})
	var repeat_every: int=int(cat.toys.get("repeat_every",0))
	if repeat_every>0 and int(cat.attacks)%repeat_every==0:
		Ledger.toy(run,"T01","volleys",1,{"cat":cat.id,"x":cat_origin(cat.id).x,"y":cat_origin(cat.id).y})
		for i: int in range(main_count): queue_hit(cat,targets[i%targets.size()],aid,true,float(sword.get("coef",1))*toy_ratio*float(cat.toys.get("repeat_ratio",.55)),.38,Build.pierce(payload,"echo"),"echo",i,{"volley_count":main_count,"source_toy":"T01","source_fish":"","carrier_origin":"T01"})
	expansion.fire_support_echo(cat,targets[0],aid)
	run.events.append({"type":"attack","cat":cat.id,"count":main_count,"target":targets[0].id,"x":targets[0].x,"y":targets[0].get("y",480.0),"kind":cat.id,"crit":critical,"attack":aid,"payload":Build.visual(payload)})

func queue_hit(cat: Dictionary, target: Dictionary, aid: int, primary: bool, coef: float, delay: float, pierce: int, kind: String, index: int = 0, options: Dictionary = {}) -> void:
	if target.is_empty(): return
	var ctx: Dictionary=b.attacks.get(aid,{})
	if ctx.is_empty(): return
	var payload: Dictionary=Build.context(cat,ctx)
	if not primary:
		payload=payload.duplicate(true)
		payload.fish={};payload.fish_ids=[];payload.elements=[];payload.mods=["echo"];payload.toys={}
		payload.critical=false;payload.forced=false
	var launch: Vector2=cat_origin(cat.id)
	var origin_y: float = float(options.get("origin_y",launch.y))
	var origin_x: float = float(options.get("origin_x",launch.x))
	var travel_from: float=origin_x if options.has("origin_x") else BASE_X
	var travel: float=maxf(.12,absf(float(target.x)-travel_from)/float(cat.speed)) if float(cat.speed)>0.0 else .12
	var count: int=int(options.get("volley_count",1))
	var lane: float=(float(index)-(count-1)*.5)*18.0 if kind in ["main","echo"] else float(options.get("lane",0))
	var projectile: Dictionary={"id":b.next_projectile,"cat":cat.id,"target":target.id,"attack":aid,"x":origin_x,"y":origin_y,"origin_x":origin_x,"origin_y":origin_y,"target_x":target.x,"target_y":float(target.get("y",480.0)),"age":0.0,"delay":delay,"travel":travel,"kind":kind,"primary":primary,"coef":coef,"pierce":clampi(pierce,0,Build.MAX_PIERCE),"index":index,"carrier":kind,"source_kind":kind,"lane":lane,"volley_count":count,"payload":payload,"native_path":cat.id=="C05" and kind in ["main","echo"],"path_group":int(options.get("path_group",b.next_projectile)),"fish":str(options.get("fish","F05" if kind=="echo" else ("F01" if payload.fish.has("F01") else "")))}
	for field: String in ["source_toy","source_fish","carrier_origin"]:
		projectile[field]=options.get(field,projectile.fish if field=="source_fish" else (kind if field=="carrier_origin" else ""))
	if projectile.source_toy=="T01": projectile.fish=""
	# Confusion rolls once per carrier, including every pellet. It fixes a forward
	# ray and resolves segment collisions; it never secretly delivers its target hit.
	if float(cat.get("confuse_left",0))>0 and not bool(options.get("ignore_confusion",false)):
		var cone: float=clampf(float(cat.get("confuse_strength",.5)),.15,.75)
		var angle: float=lerpf(-.55-cone*1.26,.25+cone*.9,run.roll("combat"))
		var homing: float=maxf(float(payload.fish.get("F09",{}).get("homing",0)),float(payload.get("toys",{}).get("air_homing",0)))
		if bool(target.get("air",false)) and homing>0:
			var aimed: float=Vector2(float(target.x)-origin_x,float(target.get("y",480))-origin_y).angle()
			angle=lerpf(angle,aimed,clampf(homing,0,.85))
		projectile.confused=true
		projectile.ray_dx=cos(angle);projectile.ray_dy=sin(angle)
		projectile.target_x=origin_x+cos(angle)*float(cat.range)
		projectile.target_y=origin_y+sin(angle)*float(cat.range)
		projectile.travel=float(cat.range)/maxf(500.0,float(cat.speed))
	b.projectiles.append(projectile)
	b.next_projectile += 1
	ctx.pending = int(ctx.get("pending",0))+1

func _tick_projectiles(delta: float) -> void:
	# New return/pierce legs are queued for the next tick, never recursively resolved.
	var current: Array=b.projectiles
	b.projectiles=[]
	for projectile: Dictionary in current:
		projectile.age += delta
		var target: Dictionary = get_enemy(projectile.target)
		if not bool(projectile.get("confused",false)) and not target.is_empty() and not target.dead:
			projectile.target_x = target.x
			projectile.target_y = float(target.get("y",480.0))
		var previous_position: Vector2=Vector2(projectile.x,projectile.y)
		var progress: float = clampf((float(projectile.age)-float(projectile.delay))/maxf(.001,float(projectile.travel)),0.0,1.0)
		projectile.x = lerpf(projectile.origin_x,projectile.target_x,progress)
		projectile.y = lerpf(projectile.origin_y,projectile.target_y,progress)
		if bool(projectile.get("confused",false)):
			target={}
			if float(projectile.age)>=float(projectile.delay):
				for candidate: Dictionary in enemies():
					if not BossRules.visible(candidate) or float(candidate.x)>VISIBLE_RIGHT: continue
					var center: Vector2=Vector2(candidate.x,candidate.get("y",480))
					var segment: Vector2=Vector2(projectile.x,projectile.y)-previous_position
					var weight: float=clampf((center-previous_position).dot(segment)/maxf(.001,segment.length_squared()),0,1)
					if center.distance_to(previous_position+segment*weight)<=float(candidate.get("hit_radius",24)):
						target=candidate;break
			if not target.is_empty():
				projectile.target=target.id
				projectile.x=target.x;projectile.y=target.y
				projectile.age=float(projectile.delay)+float(projectile.travel)
		if float(projectile.age)+.000001<float(projectile.delay)+float(projectile.travel):
			b.projectiles.append(projectile)
			continue
		var ctx: Dictionary = b.attacks.get(projectile.attack,{})
		var cat: Dictionary = get_cat(projectile.cat)
		if not cat.is_empty() and not ctx.is_empty():
			# Terminal echoes strip offensive modifiers, but retain their parent's
			# targeting permission. Use the immutable volley recipe for eligibility.
			var attack_snapshot: Dictionary=Build.context(cat,ctx)
			var payload: Dictionary=projectile.get("payload",attack_snapshot)
			# A target killed by an earlier pellet does not delete later carriers.
			if (target.is_empty() or target.dead or float(target.hp)<=0.0) and not bool(projectile.get("path_child",false)) and not bool(projectile.get("confused",false)):
				var choices: Array=near(float(projectile.target_x),float(cat.range),999).filter(func(e:Dictionary)->bool:return can_target(cat,e,attack_snapshot))
				if not choices.is_empty():
					# Redirect from the point actually reached, not a fake instantaneous
					# impact at a different enemy. Keep the same pending attack contact.
					target=choices[0]
					projectile.target=target.id
					projectile.origin_x=projectile.x;projectile.origin_y=projectile.y
					projectile.target_x=target.x;projectile.target_y=float(target.get("y",480.0))
					projectile.age=0.0;projectile.delay=0.0
					projectile.travel=maxf(.10,absf(float(target.x)-float(projectile.x))/maxf(1.0,float(cat.speed))) if float(cat.speed)>0 else .10
					projectile.source_kind="retarget"
					b.projectiles.append(projectile)
					continue
			if not target.is_empty() and not target.dead and float(target.hp)>0.0 and can_target(cat,target,attack_snapshot):
				var carrier: String=str(projectile.get("carrier",projectile.kind))
				var visual: Dictionary={"from_x":projectile.origin_x,"from_y":projectile.origin_y,"y":target.get("y",480.0),"to_y":target.get("y",480.0),"visual_kind":carrier,"carrier":carrier,"source_kind":projectile.get("source_kind",carrier),"projectile":projectile.id,"attack":ctx.id,"fish":projectile.get("fish",""),"payload":Build.visual(payload)}
				for field: String in ["source_toy","source_fish","carrier_origin"]: visual[field]=projectile.get(field,"")
				var impact_x: float=float(target.x)
				var forward: Array=enemies().filter(func(e:Dictionary)->bool:return int(e.id)!=int(target.id) and can_target(cat,e,attack_snapshot) and float(e.x)>=impact_x and absf(float(e.get("y",480))-float(target.get("y",480)))<70)
				forward.sort_custom(func(a:Dictionary,c:Dictionary)->bool:return float(a.x)<float(c.x) if not is_equal_approx(a.x,c.x) else int(a.id)<int(c.id))
				if not bool(projectile.get("primary",true)):
					visual.terminal=true
					if expansion._reactive_active(): fx.damage(target,float(payload.base_attack)*float(projectile.coef),cat.id,"toy_echo",0,visual)
				else:
					fx.primary(cat,target,ctx,float(projectile.coef),visual,payload)
				var native_path: bool=bool(projectile.get("native_path",false))
				var pierce_count: int=forward.size() if native_path else int(projectile.get("pierce",0))
				# Old main snapshots computed pierce only at impact. Preserve that upgrade path.
				if not projectile.has("carrier") and carrier=="main": pierce_count=Build.pierce(payload,carrier)
				for i: int in range(mini(pierce_count,forward.size())):
					var next: Dictionary=forward[i]
					if not next.dead and float(next.hp)>0.0:
						queue_hit(cat,next,ctx.id,true,float(projectile.coef)*(1.0 if native_path else Build.pierce_ratio(payload,carrier)),.03*i,0,"pierce",i,{"origin_x":impact_x,"origin_y":target.get("y",480.0),"ignore_confusion":true,"fish":"" if native_path else ("F03" if int(payload.fish.get("F03",{}).get("pierce",0))>0 else "F01"),"lane":projectile.get("lane",0),"path_group":projectile.get("path_group",projectile.id),"source_toy":projectile.get("source_toy",""),"source_fish":projectile.get("source_fish",""),"carrier_origin":projectile.get("carrier_origin",carrier)})
						b.projectiles[-1]["path_child"]=native_path or bool(projectile.get("path_child",false))
		if not ctx.is_empty():
			ctx.pending = int(ctx.get("pending",1))-1
			if int(ctx.pending)<=0: b.attacks.erase(projectile.attack)

func cat_display_stats(cat_id: String) -> Dictionary:
	var cat: Dictionary=get_cat(cat_id)
	if cat.is_empty(): return {"attack":0.0,"rate":0.0}
	_derive_cat_stats(cat)
	var mint: Dictionary=Build.mechanics(cat).get("F05",{})
	var bonus: float=float(cat.get("stat_speed_bonus",0))+float(cat.get("buff_speed",0))+float(mint.get("speed",0))+float(b.get("bond_speed",0))
	if float(b.get("time",0))<8: bonus+=float(mint.get("opening_speed",0))
	var interval: float=maxf(.18,float(cat.interval)/((1+bonus)*(1-float(cat.get("web_slow",0)))))
	return {"attack":float(cat.attack),"rate":SkillCatalog.speed_multiplier(cat)/interval}
