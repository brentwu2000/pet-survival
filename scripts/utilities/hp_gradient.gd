## 血量顏色：綠 → 黃 → 紅。
##
## 頭頂血條（`PetHealthBar`）與 HUD 血條（`HudHpBar`）共用同一組顏色。
## 分開寫兩份就會慢慢對不上，玩家會看到「同一隻寵物的兩條血條顏色不一樣」。
##
## 捕捉時機看的就是這個顏色（規格書 §10：HP 越低越好抓）。
class_name HpGradient
extends RefCounted

const FULL := Color(0.35, 0.85, 0.4)
const HALF := Color(0.95, 0.8, 0.2)
const LOW := Color(0.9, 0.25, 0.2)


static func color_for(ratio: float) -> Color:
	var value := clampf(ratio, 0.0, 1.0)
	if value < 0.5:
		return LOW.lerp(HALF, value * 2.0)
	return HALF.lerp(FULL, (value - 0.5) * 2.0)
