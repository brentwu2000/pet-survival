## 寵物 FSM（規格書 §9）。
##
## 規格書明確要求：**第一版不要做 Behaviour Tree。**
## 單一 script + match，不為八個狀態各開一個 Node class——那是 Phase 1 不需要的抽象。
##
## **這裡不得出現任何 sprite.play()。** FSM 只 emit state_changed，
## 由 PetVisual 監聽後自己決定播什麼（規格書 §9：AI 與 Animation 分離）。
class_name PetAI
extends Node

signal state_changed(from: State, to: State)
## 指令無法執行時發出（目標已死、目標不存在）。UI 可以用它給玩家回饋。
signal command_rejected(reason: StringName)

enum State { IDLE, FOLLOW, CHASE, ATTACK, CAST_SKILL, RETURN, DEFEND, DEAD }

## 玩家寵物跟著玩家跑；野生寵物駐守 spawn 點、被打才反擊。
## 狀態機完全共用，差別只有初始 command 與 anchor——不值得為此開一個子類別。
enum Behaviour { FOLLOWER, WILD }

@export var behaviour: Behaviour = Behaviour.FOLLOWER
@export var follow_distance: float = 3.0
@export var leash_distance: float = 20.0
@export var move_speed: float = 4.0
## 野生寵物的主動索敵範圍。FOLLOWER 不用。
@export var aggro_radius: float = 8.0

var state: State = State.IDLE
var command: PetCommand.Type = PetCommand.Type.FOLLOW
## 探索時是玩家，駐守 / 野生時是駐守點。
var follow_anchor: Node3D = null

var _previous_command: PetCommand.Type = PetCommand.Type.FOLLOW

@onready var _body: CharacterBody3D = get_parent()
@onready var _nav: NavigationAgent3D = _body.get_node("NavigationAgent3D")
@onready var _health: HealthComponent = _body.get_node("HealthComponent")
@onready var _combat: CombatComponent = _body.get_node("CombatComponent")
@onready var _skills: SkillComponent = _body.get_node("SkillComponent")
@onready var _targeting: TargetComponent = _body.get_node("TargetComponent")


func _ready() -> void:
	_health.died.connect(_on_died)
	_health.damaged.connect(_on_damaged)
	_targeting.target_lost.connect(_on_target_lost)

	if behaviour == Behaviour.WILD:
		command = PetCommand.Type.DEFEND
		_change_state(State.IDLE)
	else:
		_change_state(State.FOLLOW)


func _physics_process(delta: float) -> void:
	match state:
		State.IDLE: _tick_idle()
		State.FOLLOW: _tick_follow()
		State.CHASE: _tick_chase()
		State.ATTACK: _tick_attack()
		State.CAST_SKILL: _tick_cast()
		State.RETURN: _tick_return()
		State.DEFEND: _tick_defend()
		State.DEAD: pass

	if state == State.DEAD:
		return
	# Y 軸只由重力與 move_and_slide 決定，Navigation 不碰。
	if not _body.is_on_floor():
		_body.velocity += _body.get_gravity() * delta
	_body.move_and_slide()


func issue_command(cmd: PetCommand.Type, target: Node3D = null) -> void:
	_previous_command = command
	command = cmd
	match cmd:
		PetCommand.Type.ATTACK_TARGET:
			# 目標已死 / 不存在就直接拒絕。
			# 否則會進 CHASE 一個 frame 再被 _tick_chase 踢回來，
			# 表現出來是「點了完全沒反應」，最難查。
			if not _is_attackable(target):
				command = _previous_command
				command_rejected.emit(&"invalid_target")
				return
			_targeting.set_target(target)
			_change_state(State.CHASE)
		PetCommand.Type.FOLLOW:
			_targeting.clear_target()
			_change_state(State.FOLLOW)
		PetCommand.Type.STAY:
			_targeting.clear_target()
			_change_state(State.IDLE)
		PetCommand.Type.DEFEND:
			_change_state(State.DEFEND)
		PetCommand.Type.RETREAT:
			_targeting.clear_target()
			_change_state(State.RETURN)


func _is_attackable(target: Node3D) -> bool:
	if not is_instance_valid(target) or target == _body:
		return false
	var hp := target.get_node_or_null("HealthComponent") as HealthComponent
	return hp != null and not hp.is_dead


func _change_state(next: State) -> void:
	if state == next:
		return
	var prev := state
	state = next
	state_changed.emit(prev, next)


# --- 各狀態 ---------------------------------------------------------------

func _tick_idle() -> void:
	_stop()
	if behaviour == Behaviour.WILD:
		# 野生寵物主動索敵：有敵人靠近就打
		if _targeting.has_valid_target():
			_change_state(State.CHASE)
		return
	if command == PetCommand.Type.FOLLOW and _too_far_from_anchor(follow_distance):
		_change_state(State.FOLLOW)


func _tick_follow() -> void:
	if _targeting.has_valid_target():
		_change_state(State.CHASE)
		return
	if not _too_far_from_anchor(follow_distance):
		_change_state(State.IDLE)
		return
	_move_towards(follow_anchor.global_position)


func _tick_chase() -> void:
	if not _targeting.has_valid_target():
		_targeting.clear_target()
		_change_state(_default_state())
		return
	if _too_far_from_anchor(leash_distance):
		_change_state(State.RETURN)
		return
	var target := _targeting.current_target
	if _combat.in_range(target):
		_change_state(State.ATTACK)
		return
	_move_towards(target.global_position)


func _tick_attack() -> void:
	_stop()
	if not _targeting.has_valid_target():
		_targeting.clear_target()
		_change_state(_default_state())
		return
	var target := _targeting.current_target
	if not _combat.in_range(target):
		_change_state(State.CHASE)
		return
	_face(target.global_position)
	# 技能優先於普攻；CAST_SKILL 期間不可被普攻打斷。
	if _skills.can_cast(target):
		_change_state(State.CAST_SKILL)
		_skills.cast(target)
		return
	_combat.try_attack(target)


func _tick_cast() -> void:
	_stop()
	if not _skills.is_casting:
		_change_state(State.ATTACK)


func _tick_return() -> void:
	if not _too_far_from_anchor(follow_distance):
		_change_state(_default_state())
		return
	_move_towards(follow_anchor.global_position)


func _tick_defend() -> void:
	if not _targeting.has_valid_target():
		_stop()
		return
	var target := _targeting.current_target
	if _combat.in_range(target):
		_tick_attack()
	else:
		_move_towards(target.global_position)


func _default_state() -> State:
	return State.IDLE if behaviour == Behaviour.WILD else State.FOLLOW


# --- 移動 -----------------------------------------------------------------

func _move_towards(destination: Vector3) -> void:
	if follow_anchor == null and destination == Vector3.ZERO:
		_stop()
		return
	_nav.target_position = destination
	# get_next_path_position() 依官方文件必須每個 physics frame 呼叫一次。
	var next := _nav.get_next_path_position()
	if _nav.is_navigation_finished():
		_stop()
		return
	var dir := (next - _body.global_position)
	dir.y = 0.0
	dir = dir.normalized()
	_body.velocity.x = dir.x * move_speed
	_body.velocity.z = dir.z * move_speed
	_face_direction(dir)


func _stop() -> void:
	_body.velocity.x = 0.0
	_body.velocity.z = 0.0


func _face(target_position: Vector3) -> void:
	var to_target := target_position - _body.global_position
	to_target.y = 0.0
	_face_direction(to_target)


## 朝向會被 PetVisual 讀去算「相對鏡頭的方向」，所以要確實更新。
func _face_direction(dir: Vector3) -> void:
	if dir.length_squared() < 0.0001:
		return
	_body.rotation.y = atan2(dir.x, dir.z)


func _too_far_from_anchor(d: float) -> bool:
	if follow_anchor == null:
		return false
	return _body.global_position.distance_squared_to(follow_anchor.global_position) > d * d


# --- 事件 -----------------------------------------------------------------

func _on_died() -> void:
	_stop()
	_change_state(State.DEAD)


## 被打就反擊（野生寵物的主要接敵方式）。
func _on_damaged(_amount: float, source: Node) -> void:
	if state == State.DEAD:
		return
	if source is Node3D and not _targeting.has_valid_target():
		_targeting.set_target(source as Node3D)


func _on_target_lost() -> void:
	if state == State.CHASE or state == State.ATTACK:
		_change_state(_default_state())
