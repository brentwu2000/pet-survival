## 所有寵物共用的 Scene（規格書 §22）。
##
## **不要替蛋殼龍、火焰喵、潛水蛇各寫一套戰鬥程式。**
## 同一個 pet.tscn + 不同的 PetData 產生全部差異——
## 新增一隻寵物如果需要動到任何 .gd，就是設計錯了。
##
## 這個 script 是 Orchestrator：只做組裝與轉接，不放戰鬥或 AI 邏輯。
class_name Pet
extends CharacterBody3D

@onready var health: HealthComponent = $HealthComponent
@onready var combat: CombatComponent = $CombatComponent
@onready var skills: SkillComponent = $SkillComponent
@onready var targeting: TargetComponent = $TargetComponent
@onready var ai: PetAI = $PetAI
@onready var visual: PetVisual = $Visual
@onready var selection: SelectionIndicator = $SelectionIndicator
@onready var health_bar: PetHealthBar = $HealthBar
@onready var agent: NavigationAgent3D = $NavigationAgent3D

var data: PetData = null
## 這個節點對應到的執行期寵物。野生寵物在被捕捉前是 null。
## 用 bind_instance() 綁定，不要直接賦值——HP 同步是在那裡接上的。
var instance: PetInstance = null
var move_speed: float = 4.0

var _pending_data: PetData = null
## 被吸進球裡時暫存的碰撞層，失敗彈出來要還原。
var _captured_layer: int = 0
var _captured_mask: int = 0


## 屍體淡出的時間。留一下下讓玩家看得到「牠倒了」，但不要一直躺在地上擋路。
const CORPSE_FADE_SECONDS := 1.2
## 捕捉失敗後彈回來的時間。
const ESCAPE_SECONDS := 0.25
## 換寵：被叫出來 / 被收回的時間。
## 比捕捉的演出短——換寵在戰鬥中會一直發生，拖太久會卡手感。
const SUMMON_SECONDS := 0.28
## 收回要走一段距離（被吸到玩家手上），比單純縮小需要多一點時間。
const RECALL_SECONDS := 0.26


func _ready() -> void:
	health.died.connect(_on_died)
	health_bar.setup(health)
	if _pending_data != null:
		_apply(_pending_data)
		_pending_data = null


## Component 的 @export 是編輯器預設值；執行期一律由 Data 注入。
## 可以在 add_child 之前呼叫——資料會先存起來，等 _ready 再套用。
func setup(pet_data: PetData) -> void:
	if not is_node_ready():
		_pending_data = pet_data
		return
	_apply(pet_data)


func _apply(pet_data: PetData) -> void:
	if pet_data == null:
		push_error("Pet.setup: pet_data is null")
		return

	data = pet_data
	move_speed = pet_data.move_speed

	health.setup(pet_data.max_hp)

	combat.defense = pet_data.defense
	# 防禦側 = 種族屬性
	combat.element = pet_data.element
	# 攻擊側 = 普攻的威力 / 射程 / 冷卻 / 屬性
	if pet_data.basic_attack != null:
		combat.attack_power = pet_data.basic_attack.power
		combat.attack_element = pet_data.basic_attack.element
		combat.attack_range = pet_data.basic_attack.cast_range
		combat.attack_cooldown = pet_data.basic_attack.cooldown
	else:
		push_error("Pet.setup: %s 沒有 basic_attack" % pet_data.id)

	skills.skill = pet_data.special_skill

	ai.move_speed = pet_data.move_speed

	visual.setup(pet_data)


## 場上節點與 PetInstance 的 HP 同步。
##
## 節點只是 instance 在場上的「分身」：出場時從 instance 讀 HP，
## 之後每次 HP 變動都寫回去。不接的話換寵會變成免費補血。
## 必須在 setup() 套用完 PetData 之後呼叫（也就是 add_child 之後）。
func bind_instance(pet_instance: PetInstance) -> void:
	instance = pet_instance
	if instance == null:
		return
	health.setup(data.max_hp, instance.current_hp)
	health.health_changed.connect(_on_health_changed_sync)


## 收回前呼叫：之後這個節點再怎麼掉血都不會寫回 instance。
func unbind_instance() -> void:
	if health.health_changed.is_connected(_on_health_changed_sync):
		health.health_changed.disconnect(_on_health_changed_sync)
	instance = null


func _on_health_changed_sync(current: float, _maximum: float) -> void:
	if instance != null:
		instance.current_hp = current


## 被捕捉的演出。**成功與失敗都會被吸進球裡**——
## 失敗時怪獸從球裡跑出來，這段「跑出來」就是失敗最重要的回饋。
##
## 節奏常數在 CaptureSystem，球的動畫讀同一組，兩邊才會同步。
func play_capture_sequence(success: bool, shakes: int) -> void:
	_captured_layer = collision_layer
	_captured_mask = collision_mask
	collision_layer = 0
	collision_mask = 0
	# 被吸進去的期間不該再被打到
	health.invulnerable = true
	selection.show_as(SelectionIndicator.Kind.NONE)
	health_bar.visible = false
	set_physics_process(false)
	ai.set_physics_process(false)

	# 等球飛到身上才開始被吸進去，不然會在球還在半空時就消失
	await get_tree().create_timer(CaptureSystem.THROW_SECONDS).timeout
	if not is_inside_tree():
		return

	var absorb := create_tween()
	absorb.set_parallel(true)
	absorb.tween_property(visual, "scale", Vector3.ZERO,
		CaptureSystem.ABSORB_SECONDS).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	absorb.tween_property(visual.sprite, "modulate:a", 0.0, CaptureSystem.ABSORB_SECONDS)

	await get_tree().create_timer(
		CaptureSystem.sequence_seconds(shakes) - CaptureSystem.THROW_SECONDS).timeout
	if not is_inside_tree():
		return

	if success:
		queue_free()
		return
	_escape_from_ball()


## 捕捉失敗：怪獸彈回來繼續戰鬥（硬規則 4）。
func _escape_from_ball() -> void:
	collision_layer = _captured_layer
	collision_mask = _captured_mask
	health.invulnerable = false
	set_physics_process(true)
	ai.set_physics_process(true)
	health_bar.visible = health.health_ratio < 1.0

	var target_scale := _visual_scale()
	var escape := create_tween()
	escape.set_parallel(true)
	escape.tween_property(visual.sprite, "modulate:a", 1.0, ESCAPE_SECONDS)
	# 彈出來用 BACK，尾巴會過衝一點點，比線性放大有力
	escape.tween_property(visual, "scale", target_scale,
		ESCAPE_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


## 換寵被叫出來：從一個點彈出來。
##
## **純表現**——不停 AI、不關碰撞。換寵的戰鬥時序（接手目標、立刻繼續打）
## 由 switch_test 守著，不要為了演出去動它。
##
## 縮放與淡入用的是和「捕捉失敗彈出球」同一套 TRANS_BACK，
## 兩邊看起來才像同一個世界的規則：寵物進出都是縮放。
##
## `delay` 是等球飛到身上的時間（`SummonEffect.FLY_SECONDS`）。
## 這段期間寵物已經存在、AI 也在跑，只是看不見——
## 不用它擋 gameplay，是為了不動換寵的戰鬥時序（接手目標、立刻繼續打）。
func play_summon(delay: float = 0.0) -> void:
	visual.scale = Vector3.ZERO
	visual.sprite.modulate.a = 0.0

	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
		if not is_inside_tree():
			return

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "scale", _visual_scale(),
		SUMMON_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# 淡入比縮放早結束，才不會整段都是半透明的
	tween.tween_property(visual.sprite, "modulate:a", 1.0, SUMMON_SECONDS * 0.6)


## 換寵被收回：**被吸向 `toward`（玩家手上的球）**，一邊縮小一邊過去，然後自己移除。
##
## 呼叫前必須先 `unbind_instance()`，否則演出期間的 HP 變動還會寫回 instance。
## 收回的當下就停掉 AI 與碰撞——縮小中的寵物不該還能打人或被打，
## 也因為關掉了 `_physics_process`，才可以直接 tween `global_position`。
func play_recall_and_free(toward: Vector3) -> void:
	selection.show_as(SelectionIndicator.Kind.NONE)
	health_bar.visible = false
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	ai.set_physics_process(false)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "scale", Vector3.ZERO,
		RECALL_SECONDS).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_property(visual.sprite, "modulate:a", 0.0, RECALL_SECONDS)
	# 被吸過去：越接近球越快（EASE_IN）
	tween.tween_property(self, "global_position", toward,
		RECALL_SECONDS).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)


func _visual_scale() -> Vector3:
	return Vector3.ONE * (data.visual_scale if data != null else 1.0)


## 死掉的寵物必須立刻停止可被點選。
## 否則屍體會一直留在 Selectable 層上，玩家點它會「完全沒反應」——
## 因為 PetAI 收到已死目標會直接拒絕指令，但畫面上看不出差別。
func _on_died() -> void:
	collision_layer = 0
	collision_mask = 0
	selection.show_as(SelectionIndicator.Kind.NONE)

	# 玩家的寵物由 World 收掉：PartyManager 換上下一隻時，World 會把這具淡出移除
	# （規格書 §5：玩家必須始終有可出戰寵物）。野生寵物直接淡出移除。
	if ai.behaviour != PetAI.Behaviour.WILD:
		return
	var tween := create_tween()
	tween.tween_property(visual.sprite, "modulate:a", 0.0, CORPSE_FADE_SECONDS)
	tween.tween_callback(queue_free)
