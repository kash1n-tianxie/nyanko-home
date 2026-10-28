extends SceneTree
## Real authored schedules with a C01 starter meal and an unequipped C04 ally.
## Team selection is a controlled fixture; this is not a human playtest or an earned recruitment route.
const Run = preload("res://scripts/run_state.gd")
const Data = preload("res://scripts/catalog.gd")
const Positions = preload("res://scripts/cat_combat_positions.gd")
var checks: int = 0
var failures: Array[String] = []
var rows: Array = []

func _initialize() -> void:
	call_deferred("execute")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: ", label)

func fresh(team: Array, stage: int = 0, mode: String = "easy") -> RefCounted:
	var model: RefCounted = Run.new()
	model.new_run(41029, str(team[0]), false, mode)
	model.s.stage = stage
	model.s.active = team.duplicate()
	model.s.owned = team.duplicate()
	model.command("start")
	return model

func probe(team: Array, stage: int, mode: String) -> Dictionary:
	var model: RefCounted = fresh(team, stage, mode)
	var cats: Dictionary = {}
	for id: String in team:
		cats[id] = {"attacks":0,"hits":0,"damage":0.0,"stuns":0,"first_attack":-1.0,"first_hit":-1.0,"first_hit_x":-1.0}
	var frames: int = 0
	while model.s.phase in ["combat", "cleanup"] and frames < 9000:
		model.step(1.0 / 60.0)
		for event: Dictionary in model.events:
			var id: String = str(event.get("cat", ""))
			if not cats.has(id): continue
			var record: Dictionary = cats[id]
			match str(event.type):
				"attack":
					record.attacks += 1
					if float(record.first_attack) < 0: record.first_attack = model.combat.b.time
				"hit":
					record.hits += 1
					record.damage += float(event.amount)
					if float(record.first_hit) < 0:
						record.first_hit = model.combat.b.time
						record.first_hit_x = event.x
				"stun": record.stuns += 1
		model.events.clear()
		frames += 1
	return {"team":team,"stage":stage+1,"difficulty":mode,"phase":model.s.phase,"seconds":model.combat.b.time,"hp":model.s.hp,"cats":cats}

func boundary_and_boss_contract() -> void:
	var model: RefCounted = fresh(["C01", "C04"])
	model.combat.b.schedule = []
	var hammer: Dictionary = model.combat.get_cat("C04")
	var outside: Dictionary = model.combat.spawn("E01", 1275)
	check(not model.combat.can_target(hammer, outside), "hammer cannot acquire the distant edge of the battlefield")
	outside.x = 1080.0
	check(model.combat.can_target(hammer, outside), "hammer can engage the authored opening front at x1080")
	outside.x = 350.0 + float(hammer.range) + 1.0
	model.combat.attack(hammer, [outside])
	check(model.combat.b.projectiles.is_empty(), "explicit hammer attacks cannot bypass finite reach")
	var air: Dictionary = model.combat.spawn("E08", 600)
	check(not model.combat.can_target(hammer, air), "ground shockwave still needs an air unlock")
	for kind: String in ["B01", "B02", "B03", "B04", "B05"]:
		var boss: Dictionary = model.combat.spawn(kind)
		check(not model.combat.can_target(hammer, boss), kind + " cannot be hit during entry")
		boss.entrance_age = .8
		check(model.combat.can_target(hammer, boss), kind + " visible front is inside finite hammer reach")
		model.combat.attack(hammer, [boss])
		var projectile: Dictionary = model.combat.b.projectiles[-1]
		check(Vector2(projectile.origin_x, projectile.origin_y).distance_to(Positions.origin(1,"C04")) < .001, kind + " wave starts at the hammer release pose")
		var before: float = boss.hp
		model.combat._tick_projectiles(3.0)
		check(float(boss.hp) < before and float(boss.stun) > 0, kind + " receives actual hammer damage and stun")

func native_damage(id: String, count: int) -> float:
	var model: RefCounted = fresh([id])
	model.combat.b.schedule = []
	var cat: Dictionary = model.combat.get_cat(id)
	cat.fish = {}
	var targets: Array = []
	for index: int in range(count):
		var enemy: Dictionary = model.combat.spawn("E01", 950.0 + index * 12.0)
		enemy.hp = 10000.0
		enemy.max_hp = 10000.0
		enemy.speed = 0.0
		targets.append(enemy)
	model.combat.attack(cat, [targets[0]])
	model.combat._tick_projectiles(3.0)
	return float(model.s.stats.primary.get(id, 0)) + float(model.s.stats.extra.get(id, 0))

func native_role_contract() -> void:
	var sniper_single: float = native_damage("C01", 1)
	var hammer_single: float = native_damage("C04", 1)
	check(sniper_single > hammer_single, "Doubao remains the higher damage single-target weapon")
	check(is_equal_approx(native_damage("C01", 6), sniper_single), "Doubao does not acquire innate splash")
	check(native_damage("C04", 6) > sniper_single * 2, "hammer retains meaningful native damage against a packed ground group")
	var model: RefCounted = fresh(["C01", "C04"])
	var enemy: Dictionary = model.combat.spawn("E01", 1125)
	check(model.combat.can_target(model.combat.get_cat("C01"), enemy) and not model.combat.can_target(model.combat.get_cat("C04"), enemy), "Doubao still reaches farther than the hammer wave")

func execute() -> void:
	boundary_and_boss_contract()
	native_role_contract()
	for mode: String in ["easy", "hard"]:
		for stage: int in [0, 1, 3]:
			var row: Dictionary = probe(["C01", "C04"], stage, mode)
			rows.append(row)
			var label: String = mode + " stage " + str(stage+1)
			check(float(row.cats.C04.first_attack) >= 0 and float(row.cats.C04.first_attack) <= 2.0, label + " hammer starts during the opening encounter")
			check(int(row.cats.C04.stuns) >= 3, label + " hammer contributes repeated real control")
			var total: float = float(row.cats.C01.damage) + float(row.cats.C04.damage)
			check(float(row.cats.C04.damage) / maxf(1,total) >= .20, label + " hammer contributes at least one fifth of team damage")
		for id: String in ["C01", "C04"]:
			var row: Dictionary = probe([id], 0, mode)
			rows.append(row)
			check(row.phase != "failed", mode + " " + id + " can still finish the first authored stage alone")
			if id == "C04": check(float(row.cats.C04.first_hit_x) > 900, mode + " solo hammer acts before enemies approach the base")
	print("V041_COMBAT_RESULT ", JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"rows":rows}))
	quit(0 if failures.is_empty() else 1)
