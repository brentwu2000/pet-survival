## Test World。
##
## 規格書 §26 Phase 1：「玩家帶 Starter 出門 → 找到 Wild Pet → 指定攻擊」。
extends Node3D

const PET_SCENE: PackedScene = preload("res://scenes/pets/pet.tscn")
const CAPTURE_FX_SCENE: PackedScene = preload("res://scenes/fx/capture_effect.tscn")
const SUMMON_FX_SCENE: PackedScene = preload("res://scenes/fx/summon_effect.tscn")

## Collision layer（見 01-project-conventions.md，早期定案、後期勿改）
## 3 PetFriendly / 4 Enemy / 9 Selectable
const LAYER_PET_FRIENDLY := 1 << 2
const LAYER_ENEMY := 1 << 3
const LAYER_SELECTABLE := 1 << 8

## 開局固定給 Starter Pet（硬規則 2）。
@export var starter_id: StringName = &"eggshell_dragon"
## 開局給的捕捉球。Phase 1 先直接發，之後改由存檔 / 商店決定。
@export var starting_ball_id: StringName = &"ball_basic"
@export var starting_ball_count: int = 10
## 野生寵物住在哪一區（W4：Spawn Point）。
##
## **潛水蛇(Water) 是第一隻可捕捉的對象**——蛋殼龍是 Grass，克 Water，打得贏；
## 火焰喵(Fire) 克 Grass，是後期才該碰的硬對手。
## 兩隻分別住在牠們的屬性對應的區域（規劃 §5.2 / §5.3），
## 所以「走錯邊會打不贏」這件事在地圖上就成立了。
## 種族與出生點由 world.tscn 配置，新增怪獸不用修改生成邏輯。
@export var wild_spawns: Dictionary[StringName, NodePath] = {}

@onready var _player: Player = $Player
@onready var _pets_root: Node3D = $Pets
@onready var _hud: Hud = $Hud

## 開局出場的那個節點。換寵之後它會被移除，要拿「現在出戰的」請用 `_player.active_pet`。
var starter: Pet = null

## 出戰寵物倒下後，屍體留多久再收掉。
const FAINTED_FADE_SECONDS := 1.2
## 沒有舊寵物可以接位置時（開局），新寵物出現在玩家旁邊的這個偏移。
const SUMMON_OFFSET := Vector3(1.5, 0.0, 1.5)
## 球從玩家身上的這個高度丟出去、也收回到這裡。捕捉與換寵共用同一隻手。
const HAND_OFFSET := Vector3(0.0, 1.1, 0.0)


func _ready() -> void:
	Game.register_world(self, _player)
	Game.capture.capture_attempted.connect(_on_capture_attempted)
	# 場上節點一律跟著 PartyManager 走：開局、按 1~5、出戰寵物倒下，全部走同一條路
	EventBus.active_pet_changed.connect(_on_active_pet_changed)

	# HUD 自己不去撈玩家是誰——子節點的 _ready 比 World 早，那時還沒人登記。
	# 要在發球與 acquire_pet 之前接好，開局的球數與 Starter 才會顯示。
	_hud.bind_player(_player)

	Game.inventory.add(starting_ball_id, starting_ball_count)

	# Starter 走正式流程：建立 PetInstance -> 進收藏 -> 進 Party -> 出戰
	# 進 Party 時自動出戰會發 active_pet_changed，節點由 _on_active_pet_changed 生出來
	Game.acquire_pet(starter_id)
	starter = _player.active_pet
	for species_id: StringName in wild_spawns:
		var marker := get_node_or_null(wild_spawns[species_id]) as Node3D
		if marker == null:
			push_error("World: 找不到 %s 的 Spawn Point" % species_id)
			continue
		_spawn_pet(species_id, marker.global_position, PetAI.Behaviour.WILD)

	print("[World] ready — renderer=%s" % RenderingServer.get_video_adapter_name())


## 換寵（規劃書 §14 step 14）：舊的收回、新的在原地出場、接手舊寵物的目標繼續打。
##
## 只看 `Game.party.active`，不信任 slot 參數——
## 別的 PartyManager（例如測試裡另建的）也會發同一個 EventBus 訊號。
func _on_active_pet_changed(_slot: int) -> void:
	var instance := Game.party.active
	var old := _player.active_pet
	if instance == null or (is_instance_valid(old) and old.instance == instance):
		return

	var spawn_at := _player.global_position + SUMMON_OFFSET
	var carry_target: Node3D = null
	if is_instance_valid(old):
		spawn_at = old.global_position
		if old.targeting.has_valid_target():
			carry_target = old.targeting.current_target

	var pet := _spawn_pet(instance.species_id, spawn_at, PetAI.Behaviour.FOLLOWER)
	if pet == null:
		return
	pet.bind_instance(instance)
	# 球先飛過去，落地開球的那一刻寵物才彈出來
	_spawn_switch_fx(SummonEffect.Mode.SUMMON, spawn_at, instance.species_id)
	pet.play_summon(SummonEffect.FLY_SECONDS)
	# 倒下要等這一幀的傷害結算完再換，不要在 take_damage 的 call stack 裡生節點
	pet.health.died.connect(Game.party.on_active_fainted, CONNECT_DEFERRED | CONNECT_ONE_SHOT)

	_player.active_pet = pet
	if carry_target != null:
		pet.ai.issue_command(PetCommand.Type.ATTACK_TARGET, carry_target)

	if is_instance_valid(old):
		_recall(old)


## 收回場上的舊寵物。HP 早就同步回 instance 了，節點直接丟掉即可。
func _recall(pet: Pet) -> void:
	pet.unbind_instance()
	if not pet.health.is_dead:
		# 球留在玩家手上，寵物被吸過去縮進球裡。演完各自 queue_free()
		var hand := _player.global_position + HAND_OFFSET
		var fx := _spawn_switch_fx(SummonEffect.Mode.RECALL, hand, pet.data.id)
		# 光束要每幀追著牠——牠一邊縮小一邊往球飛
		fx.target = pet
		pet.play_recall_and_free(hand)
		return
	# 倒下的留一下讓玩家看到「牠倒了」
	var tween := pet.create_tween()
	tween.tween_property(pet.visual.sprite, "modulate:a", 0.0, FAINTED_FADE_SECONDS)
	tween.tween_callback(pet.queue_free)


## 特效是表現層：判定早就算完了，這裡只負責演。
func _on_capture_attempted(target: Pet, ball: BallData, success: bool, rate: float) -> void:
	if not is_instance_valid(target):
		return
	var effect: CaptureEffect = CAPTURE_FX_SCENE.instantiate()
	effect.ball_id = ball.id
	effect.success = success
	# 搖幾下由判定結果決定；失敗時越接近成功搖越多，玩家會覺得「就差一點」
	effect.shakes = CaptureSystem.shake_count(success, rate)
	# 球從玩家胸口畫一條拋物線飛過來
	effect.throw_from = _player.global_position + HAND_OFFSET
	effect.has_throw_origin = true

	add_child(effect)
	# global_position 要進樹之後才能設，所以演出得等設完位置再啟動
	effect.global_position = target.global_position
	effect.start()


## 換寵的球。`species_id` 只是給節點取名字，方便在除錯樹上分辨。
func _spawn_switch_fx(mode: SummonEffect.Mode, at: Vector3,
		species_id: StringName) -> SummonEffect:
	var effect: SummonEffect = SUMMON_FX_SCENE.instantiate()
	effect.name = "%sFx_%s" % [
		"Summon" if mode == SummonEffect.Mode.SUMMON else "Recall", species_id]
	effect.mode = mode
	effect.hand_position = _player.global_position + HAND_OFFSET

	add_child(effect)
	# global_position 要進樹之後才能設，所以演出得等設完位置再啟動
	effect.global_position = at
	effect.start()
	return effect


func _spawn_pet(species_id: StringName, spawn_position: Vector3,
		behaviour: PetAI.Behaviour) -> Pet:
	var data: PetData = Database.get_pet(species_id)
	if data == null:
		return null

	var pet: Pet = PET_SCENE.instantiate()
	pet.name = String(species_id)
	pet.setup(data)

	if behaviour == PetAI.Behaviour.WILD:
		pet.collision_layer = LAYER_ENEMY | LAYER_SELECTABLE
	else:
		pet.collision_layer = LAYER_PET_FRIENDLY | LAYER_SELECTABLE

	_pets_root.add_child(pet)
	pet.global_position = spawn_position

	# follow_anchor 要在 add_child 之後設——@onready 這時才就緒。
	pet.ai.behaviour = behaviour
	if behaviour == PetAI.Behaviour.WILD:
		# 野生寵物駐守 spawn 點
		var marker := Marker3D.new()
		add_child(marker)
		marker.global_position = spawn_position
		pet.ai.follow_anchor = marker
	else:
		pet.ai.follow_anchor = _player

	return pet
