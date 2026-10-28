extends RefCounted
## Optional, once-per-chapter transactions. No background RNG or combat changes.
const Data=preload("res://scripts/catalog.gd")
const ToyCatalog=preload("res://scripts/toy_catalog.gd")

static func migrate(state: Dictionary) -> bool:
	if not state.has("chapter_events"): state.chapter_events={"used":[],"history":[]}
	var value: Variant=state.chapter_events
	if not value is Dictionary or not value.get("used",null) is Array or not value.get("history",null) is Array: return false
	var seen: Array=[]
	for chapter: Variant in value.used:
		if not chapter is int or chapter not in range(1,5) or chapter in seen: return false
		seen.append(chapter)
	for entry: Variant in value.history:
		if not entry is Dictionary or entry.get("chapter",0) not in seen or entry.get("choice","") not in ["repair","fish","exchange","skip"]: return false
	return true

static func status(state: Dictionary) -> Dictionary:
	var stage: int=int(state.get("stage",0))
	@warning_ignore("integer_division") # Chapter boundaries use the existing truncated four-stage quotient.
	var chapter: int=clampi(stage/4,1,4)
	var used: Array=state.get("chapter_events",{}).get("used",[])
	var available: bool=state.get("phase","")=="prep" and stage in [4,8,12,16] and stage-1 in state.get("settled",[]) and chapter not in used
	var known: Array[String]=[]
	for item: Dictionary in state.get("items",{}).values():
		var kind: String=str(item.get("kind",""))
		if kind in Data.fish_kinds() and kind not in known: known.append(kind)
	known.sort()
	var duplicates: Array[String]=[]
	var eligible: Array[String]=[]
	for id: String in Data.toys():
		if int(state.get("toys",{}).get(id,0))>=2: duplicates.append(id)
		if not state.get("toys",{}).has(id): eligible.append(id)
	eligible.sort();duplicates.sort()
	var offers: Array[String]=[]
	# Seeded ordering is read-only: opening/closing the stall cannot reroll any stream.
	var index: int=posmod(int(state.get("seed",0))+chapter*17,maxi(1,eligible.size()))
	for _i: int in range(mini(2,eligible.size())):
		offers.append(eligible.pop_at(index%eligible.size()))
	return {"available":available,"chapter":chapter,"title":["巷口三家摊","旧货街夜市","洗衣房后门","月下最后一站"][chapter-1],"repair_cost":20+(chapter-1)*6,"repair_amount":maxf(0,minf(float(state.get("max_hp",300))*.20,float(state.get("max_hp",300))-float(state.get("hp",300)))),"fish_cost":18+(chapter-1)*4,"fish_level":2 if chapter<3 else 3,"known_fish":known,"exchange_choices":offers,"duplicates":duplicates}

static func resolve(run: RefCounted,args: Dictionary) -> Dictionary:
	var state: Dictionary=run.s
	var offer: Dictionary=status(state)
	if not bool(offer.available): return {"ok":false,"message":"本次章间奇遇已经结束"}
	var choice: String=str(args.get("choice",""))
	var message: String=""
	match choice:
		"skip": message="带着猫咪继续出发"
		"repair":
			if float(offer.repair_amount)<=0: return {"ok":false,"message":"家已经完好，不用花钱"}
			if int(state.gold)<int(offer.repair_cost): return {"ok":false,"message":"修理费不够，先留住金币"}
			run.change_gold(-int(offer.repair_cost),"chapter_spend")
			state.hp=minf(float(state.max_hp),float(state.hp)+float(offer.repair_amount))
			message="修好了 %.0f 点耐久" % float(offer.repair_amount)
		"fish":
			var kind: String=str(args.get("kind",""))
			if kind not in offer.known_fish: return {"ok":false,"message":"鱼贩只能照着已拥有的鱼配货"}
			if int(state.gold)<int(offer.fish_cost): return {"ok":false,"message":"金币不够"}
			if int(run.shop_status().count)>=int(run.shop_status().capacity): return {"ok":false,"message":"库存已满，请先整理"}
			run.change_gold(-int(offer.fish_cost),"chapter_spend")
			run.create_item(kind,0,int(offer.fish_level),int(offer.fish_cost),"inventory")
			message="收到白色 Lv.%d %s" % [int(offer.fish_level),Data.fish_name(kind)]
		"exchange":
			var give: String=str(args.get("give",""))
			var take: String=str(args.get("take",""))
			if give not in offer.duplicates or take not in offer.exchange_choices: return {"ok":false,"message":"选一件重复玩具，换摊上的新玩具"}
			state.toys[give]=int(state.toys[give])-1
			state.toys[take]=1
			state.recent_toy=take;state.recent_toy_stage=int(state.stage)
			run.events.append({"type":"toy_acquired","id":take,"stacks":1})
			message="%s换成了%s" % [Data.toys()[give].name,Data.toys()[take].name]
		_: return {"ok":false,"message":"请选择一间摊位，或直接出发"}
	state.chapter_events.used.append(int(offer.chapter))
	state.chapter_events.history.append({"chapter":int(offer.chapter),"choice":choice,"stage":int(state.stage),"message":message})
	run.events.append({"type":"chapter_choice","choice":choice,"chapter":int(offer.chapter),"message":message})
	return {"ok":true,"message":message}
