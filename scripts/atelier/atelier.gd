extends RefCounted
## Bounded per-creature atelier competence and board drawing primitives (E3.5).
## Every drawing is generated strictly by executing discrete primitive actions
## (move_pen, pen_down, pen_up, segment); never from pre-made or random images.
## Learning uses tabular hill-climbing over discrete direction and length
## conditioned on normalized residual error; reward is error reduction only,
## never adding physical energy or hydration.

const Data = preload("res://scripts/core/sim_data.gd")
const ObjectMemory = preload("res://scripts/mind/object_memory.gd")

const VERSION := 1
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
const SHAPES := ["linha", "circulo", "quadrado"]
const ALL_SHAPES := ["linha", "circulo", "quadrado", "rabisco"]
const SUCCESS_THRESHOLD := 0.22
const DRAW_COOLDOWN := 90
const DRAW_ENERGY_COST := 0.012
const SAMPLES_PER_SEGMENT := 4

var version: int = VERSION
var next_id: int = 1
var learning: bool = true
var policy_mode: String = "trained" # "trained", "naive", "random", "frozen"
var updates: int = 0
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
	offset_weights.resize(DIRECTIONS)
	offset_weights.fill(0.0)
	dir_weights.resize(DIRECTIONS * DIRECTIONS)
	dir_weights.fill(0.0)
	len_weights.resize(MAG_BUCKETS * LENGTHS.size())
	len_weights.fill(0.0)
	last_error.clear()

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
	return dirs

static func build_reference_strokes(shape: String, params: Dictionary = {}) -> Array:
	if shape not in SHAPES:
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
	if forma not in SHAPES:
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

static func residual_state(err_vec: Vector2, ref_step: float) -> Dictionary:
	var angle := wrapf(err_vec.angle(), 0.0, TAU)
	var s_dir := int(round(angle / (TAU / float(DIRECTIONS)))) % DIRECTIONS
	var ratio := err_vec.length() / maxf(1.0, ref_step)
	var s_mag := 0 if ratio < 0.75 else (1 if ratio < 1.35 else 2)
	return {"s_dir": s_dir, "s_mag": s_mag}

static func _uncalibrated_dir(s_dir: int) -> int:
	return (int(s_dir / 2) + 5) % DIRECTIONS

static func _uncalibrated_len(s_mag: int) -> int:
	return (s_mag + 1) % LENGTHS.size()

func choose_action(s_dir: int, s_mag: int, rng) -> Dictionary:
	if policy_mode == "random":
		return {
			"dir": clampi(int(rng.between(0.0, float(DIRECTIONS))), 0, DIRECTIONS - 1),
			"len": clampi(int(rng.between(0.0, float(LENGTHS.size()))), 0, LENGTHS.size() - 1)
		}
	if policy_mode == "naive" or (not learning and updates == 0):
		return {
			"dir": _uncalibrated_dir(s_dir),
			"len": _uncalibrated_len(s_mag)
		}
	var base_dir := _uncalibrated_dir(s_dir)
	var best_dir := base_dir
	var best_score := -INF
	for cand_dir in range(DIRECTIONS):
		var delta_dir := (cand_dir - s_dir + DIRECTIONS) % DIRECTIONS
		var ang_dist := absi(((cand_dir - base_dir + 8 + DIRECTIONS) % DIRECTIONS) - 8)
		var prior := 0.08 - 0.015 * float(ang_dist)
		var score := prior + 0.65 * float(offset_weights[delta_dir]) + 0.35 * float(dir_weights[s_dir * DIRECTIONS + cand_dir])
		if score > best_score:
			best_score = score
			best_dir = cand_dir
	var base_len := _uncalibrated_len(s_mag)
	var best_len := base_len
	var best_len_score := -INF
	for cand_len in range(LENGTHS.size()):
		var prior_len := 0.06 - 0.025 * float(absi(cand_len - base_len))
		var lscore := prior_len + float(len_weights[s_mag * LENGTHS.size() + cand_len])
		if lscore > best_len_score:
			best_len_score = lscore
			best_len = cand_len
	return {"dir": best_dir, "len": best_len}

func apply_feedback(trace: Array, error: float, error_reduction: float) -> int:
	if not learning or policy_mode in ["random", "naive", "frozen"]:
		return 0
	var count := 0
	var chamfer_term := clampf(error_reduction + (SUCCESS_THRESHOLD - error), -0.5, 0.5)
	for row in trace:
		var s_dir := int(row.s_dir)
		var s_mag := int(row.s_mag)
		var a_dir := int(row.a_dir)
		var a_len := int(row.a_len)
		var r_step := float(row.r_step)
		var delta_dir := (a_dir - s_dir + DIRECTIONS) % DIRECTIONS
		var signal_dir := clampf(0.75 * r_step + 0.25 * chamfer_term, -1.0, 1.0)
		var d_idx := s_dir * DIRECTIONS + a_dir
		dir_weights[d_idx] = snappedf(clampf(lerpf(float(dir_weights[d_idx]), signal_dir, 0.32), -1.0, 1.0), 0.000001)
		offset_weights[delta_dir] = snappedf(clampf(lerpf(float(offset_weights[delta_dir]), signal_dir, 0.16), -1.0, 1.0), 0.000001)
		var signed_diff := ((s_dir - a_dir + 8 + DIRECTIONS) % DIRECTIONS) - 8
		if signed_diff != 0:
			dir_weights[d_idx] = snappedf(clampf(float(dir_weights[d_idx]) - 0.08, -1.0, 1.0), 0.000001)
			offset_weights[delta_dir] = snappedf(clampf(float(offset_weights[delta_dir]) - 0.055, -1.0, 1.0), 0.000001)
			var step_sign := 1 if signed_diff > 0 else -1
			var adj_dir := (a_dir + step_sign + DIRECTIONS) % DIRECTIONS
			var adj_delta := (adj_dir - s_dir + DIRECTIONS) % DIRECTIONS
			var adj_idx := s_dir * DIRECTIONS + adj_dir
			dir_weights[adj_idx] = snappedf(clampf(float(dir_weights[adj_idx]) + 0.115, -1.0, 1.0), 0.000001)
			offset_weights[adj_delta] = snappedf(clampf(float(offset_weights[adj_delta]) + 0.065, -1.0, 1.0), 0.000001)
		var len_err := absf(float(a_len - s_mag))
		var len_reward := clampf(0.6 * r_step + (0.45 if len_err == 0.0 else (-0.35 * len_err)), -1.0, 1.0)
		var l_idx := s_mag * LENGTHS.size() + a_len
		len_weights[l_idx] = snappedf(clampf(lerpf(float(len_weights[l_idx]), len_reward, 0.30), -1.0, 1.0), 0.000001)
		if a_len != s_mag:
			var adj_len := a_len + (1 if s_mag > a_len else -1)
			var adj_l_idx := s_mag * LENGTHS.size() + adj_len
			len_weights[adj_l_idx] = snappedf(clampf(float(len_weights[adj_l_idx]) + 0.11, -1.0, 1.0), 0.000001)
		count += 1
	updates += count
	return count

func start_session(board: Dictionary, tick: int, rng) -> void:
	var target_shape := str(board.get("reference_shape", ""))
	var start_dir := clampi(int(rng.between(0.0, float(DIRECTIONS))), 0, DIRECTIONS - 1)
	var start_len := 0
	var start_virtual := Vector2(CANVAS_SIZE * 0.5, CANVAS_SIZE * 0.5)
	if target_shape in SHAPES and not board.get("reference_strokes", []).is_empty():
		var ref_stroke: Array = board.reference_strokes[0]
		if not ref_stroke.is_empty():
			start_virtual = Data.unpack_vector(ref_stroke[0])
	active = {
		"id": next_id,
		"board_id": int(board.id),
		"target_shape": target_shape,
		"start_tick": tick,
		"step_index": 0,
		"total_segments": 8,
		"status": "active",
		"actions": [
			{"op": "move_pen", "dir": start_dir, "len": start_len},
			{"op": "pen_down", "dir": 0, "len": 0}
		],
		"trace": [],
		"virtual_pos": Data.pack_vector(start_virtual)
	}
	next_id += 1

func step_drawing(world, creature, board: Dictionary) -> Dictionary:
	var rng = creature.mind.rng if creature.mind != null else world.rng
	if active.is_empty() or int(active.get("board_id", 0)) != int(board.id) or str(active.get("status", "")) != "active":
		start_session(board, world.tick, rng)
	var target_shape := str(active.target_shape)
	var has_ref: bool = target_shape in SHAPES and not board.get("reference_strokes", []).is_empty() and board.reference_strokes[0].size() >= 9
	var ref_stroke: Array = board.reference_strokes[0] if has_ref else []
	var ref_step := float(LENGTHS[1])
	if has_ref:
		var total_len := 0.0
		for i in range(8):
			total_len += Data.unpack_vector(ref_stroke[i]).distance_to(Data.unpack_vector(ref_stroke[i + 1]))
		ref_step = maxf(1.0, total_len / 8.0)
	var virtual_pos := Data.unpack_vector(active.virtual_pos)
	for s in range(MAX_STEPS_PER_TICK):
		var idx := int(active.step_index)
		if idx >= int(active.total_segments):
			break
		var a_dir := 0
		var a_len := 1
		if has_ref:
			var target_pt := Data.unpack_vector(ref_stroke[idx + 1])
			var err_vec := target_pt - virtual_pos
			var state := residual_state(err_vec, ref_step)
			var chosen := choose_action(int(state.s_dir), int(state.s_mag), rng)
			a_dir = int(chosen.dir)
			a_len = int(chosen.len)
			var step_scale := float(LENGTHS[a_len]) / float(LENGTHS[1])
			var virtual_next := virtual_pos + Vector2.from_angle(float(a_dir) * TAU / float(DIRECTIONS)) * (ref_step * step_scale)
			var err_before := err_vec.length()
			var err_after := target_pt.distance_to(virtual_next)
			var r_step := clampf((err_before - err_after) / maxf(1.0, err_before), -1.0, 1.0)
			active.trace.append({
				"s_dir": int(state.s_dir),
				"s_mag": int(state.s_mag),
				"a_dir": a_dir,
				"a_len": a_len,
				"r_step": snappedf(r_step, 0.000001)
			})
			virtual_pos = Vector2(snappedf(virtual_next.x, 0.000001), snappedf(virtual_next.y, 0.000001))
		else:
			a_dir = clampi(int(rng.between(0.0, float(DIRECTIONS))), 0, DIRECTIONS - 1)
			a_len = clampi(int(rng.between(0.0, float(LENGTHS.size()))), 0, LENGTHS.size() - 1)
		active.actions.append({"op": "segment", "dir": a_dir, "len": a_len})
		active.step_index = idx + 1
	active.virtual_pos = Data.pack_vector(virtual_pos)
	var live := execute_actions(active.actions)
	board["active_actions"] = active.actions.duplicate(true)
	board["active_strokes"] = live.strokes
	board["owner_id"] = creature.id
	board["updated_tick"] = world.tick
	if int(active.step_index) < int(active.total_segments):
		return {"completed": false}
	active.actions.append({"op": "pen_up", "dir": 0, "len": 0})
	var executed := execute_actions(active.actions)
	board["active_actions"] = active.actions.duplicate(true)
	board["active_strokes"] = executed.strokes
	var error := chamfer_distance(executed.strokes, board.reference_strokes) if has_ref else 0.0
	var prev_err := float(last_error.get(target_shape, 0.48))
	var error_reduction := snappedf(prev_err - error, 0.000001) if has_ref else 0.0
	if has_ref:
		last_error[target_shape] = error
	var applied_updates := apply_feedback(active.trace, error, error_reduction) if has_ref else 0
	var shape_key := target_shape if has_ref else "rabisco"
	var label: String = {"linha": "Linha", "circulo": "Círculo", "quadrado": "Quadrado", "rabisco": "Rabisco"}.get(shape_key, "Rabisco")
	var art_id: int = world.ids.take()
	var title := ("%s #%d de %s" % [label, int(active.id), creature.name]).left(64)
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
		"success": has_ref and error < SUCCESS_THRESHOLD,
		"steps": int(active.step_index),
		"actions_count": active.actions.size(),
		"updates": applied_updates
	}
	attempts.append(attempt)
	while attempts.size() > ATTEMPT_LIMIT:
		attempts.pop_front()
	active["status"] = "completed"
	return {"completed": true, "artifact": artifact, "attempt": attempt}

func shape_competence(shape: String) -> Dictionary:
	var subset: Array = []
	for row in attempts:
		if str(row.shape) == shape:
			subset.append(row)
	if subset.is_empty():
		return {"shape": shape, "attempts": 0, "successes": 0, "success_rate": 0.0, "best_error": 1.0, "median_error": 1.0, "last_error": 1.0, "learned": false}
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
		"learned": subset.size() >= 3 and (rate >= 0.5 or recent_ok)
	}

func snapshot() -> Dictionary:
	var comp: Dictionary = {}
	for shape in SHAPES:
		comp[shape] = shape_competence(shape)
	var current := active.duplicate(true)
	current.erase("trace")
	return {
		"enabled": true,
		"learning": learning,
		"policy_mode": policy_mode,
		"updates": updates,
		"competence": comp,
		"attempts": attempts.duplicate(true),
		"historico_tentativas": attempts.duplicate(true),
		"artifacts": artifacts.duplicate(true),
		"active": current,
		"policy_summary": {
			"offset_weights": offset_weights.duplicate(),
			"dir_weights": dir_weights.duplicate(),
			"len_weights": len_weights.duplicate()
		}
	}

static func empty_snapshot() -> Dictionary:
	var comp: Dictionary = {}
	for shape in SHAPES:
		comp[shape] = {"shape": shape, "attempts": 0, "successes": 0, "success_rate": 0.0, "best_error": 1.0, "median_error": 1.0, "last_error": 1.0, "learned": false}
	return {
		"enabled": false,
		"learning": false,
		"policy_mode": "naive",
		"updates": 0,
		"competence": comp,
		"attempts": [],
		"historico_tentativas": [],
		"artifacts": [],
		"active": {},
		"policy_summary": {"offset_weights": [], "dir_weights": [], "len_weights": []}
	}

func to_dict() -> Dictionary:
	return Data.restore_precision({
		"version": version,
		"next_id": next_id,
		"learning": learning,
		"policy_mode": policy_mode,
		"updates": updates,
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
	if not ref_shape is String or ref_shape not in SHAPES + [""]:
		return false
	var ref_params = b.get("reference_params")
	if not ref_params is Dictionary:
		return false
	if ref_shape == "":
		if not ref_params.is_empty() or not b.get("reference_strokes") is Array or not b["reference_strokes"].is_empty():
			return false
	else:
		if ref_params.size() != 3 or not Data.vector(ref_params.get("center")) or not Data.number(ref_params.get("scale")) or float(ref_params["scale"]) < 0.4 or float(ref_params["scale"]) > 1.7 or not Data.integer(ref_params.get("dir_offset")) or int(ref_params["dir_offset"]) >= DIRECTIONS:
			return false
		if not valid_strokes(b.get("reference_strokes")) or b["reference_strokes"].is_empty():
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
	for art in b["artifacts"]:
		if not valid_artifact(art, max_tick, next_world_id) or int(art["board_id"]) != int(b["id"]):
			return false
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
	if act.get("target_shape") not in SHAPES + [""]:
		return false
	if not Data.integer(act.get("start_tick")) or int(act["start_tick"]) > max_tick:
		return false
	if not Data.integer(act.get("total_segments"), 1) or int(act["total_segments"]) > 16:
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

static func from_dict(data: Variant, max_tick: int = 2147483647, next_world_id: int = 2147483647):
	if not data is Dictionary or data.size() != 12 or not Data.json_data(data):
		return null
	if not Data.integer(data.get("version"), 1) or int(data["version"]) != VERSION or not Data.integer(data.get("next_id"), 1):
		return null
	if not data.get("learning") is bool or data.get("policy_mode") not in ["trained", "naive", "random", "frozen"] or not Data.integer(data.get("updates")):
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
	if not data.get("last_error") is Dictionary or data["last_error"].size() > SHAPES.size():
		return null
	for k in data["last_error"]:
		if k not in SHAPES or not Data.number(data["last_error"][k]) or float(data["last_error"][k]) < 0.0 or float(data["last_error"][k]) > 1.0:
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
	result.updates = int(data["updates"])
	result.offset_weights = Data.restore_precision(data["offset_weights"])
	result.dir_weights = Data.restore_precision(data["dir_weights"])
	result.len_weights = Data.restore_precision(data["len_weights"])
	result.last_error = Data.restore_precision(data["last_error"])
	result.attempts = Data.restore_precision(data["attempts"])
	result.artifacts = Data.restore_precision(data["artifacts"])
	result.active = Data.restore_precision(data["active"])
	return result
