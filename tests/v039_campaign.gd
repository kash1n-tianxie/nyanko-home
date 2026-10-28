extends "res://tests/v033_campaign_runs.gd"
## Earned-gold automated policies, no extra resources and no player-save writes.
const OUTPUT: String="res://outputs/v039/balance" # lint:ignore res_path
var risk_route: bool=false
var casts: int=0
var meals: int=0
var first_mechanism: int=0
var first_breakthrough: int=0
var history: Array=[]

func _score(model: RefCounted,offer: Dictionary) -> float:
	var result: float=float(offer.level)*5+float(offer.quality)*3
	var same: int=0
	for fish: Dictionary in model.s.items.values():
		if fish.kind==offer.kind and fish.quality==offer.quality:
			same+=1
			if fish.level==offer.level and int(fish.level)<5: result+=24
	for id: String in model.s.active:
		if offer.kind in Data.cats()[id].favorites: result+=12
		var used: Array=[]
		for fish: Dictionary in model.equipped(id):
			if not fish.is_empty(): used.append(fish.kind)
		if used.size()<3 and offer.kind not in used: result+=5
	if offer.kind in ["F01","F02","F04","F06","F09"]: result+=5
	if same>4: result-=12
	return result/maxf(1,float(offer.price))

func camp(model: RefCounted) -> void:
	if policy=="no_build": return
	model.command("meal_clear")
	model.command("merge_all");outfit(model)
	var stage: int=model.s.stage
	var target: int=2 if stage<2 else (3 if stage<(9 if policy=="focused" else 7) else (4 if stage<(14 if policy=="focused" else 12) else 5))
	while int(model.s.hq)<target and int(model.s.gold)>=int(Data.hq(int(model.s.hq)+1).cost):
		model.command("upgrade");recruit(model)
	var allowance: int=[0,6,16,22,28,70][int(model.s.hq)]+(10 if policy=="focused" and stage>0 and int(model.s.hq)<5 else 0)
	var budget: int=mini(int(model.s.gold),allowance)
	var refreshes: int=0
	for attempt: int in range(12):
		var shop: Dictionary=model.shop_status();var best: int=-1;var value: float=-1
		for i: int in range(5):
			var offer: Dictionary=shop.offers[i]
			if offer.sold or int(offer.price)>budget or int(offer.price)>int(model.s.gold): continue
			var score: float=_score(model,offer)
			if score>value: best=i;value=score
		if best>=0:
			var price: int=shop.offers[best].price
			var bought: Dictionary=model.command("shop_buy",{"slot":best})
			if not bought.ok: break
			budget-=price;model.command("merge_all");outfit(model)
		elif refreshes<2 and budget>=9 and int(model.s.gold)>=9:
			var cost: int=shop.refresh_cost
			if not model.command("shop_refresh").ok: break
			budget-=cost;refreshes+=1
		else: break
	choose_priorities(model)
	# One preplanned swap, using an existing spare; no fabricated meal.
	for fish: Dictionary in model.s.items.values():
		if fish.location not in ["inventory","inbox"]: continue
		var found: bool=false
		for id: String in model.s.active:
			for slot: int in range(3):
				var current: Dictionary=model.equipped(id)[slot]
				if current.is_empty() or current.kind==fish.kind:
					if model.command("meal_prepare",{"id":fish.id,"cat":id,"slot":slot}).ok: found=true;break
			if found: break
		if found: break

func execute() -> void:
	risk_route="--risk" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var model: RefCounted=Run.new();model.new_run(seed_value,cat_id,false,mode)
	var ticks: int=0;var began: int=Time.get_ticks_msec()
	while model.s.phase not in ["failed","victory"] and ticks<240000:
		if model.s.phase=="prep":
			camp(model)
			if risk_route and model.encounter_status().available: model.command("encounter_choice",{"choice":"risk"})
			for fish: Dictionary in model.s.items.values():
				if fish.location!="equipped": continue
				var level: int=Data.effective(fish,fish.cat)
				if level>=3 and first_mechanism==0: first_mechanism=int(model.s.stage)+1
				if level>=5 and first_breakthrough==0: first_breakthrough=int(model.s.stage)+1
			history.append({"stage":int(model.s.stage)+1,"hq":model.s.hq,"gold":model.s.gold,"hp":model.s.hp,"fish_spend":model.s.stats.fish_spend,"refresh_spend":model.s.stats.get("shop_refresh_spend",0),"items":model.s.items.duplicate(true),"cats":model.s.active.duplicate()})
			if int(model.s.stage) in [3,11,15,19]: model.save(OUTPUT+"/%s-%s-%d-%s-stage%02d.save"%[mode,policy,seed_value,"risk" if risk_route else "normal",int(model.s.stage)+1])
			model.command("start")
		elif model.s.phase=="toy_reward":
			var choice: String=model.s.reward_choices[0]
			for id: String in ["T10","T04","T05","T15","T03","T01","T13","T16","T11","T14","T06"]:
				if id in model.s.reward_choices: choice=id;break
			model.command("reward_choose",{"id":choice})
		elif model.s.phase=="route": model.command("route_continue")
		elif model.combat.skills.cinematic_busy(): model.combat.skills.tick_cinematic(1.0/60)
		else:
			if policy!="no_build":
				var threats: Array=model.combat.enemies()
				if threats.size()>=6 or (float(model.combat.b.time)>20 and not threats.is_empty()):
					for id: String in model.s.active:
						if bool(model.combat.skill_status(id).get("ready",false)):
							if model.command("cat_skill",{"cat":id}).ok: casts+=1
							break
				if float(model.combat.b.time)>28 and bool(model.meal_status().prepared):
					if model.command("meal_use").ok: meals+=1
			model.step(1.0/60)
		model.events.clear();ticks+=1
	var report: Dictionary={"type":"automated_earned_resource_policy_not_human_playtest","mode":mode,"policy":policy,"seed":seed_value,"starter":cat_id,"phase":model.s.phase,"stage":int(model.s.stage)+1,"hp":model.s.hp,"hq":model.s.hq,"hq5_stage":model.s.campaign_progress.run.hq5_stage,"gold":model.s.gold,"fish_spend":model.s.stats.fish_spend,"hq_spend":model.s.stats.hq_spend,"refresh_spend":model.s.stats.get("shop_refresh_spend",0),"first_mechanism":first_mechanism,"first_breakthrough":first_breakthrough,"skills":casts,"meals":meals,"wall_seconds":(Time.get_ticks_msec()-began)/1000.0,"history":history}
	report["balance_revision"]="v039-boss-phases"
	report["risk_route"]=risk_route
	report["stage_reports"]=model.s.stage_reports
	report["hq5_cost"]=int(Data.hq(5).cost)
	var file:=FileAccess.open(OUTPUT+"/%s-%s-%d-%s-%s.json"%[mode,policy,seed_value,cat_id,"risk" if risk_route else "normal"],FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	report.erase("history");report.erase("stage_reports");print(JSON.stringify(report));quit(0 if model.s.phase in ["failed","victory"] else 1)
