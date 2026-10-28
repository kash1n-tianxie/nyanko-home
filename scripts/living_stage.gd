extends RefCounted
## Painted perimeter motion, driven exclusively by real stage/Boss events.
## configure copies scalars; no run reference or RNG stream is retained.
const Scenery=preload("res://scripts/story_scenery.gd")
const TreeArt=preload("res://scripts/tree_presentation.gd")
var tree: RefCounted=TreeArt.new()
var stage: int=-1
var chapter: int=0
var clock: float=0.0
var paused: bool=false
var reduced: bool=false
var speed: float=1.0
var cue: String=""
var cue_left: float=0.0
var cue_total: float=0.0
var enabled: bool=false
var _run_seed: int=0
var aftermath_age: float=0.0
var aftermath_active: bool=false
const QUIET_SECONDS: float=2.1

func configure(current: Dictionary, reduced_motion: bool=false) -> void:
	var next_stage: int=clampi(int(current.get("stage",0)),0,19)
	var next_seed: int=int(current.get("seed",0))
	var changed: bool=next_stage!=stage or next_seed!=_run_seed or enabled!=not current.is_empty()
	if changed:
		clock=0.0
		cue=""
		cue_left=0.0
		cue_total=0.0
		aftermath_age=0.0
		aftermath_active=false
	stage=next_stage
	_run_seed=next_seed
	chapter=clampi(floori(float(stage)/4.0),0,4)
	paused=bool(current.get("paused",false))
	reduced=reduced_motion
	speed=clampf(float(current.get("combat_speed",1.0)),1.0,2.0)
	enabled=not current.is_empty()
	tree.configure(current,reduced,changed)
	if str(current.get("phase","")) not in ["combat","cleanup"]:
		# A settled Boss's event cannot keep the next prep screen in its charge state.
		cue=""
		cue_left=0.0

func tick(delta: float) -> void:
	if paused or not enabled: return
	var real_elapsed: float=maxf(0.0,delta)
	# The visual epilogue holds its two-second rhythm even at 2x battle speed.
	if aftermath_active: aftermath_age=minf(QUIET_SECONDS,aftermath_age+real_elapsed)
	var elapsed: float=real_elapsed*speed
	clock+=elapsed
	cue_left=maxf(0.0,cue_left-elapsed)
	if cue_left<=0.0: cue=""
	tree.tick(elapsed)

func event(notice: Dictionary) -> void:
	var type: String=str(notice.get("type",""))
	var boss: bool=bool(notice.get("boss",false)) or str(notice.get("kind","")).begins_with("B")
	if type=="stage_start":
		cue="";cue_left=0.0;clock=0.0
		aftermath_active=false;aftermath_age=0.0
	elif type in ["boss_warning","boss_enter","boss_arrival"] or (type=="spawn" and boss): _cue("enter",1.6)
	elif type=="boss_counter_warning": _cue("charge",maxf(.2,float(notice.get("duration",1.8))))
	elif type=="boss_counter_success": _cue("break",1.25)
	elif type=="boss_counter_failure": _cue("release",.8)
	elif type in ["boss_cast","boss_impact"]: _cue("release",.8)
	elif type=="boss_departure" or (type=="death" and boss):
		# Duplicate death/departure notices cannot restart the quiet return.
		if not aftermath_active:
			aftermath_active=true
			aftermath_age=0.0
		_cue("death",2.0)
	tree.event(notice)

func _cue(kind: String, duration: float) -> void:
	cue=kind
	cue_left=duration
	cue_total=duration

func snapshot() -> Dictionary:
	return {"stage":stage,"chapter":chapter,"clock":clock,"paused":paused,"reduced":reduced,"cue":cue,"cue_left":cue_left,"tree":tree.snapshot(),"ambient_modules":2 if chapter!=2 else 3,"aftermath_age":aftermath_age,"aftermath_active":aftermath_active,"grade":grade_state()}

func grade_state() -> Dictionary:
	var progress: float=clampf(aftermath_age/QUIET_SECONDS,0.0,1.0) if aftermath_active else 0.0
	var eased: float=progress*progress*(3.0-2.0*progress)
	return {"aftermath":eased,"pressure":maxf(0.0,_strength()) if not aftermath_active else 0.0,"quiet":eased}

func quiet_remaining() -> float:
	return maxf(0.0,QUIET_SECONDS-aftermath_age) if aftermath_active else 0.0

func _paint(canvas: CanvasItem, id: String, rect: Rect2, angle: float=0.0, alpha: float=1.0, pivot: Vector2=Vector2(.5,.5), tint: Color=Color.WHITE) -> void:
	tint.a*=alpha
	Scenery.draw_module(canvas,id,rect,angle,pivot,tint)

func _strength() -> float:
	if cue=="charge": return 1.0
	if cue in ["enter","release"]: return cue_left/maxf(.01,cue_total)*.8
	if cue=="break": return -cue_left/maxf(.01,cue_total)*.6
	if cue=="death": return -cue_left/maxf(.01,cue_total)*.8
	return 0.0

func draw_back(canvas: CanvasItem) -> void:
	if not enabled: return
	var motion: float=0.0 if reduced else 1.0
	var strength: float=_strength()
	var calm: float=1.0-float(grade_state().quiet)*.72
	var wind: float=sin(clock*1.25)*.025*motion*calm
	var gust: float=strength*.065*motion*calm
	match chapter:
		0:
			_paint(canvas,"laundry_rope",Rect2(490,106,283,72),wind+gust,.8,Vector2(0,.1))
			_paint(canvas,"paper_scrap",Rect2(799+sin(clock*.8)*4*motion,167+sin(clock*1.1)*8*motion,29,43),wind*3+gust,.72)
		1:
			_paint(canvas,"shop_sign",Rect2(668,106,136,94),wind*1.3+gust,.9,Vector2(.5,0))
			var receipt_y: float=130+sin(clock*.9)*9*motion
			_paint(canvas,"receipt",Rect2(811-strength*14*motion,receipt_y,37,99),-.12+wind*2-gust*2,.85,Vector2(.5,0))
		2:
			_paint(canvas,"industrial_lamp",Rect2(692,105,94,103),wind*.3+gust*.5,.95,Vector2(.5,0))
			for i: int in range(2):
				var rise: float=fmod(clock*.13+i*.5,1.0) if not reduced else .25+i*.3
				_paint(canvas,"steam",Rect2(770+i*20+sin(clock+i)*4*motion,280-rise*100,66+rise*22,76+rise*18),0.0,(1.0-rise)*(.32+maxf(0,strength)*.12))
		3:
			_paint(canvas,"antenna",Rect2(677,111,153,126),wind*.7+gust*.8,.88,Vector2(.5,.95))
			var screen_tint: Color=Color("c9eeef") if cue=="break" else (Color("f3c5a3") if cue=="charge" else Color.WHITE)
			var screen_alpha: float=.80 if reduced else .76+sin(clock*1.5)*.025
			if aftermath_active: screen_tint=screen_tint.lerp(Color("ffe1ad"),float(grade_state().aftermath)*.45)
			_paint(canvas,"monitor",Rect2(766,260,82,69),0.0,screen_alpha,Vector2(.5,.5),screen_tint)
		4:
			_paint(canvas,"sock",Rect2(709,106,61,102),wind*1.6+gust,.8,Vector2(.5,0))
			_paint(canvas,"moon_fragments",Rect2(795,208+sin(clock*.7)*7*motion,63,83),wind*.4,.7,Vector2(.5,.5),Color("c0d5e2"))

func draw_front(canvas: CanvasItem) -> void:
	if not enabled: return
	var motion: float=0.0 if reduced else 1.0
	var strength: float=_strength()
	# Local scraps never enter the attack corridor or the dock (all y < 548).
	var scrap_id: String=["paper_scrap","receipt","cloth_scrap","paper_scrap","moon_fragments"][chapter]
	var rect: Rect2=Rect2(1194+sin(clock*.85)*7*motion-strength*11*motion,492+sin(clock)*4*motion,34,30)
	_paint(canvas,scrap_id,rect,sin(clock*.7)*.12*motion-strength*.18*motion,.6)
	if cue=="break":
		var alpha: float=cue_left/maxf(.01,cue_total)*.35
		_paint(canvas,"glints",Rect2(1128,167,108,112),0.0,alpha)

func draw_tree(canvas: CanvasItem) -> void:
	if enabled: tree.draw_tree(canvas)
