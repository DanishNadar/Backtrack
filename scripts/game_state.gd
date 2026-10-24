extends Node
## Progress that carries across nights (autoloaded as GameState).

const START_STRENGTH := 0.25   # you begin mostly faded
const GAIN_PER_NIGHT := 0.15   # earned by finishing a maze honestly
const CHEAT_PENALTY := 0.3     # lost per restricted shortcut used

const MEMORIES: Array[String] = [
	"CORE MEMORY — The Kitchen\n\nLeft, left, then straight ahead. The same way you walked to the kettle every morning for forty years.\nA nurse sets down a cup of tea. You reach for the handle before you see it.",
	"CORE MEMORY — The Garden\n\nRows, and the gaps between rows. You used to plant tomatoes like this.\nYou notice the hospital courtyard is laid out in the same pattern. Your hands remember the soil.",
	"CORE MEMORY — The Piano\n\nThree steps forward, one back, repeat. A scale.\nThere is an old upright in the day room. You press the keys and they press back.",
	"CORE MEMORY — Her Name\n\nA turn you almost missed, then a long straight corridor home.\nYour daughter visits. For the first time since the accident, you say her name before she says it.",
	"CORE MEMORY — The Road\n\nYou remember the headlights. You remember stepping off the curb.\nYou remember that you were walking home to someone. You are still walking home.",
]


var night := 1
var strength := START_STRENGTH
var cheats_this_night := 0


func reset() -> void:
	night = 1
	strength = START_STRENGTH
	cheats_this_night = 0


func memory_for(n: int) -> String:
	return MEMORIES[mini(n - 1, MEMORIES.size() - 1)]
