## 屬性（規格書 §7）。
##
## 規格書第一版列五種（Fire / Water / Grass / Electric / Ground），
## 並允許「未來可擴充，不修改 Combat 核心」——Steel 就是照這條路加的第六種，
## 為機械小人（`docs/references/monsters/機械小人_設定集.png`）而生。
##
## 這個 class 只放 enum、顯示名稱與顯示顏色——**克制關係在 ElementTable 資料裡**，不在這裡。
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

## 純顯示用（placeholder 膠囊、之後的 UI 標籤）。
## 這是查表不是分支——克制計算一律走 ElementTable，不准拿顏色反推屬性關係。
const COLORS := {
	Type.FIRE: Color(0.91, 0.33, 0.18),
	Type.WATER: Color(0.18, 0.56, 0.88),
	Type.GRASS: Color(0.30, 0.69, 0.31),
	Type.ELECTRIC: Color(0.95, 0.77, 0.24),
	Type.GROUND: Color(0.66, 0.47, 0.29),
	Type.STEEL: Color(0.56, 0.60, 0.65),
}
