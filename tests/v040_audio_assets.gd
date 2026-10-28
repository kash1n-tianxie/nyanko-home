extends SceneTree
## Runtime checks for imported CC0 cues, cooldown, volume and clean exit.
const Audio=preload("res://scripts/audio_player.gd")
const Presentation=preload("res://scripts/presentation_audio.gd")
var checks: int=0
var failures: Array[String]=[]
var playback_refs: Array[WeakRef]=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("AUDIO_ASSET_FAIL ",label)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sound: Node=Audio.new()
	root.add_child(sound)
	await process_frame
	playback_refs.append(weakref(sound.music.get_stream_playback()))
	sound.set_volumes(0.0,0.4)
	for key: String in Presentation.INTERFACE_PATHS:
		var stream: AudioStream=sound.streams.get(key) as AudioStream
		check(stream!=null,"imported "+key)
		if stream==null: continue
		check(stream.get_length()>0.02 and stream.get_length()<0.60,"short nonempty cue "+key)
		check(stream is AudioStreamWAV and stream.loop_mode==AudioStreamWAV.LOOP_DISABLED,"not looping "+key)
	var envelope: Dictionary={"type":"shop_purchase","merged":2,"id":"fish"}
	var before: PackedByteArray=var_to_bytes(envelope)
	sound.event(envelope)
	playback_refs.append(weakref(sound.voices[0].get_stream_playback()))
	check(var_to_bytes(envelope)==before,"routing leaves simulation event untouched")
	check(sound.voices[0].stream==sound.streams.ui_merge,"purchase that merged sounds different")
	for voice: AudioStreamPlayer in sound.voices: voice.stop()
	sound.event({"type":"stage_start"})
	sound.event({"type":"skill_ready","cat":"C01"})
	playback_refs.append(weakref(sound.voices[0].get_stream_playback()))
	sound.event({"type":"skill_ready","cat":"C02"})
	var count: int=0
	for voice: AudioStreamPlayer in sound.voices:
		if voice.playing: count+=1
	check(count==1,"simultaneous ready cats do not stack chimes")
	check(sound.voices[0].stream==sound.streams.ui_skill_ready,"ready event reaches imported asset")
	sound.event({"type":"tutorial_hint"})
	playback_refs.append(weakref(sound.voices[1].get_stream_playback()))
	sound.event({"type":"tutorial_hint"})
	count=0
	for voice: AudioStreamPlayer in sound.voices:
		if voice.playing: count+=1
	check(count==2,"repeated tutorial step does not replay chime")
	for voice: AudioStreamPlayer in sound.voices: voice.stop()
	sound.set_volumes(0.0,0.0)
	sound.event({"type":"equip"})
	count=0
	for voice: AudioStreamPlayer in sound.voices:
		if voice.playing: count+=1
	check(count==0,"mute applies to new cues")
	sound.stop_all()
	sound.event({"type":"shop_refresh"})
	for voice: AudioStreamPlayer in sound.voices: check(not voice.playing and voice.stream==null,"exit releases voice")
	sound.queue_free()
	await process_frame
	# stop() queues a mixer-thread fade and deletion. The test must observe actual
	# release, not guess it from elapsed game time or AudioStreamPlayer.playing.
	var deadline: int=Time.get_ticks_msec()+2000
	while _pending_playbacks()>0 and Time.get_ticks_msec()<deadline:
		await process_frame
	check(_pending_playbacks()==0,"audio mixer released every played stream before exit")
	print("AUDIO_ASSET_RESULT ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

func _pending_playbacks() -> int:
	var count: int=0
	for reference: WeakRef in playback_refs:
		if reference.get_ref()!=null: count+=1
	return count
