extends "res://tests/v039_campaign.gd"
## Normal authored first chapter, legal commands and earned resources only.
## --legacy-range reproduces the former C04 reach in the same deterministic policy.
var first_attacks: Dictionary = {}
var campaign_rows: Array = []
var basic_damage: Dictionary = {}
var attack_counts: Dictionary = {}

func recruit(model: RefCounted) -> void:
	var choices: Array = model.recruit_choices()
	for preferred: String in ["C04", "C03", "C05", "C02", "C06", "C01"]:
		if preferred in choices:
			model.command("recruit", {"cat":preferred})
			return

func execute() -> void:
	# Pick a reproducible legal invitation containing C04, without granting a cat.
	seed_value = 1
	for candidate: int in range(1, 51):
		var sample: RefCounted = Run.new()
		sample.new_run(candidate, "C01", false, mode)
		sample.command("upgrade")
		if "C04" in sample.recruit_choices():
			seed_value = candidate
			break
	var legacy: bool = "--legacy-range" in OS.get_cmdline_user_args()
	var model: RefCounted = Run.new()
	model.new_run(seed_value, "C01", false, mode)
	var frames: int = 0
	while model.s.phase not in ["failed", "victory"] and int(model.s.stage) < 4 and frames < 36000:
		if model.s.phase == "prep":
			camp(model)
			model.command("start")
			first_attacks = {}
			basic_damage = {}
			attack_counts = {}
			if legacy and not model.combat.get_cat("C04").is_empty(): model.combat.get_cat("C04").range = 400.0
		elif model.s.phase == "toy_reward":
			var choice: String = model.s.reward_choices[0]
			for id: String in ["T10", "T04", "T05", "T15", "T03", "T01", "T13", "T16", "T11", "T14", "T06"]:
				if id in model.s.reward_choices:
					choice = id
					break
			model.command("reward_choose", {"id":choice})
		elif model.s.phase == "route": model.command("route_continue")
		elif model.combat.skills.cinematic_busy(): model.combat.skills.tick_cinematic(1.0 / 60.0)
		else:
			var threats: Array = model.combat.enemies()
			if threats.size() >= 6 or (float(model.combat.b.time) > 20 and not threats.is_empty()):
				for id: String in model.s.active:
					if bool(model.combat.skill_status(id).get("ready", false)):
						if model.command("cat_skill", {"cat":id}).ok: break
			if float(model.combat.b.time) > 28 and bool(model.meal_status().prepared): model.command("meal_use")
			model.step(1.0 / 60.0)
			for event: Dictionary in model.events:
				if str(event.type) == "attack":
					attack_counts[event.cat] = int(attack_counts.get(event.cat, 0)) + 1
					if not first_attacks.has(event.cat): first_attacks[event.cat] = model.combat.b.time
				if str(event.type) == "hit" and not str(event.kind).begins_with("active_"):
					basic_damage[event.cat] = float(basic_damage.get(event.cat, 0)) + float(event.amount)
			if model.s.phase not in ["combat", "cleanup"]:
				var feedback: Dictionary = model.current_feedback()
				campaign_rows.append({"stage":int(model.s.stage)+1,"phase":model.s.phase,"cats":model.s.active.duplicate(),"first_attacks":first_attacks.duplicate(),"basic_damage":basic_damage.duplicate(),"attack_counts":attack_counts.duplicate(),"damage":feedback.get("damage_by_cat",{}),"support":feedback.get("support",{}),"hp":model.s.hp,"hq":model.s.hq,"gold":model.s.gold,"items":model.s.items.duplicate(true)})
		model.events.clear()
		frames += 1
	var recruited: bool = "C04" in model.s.owned
	var completed: bool = int(model.s.stage) >= 4
	var participating: bool = legacy or campaign_rows.all(func(row: Dictionary) -> bool: return float(row.first_attacks.get("C04", 99)) <= 2.0 and float(row.basic_damage.get("C04", 0)) > 0)
	print("V041_CAMPAIGN_RESULT ", JSON.stringify({"ok":recruited and completed and participating,"ordinary_hammer_participation":participating,"fixture":"automated legal earned-resource policy, selected seed with C04 invitation; not human playtesting","difficulty":mode,"seed":seed_value,"legacy_range":legacy,"recruited":recruited,"completed_first_chapter":completed,"phase":model.s.phase,"stage":int(model.s.stage)+1,"rows":campaign_rows}))
	quit(0 if recruited and completed and participating else 1)
