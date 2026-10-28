extends RefCounted
## Readability limits only: every hit has already been resolved by the simulation.
const MAX_EVENTS: int=96
const MAX_BURSTS: int=8
const MAX_DAMAGE_NUMBERS: int=16
const MERGE_WINDOW: float=.10
const IMPORTANT_BURSTS: Array[String]=["meteor","shield_break"]

static func priority(event: Dictionary) -> int:
	var type: String=str(event.get("type",""))
	if type in ["boss_counter_warning","boss_counter_success","boss_counter_failure"]: return 4
	if type=="toy_combo": return 3
	if type in ["base_damage_resolved","base_shield_broken","base_low_hp"]: return 5
	if type=="death" and (bool(event.get("boss",false)) or bool(event.get("elite",false))): return 4
	if type=="mechanism_identity" and bool(event.get("first",false)): return 4
	if type in ["enemy_debuff_cast","cat_debuff","cat_cleanse","base_hit","enemy_skill_warning"]: return 3
	if type=="mechanism_identity": return 2
	if type in ["toy_cast","toy_heal","enemy_skill","shield_absorb","safeguard","bell_return"]: return 2
	if type=="burst" and str(event.get("kind","")) in IMPORTANT_BURSTS: return 2
	if type=="hit" and bool(event.get("critical",false)): return 1
	if type in ["hit","vfx_status","critical"]: return 0
	return 1

static func _cache_key(event: Dictionary) -> String:
	var type: String=str(event.get("type",""))
	if type in ["hit","critical","vfx_status","freeze","stun"]:
		return "%s|%s|%d|%s|%s" % [type,str(event.get("kind","")),int(event.get("target",-1)),str(event.get("cat","")),str(bool(event.get("critical",false))) if type=="hit" else ""]
	return ""

static func append(events: Array, event: Dictionary, cache: Dictionary = {}) -> void:
	if bool(cache.get("fast",false)):
		_append_live(events,event,cache)
		return
	var type: String=str(event.get("type",""))
	var kind: String=str(event.get("kind",""))
	var cache_key: String=_cache_key(event)
	if cache_key!="" and cache.has(cache_key):
		var cached: Dictionary=cache[cache_key]
		if float(cached.get("age",0))<=MERGE_WINDOW and events.has(cached):
			if type=="hit": cached.amount=float(cached.get("amount",0))+float(event.get("amount",0))
			cached["combined"]=int(cached.get("combined",1))+1
			return
	# Refresh duplicate local flashes; do not collapse different chain endpoints.
	for previous: Dictionary in events:
		if str(previous.get("type",""))!=type or str(previous.get("kind",""))!=kind: continue
		if float(previous.get("age",0))>MERGE_WINDOW: continue
		var same: bool=false
		if type=="burst": same=absf(float(previous.get("x",0))-float(event.get("x",0)))<42 and absf(float(previous.get("y",478))-float(event.get("y",478)))<42
		elif type in ["hit","critical","vfx_status","freeze","stun"]:
			same=int(previous.get("target",-1))==int(event.get("target",-2)) and str(previous.get("cat",""))==str(event.get("cat",""))
			if type=="hit": same= same and bool(previous.get("critical",false))==bool(event.get("critical",false))
		elif type=="chain":
			same=absf(float(previous.get("from_x",0))-float(event.get("from_x",0)))<8 and absf(float(previous.get("from_y",478))-float(event.get("from_y",478)))<8 and absf(float(previous.get("to_x",0))-float(event.get("to_x",0)))<8 and absf(float(previous.get("to_y",478))-float(event.get("to_y",478)))<8
		if same:
			if cache_key!="": cache[cache_key]=previous
			if type=="hit": previous.amount=float(previous.get("amount",0))+float(event.get("amount",0))
			previous["combined"]=int(previous.get("combined",1))+1
			return
	if type=="burst":
		var active: int=0
		var expendable: int=-1
		for i: int in range(events.size()):
			var old: Dictionary=events[i]
			if old.get("type","")=="burst" and float(old.get("age",0))<.26:
				active+=1
				if expendable<0 and str(old.get("kind","")) not in IMPORTANT_BURSTS: expendable=i
		if active>=MAX_BURSTS:
			if expendable>=0: events.remove_at(expendable)
			elif kind not in IMPORTANT_BURSTS: return
			else:
				for i: int in range(events.size()):
					if events[i].get("type","")=="burst": events.remove_at(i); break
	if type=="hit":
		var hits: int=0
		for old: Dictionary in events:
			if old.get("type","")=="hit": hits+=1
		if hits>=MAX_DAMAGE_NUMBERS:
			var replacement: Dictionary = _number_replacement(events,event)
			if replacement.is_empty(): return
			for i: int in range(events.size()):
				if is_same(events[i],replacement): events.remove_at(i); break
	events.append(event)
	if cache_key!="":
		cache[cache_key]=event
		# Stale references are bounded; the visual queue remains the sole owner of validity.
		if cache.size()>384: cache.clear()
	while events.size()>MAX_EVENTS:
		# New damage numbers cannot evict a visible debuff strike or toy activation.
		var remove: int=0
		var lowest: int=priority(events[0])
		for i: int in range(1,events.size()):
			var value: int=priority(events[i])
			if value<lowest: lowest=value;remove=i
		events.remove_at(remove)

## Rendering-only fast queue. Slots permit O(1) identity checks without deep Dictionary equality.
static func live_cache() -> Dictionary:
	return {"fast":true,"size":-1}

static func reindex(events: Array, cache: Dictionary) -> void:
	cache.clear()
	cache.merge({"fast":true,"size":events.size(),"map":{},"hits":[],"bursts":[],"hit_count":0,"burst_count":0,"priorities":[[],[],[],[],[],[]]})
	for slot: int in range(events.size()):
		var event: Dictionary=events[slot]
		event["_budget_slot"]=slot
		_remember(events,event,cache)

static func _valid(events: Array, event: Dictionary) -> bool:
	var slot: int=int(event.get("_budget_slot",-1))
	return slot>=0 and slot<events.size() and is_same(events[slot],event)

static func _fast_key(event: Dictionary) -> String:
	var key: String=_cache_key(event)
	if key!="": return key
	if str(event.get("type",""))=="chain":
		return "chain|%s|%d|%d|%d|%d" % [str(event.get("kind","")),roundi(float(event.get("from_x",0))/4),roundi(float(event.get("from_y",478))/4),roundi(float(event.get("to_x",0))/4),roundi(float(event.get("to_y",478))/4)]
	return ""

static func _remember(_events: Array, event: Dictionary, cache: Dictionary) -> void:
	var type: String=str(event.get("type",""))
	var key: String=_fast_key(event)
	if key!="": cache.map[key]=event
	var rank: int=priority(event)
	event["_budget_priority"]=rank
	cache.priorities[rank].append(event)
	if type=="hit": cache.hit_count+=1;cache.hits.append(event)
	if type=="burst" and float(event.get("age",0))<.26:
		cache.burst_count+=1
		cache.bursts.append(event)

static func _peek(events: Array, queue: Array) -> Dictionary:
	while not queue.is_empty():
		if _valid(events,queue[0]): return queue[0]
		queue.pop_front()
	return {}

static func _number_replacement(events: Array, incoming: Dictionary) -> Dictionary:
	var first_critical: Dictionary = {}
	for old: Dictionary in events:
		if str(old.get("type",""))!="hit": continue
		if bool(old.get("number_hidden",false)) or not bool(old.get("critical",false)): return old
		if first_critical.is_empty(): first_critical=old
	# A small normal tick never pushes a readable critical out of a full number budget.
	return first_critical if bool(incoming.get("critical",false)) else {}

static func _append_live(events: Array, event: Dictionary, cache: Dictionary) -> void:
	if int(cache.get("size",-1))!=events.size(): reindex(events,cache)
	var type: String=str(event.get("type",""))
	var key: String=_fast_key(event)
	if key!="" and cache.map.has(key):
		var previous: Dictionary=cache.map[key]
		if _valid(events,previous) and float(previous.get("age",0))<=MERGE_WINDOW:
			if type=="hit": previous.amount=float(previous.get("amount",0))+float(event.get("amount",0))
			previous["combined"]=int(previous.get("combined",1))+1
			return
	var replacement: Dictionary={}
	if type=="burst":
		var ordinary: Dictionary={}
		for old: Dictionary in cache.bursts:
			if not _valid(events,old): continue
			if str(old.get("kind","")) not in IMPORTANT_BURSTS and ordinary.is_empty(): ordinary=old
			if str(old.get("kind",""))==str(event.get("kind","")) and float(old.get("age",0))<=MERGE_WINDOW and absf(float(old.get("x",0))-float(event.get("x",0)))<42 and absf(float(old.get("y",478))-float(event.get("y",478)))<42:
				old["combined"]=int(old.get("combined",1))+1
				return
		if int(cache.burst_count)>=MAX_BURSTS:
			if not ordinary.is_empty(): replacement=ordinary
			elif str(event.get("kind","")) not in IMPORTANT_BURSTS: return
			else: replacement=_peek(events,cache.bursts)
	elif type=="hit" and int(cache.hit_count)>=MAX_DAMAGE_NUMBERS:
		replacement=_number_replacement(events,event)
		if replacement.is_empty(): return
	if replacement.is_empty() and events.size()>=MAX_EVENTS:
		for rank: int in range(6):
			var candidate: Dictionary=_peek(events,cache.priorities[rank])
			if candidate.is_empty(): continue
			if priority(event)<rank: return
			replacement=candidate
			break
	var slot: int=events.size()
	if not replacement.is_empty():
		slot=int(replacement._budget_slot)
		if str(replacement.get("type",""))=="hit": cache.hit_count-=1
		if str(replacement.get("type",""))=="burst" and float(replacement.get("age",0))<.26: cache.burst_count-=1
		var old_key: String=_fast_key(replacement)
		if old_key!="" and is_same(cache.map.get(old_key,{}),replacement): cache.map.erase(old_key)
		events[slot]=event
	else: events.append(event)
	event["_budget_slot"]=slot
	_remember(events,event,cache)
	cache.size=events.size()
	# Only queues contain stale slot references. Compact at bounded size, never grow with playtime.
	for queue: Array in [cache.hits,cache.bursts]:
		if queue.size()>MAX_EVENTS*2:
			var live: Array=queue.filter(func(item: Dictionary)->bool:return _valid(events,item))
			queue.assign(live)
	for queue: Array in cache.priorities:
		if queue.size()>MAX_EVENTS*2:
			var live: Array=queue.filter(func(item: Dictionary)->bool:return _valid(events,item))
			queue.assign(live)
