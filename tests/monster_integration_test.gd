## Exercise real world spawning, navigability and camera-relative idle fallbacks.
extends Node3D

const NEW_PETS: Array[StringName] = [
	&"container_beast", &"earth_armor_dragon", &"storm_bat",
	&"mech_kid", &"island_tentacle",
]
const EXPECTED: PackedStringArray = [
	"idle_s", "idle_sw", "idle_w", "idle_nw",
	"idle_n", "idle_ne", "idle_e", "idle_se",
]
var _fail: int = 0


func _ready() -> void:
	var world: Node3D = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var map := get_world_3d().navigation_map
	var deadline := Time.get_ticks_msec() + 5000
	while NavigationServer3D.map_get_path(map, Vector3.ZERO, Vector3(10, 0, 0), true).is_empty():
		if Time.get_ticks_msec() > deadline:
			_check("navigation ready", false)
			break
		await get_tree().physics_frame
	var pets: Dictionary[StringName, Pet] = {}
	for child: Node in world.get_node("Pets").get_children():
		if child is Pet:
			var pet := child as Pet
			pets[pet.data.id] = pet
			pet.ai.set_physics_process(false)
	_check("starter and seven wild pets", pets.size() == 8)
	world.get_node("OrbitCamera").set_process(false)
	world.get_node("OrbitCamera").set_physics_process(false)
	var rig := Node3D.new()
	add_child(rig)
	var camera := Camera3D.new()
	rig.add_child(camera)
	camera.position = Vector3(0, 2, 8)
	camera.current = true
	for id: StringName in NEW_PETS:
		_check("%s spawned" % id, pets.has(id))
		if not pets.has(id):
			continue
		var pet: Pet = pets[id]
		_check("%s wild and selectable" % id,
			pet.ai.behaviour == PetAI.Behaviour.WILD and pet.get_collision_layer_value(9))
		_check("%s visual bound" % id, pet.visual.sprite.sprite_frames == pet.data.sprite_frames)
		var goal: Vector3 = world.get_node(world.wild_spawns[id]).global_position
		var path := NavigationServer3D.map_get_path(map, Vector3.ZERO, goal, true)
		_check("%s reachable spawn" % id, not path.is_empty() and path[-1].distance_to(goal) < 1.0)
		pet.rotation.y = 0.0
		for action: StringName in [&"idle", &"walk", &"attack", &"skill", &"death"]:
			pet.visual.set_animation(action)
			var actual: PackedStringArray = []
			for step in 8:
				rig.rotation.y = deg_to_rad(step * 45.0)
				await get_tree().process_frame
				await get_tree().process_frame
				actual.append(String(pet.visual.sprite.animation))
			_check("%s %s direction/fallback" % [id, action], actual == EXPECTED)
		_check("%s playing" % id, pet.visual.sprite.is_playing())
	print("TEST ===== %s (%d failures) =====" % ["ALL PASS" if _fail == 0 else "FAILED", _fail])
	get_tree().quit(_fail)


func _check(label: String, passed: bool) -> void:
	if not passed:
		_fail += 1
	print("TEST %s %s" % ["OK" if passed else "FAIL", label])
