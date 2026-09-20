## Basic HUD（規格書 §26 Phase 1 最後一項、§29「第一個 Playable」）。
##
## 只顯示四件事：
##
## 1. 球數——沒有它玩家不知道還能丟幾次
## 2. Party 五格——誰出戰、誰倒了、對應鍵盤 1~5
## 3. 目標 HP——捕捉時機的唯一依據（規格書 §10：HP 越低越好抓）
## 4. 提示訊息——取代原本散在 Player / Capture 的 `print`
##
## 完整的 Party UI（換位、詳細數值、拖曳）是 Phase 2，這裡不要先做。
##
## **HUD 只讀狀態、只聽 signal，不改任何 gameplay 狀態。**
## 沒有任何「按 HUD 就會怎樣」的互動——Phase 1 的操作全在鍵盤與滑鼠，
## 所以整棵樹都是 `MOUSE_FILTER_IGNORE`，左鍵才不會被 UI 吃掉。
class_name Hud
extends CanvasLayer

## 畫面邊距。
const MARGIN := 16.0
const TARGET_WIDTH := 260.0
const TARGET_HEIGHT := 46.0
const BOTTOM_WIDTH := 900.0
const BOTTOM_HEIGHT := 78.0
const SLOT_SEPARATION := 6.0
## 球數欄的寬度。左邊放一個同寬的空位，五個格子才會真的對準畫面正中間。
const BALL_WIDTH := 120.0

## 提示停留多久、淡出多久。
const NOTICE_SECONDS := 2.2
const NOTICE_FADE := 0.4

## 被拒絕的理由 → 給玩家看的話。
##
## 理由字串由 gameplay 端定義（`PetAI.command_rejected` / `CaptureSystem.capture_rejected`
## / `Player.switch_rejected`），**翻成人話是 UI 的事**——
## 所以中文只出現在這裡，不要散回那些 system 裡。
const REASON_TEXT := {
	&"invalid_target": "那個目標不能打",
	&"no_ball_data": "沒有這種球",
	&"no_target": "要先叫寵物去打一隻野生寵物",
	&"not_wild": "只能捕捉野生寵物",
	&"target_dead": "牠已經倒下了，不用抓",
	&"out_of_balls": "球用完了",
	&"empty_slot": "這格是空的",
	&"fainted": "牠已經倒下了",
}

var _player: Player = null
## 場上出戰的那個節點（不是 PetInstance）。換寵時整個換掉。
var _active_pet: Pet = null
var _target: Pet = null
var _ball_id: StringName = &"ball_basic"

var _slots: Array[PartySlot] = []
var _ball_label: Label = null
var _target_box: VBoxContainer = null
var _target_label: Label = null
var _target_bar: HudHpBar = null
var _notice_label: Label = null
var _notice_tween: Tween = null


func _ready() -> void:
	_build()

	Game.inventory.count_changed.connect(_on_inventory_changed)
	Game.party.party_changed.connect(_refresh_party)
	Game.capture.capture_attempted.connect(_on_capture_attempted)
	Game.capture.capture_rejected.connect(_on_capture_rejected)
	EventBus.active_pet_changed.connect(_on_active_slot_changed)

	_refresh_party()
	_refresh_balls()


## 由 World 在 `_ready()` 呼叫（Signal Up, Call Down）。
##
## HUD 不自己去 `Game.player` 撈——子節點的 `_ready()` 比 World 的早，
## 那時候還沒有人登記玩家。誰是玩家由持有者告訴 HUD。
func bind_player(player: Player) -> void:
	_player = player
	_ball_id = player.ball_id
	player.active_pet_node_changed.connect(_on_active_pet_node_changed)
	player.switch_rejected.connect(_on_switch_rejected)
	_on_active_pet_node_changed(player.active_pet)
	_refresh_balls()


# --- 給測試與 debug 用的讀取介面 -------------------------------------------

func ball_text() -> String:
	return _ball_label.text


func slot_text(index: int) -> String:
	return _slots[index].text() if index >= 0 and index < _slots.size() else ""


## 沒有目標時回傳空字串（面板是隱藏的）。
func target_text() -> String:
	return _target_label.text if _target_box.visible else ""


func target_ratio() -> float:
	return _target_bar.ratio()


func notice_text() -> String:
	return _notice_label.text


# --- 狀態更新 ---------------------------------------------------------------

func _refresh_party() -> void:
	var active := Game.party.active_index
	for i in _slots.size():
		_slots[i].show_instance(i, Game.party.at(i), i == active)


func _refresh_balls() -> void:
	var ball: BallData = Database.get_item(_ball_id)
	var label := ball.display_name if ball != null else String(_ball_id)
	_ball_label.text = "%s ×%d" % [label, Game.inventory.count(_ball_id)]


func _on_inventory_changed(item_id: StringName, _count: int) -> void:
	if item_id == _ball_id:
		_refresh_balls()


## 誰出戰換人了。節點的替換是 World 做的，這裡只重畫格子。
func _on_active_slot_changed(_slot: int) -> void:
	_refresh_party()


## 出戰的**節點**換人了：血量、目標、被拒絕的指令都要改聽新的那隻。
func _on_active_pet_node_changed(pet: Pet) -> void:
	if is_instance_valid(_active_pet):
		_active_pet.health.health_changed.disconnect(_on_active_health_changed)
		_active_pet.targeting.target_changed.disconnect(_on_target_changed)
		_active_pet.targeting.target_lost.disconnect(_on_target_cleared)
		_active_pet.ai.command_rejected.disconnect(_on_command_rejected)

	_active_pet = pet

	if is_instance_valid(_active_pet):
		_active_pet.health.health_changed.connect(_on_active_health_changed)
		_active_pet.targeting.target_changed.connect(_on_target_changed)
		_active_pet.targeting.target_lost.connect(_on_target_cleared)
		_active_pet.ai.command_rejected.connect(_on_command_rejected)
		_on_target_changed(_active_pet.targeting.current_target)
	else:
		_on_target_changed(null)

	_refresh_party()


## 出戰寵物掉血。整排格子重畫太浪費，只動出戰那一格。
func _on_active_health_changed(current: float, maximum: float) -> void:
	var index := Game.party.active_index
	if index >= 0 and index < _slots.size():
		_slots[index].set_hp(current, maximum)


func _on_target_cleared() -> void:
	_on_target_changed(null)


func _on_target_changed(target: Node3D) -> void:
	var pet := target as Pet
	if _target == pet:
		return

	if is_instance_valid(_target):
		_target.health.health_changed.disconnect(_on_target_health_changed)
		_target.tree_exiting.disconnect(_on_target_cleared)

	_target = pet
	if not is_instance_valid(_target):
		_target_box.visible = false
		return

	# 被捕捉 / 倒下的目標會被 queue_free，面板要跟著收起來
	_target.health.health_changed.connect(_on_target_health_changed)
	_target.tree_exiting.connect(_on_target_cleared)
	_target_box.visible = true
	_on_target_health_changed(_target.health.current_health, _target.health.max_health)


func _on_target_health_changed(current: float, maximum: float) -> void:
	if not is_instance_valid(_target) or _target.data == null:
		return
	_target_label.text = "%s（%s） %d/%d" % [
		_target.data.display_name,
		Element.NAMES.get(_target.data.element, "?"),
		ceili(current), int(maximum)]
	_target_bar.set_ratio(current / maximum if maximum > 0.0 else 0.0)


# --- 提示訊息（取代原本的 print）--------------------------------------------

func _on_capture_attempted(target: Pet, _ball: BallData, success: bool, rate: float) -> void:
	var pet_name := target.data.display_name if is_instance_valid(target) else "牠"
	if success:
		_notify("捕捉成功！%s 加入隊伍" % pet_name)
		return
	# 失敗要讓玩家知道「差多少」，不然只會覺得是隨機整人
	_notify("捕捉失敗（成功率 %d%%）— 再打弱一點" % roundi(rate * 100.0))


func _on_capture_rejected(reason: StringName) -> void:
	_notify("不能丟球：%s" % _reason_text(reason))


func _on_command_rejected(reason: StringName) -> void:
	_notify(_reason_text(reason))


func _on_switch_rejected(slot: int, reason: StringName) -> void:
	var instance := Game.party.at(slot)
	var who := instance.data.display_name if instance != null else ""
	_notify("不能切到第 %d 格：%s%s" % [slot + 1, who, _reason_text(reason)])


func _reason_text(reason: StringName) -> String:
	return REASON_TEXT.get(reason, String(reason))


func _notify(text: String) -> void:
	_notice_label.text = text
	_notice_label.modulate.a = 1.0
	if _notice_tween != null and _notice_tween.is_valid():
		_notice_tween.kill()
	_notice_tween = create_tween()
	_notice_tween.tween_interval(NOTICE_SECONDS)
	_notice_tween.tween_property(_notice_label, "modulate:a", 0.0, NOTICE_FADE)


# --- 建立畫面 ---------------------------------------------------------------
#
# 全部用程式建：五個格子是同一個東西重複五次，寫進 .tscn 只是把同一段複製五遍。

func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_target_panel(root)
	_build_bottom_bar(root)


## 目標面板放畫面上方正中間——玩家盯著怪獸看，視線離那裡最近。
func _build_target_panel(root: Control) -> void:
	_target_box = VBoxContainer.new()
	_target_box.name = "TargetPanel"
	_target_box.anchor_left = 0.5
	_target_box.anchor_right = 0.5
	_target_box.offset_left = -TARGET_WIDTH * 0.5
	_target_box.offset_right = TARGET_WIDTH * 0.5
	_target_box.offset_top = MARGIN
	_target_box.offset_bottom = MARGIN + TARGET_HEIGHT
	_target_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_target_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_box.visible = false
	root.add_child(_target_box)

	_target_label = _make_label(15, HORIZONTAL_ALIGNMENT_CENTER)
	_target_box.add_child(_target_label)

	_target_bar = HudHpBar.new()
	_target_bar.custom_minimum_size = Vector2(0.0, 10.0)
	_target_box.add_child(_target_bar)


func _build_bottom_bar(root: Control) -> void:
	var bottom := VBoxContainer.new()
	bottom.name = "BottomBar"
	bottom.anchor_left = 0.5
	bottom.anchor_right = 0.5
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_left = -BOTTOM_WIDTH * 0.5
	bottom.offset_right = BOTTOM_WIDTH * 0.5
	bottom.offset_top = -(BOTTOM_HEIGHT + MARGIN)
	bottom.offset_bottom = -MARGIN
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 6)
	root.add_child(bottom)

	_notice_label = _make_label(15, HORIZONTAL_ALIGNMENT_CENTER)
	_notice_label.modulate.a = 0.0
	bottom.add_child(_notice_label)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	bottom.add_child(row)

	# 左邊的空位：和右邊球數同寬，Party 五格才會落在畫面正中央
	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.custom_minimum_size = Vector2(BALL_WIDTH, 0.0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	var party_bar := HBoxContainer.new()
	party_bar.name = "PartyBar"
	party_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	party_bar.add_theme_constant_override("separation", int(SLOT_SEPARATION))
	row.add_child(party_bar)

	# 上限 5 是硬規則，格子數直接綁 PartyManager，不要各寫各的
	for i in PartyManager.MAX_SIZE:
		var slot := PartySlot.new()
		slot.name = "Slot%d" % (i + 1)
		party_bar.add_child(slot)
		_slots.append(slot)

	_ball_label = _make_label(16, HORIZONTAL_ALIGNMENT_LEFT)
	_ball_label.name = "BallCount"
	_ball_label.custom_minimum_size = Vector2(BALL_WIDTH, 0.0)
	_ball_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_ball_label)


## 天空很亮，白字直接放上去會看不清楚——一律加黑色描邊。
func _make_label(font_size: int, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("outline_size", 5)
	label.horizontal_alignment = alignment
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
