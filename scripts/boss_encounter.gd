extends RefCounted
## One saved director for the existing heavy, counter and base-pressure actions.
## Artwork never drives damage. Phase 2 unlocks the existing base attack budget.
const VERSION: int=39
const TRANSITION_SECONDS: float=1.35
const RECOVERY_SECONDS: float=.55
const IDENTITIES: Dictionary={
	"B01":{"phase1":"纸箱军团","phase2":"王冠裂开 · 亲自砸家","tell":"纸箱重拳","adds":["E03","E03"]},
	"B02":{"phase1":"吸入杂物","phase2":"吸口暴露 · 双重冲击","tell":"双重风炮","adds":["E04","E04"]},
	"B03":{"phase1":"开饭了","phase2":"饿急了 · 影爪拍击","tell":"饥饿影爪","adds":["E07","E07"]},
	"B04":{"phase1":"收视军团","phase2":"屏幕破裂 · 强制播送","tell":"电视冲击波","adds":["E08","E08"]},
	"B05":{"phase1":"滚筒狂欢","phase2":"舱门打开 · 吐出月潮","tell":"滚筒月潮","adds":["E02","E02"]}}

static func initialize(enemy: Dictionary, legacy: bool=false) -> void:
	if int(enemy.get("boss_encounter_version",0))>=VERSION: return
	enemy.boss_encounter_version=VERSION
	enemy.boss_phase=1;enemy.boss_phase_name=str(IDENTITIES.get(str(enemy.kind),IDENTITIES.B01).phase1)
	enemy.boss_state="enter" if not legacy else "idle"
	enemy.boss_tell="";enemy.boss_state_left=0.0;enemy.boss_state_duration=0.0
	enemy.boss_transition_left=0.0;enemy.boss_recovery_left=0.0
	# Old battles have already paid their original entrance costs; no surprise new wave.
	enemy.boss_reinforced=legacy
	if not enemy.has("boss_pending_summons"): enemy.boss_pending_summons=[]

static func status(enemy: Dictionary) -> Dictionary:
	var left: float=float(enemy.get("boss_state_left",0))
	var duration: float=maxf(.001,float(enemy.get("boss_state_duration",0)))
	return {"phase":int(enemy.get("boss_phase",1)),"phase_name":str(enemy.get("boss_phase_name","")),"state":str(enemy.get("boss_state","idle")),"tell":str(enemy.get("boss_tell","")),"left":left,"duration":duration,"progress":clampf(1-left/duration,0,1)}

static func _set_state(enemy: Dictionary, state: String, tell: String="", left: float=0, duration: float=0) -> void:
	enemy.boss_state=state;enemy.boss_tell=tell;enemy.boss_state_left=left
	if duration>0: enemy.boss_state_duration=duration

static func _announce(combat: RefCounted, enemy: Dictionary) -> void:
	combat.run.events.append({"type":"boss_phase","target":enemy.id,"kind":enemy.kind,"phase":enemy.boss_phase,"label":enemy.boss_phase_name,"x":enemy.x,"y":enemy.y,"duration":TRANSITION_SECONDS})

static func _pending_flight(combat: RefCounted, enemy: Dictionary) -> Dictionary:
	for flight: Dictionary in combat.b.get("hostile_boss_flights",[]):
		if int(flight.boss_id)==int(enemy.id): return flight
	return {}

static func _reinforce(combat: RefCounted, enemy: Dictionary) -> void:
	enemy.boss_reinforced=true
	var kinds: Array=IDENTITIES[str(enemy.kind)].adds
	for i: int in range(kinds.size()):
		var add: Dictionary=combat.spawn(str(kinds[i]),combat.BossRules.summon_x(i,38),true)
		add.boss_reinforcement_owner=int(enemy.id)
	# The first two minions consume existing finite summon allowances where present.
	if str(enemy.kind)=="B03": enemy.summoned=int(enemy.get("summoned",0))+kinds.size()
	if str(enemy.kind)=="B05": enemy.boss_threshold_summon_credit=kinds.size()
	combat.run.events.append({"type":"boss_reinforcement","target":enemy.id,"kind":enemy.kind,"count":kinds.size(),"x":combat.BossRules.cast_point(str(enemy.kind)).x,"y":combat.BossRules.cast_point(str(enemy.kind)).y,"duration":.7})
	_announce(combat,enemy)

static func resolve_summons(combat: RefCounted, enemy: Dictionary) -> void:
	var pending: Array=enemy.get("boss_pending_summons",[])
	if pending.is_empty(): return
	enemy.boss_pending_summons=[]
	for wave: Dictionary in pending:
		var credit: int=mini(int(wave.count),int(enemy.get("boss_threshold_summon_credit",0)))
		enemy.boss_threshold_summon_credit=maxi(0,int(enemy.get("boss_threshold_summon_credit",0))-credit)
		for i: int in range(credit,int(wave.count)):
			var kind: String="E02" if str(enemy.kind)=="B05" and i<4 else ("E07" if str(enemy.kind)=="B05" else "E01")
			combat.spawn(kind,combat.BossRules.summon_x(i,20),true)
		combat.run.events.append({"type":"enemy_special","kind":enemy.kind,"action":"sock_summon" if str(enemy.kind)=="B05" else "shadow_summon","target":enemy.id,"x":enemy.x,"count":int(wave.count)-credit})
		combat.run.events.append({"type":"boss_reinforcement","target":enemy.id,"kind":enemy.kind,"count":int(wave.count)-credit,"x":combat.BossRules.cast_point(str(enemy.kind)).x,"y":combat.BossRules.cast_point(str(enemy.kind)).y,"duration":.7})

static func tick(combat: RefCounted, enemy: Dictionary, delta: float) -> void:
	initialize(enemy)
	if not bool(enemy.get("boss_reinforced",false)): _reinforce(combat,enemy)
	resolve_summons(combat,enemy)
	var flight: Dictionary=_pending_flight(combat,enemy)
	var counter: Dictionary=enemy.get("counter_state",{})
	var ongoing: bool=float(enemy.get("special_windup",0))>0 or float(enemy.get("second_bite",-1))>=0
	if int(enemy.boss_phase)==1 and float(enemy.hp)<=float(enemy.max_hp)*.5 and counter.is_empty() and not ongoing and flight.is_empty():
		enemy.boss_phase=2;enemy.boss_phase_name=str(IDENTITIES[str(enemy.kind)].phase2)
		enemy.boss_transition_left=TRANSITION_SECONDS
		enemy.legacy_contact_ready=true
		enemy.attack_left=maxf(1.1,float(enemy.attack_left))
		enemy.special_left=maxf(1.3,float(enemy.special_left))
		_announce(combat,enemy)
	if float(enemy.boss_transition_left)>0:
		enemy.boss_transition_left=maxf(0,float(enemy.boss_transition_left)-delta)
		_set_state(enemy,"transition","本体暴露 · 将直接攻击大本营",enemy.boss_transition_left,TRANSITION_SECONDS)
		return
	if not counter.is_empty():
		combat.expansion._tick_boss_skill(enemy,delta)
		counter=enemy.get("counter_state",{})
		if not counter.is_empty(): _set_state(enemy,"windup",str(counter.label),float(counter.left),float(counter.total))
		else:
			enemy.boss_recovery_left=RECOVERY_SECONDS
			_set_state(enemy,"recover","",RECOVERY_SECONDS,RECOVERY_SECONDS)
		return
	# A second bite is part of the same volley; preserve its authored 0.4 second gap.
	if ongoing:
		_heavy(combat,enemy,delta)
		_describe_action(combat,enemy)
		return
	if not flight.is_empty():
		_set_state(enemy,"flight",str(IDENTITIES[str(enemy.kind)].tell),float(flight.left),float(flight.duration))
		enemy.boss_recovery_left=RECOVERY_SECONDS
		return
	if float(enemy.boss_recovery_left)>0:
		enemy.boss_recovery_left=maxf(0,float(enemy.boss_recovery_left)-delta)
		_set_state(enemy,"recover","",enemy.boss_recovery_left,RECOVERY_SECONDS)
		return
	combat.expansion.tick_enemy(enemy,delta)
	counter=enemy.get("counter_state",{})
	if not counter.is_empty():
		_set_state(enemy,"windup",str(counter.label),float(counter.left),float(counter.total));return
	if _heavy(combat,enemy,delta):
		_describe_action(combat,enemy);return
	var pace: float=float(enemy.speed)*(1.0-float(enemy.slow))*(1.5 if combat.b.pressure else 1.0)*(1.0+float(enemy.get("rally_strength",0)) if float(enemy.get("rally_left",0))>0 else 1.0)
	combat._tick_fixed_boss_contact(enemy,delta,pace)
	_describe_action(combat,enemy)

static func _heavy(combat: RefCounted, enemy: Dictionary, delta: float) -> bool:
	return combat._tick_washer(enemy,delta) if str(enemy.kind)=="B05" else combat._tick_approaching_boss(enemy,delta)

static func _describe_action(combat: RefCounted, enemy: Dictionary) -> void:
	var flight: Dictionary=_pending_flight(combat,enemy)
	if not flight.is_empty():
		_set_state(enemy,"flight",str(IDENTITIES[str(enemy.kind)].tell),float(flight.left),float(flight.duration))
	elif float(enemy.get("special_windup",0))>0:
		var duration: float=float(enemy.get("heavy_windup",1.0))
		if str(enemy.kind)=="B05" and int(enemy.get("special_cycle",0))%2==1: duration=float(enemy.get("heavy_alternate_windup",1.3))
		_set_state(enemy,"windup",str(IDENTITIES[str(enemy.kind)].tell),float(enemy.special_windup),duration)
	elif float(enemy.get("windup",0))>0:
		_set_state(enemy,"windup","砸向大本营",float(enemy.windup),.6)
	else: _set_state(enemy,"idle")
