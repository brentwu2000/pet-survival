## 腳下的選取光圈（規格書 §22 的 SelectionIndicator）。
##
## 用途是讓玩家看得出來「誰在聽我的」與「我指定了誰」——
## 沒有它的話，指令下成功或失敗在畫面上完全一樣。
class_name SelectionIndicator
extends MeshInstance3D

enum Kind { NONE, ACTIVE, TARGET }

## 顏色要在深綠地面上拉得開，而且不能只靠色相區分（綠圈畫在綠地上等於看不到）。
const COLORS := {
	Kind.ACTIVE: Color(0.45, 1.0, 0.9, 0.45),    ## 出戰中的自家寵物
	Kind.TARGET: Color(1.0, 0.3, 0.22, 0.55),    ## 玩家指定的攻擊目標
}

## 圓盤半徑。用實心圓盤而不是細圓環：
## 圓環在正常鏡頭距離下只有 1~2 像素寬，實際上看不見。
const RADIUS := 0.6

var _material: StandardMaterial3D = null


func _ready() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = RADIUS
	disc.bottom_radius = RADIUS
	disc.height = 0.02
	disc.radial_segments = 24
	disc.rings = 0
	mesh = disc

	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# 光圈貼在地面上，不要被地面 z-fighting 吃掉
	_material.no_depth_test = true
	material_override = _material

	position.y = 0.03
	show_as(Kind.NONE)


func show_as(kind: Kind) -> void:
	if kind == Kind.NONE:
		visible = false
		return
	visible = true
	_material.albedo_color = COLORS[kind]
