extends Node

## Records the microphone through a Python sidecar and sends clips to Groq Whisper.
## Used by the Ravager mantra: repeat Tobor's words within 5 seconds.
##
## Godot WASAPI cannot open 4-channel laptop arrays, so capture stays out of
## the audio driver (tools/av_capture.py, PortAudio MME). The same helper can
## snap a webcam frame for a later boss via snap_pose().

const MANTRAS: Array[String] = [
	"i am safe here",
	"breathe in slowly",
	"let the tension go",
	"tobor breathes with me",
	"the light stays on",
	"i accept who i am",
]

const CHANT_SECONDS := 5.0
const WAV_PATH := "user://tobor_chant.wav"
const POSE_PATH := "user://tobor_pose.png"
const CMD_PATH := "user://av_cmd.txt"
const ACK_PATH := "user://av_ack.txt"
const STATUS_PATH := "user://av_status.json"
const HELPER_SCRIPT := "res://tools/av_capture.py"
const HEARTBEAT_SECONDS := 2.5

var _http: HTTPRequest
var _busy := false
var _helper_failed := false
var _helper_pid := -1
var _spawn_at_msec := 0
var _spawn_tries := 0
var _python_path := ""
var _last_heard := ""
var _cmd_token := 0
var mantra_index := 0


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 8.0
	add_child(_http)


func _exit_tree() -> void:
	_write_cmd("quit")


func next_mantra() -> String:
	var text := MANTRAS[mantra_index % MANTRAS.size()]
	mantra_index += 1
	return text


func mantra_words(text: String) -> PackedStringArray:
	return text.to_lower().split(" ", false)


func matched_count(mantra: String, heard: String) -> int:
	var words := mantra_words(mantra)
	var spoken := _normalize(heard)
	var count := 0
	var cursor := 0
	for word in words:
		var found := spoken.find(word, cursor)
		if found < 0:
			break
		count += 1
		cursor = found + word.length()
	return count


func is_complete(mantra: String, heard: String) -> bool:
	return matched_count(mantra, heard) >= mantra_words(mantra).size()


func mic_available() -> bool:
	if _helper_failed:
		return false
	var status := _read_status()
	return bool(status.get("mic", false)) and _heartbeat_fresh(status)


func camera_available() -> bool:
	var status := _read_status()
	return bool(status.get("camera", false)) and _heartbeat_fresh(status)


func voice_ready() -> bool:
	return groq_ready() and mic_available()


func ensure_capture() -> void:
	if _helper_failed:
		return
	if _heartbeat_fresh(_read_status()):
		_spawn_tries = 0
		return
	if _spawn_at_msec > 0 and Time.get_ticks_msec() - _spawn_at_msec < 4000:
		return
	if _spawn_tries >= 2:
		_helper_failed = true
		push_warning("AV capture helper did not come up; chant falls back to ENTER.")
		return
	_spawn_tries += 1
	_spawn_helper()
	_spawn_at_msec = Time.get_ticks_msec()


func start_recording() -> void:
	_last_heard = ""
	ensure_capture()
	if not mic_available():
		return
	_write_cmd("start")


func stop_recording() -> void:
	if _http != null:
		_http.cancel_request()


func transcribe_current(hint: String = "") -> String:
	if _busy or not mic_available():
		return _last_heard
	_busy = true
	var dumped := await _request_helper("dump", WAV_PATH)
	if not dumped:
		_busy = false
		return _last_heard
	var heard := await _post_wav(hint)
	if not heard.is_empty():
		_last_heard = heard
	_busy = false
	return _last_heard


func snap_pose() -> String:
	ensure_capture()
	var deadline := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline and not camera_available():
		await get_tree().process_frame
	if not camera_available():
		return ""
	if await _request_helper("snap", POSE_PATH):
		return POSE_PATH
	return ""


func groq_ready() -> bool:
	return not _groq_key().is_empty()


func _spawn_helper() -> void:
	_kill_stale_helper()
	var python := _find_python()
	var script := ProjectSettings.globalize_path(HELPER_SCRIPT)
	var user_dir := ProjectSettings.globalize_path("user://")
	if python.is_empty() or not FileAccess.file_exists(script):
		_helper_failed = true
		push_warning("AV capture helper is missing; chant falls back to ENTER.")
		return
	_helper_pid = OS.create_process(python, PackedStringArray(["-u", script, "--dir", user_dir]), false)
	if _helper_pid < 0:
		_helper_failed = true
		push_warning("AV capture helper failed to start; chant falls back to ENTER.")


func _kill_stale_helper() -> void:
	var status := _read_status()
	var pid := int(status.get("pid", -1))
	if pid > 0 and not _heartbeat_fresh(status):
		OS.kill(pid)


func _find_python() -> String:
	if not _python_path.is_empty():
		return _python_path
	var env := OS.get_environment("PYTHON_EXE").strip_edges()
	if not env.is_empty() and FileAccess.file_exists(env):
		_python_path = env
		return _python_path
	for launcher in PackedStringArray(["py", "python"]):
		var output: Array = []
		var args := PackedStringArray(["-c", "import sys; print(sys.executable)"])
		if launcher == "py":
			args = PackedStringArray(["-3", "-c", "import sys; print(sys.executable)"])
		if OS.execute(launcher, args, output, true, false) != 0 or output.is_empty():
			continue
		var path := str(output[0]).strip_edges()
		if path.is_empty() or "WindowsApps" in path:
			continue
		if FileAccess.file_exists(path):
			_python_path = path
			return _python_path
	_helper_failed = true
	return ""


func _write_cmd(command: String) -> String:
	_cmd_token += 1
	var line := "%s %d" % [command, _cmd_token]
	var tmp := "user://av_cmd.tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(line + "\n")
	file = null
	var dir := DirAccess.open("user://")
	if dir == null:
		return ""
	if FileAccess.file_exists(CMD_PATH):
		dir.remove("av_cmd.txt")
	dir.rename("av_cmd.tmp", "av_cmd.txt")
	return line


func _request_helper(command: String, result_path: String) -> bool:
	var line := _write_cmd(command)
	if line.is_empty():
		return false
	var deadline := Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < deadline:
		if _ack_matches(line) and FileAccess.file_exists(result_path):
			return true
		await get_tree().process_frame
	return FileAccess.file_exists(result_path)


func _ack_matches(line: String) -> bool:
	if not FileAccess.file_exists(ACK_PATH):
		return false
	var file := FileAccess.open(ACK_PATH, FileAccess.READ)
	if file == null:
		return false
	var ack := file.get_as_text().strip_edges()
	return ack == (line + " ok")


func _read_status() -> Dictionary:
	if not FileAccess.file_exists(STATUS_PATH):
		return {}
	var file := FileAccess.open(STATUS_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


func _heartbeat_fresh(status: Dictionary) -> bool:
	if status.is_empty():
		return false
	var age := Time.get_unix_time_from_system() - float(status.get("ts", 0.0))
	return age >= 0.0 and age <= HEARTBEAT_SECONDS


func _post_wav(hint: String = "") -> String:
	var key := _groq_key()
	if key.is_empty():
		return ""
	if not FileAccess.file_exists(WAV_PATH):
		return ""
	var file := FileAccess.open(WAV_PATH, FileAccess.READ)
	if file == null:
		return ""
	var wav := file.get_buffer(file.get_length())
	var boundary := "----ToborBoundary"
	var body := PackedByteArray()
	body.append_array(_part(boundary, "model", "whisper-large-v3-turbo"))
	body.append_array(_part(boundary, "language", "nl"))
	if not hint.is_empty():
		body.append_array(_part(boundary, "prompt", hint))
	body.append_array(_file_part(boundary, "file", "clip.wav", "audio/wav", wav))
	body.append_array(("\r\n--%s--\r\n" % boundary).to_utf8_buffer())
	var headers := PackedStringArray([
		"Authorization: Bearer %s" % key,
		"Content-Type: multipart/form-data; boundary=%s" % boundary,
	])
	var err := _http.request_raw(
		"https://api.groq.com/openai/v1/audio/transcriptions",
		headers,
		HTTPClient.METHOD_POST,
		body
	)
	if err != OK:
		return ""
	var result: Array = await _http.request_completed
	var code := int(result[1])
	var response_body: PackedByteArray = result[3]
	if code < 200 or code >= 300:
		push_warning("STT failed: %s" % response_body.get_string_from_utf8())
		return ""
	var parsed: Variant = JSON.parse_string(response_body.get_string_from_utf8())
	if parsed is Dictionary:
		return _normalize(str(parsed.get("text", "")))
	return ""


func _part(boundary: String, name: String, value: String) -> PackedByteArray:
	return ("--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n" % [boundary, name, value]).to_utf8_buffer()


func _file_part(boundary: String, name: String, filename: String, mime: String, data: PackedByteArray) -> PackedByteArray:
	var header := "--%s\r\nContent-Disposition: form-data; name=\"%s\"; filename=\"%s\"\r\nContent-Type: %s\r\n\r\n" % [boundary, name, filename, mime]
	var out := header.to_utf8_buffer()
	out.append_array(data)
	out.append_array("\r\n".to_utf8_buffer())
	return out


func _normalize(text: String) -> String:
	var lowered := text.to_lower()
	var cleaned := ""
	for i in lowered.length():
		var ch := lowered[i]
		if ch >= "a" and ch <= "z":
			cleaned += ch
		elif ch == " " or ch == "'":
			cleaned += " "
		# keep Dutch letters
		elif ch == "ë" or ch == "é" or ch == "è" or ch == "ï":
			cleaned += ch
	return cleaned.strip_edges()


func _groq_key() -> String:
	var env := OS.get_environment("GROQ_API_KEY").strip_edges()
	if not env.is_empty():
		return env
	var candidates := PackedStringArray([
		ProjectSettings.globalize_path("res://tobor-haven/server/.env"),
		ProjectSettings.globalize_path("res://../tobor-haven/server/.env"),
	])
	for path in candidates:
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		while not file.eof_reached():
			var line := file.get_line().strip_edges()
			if line.begins_with("GROQ_API_KEY="):
				return line.trim_prefix("GROQ_API_KEY=").strip_edges().trim_prefix("\"").trim_suffix("\"")
	return ""
