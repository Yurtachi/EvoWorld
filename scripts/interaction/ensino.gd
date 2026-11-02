extends RefCounted
## Bounded, data-only teaching state owned by each creature, never by UI.
const Data = preload("res://scripts/core/sim_data.gd")
const Obs = preload("res://scripts/behavior/observation.gd")
const Actions = preload("res://scripts/behavior/actions.gd")
const Text = preload("res://scripts/core/textos.gd")
const LIMIT := 32
const LOG_LIMIT := 64
const TRACE_LIMIT := 256
const RECENT := 20
const LEARNED_THRESHOLD := 0.7
const MIN_ATTEMPTS := 5
var next_id := 1
var sessions: Array = []
var attempts: Array = []
var events: Array = []
var active: Dictionary = {}

func start(skill: String, target: Vector2, tick: int, energy: float, assisted: bool, horizon: int, policy: String) -> void:
	var before: Dictionary = statistics(skill)
	active = {"id": next_id, "skill": skill, "target": Data.pack_vector(target), "start_tick": tick,
		"end_tick": tick, "status": "active", "steps": 0, "assistance": 0, "assisted": assisted,
		"horizon": horizon, "policy": policy, "rewarded": false, "updates": 0,
		"energy_before": energy, "energy_after": energy, "initial_distance": 0.0, "final_distance": 0.0,
		"trace": [], "before_rate": before.success_rate}
	sessions.append({"id": next_id, "skill": skill, "start_tick": tick, "before_rate": before.success_rate})
	next_id += 1
	trim(sessions, LIMIT)
	record(tick, "start", {}, -1, "active", 0)

func running() -> bool:
	return not active.is_empty() and active.status == "active"

func record(tick: int, event: String, observation: Dictionary, action: int, result: String, updates: int) -> void:
	events.append({"tick": tick, "event": event, "observation": observation.duplicate(true),
		"action": action, "result": result, "updates": updates})
	trim(events, LOG_LIMIT)

func step_record(tick: int, observation: Dictionary, action: int, assisted: bool, energy: float) -> void:
	active.steps += 1
	active.end_tick = tick
	active.energy_after = energy
	active.final_distance = observation.distance
	if active.steps == 1:
		active.initial_distance = observation.distance
	if assisted:
		active.assistance += 1
	if observation.visible:
		active.trace.append({"state": observation.state, "action": action})
		trim(active.trace, TRACE_LIMIT)
	record(tick, "assistance" if assisted else "decision", observation, action, "pending", 0)

func finish(tick: int, status: String, energy: float, distance: float) -> void:
	if not running():
		return
	active.status = status
	active.end_tick = tick
	active.energy_after = energy
	active.final_distance = snappedf(distance, 0.000001)
	var row := active.duplicate(true)
	row.erase("trace")
	attempts.append(row)
	trim(attempts, LIMIT)
	record(tick, "outcome", {}, -1, status, 0)

func statistics(skill: String) -> Dictionary:
	var rows: Array = []
	for attempt in attempts:
		if attempt.skill == skill and int(attempt.assistance) == 0 and str(attempt.get("policy", "q")) == "q":
			rows.append(attempt)
	rows = rows.slice(maxi(0, rows.size() - RECENT))
	var successes := 0
	for row in rows:
		if row.status == "success":
			successes += 1
	var rate := float(successes) / maxf(1.0, rows.size())
	var learned := rows.size() >= MIN_ATTEMPTS and rate >= LEARNED_THRESHOLD
	return {"skill": skill, "attempts": rows.size(), "successes": successes, "success_rate": rate,
		"learned": learned, "status": "learned" if learned else "not_learned",
		"text": Text.E3_CATALOGO["learned" if learned else "not_learned"],
		"threshold": LEARNED_THRESHOLD, "minimum_attempts": MIN_ATTEMPTS}

func snapshot() -> Dictionary:
	var skills: Array = []
	for skill in Obs.GOAL_SKILLS:
		skills.append(statistics(skill))
	var current := active.duplicate(true)
	current.erase("trace")
	return {"ok": true, "skills": skills, "sessions": sessions.duplicate(true),
		"attempts": attempts.duplicate(true), "events": events.duplicate(true), "active": current,
		"before_after": {} if active.is_empty() else {"before": active.before_rate,
			"after": statistics(active.skill).success_rate, "skill": active.skill},
		"limits": {"history": LIMIT, "events": LOG_LIMIT, "trace": TRACE_LIMIT}}

func to_dict() -> Dictionary:
	return Data.restore_precision({"version": 1, "next_id": next_id, "sessions": sessions,
		"attempts": attempts, "events": events, "active": active})

static func trim(rows: Array, limit: int) -> void:
	while rows.size() > limit:
		rows.pop_front()

static func valid_attempt(row: Variant, has_trace: bool, max_tick: int, next: int) -> bool:
	if not row is Dictionary or row.size() != (19 if has_trace else 18):
		return false
	if not Data.integer(row.get("id"), 1) or int(row.id) >= next or row.get("skill") not in Obs.GOAL_SKILLS:
		return false
	if not Data.vector(row.get("target")) or row.get("status") not in ["active", "success", "timeout", "cancelled", "death"]:
		return false
	for key in ["start_tick", "end_tick", "steps", "assistance", "updates", "horizon"]:
		if not Data.integer(row.get(key)):
			return false
	if int(row.start_tick) > int(row.end_tick) or int(row.end_tick) > max_tick or int(row.horizon) < 1 or int(row.horizon) > TRACE_LIMIT or int(row.steps) > int(row.horizon) or int(row.assistance) > int(row.steps):
		return false
	if not row.get("assisted") is bool or not row.get("rewarded") is bool or row.get("policy") not in ["q", "heuristica"]:
		return false
	for key in ["energy_before", "energy_after", "initial_distance", "final_distance", "before_rate"]:
		if not Data.number(row.get(key)) or float(row[key]) < 0.0:
			return false
	if float(row.before_rate) > 1.0 or (row.rewarded and row.status != "success") or int(row.updates) > TRACE_LIMIT:
		return false
	if float(row.energy_before) > 10000.0 or float(row.energy_after) > 10000.0 or (int(row.updates) > 0 and not row.rewarded):
		return false
	if has_trace:
		if not row.get("trace") is Array or row.trace.size() > TRACE_LIMIT or row.trace.size() > int(row.steps):
			return false
		for item in row.trace:
			if not item is Dictionary or item.size() != 2 or not Data.integer(item.get("state")) or int(item.state) >= Obs.GOAL_STATE_COUNT or not Data.integer(item.get("action")) or int(item.action) >= Actions.COUNT:
				return false
			if int(item.state) / (13 * 3 * 2) != Obs.GOAL_SKILLS.find(row.skill):
				return false
	return true

static func from_dict(data: Variant, max_tick: int = 2147483647):
	if not data is Dictionary or data.size() != 6 or data.get("version") != 1 or not Data.integer(data.get("next_id"), 1):
		return null
	for key in ["sessions", "attempts", "events"]:
		if not data.get(key) is Array or data[key].size() > (LOG_LIMIT if key == "events" else LIMIT):
			return null
	if not data.get("active") is Dictionary or not Data.json_data(data):
		return null
	var previous_id := 0
	for session in data.sessions:
		if not session is Dictionary or session.size() != 4 or not Data.integer(session.get("id"), 1) or int(session.id) >= int(data.next_id) or session.get("skill") not in Obs.GOAL_SKILLS or not Data.integer(session.get("start_tick")) or int(session.start_tick) > max_tick or not Data.number(session.get("before_rate")) or float(session.before_rate) < 0.0 or float(session.before_rate) > 1.0:
			return null
		if int(session.id) <= previous_id:
			return null
		previous_id = int(session.id)
	previous_id = 0
	for attempt in data.attempts:
		if not valid_attempt(attempt, false, max_tick, int(data.next_id)) or attempt.status == "active":
			return null
		if int(attempt.id) <= previous_id:
			return null
		previous_id = int(attempt.id)
	if not data.active.is_empty() and not valid_attempt(data.active, true, max_tick, int(data.next_id)):
		return null
	if not data.active.is_empty():
		if int(data.active.id) != int(data.next_id) - 1 or data.sessions.is_empty() or int(data.sessions.back().id) != int(data.active.id):
			return null
		if data.active.status != "active":
			var final_row: Dictionary = data.active.duplicate(true)
			final_row.erase("trace")
			if data.attempts.is_empty() or final_row != data.attempts.back():
				return null
	for event in data.events:
		if not event is Dictionary or event.size() != 6 or not Data.integer(event.get("tick")) or int(event.tick) > max_tick or event.get("event") not in ["start", "show", "assistance", "decision", "outcome", "reward", "reward_rejected"] or not event.get("observation") is Dictionary or not Data.integer(event.get("action"), -1) or int(event.action) >= Actions.COUNT or not Data.integer(event.get("updates")) or int(event.updates) > TRACE_LIMIT or event.get("result") not in ["active", "pending", "moved", "drink", "no_movement", "success", "timeout", "cancelled", "death", "not_completed", "already_rewarded", "frozen"]:
			return null
		var obs: Dictionary = event.observation
		if not obs.is_empty():
			if obs.size() != 7 or obs.get("skill") not in Obs.GOAL_SKILLS or not Data.integer(obs.get("state")) or int(obs.state) >= Obs.GOAL_STATE_COUNT or not Data.integer(obs.get("direction_bucket")) or int(obs.direction_bucket) > 12 or not Data.integer(obs.get("distance_bucket")) or int(obs.distance_bucket) > 2 or not Data.number(obs.get("distance")) or float(obs.distance) < 0.0 or not obs.get("visible") is bool or not obs.get("obstacle_ahead") is bool:
				return null
	var result = load("res://scripts/interaction/ensino.gd").new()
	result.next_id = int(data.next_id)
	result.sessions = Data.restore_precision(data.sessions)
	result.attempts = Data.restore_precision(data.attempts)
	result.events = Data.restore_precision(data.events)
	result.active = Data.restore_precision(data.active)
	return result
