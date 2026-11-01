extends RefCounted
## Discrete action set shared by pluggable brains. Effects are applied by SimWorld.

const FORWARD := 0
const TURN_LEFT := 1   # heading -= TURN_STEP
const TURN_RIGHT := 2  # heading += TURN_STEP
const EAT := 3         # eat nearest perceived food, only succeeds within reach
const REST := 4        # no movement, still pays basal metabolism
const COUNT := 5
const TURN_STEP := 0.5 # radians per tick; turns are followed by a forward move
const NAMES := ["forward", "turn_left", "turn_right", "eat", "rest"]

static func name_of(action: int) -> String:
	if action < 0 or action >= COUNT:
		return "invalid"
	return NAMES[action]
