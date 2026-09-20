## 把 world.tscn 的 NavigationMesh 烤出來存成檔案（Milestone W2）。
##
##   godot --headless --path <專案> res://tools/bake_navmesh.tscn
##
## **為什麼要離線烤、存成 .res：**
## 執行期烤一次要花時間，Web 上那就是載入畫面多卡一下；而地圖是灰盒、不會動態改變，
## 烤好的結果直接進版控就好。改完地圖再跑一次這支。
##
## 來源幾何是 **StaticBody3D 的碰撞形狀**（不是 MeshInstance3D）——
## 玩家撞得到什麼，寵物就該繞過什麼，兩邊用同一份資料才不會不一致。
## Player 與 Pet 是 CharacterBody3D，不會被算進去。
extends Node

const OUTPUT_PATH := "res://resources/world/world_navmesh.res"

## 地圖是平的灰盒，這些值夠用。
##
## `AGENT_RADIUS` 是**寵物會不會卡牆角**的關鍵：它決定可走區域從牆面往內縮多少。
## 寵物的碰撞膠囊半徑只有 0.35，但路徑如果貼著牆角切，牠就會一路磨著牆走。
## 這裡刻意開到 0.9——這張地圖沒有窄門或走廊，路離牆遠一點只有好處。
const CELL_SIZE := 0.25
const AGENT_RADIUS := 0.9
const AGENT_HEIGHT := 1.6
const AGENT_MAX_CLIMB := 0.3
const AGENT_MAX_SLOPE := 45.0


func _ready() -> void:
	var world: Node3D = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().physics_frame

	var region: NavigationRegion3D = world.get_node("NavigationRegion3D")
	var navmesh := NavigationMesh.new()
	navmesh.cell_size = CELL_SIZE
	navmesh.agent_radius = AGENT_RADIUS
	navmesh.agent_height = AGENT_HEIGHT
	navmesh.agent_max_climb = AGENT_MAX_CLIMB
	navmesh.agent_max_slope = AGENT_MAX_SLOPE
	navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navmesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN

	# 明確指定從 World 開始掃，不要靠 NavigationRegion3D 自己猜 root——
	# 道具掛在 Zones 底下，不是 region 的子節點。
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(navmesh, source, world)
	if source.get_vertices().is_empty():
		push_error("[BakeNavmesh] 沒有掃到任何幾何，不會產生可走區域")
		get_tree().quit(1)
		return
	NavigationServer3D.bake_from_source_geometry_data(navmesh, source)

	var polygons := navmesh.get_polygon_count()
	print("[BakeNavmesh] 來源頂點 %d、烤出 %d 個多邊形"
		% [source.get_vertices().size() / 3, polygons])
	if polygons == 0:
		push_error("[BakeNavmesh] 烤不出多邊形")
		get_tree().quit(1)
		return

	region.navigation_mesh = navmesh
	var error := ResourceSaver.save(navmesh, OUTPUT_PATH)
	if error != OK:
		push_error("[BakeNavmesh] 存檔失敗：%d" % error)
		get_tree().quit(1)
		return

	print("[BakeNavmesh] 已存到 %s" % OUTPUT_PATH)
	get_tree().quit(0)
