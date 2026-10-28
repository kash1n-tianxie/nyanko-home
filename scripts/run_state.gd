extends RefCounted
## Ownership, single-charge transactions, phase transitions and durable run saves.
const Data = preload("res://scripts/catalog.gd")
const Battle = preload("res://scripts/combat.gd")
const Growth = preload("res://scripts/growth_economy.gd")
const BasketCapacity = preload("res://scripts/basket_capacity.gd")
const FeedbackLedger = preload("res://scripts/feedback_ledger.gd")
const Progress = preload("res://scripts/campaign_progress.gd")
const ChapterEvents = preload("res://scripts/chapter_events.gd")
const Toys = preload("res://scripts/toy_catalog.gd")
const CampShop=preload("res://scripts/camp_shop.gd")
const EncounterChoice=preload("res://scripts/encounter_choice.gd")
const BALANCE_VERSION: int=41
const SAVE_PATH: String = "user://cat_tree_v02.save"
var s: Dictionary = {}
var events: Array = []
var autosave: bool = false
var save_path: String = SAVE_PATH
var combat: RefCounted
var _save_clock: float = 0.0

func new_run(run_seed: int = 20261014, cat_id: String = "C01", choose_gift: bool = false, difficulty: String = "easy") -> void:
	if not Data.cats().has(cat_id): cat_id = "C01"
	if difficulty not in Progress.DIFFICULTIES: difficulty = "easy"
	var previous_profile: Dictionary = _retained_profile()
	s = {"schema":2,"growth_version":Growth.VERSION,"stage_casts":{},"campaign_stages":Data.total_stages(),"campaign_version":30,"toys":{},"toy_revives_used":0,"reward_choices":[],"route_from":0,"route_to":0,"combat_speed":1.0,"mode":"cat_tree","seed":run_seed,"phase":"prep","paused":false,"stage":0,"gold":24,"hq":1,"applied_hq":1,"hp":300.0,"max_hp":300.0,"owned":[cat_id],"active":[cat_id],"initial_cat":cat_id,"items":{},"next_item":1,"pending":"","cast_left":0.0,"visitors":[],"pending_recruits":[],"legacy_recruit_debt":0,"battle":{},"receipts":{},"tx_seq":0,"rng":{},"settled":[],"ledger":[],"stage_reports":[],"stats":{"kill_gold":0,"bonus_gold":0,"sell_gold":0,"fish_spend":0,"hq_spend":0,"casts":0,"kills":0,"primary":{},"extra":{},"absorbed":0.0,"incoming":0.0,"lost_hp":0.0,"max_enemies":0,"spawned":0,"truncated_hits":0},"tutorial_step":0,"initial_fish_choices":[],"attack_mode":"auto","aim_x":600.0,"aim_y":480.0}
	s.balance_version = BALANCE_VERSION
	s.chapter_events = {"used":[],"history":[]}
	s.difficulty = difficulty
	s.difficulty_locked = false
	s.cat_priorities = {}
	s.directed_bait = {"target":{},"used_chapters":[]}
	Progress.begin(s,previous_profile)
	for stream: String in ["fishing","combat","visitor","reward","stage"]:
		var generator := RandomNumberGenerator.new()
		generator.seed = run_seed + ["fishing","combat","visitor","reward","stage"].find(stream)*104729
		s.rng[stream] = generator.state
	s.stats["hp_loss_by_enemy"] = {}
	s.stats["incoming_by_enemy"] = {}
	s.stats["damage_by_source"] = {}
	s.stats["shield_by_cat"] = {}
	FeedbackLedger.begin(self)
	if choose_gift:
		s.phase = "initial_fish"
		var favorites: Array = Data.cats()[cat_id].favorites
		s.initial_fish_choices.append(favorites[rand_index("reward",favorites.size())])
		var pool: Array = Data.fish_kinds()
		pool.erase(s.initial_fish_choices[0])
		for _choice: int in range(2): s.initial_fish_choices.append(pool.pop_at(rand_index("reward",pool.size())))
		# Shuffle presentation without consuming fishing/combat/visitor randomness.
		for index: int in range(2,0,-1):
			var other: int = rand_index("reward",index+1)
			var previous: String = s.initial_fish_choices[index]
			s.initial_fish_choices[index] = s.initial_fish_choices[other]
			s.initial_fish_choices[other] = previous
		s.initial_fish_pool = s.initial_fish_choices.duplicate()
		s.initial_fish_favorite_slot = s.initial_fish_choices.find(Data.starter_fish(cat_id))
	else:
		_give_initial_fish(Data.starter_fish(cat_id))
	CampShop.migrate(self)
	EncounterChoice.migrate(s)
	combat = Battle.new()
	combat.setup(self)
	Progress.observe(s)
	events.clear()
	if autosave: save(save_path)

func shop_status() -> Dictionary:
	return CampShop.status(self)

func encounter_status() -> Dictionary:
	return EncounterChoice.status(self)

func meal_status() -> Dictionary:
	# Compatibility shape for old save readers; emergency feeding is retired.
	return {"prepared":false,"used":false,"item":{},"cat":"","slot":-1,"busy":false,"left":0.0}

func _clear_meal() -> void:
	# Reserved fish remain owned and available; an in-flight legacy meal is cancelled.
	for fish: Dictionary in s.items.values(): fish.reserved=false
	s.meal=CampShop.empty_meal()

func _give_initial_fish(kind: String) -> void:
	var gift: Dictionary = create_item(kind,0,1,0,"equipped")
	gift.cat = s.initial_cat
	gift.slot = 0

func roll(stream: String) -> float:
	var generator := RandomNumberGenerator.new()
	generator.state = s.rng[stream]
	var result: float = generator.randf()
	s.rng[stream] = generator.state
	return result

func rand_index(stream: String, count: int) -> int:
	return mini(count-1,floori(roll(stream)*count))

func weighted(stream: String, weights: Array) -> int:
	# randf includes 1.0; clamp the upper endpoint so zero-weight tail bins stay impossible.
	var sample: float = minf(99.999999999,roll(stream)*100.0)
	var total: float = 0.0
	for i: int in range(weights.size()):
		total += float(weights[i])
		if sample<total: return i
	return weights.size()-1

func item(id: String) -> Dictionary:
	return s.get("items",{}).get(id,{})

func equipped(cat_id: String) -> Array:
	var result: Array = [{},{},{}]
	for value: Dictionary in s.items.values():
		if value.location=="equipped" and value.cat==cat_id: result[int(value.slot)] = value
	return result

func effective(value: Dictionary, cat_id: String) -> int:
	return Data.effective(value,cat_id)

func in_location(location: String) -> Array:
	return s.items.values().filter(func(value: Dictionary) -> bool: return value.location==location)

func loose_count() -> int:
	var count: int = 0
	for value: Dictionary in s.items.values():
		if value.location in ["pending","basket","inventory"]: count += 1
	return count

func basket_count() -> int:
	return BasketCapacity.count(s.get("items",{}))

func basket_capacity() -> int:
	return BasketCapacity.for_hq(int(s.get("hq",1)))

func can_cast_capacity() -> bool:
	return BasketCapacity.has_space(s.get("items",{}),int(s.get("hq",1)))

func cast_cost() -> int:
	return normal_cast_cost()+(Growth.DIRECTED_SURCHARGE if _bait_is_armed() else 0)

func normal_cast_cost() -> int:
	return Growth.cast_cost(int(s.get("hq",1)),int(s.get("stage_casts",{}).get(int(s.get("stage",0)),0)))

func current_chapter() -> int:
	return clampi(floori(float(s.get("stage",0))/4.0)+1,1,5)

func _bait_is_armed() -> bool:
	var bait: Dictionary = s.get("directed_bait",{})
	var target: Dictionary = bait.get("target",{})
	return int(target.get("chapter",0))==current_chapter() and current_chapter() not in bait.get("used_chapters",[]) and not target.is_empty()

func bait_status() -> Dictionary:
	var bait: Dictionary = s.get("directed_bait",{})
	var target: Dictionary = bait.get("target",{})
	var used: bool = current_chapter() in bait.get("used_chapters",[])
	var armed: bool = _bait_is_armed()
	var usable: bool = not used and int(s.get("stage",0))<Data.last_stage()
	var description: String = "每章一次 · 选一条已拥有鱼干，下次钓获同鱼种同品质，等级仍按大本营概率。"
	if used: description = "本章定向鱼饵已使用；下一章补充一次。"
	elif not usable: description = "最终关无法钓鱼。"
	elif armed: description = "下竿锁定%s · %s；额外%d金币，等级仍随机。" % [Data.fish_name(str(target.kind)),Data.QUALITIES[int(target.quality)],Growth.DIRECTED_SURCHARGE]
	return {"available":usable,"armed":armed,"used":used,"kind":str(target.get("kind","")) if armed else "","quality":int(target.get("quality",0)) if armed else 0,"cost":cast_cost(),"normal_cost":normal_cast_cost(),"surcharge":Growth.DIRECTED_SURCHARGE,"chapter":current_chapter(),"description":description}

func can_choose_difficulty() -> bool:
	return s.get("phase","") in ["initial_fish","prep"] and int(s.get("stage",0))==0 and not bool(s.get("difficulty_locked",false)) and s.get("settled",[]).is_empty() and s.get("battle",{}).is_empty()

func campaign_goals() -> Array:
	return Progress.goals(s)

func codex_status() -> Dictionary:
	return Progress.codex(s)

func challenge_status() -> Array:
	return Progress.challenges(s)

func discover_enemy(kind: String) -> void:
	if kind in s.get("campaign_progress",{}).get("profile",{}).get("discovered",{}).get("enemies",[]): return
	if Data.enemies().has(kind): Progress.discover(s,"enemies",kind)

func recruit_choices() -> Array:
	return s.get("pending_recruits",[]).duplicate()

func _offer_recruits() -> void:
	s.pending_recruits = []
	s.visitors = []
	if s.owned.size()>=5: return
	var candidates: Array = Data.cats().keys().filter(func(id: String) -> bool: return id not in s.owned)
	for _index: int in range(mini(2,candidates.size())):
		s.pending_recruits.append(candidates.pop_at(rand_index("visitor",candidates.size())))
	# Kept as a compatibility alias for older presentation code, never a phase.
	s.visitors = s.pending_recruits.duplicate()

func create_item(kind: String, quality: int, level: int, paid_basis: int, location: String) -> Dictionary:
	var id: String = "fish_%06d" % int(s.next_item)
	s.next_item += 1
	var value: Dictionary = {"id":id,"kind":kind,"quality":quality,"level":level,"paid_basis":paid_basis,"location":location,"cat":"","slot":-1}
	s.items[id] = value
	return value

func command(action: String, args: Dictionary = {}, txid: String = "") -> Dictionary:
	if not txid.is_empty() and s.receipts.has(txid): return s.receipts[txid].duplicate(true)
	if s.paused and action!="pause": return _result(false,"已暂停，继续后再操作")
	# Dragging aim is transient input: periodic combat saves persist it, without
	# duplicating the whole simulation or writing a receipt on every mouse move.
	if action=="aim": return _execute(action,args)
	var before: Dictionary = s.duplicate(true) if autosave else {}
	var event_size: int = events.size()
	var result: Dictionary = _execute(action,args)
	if result.ok: Progress.observe(s)
	if txid.is_empty():
		s.tx_seq += 1
		txid = "local_%d" % int(s.tx_seq)
	s.receipts[txid] = result.duplicate(true)
	if result.ok and autosave and not save(save_path):
		s = before
		events.resize(event_size)
		return _result(false,"存档未写入，本次操作已撤销")
	return result

func _result(ok: bool, message: String) -> Dictionary:
	return {"ok":ok,"message":message}

func _execute(action: String, args: Dictionary) -> Dictionary:
	var prep: bool = s.phase=="prep"
	var fighting: bool = s.phase in ["combat","cleanup"]
	if action in ["meal_prepare","meal_clear","meal_use"]: return _result(false,"紧急投喂已关闭，请在休整时装配鱼干")
	if action in ["cast","keep","skip","bait_target"]: return _result(false,"钓鱼已改为关间鱼摊，回家购买鱼干")
	if action in ["sell","upgrade","recruit","merge","merge_all","equip","unequip","active","shop_buy","shop_refresh","shop_lock","shop_auto_merge","shop_order"] and not prep:
		return _result(false,"回家后才能经营和装配")
	if action.begins_with("shop_"): return CampShop.command(self,action,args)
	match action:
		"encounter_choice": return EncounterChoice.command(self,args)
		"cat_skill":
			if not fighting: return _result(false,"战斗中才能使用技能")
			if s.phase=="cleanup" and combat.enemies().is_empty() and int(s.battle.next_spawn)>=s.battle.schedule.size(): return _result(false,"敌人已清空，正在结算")
			return combat.skills.cast(str(args.get("cat","")))
		"chapter_event":
			return ChapterEvents.resolve(self,args)
		"track_build":
			var target: String=str(args.get("id",""))
			if target not in ["popcorn","meteor","fortress"]: return _result(false,"没有这个构筑目标")
			s.campaign_progress.profile.tracked_build=target
			return _result(true,"下一次，试试这套")
		"difficulty":
			var selected: String = str(args.get("difficulty",args.get("id","")))
			if not can_choose_difficulty(): return _result(false,"难度在本局首次出门前选择，出发后锁定")
			if selected not in Progress.DIFFICULTIES: return _result(false,"请选择简单、困难或地狱")
			s.difficulty = selected
			return _result(true,"难度已选择 · "+{"easy":"简单","hard":"困难","hell":"地狱"}[selected])
		"cat_priority":
			var cat_id: String = str(args.get("cat",""))
			var priority: String = str(args.get("priority",""))
			if not prep or cat_id not in s.owned: return _result(false,"休整时选择已招募猫咪的攻击倾向")
			if priority not in ["nearest","air","threat"]: return _result(false,"无效攻击倾向")
			s.cat_priorities[cat_id] = priority
			return _result(true,"攻击倾向 · "+{"nearest":"最近敌人","air":"优先空中","threat":"优先高威胁"}[priority])
		"switch_initial_cat":
			var cat_id: String = str(args.get("cat",""))
			if s.phase!="initial_fish" or int(s.stage)!=0 or int(s.hq)!=1 or not s.items.is_empty() or not s.battle.is_empty() or s.owned.size()!=1 or s.active.size()!=1:
				return _result(false,"出发前选鱼时才能更换伙伴")
			if not Data.cats().has(cat_id): return _result(false,"没有这位猫咪伙伴")
			# Keep this run's original three choices. Replacing only the favorite
			# slot is reversible and consumes no RNG, so switching cannot reroll.
			if not s.has("initial_fish_pool"):
				s.initial_fish_pool = s.initial_fish_choices.duplicate()
				s.initial_fish_favorite_slot = s.initial_fish_choices.find(Data.starter_fish(str(s.initial_cat)))
			var choices: Array = s.initial_fish_pool.duplicate()
			var favorite: String = Data.starter_fish(cat_id)
			if favorite not in choices: choices[clampi(int(s.initial_fish_favorite_slot),0,2)] = favorite
			s.initial_cat = cat_id
			s.owned = [cat_id]
			s.active = [cat_id]
			s.initial_fish_choices = choices
			return _result(true,"")
		"choose_fish":
			var kind: String = str(args.get("kind",""))
			if s.phase!="initial_fish" or kind not in s.get("initial_fish_choices",[]): return _result(false,"请选择这一局的小鱼干")
			_give_initial_fish(kind)
			s.erase("initial_fish_pool")
			s.erase("initial_fish_favorite_slot")
			s.initial_fish_choices.clear()
			s.phase = "prep"
			CampShop.enter(self)
			return _result(true,"")
		"combat_speed":
			if not prep and not fighting: return _result(false,"战斗与休整时可以调整速度")
			var speeds: Array = [1.0,1.5,2.0]
			var current: int = speeds.find(float(s.get("combat_speed",1.0)))
			s.combat_speed = speeds[(current+1)%speeds.size()]
			return _result(true,"")
		"reward_choose":
			var toy_id: String = str(args.get("id",""))
			if s.phase!="toy_reward" or toy_id not in s.get("reward_choices",[]): return _result(false,"请选择当前奖励中的一个玩具")
			if Toys.is_capped(toy_id,int(s.toys.get(toy_id,0))): return _result(false,"这件玩具已到效果上限，请选择其他奖励")
			s.toys[toy_id] = int(s.toys.get(toy_id,0))+1
			s.recent_toy = toy_id
			s.recent_toy_stage = int(s.get("route_to",int(s.stage)+1))
			s.reward_choices = []
			s.phase = "route"
			events.append({"type":"toy_acquired","id":toy_id,"stacks":s.toys[toy_id]})
			events.append({"type":"route"})
			return _result(true,"")
		"route_continue":
			if s.phase!="route": return _result(false,"请先完成这一关")
			if int(s.route_to)>=Data.total_stages():
				s.phase = "victory"
				Progress.victory(s)
				events.append({"type":"victory"})
			else:
				s.stage = int(s.route_to)
				s.phase = "prep"
				s.battle = {}
				CampShop.enter(self)
				events.append({"type":"settlement"})
			return _result(true,"")
		"attack_mode":
			var mode: String = str(args.get("mode",""))
			if not prep and not fighting: return _result(false,"当前无法切换攻击模式")
			if mode not in ["auto","manual"]: return _result(false,"无效攻击模式")
			s.attack_mode = mode
			return _result(true,"")
		"aim":
			if not fighting or s.get("attack_mode","auto")!="manual": return _result(false,"请先切换手动攻击")
			var point: Variant = args.get("x",null)
			if not (point is float or point is int) or not is_finite(float(point)): return _result(false,"无效瞄准位置")
			var height: Variant=args.get("y",s.get("aim_y",480.0))
			if not (height is float or height is int) or not is_finite(float(height)): return _result(false,"无效瞄准位置")
			s.aim_x = clampf(float(point),350.0,1280.0)
			s.aim_y = clampf(float(height),140.0,505.0)
			return _result(true,"")
		"pause":
			s.paused = not s.paused
			return _result(true,"暂停" if s.paused else "继续守家")
		"start":
			if not prep or s.active.is_empty(): return _result(false,"请先完成休整和来访选择")
			if not recruit_choices().is_empty(): return _result(false,"先选择新伙伴再出门")
			if str(s.meal.cat)!="" and str(s.meal.cat) not in s.active: _clear_meal()
			if bool(chapter_event_status().available): ChapterEvents.resolve(self,{"choice":"skip"})
			s.difficulty_locked = true
			Progress.start_stage(s)
			s.phase = "combat"
			combat.start_stage()
			events.append({"type":"stage_start"})
			return _result(true,"守住猫爬架！")
		"sell":
			var value: Dictionary = item(str(args.get("id",s.pending)))
			if value.is_empty(): return _result(false,"这条鱼已经不在了")
			if bool(value.get("reserved",false)): return _result(false,"这条鱼已放入餐盒，先收起餐盒")
			var can_sell: bool = prep and value.location in ["inventory","inbox"]
			if not can_sell: return _result(false,"回家后选择闲置鱼干出售")
			var refund: int = Growth.refund(int(value.paid_basis))
			if value.id==s.pending:
				s.pending = ""
				s.cast_left = 0.0
			s.items.erase(value.id)
			change_gold(refund,"sell_gold")
			return _result(true,"回收 +%d 金币" % refund)
		"upgrade":
			if not prep and not fighting and s.phase!="visit": return _result(false,"当前阶段无法升级")
			if int(s.hq)>=5: return _result(false,"大本营已经满级")
			if not recruit_choices().is_empty(): return _result(false,"先选一只新伙伴")
			var cost: int = Data.hq(int(s.hq)+1).cost
			if int(s.gold)<cost: return _result(false,"升级需要 %d 金币" % cost)
			change_gold(-cost,"hq_spend")
			s.hq += 1
			_offer_recruits()
			if not fighting: _apply_hq()
			events.append({"type":"upgrade"})
			return _result(true,"鱼篓、概率和猫位已升级；耐久%s生效" % ("已经" if not fighting else "休整时"))
		"equip":
			if not prep: return _result(false,"休整时才能装配")
			var value: Dictionary = item(str(args.get("id","")))
			var cat_id: String = str(args.get("cat",""))
			var slot: int = int(args.get("slot",-1))
			if value.is_empty() or value.location not in ["inventory","inbox"] or cat_id not in s.owned or slot<0 or slot>2: return _result(false,"请选择库存鱼干和有效猫咪槽位")
			if bool(value.get("reserved",false)): return _result(false,"先收起餐盒再装配这条鱼")
			for existing: Dictionary in equipped(cat_id):
				if not existing.is_empty() and existing.kind==value.kind and int(existing.slot)!=slot: return _result(false,"同一只猫不能装两份同名鱼干")
			var previous: Dictionary = equipped(cat_id)[slot]
			if not previous.is_empty():
				if loose_count()>=128 and value.location=="inbox": return _result(false,"库存已满，请先整理")
				previous.location = "inventory"
				previous.cat = ""
				previous.slot = -1
			if str(s.meal.cat)==cat_id: _clear_meal()
			value.location = "equipped"
			value.cat = cat_id
			value.slot = slot
			return _result(true,"已装配 · %s" % Data.cats()[cat_id].name)
		"unequip":
			var value: Dictionary = item(str(args.get("id","")))
			if not prep or value.is_empty() or value.location!="equipped" or CampShop.count(self)>=int(s.hq)*5: return _result(false,"仅休整且鱼篓有空间时可取下")
			value.location = "inventory"
			value.cat = ""
			value.slot = -1
			return _result(true,"已取下")
		"merge":
			if not prep and not fighting: return _result(false,"当前阶段无法合成")
			var first: Dictionary = item(str(args.get("id","")))
			var second: Dictionary = item(str(args.get("other","")))
			if first.is_empty() or second.is_empty() or first.id==second.id: return _result(false,"需要两份不同实例")
			if bool(first.get("reserved",false)) or bool(second.get("reserved",false)): return _result(false,"餐盒鱼不会参与合成")
			if first.location=="equipped" and second.location=="equipped": return _result(false,"不能消耗两只猫身上已装配的鱼")
			if second.location=="equipped":
				var swap: Dictionary=first;first=second;second=swap
			var locations: Array = ["inventory","equipped","inbox","basket"] if prep else ["inventory","inbox","basket"]
			if first.location not in locations or second.location not in locations: return _result(false,"战斗中只能合成未装配的鱼干")
			if int(first.level)>=5 or first.kind!=second.kind or first.quality!=second.quality or first.level!=second.level: return _result(false,"必须同名、同品质、同实际等级，最高5级")
			if (first.location=="equipped" or second.location=="equipped") and not args.get("confirm",false): return _result(false,"合成会消耗已装配鱼干，需要确认")
			first.level += 1
			first.paid_basis += second.paid_basis
			s.items.erase(second.id)
			events.append({"type":"merge"})
			return _result(true,"合成成功 · 实际 Lv.%d" % int(first.level))
		"merge_all":
			if not prep and not fighting: return _result(false,"当前阶段无法合成")
			var merged: int = _merge_all_loose(prep)
			if merged<=0: return _result(false,"没有可合成的鱼干")
			events.append({"type":"merge_all","count":merged})
			return {"ok":true,"message":"合成 %d 次" % merged,"merged":merged}
		"active":
			if not prep: return _result(false,"休整时才能更换出战猫")
			var selected: Array = args.get("cats",[])
			if selected.is_empty() or selected.size()>int(Data.hq(s.hq).slots): return _result(false,"超过当前出战位，或未选择猫咪")
			var seen: Array = []
			for cat_id: String in selected:
				if cat_id not in s.owned or cat_id in seen: return _result(false,"出战名单无效")
				seen.append(cat_id)
			s.active = selected.duplicate()
			if str(s.meal.cat) not in s.active: _clear_meal()
			return _result(true,"出战阵容已更新")
		"recruit":
			var cat_id: String = str(args.get("cat",""))
			if not prep and not fighting and s.phase!="visit": return _result(false,"当前无法招猫")
			if cat_id not in recruit_choices() or cat_id in s.owned or s.owned.size()>=5: return _result(false,"请选择这次来访猫")
			s.owned.append(cat_id)
			if s.active.size()<int(Data.hq(s.hq).slots):
				s.active.append(cat_id)
				if fighting: combat.add_cat(cat_id)
			s.pending_recruits = []
			s.visitors.clear()
			if s.phase=="visit": s.phase = "prep"
			if int(s.get("legacy_recruit_debt",0))>0:
				s.legacy_recruit_debt = maxi(0,int(s.legacy_recruit_debt)-1)
				if s.owned.size()>=5: s.legacy_recruit_debt = 0
				elif int(s.legacy_recruit_debt)>0: _offer_recruits()
			events.append({"type":"recruit","cat":cat_id})
			return _result(true,"%s住进来了！" % Data.cats()[cat_id].name)
	return _result(false,"未知操作")

func _merge_all_loose(allow_equipped: bool) -> int:
	# Stable id ordering makes one-click compaction deterministic and replayable.
	# Paid pending catches are never touched. In rest, upgrade an equipped
	# fish in place using one loose material; never consume two equipped fish.
	var merged: int = 0
	while true:
		var groups: Dictionary = {}
		var pair: Array = []
		var ids: Array = s.items.keys()
		ids.sort()
		if allow_equipped:
			for id: String in ids:
				var equipped_fish: Dictionary = item(id)
				if equipped_fish.location!="equipped" or int(equipped_fish.level)>=5: continue
				for material_id: String in ids:
					var material: Dictionary = item(material_id)
					if material.location not in ["inventory","inbox","basket"] or bool(material.get("reserved",false)): continue
					if material.kind==equipped_fish.kind and material.quality==equipped_fish.quality and material.level==equipped_fish.level:
						pair = [id,material_id]
						break
				if not pair.is_empty(): break
		for id: String in ids:
			if not pair.is_empty(): break
			var value: Dictionary = item(id)
			if value.location not in ["inventory","inbox","basket"] or bool(value.get("reserved",false)) or int(value.level)>=5: continue
			var key: String = "%s_%d_%d" % [value.kind,int(value.quality),int(value.level)]
			if groups.has(key):
				pair = [groups[key],id]
				break
			groups[key] = id
		if pair.is_empty(): break
		var first: Dictionary = item(pair[0])
		var second: Dictionary = item(pair[1])
		first.level += 1
		first.paid_basis += second.paid_basis
		# A new catch remains in the basket until the current battle has ended.
		if first.location!="equipped" and second.location=="basket": first.location = "basket"
		s.items.erase(second.id)
		merged += 1
	return merged

func _keep_pending() -> void:
	if s.pending!="" and not item(s.pending).is_empty(): item(s.pending).location = "basket"
	s.pending = ""
	s.cast_left = 0.0

func change_gold(amount: int, category: String) -> void:
	s.gold += amount
	s.stats[category] = int(s.stats.get(category,0))+absi(amount)
	s.ledger.append({"stage":s.stage,"category":category,"amount":amount,"balance":s.gold})

func _apply_hq() -> void:
	var new_hp: float = Data.hq(s.hq).hp
	s.hp = minf(new_hp,float(s.hp)+new_hp-float(s.max_hp))
	s.max_hp = new_hp
	s.applied_hq = s.hq

func settle_stage() -> void:
	if s.phase not in ["combat","cleanup"] or combat.skills.cinematic_busy(): return
	_clear_meal()
	if float(s.hp)<=0.0:
		combat.clear_boss_flights()
		combat.skills.clear()
		combat.expansion.clear_reactive_toys()
		s.phase = "failed"
		s.paused = false
		s.failure_feedback = FeedbackLedger.failure(self)
		s.last_feedback_report = s.failure_feedback.duplicate(true)
		events.append({"type":"failed"})
		return
	if int(s.stage) in s.settled: return
	combat.clear_boss_flights()
	combat.skills.clear()
	combat.expansion.clear_reactive_toys()
	var done: int = int(s.stage)
	Progress.settle_stage(s)
	s.settled.append(done)
	var risk_gold: int=EncounterChoice.victory_reward(self)
	if risk_gold>0:
		change_gold(risk_gold,"bonus_gold")
		events.append({"type":"risk_reward","gold":risk_gold,"stage":done})
	_keep_pending()
	for value: Dictionary in in_location("basket"): value.location = "inventory"
	var feedback: Dictionary = FeedbackLedger.report(self)
	var stats_before: Dictionary = FeedbackLedger.ensure(self).get("stats_before",{})
	s.last_feedback_report = feedback.duplicate(true)
	var stage_stats: Dictionary = FeedbackLedger.stats_delta(s.stats,stats_before)
	stage_stats.max_enemies = int(feedback.get("peak_enemies",0))
	s.stage_reports.append({"stage":done,"hp":s.hp,"gold":s.gold,"time":s.battle.get("time",0.0),"stats":stage_stats,"cumulative_stats":s.stats.duplicate(true),"feedback":feedback,"risk_reward":risk_gold})
	# Clear rewards are applied once, before the route. The stage index remains
	# on the completed encounter until route_continue commits the next stop.
	if done<Data.last_stage():
		change_gold(4,"bonus_gold")
		var kind: String = "F%02d" % (rand_index("reward",Data.FISH_NAMES.size())+1)
		if done==0: kind = Data.starter_fish(s.initial_cat)
		var reward_level: int = mini(3,1+floori(done/8.0))
		create_item(kind,0,reward_level,0,"inventory" if loose_count()<128 else "inbox")
	_apply_hq()
	if not Data.boss_for_stage(done).is_empty(): s.hp = minf(s.max_hp,float(s.hp)+80.0)
	s.route_from = done
	s.route_to = done+1
	s.paused = false
	var stage: Dictionary = Data.stages()[done]
	var choices: int = 4 if stage.rank=="boss" else (3 if stage.rank=="elite" else 0)
	s.reward_choices = []
	if choices>0:
		var pool: Array = Data.toys().keys().filter(func(id: String) -> bool: return not Toys.is_capped(id,int(s.toys.get(id,0))))
		# At least one new toy remains visible while unseen toys are available.
		var unseen: Array = pool.filter(func(id: String) -> bool: return not s.toys.has(id))
		if not unseen.is_empty():
			var first: String = unseen[rand_index("reward",unseen.size())]
			s.reward_choices.append(first)
			pool.erase(first)
		while s.reward_choices.size()<choices and not pool.is_empty():
			s.reward_choices.append(pool.pop_at(rand_index("reward",pool.size())))
		s.phase = "toy_reward"
	else:
		s.phase = "route"
	events.append({"type":"level_completed","stage":done,"rank":stage.rank})
	events.append({"type":"toy_reward" if choices>0 else "route"})
	if autosave: save(save_path)

func step(delta: float) -> void:
	if s.is_empty() or s.paused or s.phase not in ["combat","cleanup"]: return
	if combat.skills.cinematic_busy(): return
	combat.tick(delta)
	_save_clock += delta
	if autosave and _save_clock>=1.0:
		_save_clock = 0.0
		save(save_path)

func save(path: String = SAVE_PATH) -> bool:
	var bytes: PackedByteArray = var_to_bytes(s)
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null: return false
	file.store_var({"payload":bytes,"hash":hashing.finish()},false)
	file.flush()
	file.close()
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(absolute,absolute+".bak")
	return DirAccess.rename_absolute(absolute+".tmp",absolute)==OK

func load_save(path: String = SAVE_PATH) -> bool:
	for candidate: String in [path,path+".bak"]:
		if not FileAccess.file_exists(candidate): continue
		var file := FileAccess.open(candidate,FileAccess.READ)
		if file==null: continue
		var envelope: Variant = file.get_var(false)
		file.close()
		if not envelope is Dictionary or not envelope.has("payload") or not envelope.has("hash"): continue
		var hashing := HashingContext.new()
		hashing.start(HashingContext.HASH_SHA256)
		hashing.update(envelope.payload)
		if hashing.finish()!=envelope.hash: continue
		var restored: Variant = bytes_to_var(envelope.payload)
		if not restored is Dictionary or restored.get("schema",0)!=2 or restored.get("mode","")!="cat_tree": continue
		if not _migrate_campaign(restored): continue
		var old_growth: bool = int(restored.get("growth_version",0))<Growth.VERSION
		if not _migrate_growth(restored): continue
		if not _migrate_controls(restored): continue
		if not restored.get("active",[]) is Array: continue
		var previous_active: Array = restored.get("active",[]).duplicate()
		if not _migrate_recruits(restored): continue
		if not _migrate_v033(restored): continue
		if not ChapterEvents.migrate(restored): continue
		if not CampShop.validate(restored): continue
		if not EncounterChoice.migrate(restored): continue
		var old_balance: bool=int(restored.get("balance_version",0))<BALANCE_VERSION
		var team_trimmed: bool = previous_active!=restored.active
		var saved_stage: int = int(restored.get("stage",-1))
		if saved_stage<0 or saved_stage>=Data.total_stages(): continue
		var previous_total: int = int(restored.get("campaign_stages",9))
		if previous_total<=0 or previous_total>Data.total_stages(): continue
		s = restored
		CampShop.migrate(self)
		_clear_meal()
		FeedbackLedger.ensure(self)
		if not s.has("last_feedback_report"): s.last_feedback_report = {}
		if not s.has("failure_feedback"): s.failure_feedback = {}
		s.campaign_stages = Data.total_stages()
		if s.phase=="victory" and saved_stage==previous_total-1 and previous_total<Data.total_stages():
			_extend_legacy_victory(previous_total)
		if int(s.get("legacy_recruit_debt",0))>0 and recruit_choices().is_empty() and s.phase in ["prep","combat","cleanup"]: _offer_recruits()
		combat = Battle.new()
		combat.setup(self)
		if old_balance:
			for cat: Dictionary in s.get("battle",{}).get("cats",[]):
				if Data.cats().has(str(cat.id)):
					cat.base_attack=float(Data.cats()[cat.id].attack)
					for key: String in ["interval","range","speed"]:
						cat[key]=Data.cats()[cat.id][key]
					combat._derive_cat_stats(cat)
		s.balance_version=BALANCE_VERSION
		if old_growth and not s.battle.is_empty(): combat.rebuild_cat_stats(true)
		elif team_trimmed and not s.battle.is_empty(): combat.refresh_team_bonuses()
		combat.migrate_fixed_bosses()
		combat.skills.migrate()
		events.clear()
		return true
	return false

func _migrate_growth(restored: Dictionary) -> bool:
	var version: int = int(restored.get("growth_version",0))
	if version>Growth.VERSION: return false
	if not restored.has("stage_casts"):
		restored.stage_casts = {}
		# Historical payments already reserved a fish. Reconstruct only the
		# number of casts, never reprice or refund those existing purchases.
		for entry: Dictionary in restored.get("ledger",[]):
			if entry.get("category","")=="fish_spend":
				var index: int = int(entry.get("stage",0))
				restored.stage_casts[index] = int(restored.stage_casts.get(index,0))+1
	if not restored.stage_casts is Dictionary: return false
	for count: Variant in restored.stage_casts.values():
		if not count is int or int(count)<0: return false
	if version<Growth.VERSION and restored.get("phase","")=="initial_fish":
		var choices: Array = restored.get("initial_fish_choices",[])
		var favorite: String = Data.starter_fish(str(restored.get("initial_cat","C01")))
		if choices.size()==3 and favorite not in choices: choices[2] = favorite
	restored.growth_version = Growth.VERSION
	return true

func _migrate_controls(restored: Dictionary) -> bool:
	# Schema 2 saves predate the opening choice and manual targeting. Preserve
	# their actual loadout and RNG, adding only inert presentation/input defaults.
	if not restored.has("attack_mode"): restored.attack_mode = "auto"
	if not restored.has("aim_x"): restored.aim_x = 600.0
	if not restored.has("initial_fish_choices"): restored.initial_fish_choices = []
	if restored.attack_mode not in ["auto","manual"]: return false
	if not (restored.aim_x is int or restored.aim_x is float) or not is_finite(float(restored.aim_x)): return false
	restored.aim_x = clampf(float(restored.aim_x),350.0,1280.0)
	if not restored.initial_fish_choices is Array: return false
	if restored.get("phase","")=="initial_fish":
		if restored.initial_fish_choices.size()!=3 or not Data.cats().has(restored.get("initial_cat","")): return false
		if not restored.get("items",{}).is_empty(): return false
		var seen: Array = []
		var has_favorite: bool = false
		for kind: Variant in restored.initial_fish_choices:
			if kind not in Data.fish_kinds() or kind in seen: return false
			seen.append(kind)
			has_favorite = has_favorite or kind in Data.cats()[restored.initial_cat].favorites
		if not has_favorite: return false
		if not restored.has("initial_fish_pool"):
			restored.initial_fish_pool = restored.initial_fish_choices.duplicate()
			restored.initial_fish_favorite_slot = restored.initial_fish_choices.find(Data.starter_fish(str(restored.initial_cat)))
		if not restored.initial_fish_pool is Array or restored.initial_fish_pool.size()!=3: return false
		var fixed_seen: Array = []
		for kind: Variant in restored.initial_fish_pool:
			if kind not in Data.fish_kinds() or kind in fixed_seen: return false
			fixed_seen.append(kind)
		if not restored.get("initial_fish_favorite_slot",null) is int or int(restored.initial_fish_favorite_slot) not in range(3): return false
	elif not restored.initial_fish_choices.is_empty(): return false
	return true

func _migrate_recruits(restored: Dictionary) -> bool:
	# Preserve owned cats and every fish in old saves, including over-full baskets.
	# Old noon visits become an inline choice; an extra sixth cat remains reserve.
	if not restored.get("owned",[]) is Array or not restored.get("active",[]) is Array: return false
	var legacy_recruit_rules: bool = not restored.has("pending_recruits")
	if legacy_recruit_rules:
		restored.legacy_recruit_debt = maxi(0,int(Data.hq(int(restored.get("hq",1))).slots)-restored.owned.size())
		restored.pending_recruits = restored.get("visitors",[]).slice(0,2) if restored.get("phase","")=="visit" else []
	if not restored.has("legacy_recruit_debt"): restored.legacy_recruit_debt = 0
	if not restored.legacy_recruit_debt is int or int(restored.legacy_recruit_debt)<0 or int(restored.legacy_recruit_debt)>4: return false
	if not restored.pending_recruits is Array or restored.pending_recruits.size()>2: return false
	var seen: Array = []
	for cat_id: Variant in restored.pending_recruits:
		if not Data.cats().has(cat_id) or cat_id in seen or cat_id in restored.owned: return false
		seen.append(cat_id)
	if restored.owned.size()>=5:
		restored.pending_recruits = []
		restored.legacy_recruit_debt = 0
	restored.visitors = restored.pending_recruits.duplicate()
	if restored.get("phase","")=="visit": restored.phase = "prep"
	var maximum: int = int(Data.hq(int(restored.get("hq",1))).slots)
	if restored.active.size()>maximum:
		restored.active = restored.active.slice(0,maximum)
		if restored.get("battle",{}).has("cats"):
			restored.battle.cats = restored.battle.cats.filter(func(cat: Dictionary) -> bool: return cat.id in restored.active)
	return true

func _extend_legacy_victory(previous_total: int) -> void:
	# Reserved for future campaign extensions: current v0.3 migration is handled
	# before assigning live state, and never awards duplicate clear rewards.
	s.stage = mini(previous_total,Data.last_stage())
	s.phase = "prep"
	s.paused = false
	s.battle = {}

func _migrate_campaign(restored: Dictionary) -> bool:
	var version: int = int(restored.get("campaign_version",0))
	if version>30: return false
	if not restored.has("toys"): restored.toys = {}
	if not restored.toys is Dictionary: return false
	for id: Variant in restored.toys:
		if not Data.toys().has(id) or not restored.toys[id] is int or int(restored.toys[id])<=0: return false
	if not restored.has("toy_revives_used"): restored.toy_revives_used = 0
	if not restored.toy_revives_used is int or int(restored.toy_revives_used)<0: return false
	if not restored.has("combat_speed"): restored.combat_speed = 1.0
	if float(restored.combat_speed) not in [1.0,1.5,2.0]: return false
	if not restored.has("reward_choices"): restored.reward_choices = []
	if not restored.reward_choices is Array: return false
	var seen: Array = []
	for id: Variant in restored.reward_choices:
		if not Data.toys().has(id) or id in seen: return false
		seen.append(id)
	if version<30:
		var old_stage: int = int(restored.get("stage",-1))
		var old_total: int = int(restored.get("campaign_stages",9))
		if old_stage<0 or old_stage>=old_total or old_total not in [9,12]: return false
		var mapped: int = floori(old_stage/3.0)*4+(3 if old_stage%3==2 else old_stage%3)
		if restored.get("phase","")=="victory": mapped = mini(Data.last_stage(),floori(old_total/3.0)*4)
		restored.stage = mapped
		# Combat timelines use a different enemy schema. Resume safely at the
		# same chapter's preparation, keeping paid catches, cats, gold and HP.
		if restored.get("phase","") in ["combat","cleanup","victory"]:
			restored.phase = "prep"
			restored.battle = {}
			restored.paused = false
			for value: Dictionary in restored.get("items",{}).values():
				if value.get("location","") in ["basket","pending"]: value.location = "inventory"
			restored.pending = ""
			restored.cast_left = 0.0
		var remapped_settled: Array = []
		for old_done: Variant in restored.get("settled",[]):
			var done: int = int(old_done)
			remapped_settled.append(floori(done/3.0)*4+(3 if done%3==2 else done%3))
		restored.settled = remapped_settled
		var historical_casts: Dictionary = restored.get("stage_casts",{}).duplicate()
		if not restored.has("stage_casts"):
			for entry: Dictionary in restored.get("ledger",[]):
				if entry.get("category","")=="fish_spend":
					var old_index: int = int(entry.get("stage",0))
					historical_casts[old_index] = int(historical_casts.get(old_index,0))+1
		var remapped_casts: Dictionary = {}
		for old_index: Variant in historical_casts:
			var index: int = int(old_index)
			remapped_casts[floori(index/3.0)*4+(3 if index%3==2 else index%3)] = historical_casts[old_index]
		restored.stage_casts = remapped_casts
		restored.reward_choices = []
		restored.route_from = mapped
		restored.route_to = mapped
		restored.campaign_stages = Data.total_stages()
	if not restored.has("route_from"): restored.route_from = int(restored.get("stage",0))
	if not restored.has("route_to"): restored.route_to = int(restored.get("stage",0))
	if restored.get("phase","")=="toy_reward":
		var index: int = int(restored.get("stage",-1))
		if index<0 or index>=Data.total_stages(): return false
		var count: int = 4 if Data.stages()[index].rank=="boss" else 3
		if restored.reward_choices.size()>count: return false
		# Saved offers may predate saturation filtering. Preserve legal choices,
		# replace only missing/capped slots without touching any future RNG stream.
		restored.reward_choices=restored.reward_choices.filter(func(id: String) -> bool: return not Toys.is_capped(id,int(restored.toys.get(id,0))))
		var available: Array=Data.toys().keys().filter(func(id: String) -> bool: return id not in restored.reward_choices and not Toys.is_capped(id,int(restored.toys.get(id,0))))
		available.sort()
		var pick: int=posmod(int(restored.get("seed",0))+index*131,maxi(1,available.size()))
		while restored.reward_choices.size()<count and not available.is_empty():
			restored.reward_choices.append(available.pop_at(pick%available.size()))
		# Future finite catalogs may have fewer than a full offer left. A short
		# legal offer is valid; an empty pool goes straight to the route.
		if restored.reward_choices.is_empty(): restored.phase="route"
	elif not restored.reward_choices.is_empty(): return false
	if restored.get("phase","") in ["route","toy_reward"] and int(restored.route_to)!=int(restored.stage)+1: return false
	restored.campaign_version = 30
	return true

func chapter_event_status() -> Dictionary:
	return ChapterEvents.status(s)

func current_feedback() -> Dictionary:
	return FeedbackLedger.report(self)

func _migrate_v033(restored: Dictionary) -> bool:
	if not restored.has("difficulty"): restored.difficulty = "easy"
	if restored.difficulty not in Progress.DIFFICULTIES: return false
	var started: bool = int(restored.get("stage",0))>0 or restored.get("phase","") not in ["initial_fish","prep"] or not restored.get("settled",[]).is_empty() or not restored.get("battle",{}).is_empty()
	if not restored.has("difficulty_locked"): restored.difficulty_locked = started
	if not restored.difficulty_locked is bool: return false
	if started: restored.difficulty_locked = true
	if not restored.has("cat_priorities"): restored.cat_priorities = {}
	if not restored.cat_priorities is Dictionary: return false
	for cat: Variant in restored.cat_priorities:
		if not Data.cats().has(cat) or restored.cat_priorities[cat] not in ["nearest","air","threat"]: return false
	if not restored.has("directed_bait"): restored.directed_bait = {"target":{},"used_chapters":[]}
	if not restored.directed_bait is Dictionary: return false
	var bait: Dictionary = restored.directed_bait
	if not bait.has("target"): bait.target = {}
	if not bait.has("used_chapters"): bait.used_chapters = []
	if not bait.target is Dictionary or not bait.used_chapters is Array: return false
	var seen: Array = []
	for chapter: Variant in bait.used_chapters:
		if not chapter is int or int(chapter) not in range(1,6) or chapter in seen: return false
		seen.append(chapter)
	if not bait.target.is_empty():
		if not bait.target.get("chapter",null) is int or int(bait.target.chapter) not in range(1,6): return false
		if bait.target.get("kind","") not in Data.fish_kinds(): return false
		if not bait.target.get("quality",null) is int or int(bait.target.quality) not in range(3): return false
		if int(bait.target.chapter) in bait.used_chapters: return false
	return Progress.migrate(restored)

func _retained_profile() -> Dictionary:
	# Discovery survives a deliberate new run, inside the same atomic save.
	# Save-isolated fixtures never read the player's file merely by creating a run.
	var current: Dictionary = s.get("campaign_progress",{}).get("profile",{})
	if Progress.valid_profile(current): return current.duplicate(true)
	if not autosave: return {}
	for candidate: String in [save_path,save_path+".bak"]:
		if not FileAccess.file_exists(candidate): continue
		var file: FileAccess = FileAccess.open(candidate,FileAccess.READ)
		if file==null: continue
		var envelope: Variant = file.get_var(false)
		file.close()
		if not envelope is Dictionary or not envelope.get("payload",null) is PackedByteArray or not envelope.get("hash",null) is PackedByteArray: continue
		var hashing := HashingContext.new()
		hashing.start(HashingContext.HASH_SHA256)
		hashing.update(envelope.payload)
		if hashing.finish()!=envelope.hash: continue
		var restored: Variant = bytes_to_var(envelope.payload)
		if not restored is Dictionary or restored.get("schema",0)!=2 or restored.get("mode","")!="cat_tree": continue
		var progress: Variant = restored.get("campaign_progress",{})
		if not progress is Dictionary or not progress.get("profile",{}) is Dictionary: continue
		var profile: Dictionary = progress.get("profile",{})
		if Progress.valid_profile(profile): return profile.duplicate(true)
	return {}
