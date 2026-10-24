extends Node
## Progress that carries across nights (autoloaded as GameState).

const START_STRENGTH := 0.25   # you begin mostly faded
const GAIN_PER_NIGHT := 0.15   # earned by finishing a night without secret walls


var night := 1
var strength := START_STRENGTH
var cheats_this_night := 0


func reset() -> void:
	night = 1
	strength = START_STRENGTH
	cheats_this_night = 0


## One night per core memory in the story.
func total_nights() -> int:
	return Story.MEMORIES.size()


func is_last_night() -> bool:
	return night >= total_nights()
