## Milestone W2 — Navigation 驗收（`docs/PHASE_WORLD_PROTOTYPE.md` §13）。
##
## 文件的驗收是「玩家不穿牆」與「蛋殼龍可以從草原跟到主要區域」。
##
## 穿牆由碰撞保證（W1 已經做完，`world_zones_test` 在守）；
## 這裡守的是**路徑**：烤出來的 NavigationMesh 要知道校舍、火山、房子在哪，
## 算出來的路要繞過去而不是直接穿過去。
##
##   godot --headless --path <專案> res://tests/navigation_test.tscn
extends Node

var _fail := 0
var _world: Node3D = null
var _player: Player = null
var _map: RID


func _ready() -> void:
	_world = load("res://scenes/world/world.tscn").instantiate()
	add_child(_world)
	_player = _world.get_node("Player")
	await get_tree().physics_frame
	# NavigationServer 的地圖要等它自己同步完才查得到路
	await NavigationServer3D.map_changed
	await get_tree().physics_frame
	_map = _world.get_world_3d().navigation_map
	# NavigationServer 是在 physics frame 結束時才同步的，map_changed 之後
	# 還不保證查得到路。等到真的問得出一條路再開始檢查。
	var ready := await _wait_for(func() -> bool:
		return _path(Vector3.ZERO, Vector3(10, 0, 0)).size() > 0, 5.0)
	_check("NavigationServer 已就緒", ready, true)

	_check_reachable()
	_check_paths_go_around()
	await _check_pet_follows_to_school()
	await _check_pet_rounds_the_corner()

	print("TEST ===== %s (%d failures) =====" % ["ALL PASS" if _fail == 0 else "FAILED", _fail])
	get_tree().quit(_fail)


func _check(label: String, got: Variant, want: Variant) -> void:
	var ok: bool = got == want
	if not ok:
		_fail += 1
	print("TEST %s %-42s got=%s want=%s" % ["OK  " if ok else "FAIL", label, got, want])


func _path(from: Vector3, to: Vector3) -> PackedVector3Array:
	return NavigationServer3D.map_get_path(_map, from, to, true)


## 五區之間都要走得到——路徑的終點必須真的落在目的地附近。
## 路徑被牆完全擋死時，NavigationServer 會回傳一條停在半路的路。
func _check_reachable() -> void:
	print("TEST --- 草原到各區都有路 ---")
	var destinations := {
		"水系學校": Vector3(52, 0, 8),
		"火山": Vector3(-46, 0, 12),
		"山區": Vector3(0, 0, -45),
		# 不要挑「你家」那棟房子的位置——那裡本來就走不進去
		"聚落": Vector3(10, 0, 52),
	}
	for name: String in destinations:
		var goal: Vector3 = destinations[name]
		var path := _path(Vector3.ZERO, goal)
		var arrived := path.size() > 0 and path[-1].distance_to(goal) < 2.0
		_check("走得到%s" % name, arrived, true)


## 路要繞過建築，不是穿過去。
##
## 判準：起點與終點分別在校舍的兩側，直線會穿過建築；
## 所以路徑一定會比直線長，而且中間必須有轉折點。
func _check_paths_go_around() -> void:
	print("TEST --- 路徑會繞過建築 ---")
	# 校舍在 (52, -8) 附近，佔 26 × 14。從北邊走到南邊
	var north := Vector3(52, 0, -20)
	var south := Vector3(52, 0, 6)
	var path := _path(north, south)
	var straight := north.distance_to(south)
	var walked := 0.0
	for i in range(1, path.size()):
		walked += path[i - 1].distance_to(path[i])

	_check("有算出路徑", path.size() >= 2, true)
	_check("路徑有轉折（不是一條直線穿過去）", path.size() > 2, true)
	_check("繞路比直線遠", walked > straight + 4.0, true)

	# 校舍裡面**進不去**。
	#
	# 注意判準：不要用 map_get_closest_point 去問「那裡是不是可走區域」——
	# Recast 不會把封閉建築的室內挖掉，它會留下一塊四面被牆圍住的**孤島** navmesh。
	# 那塊多邊形確實存在（closest_point 找得到），但從外面走不進去，
	# 這正是我們要的結果。所以要驗的是**到不了**，不是「不存在」。
	var inside := Vector3(52, 0, -8)
	var blocked := _path(south, inside)
	var reached_inside := blocked.size() > 0 and blocked[-1].distance_to(inside) < 3.0
	_check("走不進校舍裡面", reached_inside, false)


## 文件的驗收句：蛋殼龍可以從草原跟到主要區域。
##
## 真的用走的——62 公尺、`move_speed` 4，所以放寬到 40 秒。
## 這是整套測試裡最慢的一條，但它是這個 Milestone 的定義。
func _check_pet_follows_to_school() -> void:
	print("TEST --- 蛋殼龍從草原跟到學校 ---")
	var pet := _player.active_pet
	_check("出戰的是蛋殼龍", pet.data.id, &"eggshell_dragon")

	# 玩家走到學校南側（校舍的另一邊），寵物得繞過建築才跟得到
	var destination := Vector3(52.0, 1.0, 10.0)
	_player.global_position = destination
	var arrived := await _wait_for(func() -> bool:
		return (is_instance_valid(pet)
			and pet.global_position.distance_to(destination) < 6.0), 40.0)
	_check("蛋殼龍跟到學校", arrived, true)
	_check("沒有卡在校舍裡", _inside_school(pet.global_position), false)


## 卡牆角是實際玩到的問題（使用者回報）：路貼著牆角切，寵物就一路磨著牆走。
##
## 這條把寵物丟到校舍**正北**、玩家放在**正南**，中間隔著 26 × 14 的建築。
## 唯一的路就是繞過去；卡住的話就到不了。
func _check_pet_rounds_the_corner() -> void:
	print("TEST --- 繞過校舍不卡牆角 ---")
	var pet := _player.active_pet
	var south := Vector3(52.0, 1.0, 6.0)
	_player.global_position = south
	pet.global_position = Vector3(52.0, 0.0, -22.0)
	pet.ai.issue_command(PetCommand.Type.FOLLOW)

	var arrived := await _wait_for(func() -> bool:
		return (is_instance_valid(pet)
			and pet.global_position.distance_to(south) < 6.0), 30.0)
	_check("從校舍北邊繞到南邊", arrived, true)


func _inside_school(at: Vector3) -> bool:
	# 校舍 26 × 14，中心 (52, -8)
	return absf(at.x - 52.0) < 13.0 and absf(at.z + 8.0) < 7.0


func _wait_for(condition: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()
