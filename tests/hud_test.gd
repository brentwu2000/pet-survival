## Basic HUD 檢查（規格書 §26 Phase 1 最後一項）。
##
##   godot --headless --path <專案> res://tests/hud_test.tscn
##
## HUD 不改任何 gameplay 狀態，所以這裡檢查的全是「畫面上寫了什麼」——
## 讀 `Hud.ball_text()` / `slot_text()` / `target_text()` / `notice_text()`。
extends Node

var _fail := 0
var _world: Node3D = null
var _hud: Hud = null
var _player: Player = null


func _ready() -> void:
	_world = load("res://scenes/world/world.tscn").instantiate()
	add_child(_world)
	await get_tree().physics_frame
	await get_tree().physics_frame

	_hud = _world.get_node("Hud")
	_player = _world.get_node("Player")

	_check_start_state()
	_check_layout()
	_check_party_slots()
	await _check_target_panel()
	_check_switch_notice()
	await _check_capture_notice()

	print("TEST ===== %s (%d failures) =====" % ["ALL PASS" if _fail == 0 else "FAILED", _fail])
	get_tree().quit(_fail)


func _check(label: String, got: Variant, want: Variant) -> void:
	var ok: bool = got == want
	if not ok:
		_fail += 1
	print("TEST %s %-42s got=%s want=%s" % ["OK  " if ok else "FAIL", label, got, want])


func _check_contains(label: String, got: String, want: String) -> void:
	var ok := got.contains(want)
	if not ok:
		_fail += 1
	print("TEST %s %-42s got=%s want~%s" % ["OK  " if ok else "FAIL", label, got, want])


func _snake() -> Pet:
	return _world.get_node("Pets/diving_snake")


## 開局：球數要顯示、Starter 在第 1 格、沒有目標面板。
func _check_start_state() -> void:
	_check_contains("開局球數", _hud.ball_text(), "×10")
	_check_contains("第 1 格是 Starter", _hud.slot_text(0), "1 蛋殼龍")
	_check("開局沒有目標面板", _hud.target_text(), "")


## anchor 是手寫的，headless 看不到畫面，只能驗錨點算出來的位置。
##
## **不要拿「在不在螢幕裡」當判準**——headless 的 viewport 只有 64×64，
## HUD 一定超出去，那是無視窗的假象不是 bug。要驗的是相對於畫面的錨點關係。
func _check_layout() -> void:
	var root: Control = _hud.get_node("Root")
	var bottom: Control = _hud.get_node("Root/BottomBar")
	var target: Control = _hud.get_node("Root/TargetPanel")
	var first := _slot_rect(0)
	var last := _slot_rect(PartyManager.MAX_SIZE - 1)

	_check("Root 跟著整個畫面", root.size, get_viewport().get_visible_rect().size)
	_check("Party 置中", is_equal_approx(
		(first.position.x + last.end.x) * 0.5, root.size.x * 0.5), true)
	_check("格子不重疊、由左往右排", first.end.x <= last.position.x, true)
	_check("Party 貼畫面下緣", is_equal_approx(
		bottom.global_position.y + bottom.size.y, root.size.y - Hud.MARGIN), true)
	_check("目標面板貼畫面上緣", is_equal_approx(target.global_position.y, Hud.MARGIN), true)
	_check("目標面板置中", is_equal_approx(
		target.global_position.x + target.size.x * 0.5, root.size.x * 0.5), true)


func _slot_rect(index: int) -> Rect2:
	var slot: Control = _hud.get_node("Root/BottomBar/Row/PartyBar/Slot%d" % (index + 1))
	return Rect2(slot.global_position, slot.size)


func _check_party_slots() -> void:
	# 上限 5 是硬規則，空格子也要畫出來，玩家才知道還有幾個位子
	for i in range(1, PartyManager.MAX_SIZE):
		_check_contains("第 %d 格是空的" % (i + 1), _hud.slot_text(i), "%d --" % (i + 1))
	_check("沒有第 6 格", _hud.slot_text(PartyManager.MAX_SIZE), "")


## 指定目標 -> 目標面板出現；目標掉血 -> 血條跟著掉。
func _check_target_panel() -> void:
	var snake := _snake()
	_player.active_pet.ai.issue_command(PetCommand.Type.ATTACK_TARGET, snake)
	await get_tree().process_frame

	_check_contains("目標面板顯示目標", _hud.target_text(), "潛水蛇")
	_check("滿血時比例 1.0", _hud.target_ratio(), 1.0)

	snake.health.take_damage(snake.health.max_health * 0.5)
	await get_tree().process_frame
	_check("掉一半血後比例 0.5", _hud.target_ratio(), 0.5)
	_check_contains("目標面板顯示 HP 數字", _hud.target_text(), "/%d" % int(snake.health.max_health))

	# 出戰寵物掉血 -> 換成它那一格更新
	var active := _player.active_pet
	active.health.take_damage(10.0)
	await get_tree().process_frame
	_check_contains("出戰格子的 HP 跟著掉", _hud.slot_text(0),
		"%d/%d" % [ceili(active.health.current_health), int(active.health.max_health)])


## 切到空格子要有提示（原本是 print）。
func _check_switch_notice() -> void:
	_player.switch_to_slot(1)
	_check_contains("切空格子有提示", _hud.notice_text(), "第 2 格")
	_check_contains("切空格子講得出原因", _hud.notice_text(), "空的")


## 丟球被拒 / 丟球失敗都要有提示，球數要跟著減。
func _check_capture_notice() -> void:
	var ball: BallData = Database.get_item(&"ball_basic")

	# 沒有目標就丟球：被 CaptureSystem 擋下，球不消耗
	Game.capture.attempt_capture(null, ball)
	_check_contains("沒目標丟球有提示", _hud.notice_text(), "不能丟球")
	_check_contains("球數沒有被扣", _hud.ball_text(), "×10")

	# 對滿血的目標丟球：成功率極低，這裡只驗提示與扣球
	var snake := _snake()
	Game.capture.attempt_capture(snake, ball)
	await get_tree().process_frame
	_check_contains("丟球後球數 -1", _hud.ball_text(), "×9")
	_check_contains("丟球結果有提示", _hud.notice_text(), "捕捉")
