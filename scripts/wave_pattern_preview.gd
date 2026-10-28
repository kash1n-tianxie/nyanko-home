extends RefCounted
## Optional A/B presentation experiment only. Preserves every authored spawn entry.
const Data=preload("res://scripts/catalog.gd")
static func arrange(original: Array, duration: float) -> Array:
	var ordinary: Array=[]
	var special: Array=[]
	for entry: Dictionary in original:
		if str(entry.kind).begins_with("E"): ordinary.append(entry.duplicate(true))
		else: special.append(entry.duplicate(true))
	if ordinary.is_empty(): return original.duplicate(true)
	var packets: int=maxi(1,floori(duration*.85/11.5))
	var window: float=clampf((duration*.85-(packets-1)*1.5)/packets,8.0,14.0)
	var count: int=ordinary.size()
	var output: Array=special
	for packet: int in range(packets):
		var take: int=ceili(float(count)/packets) if packet<packets-1 else ordinary.size()
		take=mini(take,ordinary.size())
		# Alternate available swarms, armour escorts, air/ground and rear casters.
		ordinary.sort_custom(func(a: Dictionary,b: Dictionary)->bool:
			var left: int=_priority(str(a.kind),packet%4)
			var right: int=_priority(str(b.kind),packet%4)
			return left<right if left!=right else float(a.time)<float(b.time))
		for i: int in range(take):
			var entry: Dictionary=ordinary.pop_front()
			entry.time=packet*(window+1.5)+window*float(i)/maxi(1,take-1)
			output.append(entry)
	output.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return float(a.time)<float(b.time))
	return output
static func _priority(kind: String, pattern: int) -> int:
	var enemy: Dictionary=Data.enemies().get(kind,{})
	if pattern==0: return 0 if str(enemy.get("trait","")) in ["swarm","fast","slow"] else 2
	if pattern==1: return 0 if float(enemy.get("armor",0))>0 else 1
	if pattern==2: return 0 if bool(enemy.get("air",false)) else 1
	return 2 if str(enemy.get("skill",""))!="" else 0
