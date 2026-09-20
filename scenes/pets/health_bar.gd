## 頭頂血條。
##
## 滿血時自動隱藏，避免整片光圈與血條蓋住畫面；
## 一掉血就出現——捕捉系統要看的就是這條（規格書 §10：HP 越低捕捉率越高）。
class_name PetHealthBar
extends Node3D

const WIDTH := 0.85
const HEIGHT := 0.1

var _fill: MeshInstance3D = null
var _fill_material: StandardMaterial3D = null


func _ready() -> void:
	_build_quad(Color(0.08, 0.08, 0.1, 0.85), 0.0)
	_fill = _build_quad(HpGradient.FULL, 0.001)
	_fill_material = _fill.material_override
	visible = false


func setup(health: HealthComponent) -> void:
	health.health_changed.connect(_on_health_changed)
	_on_health_changed(health.current_health, health.max_health)


func _build_quad(color: Color, z_offset: float) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(WIDTH, HEIGHT)

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	# 血條是 UI，要蓋在角色上面，不要被 sprite 擋住
	material.no_depth_test = true

	var node := MeshInstance3D.new()
	node.mesh = quad
	node.material_override = material
	node.position.z = z_offset
	add_child(node)
	return node


func _on_health_changed(current: float, maximum: float) -> void:
	var ratio := clampf(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0
	visible = ratio < 1.0

	# QuadMesh 以原點為中心，縮放後要往左補回來，血條才會從右邊減少
	_fill.scale.x = maxf(ratio, 0.0001)
	_fill.position.x = -WIDTH * (1.0 - ratio) * 0.5

	# 綠 -> 黃 -> 紅。顏色與 HUD 血條共用 HpGradient，兩邊才不會慢慢對不上
	_fill_material.albedo_color = HpGradient.color_for(ratio)
