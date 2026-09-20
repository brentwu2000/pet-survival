## HUD 的血條。Party 格子與目標面板共用同一個。
##
## 自己長出背景與填充——跟 `PetHealthBar` 一樣用程式建，
## 這樣 HUD 的 .tscn 就不必手工排五格 × 每格三層節點。
class_name HudHpBar
extends Control

const BG_COLOR := Color(0.05, 0.05, 0.07, 0.9)

var _fill: ColorRect = null
var _ratio: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_rect(BG_COLOR, 1.0)
	_fill = _add_rect(HpGradient.color_for(_ratio), _ratio)


## 可以在進樹前呼叫——比例先記著，`_ready()` 建好填充後再套用。
func set_ratio(ratio: float) -> void:
	_ratio = clampf(ratio, 0.0, 1.0)
	if _fill == null:
		return
	# 錨點右邊界 = 比例，血條就從右邊減少。
	_fill.anchor_right = _ratio
	_fill.color = HpGradient.color_for(_ratio)


func ratio() -> float:
	return _ratio


func _add_rect(color: Color, right_anchor: float) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# offset 全部是 0，所以寬度就是 anchor_right × 父節點寬度。
	rect.anchor_right = right_anchor
	rect.anchor_bottom = 1.0
	add_child(rect)
	return rect
