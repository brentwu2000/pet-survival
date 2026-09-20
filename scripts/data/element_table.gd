## 屬性克制表（規格書 §7，硬規則 5）。
##
## 倍率只有三個值：1.5 / 1.0 / 0.75。不要引入 2.0 / 0.5 / 0.0。
## 擴充 Ice / Light / Dark 時只改 Element 的 enum 與這份 .tres，**不動 CombatComponent**。
class_name ElementTable
extends Resource

const SUPER_EFFECTIVE := 1.5
const NORMAL := 1.0
const NOT_EFFECTIVE := 0.75

## attacker(Element.Type) -> Array[Element.Type]，被這個屬性克制的目標。
@export var strong_against: Dictionary = {}


func get_multiplier(attacker: Element.Type, defender: Element.Type) -> float:
	if defender in strong_against.get(attacker, []):
		return SUPER_EFFECTIVE
	if attacker in strong_against.get(defender, []):
		return NOT_EFFECTIVE
	return NORMAL
