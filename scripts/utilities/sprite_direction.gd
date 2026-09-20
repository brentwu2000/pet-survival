## 2D 角色在 3D 世界中的方向判定（規格書 §23）。
##
## **主角與寵物共用這一份。** 兩邊各寫一套的話，
## 轉鏡頭時主角和夥伴會不同步，而且很難察覺是哪裡不一致。
##
## 核心：方向取決於**角色朝向相對於鏡頭朝向**，不是角色的世界朝向——
## Camera 可以繞角色轉，所以同一個世界朝向在不同鏡頭角度要播不同方向的圖。
class_name SpriteDirection
extends RefCounted

## 羅盤命名：s = 面向鏡頭（正面），n = 背對鏡頭（背面），順時針。
const DIRECTIONS_8: PackedStringArray = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]
## 4 方向模式只取四個正方向，共用同一份 SpriteFrames。
const DIRECTIONS_4: PackedStringArray = ["s", "e", "n", "w"]


static func names_for(count: int) -> PackedStringArray:
	return DIRECTIONS_8 if count == 8 else DIRECTIONS_4


## 0 = s（角色面向鏡頭），順時針遞增。
##
## s / n 不會弄錯（正面 vs 背面），左右則取決於美術的繪製慣例。
##
## **2026-09-13 目視確認後修正：原本左右是反的，拿掉 angle 前面的負號。**
## 這個只能靠人眼繞鏡頭一圈判斷——程式測得出「8 個方向都到得了、順序單調」，
## 但測不出「畫面上的左邊該對應哪一張圖」。
static func index_for(char_forward: Vector3, cam_forward: Vector3, count: int) -> int:
	var f := Vector2(char_forward.x, char_forward.z).normalized()
	var c := Vector2(cam_forward.x, cam_forward.z).normalized()
	var angle := f.angle_to(c)
	var step := TAU / float(count)
	# angle 可能是負的，用 posmod 而不是 % 才不會拿到負索引。
	return posmod(int(roundf(angle / step)), count)


static func suffix_for(char_forward: Vector3, cam_forward: Vector3, count: int) -> String:
	var names := names_for(count)
	return names[index_for(char_forward, cam_forward, count)]
