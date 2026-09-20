## 捕捉系統檢查（規格書 §10，硬規則 4）。
##
##   godot --headless --path <專案> res://tests/capture_test.tscn
extends Node

var _fail := 0
var _world: Node3D = null


func _ready() -> void:
	_world = load("res://scenes/world/world.tscn").instantiate()
	add_child(_world)
	await get_tree().physics_frame
	await get_tree().physics_frame

	_check_rate()
	_check_rejections()
	await _check_failure()
	await _check_success()
	await _check_q_key()

	print("TEST ===== %s (%d failures) =====" % ["ALL PASS" if _fail == 0 else "FAILED", _fail])
	get_tree().quit(_fail)


func _check(label: String, got: Variant, want: Variant) -> void:
	var ok: bool = false
	if typeof(got) == TYPE_FLOAT and typeof(want) == TYPE_FLOAT:
		ok = is_equal_approx(got, want)
	else:
		ok = got == want
	if not ok:
		_fail += 1
	print("TEST %s %-40s got=%s want=%s" % ["OK  " if ok else "FAIL", label, got, want])


## 用真實時間等，不要用 frame 數。
## headless 沒有 vsync，process frame 跑得比 60fps 快很多，
## 「等 240 frame」換算成秒數是錯的——這條讓一個好的功能被判成失敗過。
func _wait_for(condition: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await get_tree().process_frame
	return condition.call()


func _snake() -> Pet:
	return _world.get_node("Pets/diving_snake")


func _make_ball(id: StringName, power: float, guaranteed: bool = false) -> BallData:
	var ball := BallData.new()
	ball.id = id
	ball.power = power
	ball.guaranteed = guaranteed
	return ball


func _check_rate() -> void:
	print("TEST --- capture_rate = ball × hp × rarity ---")
	var snake := _snake()
	var basic: BallData = Database.get_item(&"ball_basic")
	var great: BallData = Database.get_item(&"ball_great")

	# 潛水蛇 capture_difficulty 0.6 -> rarity = lerp(1.0, 0.45, 0.6) = 0.67
	snake.health.current_health = snake.health.max_health
	var full := CaptureSystem.calculate_rate(snake, basic)
	_check("滿血 普通球 = 0.3 × 0.67", full, 0.201)

	snake.health.current_health = 0.001
	var low := CaptureSystem.calculate_rate(snake, basic)
	_check("殘血 普通球 = 1.0 × 0.67", low, 0.67)
	_check("HP 越低成功率越高（硬規則 4）", low > full, true)

	_check("高級球更高", CaptureSystem.calculate_rate(snake, great) > low, true)
	_check("普通情況不到 100%（MAX_RATE 0.95）",
		CaptureSystem.calculate_rate(snake, great), CaptureSystem.MAX_RATE)
	print("TEST --- 搖幾下（純表現）---")
	_check("成功一律搖滿", CaptureSystem.shake_count(true, 0.1), CaptureSystem.MAX_SHAKES)
	_check("失敗 rate 0.9 -> 3 下", CaptureSystem.shake_count(false, 0.9), 3)
	_check("失敗 rate 0.67 -> 2 下", CaptureSystem.shake_count(false, 0.67), 2)
	_check("失敗 rate 0.1 -> 至少 1 下", CaptureSystem.shake_count(false, 0.1), 1)
	_check("失敗 rate 0 -> 至少 1 下", CaptureSystem.shake_count(false, 0.0), 1)
	_check("搖越多演越久",
		CaptureSystem.sequence_seconds(3) > CaptureSystem.sequence_seconds(1), true)

	print("TEST --- capture_rate 續 ---")
	_check("guaranteed 球 = 1.0",
		CaptureSystem.calculate_rate(snake, _make_ball(&"x", 0.1, true)), 1.0)

	# 稀有度：難抓的比較低
	var dragon: Pet = _world.starter
	dragon.health.current_health = 0.001
	_check("難抓的(0.6) 低於普通的(0.5)",
		low < CaptureSystem.calculate_rate(dragon, basic), true)

	snake.health.current_health = snake.health.max_health
	dragon.health.current_health = dragon.health.max_health


func _check_rejections() -> void:
	print("TEST --- 前置條件 ---")
	var basic: BallData = Database.get_item(&"ball_basic")
	var reasons: Array[StringName] = []
	Game.capture.capture_rejected.connect(func(r: StringName) -> void: reasons.append(r))

	_check("目標是自己的寵物 -> 拒絕",
		Game.capture.attempt_capture(_world.starter, basic), false)
	_check("理由 not_wild", reasons[-1], &"not_wild")

	_check("沒有目標 -> 拒絕", Game.capture.attempt_capture(null, basic), false)
	_check("理由 no_target", reasons[-1], &"no_target")

	var empty_ball := _make_ball(&"ball_none", 1.0)
	_check("沒球 -> 拒絕", Game.capture.attempt_capture(_snake(), empty_ball), false)
	_check("理由 out_of_balls", reasons[-1], &"out_of_balls")

	var before := Game.inventory.count(&"ball_basic")
	Game.capture.attempt_capture(_world.starter, basic)
	_check("被拒絕時不會消耗球", Game.inventory.count(&"ball_basic"), before)


func _check_failure() -> void:
	print("TEST --- 捕捉失敗（硬規則 4）---")
	var snake := _snake()
	# power 0 -> rate 0 -> randf() < 0 恆為 false，不需要控制亂數種子
	var dud := _make_ball(&"ball_dud", 0.0)
	Game.inventory.add(&"ball_dud", 2)

	# 讓牠先進入戰鬥狀態，驗證失敗不會打斷 FSM
	snake.targeting.set_target(_world.starter)
	await get_tree().physics_frame
	var state_before: PetAI.State = snake.ai.state
	var hp_before: float = snake.health.current_health

	var layer_before: int = snake.collision_layer
	_check("失敗回傳 false", Game.capture.attempt_capture(snake, dud), false)
	_check("球有消耗", Game.inventory.count(&"ball_dud"), 1)
	_check("目標沒有消失", is_instance_valid(snake), true)
	_check("目標 HP 不變", snake.health.current_health, hp_before)

	# 被吸進球裡的期間：不可被點選、不會被打到
	_check("吸入中離開碰撞層", snake.collision_layer, 0)
	_check("吸入中無敵", snake.health.invulnerable, true)

	# 演完之後要彈回來繼續打（硬規則 4：目標不消失、戰鬥繼續）
	_check("失敗後彈回來、碰撞層還原", await _wait_for(
		func() -> bool: return snake.collision_layer == layer_before, 8.0), true)
	_check("不再無敵", snake.health.invulnerable, false)
	_check("FSM 恢復運作", snake.ai.is_physics_processing(), true)
	_check("目標還活著", snake.health.is_dead, false)
	_check("HP 全程沒被動過", snake.health.current_health, hp_before)
	_check("FSM 狀態沒被改掉", snake.ai.state, state_before)


func _check_success() -> void:
	print("TEST --- 捕捉成功 ---")
	var snake := _snake()
	var species_id: StringName = snake.data.id
	snake.health.current_health = 12.0

	var sure := _make_ball(&"ball_sure", 1.0, true)
	Game.inventory.add(&"ball_sure", 1)

	var captured: Array[StringName] = []
	EventBus.pet_captured.connect(func(_iid: StringName, sid: StringName) -> void:
		captured.append(sid))

	var collection_before := Game.collection.size()
	var party_before := Game.party.size()

	_check("成功回傳 true", Game.capture.attempt_capture(snake, sure), true)
	_check("EventBus.pet_captured 有發", captured, [species_id] as Array[StringName])
	_check("進了收藏", Game.collection.size(), collection_before + 1)
	_check("Party 未滿 -> 也進了 Party", Game.party.size(), party_before + 1)

	var caught: PetInstance = Game.party.at(Game.party.size() - 1)
	_check("捕捉成功以滿血加入（Phase 1 沒有回血手段）",
		caught.current_hp, Database.get_pet(species_id).max_hp)
	_check("species_id 正確", caught.species_id, species_id)
	_check("球有消耗", Game.inventory.count(&"ball_sure"), 0)

	_check("立刻停止可被點選", snake.collision_layer, 0)
	_check("演完吸入動畫後從世界移除", await _wait_for(
		func() -> bool: return not is_instance_valid(snake), 8.0), true)


## 真正會被按下的那條路：Q -> Player._throw_ball -> CaptureSystem
func _check_q_key() -> void:
	print("TEST --- Q 鍵 ---")
	var player: Player = _world.get_node("Player")
	var cat: Pet = _world.get_node("Pets/flame_cat")
	# 火焰喵住在火山區（W4 Spawn Point），離出生點五十幾公尺——
	# 先走過去，球的拋物線才有意義。y 用牠的高度，不要讓玩家邊掉邊丟。
	player.global_position = cat.global_position + Vector3(-4.0, 0.0, 0.0)
	await get_tree().physics_frame
	player.active_pet.targeting.set_target(cat)

	var attempts: Array[float] = []
	Game.capture.capture_attempted.connect(
		func(_t: Pet, _b: BallData, _s: bool, rate: float) -> void: attempts.append(rate))

	var before := Game.inventory.count(&"ball_basic")
	var event := InputEventAction.new()
	event.action = &"throw_ball"
	event.pressed = true
	Input.parse_input_event(event)
	# parse_input_event 是**排進下一幀**才處理的，不能只等一個 frame 就去抓特效——
	# 抓到的會是上一段測試留下來的舊特效（症狀：ball_id 變成上一顆球）。
	var guard := 0
	while attempts.is_empty() and guard < 120:
		guard += 1
		await get_tree().process_frame

	var effects := _world.get_children().filter(func(n: Node) -> bool: return n is CaptureEffect)
	var fx: CaptureEffect = effects[-1] if not effects.is_empty() else null

	# **先把飛行軌跡錄下來，再做任何 _check。**
	# print 到主控台每次要好幾毫秒，十幾個 _check 加起來就吃掉拋物線的前段，
	# flight[0] 會錄到「球已經飛到一半」——這條讓正確的演出被判成失敗過。
	var thrower := (_world.get_node("Player") as Node3D).global_position
	var anim_at_launch := fx.sprite.animation if fx != null else &""
	var flight: Array[Vector3] = []
	var frames := int(ceil(CaptureSystem.THROW_SECONDS * 60.0)) + 2
	if fx != null:
		for i in frames:
			flight.append(fx.sprite.global_position)
			await get_tree().physics_frame

	_check("Q 有觸發捕捉判定", attempts.size(), 1)
	_check("Q 有消耗一顆球", Game.inventory.count(&"ball_basic"), before - 1)

	print("TEST --- 捕捉特效 ---")
	_check("判定後有生出特效節點", effects.size() >= 1, true)
	_check("特效知道用哪一顆球", fx.ball_id, &"ball_basic")
	_check("特效在目標身上（不是原點）", fx.global_position.is_equal_approx(Vector3.ZERO), false)

	# 素材真的有接上，不是靜默 fallback
	_check("SpriteFrames 有載入", fx.sprite.sprite_frames != null, true)
	_check("四個動畫都在", [
		fx.sprite.sprite_frames.has_animation(&"ball_basic"),
		fx.sprite.sprite_frames.has_animation(&"ball_great"),
		fx.sprite.sprite_frames.has_animation(&"success"),
		fx.sprite.sprite_frames.has_animation(&"fail"),
	], [true, true, true, true])
	_check("出手就在播搖球動畫", anim_at_launch, &"ball_basic")

	# 拋物線：驗**球真的飛過去**，不是只驗屬性有被設上。
	# 第一版測試就是只驗了屬性，結果球其實一直走「從正上方落下」的退化路徑，
	# 測試全綠但畫面上沒有投擲動作。
	_check("有投擲起點", fx.has_throw_origin, true)
	_check("起點在玩家身上", fx.throw_from.distance_to(thrower) < 2.0, true)

	var landing := fx.global_position + Vector3(0.0, CaptureEffect.REST_Y, 0.0)
	_check("球從玩家那邊出發", flight[0].distance_to(thrower) < 1.5, true)
	_check("球飛到目標身上", flight[-1].distance_to(landing) < 0.6, true)
	_check("中途真的離開了起點",
		flight[frames / 2].distance_to(flight[0]) > 1.0, true)

	# 是弧線不是直線：中點的高度要明顯高於起訖連線
	var straight_mid_y: float = (flight[0].y + landing.y) * 0.5
	_check("中點高於直線（是拋物線）",
		flight[frames / 2].y > straight_mid_y + 0.5, true)

	print("TEST --- 音效 ---")
	var missing: Array[String] = []
	for sfx: String in ["throw", "land", "shake", "success", "fail"]:
		var path := "res://assets/sfx/capture/%s.wav" % sfx
		if not ResourceLoader.exists(path) or load(path) == null:
			missing.append(sfx)
	_check("五個音效都載得到", missing, [] as Array[String])
	_check("特效有 AudioStreamPlayer3D", fx.audio != null, true)

	# 素材還沒進來也不能卡住：特效要會自己消失
	_check("特效播完會自己消失", await _wait_for(
		func() -> bool: return not is_instance_valid(fx), 8.0), true)
