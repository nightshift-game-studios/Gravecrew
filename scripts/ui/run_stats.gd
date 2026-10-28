class_name RunStatsTracker
extends Node
## Gooey: death-screen bridge to Skillz's MatchStats (STATS_API.md "Match stats"). The tally itself lives in MatchStats
## now (v0.7.0); this node only waits for match_ended, reads MatchStats.summary() once Progress.record_match has run,
## maps it to the GameOverScreen keys and emits finished(stats). hud.gd keeps owning it (no shared-file change).
## Overkill is capped in MatchStats via ctx.hp_before (Player.take_damage / Skillz 9120a3a + G4M3N 105e428).

signal finished(stats: Dictionary)

var player: Node ## local player (bound by HUD)
var ended: bool = false
var _end_ctx: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var ge := get_node_or_null("/root/GameEvents")
	if ge and not ge.event.is_connected(on_event):
		ge.event.connect(on_event)


func reset() -> void:
	ended = false
	_end_ctx = {}


func on_event(name: StringName, ctx: Dictionary) -> void:
	match name:
		&"round_started":
			if ended:
				reset()
		&"match_ended":
			if ended:
				return
			ended = true
			_end_ctx = ctx.duplicate()
			_finish.call_deferred() # Progress.record_match (XP) runs right after match_ended in the same frame


func _finish() -> void:
	finished.emit(snapshot())


## MatchStats.summary() in GameOverScreen keys, plus Progress-side numbers (level, best round).
func snapshot() -> Dictionary:
	var out := from_summary(MatchStats.summary(), _end_ctx)
	var prog := get_node_or_null("/root/Progress")
	if prog:
		out["best_round"] = int(prog.get("best_round"))
		out["level"] = int(prog.call("get_level")) if prog.has_method("get_level") else 0
	return out


## MatchStats keys -> death screen keys. match_ended's kills / round (main.gd) win when present.
static func from_summary(m: Dictionary, end_ctx: Dictionary = {}) -> Dictionary:
	var out := m.duplicate(true)
	out["grenades"] = int(m.get("grenades_thrown", 0))
	out["xp_earned"] = int(m.get("xp", 0))
	out["rounds"] = maxi(int(m.get("round_reached", 0)), int(end_ctx.get("round", 0)))
	if end_ctx.has("kills"):
		out["kills"] = maxi(int(end_ctx.kills), int(m.get("kills", 0)))
	out["accuracy"] = float(m.get("accuracy", 0.0)) if int(m.get("shots_fired", 0)) > 0 else -1.0
	out["precision_kills"] = int(m.get("precision_kills", m.get("headshot_kills", 0)))
	return out


## Accuracy over hitscan rounds fired. -1 = no shots.
static func accuracy_of(st: Dictionary) -> float:
	var fired := int(st.get("shots_fired", 0))
	if fired <= 0:
		return -1.0
	return clampf(float(fired - int(st.get("shots_missed", 0))) / float(fired), 0.0, 1.0)


static func format_time(t: float) -> String:
	var n := int(t)
	return "%d:%02d" % [n / 60, n % 60] if n < 3600 else "%d:%02d:%02d" % [n / 3600, (n / 60) % 60, n % 60]
