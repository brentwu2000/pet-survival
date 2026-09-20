## Milestone W1 — World Graybox 驗收（`docs/PHASE_WORLD_PROTOTYPE.md` §13）。
##
## 文件的驗收條件是「玩家可以從草原走到全部五區」。
## 真的用走的要 40 秒以上的實際時間，所以這裡改驗**走得過去的前提**：
## 從草原中心到每一區，沿路每 5 公尺往下打一條 raycast，確認腳下都有地板。
## 灰盒階段最容易出的錯就是區域之間有洞、或某一區飄在地板外面。
##
##   godot --headless --path <專案> res://tests/world_zones_test.tscn
extends Node

var _fail := 0
var _world: Node3D = null

## 五區的 id 與它們在世界座標的中心。與 world.tscn 的擺法一致。
## 四區與草原**邊對邊相接**：草原半徑 30 + 區域半徑 22 = 52。
## 中間不留空隙、不鋪道路——區塊之間不該有一條跟誰都不一樣的帶子。
const ZONES := {
	&"grassland": Vector3(0, 0, 0),
	&"water_school": Vector3(52, 0, 0),
	&"fire_zone": Vector3(-52, 0, 0),
	&"mountain": Vector3(0, 0, -52),
	&"village": Vector3(0, 0, 52),
}
const GRASS_HALF := 30.0
const ZONE_HALF := 22.0

## 每一區至少要有的 Spawn Point（W4 才接上，W1 先確認位置都標好了）。
const SPAWNS := {
	&"grassland": ["PlayerSpawn", "EggshellDragonSpawn"],
	&"water_school": ["WaterSnakeSpawn"],
	&"fire_zone": ["FireCatSpawn"],
	&"mountain": ["CaveEntranceMarker"],
	&"village": ["BaseCoreSpawn", "HomeDoorSpawn"],
}

## 地形在 layer 1 World。
const WORLD_MASK := 1


func _ready() -> void:
	_world = load("res://scenes/world/world.tscn").instantiate()
	add_child(_world)
	await get_tree().physics_frame
	await get_tree().physics_frame

	_check_zones()
	_check_spawns()
	_check_walkable()
	_check_cave_locked()
	_check_props_solid()

	print("TEST ===== %s (%d failures) =====" % ["ALL PASS" if _fail == 0 else "FAILED", _fail])
	get_tree().quit(_fail)


func _check(label: String, got: Variant, want: Variant) -> void:
	var ok: bool = got == want
	if not ok:
		_fail += 1
	print("TEST %s %-44s got=%s want=%s" % ["OK  " if ok else "FAIL", label, got, want])


func _zone(zone_id: StringName) -> Zone:
	for child: Node in _world.get_node("Zones").get_children():
		if child is Zone and (child as Zone).zone_id == zone_id:
			return child
	return null


func _check_zones() -> void:
	print("TEST --- 五個區域都在 ---")
	_check("Zones 底下有五區", _world.get_node("Zones").get_child_count(), ZONES.size())
	for zone_id: StringName in ZONES:
		var zone := _zone(zone_id)
		if zone == null:
			_check("找得到 %s" % zone_id, false, true)
			continue
		_check("%s 的位置" % zone_id, zone.global_position, ZONES[zone_id])
		_check("%s 有名字" % zone_id, not zone.display_name.is_empty(), true)

	# 四區都要**貼著**草原，中間不留空隙也不鋪道路
	for zone_id: StringName in [&"water_school", &"fire_zone", &"mountain", &"village"]:
		var centre: Vector3 = ZONES[zone_id]
		var gap := maxf(absf(centre.x), absf(centre.z)) - ZONE_HALF - GRASS_HALF
		_check("%s 貼著草原" % zone_id, is_zero_approx(gap), true)
	_check("沒有道路節點", _world.get_node_or_null("Roads"), null)

	# 聚落是中立的，其餘四區各有屬性（規劃 §3）
	_check("聚落沒有屬性", _zone(&"village").has_element, false)
	_check("學校是水系", _zone(&"water_school").element, Element.Type.WATER)
	_check("火山是火系", _zone(&"fire_zone").element, Element.Type.FIRE)
	_check("山區是地系", _zone(&"mountain").element, Element.Type.GROUND)
	_check("草原是草系", _zone(&"grassland").element, Element.Type.GRASS)


func _check_spawns() -> void:
	print("TEST --- Spawn Point 都標好了（W4 才接上）---")
	for zone_id: StringName in SPAWNS:
		var zone := _zone(zone_id)
		for spawn_name: String in SPAWNS[zone_id]:
			_check("%s/%s" % [zone_id, spawn_name],
				zone.get_node_or_null("SpawnPoints/%s" % spawn_name) != null, true)


## 從草原中心往每一區走，沿路每 5 公尺確認腳下有地板。
func _check_walkable() -> void:
	print("TEST --- 從草原走得到每一區 ---")
	for zone_id: StringName in ZONES:
		if zone_id == &"grassland":
			continue
		var destination: Vector3 = ZONES[zone_id]
		var steps := int(destination.length() / 5.0)
		var holes: Array[String] = []
		for i in range(steps + 1):
			var point := destination * (float(i) / float(steps))
			if not _has_ground(point):
				holes.append("%.0f,%.0f" % [point.x, point.z])
		_check("走到 %s 沿路都有地板" % zone_id, holes, [] as Array[String])


## 洞窟入口在山區存在，但 W1 不做 Dungeon——「鎖住」就是走不進去的一面牆。
func _check_cave_locked() -> void:
	print("TEST --- 洞窟入口存在但沒開 ---")
	var mountain := _zone(&"mountain")
	var cave := mountain.get_node_or_null("Props/CaveEntrance")
	_check("山區有洞窟入口", cave is StaticBody3D, true)
	_check("洞窟擋得住（走不進去）", (cave as StaticBody3D).collision_layer, 1)
	var interactable := false
	for child: Node in cave.get_children():
		interactable = interactable or child is Area3D
	_check("洞窟還沒有互動（沒有 Area3D）", interactable, false)


## 道具要擋得住玩家（使用者要求）。抽查每一區最大的那個東西。
func _check_props_solid() -> void:
	print("TEST --- 大型道具擋得住 ---")
	var solids := {
		&"water_school": "Props/SchoolBuilding",
		&"fire_zone": "Props/Volcano",
		&"mountain": "Props/Peak1",
		&"village": "Props/HomeBody",
		&"grassland": "Props/Tree1Trunk",
	}
	for zone_id: StringName in solids:
		var prop := _zone(zone_id).get_node_or_null(solids[zone_id])
		_check("%s 是實心的" % solids[zone_id], prop is StaticBody3D, true)


func _has_ground(at: Vector3) -> bool:
	var from := at + Vector3(0.0, 5.0, 0.0)
	var to := at + Vector3(0.0, -2.0, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = WORLD_MASK
	return not _world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
