extends Control

@export var typing_speed: float = 40.0

@onready var dialogue_label: RichTextLabel = $DialogueLabel
@onready var typing_player: AudioStreamPlayer = $TypingPlayer
@onready var heartbeat_player: AudioStreamPlayer = $HeartbeatPlayer
@onready var sfx_player: AudioStreamPlayer = $SfxPlayer

var _full_text: String = ""
var _next_scene_path: String = ""

var _char_index: int = 0
var _time_accum: float = 0.0
var _typing_active: bool = false
var _can_advance: bool = false

var _break_indices: Array[int] = []
var _next_break_i: int = 0
var _awaiting_break_continue: bool = false

var _pause_indices: Array[int] = []
var _pause_durations: Array[float] = []
var _next_pause_i: int = 0
var _pause_until_time: float = -1.0

var _audio_indices: Array[int] = []
var _audio_paths: Array[String] = []
var _next_audio_i: int = 0
var _audio_playing: bool = false
var _pending_pause_after_audio: float = -1.0
var _resume_heartbeat_after_audio: bool = false
var _audio_after_pause_map: Dictionary = {}
var _last_triggered_pause_index: int = -1

var _fade_break_indices: Array[int] = []
var _next_fade_break_i: int = 0
var _segment_start_index: int = 0
var _segment_fading: bool = false
var _segment_fade_duration: float = 0.35
var _pending_fade_start_index: int = -1

var _display_text: String = ""
var _cursor_char: String = "X"
var _cursor_visible: bool = true
var _cursor_timer: float = 0.0
var _cursor_period: float = 0.5

# Color spans for inline tags like <r>...</r>
var _color_spans: Array = [] # each: {start: int, end: int, color: String}


func _setup_cutscene_common() -> void:
	# Apply default font to dialogue
	FontConfig.apply_dialogue_font(dialogue_label)
	if dialogue_label:
		dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		# Control space between lines using RichTextLabel's line_separation constant
		dialogue_label.add_theme_constant_override("line_separation", 14)
		dialogue_label.add_theme_constant_override("paragraph_separation", 14)
		# We will feed BBCode into this RichTextLabel
		dialogue_label.bbcode_enabled = true

	_char_index = 0
	_time_accum = 0.0
	_typing_active = false
	_can_advance = false
	_break_indices.clear()
	_next_break_i = 0
	_awaiting_break_continue = false
	_pause_indices.clear()
	_pause_durations.clear()
	_next_pause_i = 0
	_pause_until_time = -1.0
	_display_text = ""
	_cursor_visible = true
	_cursor_timer = 0.0
	if dialogue_label:
		_dialogue_set_with_cursor()

	if heartbeat_player and heartbeat_player.stream:
		heartbeat_player.play()

	if sfx_player:
		sfx_player.connect("finished", Callable(self, "_on_sfx_finished"))


func _process(delta: float) -> void:
	_update_cursor(delta)
	if _audio_playing:
		if sfx_player and sfx_player.playing:
			return
		_audio_playing = false
		if _resume_heartbeat_after_audio and heartbeat_player:
			heartbeat_player.play()
			_resume_heartbeat_after_audio = false
		if _pending_pause_after_audio > 0.0:
			_pause_until_time = Time.get_ticks_msec() / 1000.0 + _pending_pause_after_audio
			_pending_pause_after_audio = -1.0
			_typing_active = false
		else:
			_typing_active = true
			if typing_player and typing_player.stream:
				typing_player.play()
	if _segment_fading:
		return
	if _pause_until_time > 0.0:
		if Time.get_ticks_msec() / 1000.0 >= _pause_until_time:
			_pause_until_time = -1.0
			var idx := _last_triggered_pause_index
			_last_triggered_pause_index = -1
			if _audio_after_pause_map.has(idx):
				var apath: String = _audio_after_pause_map[idx]
				_audio_after_pause_map.erase(idx)
				_typing_active = false
				if typing_player:
					typing_player.stop()
				var streamp := load(apath)
				if sfx_player and streamp:
					sfx_player.stream = streamp
					if sfx_player.stream:
						sfx_player.stream.loop = false
					sfx_player.play()
					_audio_playing = true
					if heartbeat_player and heartbeat_player.playing:
						heartbeat_player.stop()
						_resume_heartbeat_after_audio = true
			else:
				_typing_active = true
				if typing_player and typing_player.stream:
					typing_player.play()
		else:
			return

	if _typing_active:
		_time_accum += delta * typing_speed
		var target_index := int(_time_accum)
		if target_index > _char_index:
			target_index = clamp(target_index, 0, _full_text.length())
			var current_fade_break_index := -1
			if _next_fade_break_i < _fade_break_indices.size():
				current_fade_break_index = _fade_break_indices[_next_fade_break_i]
			var current_pause_index := -1
			var current_pause_duration := 0.0
			if _next_pause_i < _pause_indices.size():
				current_pause_index = _pause_indices[_next_pause_i]
				current_pause_duration = _pause_durations[_next_pause_i]
			var current_audio_index := -1
			var current_audio_path := ""
			if _next_audio_i < _audio_indices.size():
				current_audio_index = _audio_indices[_next_audio_i]
				current_audio_path = _audio_paths[_next_audio_i]
			if current_fade_break_index != -1 and not _awaiting_break_continue and _char_index < current_fade_break_index and target_index >= current_fade_break_index:
				_typing_active = false
				if typing_player:
					typing_player.stop()
				target_index = current_fade_break_index
				_pending_fade_start_index = current_fade_break_index
				_awaiting_break_continue = true
				_can_advance = false
				_set_visible_char_count(target_index)
				_char_index = target_index
				# Fade will be triggered after user presses space
				return
			elif current_audio_index != -1 and _char_index < current_audio_index and target_index >= current_audio_index:
				_typing_active = false
				if typing_player:
					typing_player.stop()
				target_index = current_audio_index
				_next_audio_i += 1
				var stream := load(current_audio_path)
				if sfx_player and stream:
					sfx_player.stream = stream
					if sfx_player.stream:
						sfx_player.stream.loop = false
					sfx_player.play()
					_audio_playing = true
					if heartbeat_player and heartbeat_player.playing:
						heartbeat_player.stop()
						_resume_heartbeat_after_audio = true
				# If a pause tag is exactly at the same index, schedule it to start after audio ends
				if _next_pause_i < _pause_indices.size() and _pause_indices[_next_pause_i] == current_audio_index:
					_pending_pause_after_audio = _pause_durations[_next_pause_i]
					_next_pause_i += 1
			elif current_pause_index != -1 and _char_index < current_pause_index and target_index >= current_pause_index:
				_typing_active = false
				_pause_until_time = Time.get_ticks_msec() / 1000.0 + current_pause_duration
				if typing_player:
					typing_player.stop()
				target_index = current_pause_index
				_next_pause_i += 1
				_last_triggered_pause_index = current_pause_index
			var current_break_index := -1
			if _next_break_i < _break_indices.size():
				current_break_index = _break_indices[_next_break_i]
			if current_break_index != -1 and not _awaiting_break_continue and _char_index < current_break_index and target_index >= current_break_index:
				target_index = current_break_index
				_typing_active = false
				_awaiting_break_continue = true
				_can_advance = false
				if typing_player:
					typing_player.stop()
				_next_break_i += 1
			_set_visible_char_count(target_index)
			_char_index = target_index
			if _char_index >= _full_text.length() and not _awaiting_break_continue:
				_typing_active = false
				_can_advance = true
				if typing_player:
					typing_player.stop()


func _start_typing(text: String) -> void:
	_full_text = text.to_upper()
	_break_indices.clear()
	_next_break_i = 0
	_awaiting_break_continue = false
	_pause_indices.clear()
	_pause_durations.clear()
	_next_pause_i = 0
	_pause_until_time = -1.0
	_color_spans.clear()
	_audio_indices.clear()
	_audio_paths.clear()
	_next_audio_i = 0
	_audio_playing = false
	_audio_after_pause_map.clear()
	_fade_break_indices.clear()
	_next_fade_break_i = 0
	_segment_start_index = 0
	_segment_fading = false
	_pending_fade_start_index = -1

	var final_text := ""
	var visible_index := 0
	var raw := _full_text
	var i := 0
	var stack: Array = [] # stack of {color: String, start: int}
	while i < raw.length():
		var consumed := false
		# pause tag: (pause=...)
		if i + 7 <= raw.length() and raw.substr(i, 7).to_lower() == "(pause=":
			var close := raw.find(")", i + 7)
			if close == -1:
				break
			var value_string := raw.substr(
				i + 7,
				close - (i + 7)
			)
			var duration := float(value_string)
			_pause_indices.append(visible_index)
			_pause_durations.append(duration)
			i = close + 1
			consumed = true
		# break tag: (break)
		elif i + 7 <= raw.length() and raw.substr(i, 7).to_lower() == "(break)":
			_break_indices.append(visible_index)
			i += 7
			consumed = true
		# opening color tags
		elif i + 3 <= raw.length() and raw.substr(i, 3).to_lower() == "<r>":
			stack.append({"color": "red", "start": visible_index})
			i += 3
			consumed = true
		elif i + 3 <= raw.length() and raw.substr(i, 3).to_lower() == "<y>":
			stack.append({"color": "yellow", "start": visible_index})
			i += 3
			consumed = true
		elif i + 3 <= raw.length() and raw.substr(i, 3).to_lower() == "<g>":
			stack.append({"color": "green", "start": visible_index})
			i += 3
			consumed = true
		elif i + 3 <= raw.length() and raw.substr(i, 3).to_lower() == "<b>":
			stack.append({"color": "blue", "start": visible_index})
			i += 3
			consumed = true
		# closing color tags
		elif i + 4 <= raw.length() and (raw.substr(i, 4).to_lower() == "</r>" or raw.substr(i, 4).to_lower() == "</y>" or raw.substr(i, 4).to_lower() == "</g>" or raw.substr(i, 4).to_lower() == "</b>"):
			if stack.size() > 0:
				var span = stack.pop_back()
				span["end"] = visible_index
				_color_spans.append(span)
			i += 4
			consumed = true
		elif i + 1 <= raw.length() and raw[i] == "<":
			var close2 := raw.find(">", i + 1)
			if close2 != -1:
				var content := raw.substr(i + 1, close2 - (i + 1))
				var lower := content.to_lower()
				if lower == "break":
					_fade_break_indices.append(visible_index)
					i = close2 + 1
					consumed = true
				elif lower.ends_with(".mp3") or lower.ends_with(".ogg") or lower.ends_with(".wav"):
					var ap := content
					ap = ap.replace("\\", "/")
					if not ap.contains("://"):
						if ap.length() >= 3 and ap[1] == ":" and ap[2] == "/":
							var localized := ProjectSettings.localize_path(ap)
							if localized.begins_with("res://") or localized.begins_with("user://"):
								ap = localized
						elif ap.begins_with("/"):
							ap = "res://" + ap.substr(1, ap.length() - 1)
						else:
							ap = "res://" + ap
					var attach_to_prev_pause := false
					if _pause_indices.size() > 0 and _pause_indices[_pause_indices.size() - 1] == visible_index:
						attach_to_prev_pause = true
					if attach_to_prev_pause:
						_audio_after_pause_map[visible_index] = ap
					else:
						_audio_indices.append(visible_index)
						_audio_paths.append(ap)
					i = close2 + 1
					consumed = true
		if consumed:
			continue
		# normal visible character
		final_text += raw[i]
		visible_index += 1
		i += 1

	# close any unclosed color spans at end
	for span_dict in stack:
		span_dict["end"] = visible_index
		_color_spans.append(span_dict)

	_full_text = final_text

	_char_index = 0
	_time_accum = 0.0
	_typing_active = _full_text.length() > 0
	_can_advance = false
	_set_visible_char_count(0)
	# If a pause tag is at the very beginning, honor it before any audio or text
	if _pause_indices.size() > 0 and _pause_indices[0] == 0:
		_typing_active = false
		if typing_player:
			typing_player.stop()
		_pause_until_time = Time.get_ticks_msec() / 1000.0 + _pause_durations[0]
		_next_pause_i = 1
		_last_triggered_pause_index = 0
	elif _audio_indices.size() > 0 and _audio_indices[0] == 0:
		# Otherwise, if an inline audio tag is at the very beginning, play it before any text appears
		_typing_active = false
		if typing_player:
			typing_player.stop()
		var stream0 := load(_audio_paths[0])
		if sfx_player and stream0:
			sfx_player.stream = stream0
			if sfx_player.stream:
				sfx_player.stream.loop = false
			sfx_player.play()
			_audio_playing = true
			if heartbeat_player and heartbeat_player.playing:
				heartbeat_player.stop()
				_resume_heartbeat_after_audio = true
		_next_audio_i = 1
	else:
		if _typing_active and typing_player and typing_player.stream:
			typing_player.play()


func _set_visible_char_count(count: int) -> void:
	var max_count: int = clamp(count, 0, _full_text.length())
	var start_i: int = clamp(_segment_start_index, 0, max_count)
	var result: String = ""
	var idx: int = start_i
	var span_i: int = 0
	var active_span: Dictionary = {"start": 0, "end": 0, "color": ""}
	var has_active_span: bool = false
	while span_i < _color_spans.size() and int(_color_spans[span_i]["start"]) < start_i:
		span_i += 1
	if span_i > 0:
		var prev_span: Dictionary = _color_spans[span_i - 1]
		if int(prev_span["start"]) <= start_i and int(prev_span["end"]) > start_i:
			active_span = prev_span
			has_active_span = true
			result += "[color=" + String(active_span["color"]) + "]"
	while idx < max_count:
		if has_active_span and idx >= int(active_span["end"]):
			result += "[/color]"
			has_active_span = false
		if (not has_active_span) and span_i < _color_spans.size() and idx >= int(_color_spans[span_i]["start"]):
			active_span = _color_spans[span_i]
			has_active_span = true
			result += "[color=" + String(active_span["color"]) + "]"
			span_i += 1
		result += _full_text[idx]
		idx += 1
	if has_active_span:
		result += "[/color]"
	_display_text = result
	_cursor_timer = 0.0
	_cursor_visible = true
	_dialogue_set_with_cursor()


func _update_cursor(delta: float) -> void:
	_cursor_timer += delta
	if _cursor_timer >= _cursor_period:
		_cursor_timer -= _cursor_period
		_cursor_visible = not _cursor_visible
		_dialogue_set_with_cursor()


func _dialogue_set_with_cursor() -> void:
	if not dialogue_label:
		return
	var text := _display_text
	if _cursor_visible:
		text += _cursor_char
	dialogue_label.text = text


func _unhandled_input(event: InputEvent) -> void:
	var pressed_accept := event.is_action_pressed("ui_accept")
	var pressed_space: bool = event is InputEventKey and event.pressed and event.keycode == KEY_SPACE
	if not (pressed_accept or pressed_space):
		return

	if _awaiting_break_continue:
		if _pending_fade_start_index != -1:
			var next_start: int = _pending_fade_start_index
			_pending_fade_start_index = -1
			_awaiting_break_continue = false
			_segment_fading = true
			if typing_player:
				typing_player.stop()
			var t1 := create_tween()
			t1.tween_property(dialogue_label, "modulate:a", 0.0, _segment_fade_duration)
			t1.tween_callback(Callable(self, "_on_segment_fade_out").bind(next_start))
			t1.tween_property(dialogue_label, "modulate:a", 1.0, _segment_fade_duration)
			t1.tween_callback(Callable(self, "_on_segment_fade_in_complete"))
			_next_fade_break_i += 1
		else:
			_awaiting_break_continue = false
			_typing_active = true
			_time_accum = float(_char_index)
			if typing_player and typing_player.stream:
				typing_player.play()
		return

	if not _can_advance:
		return
	if _next_scene_path == "":
		return
	var tree := get_tree()
	if not tree:
		return
	# Try to find an existing TransitionManager in the root
	var root := tree.get_root()
	var tm := root.get_node_or_null("TransitionManager")
	# If none exists yet, create one and attach it to the root so it survives scene changes
	if not tm:
		var tm_script := load("res://scripts/TransitionManager.gd")
		if tm_script:
			tm = Node.new()
			tm.name = "TransitionManager"
			tm.set_script(tm_script)
			root.add_child(tm)
	if tm:
		tm.fade_to_scene(_next_scene_path, 1.5, 1.5)
	else:
		# Fallback: hard cut if TransitionManager couldn't be created
		tree.change_scene_to_file(_next_scene_path)


func _on_sfx_finished() -> void:
	_audio_playing = false
	if _pending_pause_after_audio > 0.0:
		_pause_until_time = Time.get_ticks_msec() / 1000.0 + _pending_pause_after_audio
		_pending_pause_after_audio = -1.0
		_typing_active = false
		return
	if _resume_heartbeat_after_audio and heartbeat_player:
		heartbeat_player.play()
		_resume_heartbeat_after_audio = false
	_typing_active = true
	if typing_player and typing_player.stream:
		typing_player.play()

func _on_segment_fade_out(next_start: int) -> void:
	_segment_start_index = next_start
	_set_visible_char_count(_char_index)

func _on_segment_fade_in_complete() -> void:
	_segment_fading = false
	_typing_active = true
	if typing_player and typing_player.stream:
		typing_player.play()
