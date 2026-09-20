## PetAI FSM 檢查（規格書 §9）：FOLLOW → CHASE → ATTACK → 目標死亡 → 回到預設狀態。
##
## 直接跑真正的 world.tscn，不另外搭測試場景——測到的才是實際會跑的東西。
##
##   godot --headless --path <專案> res://tests/pet_ai_test.tscn
extends Node

const MAX_FRAMES := 900   # 15 秒 @60fps

var _fail := 0
var _world: Node3D = null


func _ready() -> void:
	_world = load("res://scenes/world/world.tscn").instantiate()
	add_child(_world)
	await get_tree().physics_frame
	await get_tree().physics_frame

	await _run()

	print("TEST ===== %s (%d failures) =====" % ["ALL PASS" if _fail == 0 else "FAILED", _fail])
	get_tree().quit(_fail)


func _run() -> void:
	var starter: Pet = _world.starter
	# 潛水蛇是第一隻可捕捉的（Grass 克 Water），放得近；火焰喵放遠，拿來測 leash
	var wild: Pet = _world.get_node("Pets/diving_snake")
	var far_wild: Pet = _world.get_node("Pets/flame_cat")
	var player: Node3D = _world.get_node("Player")

	print("TEST --- 初始狀態 ---")
	_check("starter behaviour", starter.ai.behaviour, PetAI.Behaviour.FOLLOWER)
	_check("starter anchor 是玩家", starter.ai.follow_anchor, player)
	_check("wild behaviour", wild.ai.behaviour, PetAI.Behaviour.WILD)
	_check("wild 起始 IDLE", wild.ai.state, PetAI.State.IDLE)
	_check("第一隻可捕捉的是 Water 的潛水蛇", wild.data.element, Element.Type.WATER)
	_check("Starter 是 Grass（克 Water）", starter.data.element, Element.Type.GRASS)
	_check("starter layer = PetFriendly|Selectable", starter.collision_layer, (1 << 2) | (1 << 8))
	_check("wild layer = Enemy|Selectable", wild.collision_layer, (1 << 3) | (1 << 8))
	_check("普攻威力來自 basic_attack.power", starter.combat.attack_power,
		Database.get_pet(&"eggshell_dragon").basic_attack.power)

	print("TEST --- FOLLOW：玩家走遠，寵物跟上 ---")
	player.global_position = Vector3(12.0, 1.0, 12.0)
	var followed := await _wait_until(func() -> bool:
		return starter.global_position.distance_to(player.global_position) < starter.ai.follow_distance + 0.5)
	_check("跟到玩家附近", followed, true)
	_check("到位後回 IDLE", await _wait_until(func() -> bool:
		return starter.ai.state == PetAI.State.IDLE), true)

	print("TEST --- 滑鼠指揮：raycast 打得到 Selectable ---")
	# 不模擬滑鼠事件，直接驗證 Player 用的那條 ray 與 mask 打不打得中寵物。
	var camera := _world.get_node("OrbitCamera/Camera3D") as Camera3D
	_check("相機是 current", camera.current, true)
	var screen_pos := camera.unproject_position(wild.global_position + Vector3(0, 0.6, 0))
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * Player.PICK_DISTANCE
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = Player.SELECT_MASK
	var hit := _world.get_world_3d().direct_space_state.intersect_ray(query)
	_check("ray 打到東西", not hit.is_empty(), true)
	_check("打到的是那隻野生寵物", hit.get("collider"), wild)

	# 玩家的地面 / 其他 layer 不該被 Selectable mask 打到
	var ground_screen := camera.unproject_position(Vector3(20.0, 0.0, 20.0))
	var gfrom := camera.project_ray_origin(ground_screen)
	var gquery := PhysicsRayQueryParameters3D.create(
		gfrom, gfrom + camera.project_ray_normal(ground_screen) * Player.PICK_DISTANCE)
	gquery.collision_mask = Player.SELECT_MASK
	_check("點空地不會誤中地面", _world.get_world_3d().direct_space_state
		.intersect_ray(gquery).is_empty(), true)

	print("TEST --- leash：目標超出 leash_distance 就返回 ---")
	# 玩家在 (12,12)、火焰喵在火山區 (-56,12)，相距遠大於 leash_distance 20
	starter.ai.issue_command(PetCommand.Type.ATTACK_TARGET, far_wild)
	_check("超出 leash 會轉 RETURN", await _wait_until(func() -> bool:
		return starter.ai.state == PetAI.State.RETURN), true)

	print("TEST --- ATTACK_TARGET：CHASE -> ATTACK ---")
	# 把玩家帶到目標附近，讓追擊落在 leash 範圍內。
	# 野生寵物住在自己的區域（潛水蛇在水系學校），離出生點幾十公尺，
	# 所以不能再寫死座標——連寵物一起挪過去，不然牠要自己跑半張地圖。
	player.global_position = wild.global_position + Vector3(-4.0, 1.0, 0.0)
	starter.global_position = player.global_position + Vector3(1.0, 0.0, 1.0)
	starter.ai.issue_command(PetCommand.Type.FOLLOW)
	_check("玩家回到原點後寵物跟上", await _wait_until(func() -> bool:
		return starter.global_position.distance_to(player.global_position) < starter.ai.follow_distance + 0.5), true)

	var wild_hp_before: float = wild.health.current_health
	starter.ai.issue_command(PetCommand.Type.ATTACK_TARGET, wild)
	_check("指令後進入 CHASE", starter.ai.state, PetAI.State.CHASE)

	var reached := await _wait_until(func() -> bool:
		return starter.ai.state == PetAI.State.ATTACK or starter.ai.state == PetAI.State.CAST_SKILL)
	_check("追到並進入 ATTACK/CAST_SKILL", reached, true)
	_check("在攻擊射程內", starter.combat.in_range(wild), true)

	var damaged := await _wait_until(func() -> bool:
		return wild.health.current_health < wild_hp_before)
	_check("野生寵物開始掉血", damaged, true)

	print("TEST --- 反擊：被打之後 wild 自己接敵 ---")
	_check("wild 取得目標", await _wait_until(func() -> bool:
		return wild.targeting.current_target == starter), true)
	_check("wild 離開 IDLE", await _wait_until(func() -> bool:
		return wild.ai.state != PetAI.State.IDLE), true)
	_check("wild 真的打回來（starter 掉血）", await _wait_until(func() -> bool:
		return starter.health.current_health < starter.health.max_health), true)

	print("TEST --- 血條 ---")
	_check("沒受傷的寵物血條隱藏", far_wild.health_bar.visible, false)
	_check("starter 被反擊後血條出現", starter.health_bar.visible, true)

	print("TEST --- 目標死亡與屍體（回報的 bug）---")
	# 玩家點了怪物卻「完全沒反應」，原因是點到了先前打死、卻還留在 Selectable 層的屍體。
	wild.health.take_damage(9999.0)
	await get_tree().physics_frame
	_check("wild 進入 DEAD", wild.ai.state, PetAI.State.DEAD)
	_check("屍體離開 Selectable 層", (wild.collision_layer & (1 << 8)) != 0, false)
	_check("raycast 打不到屍體", _ray_hits(wild), false)

	starter.ai.issue_command(PetCommand.Type.FOLLOW)
	await get_tree().physics_frame
	# GDScript 的 lambda 對區域變數是「傳值」捕獲，寫回去外面看不到。
	# 要觀察副作用就得用參考型別（Array / Dictionary / 成員變數）。
	var rejected: Array[bool] = [false]
	starter.ai.command_rejected.connect(func(_r: StringName) -> void: rejected[0] = true)
	var state_before: PetAI.State = starter.ai.state
	starter.targeting.clear_target()
	starter.ai.issue_command(PetCommand.Type.ATTACK_TARGET, wild)
	_check("對屍體下指令會被拒絕", rejected[0], true)
	_check("狀態不會閃一下 CHASE", starter.ai.state, state_before)
	_check("目標不會被設成屍體", starter.targeting.current_target, null)

	_check("野生寵物屍體會淡出移除", await _wait_until(func() -> bool:
		return not is_instance_valid(wild), 180), true)

	_check("starter 回到 FOLLOW/IDLE", await _wait_until(func() -> bool:
		return starter.ai.state == PetAI.State.FOLLOW or starter.ai.state == PetAI.State.IDLE), true)


func _ray_hits(target: Node3D) -> bool:
	var camera := _world.get_node("OrbitCamera/Camera3D") as Camera3D
	var screen_pos := camera.unproject_position(target.global_position + Vector3(0, 0.6, 0))
	var from := camera.project_ray_origin(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(
		from, from + camera.project_ray_normal(screen_pos) * Player.PICK_DISTANCE)
	query.collision_mask = Player.SELECT_MASK
	var hit := _world.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider") == target


## 等到 condition 成立為止，回傳是否成立。
func _wait_until(condition: Callable, max_frames: int = MAX_FRAMES) -> bool:
	for i in max_frames:
		if condition.call():
			return true
		await get_tree().physics_frame
	return false


func _check(label: String, got: Variant, want: Variant) -> void:
	var ok: bool = false
	if typeof(got) == TYPE_FLOAT and typeof(want) == TYPE_FLOAT:
		ok = is_equal_approx(got, want)
	else:
		ok = got == want
	if not ok:
		_fail += 1
	print("TEST %s %-34s got=%s want=%s" % ["OK  " if ok else "FAIL", label, got, want])
