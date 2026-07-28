extends Node

## 音效管理器（Autoload 单例）
## 不依赖外部音频文件，用 AudioStreamGenerator 实时合成短促音效。
## - play_click()    按钮点击
## - play_success()  通关（升调琶音 C-E-G-C）
## - play_error()    出错（下降两音）
## - play_step()     代码执行启动
##
## 设计：4 个 AudioStreamPlayer 轮询，避免短音效互相打断；每次播放新建
## AudioStreamGenerator 作为 stream，然后 push_buffer 写正弦波采样。

const SAMPLE_RATE := 44100

var _players: Array[AudioStreamPlayer] = []
var _muted: bool = false

func _ready() -> void:
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.name = "SFXPlayer%d" % i
		add_child(p)
		_players.append(p)

## ---- 对外 API ----

func play_click() -> void:
	_play_tone([_t(880.0, 0.04, 0.22)])

func play_step() -> void:
	_play_tone([_t(660.0, 0.05, 0.18)])

func play_success() -> void:
	_play_tone([
		_t(523.25, 0.10, 0.32),   # C5
		_t(659.25, 0.10, 0.32),   # E5
		_t(783.99, 0.10, 0.32),   # G5
		_t(1046.5, 0.22, 0.38),   # C6
	])

func play_error() -> void:
	_play_tone([
		_t(330.0, 0.12, 0.28),
		_t(220.0, 0.20, 0.28),
	], true)

func toggle_mute() -> bool:
	_muted = not _muted
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		AudioServer.set_bus_mute(bus_idx, _muted)
	return _muted

func is_muted() -> bool:
	return _muted

## ---- 内部 ----

static func _t(freq: float, duration: float, volume: float) -> Dictionary:
	return {"freq": freq, "duration": duration, "volume": volume}

func _play_tone(tones: Array, add_noise := false) -> void:
	if _muted:
		return
	var player := _get_free_player()
	if player == null:
		return

	var total_samples := 0
	for t in tones:
		total_samples += int(t["duration"] * SAMPLE_RATE)
	if add_noise:
		total_samples += int(0.10 * SAMPLE_RATE)

	var stream := AudioStreamGenerator.new()
	stream.mix_rate = SAMPLE_RATE
	stream.buffer_length = max(0.25, float(total_samples) / SAMPLE_RATE + 0.05)
	player.stream = stream
	player.play()

	var gen := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if gen == null:
		return

	# 先合成全部采样（单声道 Vector2）
	var buf := PackedVector2Array()
	buf.resize(total_samples)
	var idx := 0
	for t in tones:
		idx = _fill_sine(buf, idx, float(t["freq"]), int(t["duration"] * SAMPLE_RATE), float(t["volume"]))
	if add_noise:
		_fill_noise(buf, idx, int(0.10 * SAMPLE_RATE), 0.12)

	# 分段 push
	_async_push(gen, buf)

func _fill_sine(buf: PackedVector2Array, start: int, freq: float, dur: int, vol: float) -> int:
	var phase := 0.0
	var step := TAU * freq / SAMPLE_RATE
	var fade: int = min(900, dur / 4)
	var idx := start
	for i in dur:
		var env := 1.0
		if i < fade:
			env = float(i) / fade
		elif i > dur - fade:
			env = float(dur - i) / fade
		var s := sin(phase) * vol * env
		buf[idx] = Vector2(s, s)
		phase += step
		idx += 1
	return idx

func _fill_noise(buf: PackedVector2Array, start: int, dur: int, vol: float) -> void:
	var fade: int = min(2200, dur / 2)
	var idx := start
	for i in dur:
		var env := 1.0
		if i > dur - fade:
			env = float(dur - i) / fade
		var n := (randf() * 2.0 - 1.0) * vol * env
		buf[idx] = Vector2(n, n)
		idx += 1

func _async_push(gen: AudioStreamGeneratorPlayback, buf: PackedVector2Array) -> void:
	var remaining := buf.size()
	var offset := 0
	# 最多等 60 帧避免死循环
	var waited := 0
	while remaining > 0 and waited < 60:
		var space := gen.get_frames_available()
		if space <= 0:
			await get_tree().process_frame
			waited += 1
			continue
		var take: int = min(remaining, space)
		var chunk := buf.slice(offset, offset + take)
		gen.push_buffer(chunk)
		offset += take
		remaining -= take

func _get_free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0] if not _players.is_empty() else null
