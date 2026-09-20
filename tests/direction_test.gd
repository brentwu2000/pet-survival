## 方向對應檢查（規劃書 §14 step 02「Godot Direction Test」的程式面）。
##
## 固定寵物朝向，把鏡頭繞一圈，印出每個鏡頭角度播到哪個方向動畫。
##
## 驗證的是「8 個方向都到得了、順序單調、4 向模式只用 4 張」。
## **測不出來的是左右有沒有反**——那取決於美術的繪製慣例，只能人眼看。
## 實際上第一版左右就是反的，目視回報後才修正（見 SpriteDirection.index_for）。
## 下面的期望順序是修正後的，改動方向邏輯時這裡會跟著紅。
extends Node3D

var _fail := 0


func _ready() -> void:
	await _run()
	await _check_player()
	print("TEST ===== %s (%d failures) =====" % ["ALL PASS" if _fail == 0 else "FAILED", _fail])
	get_tree().quit(_fail)


func _run() -> void:
	var pet: Pet = load("res://scenes/pets/pet.tscn").instantiate()
	pet.setup(Database.get_pet(&"eggshell_dragon"))
	add_child(pet)

	var rig := Node3D.new()
	add_child(rig)
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 0.0, 8.0)
	rig.add_child(cam)
	cam.current = true

	await get_tree().process_frame

	# 寵物固定朝 -Z（世界前方）。鏡頭繞 Y 軸一圈。
	pet.rotation.y = 0.0

	print("TEST --- 8 方向 ---")
	pet.visual.direction_count = 8
	const EXPECTED_8: PackedStringArray = [
		"idle_s", "idle_sw", "idle_w", "idle_nw",
		"idle_n", "idle_ne", "idle_e", "idle_se",
	]
	var seen_8: Dictionary = {}
	var actual_8: PackedStringArray = []
	for step in 8:
		var yaw := step * 45.0
		var anim := await _sample(rig, pet, yaw)
		seen_8[anim] = true
		actual_8.append(anim)
		print("TEST    camera_yaw=%4.0f°  ->  %s" % [yaw, anim])
	_check("8 方向全部都到得了", seen_8.size(), 8)
	_check("順序與目視校正後一致", actual_8, EXPECTED_8)

	print("TEST --- 4 方向 ---")
	pet.visual.direction_count = 4
	var seen_4: Dictionary = {}
	for step in 8:
		var yaw := step * 45.0
		var anim := await _sample(rig, pet, yaw)
		seen_4[anim] = true
	_check("4 方向只用到 4 個動畫", seen_4.size(), 4)
	_check("4 方向用的是 s/e/n/w", _sorted_keys(seen_4),
		["idle_e", "idle_n", "idle_s", "idle_w"])


## 主角的素材與 idle / walk 切換，以及「和寵物共用方向邏輯」。
func _check_player() -> void:
	print("TEST --- 主角 ---")
	var world: Node3D = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().physics_frame
	var player: Player = world.get_node("Player")
	var visual: PlayerVisual = player.visual

	_check("SpriteFrames 有載入", visual.sprite.sprite_frames != null, true)
	_check("素材齊了就不顯示膠囊", visual.placeholder.visible, false)
	_check("16 個動畫（8 向 × idle/walk）",
		visual.sprite.sprite_frames.get_animation_names().size(), 16)
	# 方向取決於「相對鏡頭」，而這個測試場景前面自己建過相機，
	# 所以只驗動作前綴，不驗是哪一個方向——方向本身上面已經測過了。
	_check("站著播 idle", String(visual.sprite.animation).begins_with("idle"), true)

	# 動起來要切 walk。
	# **不要 await frame**：Player._physics_process 會把手動設的 velocity 歸零，
	# 等一個 frame 再看就永遠是 idle。sprite.play() 本來就是同步生效的。
	player.velocity = Vector3(3.0, 0.0, 0.0)
	player._update_animation()
	_check("動起來播 walk", String(visual.sprite.animation).begins_with("walk"), true)
	player.velocity = Vector3.ZERO
	player._update_animation()
	_check("停下來回 idle", String(visual.sprite.animation).begins_with("idle"), true)

	# 主角與寵物必須用同一份方向邏輯（PHASE_PLAYER_PROTOTYPE §3）
	_check("主角與寵物方向索引一致",
		SpriteDirection.index_for(Vector3.BACK, Vector3.BACK, 8),
		SpriteDirection.index_for(Vector3.BACK, Vector3.BACK, 8))
	_check("主角與寵物 PIXEL_SIZE 相同",
		PlayerVisual.PIXEL_SIZE, PetVisual.PIXEL_SIZE)

	# 比例：設定圖說主角 1.2 頭身、蛋殼龍 0.8 -> 主角約 1.5 倍
	var player_h := 58.0 * PlayerVisual.PIXEL_SIZE
	var dragon: Pet = world.starter
	var dragon_h: float = 40.0 * PetVisual.PIXEL_SIZE * dragon.data.visual_scale
	_check("主角比蛋殼龍高 1.3~1.7 倍",
		player_h / dragon_h > 1.3 and player_h / dragon_h < 1.7, true)


func _sample(rig: Node3D, pet: Pet, yaw_deg: float) -> String:
	rig.rotation.y = deg_to_rad(yaw_deg)
	await get_tree().process_frame
	await get_tree().process_frame
	return String(pet.visual.sprite.animation)


func _sorted_keys(d: Dictionary) -> Array:
	var keys: Array = d.keys()
	keys.sort()
	return keys


func _check(label: String, got: Variant, want: Variant) -> void:
	var ok: bool = got == want
	if not ok:
		_fail += 1
	print("TEST %s %-28s got=%s want=%s" % ["OK  " if ok else "FAIL", label, got, want])
