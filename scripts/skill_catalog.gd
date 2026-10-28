extends RefCounted
## Active-skill tuning is separate from ordinary attacks, fish and toy rules.
const VERSION: int=2
const BASE_CHARGE: float=18.0
const MIN_CHARGE: float=10.0
const CUTIN_DURATION: float=3.0
const DEFINITIONS: Dictionary={
	"C01":{"id":"rage","name":"鱼骨狂暴","description":"狂暴 8 秒，最终攻击与攻速 ×2","cinema_duration":3.2,"delay":1.55,"buff_duration":8.0,"attack_multiplier":2.0,"speed_multiplier":2.0},
	"C02":{"id":"meteor","name":"毛线天坠","description":"毛线陨石：落点 260 范围，16 倍攻击伤害","cinema_duration":4.2,"delay":2.55,"coefficient":16.0,"radius":260.0},
	"C03":{"id":"thunder","name":"喵引天雷","description":"5 道天雷，每道 3 倍攻击；追加 2 次 0.6 倍连锁","cinema_duration":4.0,"delay":1.65,"pulses":5,"pulse_interval":.28,"coefficient":3.0,"chain_count":2,"chain_coefficient":.6,"chain_radius":230.0},
	"C04":{"id":"quake","name":"一锤天地静","description":"全场 2 倍攻击；眩晕普通 3 秒 / 精英 1.8 秒 / 首领 1 秒","cinema_duration":3.8,"delay":2.25,"coefficient":2.0,"stun":3.0,"elite_stun":1.8,"boss_stun":1.0},
	"C05":{"id":"roar","name":"起床气风暴","description":"全场 2.5 倍攻击；普通最多后退 240 / 精英 120，首领硬直 0.8 秒","cinema_duration":3.6,"delay":1.45,"sweep_duration":.9,"coefficient":2.5,"push":240.0,"elite_push":120.0,"boss_stun":.8},
	"C06":{"id":"sanctuary","name":"叮当守护曲","description":"全队净化，8 倍攻击护盾持续 8 秒；全队攻速与攻击 +30% 持续 6 秒","cinema_duration":3.5,"delay":1.85,"shield_coefficient":8.0,"shield_duration":8.0,"buff_duration":6.0,"attack_multiplier":1.3,"speed_multiplier":1.3}}

static func definition(cat_id: String) -> Dictionary:
	return DEFINITIONS.get(cat_id,{}).duplicate(true)

static func charge_duration(cat: Dictionary) -> float:
	var bonus: float=0.0
	for fish: Dictionary in cat.get("fish",{}).values(): bonus+=maxf(0.0,float(fish.get("speed_bonus",0)))
	return maxf(MIN_CHARGE,BASE_CHARGE/sqrt(1.0+bonus))

static func attack_multiplier(cat: Dictionary) -> float:
	return (float(DEFINITIONS.C01.attack_multiplier) if float(cat.get("skill_rage_left",0))>0 else 1.0)*(float(DEFINITIONS.C06.attack_multiplier) if float(cat.get("skill_chorus_left",0))>0 else 1.0)

static func speed_multiplier(cat: Dictionary) -> float:
	return (float(DEFINITIONS.C01.speed_multiplier) if float(cat.get("skill_rage_left",0))>0 else 1.0)*(float(DEFINITIONS.C06.speed_multiplier) if float(cat.get("skill_chorus_left",0))>0 else 1.0)
