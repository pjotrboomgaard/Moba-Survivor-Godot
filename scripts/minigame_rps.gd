extends "res://scripts/minigame_base.gd"

## Rock-Paper-Creep — Scorch corner (1,1).
## RPS vs a bot, best-of-5. Press 1 (rock), 2 (paper), 3 (scissors) each round.
## Score = rounds won. Bot drives via bot_tick (random pick).

const ROUNDS_TO_WIN := 3
const WAIT_BETWEEN_ROUNDS := 1.2
const PICKS := ["rock", "paper", "scissors"]
const PICK_COLORS: Array[Color] = [Color(0.8, 0.6, 0.4), Color(0.5, 0.7, 0.9), Color(0.7, 0.85, 0.4)]

var _round := 0
var _wins_player := 0
var _wins_bot := 0
var _state := "pick"  # "pick" | "reveal"
var _player_pick := -1
var _bot_pick := -1
var _reveal_timer := 0.0
var _last_result := ""  # "win" | "lose" | "tie"


func _reset() -> void:
	_round = 0
	_wins_player = 0
	_wins_bot = 0
	_state = "pick"
	_player_pick = -1
	_bot_pick = -1
	_reveal_timer = 0.0
	_last_result = ""


func _update_delta(delta: float) -> void:
	if not active:
		return
	if _state == "reveal":
		_reveal_timer -= delta
		if _reveal_timer <= 0.0:
			_state = "pick"
			_player_pick = -1
			_bot_pick = -1


func on_input_event(event: InputEvent) -> void:
	if not active or _state != "pick":
		return
	if event is InputEventKey and event.pressed:
		var k: int = event.keycode
		if k == KEY_1:
			_player_pick = 0
		elif k == KEY_2:
			_player_pick = 1
		elif k == KEY_3:
			_player_pick = 2
		if _player_pick >= 0:
			_resolve_round()


func bot_tick(delta: float) -> Dictionary:
	if not active:
		return {"move": Vector2.ZERO, "attack": false, "interact": false}
	if _state == "pick":
		_player_pick = randi() % 3
		_resolve_round()
	return {"move": Vector2.ZERO, "attack": false, "interact": false}


func _resolve_round() -> void:
	_bot_pick = randi() % 3
	_round += 1
	_state = "reveal"
	_reveal_timer = WAIT_BETWEEN_ROUNDS
	# Determine winner: 0=rock beats 2=scissors, 1=paper beats 0=rock, 2=scissors beats 1=paper
	var result := _rps_result(_player_pick, _bot_pick)
	if result == "win":
		_wins_player += 1
		score += 1
		_last_result = "WIN!"
		AudioService.play("minigame_rps")
		_vfx_burst(Color(0.5, 0.7, 0.9), 20.0, 100.0)
	elif result == "lose":
		_wins_bot += 1
		_last_result = "LOSE"
		AudioService.play("minigame_rps")
		_vfx_burst(Color(1.0, 0.5, 0.5), 16.0, 90.0)
	else:
		_last_result = "TIE"
		_vfx_burst(Color(0.9, 0.9, 0.4), 12.0, 80.0)
	queue_redraw()
	# Check match end
	if _wins_player >= ROUNDS_TO_WIN or _wins_bot >= ROUNDS_TO_WIN:
		_finish_with_reward()


func _rps_result(a: int, b: int) -> String:
	if a == b:
		return "tie"
	if (a == 0 and b == 2) or (a == 1 and b == 0) or (a == 2 and b == 1):
		return "win"
	return "lose"


func _draw_body() -> void:
	# Round / score
	var text := "Round %d" % _round
	draw_string(ThemeDB.fallback_font, Vector2(-80.0, -40.0), text,
		HORIZONTAL_ALIGNMENT_CENTER, 160, 16, Color(1.0, 1.0, 1.0, 0.9))
	# Score
	draw_string(ThemeDB.fallback_font, Vector2(-60.0, -20.0),
		"You %d" % _wins_player, HORIZONTAL_ALIGNMENT_CENTER, 120, 14,
		Color(0.5, 1.0, 0.5, 0.95))
	draw_string(ThemeDB.fallback_font, Vector2(20.0, -20.0),
		"Creep %d" % _wins_bot, HORIZONTAL_ALIGNMENT_CENTER, 120, 14,
		Color(1.0, 0.5, 0.5, 0.95))
	# Prompt or reveal
	if _state == "pick":
		draw_string(ThemeDB.fallback_font, Vector2(-120.0, 10.0),
			"Press 1 Rock / 2 Paper / 3 Scissors",
			HORIZONTAL_ALIGNMENT_CENTER, 240, 14, Color(0.9, 0.9, 0.9, 0.9))
		# Show the 3 options
		for i in 3:
			var x := -80.0 + i * 80.0
			var col: Color = PICK_COLORS[i]
			var pressed := (_player_pick == i)
			draw_rect(Rect2(x - 28.0, 30.0, 56.0, 36.0),
				Color(col.r, col.g, col.b, 0.5 if pressed else 0.25))
			draw_string(ThemeDB.fallback_font, Vector2(x - 10.0, 52.0),
				str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 20, 18, Color(1.0, 1.0, 1.0, 0.95))
	else:
		# Reveal: show both picks
		var px := -50.0
		var bx := 50.0
		_draw_pick(px, _player_pick)
		_draw_pick(bx, _bot_pick)
		# Result text
		var result_col := Color(0.5, 1.0, 0.5) if _last_result == "WIN!" else (
			Color(1.0, 0.5, 0.5) if _last_result == "LOSE" else Color(0.9, 0.9, 0.4))
		draw_string(ThemeDB.fallback_font, Vector2(-80.0, 40.0), _last_result,
			HORIZONTAL_ALIGNMENT_CENTER, 160, 22, result_col)


func _draw_pick(x: float, pick: int) -> void:
	var col: Color = PICK_COLORS[pick] if pick >= 0 else Color(0.5, 0.5, 0.5)
	draw_rect(Rect2(x - 26.0, -10.0, 52.0, 36.0), Color(col.r, col.g, col.b, 0.7))
	# Symbol — chunky pixel-art shapes (T3.4 minigames use pixel art only).
	match pick:
		0:  # rock — a 3x3 blocky stone
			for rx in 3:
				for ry in 3:
					var rp := Vector2(x, 8.0) + Vector2(rx - 1.0, ry - 1.0) * 8.0
					draw_rect(Rect2(rp - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), Color(0.3, 0.2, 0.15, 0.95))
		1:  # paper — a chunky sheet of paper
			draw_rect(Rect2(x - 10.0, -2.0, 20.0, 22.0), Color(0.95, 0.95, 0.9, 0.95))
			draw_rect(Rect2(x - 7.0, 3.0, 14.0, 3.0), Color(0.5, 0.5, 0.55, 0.6))
			draw_rect(Rect2(x - 7.0, 9.0, 14.0, 3.0), Color(0.5, 0.5, 0.55, 0.6))
		2:  # scissors — two chunky crossed blades
			draw_rect(Rect2(x - 8.0, 0.0, 5.0, 16.0), Color(0.2, 0.2, 0.2, 0.9))
			draw_rect(Rect2(x + 3.0, 0.0, 5.0, 16.0), Color(0.2, 0.2, 0.2, 0.9))
			draw_rect(Rect2(x - 2.0, 10.0, 4.0, 4.0), Color(0.4, 0.4, 0.45, 0.9))
		_:
			pass
