extends RefCounted
## Bounded per-creature atelier competence, observation memory, and open-loop motor reproduction (M3b / X5).
## Phase 1 (Observation): creature perceives demonstration as a noisy, capacity-bounded stroke-3 sequence
## and encodes a translation/scale-invariant representation in shape_memory.
## Phase 2 (Reproduction): creature generates primitive pen actions (move_pen, pen_down, pen_up, segment)
## strictly from shape_memory without reading reference_strokes, subject to motor drift, corner compliance, and noise.
## Phase 3 (Feedback): creature receives only scalar symmetric Chamfer error in [0, 1].
## Phase 4 (Learning): creature calibrates decoder_params and consolidates shape_memory across attempts;
## competence is persisted per creature, never inherited genetically, and never adds energy or hydration.

const Data = preload("res://scripts/core/sim_data.gd")
const ObjectMemory = preload("res://scripts/mind/object_memory.gd")
const Textos = preload("res://scripts/core/textos.gd")

const VERSION := 2
const BOARD_LIMIT := 32
const BOARD_RADIUS := 6.0
const GALLERY_LIMIT := 64
const BOARD_ARTIFACT_LIMIT := 16
const ATTEMPT_LIMIT := 32
const CANVAS_SIZE := 64.0
const MAX_STROKES_PER_DRAWING := 8
const MAX_POINTS_PER_STROKE := 24
const MAX_POINTS_PER_DRAWING := 64
const MAX_ACTIONS_PER_DRAWING := 64
const MAX_STEPS_PER_TICK := 2
const DIRECTIONS := 16
const MAG_BUCKETS := 3
const LENGTHS := [2.0, 3.0, 4.5]
const OPS := ["move_pen", "pen_down", "pen_up", "segment"]
const TRAIN_SHAPES := ["linha", "circulo", "quadrado"]
const HOLDOUT_SHAPES := ["triangulo", "cruz", "zigue_zague"]
const KNOWN_SHAPES := ["linha", "circulo", "quadrado", "triangulo", "cruz", "zigue_zague"]
const SHAPES := ["linha", "circulo", "quadrado"]
const ALL_SHAPES := ["linha", "circulo", "quadrado", "triangulo", "cruz", "zigue_zague", "rabisco"]
const POLICY_MODES := ["trained", "naive", "memoria_sem_treino", "servo_geometrico", "random", "frozen", "oraculo"]
const SUCCESS_THRESHOLD := 0.22
const DRAW_COOLDOWN := 90
const DRAW_ENERGY_COST := 0.012
const SAMPLES_PER_SEGMENT := 4

const MEMORY_SLOT_LIMIT := 6
const MAX_MEMORY_SEGMENTS := 8
const PERCEPTION_ANG_NOISE := 0.22
const PERCEPTION_LEN_NOISE := 0.20
const MOTOR_ANG_NOISE := 0.38
const PHYSICAL_WRIST_DRIFT := -0.26
const PHYSICAL_TURN_COMPLIANCE := 0.64

const INITIAL_DECODER_PARAMS := [0.62, -0.44, 0.0]
const ORACLE_DECODER_PARAMS := [0.26, 0.5625, 1.0]
const SERVO_DECODER_PARAMS := [0.0, 0.0, 0.0]
const INITIAL_SEARCH_DIRS := [-1.0, 1.0, 1.0]
const INITIAL_STEP_SIZES := [0.34, 0.46, 0.36]

var version: int = VERSION
var next_id: int = 1
var learning: bool = true
var policy_mode: String = "trained"
var observation_enabled: bool = true
var updates: int = 0
var decoder_params: Array = []
var best_params: Array = []
var search_dirs: Array = []
var step_sizes: Array = []
var active_probe_axis: int = -1
var probe_shape: String = ""
var best_error: Dictionary = {}
var shape_memory: Dictionary = {}
var offset_weights: Array = []
var dir_weights: Array = []
var len_weights: Array = []
var last_error: Dictionary = {}
var attempts: Array = []
var artifacts: Array = []
var active: Dictionary = {}

func _init() -> void:
	reset_policy()

func reset_policy() -> void:
	updates = 0
	decoder_params = INITIAL_DECODER_PARAMS.duplicate()
	best_params = INITIAL_DECODER_PARAMS.duplicate()
	search_dirs = INITIAL_SEARCH_DIRS.duplicate()
	step_sizes = INITIAL_STEP_SIZES.duplicate()
	active_probe_axis = -1
	probe_shape = ""
	best_error.clear()
	shape_memory.clear()
	offset_weights.resize(DIRECTIONS)
	offset_weights.fill(0.0)
	dir_weights.resize(DIRECTIONS * DIRECTIONS)
	dir_weights.fill(0.0)
	len_weights.resize(MAG_BUCKETS * LENGTHS.size())
	len_weights.fill(0.0)
	last_error.clear()

func has_observed(shape: String) -> bool:
	if not shape_memory.has(shape):
		return false
	var mem: Variant = shape_memory.get(shape)
	return mem is Dictionary and mem.get("rel_turns") is Array and not mem["rel_turns"].is_empty()

func clear_memory(shape: String = "") -> void:
	if shape == "":
		shape_memory.clear()
	else:
		shape_memory.erase(shape)

func effective_params(shape: String = "") -> Array:
	if policy_mode == "oraculo":
		return ORACLE_DECODER_PARAMS.duplicate()
	if policy_mode == "servo_geometrico":
		return SERVO_DECODER_PARAMS.duplicate()
	if policy_mode in ["naive", "memoria_sem_treino"] or (not learning and updates == 0):
		return INITIAL_DECODER_PARAMS.duplicate()
	if not learning or policy_mode == "frozen":
		return best_params.duplicate()
	return decoder_params.duplicate()

func _sync_summary_weights() -> void:
	if offset_weights.size() != DIRECTIONS:
		offset_weights.resize(DIRECTIONS)
	if dir_weights.size() != DIRECTIONS * DIRECTIONS:
		dir_weights.resize(DIRECTIONS * DIRECTIONS)
	if len_weights.size() != MAG_BUCKETS * LENGTHS.size():
		len_weights.resize(MAG_BUCKETS * LENGTHS.size())
	var p0 := clampf(float(best_params[0]), -1.0, 1.0)
	var p1 := clampf(float(best_params[1]), -1.0, 1.0)
	var p2 := clampf(float(best_params[2]), 0.0, 1.0)
	for i in range(DIRECTIONS):
		var ang := float(i) * TAU / float(DIRECTIONS)
		offset_weights[i] = snappedf(clampf(p0 * cos(ang) + p1 * sin(ang), -1.0, 1.0), 0.000001)
	for i in range(DIRECTIONS * DIRECTIONS):
		var r := float(int(i / DIRECTIONS)) / float(DIRECTIONS)
		var c := float(i % DIRECTIONS) / float(DIRECTIONS)
		dir_weights[i] = snappedf(clampf(0.5 * p1 * (r - c) + 0.4 * p2, -1.0, 1.0), 0.000001)
	for i in range(MAG_BUCKETS * LENGTHS.size()):
		len_weights[i] = snappedf(p2, 0.000001)

static func make_board(board_id: int, pos: Vector2, tick: int = 0) -> Dictionary:
	return {
		"id": board_id,
		"pos": pos,
		"reference_shape": "",
		"reference_params": {},
		"reference_strokes": [],
		"active_actions": [],
		"active_strokes": [],
		"owner_id": 0,
		"updated_tick": tick,
		"artifacts": []
	}

static func board_appearance(board: Dictionary) -> Dictionary:
	return {
		"id": int(board.id),
		"pos": board.pos,
		"category": "quadro",
		"appearance": "plano",
		"reference_shape": str(board.get("reference_shape", ""))
	}

static func sanitize_params(params: Dictionary = {}) -> Dictionary:
	var center := Vector2(CANVAS_SIZE * 0.5, CANVAS_SIZE * 0.5)
	if params.get("center") is Vector2 and params["center"].is_finite():
		center = params["center"]
	elif Data.vector(params.get("center")):
		center = Data.unpack_vector(params["center"])
	center = center.clamp(Vector2(10.0, 10.0), Vector2(CANVAS_SIZE - 10.0, CANVAS_SIZE - 10.0))
	var scale_val := 1.0
	if Data.number(params.get("scale")):
		scale_val = clampf(float(params["scale"]), 0.45, 1.65)
	var dir_offset := 0
	if Data.integer(params.get("dir_offset"), -1024):
		dir_offset = ((int(params["dir_offset"]) % DIRECTIONS) + DIRECTIONS) % DIRECTIONS
	return {
		"center": [snappedf(center.x, 0.000001), snappedf(center.y, 0.000001)],
		"scale": snappedf(scale_val, 0.000001),
		"dir_offset": dir_offset
	}

static func shape_segment_dirs(shape: String, dir_offset: int = 0) -> Array:
	var base := ((dir_offset % DIRECTIONS) + DIRECTIONS) % DIRECTIONS
	var dirs: Array = []
	match shape:
		"linha":
			for i in range(8):
				dirs.append(base)
		"circulo":
			# Regular 8-segment polygon approximation of a circle; curves only by straight segments.
			for i in range(8):
				dirs.append((base + 2 * i) % DIRECTIONS)
		"quadrado":
			for i in range(8):
				dirs.append((base + 4 * int(i / 2)) % DIRECTIONS)
		"triangulo":
			# Closed 8-segment isosceles triangle (unseen holdout shape).
			for o in [0, 0, 5, 5, 5, 11, 11, 11]:
				dirs.append((base + o) % DIRECTIONS)
		"cruz":
			# Symmetric 4-arm cross in '+' (unseen holdout shape).
			for o in [0, 8, 8, 0, 4, 12, 12, 4]:
				dirs.append((base + o) % DIRECTIONS)
		"zigue_zague":
			# 4-tooth sawtooth wave (unseen holdout shape).
			for o in [3, 3, 13, 13, 3, 3, 13, 13]:
				dirs.append((base + o) % DIRECTIONS)
	return dirs

static func build_reference_strokes(shape: String, params: Dictionary = {}) -> Array:
	if shape not in KNOWN_SHAPES:
		return []
	var clean := sanitize_params(params)
	var center := Data.unpack_vector(clean.center)
	var scale_val := float(clean.scale)
	var dirs := shape_segment_dirs(shape, int(clean.dir_offset))
	var step_px := float(LENGTHS[1]) * scale_val
	var raw_pts: Array = [Vector2.ZERO]
	var cursor := Vector2.ZERO
	for d in dirs:
		cursor += Vector2.from_angle(float(d) * TAU / float(DIRECTIONS)) * step_px
		raw_pts.append(cursor)
	var mean := Vector2.ZERO
	for p in raw_pts:
		mean += p
	mean /= float(raw_pts.size())
	var stroke: Array = []
	for p in raw_pts:
		var pt: Vector2 = (p - mean + center).clamp(Vector2(2.0, 2.0), Vector2(CANVAS_SIZE - 2.0, CANVAS_SIZE - 2.0))
		stroke.append([snappedf(pt.x, 0.000001), snappedf(pt.y, 0.000001)])
	return [stroke]

static func demonstrate_shape(board: Dictionary, forma: String, tick: int, params: Dictionary = {}) -> bool:
	if forma not in KNOWN_SHAPES:
		return false
	var clean := sanitize_params(params)
	var ref_strokes := build_reference_strokes(forma, clean)
	if ref_strokes.is_empty():
		return false
	board["reference_shape"] = forma
	board["reference_params"] = clean
	board["reference_strokes"] = ref_strokes
	board["updated_tick"] = tick
	return true

## Phase 1: Observe demonstration as noisy, capacity-bounded stroke-3 sequence and encode into shape_memory.
func observe_demonstration(shape: String, reference_strokes: Array, rng, tick: int = 0) -> bool:
	if not observation_enabled or shape not in KNOWN_SHAPES or reference_strokes.is_empty():
		return false
	var stroke: Variant = reference_strokes[0]
	if not stroke is Array or stroke.size() < 2:
		return false
	var seg_count := mini(stroke.size() - 1, MAX_MEMORY_SEGMENTS)
	if seg_count < 1:
		return false
	var eff := effective_params(shape)
	var prec := clampf(float(eff[2]), 0.0, 1.0)
	var noise_scale := 0.0 if policy_mode == "oraculo" else (1.0 - 0.85 * prec)
	var seg_angles: Array = []
	var seg_lens: Array = []
	var stroke3: Array = []
	var sum_len := 0.0
	for i in range(seg_count):
		var a := Data.unpack_vector(stroke[i])
		var b := Data.unpack_vector(stroke[i + 1])
		var delta := b - a
		var ang_noise := noise_scale * float(rng.between(-PERCEPTION_ANG_NOISE, PERCEPTION_ANG_NOISE))
		var len_noise := noise_scale * float(rng.between(-PERCEPTION_LEN_NOISE, PERCEPTION_LEN_NOISE))
		var ang: float = delta.angle() + ang_noise
		var l: float = clampf(delta.length() * (1.0 + len_noise), 0.2, CANVAS_SIZE)
		seg_angles.append(ang)
		seg_lens.append(l)
		sum_len += l
		var obs_vec := Vector2.from_angle(ang) * l
		var pen_end := 1 if i == seg_count - 1 else 0
		stroke3.append([snappedf(obs_vec.x, 0.000001), snappedf(obs_vec.y, 0.000001), pen_end])
	var mean_len := sum_len / float(seg_count)
	# Store normalized observed displacements, never absolute canvas coordinates
	# or the demonstration's physical scale.
	for item in stroke3:
		item[0] = snappedf(float(item[0]) * LENGTHS[1] / mean_len, 0.000001)
		item[1] = snappedf(float(item[1]) * LENGTHS[1] / mean_len, 0.000001)
	var step_rad := TAU / float(DIRECTIONS)
	var cont_dir0 := wrapf(float(seg_angles[0]), 0.0, TAU) / step_rad
	var anchor_dir := ((int(round(cont_dir0)) % DIRECTIONS) + DIRECTIONS) % DIRECTIONS
	var turn_rads: Array = [0.0]
	var rel_lens: Array = []
	for i in range(seg_count):
		var ratio := float(seg_lens[i]) / maxf(0.5, mean_len)
		var l_b := 0 if ratio < 0.78 else (1 if ratio <= 1.24 else 2)
		rel_lens.append(l_b)
		if i > 0:
			var diff_rad := wrapf(float(seg_angles[i]) - float(seg_angles[i - 1]), -PI, PI)
			turn_rads.append(snappedf(diff_rad, 0.000001))
	var obs_count := 1
	if learning and policy_mode == "trained" and shape_memory.has(shape):
		var prev_mem: Dictionary = shape_memory[shape]
		var prev_rads: Array = prev_mem.get("turn_rads", [])
		var prev_n: int = int(prev_mem.get("observations", 1))
		if prev_rads.size() == turn_rads.size():
			obs_count = mini(prev_n + 1, 64)
			var w_prev := clampf(float(prev_n) / float(obs_count), 0.3, 0.85)
			for i in range(1, turn_rads.size()):
				var prev_r := float(prev_rads[i])
				var cur_r := float(turn_rads[i])
				turn_rads[i] = snappedf(wrapf(prev_r + wrapf(cur_r - prev_r, -PI, PI) * (1.0 - w_prev), -PI, PI), 0.000001)
	var rel_turns: Array = [0]
	var flip_sign := 1
	for i in range(1, turn_rads.size()):
		var raw_bins := int(round(float(turn_rads[i]) / step_rad))
		var wrapped_bins := ((raw_bins + 8 + DIRECTIONS) % DIRECTIONS) - 8
		if absi(wrapped_bins) == 8:
			wrapped_bins = 8 * flip_sign
			flip_sign = -flip_sign
		rel_turns.append(clampi(wrapped_bins, -8, 8))
	if not shape_memory.has(shape) and shape_memory.size() >= MEMORY_SLOT_LIMIT:
		var oldest_key := ""
		var oldest_tick := 2147483647
		for k in shape_memory:
			var t_k := int(shape_memory[k].get("last_tick", 0))
			if t_k < oldest_tick:
				oldest_tick = t_k
				oldest_key = str(k)
		if oldest_key != "":
			shape_memory.erase(oldest_key)
	shape_memory[shape] = {
		"anchor_dir": anchor_dir,
		"rel_turns": rel_turns,
		"rel_lens": rel_lens,
		"turn_rads": turn_rads,
		"stroke3": stroke3,
		"observations": obs_count,
		"last_tick": maxi(0, tick)
	}
	return true

## Phase 2: Reproduce segment plan strictly from shape_memory without access to reference_strokes.
func _plan_reproduction_trace(target_shape: String, rng) -> Array:
	var planned: Array = []
	if policy_mode == "random" or target_shape == "" or target_shape == "rabisco":
		for i in range(MAX_MEMORY_SEGMENTS):
			var r_dir := clampi(int(rng.between(0.0, float(DIRECTIONS))), 0, DIRECTIONS - 1)
			var r_len := clampi(int(rng.between(0.0, float(LENGTHS.size()))), 0, LENGTHS.size() - 1)
			planned.append({
				"s_dir": r_dir,
				"s_mag": r_len,
				"a_dir": r_dir,
				"a_len": r_len,
				"r_step": 0.0
			})
		return planned
	if not has_observed(target_shape):
		return []
	var mem: Dictionary = shape_memory[target_shape]
	var eff := effective_params(target_shape)
	var b_drift := float(eff[0])
	var b_turn := float(eff[1])
	var prec := clampf(float(eff[2]), 0.0, 1.0)
	var net_drift := 0.0 if policy_mode == "oraculo" else (PHYSICAL_WRIST_DRIFT + b_drift)
	var motor_noise_scale := 0.0 if policy_mode == "oraculo" else (1.0 - 0.84 * prec)
	var turn_mult := 1.0 if policy_mode == "oraculo" else clampf(PHYSICAL_TURN_COMPLIANCE * (1.0 + 1.0 * b_turn), 0.25, 1.35)
	var heading := float(mem.anchor_dir) + 1.5 * net_drift
	var nom_heading := int(mem.anchor_dir)
	var rel_turns: Array = mem.rel_turns
	var rel_lens: Array = mem.rel_lens
	for i in range(mini(rel_turns.size(), MAX_MEMORY_SEGMENTS)):
		var turn_i := float(rel_turns[i])
		nom_heading = ((nom_heading + int(rel_turns[i])) % DIRECTIONS + DIRECTIONS) % DIRECTIONS
		var corner_load := 2.4 * sin(turn_i * PI / 8.0) + 0.36 * turn_i
		var jitter: float = motor_noise_scale * float(rng.between(-MOTOR_ANG_NOISE, MOTOR_ANG_NOISE))
		var speed_tremor: float = 0.0 if policy_mode == "oraculo" else float(rng.between(-1.0, 1.0)) * (1.0 - 0.55 * prec)
		heading += turn_i + (turn_mult - 1.0) * corner_load + 0.62 * net_drift + jitter
		var a_dir := ((int(round(heading)) % DIRECTIONS) + DIRECTIONS) % DIRECTIONS
		var base_len := clampi(int(rel_lens[i]), 0, LENGTHS.size() - 1)
		var a_len := base_len
		if speed_tremor > 0.36:
			a_len = mini(LENGTHS.size() - 1, base_len + 1)
		elif speed_tremor < -0.36:
			a_len = maxi(0, base_len - 1)
		planned.append({
			"s_dir": nom_heading,
			"s_mag": base_len,
			"a_dir": a_dir,
			"a_len": a_len,
			"r_step": 0.0
		})
	return planned

## Direct action proposal from internal memory without reference vertices.
func propose_actions(shape: String, rng) -> Array:
	var is_known := shape in KNOWN_SHAPES
	if is_known and policy_mode != "random" and not has_observed(shape):
		return []
	var start_dir := clampi(int(rng.between(0.0, float(DIRECTIONS))), 0, DIRECTIONS - 1)
	var planned := _plan_reproduction_trace(shape, rng)
	if planned.is_empty():
		return []
	var actions: Array = [
		{"op": "move_pen", "dir": start_dir, "len": 0},
		{"op": "pen_down", "dir": 0, "len": 0}
	]
	for step in planned:
		actions.append({"op": "segment", "dir": int(step.a_dir), "len": int(step.a_len)})
	actions.append({"op": "pen_up", "dir": 0, "len": 0})
	return actions

static func execute_actions(actions: Array) -> Dictionary:
	var pen_pos := Vector2(CANVAS_SIZE * 0.5, CANVAS_SIZE * 0.5)
	var pen_down := false
	var strokes: Array = []
	var current_stroke: Array = []
	var stroke3: Array = []
	var total_points := 0
	var count := mini(actions.size(), MAX_ACTIONS_PER_DRAWING)
	for i in range(count):
		var act: Dictionary = actions[i]
		var op: String = str(act.get("op", ""))
		var dir_idx: int = ((int(act.get("dir", 0)) % DIRECTIONS) + DIRECTIONS) % DIRECTIONS
		var len_idx: int = clampi(int(act.get("len", 0)), 0, LENGTHS.size() - 1)
		match op:
			"move_pen":
				if pen_down and current_stroke.size() >= 2 and strokes.size() < MAX_STROKES_PER_DRAWING:
					strokes.append(current_stroke)
					if not stroke3.is_empty():
						stroke3.back()[2] = 1
				pen_down = false
				current_stroke = []
				var angle := float(dir_idx) * TAU / float(DIRECTIONS)
				var step_len := float(LENGTHS[len_idx])
				var next_pos := (pen_pos + Vector2.from_angle(angle) * step_len).clamp(Vector2.ZERO, Vector2.ONE * CANVAS_SIZE)
				next_pos = Vector2(snappedf(next_pos.x, 0.000001), snappedf(next_pos.y, 0.000001))
				var delta := next_pos - pen_pos
				pen_pos = next_pos
				stroke3.append([snappedf(delta.x, 0.000001), snappedf(delta.y, 0.000001), 1])
			"pen_down":
				if not pen_down and strokes.size() < MAX_STROKES_PER_DRAWING and total_points < MAX_POINTS_PER_DRAWING:
					pen_down = true
					current_stroke = [[snappedf(pen_pos.x, 0.000001), snappedf(pen_pos.y, 0.000001)]]
					total_points += 1
			"pen_up":
				if pen_down:
					if current_stroke.size() >= 2 and strokes.size() < MAX_STROKES_PER_DRAWING:
						strokes.append(current_stroke)
					if not stroke3.is_empty():
						stroke3.back()[2] = 1
					pen_down = false
					current_stroke = []
			"segment":
				var angle := float(dir_idx) * TAU / float(DIRECTIONS)
				var step_len := float(LENGTHS[len_idx])
				var next_pos := (pen_pos + Vector2.from_angle(angle) * step_len).clamp(Vector2.ZERO, Vector2.ONE * CANVAS_SIZE)
				next_pos = Vector2(snappedf(next_pos.x, 0.000001), snappedf(next_pos.y, 0.000001))
				var delta := next_pos - pen_pos
				var prev_pos := pen_pos
				pen_pos = next_pos
				if pen_down:
					if current_stroke.is_empty() and total_points < MAX_POINTS_PER_DRAWING:
						current_stroke.append([snappedf(prev_pos.x, 0.000001), snappedf(prev_pos.y, 0.000001)])
						total_points += 1
					if current_stroke.size() < MAX_POINTS_PER_STROKE and total_points < MAX_POINTS_PER_DRAWING:
						current_stroke.append([snappedf(pen_pos.x, 0.000001), snappedf(pen_pos.y, 0.000001)])
						total_points += 1
						stroke3.append([snappedf(delta.x, 0.000001), snappedf(delta.y, 0.000001), 0])
					if current_stroke.size() >= MAX_POINTS_PER_STROKE or total_points >= MAX_POINTS_PER_DRAWING:
						if current_stroke.size() >= 2 and strokes.size() < MAX_STROKES_PER_DRAWING:
							strokes.append(current_stroke)
						if not stroke3.is_empty():
							stroke3.back()[2] = 1
						pen_down = false
						current_stroke = []
				else:
					stroke3.append([snappedf(delta.x, 0.000001), snappedf(delta.y, 0.000001), 1])
	if pen_down and current_stroke.size() >= 2 and strokes.size() < MAX_STROKES_PER_DRAWING:
		strokes.append(current_stroke)
		if not stroke3.is_empty():
			stroke3.back()[2] = 1
	return {
		"strokes": strokes,
		"stroke3": stroke3,
		"pen_pos": pen_pos,
		"pen_down": pen_down,
		"total_points": total_points
	}

static func sample_strokes(strokes: Array) -> Array:
	var pts: Array = []
	for stroke in strokes:
		if not stroke is Array or stroke.size() < 2:
			continue
		for i in range(stroke.size() - 1):
			var a := Data.unpack_vector(stroke[i])
			var b := Data.unpack_vector(stroke[i + 1])
			for s in range(SAMPLES_PER_SEGMENT):
				var t := float(s) / float(SAMPLES_PER_SEGMENT)
				pts.append(a.lerp(b, t))
		pts.append(Data.unpack_vector(stroke.back()))
	return pts

static func normalize_points(pts: Array) -> Array:
	if pts.size() < 2:
		return []
	var mean := Vector2.ZERO
	for p in pts:
		mean += p
	mean /= float(pts.size())
	var sum_sq := 0.0
	for p in pts:
		sum_sq += (p - mean).length_squared()
	var rms := sqrt(sum_sq / float(pts.size()))
	if rms < 0.0001 or not is_finite(rms):
		return []
	var out: Array = []
	for p in pts:
		out.append((p - mean) / rms)
	return out

## Symmetric Chamfer distance in [0, 1], invariant to translation and scale.
static func chamfer_distance(strokes_a: Array, strokes_b: Array) -> float:
	var norm_a := normalize_points(sample_strokes(strokes_a))
	var norm_b := normalize_points(sample_strokes(strokes_b))
	if norm_a.is_empty() or norm_b.is_empty():
		return 1.0
	var sum_ab := 0.0
	for pa in norm_a:
		var best := INF
		for pb in norm_b:
			var d: float = pa.distance_to(pb)
			if d < best:
				best = d
		sum_ab += best
	var sum_ba := 0.0
	for pb in norm_b:
		var best := INF
		for pa in norm_a:
			var d: float = pb.distance_to(pa)
			if d < best:
				best = d
		sum_ba += best
	var mean_sym := 0.5 * (sum_ab / float(norm_a.size()) + sum_ba / float(norm_b.size()))
	return snappedf(clampf(mean_sym / 1.12, 0.0, 1.0), 0.000001)

static func candidate(mind, creature, sensors: Dictionary, tick: int) -> Dictionary:
	var best := {"score": -4.0, "id": 0, "novelty": 0.0}
	var s := ObjectMemory.state(mind)
	var t: Dictionary = mind.traits(creature)
	var curiosity := float(t.curiosity) if s.curiosity_enabled else 0.0
	var enthusiasm := float(mind.affect.values.entusiasmo) if mind.affect_enabled and mind.policy_mode == "full" else 0.0
	var receio := float(mind.affect.values.receio) if mind.affect_enabled and mind.policy_mode == "full" else 0.0
	var boredom: float = creature.personality.boredom if creature.personality != null else 0.0
	var fatigue: float = creature.personality.fatigue if creature.personality != null else 0.0
	var thirst_need: float = creature.thirst if creature.personality_water_enabled else 0.0
	var idleness := clampf(1.0 - maxf(creature.hunger, thirst_need) * 1.6 - fatigue * 0.6, 0.0, 1.0)
	if curiosity < 0.15 and enthusiasm < 0.1:
		return best
	for row in sensors.get("boards", []):
		var key := str(row.id)
		if tick < int(s.cooldowns.get(key, 0)):
			continue
		var entry: Dictionary = s.entries.get(key, {}) if mind.memory_enabled else {}
		if tick < int(entry.get("retry_tick", 0)):
			continue
		var nov := ObjectMemory.novelty(mind, row, tick)
		var has_demo := 0.22 if str(row.get("reference_shape", "")) != "" else 0.0
		var score := (nov * 0.65 + idleness * 0.45 + has_demo) * (0.35 + curiosity * 0.85) + enthusiasm * 0.45 + boredom * 0.25
		score -= receio * (0.35 + float(t.caution) * 0.5)
		if score > float(best.score):
			best = {"score": snappedf(score, 0.000001), "id": int(row.id), "novelty": nov}
	return best

## Phase 3 & 4: Scalar error feedback hill-climbing (no reference vertices or per-segment target directions).
func apply_feedback(shape: String, error: float, _unused_reduction: float = 0.0) -> int:
	if not learning or policy_mode != "trained" or shape not in KNOWN_SHAPES:
		return 0
	if not is_finite(error) or error < 0.0 or error > 1.0:
		return 0
	var clean_err := snappedf(clampf(error, 0.0, 1.0), 0.000001)
	last_error[shape] = clean_err
	if not best_error.has(shape) or probe_shape != shape:
		best_error[shape] = clean_err
		probe_shape = shape
		best_params = decoder_params.duplicate()
		active_probe_axis = -1
	elif active_probe_axis >= 0:
		var prev_best := float(best_error[shape])
		if clean_err < prev_best - 0.002:
			best_error[shape] = clean_err
			best_params = decoder_params.duplicate()
		else:
			search_dirs[active_probe_axis] = -float(search_dirs[active_probe_axis])
			step_sizes[active_probe_axis] = snappedf(maxf(0.03, float(step_sizes[active_probe_axis]) * 0.75), 0.000001)
	updates += 1
	# Coordinate search only compares scalar outcomes. No ideal plant parameter
	# or reference direction enters acceptance or the next proposal.
	active_probe_axis = (updates - 1) % 3
	decoder_params = best_params.duplicate()
	var lo := 0.0 if active_probe_axis == 2 else -1.0
	var delta := float(search_dirs[active_probe_axis]) * float(step_sizes[active_probe_axis])
	decoder_params[active_probe_axis] = snappedf(clampf(float(best_params[active_probe_axis]) + delta, lo, 1.0), 0.000001)
	_sync_summary_weights()
	return 1

func start_session(board: Dictionary, tick: int, rng) -> bool:
	var target_shape := str(board.get("reference_shape", ""))
	if target_shape in KNOWN_SHAPES and policy_mode != "random" and not has_observed(target_shape):
		active.clear()
		return false
	var start_dir := clampi(int(rng.between(0.0, float(DIRECTIONS))), 0, DIRECTIONS - 1)
	var start_len := 0
	var start_virtual := Vector2(CANVAS_SIZE * 0.5, CANVAS_SIZE * 0.5)
	# Exploratory scribbles retain their historical per-tick RNG consumption.
	var planned_trace: Array = [] if target_shape == "" else _plan_reproduction_trace(target_shape, rng)
	if planned_trace.is_empty() and target_shape != "":
		active.clear()
		return false
	active = {
		"id": next_id,
		"board_id": int(board.id),
		"target_shape": target_shape,
		"start_tick": tick,
		"step_index": 0,
		"total_segments": MAX_MEMORY_SEGMENTS,
		"status": "active",
		"actions": [
			{"op": "move_pen", "dir": start_dir, "len": start_len},
			{"op": "pen_down", "dir": 0, "len": 0}
		],
		"trace": planned_trace,
		"virtual_pos": Data.pack_vector(start_virtual)
	}
	next_id += 1
	return true

func step_drawing(world, creature, board: Dictionary) -> Dictionary:
	var rng = creature.mind.rng if creature.mind != null else world.rng
	var board_target := str(board.get("reference_shape", ""))
	if board_target in KNOWN_SHAPES and policy_mode != "random" and not has_observed(board_target):
		active.clear()
		return {"completed": false, "reproduced": false, "reason": "unobserved"}
	if active.is_empty() or int(active.get("board_id", 0)) != int(board.id) or str(active.get("status", "")) != "active" or str(active.get("target_shape", "")) != board_target:
		if not start_session(board, world.tick, rng):
			return {"completed": false, "reproduced": false, "reason": "unobserved"}
	var target_shape := str(active.target_shape)
	var is_known_shape := target_shape in KNOWN_SHAPES
	var virtual_pos := Data.unpack_vector(active.virtual_pos)
	for _s in range(MAX_STEPS_PER_TICK):
		var idx := int(active.step_index)
		if idx >= int(active.total_segments):
			break
		var a_dir := 0
		var a_len := 1
		if idx < active.trace.size():
			var planned_step: Dictionary = active.trace[idx]
			a_dir = int(planned_step.get("a_dir", 0))
			a_len = int(planned_step.get("a_len", 1))
		else:
			a_dir = clampi(int(rng.between(0.0, float(DIRECTIONS))), 0, DIRECTIONS - 1)
			a_len = clampi(int(rng.between(0.0, float(LENGTHS.size()))), 0, LENGTHS.size() - 1)
			active.trace.append({
				"s_dir": a_dir,
				"s_mag": a_len,
				"a_dir": a_dir,
				"a_len": a_len,
				"r_step": 0.0
			})
		var step_px := float(LENGTHS[clampi(a_len, 0, LENGTHS.size() - 1)])
		var virtual_next := (virtual_pos + Vector2.from_angle(float(a_dir) * TAU / float(DIRECTIONS)) * step_px).clamp(Vector2.ZERO, Vector2.ONE * CANVAS_SIZE)
		virtual_pos = Vector2(snappedf(virtual_next.x, 0.000001), snappedf(virtual_next.y, 0.000001))
		active.actions.append({"op": "segment", "dir": a_dir, "len": a_len})
		active.step_index = idx + 1
	active.virtual_pos = Data.pack_vector(virtual_pos)
	var live := execute_actions(active.actions)
	board["active_actions"] = active.actions.duplicate(true)
	board["active_strokes"] = live.strokes
	board["owner_id"] = creature.id
	board["updated_tick"] = world.tick
	if int(active.step_index) < int(active.total_segments):
		return {"completed": false, "reproduced": true}
	active.actions.append({"op": "pen_up", "dir": 0, "len": 0})
	var executed := execute_actions(active.actions)
	board["active_actions"] = active.actions.duplicate(true)
	board["active_strokes"] = executed.strokes
	var has_board_ref: bool = is_known_shape and not board.get("reference_strokes", []).is_empty() and board.reference_strokes[0].size() >= 2
	var eval_ref_strokes: Array = []
	if has_board_ref:
		eval_ref_strokes = board.reference_strokes
	var has_eval_ref := is_known_shape and not eval_ref_strokes.is_empty()
	var error := chamfer_distance(executed.strokes, eval_ref_strokes) if has_eval_ref else (1.0 if is_known_shape else 0.0)
	var prev_err := float(last_error.get(target_shape, 0.48))
	var error_reduction := snappedf(prev_err - error, 0.000001) if has_eval_ref else 0.0
	if has_eval_ref:
		last_error[target_shape] = error
	var applied_updates := apply_feedback(target_shape, error, error_reduction) if has_board_ref else 0
	var shape_key := target_shape if is_known_shape else "rabisco"
	var label: String = Textos.texto("shape_" + shape_key)
	var art_id: int = world.ids.take()
	var title := Textos.texto("m3_artifact_title", [label, int(active.id), creature.name]).left(64)
	var artifact := {
		"id": art_id,
		"title": title,
		"created_tick": world.tick,
		"owner_id": creature.id,
		"owner_name": creature.name.left(64),
		"board_id": int(board.id),
		"target_shape": shape_key,
		"actions": active.actions.duplicate(true),
		"strokes": executed.strokes,
		"stroke3": executed.stroke3,
		"error": error
	}
	board.artifacts.append(artifact.duplicate(true))
	while board.artifacts.size() > BOARD_ARTIFACT_LIMIT:
		board.artifacts.pop_front()
	world.gallery.append(artifact.duplicate(true))
	while world.gallery.size() > GALLERY_LIMIT:
		world.gallery.pop_front()
	artifacts.append(artifact.duplicate(true))
	while artifacts.size() > BOARD_ARTIFACT_LIMIT:
		artifacts.pop_front()
	var attempt := {
		"id": int(active.id),
		"tick": world.tick,
		"board_id": int(board.id),
		"shape": shape_key,
		"error": error,
		"error_reduction": error_reduction,
		"success": has_eval_ref and error < SUCCESS_THRESHOLD,
		"steps": int(active.step_index),
		"actions_count": active.actions.size(),
		"updates": applied_updates
	}
	attempts.append(attempt)
	while attempts.size() > ATTEMPT_LIMIT:
		attempts.pop_front()
	active["status"] = "completed"
	return {"completed": true, "reproduced": true, "artifact": artifact, "attempt": attempt}

func shape_competence(shape: String) -> Dictionary:
	var subset: Array = []
	for row in attempts:
		if str(row.shape) == shape:
			subset.append(row)
	if subset.is_empty():
		return {"shape": shape, "attempts": 0, "successes": 0, "success_rate": 0.0, "best_error": 1.0, "median_error": 1.0, "last_error": 1.0, "learned": false, "observed": has_observed(shape)}
	var successes := 0
	var errors: Array = []
	var best := 1.0
	for row in subset:
		var e := float(row.error)
		errors.append(e)
		if e < best:
			best = e
		if bool(row.success):
			successes += 1
	errors.sort()
	var mid := errors.size() / 2
	var median := float(errors[mid]) if errors.size() % 2 == 1 else snappedf(0.5 * (float(errors[mid - 1]) + float(errors[mid])), 0.000001)
	var rate := snappedf(float(successes) / float(subset.size()), 0.000001)
	var recent_ok := float(subset.back().error) < SUCCESS_THRESHOLD
	return {
		"shape": shape,
		"attempts": subset.size(),
		"successes": successes,
		"success_rate": rate,
		"best_error": snappedf(best, 0.000001),
		"median_error": snappedf(median, 0.000001),
		"last_error": snappedf(float(subset.back().error), 0.000001),
		"learned": subset.size() >= 3 and (rate >= 0.5 or recent_ok),
		"observed": has_observed(shape)
	}

func snapshot() -> Dictionary:
	var comp: Dictionary = {}
	for shape in KNOWN_SHAPES:
		comp[shape] = shape_competence(shape)
	var current := active.duplicate(true)
	current.erase("trace")
	return {
		"enabled": true,
		"learning": learning,
		"policy_mode": policy_mode,
		"observation_enabled": observation_enabled,
		"updates": updates,
		"competence": comp,
		"shape_memory": shape_memory.duplicate(true),
		"attempts": attempts.duplicate(true),
		"historico_tentativas": attempts.duplicate(true),
		"artifacts": artifacts.duplicate(true),
		"active": current,
		"policy_summary": {
			"decoder_params": decoder_params.duplicate(),
			"best_params": best_params.duplicate(),
			"offset_weights": offset_weights.duplicate(),
			"dir_weights": dir_weights.duplicate(),
			"len_weights": len_weights.duplicate()
		}
	}

static func empty_snapshot() -> Dictionary:
	var comp: Dictionary = {}
	for shape in KNOWN_SHAPES:
		comp[shape] = {"shape": shape, "attempts": 0, "successes": 0, "success_rate": 0.0, "best_error": 1.0, "median_error": 1.0, "last_error": 1.0, "learned": false, "observed": false}
	return {
		"enabled": false,
		"learning": false,
		"policy_mode": "naive",
		"observation_enabled": true,
		"updates": 0,
		"competence": comp,
		"shape_memory": {},
		"attempts": [],
		"historico_tentativas": [],
		"artifacts": [],
		"active": {},
		"policy_summary": {"decoder_params": [], "best_params": [], "offset_weights": [], "dir_weights": [], "len_weights": []}
	}

func to_dict() -> Dictionary:
	return Data.restore_precision({
		"version": version,
		"next_id": next_id,
		"learning": learning,
		"policy_mode": policy_mode,
		"observation_enabled": observation_enabled,
		"updates": updates,
		"decoder_params": decoder_params,
		"best_params": best_params,
		"search_dirs": search_dirs,
		"step_sizes": step_sizes,
		"active_probe_axis": active_probe_axis,
		"probe_shape": probe_shape,
		"best_error": best_error,
		"shape_memory": shape_memory,
		"offset_weights": offset_weights,
		"dir_weights": dir_weights,
		"len_weights": len_weights,
		"last_error": last_error,
		"attempts": attempts,
		"artifacts": artifacts,
		"active": active
	})

static func valid_action(act: Variant) -> bool:
	if not act is Dictionary or act.size() != 3:
		return false
	if act.get("op") not in OPS:
		return false
	if not Data.integer(act.get("dir")) or int(act["dir"]) >= DIRECTIONS:
		return false
	if not Data.integer(act.get("len")) or int(act["len"]) >= LENGTHS.size():
		return false
	return true

static func valid_strokes(strokes: Variant) -> bool:
	if not strokes is Array or strokes.size() > MAX_STROKES_PER_DRAWING:
		return false
	var total_pts := 0
	for stroke in strokes:
		if not stroke is Array or stroke.size() < 2 or stroke.size() > MAX_POINTS_PER_STROKE:
			return false
		for pt in stroke:
			if not Data.vector(pt):
				return false
			var v := Data.unpack_vector(pt)
			if v.x < -0.001 or v.y < -0.001 or v.x > CANVAS_SIZE + 0.001 or v.y > CANVAS_SIZE + 0.001:
				return false
			total_pts += 1
	return total_pts <= MAX_POINTS_PER_DRAWING

static func valid_stroke3(stroke3: Variant) -> bool:
	if not stroke3 is Array or stroke3.size() > MAX_ACTIONS_PER_DRAWING:
		return false
	for item in stroke3:
		if not item is Array or item.size() != 3 or not Data.number(item[0]) or not Data.number(item[1]) or not Data.integer(item[2]):
			return false
		if absf(float(item[0])) > CANVAS_SIZE or absf(float(item[1])) > CANVAS_SIZE or int(item[2]) not in [0, 1]:
			return false
	return true

static func valid_shape_memory(mem_dict: Variant, max_tick: int) -> bool:
	if not mem_dict is Dictionary or mem_dict.size() > MEMORY_SLOT_LIMIT:
		return false
	for shape_key in mem_dict:
		if not shape_key is String or shape_key not in KNOWN_SHAPES:
			return false
		var entry: Variant = mem_dict[shape_key]
		if not entry is Dictionary or entry.size() != 7:
			return false
		if not Data.integer(entry.get("anchor_dir")) or int(entry["anchor_dir"]) >= DIRECTIONS:
			return false
		if not Data.integer(entry.get("observations"), 1) or int(entry["observations"]) > 64:
			return false
		if not Data.integer(entry.get("last_tick")) or int(entry["last_tick"]) > max_tick:
			return false
		var rt: Variant = entry.get("rel_turns")
		var rl: Variant = entry.get("rel_lens")
		var tr: Variant = entry.get("turn_rads")
		var s3: Variant = entry.get("stroke3")
		if not rt is Array or not rl is Array or not tr is Array or not s3 is Array:
			return false
		var seg_n: int = rt.size()
		if seg_n < 1 or seg_n > MAX_MEMORY_SEGMENTS or rl.size() != seg_n or tr.size() != seg_n or s3.size() != seg_n:
			return false
		for i in range(seg_n):
			if not Data.integer(rt[i], -8) or int(rt[i]) > 8:
				return false
			if not Data.integer(rl[i]) or int(rl[i]) >= LENGTHS.size():
				return false
			if not Data.number(tr[i]) or absf(float(tr[i])) > PI + 0.01:
				return false
		if not valid_stroke3(s3):
			return false
	return true

static func valid_artifact(art: Variant, max_tick: int, next_world_id: int) -> bool:
	if not art is Dictionary or art.size() != 11:
		return false
	if not Data.integer(art.get("id"), 1) or int(art["id"]) >= next_world_id:
		return false
	if not art.get("title") is String or art["title"].is_empty() or art["title"].length() > 64:
		return false
	if not Data.integer(art.get("created_tick")) or int(art["created_tick"]) > max_tick:
		return false
	if not Data.integer(art.get("owner_id"), 1) or int(art["owner_id"]) >= next_world_id:
		return false
	if not art.get("owner_name") is String or art["owner_name"].length() > 64:
		return false
	if not Data.integer(art.get("board_id"), 1) or int(art["board_id"]) >= next_world_id:
		return false
	if art.get("target_shape") not in ALL_SHAPES:
		return false
	if not art.get("actions") is Array or art["actions"].is_empty() or art["actions"].size() > MAX_ACTIONS_PER_DRAWING:
		return false
	for act in art["actions"]:
		if not valid_action(act):
			return false
	if not valid_strokes(art.get("strokes")) or art["strokes"].is_empty() or not valid_stroke3(art.get("stroke3")):
		return false
	if not Data.number(art.get("error")) or float(art["error"]) < 0.0 or float(art["error"]) > 1.0:
		return false
	# Verify that strokes and stroke3 strictly derive from executing primitive actions.
	var replayed := execute_actions(art["actions"])
	if Data.restore_precision(replayed.strokes) != Data.restore_precision(art["strokes"]):
		return false
	if Data.restore_precision(replayed.stroke3) != Data.restore_precision(art["stroke3"]):
		return false
	return true

static func valid_board(b: Variant, max_tick: int, next_world_id: int) -> bool:
	if not b is Dictionary or b.size() != 10:
		return false
	if not Data.integer(b.get("id"), 1) or int(b["id"]) >= next_world_id or not Data.vector(b.get("pos")):
		return false
	var ref_shape = b.get("reference_shape")
	if not ref_shape is String or ref_shape not in KNOWN_SHAPES + [""]:
		return false
	var ref_params = b.get("reference_params")
	if not ref_params is Dictionary:
		return false
	if ref_shape == "":
		if not ref_params.is_empty() or not b.get("reference_strokes") is Array or not b["reference_strokes"].is_empty():
			return false
	else:
		var strokes_val = b.get("reference_strokes")
		if not strokes_val is Array:
			return false
		if ref_params.is_empty() and strokes_val.is_empty():
			pass # Cleared demonstration after observation for memory-only reproduction
		else:
			if ref_params.size() != 3 or not Data.vector(ref_params.get("center")) or not Data.number(ref_params.get("scale")) or float(ref_params["scale"]) < 0.4 or float(ref_params["scale"]) > 1.7 or not Data.integer(ref_params.get("dir_offset")) or int(ref_params["dir_offset"]) >= DIRECTIONS:
				return false
			if not valid_strokes(strokes_val) or strokes_val.is_empty():
				return false
			if Data.restore_precision(strokes_val) != Data.restore_precision(build_reference_strokes(ref_shape, ref_params)):
				return false
	if not b.get("active_actions") is Array or b["active_actions"].size() > MAX_ACTIONS_PER_DRAWING:
		return false
	for act in b["active_actions"]:
		if not valid_action(act):
			return false
	if not valid_strokes(b.get("active_strokes")):
		return false
	if not b["active_actions"].is_empty():
		var replayed := execute_actions(b["active_actions"])
		if Data.restore_precision(replayed.strokes) != Data.restore_precision(b["active_strokes"]):
			return false
	elif not b["active_strokes"].is_empty():
		return false
	if not Data.integer(b.get("owner_id")) or int(b["owner_id"]) >= next_world_id:
		return false
	if not Data.integer(b.get("updated_tick")) or int(b["updated_tick"]) > max_tick:
		return false
	if not b.get("artifacts") is Array or b["artifacts"].size() > BOARD_ARTIFACT_LIMIT:
		return false
	if not unique_artifacts(b["artifacts"]): return false
	for art in b["artifacts"]:
		if not valid_artifact(art, max_tick, next_world_id) or int(art["board_id"]) != int(b["id"]):
			return false
	return true

static func unique_artifacts(collection: Array) -> bool:
	var seen := {}
	for art in collection:
		if not art is Dictionary or not Data.integer(art.get("id"), 1) or seen.has(int(art.id)):
			return false
		seen[int(art.id)] = true
	return true

static func valid_active(act: Variant, max_tick: int, next_attempt_id: int, next_world_id: int) -> bool:
	if not act is Dictionary:
		return false
	if act.is_empty():
		return true
	if act.size() != 10:
		return false
	if not Data.integer(act.get("id"), 1) or int(act["id"]) >= next_attempt_id:
		return false
	if not Data.integer(act.get("board_id"), 1) or int(act["board_id"]) >= next_world_id:
		return false
	if act.get("target_shape") not in KNOWN_SHAPES + [""]:
		return false
	if not Data.integer(act.get("start_tick")) or int(act["start_tick"]) > max_tick:
		return false
	if not Data.integer(act.get("total_segments"), 1) or int(act["total_segments"]) != MAX_MEMORY_SEGMENTS:
		return false
	if not Data.integer(act.get("step_index")) or int(act["step_index"]) > int(act["total_segments"]):
		return false
	if act.get("status") not in ["active", "completed"]:
		return false
	if not Data.vector(act.get("virtual_pos")):
		return false
	if not act.get("actions") is Array or act["actions"].is_empty() or act["actions"].size() > MAX_ACTIONS_PER_DRAWING:
		return false
	for item in act["actions"]:
		if not valid_action(item):
			return false
	var done: bool = act["status"] == "completed"
	var step_index: int = int(act["step_index"])
	if (done and step_index != int(act["total_segments"])) or (not done and step_index >= int(act["total_segments"])):
		return false
	if act["actions"].size() != 2 + step_index + (1 if done else 0): return false
	if act["actions"][0].op != "move_pen" or act["actions"][1].op != "pen_down": return false
	for i in range(step_index):
		if act["actions"][i + 2].op != "segment": return false
	if done and act["actions"].back().op != "pen_up": return false
	if not act.get("trace") is Array or act["trace"].size() > int(act["total_segments"]):
		return false
	for step in act["trace"]:
		if not step is Dictionary or step.size() != 5:
			return false
		if not Data.integer(step.get("s_dir")) or int(step["s_dir"]) >= DIRECTIONS or not Data.integer(step.get("a_dir")) or int(step["a_dir"]) >= DIRECTIONS:
			return false
		if not Data.integer(step.get("s_mag")) or int(step["s_mag"]) >= MAG_BUCKETS or not Data.integer(step.get("a_len")) or int(step["a_len"]) >= LENGTHS.size():
			return false
		if not Data.number(step.get("r_step")) or absf(float(step["r_step"])) > 1.0:
			return false
	return true

static func migrate_v1(data: Variant) -> Dictionary:
	if not data is Dictionary or not Data.json_data(data):
		return {}
	if not Data.integer(data.get("version"), 1):
		return {}
	if int(data.get("version", 0)) == VERSION and data.size() == 21:
		return data.duplicate(true)
	if int(data.get("version", 0)) != 1 or data.size() != 12:
		return {}
	if not Data.integer(data.get("next_id"), 1) or not data.get("learning") is bool or data.get("policy_mode") not in ["trained", "naive", "random", "frozen"] or not Data.integer(data.get("updates")):
		return {}
	if not data.get("offset_weights") is Array or data["offset_weights"].size() != DIRECTIONS:
		return {}
	for v in data["offset_weights"]:
		if not Data.number(v) or absf(float(v)) > 1.0:
			return {}
	if not data.get("dir_weights") is Array or data["dir_weights"].size() != DIRECTIONS * DIRECTIONS:
		return {}
	for v in data["dir_weights"]:
		if not Data.number(v) or absf(float(v)) > 1.0:
			return {}
	if not data.get("len_weights") is Array or data["len_weights"].size() != MAG_BUCKETS * LENGTHS.size():
		return {}
	for v in data["len_weights"]:
		if not Data.number(v) or absf(float(v)) > 1.0:
			return {}
	if not data.get("last_error") is Dictionary:
		return {}
	if not valid_active(data.get("active"), 2147483647, int(data.next_id), 2147483647):
		return {}
	var migrated: Dictionary = data.duplicate(true)
	migrated["version"] = VERSION
	migrated["observation_enabled"] = true
	# X4 calibrated a different actuator: never invent X5 motor experience.
	var init_p := INITIAL_DECODER_PARAMS.duplicate()
	migrated["decoder_params"] = init_p.duplicate()
	migrated["best_params"] = init_p.duplicate()
	migrated["search_dirs"] = INITIAL_SEARCH_DIRS.duplicate()
	migrated["step_sizes"] = INITIAL_STEP_SIZES.duplicate()
	migrated["active_probe_axis"] = -1
	migrated["probe_shape"] = ""
	migrated["best_error"] = {}
	migrated["shape_memory"] = {}
	# A live X4 servo session cannot resume as an X5 memory plan.
	migrated["active"] = {}
	return migrated

static func from_dict(data: Variant, max_tick: int = 2147483647, next_world_id: int = 2147483647):
	if not data is Dictionary or not Data.json_data(data):
		return null
	if not Data.integer(data.get("version"), 1):
		return null
	if data.size() != 21:
		return null
	if not Data.integer(data.get("version"), 1) or int(data["version"]) != VERSION or not Data.integer(data.get("next_id"), 1):
		return null
	if not data.get("learning") is bool or not data.get("observation_enabled") is bool or data.get("policy_mode") not in POLICY_MODES or not Data.integer(data.get("updates")):
		return null
	for p_field in ["decoder_params", "best_params"]:
		var arr: Variant = data.get(p_field)
		if not arr is Array or arr.size() != 3:
			return null
		for idx in range(3):
			if not Data.number(arr[idx]):
				return null
			var val := float(arr[idx])
			if idx < 2 and absf(val) > 1.0:
				return null
			if idx == 2 and (val < 0.0 or val > 1.0):
				return null
	var s_dirs: Variant = data.get("search_dirs")
	if not s_dirs is Array or s_dirs.size() != 3:
		return null
	for d_val in s_dirs:
		if not Data.number(d_val) or absf(float(d_val)) > 1.0 or float(d_val) == 0.0:
			return null
	var s_sizes: Variant = data.get("step_sizes")
	if not s_sizes is Array or s_sizes.size() != 3:
		return null
	for sz_val in s_sizes:
		if not Data.number(sz_val) or float(sz_val) <= 0.0 or float(sz_val) > 1.0:
			return null
	if not Data.integer(data.get("active_probe_axis"), -1) or int(data["active_probe_axis"]) > 2:
		return null
	if not data.get("probe_shape") is String or data["probe_shape"] not in KNOWN_SHAPES + [""]:
		return null
	if not valid_shape_memory(data.get("shape_memory"), max_tick):
		return null
	if not data.get("offset_weights") is Array or data["offset_weights"].size() != DIRECTIONS:
		return null
	for v in data["offset_weights"]:
		if not Data.number(v) or absf(float(v)) > 1.0:
			return null
	if not data.get("dir_weights") is Array or data["dir_weights"].size() != DIRECTIONS * DIRECTIONS:
		return null
	for v in data["dir_weights"]:
		if not Data.number(v) or absf(float(v)) > 1.0:
			return null
	if not data.get("len_weights") is Array or data["len_weights"].size() != MAG_BUCKETS * LENGTHS.size():
		return null
	for v in data["len_weights"]:
		if not Data.number(v) or absf(float(v)) > 1.0:
			return null
	for err_field in ["last_error", "best_error"]:
		var err_dict: Variant = data.get(err_field)
		if not err_dict is Dictionary or err_dict.size() > KNOWN_SHAPES.size():
			return null
		for k in err_dict:
			if k not in KNOWN_SHAPES or not Data.number(err_dict[k]) or float(err_dict[k]) < 0.0 or float(err_dict[k]) > 1.0:
				return null
	if not data.get("attempts") is Array or data["attempts"].size() > ATTEMPT_LIMIT:
		return null
	var prev_id := 0
	for row in data["attempts"]:
		if not row is Dictionary or row.size() != 10:
			return null
		if not Data.integer(row.get("id"), 1) or int(row["id"]) <= prev_id or int(row["id"]) >= int(data["next_id"]):
			return null
		prev_id = int(row["id"])
		if not Data.integer(row.get("tick")) or int(row["tick"]) > max_tick or not Data.integer(row.get("board_id"), 1) or int(row["board_id"]) >= next_world_id:
			return null
		if row.get("shape") not in ALL_SHAPES or not row.get("success") is bool:
			return null
		if not Data.number(row.get("error")) or float(row["error"]) < 0.0 or float(row["error"]) > 1.0 or not Data.number(row.get("error_reduction")) or absf(float(row["error_reduction"])) > 1.0:
			return null
		if not Data.integer(row.get("steps"), 1) or int(row["steps"]) > MAX_ACTIONS_PER_DRAWING or not Data.integer(row.get("actions_count"), 1) or int(row["actions_count"]) > MAX_ACTIONS_PER_DRAWING or not Data.integer(row.get("updates")) or int(row["updates"]) > MAX_ACTIONS_PER_DRAWING:
			return null
	if not data.get("artifacts") is Array or data["artifacts"].size() > BOARD_ARTIFACT_LIMIT:
		return null
	if not unique_artifacts(data["artifacts"]): return null
	for art in data["artifacts"]:
		if not valid_artifact(art, max_tick, next_world_id):
			return null
	if not valid_active(data.get("active"), max_tick, int(data["next_id"]), next_world_id):
		return null
	var result = load("res://scripts/atelier/atelier.gd").new()
	result.version = int(data["version"])
	result.next_id = int(data["next_id"])
	result.learning = bool(data["learning"])
	result.policy_mode = str(data["policy_mode"])
	result.observation_enabled = bool(data["observation_enabled"])
	result.updates = int(data["updates"])
	result.decoder_params = Data.restore_precision(data["decoder_params"])
	result.best_params = Data.restore_precision(data["best_params"])
	result.search_dirs = Data.restore_precision(data["search_dirs"])
	result.step_sizes = Data.restore_precision(data["step_sizes"])
	result.active_probe_axis = int(data["active_probe_axis"])
	result.probe_shape = str(data["probe_shape"])
	result.best_error = Data.restore_precision(data["best_error"])
	result.shape_memory = Data.restore_precision(data["shape_memory"])
	result.offset_weights = Data.restore_precision(data["offset_weights"])
	result.dir_weights = Data.restore_precision(data["dir_weights"])
	result.len_weights = Data.restore_precision(data["len_weights"])
	result.last_error = Data.restore_precision(data["last_error"])
	result.attempts = Data.restore_precision(data["attempts"])
	result.artifacts = Data.restore_precision(data["artifacts"])
	result.active = Data.restore_precision(data["active"])
	return result
