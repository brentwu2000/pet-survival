## 屬性（規格書 §7）。
##
## 規格書第一版列五種（Fire / Water / Grass / Electric / Ground），
## 並允許「未來可擴充，不修改 Combat 核心」——Steel 就是照這條路加的第六種，
## 為機械小人（`docs/references/monsters/機械小人_設定集.png`）而生。
##
## 這個 class 只放 enum 與顯示名稱——**克制關係在 ElementTable 資料裡**，不在這裡。
## 硬規則 5：禁止 `if element == ...` 散落各處。
class_name Element
extends RefCounted

enum Type { FIRE, WATER, GRASS, ELECTRIC, GROUND, STEEL }

const NAMES := {
	Type.FIRE: "Fire",
	Type.WATER: "Water",
	Type.GRASS: "Grass",
	Type.ELECTRIC: "Electric",
	Type.GROUND: "Ground",
	Type.STEEL: "Steel",
}
