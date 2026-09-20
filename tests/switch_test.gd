## Phase 1 驗收流程（規劃書 §15，2026-09 修訂版）＋ 換寵（§14 step 14）。
##
##   蛋殼龍削弱潛水蛇 → 捕捉 → 按 2 切換潛水蛇 → 潛水蛇打火焰喵 → 捕捉火焰喵
##
## 跑真正的 world.tscn，戰鬥是真打。只有球用 guaranteed，避免亂數讓測試不穩；
## 捕捉率本身由 capture_test 負責。
##
##   godot --headless --path <專案> res://tests/switch_test.tscn
extends Node

var _fail := 0
var _world: Node3D = null
var _player: Player = null


func _ready() -> void:
	_world = load("res://scenes/world/world.tscn").instantiate()
	add_child(_world)
	_player = _world.get_node("Player")
	await get_tree().physics_frame
	await get_tree().physics_frame

	await _run()

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


## 用真實時間等，不要用 frame 數（見 capture_test）。
func _wait_for(condition: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	await get_tree().physics_frame


## 場上還在演的換寵球。
func _balls() -> Array[Node]:
	return _world.get_children().filter(func(n: Node) -> bool: return n is SummonEffect)


## 把玩家與出戰寵物一起挪過去。
## 只挪玩家的話，寵物要自己跑五十幾公尺才追得上——測試會拖到天荒地老。
func _move_to(position: Vector3) -> void:
	_player.global_position = position
	if is_instance_valid(_player.active_pet):
		_player.active_pet.global_position = position + Vector3(1.5, 0.0, 1.5)


func _followers() -> Array[Node]:
	return _world.get_node("Pets").get_children().filter(_is_live_follower)


func _is_live_follower(n: Node) -> bool:
	return (n is Pet and not n.is_queued_for_deletion()
		and (n as Pet).ai.behaviour == PetAI.Behaviour.FOLLOWER
		and not (n as Pet).health.is_dead)


## 讓出戰寵物把目標打到半血以下（但還活著）就丟球。
func _weaken_and_capture(target: Pet) -> bool:
	var ball := BallData.new()
	ball.id = &"ball_test_sure"
	ball.guaranteed = true
	Game.inventory.add(ball.id, 1)

	_player.active_pet.ai.issue_command(PetCommand.Type.ATTACK_TARGET, target)
	var weakened := await _wait_for(func() -> bool:
		return (is_instance_valid(target) and not target.health.is_dead
			and target.health.health_ratio < 0.5), 20.0)
	if not weakened:
		return false
	return Game.capture.attempt_capture(target, ball)


func _run() -> void:
	var snake: Pet = _world.get_node("Pets/diving_snake")
	var cat: Pet = _world.get_node("Pets/flame_cat")

	print("TEST --- 開局：節點由 PartyManager 生出來 ---")
	_check("出戰的是蛋殼龍", _player.active_pet.data.id, &"eggshell_dragon")
	_check("節點綁到 Party 的出戰 instance", _player.active_pet.instance, Game.party.active)
	_check("world.starter 就是它", _world.starter, _player.active_pet)
	_check("場上只有一隻自家寵物", _followers().size(), 1)

	print("TEST --- 1. 蛋殼龍削弱並捕捉潛水蛇 ---")
	var dragon := _player.active_pet
	var dragon_instance := dragon.instance
	# 潛水蛇住在水系學校的廁所旁邊（W4 Spawn Point），不在出生點了
	_move_to(snake.global_position + Vector3(-3.0, 1.0, 2.0))
	_check("削弱後捕捉成功", await _weaken_and_capture(snake), true)
	_check("潛水蛇進了 Party 第 2 格", Game.party.at(1).species_id, &"diving_snake")
	_check("捕捉的演出結束、野生潛水蛇移除", await _wait_for(
		func() -> bool: return not is_instance_valid(snake), 8.0), true)
	_check("抓到的潛水蛇是滿血", Game.party.at(1).current_hp,
		Database.get_pet(&"diving_snake").max_hp)

	print("TEST --- HP 同步 ---")
	# 潛水蛇常常還沒反擊就被抓了，所以直接打一下，不靠戰鬥的隨機結果
	var hp_before_hit := dragon.health.current_health
	dragon.health.take_damage(17.0)
	_check("節點 HP 即時寫回 instance", dragon_instance.current_hp, hp_before_hit - 17.0)
	var dragon_hp := dragon_instance.current_hp

	print("TEST --- 2. 按 2 切換到潛水蛇 ---")
	await _press(&"pet_slot_2")
	_check("Party active_index = 1", Game.party.active_index, 1)
	_check("場上出戰的換成潛水蛇", _player.active_pet.data.id, &"diving_snake")
	_check("新節點綁到潛水蛇的 instance", _player.active_pet.instance, Game.party.at(1))
	_check("潛水蛇以 instance 的 HP 出場", _player.active_pet.health.current_health,
		Game.party.at(1).current_hp)
	_check("舊的蛋殼龍節點被收回", await _wait_for(
		func() -> bool: return not is_instance_valid(dragon), 2.0), true)
	_check("場上仍然只有一隻自家寵物（同時出戰 1）", _followers().size(), 1)
	_check("收回的蛋殼龍 HP 留在 instance", dragon_instance.current_hp, dragon_hp)

	print("TEST --- 換寵演出（喚出 / 收回）---")
	var outgoing := _player.active_pet
	var snake_scale: float = Database.get_pet(&"diving_snake").visual_scale
	# 先等上一次換寵的演出完全結束，這一段才有乾淨的起點：
	# 潛水蛇站定（球飛過去 + 彈出來都跑完）、場上沒有殘留的球
	_check("上一次的演出跑完", await _wait_for(func() -> bool:
		return (is_equal_approx(outgoing.visual.scale.x, snake_scale)
			and _balls().is_empty()), 5.0), true)

	await _press(&"pet_slot_1")
	var incoming := _player.active_pet
	var full_scale: float = Database.get_pet(&"eggshell_dragon").visual_scale

	# 兩顆球：一顆飛去接舊的，一顆把新的送出來
	_check("生出兩顆球（收回 + 喚出）", _balls().size(), 2)
	_check("球從玩家手上出發 / 回到玩家手上", _balls().all(func(n: Node) -> bool:
		return (n as SummonEffect).hand_position.distance_to(
			_player.global_position) < 2.0), true)
	# 按下去的當下：新的還看不見（等球飛到）、舊的正在縮小（不是瞬間消失）
	_check("新寵物等球飛到才出現", incoming.visual.scale.x < full_scale, true)
	_check("舊寵物沒有瞬間消失", is_instance_valid(outgoing), true)

	# 收回：球留在玩家手上，怪被吸過去（不是球飛出去接牠）
	var recall_ball: SummonEffect = null
	for ball: Node in _balls():
		if (ball as SummonEffect).mode == SummonEffect.Mode.RECALL:
			recall_ball = ball
	_check("收回的球在玩家手上", recall_ball != null and
		recall_ball.global_position.distance_to(_player.global_position) < 2.0, true)
	# 用座標不用節點——球會先演完被 free，lambda 抓著節點會噴 freed capture
	var ball_pos: Vector3 = recall_ball.global_position if recall_ball != null else Vector3.ZERO
	var distance_before := outgoing.global_position.distance_to(ball_pos)
	_check("舊寵物被吸向球", await _wait_for(func() -> bool:
		return (is_instance_valid(outgoing)
			and outgoing.global_position.distance_to(ball_pos) < distance_before - 0.2),
		1.0), true)
	# Input.parse_input_event 是排進下一幀才處理的，所以 tween 不一定已經走過一步——
	# 這裡要等一下下，不能在按下去的同一幀就斷定它在縮小
	_check("舊寵物縮小中", await _wait_for(func() -> bool:
		return is_instance_valid(outgoing) and outgoing.visual.scale.x < snake_scale * 0.9,
		1.0), true)
	_check("收回中不再吃碰撞", outgoing.collision_layer, 0)
	_check("演完回到正常大小", await _wait_for(func() -> bool:
		return is_equal_approx(incoming.visual.scale.x, full_scale), 2.0), true)
	_check("演完淡入完成", is_equal_approx(incoming.visual.sprite.modulate.a, 1.0), true)
	_check("收回演完就移除", await _wait_for(
		func() -> bool: return not is_instance_valid(outgoing), 2.0), true)
	_check("球演完自己收掉", await _wait_for(
		func() -> bool: return _balls().is_empty(), 4.0), true)

	print("TEST --- 換回來不會免費補血 ---")
	_check("切回蛋殼龍", _player.active_pet.data.id, &"eggshell_dragon")
	_check("HP 還是離場時的值", _player.active_pet.health.current_health, dragon_hp)
	_check("按同一格不會重生節點", _player.switch_to_slot(0), false)
	_check("切到空格子失敗", _player.switch_to_slot(4), false)
	_check("失敗時出戰不變", _player.active_pet.data.id, &"eggshell_dragon")
	await _press(&"pet_slot_2")
	_check("再切到潛水蛇", _player.active_pet.data.id, &"diving_snake")

	print("TEST --- 3. 潛水蛇打火焰喵，換寵時目標會被接手 ---")
	# 火焰喵住在火山區
	_move_to(cat.global_position + Vector3(-3.0, 1.0, 2.0))
	await _wait_for(func() -> bool:
		return _player.active_pet.global_position.distance_to(_player.global_position) < 4.0, 6.0)
	var water: Pet = _player.active_pet
	water.ai.issue_command(PetCommand.Type.ATTACK_TARGET, cat)
	_check("火焰喵開始掉血", await _wait_for(
		func() -> bool: return cat.health.current_health < cat.health.max_health, 10.0), true)
	await _press(&"pet_slot_1")
	_check("戰鬥中換成蛋殼龍，接手同一個目標",
		_player.active_pet.targeting.current_target, cat)
	await _press(&"pet_slot_2")
	_check("再換回潛水蛇，目標還是火焰喵",
		_player.active_pet.targeting.current_target, cat)

	print("TEST --- 4. 用潛水蛇削弱並捕捉火焰喵 ---")
	_check("削弱後捕捉成功", await _weaken_and_capture(cat), true)
	_check("火焰喵進了 Party 第 3 格", Game.party.at(2).species_id, &"flame_cat")
	_check("潛水蛇打贏時還活著", _player.active_pet.health.is_dead, false)
	_check("出戰的仍是潛水蛇", _player.active_pet.data.id, &"diving_snake")
	_check("收藏共 3 隻", Game.collection.size(), 3)

	print("TEST --- 出戰寵物倒下：自動換下一隻 ---")
	var fainted := _player.active_pet
	fainted.health.take_damage(9999.0)
	_check("自動換上可出戰的寵物", await _wait_for(
		func() -> bool: return _player.active_pet != fainted, 2.0), true)
	_check("倒下的 instance is_fainted", fainted.instance == null and Game.party.at(1).is_fainted, true)
	_check("換上來的是活的", _player.active_pet.health.is_dead, false)
	_check("切到倒下的寵物失敗", _player.switch_to_slot(1), false)
	_check("倒下的屍體淡出移除", await _wait_for(
		func() -> bool: return not is_instance_valid(fainted), 4.0), true)
