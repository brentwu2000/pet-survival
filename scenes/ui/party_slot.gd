## HUD 底部的一個 Party 格子（硬規則 3：Party 上限 5、同時出戰 1）。
##
## 一格只有四種長相：空的 / 待命 / 出戰中 / 倒下。
## 數字就是鍵盤的 1~5——玩家要能一眼對起來，所以數字一定印在名字前面。
##
## 這一格**不吃滑鼠**（`MOUSE_FILTER_IGNORE`）：Phase 1 換寵只用鍵盤，
## 而且左鍵是「指定目標」的 raycast，被 UI 吃掉會變成點了沒反應。
class_name PartySlot
extends Control

const SLOT_SIZE := Vector2(116.0, 44.0)
const BAR_HEIGHT := 8.0
const EMPTY_TEXT := "--"

const BG_NORMAL := Color(0.09, 0.09, 0.12, 0.8)
const BG_ACTIVE := Color(0.16, 0.15, 0.09, 0.9)
const BORDER_NORMAL := Color(0.3, 0.3, 0.36, 0.9)
const BORDER_ACTIVE := Color(0.95, 0.8, 0.25)
## 空格子與倒下的寵物都調暗，但倒下的還看得到名字——玩家要知道是誰倒了。
const DIM_EMPTY := 0.45
const DIM_FAINTED := 0.6

var _style: StyleBoxFlat = null
var _name_label: Label = null
var _hp_label: Label = null
var _bar: HudHpBar = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = SLOT_SIZE

	_style = StyleBoxFlat.new()
	_style.bg_color = BG_NORMAL
	_style.set_corner_radius_all(4)
	_style.set_border_width_all(2)
	_style.border_color = BORDER_NORMAL

	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _style)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 6.0
	box.offset_right = -6.0
	box.offset_top = 4.0
	box.offset_bottom = -5.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 3)
	add_child(box)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)

	_name_label = _make_label(13, HORIZONTAL_ALIGNMENT_LEFT)
	row.add_child(_name_label)
	_hp_label = _make_label(11, HORIZONTAL_ALIGNMENT_RIGHT)
	_hp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_hp_label)

	_bar = HudHpBar.new()
	_bar.custom_minimum_size = Vector2(0.0, BAR_HEIGHT)
	box.add_child(_bar)


## `instance` 為 null = 空格子。`index` 是 0 起算，畫面上顯示 index + 1。
func show_instance(index: int, instance: PetInstance, is_active: bool) -> void:
	var number := index + 1
	if instance == null:
		_name_label.text = "%d %s" % [number, EMPTY_TEXT]
		_hp_label.text = ""
		_bar.visible = false
		_paint(false, false, true)
		return

	_name_label.text = "%d %s" % [number, instance.data.display_name]
	_bar.visible = true
	set_hp(instance.current_hp, instance.data.max_hp)
	_paint(is_active, instance.is_fainted, false)


## 出戰中的寵物血量每次變動都會進來——整格重畫太浪費，只動血條與數字。
func set_hp(current: float, maximum: float) -> void:
	_hp_label.text = "%d/%d" % [ceili(current), int(maximum)]
	_bar.set_ratio(current / maximum if maximum > 0.0 else 0.0)


## 給測試與 debug 用：這一格現在顯示什麼。
func text() -> String:
	return "%s %s" % [_name_label.text, _hp_label.text]


func _paint(is_active: bool, is_fainted: bool, is_empty: bool) -> void:
	_style.bg_color = BG_ACTIVE if is_active else BG_NORMAL
	_style.border_color = BORDER_ACTIVE if is_active else BORDER_NORMAL
	if is_empty:
		modulate.a = DIM_EMPTY
	elif is_fainted:
		modulate.a = DIM_FAINTED
	else:
		modulate.a = 1.0


func _make_label(font_size: int, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = alignment
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
