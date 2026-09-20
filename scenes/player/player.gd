## 玩家角色（規格書 §4、§24）。
##
## 硬規則 1：**玩家不直接攻擊**——這個 script 永遠不會有普攻 / 武器 / 裝備。
## 玩家的戰鬥行為是「指揮寵物」，會在 Phase 1 以選取 + 下令的形式加入。
class_name Player
extends CharacterBody3D

## HUD 用：場上出戰的**節點**換人了。
## 「誰出戰」是 PartyManager 的狀態，這個訊號講的是「場上這個節點」。
signal active_pet_node_changed(pet: Pet)
## HUD 用：切換失敗的理由（`empty_slot` / `fainted`）。
## 這裡只給理由代號，翻成人話是 HUD 的事。
signal switch_rejected(slot: int, reason: StringName)

@export var move_speed: float = 5.0
@export var rotation_speed: float = 12.0
## 移動方向相對鏡頭，不是相對玩家自身朝向。
@export var camera_rig: Node3D
## 超過這個速度就播 walk。用 squared 省一次開根號。
@export var walk_speed_threshold: float = 0.3

@onready var visual: PlayerVisual = $Visual

## 目前出戰的寵物節點。誰出戰由 PartyManager 決定，World 聽 active_pet_changed 換節點後指派過來。
var active_pet: Pet = null:
	set(value):
		if active_pet == value:
			return
		if is_instance_valid(active_pet):
			active_pet.selection.show_as(SelectionIndicator.Kind.NONE)
			active_pet.targeting.target_lost.disconnect(_on_target_lost)
		active_pet = value
		if is_instance_valid(active_pet):
			active_pet.selection.show_as(SelectionIndicator.Kind.ACTIVE)
			active_pet.targeting.target_lost.connect(_on_target_lost)
		active_pet_node_changed.emit(active_pet)

var _marked_target: Pet = null

## 可點選物件在 layer 9 Selectable。mask 是位元：layer N -> 1 << (N - 1)。
const SELECT_MASK := 1 << 8
const PICK_DISTANCE := 1000.0

## Phase 1 只用普通球。之後由 HUD 讓玩家選。
@export var ball_id: StringName = &"ball_basic"


func _ready() -> void:
	# 拒絕丟球 / 拒絕指令的提示由 HUD 顯示，Player 只管「成功抓到就清掉紅圈」
	Game.capture.capture_attempted.connect(_on_capture_attempted)


## 數字鍵 1~5 對應 Party 五格（硬規則 3：上限 5、同時出戰 1）。
const SLOT_ACTIONS: Array[StringName] = [
	&"pet_slot_1", &"pet_slot_2", &"pet_slot_3", &"pet_slot_4", &"pet_slot_5"]


## 硬規則 1：玩家沒有普攻。左鍵不是攻擊，是**指定目標讓寵物去打**。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("throw_ball"):
		_throw_ball()
		get_viewport().set_input_as_handled()
		return
	for slot in SLOT_ACTIONS.size():
		if event.is_action_pressed(SLOT_ACTIONS[slot]):
			switch_to_slot(slot)
			get_viewport().set_input_as_handled()
			return
	if not event.is_action_pressed("select"):
		return
	if active_pet == null or active_pet.health.is_dead:
		return

	var picked := _pick_under_mouse()
	if picked == null:
		# 點空地 = 取消指令，回到跟隨
		_mark_target(null)
		active_pet.ai.issue_command(PetCommand.Type.FOLLOW)
		return
	if picked == active_pet:
		return

	active_pet.ai.issue_command(PetCommand.Type.ATTACK_TARGET, picked)
	# issue_command 會擋掉已死目標，所以用實際結果決定要不要標記
	_mark_target(active_pet.targeting.current_target as Pet)


## 只改 PartyManager 的狀態；場上節點的替換是 World 聽 EventBus 做的。
func switch_to_slot(slot: int) -> bool:
	if slot == Game.party.active_index:
		return false
	var instance := Game.party.at(slot)
	if not Game.party.set_active(slot):
		switch_rejected.emit(slot, &"empty_slot" if instance == null else &"fainted")
		return false
	return true


## 丟球的對象就是「寵物正在打的那隻」——所以一定得先下過攻擊指令，
## 這也順帶讓硬規則 1「必須先靠寵物戰鬥削弱目標」在操作上成立。
func _throw_ball() -> void:
	if active_pet == null:
		return
	var ball: BallData = Database.get_item(ball_id)
	var target := active_pet.targeting.current_target as Pet
	Game.capture.attempt_capture(target, ball)


## 抓到了就把紅圈清掉——顯示成功 / 失敗是 HUD 的事。
func _on_capture_attempted(_target: Pet, _ball: BallData, success: bool, _rate: float) -> void:
	if success:
		_mark_target(null)


## 指定目標的紅圈。沒有它的話，點成功和點失敗在畫面上長得一模一樣。
func _mark_target(target: Pet) -> void:
	if _marked_target == target:
		return
	if is_instance_valid(_marked_target):
		_marked_target.selection.show_as(SelectionIndicator.Kind.NONE)
	_marked_target = target
	if is_instance_valid(_marked_target):
		_marked_target.selection.show_as(SelectionIndicator.Kind.TARGET)


func _on_target_lost() -> void:
	_mark_target(null)


func _pick_under_mouse() -> Node3D:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var mouse := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var to := from + camera.project_ray_normal(mouse) * PICK_DISTANCE

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = SELECT_MASK
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	# intersect_ray 沒打中會回傳空 Dictionary，要先 is_empty() 再取 collider。
	if hit.is_empty():
		return null
	return hit.get("collider") as Node3D


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	var direction := _input_direction()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	move_and_slide()

	if direction.length_squared() > 0.01:
		_face_direction(direction, delta)

	_update_animation()


## 站著 idle、動了 walk。第一版只有這兩個動作——
## 主角沒有攻擊動作，因為玩家不直接攻擊（硬規則 1）。
func _update_animation() -> void:
	var planar := Vector2(velocity.x, velocity.z)
	visual.set_animation(
		&"walk" if planar.length_squared() > walk_speed_threshold * walk_speed_threshold
		else &"idle")


func _input_direction() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if camera_rig == null:
		return Vector3(input.x, 0.0, input.y)

	# 取鏡頭的水平朝向，忽略俯仰。
	var rig_basis := camera_rig.global_basis
	var forward := -Vector3(rig_basis.z.x, 0.0, rig_basis.z.z).normalized()
	var right := Vector3(rig_basis.x.x, 0.0, rig_basis.x.z).normalized()
	# move_forward 在 get_vector 中是負 y，所以乘 -input.y。寫反的症狀是前後顛倒。
	return (right * input.x + forward * -input.y).normalized()


func _face_direction(direction: Vector3, delta: float) -> void:
	var target_yaw := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, rotation_speed * delta)
