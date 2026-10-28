extends Node
## Original three-part battle score, crossfaded independently of the five SFX voices.
const SOUND_MAP: Dictionary = {"shop_purchase":"buy_1.wav","shop_refresh":"button_1.wav","meal_launch":"button_1.wav","meal_arrive":"cat_start.wav","cast":"button_1.wav","catch":"coin_1.wav","upgrade":"upgrade_1.wav","merge":"buy_1.wav","merge_all":"buy_1.wav","visit":"cat_start.wav","settlement":"cat_win.wav","victory":"victory.wav","failed":"failure.wav","attack":"weapon_cloud_bow_release_1.wav","base_hit":"hurt_1.wav","freeze":"weapon_frost_knife_impact_1.wav"}
const MUSIC_PATHS: Dictionary = {
	"home":"res://audio/v04/title.ogg",
	"day":"res://audio/new-v025/day.ogg",
	"noon":"res://audio/new-v025/noon.ogg",
	"dusk":"res://audio/new-v025/dusk.ogg"
}
const CROSSFADE_SECONDS: float = 1.1
const PresentationAudio=preload("res://scripts/presentation_audio.gd")
var emphasis: RefCounted=PresentationAudio.new()
var voice_gains: Dictionary={}
# Public active player is retained for callers that inspect music playback.
var music: AudioStreamPlayer
var music_players: Array[AudioStreamPlayer] = []
var music_streams: Dictionary = {}
var music_levels: Array[float] = [1.0,0.0]
var music_active: int = 0
var music_context: String = "home"
var stopped: bool = false
var voices: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var music_volume: float = .35
var sfx_volume: float = .4
var sound_clock: float = 0
var last_attack: float = -10
var priorities: Dictionary = {}
var event_cooldowns: Dictionary = {}
var seen_attacks: Dictionary = {}
var seen_toys: Dictionary = {}
var global_attack_at: float = -10
var global_hit_at: float = -10
var global_toy_at: float = -10

func _ready() -> void:
	for key: String in MUSIC_PATHS:
		var stream: AudioStream = load(str(MUSIC_PATHS[key])) as AudioStream
		if stream is AudioStreamOggVorbis: (stream as AudioStreamOggVorbis).loop = true
		music_streams[key] = stream
	for index: int in range(2):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "MusicA" if index==0 else "MusicB"
		add_child(player)
		music_players.append(player)
	music = music_players[0]
	music.stream = music_streams.home
	_apply_music_volumes()
	if not stopped: music.play()
	for index: int in range(8):
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	for file: String in SOUND_MAP.values():
		if not streams.has(file): streams[file] = load("res://audio/v04/"+file)
	for key: String in PresentationAudio.INTERFACE_PATHS:
		streams[key]=load(str(PresentationAudio.INTERFACE_PATHS[key])) as AudioStream
	for id: int in range(1,7):
		for phase: String in ["attack","hit"]:
			_load_feedback("C%02d_%s" % [id,phase])
	for id: int in range(1,21): _load_feedback("T%02d" % id)
	for key: String in ["shield_hit","shield_break","base_hurt","base_danger","debuff_hit","debuff_cast","elite_defeat","boss_defeat","bell_return"]: _load_feedback(key)

func _process(delta: float) -> void:
	sound_clock += delta
	if stopped: return
	emphasis.tick(delta)
	for index: int in range(music_players.size()):
		music_levels[index] = move_toward(music_levels[index],1.0 if index==music_active else 0.0,delta/CROSSFADE_SECONDS)
		if index!=music_active and music_levels[index]<=0.0 and music_players[index].playing:
			music_players[index].stop()
	_apply_music_volumes()
	_apply_sfx_volumes()

## Stage is zero-based. Main menu, pause menu and home/prep use the gentle home theme.
## A repeated call with the same context never restarts a track or interrupts SFX.
func set_context(phase: String, stage: int, menu: bool = false) -> void:
	if stopped or music_players.size()!=2: return
	var next_context: String = "home"
	if not menu and phase in ["combat","cleanup"]:
		next_context = ["day","noon","dusk","dusk"][posmod(stage,4)]
	if next_context==music_context: return
	music_context = next_context
	music_active = 1-music_active
	music = music_players[music_active]
	music.stop()
	music.stream = music_streams[next_context]
	# The incoming voice starts at silence; the outgoing voice continues its release.
	music_levels[music_active] = 0.0
	_apply_music_volumes()
	music.play()

func _apply_music_volumes() -> void:
	for index: int in range(music_players.size()):
		# Equal-power curve avoids a perceived volume hole in the middle of a transition.
		var gain: float = sin(music_levels[index]*PI*.5)
		music_players[index].volume_db = linear_to_db(maxf(.0001,music_volume*gain*emphasis.music_gain()))

func _apply_sfx_volumes() -> void:
	for voice: AudioStreamPlayer in voices:
		var id: int=voice.get_instance_id()
		var gain: float=float(voice_gains.get(id,1.0))
		if int(priorities.get(id,0))<2: gain*=emphasis.routine_gain()
		voice.volume_db=linear_to_db(maxf(.0001,sfx_volume*gain))

func set_volumes(music_value: float, sfx_value: float) -> void:
	music_volume = clampf(music_value,0.0,1.0)
	sfx_volume = clampf(sfx_value,0.0,1.0)
	_apply_music_volumes()
	_apply_sfx_volumes()

## Fixtures can release both music streams and all SFX before closing the engine.
func stop_all() -> void:
	stopped = true
	emphasis.reset()
	for player: AudioStreamPlayer in music_players:
		player.stop()
		player.stream = null
	for voice: AudioStreamPlayer in voices:
		voice.stop()
		voice.stream = null

func _exit_tree() -> void:
	stop_all()

func _load_feedback(key: String) -> void:
	streams[key]=load("res://audio/feedback-v031/"+key+".wav") as AudioStream

## Public pure routing makes per-source identity verifiable without audio hardware.
static func feedback_route(data: Dictionary) -> Dictionary:
	var interface_cue: Dictionary=PresentationAudio.interface_route(data)
	if not interface_cue.is_empty(): return interface_cue
	var material: Dictionary=PresentationAudio.boss_route(data)
	if not material.is_empty(): return material
	var type: String=str(data.get("type",""))
	var cat: String=str(data.get("cat",data.get("killer_cat","C01")))
	if not cat.begins_with("C"): cat="C01"
	if type=="skill_cast": return {"key":cat+"_attack","priority":4,"gain":.85,"interval":.2,"pitch":.88}
	if type=="skill_impact": return {"key":cat+"_hit","priority":4,"gain":.80,"interval":.15,"pitch":.90}
	if type=="attack": return {"key":cat+"_attack","priority":1,"gain":.48,"interval":.12}
	if type=="hit" and float(data.get("amount",0))>0:
		if str(data.get("kind","")) in ["burn","toy_bleed"]: return {}
		return {"key":cat+"_hit","priority":0,"gain":.26,"interval":.17}
	if type=="toy_trigger":
		var toy: String=str(data.get("source_toy",data.get("toy","")))
		# New mechanics reuse the established soft paper/bell timbres at restrained gain.
		var key: String={"T21":"T13","T22":"bell_return"}.get(toy,toy)
		return {"key":key,"priority":3 if toy in ["T21","T22"] else 2,"gain":.56 if toy in ["T21","T22"] else .63,"interval":.36,"pitch":.91 if toy=="T21" else 1.0}
	if type=="toy_combo": return {"key":"T19","priority":4,"gain":.62,"interval":.8,"pitch":.94}
	if type=="boss_counter_warning": return {"key":"debuff_cast","priority":4,"gain":.42,"interval":1.0,"pitch":.93}
	if type=="boss_counter_success": return {"key":"upgrade_1.wav","priority":5,"gain":.58,"interval":.6,"pitch":.96}
	if type=="boss_counter_failure": return {"key":"debuff_hit","priority":4,"gain":.48,"interval":.6,"pitch":.90}
	if type=="base_damage_resolved":
		if float(data.get("hp_damage",0))>0: return {"key":"base_hurt","priority":4,"gain":.82,"interval":.12}
		if float(data.get("shield_absorbed",0))>0: return {"key":"shield_hit","priority":3,"gain":.6,"interval":.14}
		return {}
	if type=="base_shield_broken": return {"key":"shield_break","priority":5,"gain":.85,"interval":.3}
	if type=="base_low_hp": return {"key":"base_danger","priority":5,"gain":.84,"interval":.5}
	if type=="cat_debuff": return {"key":"debuff_hit","priority":4,"gain":.64,"interval":.13}
	if type=="enemy_debuff_cast": return {"key":"debuff_cast","priority":3,"gain":.45,"interval":.20}
	if type=="bell_return": return {"key":"bell_return","priority":2,"gain":.48,"interval":.24}
	if type=="death":
		if bool(data.get("boss",false)) or str(data.get("enemy_kind",data.get("kind",""))).begins_with("B"): return {"key":"boss_defeat","priority":4,"gain":.85,"interval":.5}
		if bool(data.get("elite",false)): return {"key":"elite_defeat","priority":3,"gain":.65,"interval":.3}
	# base_hit is pre-mitigation; do not announce HP loss until it resolves.
	if type=="base_hit": return {}
	if SOUND_MAP.has(type): return {"key":SOUND_MAP[type],"priority":3 if type in ["victory","failed","upgrade","settlement","visit"] else 2,"gain":.8,"interval":.08}
	return {}

func event(event_data: Dictionary) -> void:
	var type: String=str(event_data.get("type",""))
	emphasis.notice(event_data)
	if type=="stage_start":
		seen_attacks.clear()
		seen_toys.clear()
		event_cooldowns.clear()
		return
	if stopped or sfx_volume<=0: return
	var route: Dictionary=feedback_route(event_data)
	if route.is_empty() or not streams.has(str(route.key)): return
	var key: String=str(route.key)
	if type=="attack":
		var token: String=str(event_data.get("cat",""))+":"+str(event_data.get("attack",-1))
		if int(event_data.get("attack",-1))>=0:
			if seen_attacks.has(token): return
			seen_attacks[token]=true
			if seen_attacks.size()>128: seen_attacks.erase(seen_attacks.keys()[0])
		if sound_clock-global_attack_at<.045: return
		global_attack_at=sound_clock
	if type=="hit":
		if sound_clock-global_hit_at<.10: return
		global_hit_at=sound_clock
	if type=="toy_trigger":
		if not seen_toys.has(key):
			route.priority=4
			route.gain=minf(.70,float(route.gain)*1.12)
			seen_toys[key]=true
		elif sound_clock-global_toy_at<.16: return
		global_toy_at=sound_clock
	if sound_clock-float(event_cooldowns.get(key,-100))<float(route.interval): return
	event_cooldowns[key]=sound_clock
	var selected: AudioStreamPlayer=null
	for voice: AudioStreamPlayer in voices:
		if not voice.playing: selected=voice;break
	if selected==null:
		var lowest: int=int(route.priority)
		for voice: AudioStreamPlayer in voices:
			var priority: int=int(priorities.get(voice.get_instance_id(),0))
			if priority<lowest: selected=voice;lowest=priority
	if selected==null: return
	selected.stop()
	selected.stream=streams[key]
	selected.pitch_scale=clampf(float(route.get("pitch",1.0)),.85,1.05)
	selected.volume_db=linear_to_db(maxf(.0001,sfx_volume*float(route.gain)))
	priorities[selected.get_instance_id()]=int(route.priority)
	voice_gains[selected.get_instance_id()]=float(route.gain)
	_apply_sfx_volumes()
	selected.play()
