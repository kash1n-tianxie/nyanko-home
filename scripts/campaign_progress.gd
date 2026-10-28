extends RefCounted
## Discovery and milestones share the run's atomic save. They never award stats or money.
const Data = preload("res://scripts/catalog.gd")
const VERSION: int = 34
const DIFFICULTIES: Array[String] = ["easy","hard","hell"]
const CHALLENGES: Array = [
	{"id":"first_mechanism","name":"第一口魔法","detail":"给出战猫装备一条生效3级鱼干"},
	{"id":"first_transformation","name":"猫饭大变身","detail":"给出战猫装备一条生效5级鱼干"},
	{"id":"hq_full","name":"五猫满屋","detail":"将大本营升到5级"},
	{"id":"first_clear","name":"月亮回家","detail":"任意难度通关20关"},
	{"id":"hard_clear","name":"硬仗家长","detail":"困难难度通关20关"},
	{"id":"hell_clear","name":"地狱铲屎官","detail":"地狱难度通关20关"},
	{"id":"no_revive_clear","name":"一条命的月亮","detail":"没有触发复活，完成一局"},
	{"id":"support_clear","name":"铃声带大家回家","detail":"带小铃完成最终战"},
	{"id":"all_cats","name":"六位老朋友","detail":"跨局招募或选择全部6只猫"},
	{"id":"all_fish","name":"十味猫饭","detail":"跨局收集全部10种鱼干"},
	{"id":"all_toys","name":"荒诞玩具柜","detail":"跨局收集全部荒诞玩具"}]

static func empty_profile() -> Dictionary:
	return {"discovered":{"cats":[],"fish":[],"toys":[],"enemies":[]},"victories":{"easy":0,"hard":0,"hell":0},"cat_victories":{},"challenges":[],"mementos":[],"tracked_build":"popcorn"}

static func empty_run() -> Dictionary:
	return {"first_lv3_stage":0,"first_lv5_stage":0,"hq5_stage":0,"first_lv3_cat":"","first_lv5_cat":"","first_lv3_fish":"","first_lv5_fish":"","observed_from_stage":1,"prior_lv3":false,"prior_lv5":false,"prior_hq5":false,"last_build":"","current_build":"","unchanged_streak":0,"max_unchanged_streak":0,"unchanged_transitions":0,"stages":[],"victory_recorded":false}

static func begin(state: Dictionary, previous_profile: Dictionary = {}) -> void:
	state.campaign_progress = {"version":VERSION,"profile":previous_profile.duplicate(true) if valid_profile(previous_profile) else empty_profile(),"run":empty_run()}
	if not state.campaign_progress.profile.has("mementos"): state.campaign_progress.profile.mementos=[]
	if not state.campaign_progress.profile.has("tracked_build"): state.campaign_progress.profile.tracked_build="popcorn"

static func valid_profile(profile: Dictionary) -> bool:
	if profile.get("tracked_build","popcorn") not in ["popcorn","meteor","fortress"]: return false
	if not profile.get("mementos",[]) is Array: return false
	var memories: Array=[]
	for chapter: Variant in profile.get("mementos",[]):
		if not chapter is int or chapter not in range(1,6) or chapter in memories: return false
		memories.append(chapter)
	if not profile.get("discovered",null) is Dictionary or not profile.get("victories",null) is Dictionary or not profile.get("cat_victories",null) is Dictionary or not profile.get("challenges",null) is Array: return false
	var catalogs: Dictionary = {"cats":Data.cats().keys(),"fish":Data.fish_kinds(),"toys":Data.toys().keys(),"enemies":Data.enemies().keys()}
	for category: String in catalogs:
		if not profile.discovered.get(category,null) is Array: return false
		var seen: Array = []
		for id: Variant in profile.discovered[category]:
			if not id is String or id not in catalogs[category] or id in seen: return false
			seen.append(id)
	for difficulty: String in DIFFICULTIES:
		if not profile.victories.get(difficulty,null) is int or int(profile.victories[difficulty])<0: return false
	for cat: Variant in profile.cat_victories:
		if not Data.cats().has(cat) or not profile.cat_victories[cat] is int or int(profile.cat_victories[cat])<0: return false
	var challenge_ids: Array = CHALLENGES.map(func(value: Dictionary) -> String: return str(value.id))
	var unique: Array = []
	for id: Variant in profile.challenges:
		if id not in challenge_ids or id in unique: return false
		unique.append(id)
	return true

static func migrate(state: Dictionary) -> bool:
	# Missing v0.3.3 metadata is inert. Never reconstruct unobserved clear milestones.
	if not state.has("campaign_progress"):
		begin(state)
		var imported_record: Dictionary = state.campaign_progress.run
		imported_record.observed_from_stage = clampi(int(state.get("stage",0))+1,1,Data.total_stages())
		# An imported save can prove a mechanism exists, not when it first formed.
		for item: Dictionary in state.get("items",{}).values():
			if item.get("location","")!="equipped" or item.get("cat","") not in state.get("active",[]): continue
			var level: int = Data.effective(item,str(item.cat))
			imported_record.prior_lv3 = bool(imported_record.prior_lv3) or level>=3
			imported_record.prior_lv5 = bool(imported_record.prior_lv5) or level>=5
		imported_record.prior_hq5 = int(state.get("hq",1))>=5
		observe(state)
		return true
	if not state.campaign_progress is Dictionary: return false
	var progress: Dictionary = state.campaign_progress
	if int(progress.get("version",0))>VERSION: return false
	if not progress.get("profile",null) is Dictionary or not valid_profile(progress.profile): return false
	if not progress.profile.has("mementos"): progress.profile.mementos=[]
	if not progress.profile.has("tracked_build"): progress.profile.tracked_build="popcorn"
	if not progress.get("run",null) is Dictionary: return false
	var record: Dictionary = progress.run
	for key: String in empty_run():
		if not record.has(key): record[key] = empty_run()[key]
	for key: String in ["first_lv3_stage","first_lv5_stage","hq5_stage"]:
		if not record[key] is int or int(record[key])<0 or int(record[key])>Data.total_stages(): return false
	if not record.observed_from_stage is int or int(record.observed_from_stage)<1 or int(record.observed_from_stage)>Data.total_stages(): return false
	for key: String in ["prior_lv3","prior_lv5","prior_hq5"]:
		if not record[key] is bool: return false
	for key: String in ["unchanged_streak","max_unchanged_streak","unchanged_transitions"]:
		if not record[key] is int or int(record[key])<0: return false
	for key: String in ["last_build","current_build","first_lv3_cat","first_lv5_cat","first_lv3_fish","first_lv5_fish"]:
		if not record[key] is String: return false
	if not record.stages is Array or not record.victory_recorded is bool: return false
	for entry: Variant in record.stages:
		if not entry is Dictionary or not entry.get("stage",null) is int or int(entry.stage)<1 or int(entry.stage)>Data.total_stages(): return false
	progress.version = VERSION
	return true

static func discover(state: Dictionary, category: String, id: String) -> void:
	if not state.has("campaign_progress"): begin(state)
	var discovered: Dictionary = state.campaign_progress.profile.discovered
	if not discovered.has(category): return
	if id not in discovered[category]: discovered[category].append(id)

static func _unlock(state: Dictionary, id: String) -> void:
	var list: Array = state.campaign_progress.profile.challenges
	if id not in list: list.append(id)

static func observe(state: Dictionary) -> void:
	if not state.has("campaign_progress"): begin(state)
	var record: Dictionary = state.campaign_progress.run
	var stage: int = clampi(int(state.get("stage",0))+1,1,Data.total_stages())
	for cat: String in state.get("owned",[]): discover(state,"cats",cat)
	for toy: String in state.get("toys",{}): discover(state,"toys",toy)
	for item: Dictionary in state.get("items",{}).values():
		discover(state,"fish",str(item.kind))
		if item.get("location","")!="equipped" or str(item.get("cat","")) not in state.get("active",[]): continue
		var effective: int = Data.effective(item,str(item.cat))
		for threshold: int in [3,5]:
			var key: String = "first_lv%d_stage" % threshold
			if effective>=threshold: _unlock(state,"first_mechanism" if threshold==3 else "first_transformation")
			if effective>=threshold and int(record[key])==0 and not bool(record.get("prior_lv%d" % threshold,false)):
				record[key] = stage
				record["first_lv%d_cat" % threshold] = str(item.cat)
				record["first_lv%d_fish" % threshold] = str(item.kind)
	if int(state.get("hq",1))>=5:
		if int(record.hq5_stage)==0 and not bool(record.prior_hq5): record.hq5_stage = stage
		_unlock(state,"hq_full")
	var profile: Dictionary = state.campaign_progress.profile
	for category: String in ["cats","fish","toys"]:
		var total: int = {"cats":6,"fish":10,"toys":Data.toys().size()}[category]
		if profile.discovered[category].size()>=total: _unlock(state,"all_"+category)

static func build_signature(state: Dictionary) -> String:
	var pieces: Array[String] = ["hq:%d" % int(state.get("hq",1))]
	var cats: Array = state.get("active",[]).duplicate()
	cats.sort()
	for cat: String in cats: pieces.append("cat:%s:%s" % [cat,state.get("cat_priorities",{}).get(cat,"nearest")])
	for item: Dictionary in state.get("items",{}).values():
		if item.get("location","")=="equipped" and item.get("cat","") in cats:
			pieces.append("fish:%s:%s:%d:%d" % [item.cat,item.kind,int(item.quality),int(item.level)])
	for toy: String in state.get("toys",{}): pieces.append("toy:%s:%d" % [toy,int(state.toys[toy])])
	pieces.sort()
	return "|".join(pieces)

static func start_stage(state: Dictionary) -> void:
	observe(state)
	state.campaign_progress.run.current_build = build_signature(state)

static func settle_stage(state: Dictionary) -> void:
	observe(state)
	@warning_ignore("integer_division") # Four stages per chapter; preserve the existing integer quotient.
	var chapter: int=int(state.get("stage",0))/4+1
	var profile: Dictionary=state.campaign_progress.profile
	if not profile.has("mementos"): profile.mementos=[]
	if int(state.get("stage",0))%4==3 and chapter not in profile.mementos: profile.mementos.append(chapter)
	var record: Dictionary = state.campaign_progress.run
	var stage: int = int(state.get("stage",0))+1
	for entry: Dictionary in record.stages:
		if int(entry.stage)==stage: return
	# Recruitment/HQ upgrades can legally happen during battle. Compare the
	# actual final fielded build, so those changes are not labelled stagnation.
	var signature: String = build_signature(state)
	var unchanged: bool = record.last_build!="" and signature==record.last_build
	record.unchanged_streak = int(record.unchanged_streak)+1 if unchanged else 0
	record.max_unchanged_streak = maxi(int(record.max_unchanged_streak),int(record.unchanged_streak))
	if unchanged: record.unchanged_transitions += 1
	record.last_build = signature
	record.stages.append({"stage":stage,"hq":int(state.get("hq",1)),"gold":int(state.get("gold",0)),"hp":float(state.get("hp",0)),"unchanged":unchanged,"unchanged_streak":int(record.unchanged_streak),"first_lv3_stage":record.first_lv3_stage,"first_lv5_stage":record.first_lv5_stage,"casts":int(state.get("stage_casts",{}).get(stage-1,0))})

static func victory(state: Dictionary) -> void:
	observe(state)
	var progress: Dictionary = state.campaign_progress
	if bool(progress.run.victory_recorded): return
	progress.run.victory_recorded = true
	var difficulty: String = str(state.get("difficulty","easy"))
	progress.profile.victories[difficulty] = int(progress.profile.victories.get(difficulty,0))+1
	var cat: String = str(state.get("initial_cat","C01"))
	progress.profile.cat_victories[cat] = int(progress.profile.cat_victories.get(cat,0))+1
	_unlock(state,"first_clear")
	if difficulty in ["hard","hell"]: _unlock(state,"hard_clear")
	if difficulty=="hell": _unlock(state,"hell_clear")
	if int(state.get("toy_revives_used",0))==0: _unlock(state,"no_revive_clear")
	if "C06" in state.get("active",[]): _unlock(state,"support_clear")

static func goals(state: Dictionary) -> Array:
	var progress: Dictionary = state.get("campaign_progress",{})
	var record: Dictionary = progress.get("run",empty_run())
	return [
		{"id":"mechanism","title":"点亮第一种机制","detail":"喜好鱼实际2级 = 生效3级；首关送初始猫喜好鱼。","complete":int(record.first_lv3_stage)>0 or bool(record.get("prior_lv3",false)),"stage":int(record.first_lv3_stage)},
		{"id":"transform","title":"做出一次质变","detail":"鱼干生效5级；喜好猫实际4级即可。","complete":int(record.first_lv5_stage)>0 or bool(record.get("prior_lv5",false)),"stage":int(record.first_lv5_stage)},
		{"id":"home","title":"第四阶段，五猫满屋","detail":"大本营5级解锁第五猫位与25条鱼篓。","complete":int(record.hq5_stage)>0 or bool(record.get("prior_hq5",false)),"stage":int(record.hq5_stage)},
		{"id":"moon","title":"让月亮回家","detail":"打败吞月洗衣机，完成五阶段20关。","complete":bool(record.victory_recorded),"stage":20 if bool(record.victory_recorded) else 0}]

static func codex(state: Dictionary) -> Dictionary:
	var profile: Dictionary = state.get("campaign_progress",{}).get("profile",empty_profile())
	var result: Dictionary = {"categories":[],"total_found":0,"total":0}
	var names: Dictionary = {"cats":"猫咪伙伴","fish":"小鱼干","toys":"荒诞玩具","enemies":"变异杂物"}
	var catalogs: Dictionary = {"cats":Data.cats(),"fish":{},"toys":Data.toys(),"enemies":Data.enemies()}
	for kind: String in Data.fish_kinds(): catalogs.fish[kind] = {"name":Data.fish_name(kind)}
	for category: String in names:
		var found: Array = profile.discovered.get(category,[])
		var entries: Array = []
		for id: String in catalogs[category]: entries.append({"id":id,"name":str(catalogs[category][id].name),"discovered":id in found})
		result.categories.append({"id":category,"name":names[category],"found":found.size(),"total":entries.size(),"entries":entries})
		result.total_found += found.size()
		result.total += entries.size()
	return result

static func challenges(state: Dictionary) -> Array:
	var profile: Dictionary = state.get("campaign_progress",{}).get("profile",empty_profile())
	var result: Array = []
	for entry: Dictionary in CHALLENGES:
		var value: Dictionary = entry.duplicate()
		value.complete = str(value.id) in profile.challenges
		result.append(value)
	return result
