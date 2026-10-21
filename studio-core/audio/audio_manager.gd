class_name StudioAudio
extends Node
## Plays short procedurally synthesized sound effects. No audio files, no licensing risk.
## Volume follows a StudioSettings node if one is given.

var settings: StudioSettings
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0

const RATE := 22050


func _ready() -> void:
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


## Registers a sound made of one or more (frequency_hz, duration_s) notes played in sequence.
func register_tone(name: String, notes: Array, volume: float = 0.5, shape := "sine") -> void:
	_streams[name] = synth(notes, volume, shape)


func play(name: String) -> void:
	if not _streams.has(name) or _players.is_empty():
		return
	var vol := 0.8
	if settings:
		vol = float(settings.get_value("sfx_volume", 0.8))
	if vol <= 0.001:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.volume_db = linear_to_db(vol)
	p.play()


static func synth(notes: Array, volume: float, shape: String) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	for note in notes:
		var freq: float = note[0]
		var dur: float = note[1]
		var count := int(dur * RATE)
		for i in count:
			var t := float(i) / RATE
			var env := minf(1.0, t / 0.005) * pow(1.0 - float(i) / count, 2.0)
			var ph := TAU * freq * t
			var s := sin(ph)
			if shape == "soft":
				s = 0.7 * sin(ph) + 0.3 * sin(ph * 2.0)
			var v := int(clampf(s * env * volume, -1.0, 1.0) * 32767.0)
			bytes.append(v & 0xff)
			bytes.append((v >> 8) & 0xff)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w
