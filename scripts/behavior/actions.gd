extends RefCounted
## Discrete action set shared by pluggable brains. Effects are applied by SimWorld.

const FORWARD := 0
const TURN_LEFT := 1   # heading -= TURN_STEP
const TURN_RIGHT := 2  # heading += TURN_STEP
const EAT := 3         # eat nearest perceived food, only succeeds within reach
const REST := 4        # no movement, still pays basal metabolism
const SIGNAL_FIRST := 5
const MAX_SIGNALS := 8
const DRINK := SIGNAL_FIRST + MAX_SIGNALS # append; never renumber persisted actions
const COUNT := DRINK + 1
const TURN_STEP := 0.5 # radians per tick; turns are followed by a forward move
const NAMES := ["forward", "turn_left", "turn_right", "eat", "rest", "emit_signal_0", "emit_signal_1", "emit_signal_2", "emit_signal_3", "emit_signal_4", "emit_signal_5", "emit_signal_6", "emit_signal_7", "drink"]

static func emitir_sinal(symbol: int) -> int:
	return SIGNAL_FIRST + symbol if symbol >= 0 and symbol < MAX_SIGNALS else -1

static func name_of(action: int) -> String:
	if action < 0 or action >= COUNT:
		return "invalid"
	return NAMES[action]
