extends Node
## AudioLib -- the game's sound library and playback (autoload).
##
## WHERE THE SOUNDS COME FROM
## The Ballgame Sound Lab exports a ZIP whose `library/` folder is unzipped into
## `game/audio/`. Inside is `audio_catalog.gd`, a generated script whose
## ENTRIES constant describes every sound (id, category, files, tiers ...).
## It is a script rather than a loose JSON file so it is bundled into exported
## builds automatically. If the folder is missing the game simply runs silent.
##
## WHAT IS PICKED
## The Sound Lab exports several versions of most sounds (original, A, B, C).
## A "hook" is a place the game plays a sound: menu music, game music, and one
## per sound effect (click, launch, bounce ...). Each hook has a pick, which is
## the id of one catalog entry. Picks are edited in the Asset Viewer's Audio
## tab and saved to `user://audio_picks.cfg`, so they survive restarts. They are
## kept out of `user://settings.cfg` on purpose: `Settings._save()` rewrites
## that whole file and would otherwise drop them.
##
## Runs while the tree is paused so the pause menu can still click and the
## music keeps playing behind it.

signal picks_changed
signal catalog_loaded

const CATALOG_PATH := "res://audio/library/audio_catalog.gd"
const PICKS_PATH := "user://audio_picks.cfg"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
## Game music has one file per round tier and a new tier starts every this many rounds.
const ROUNDS_PER_TIER := 10
const MAX_TIER := 5
const SFX_VOICES := 16
## AudioStreamPlaylist holds at most this many streams.
const PLAYLIST_MAX_STREAMS := 64

## Every place the game plays a sound.
##   kind      "music" or "sfx"
##   filter    music: the catalog `category` to choose from; sfx: the catalog `slot`
##   cooldown  seconds before the same hook may fire again (many balls bounce at once)
##   db        gain for this hook, on top of the SFX bus volume
##   jitter    random pitch spread so rapid repeats do not sound like a machine gun
const HOOKS := [
	{"key": "menu_music", "label": "Menu music", "kind": "music", "filter": "menu"},
	{"key": "game_music", "label": "Game music", "kind": "music", "filter": "game"},
	{"key": "click", "label": "Button click", "kind": "sfx", "filter": "button_click", "cooldown": 0.02},
	{"key": "hover", "label": "Button hover", "kind": "sfx", "filter": "button_hover", "cooldown": 0.04, "db": -4.0},
	{"key": "toggle_on", "label": "Toggle on", "kind": "sfx", "filter": "toggle_on"},
	{"key": "toggle_off", "label": "Toggle off", "kind": "sfx", "filter": "toggle_off"},
	{"key": "launch", "label": "Ball launch", "kind": "sfx", "filter": "ball_launch", "cooldown": 0.03, "db": -3.0, "jitter": 0.04},
	{"key": "bounce", "label": "Wall bounce", "kind": "sfx", "filter": "wall_bounce", "cooldown": 0.06, "db": -8.0, "jitter": 0.05},
	{"key": "hit", "label": "Block hit", "kind": "sfx", "filter": "block_hit", "cooldown": 0.04, "db": -4.0},
	{"key": "break_small", "label": "Block break (small)", "kind": "sfx", "filter": "block_break_small", "cooldown": 0.03, "db": -3.0, "jitter": 0.04},
	{"key": "break_big", "label": "Block break (big)", "kind": "sfx", "filter": "block_break_big", "cooldown": 0.03, "db": -2.0},
	{"key": "pickup", "label": "Ball +1 pickup", "kind": "sfx", "filter": "ball_pickup", "cooldown": 0.05},
	{"key": "land", "label": "Ball lands", "kind": "sfx", "filter": "ball_lands", "cooldown": 0.05, "db": -6.0, "jitter": 0.05},
	{"key": "row_shift", "label": "Rows shift down", "kind": "sfx", "filter": "rows_shift_down"},
	{"key": "danger", "label": "Danger warning", "kind": "sfx", "filter": "danger_warning"},
	{"key": "game_over", "label": "Game over", "kind": "sfx", "filter": "game_over"},
]

## Every catalog entry (Dictionaries, see the generated catalog for the fields).
var entries: Array = []
## id -> entry, for quick lookup.
var by_id: Dictionary = {}
## hook key -> chosen entry id. Only holds picks the user changed away from the default.
var picks: Dictionary = {}
## Tier used when previewing game music in the Asset Viewer.
var preview_tier: int = MAX_TIER

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0
var _last_played: Dictionary = {}          ## hook key -> msec of the last play
var _stream_cache: Dictionary = {}         ## path -> loaded stream (or null)

var _music: AudioStreamPlayer
var _music_key: String = ""                ## "menu:<id>" or "game:<id>", to avoid restarting the same tune
var _music_entry: Dictionary = {}
var _music_tier: int = 0
var _music_last_pos: float = 0.0
var _pending_tier: int = 0                 ## tier waiting for the loop to come around
var _music_tween: Tween

var _preview: AudioStreamPlayer
var _preview_entry_id: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = _make_player(MUSIC_BUS)
	_preview = _make_player(MUSIC_BUS)
	for i in range(SFX_VOICES):
		_sfx_players.append(_make_player(SFX_BUS))
	_load_catalog()
	_load_picks()
	get_tree().node_added.connect(_on_node_added)

func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	# Fall back to Master if a project's bus layout has no such bus.
	p.bus = bus if AudioServer.get_bus_index(bus) >= 0 else "Master"
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	return p

func _process(_delta: float) -> void:
	_tick_tier_swap()


# ----------------------------------------------------------------- catalog

func _load_catalog() -> void:
	entries.clear()
	by_id.clear()
	if not ResourceLoader.exists(CATALOG_PATH):
		return
	var script = load(CATALOG_PATH)
	if script == null:
		push_warning("AudioLib: could not load %s" % CATALOG_PATH)
		return
	for e in script.ENTRIES:
		entries.append(e)
		by_id[e["id"]] = e
	catalog_loaded.emit()

func has_library() -> bool:
	return not entries.is_empty()

func hook_def(key: String) -> Dictionary:
	for h in HOOKS:
		if h["key"] == key:
			return h
	return {}

## Entries a hook may use, in catalog order (original first, then variations).
func entries_for(key: String) -> Array:
	var h := hook_def(key)
	var out: Array = []
	if h.is_empty():
		return out
	for e in entries:
		if e["kind"] != h["kind"]:
			continue
		var field := "category" if h["kind"] == "music" else "slot"
		if e[field] == h["filter"]:
			out.append(e)
	return out

## The entry a hook plays right now: the saved pick, else the first original.
func pick_entry(key: String) -> Dictionary:
	var id: String = picks.get(key, "")
	if id != "" and by_id.has(id):
		return by_id[id]
	return default_entry(key)

func default_entry(key: String) -> Dictionary:
	var list := entries_for(key)
	for e in list:
		if e["original"]:
			return e
	return list[0] if not list.is_empty() else {}

func set_pick(key: String, id: String) -> void:
	if not by_id.has(id):
		return
	if default_entry(key).get("id", "") == id:
		picks.erase(key)       # back to the default: nothing to remember
	else:
		picks[key] = id
	_save_picks()
	picks_changed.emit()
	# A changed music pick applies at once if that music is what is playing.
	if key == "menu_music" and _music_key.begins_with("menu:"):
		play_menu_music()
	elif key == "game_music" and _music_key.begins_with("game:"):
		play_game_music(_round_for_music)

func reset_picks() -> void:
	picks.clear()
	_save_picks()
	picks_changed.emit()

func _load_picks() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PICKS_PATH) != OK:
		return
	for h in HOOKS:
		var id: String = cfg.get_value("picks", h["key"], "")
		if id != "" and by_id.has(id):
			picks[h["key"]] = id

func _save_picks() -> void:
	var cfg := ConfigFile.new()
	for key in picks:
		cfg.set_value("picks", key, picks[key])
	cfg.save(PICKS_PATH)


# ------------------------------------------------------------- stream loading

## Loads a file once; null when it is missing or not imported yet.
func _load_stream(path: String) -> AudioStream:
	if path == "":
		return null
	if _stream_cache.has(path):
		return _stream_cache[path]
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path) as AudioStream
	_stream_cache[path] = s
	return s

## Music prefers OGG (small); effects prefer WAV (no decode cost, exact length).
func _stream_for(wav: String, ogg: String, prefer_ogg: bool) -> AudioStream:
	var first := ogg if prefer_ogg else wav
	var second := wav if prefer_ogg else ogg
	var s := _load_stream(first)
	return s if s != null else _load_stream(second)

## Turns looping on for a music stream, whichever format it came in.
func _looped(s: AudioStream) -> AudioStream:
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.get_length() * float(w.mix_rate))
	return s

## The stream to play for a music entry at a tier: intro (if any) followed by the endless loop.
func _music_stream(e: Dictionary, tier: int) -> AudioStream:
	var loop_wav: String = e.get("wav", "")
	var loop_ogg: String = e.get("ogg", "")
	if not e["tiers"].is_empty():
		# Game music: one file per tier, all the same length.
		var t: Dictionary = e["tiers"][clampi(tier, 1, e["tiers"].size()) - 1]
		loop_wav = t.get("wav", "")
		loop_ogg = t.get("ogg", "")
	var body := _stream_for(loop_wav, loop_ogg, true)
	if body == null:
		return null
	_looped(body)
	var intro := _stream_for(e.get("intro_wav", ""), e.get("intro_ogg", ""), true)
	if intro == null:
		return body
	# An intro plays once, then hands over to the loop with no gap. Godot's
	# playlist ignores a child stream's own loop flag (it moves on when the
	# child ends), so the loop is queued many times over instead and the
	# whole list repeats only after several minutes, which nobody sits through
	# on a menu.
	var list := AudioStreamPlaylist.new()
	list.stream_count = PLAYLIST_MAX_STREAMS
	list.set_list_stream(0, intro)
	for i in range(1, PLAYLIST_MAX_STREAMS):
		list.set_list_stream(i, body)
	list.loop = true
	list.fade_time = 0.0
	return list


# ------------------------------------------------------------------- effects

## Plays the sound picked for `hook`. `db_offset` lets a caller trim one play.
func play_sfx(hook: String, db_offset: float = 0.0) -> void:
	var h := hook_def(hook)
	if h.is_empty() or not has_library():
		return
	var now := Time.get_ticks_msec()
	var cd: float = h.get("cooldown", 0.0)
	if cd > 0.0 and now - int(_last_played.get(hook, -100000)) < int(cd * 1000.0):
		return
	var e := pick_entry(hook)
	if e.is_empty():
		return
	var s := _stream_for(e.get("wav", ""), e.get("ogg", ""), false)
	if s == null:
		return
	_last_played[hook] = now
	var p := _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % SFX_VOICES
	p.stream = s
	p.volume_db = float(h.get("db", 0.0)) + db_offset
	var jitter: float = h.get("jitter", 0.0)
	p.pitch_scale = 1.0 + randf_range(-jitter, jitter) if jitter > 0.0 else 1.0
	p.play()


# --------------------------------------------------------------------- music

var _round_for_music: int = 1

func tier_for_round(round_number: int) -> int:
	return clampi(1 + (maxi(1, round_number) - 1) / ROUNDS_PER_TIER, 1, MAX_TIER)

func play_menu_music() -> void:
	_start_music("menu_music", "menu", 1)

func play_game_music(round_number: int) -> void:
	_round_for_music = round_number
	_start_music("game_music", "game", tier_for_round(round_number))

## Called as the round number changes. The switch waits for the loop to come
## around so the arrangement changes on a downbeat, not mid bar.
func set_round(round_number: int) -> void:
	_round_for_music = round_number
	if not _music_key.begins_with("game:") or _music_entry["tiers"].is_empty():
		return
	var t := tier_for_round(round_number)
	if t != _music_tier:
		_pending_tier = t

func _start_music(hook: String, prefix: String, tier: int) -> void:
	if not has_library():
		return
	var e := pick_entry(hook)
	if e.is_empty():
		return
	var key := "%s:%s" % [prefix, e["id"]]
	if key == _music_key and _music.playing:
		# Already playing this tune (menu -> mode select -> menu): keep it going.
		if prefix == "game":
			_pending_tier = tier if tier != _music_tier else 0
		return
	var s := _music_stream(e, tier)
	if s == null:
		return
	_kill_music_tween()
	stop_preview()
	_music_key = key
	_music_entry = e
	_music_tier = tier
	_pending_tier = 0
	_music.stream = s
	_music.volume_db = 0.0
	_music.play()

func stop_music(fade: float = 0.0) -> void:
	_music_key = ""
	_pending_tier = 0
	if not _music.playing:
		return
	_kill_music_tween()
	if fade <= 0.0:
		_music.stop()
		return
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", -60.0, fade)
	_music_tween.tween_callback(_music.stop)

func _kill_music_tween() -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = null

## Applies a queued tier change at the loop point. All tiers of a track have
## the same length, so the new file carries on from the same position.
func _tick_tier_swap() -> void:
	if not _music.playing:
		_music_last_pos = 0.0
		return
	var pos := _music.get_playback_position() + AudioServer.get_time_since_last_mix()
	var wrapped := pos < _music_last_pos
	_music_last_pos = pos
	if _pending_tier == 0 or not wrapped or _music_key == "" or _music_entry.is_empty():
		return
	var s := _music_stream(_music_entry, _pending_tier)
	if s == null:
		_pending_tier = 0
		return
	_music_tier = _pending_tier
	_pending_tier = 0
	_music.stream = s
	_music.play(pos)


# ------------------------------------------------------------------- preview

## Plays one catalog entry for auditioning, without touching the picks.
func preview(id: String) -> void:
	if not by_id.has(id):
		return
	var e: Dictionary = by_id[id]
	stop_preview()
	var s: AudioStream
	if e["kind"] == "music":
		s = _music_stream(e, preview_tier)
	else:
		s = _stream_for(e.get("wav", ""), e.get("ogg", ""), false)
	if s == null:
		return
	_preview_entry_id = id
	_preview.stream = s
	_preview.bus = MUSIC_BUS if e["kind"] == "music" else SFX_BUS
	_preview.volume_db = 0.0
	_preview.pitch_scale = 1.0
	_preview.play()

func stop_preview() -> void:
	_preview_entry_id = ""
	if _preview != null and _preview.playing:
		_preview.stop()

func is_previewing(id: String) -> bool:
	return _preview_entry_id == id and _preview.playing


# ------------------------------------------------------------------ UI sounds

## Every Button in every scene clicks, hovers and toggles with the picked
## sounds, without each scene having to wire anything. A control opts out by
## setting the meta "no_ui_sound" (the Asset Viewer's audition buttons do,
## because they already play the sound they are auditioning).
func _on_node_added(node: Node) -> void:
	if not (node is BaseButton):
		return
	var b := node as BaseButton
	# `pressed` only fires for real presses, while `toggled` also fires when
	# code sets button_pressed, which would beep whenever a menu builds itself.
	b.pressed.connect(func() -> void:
		if b.has_meta("no_ui_sound"):
			return
		if b.toggle_mode:
			play_sfx("toggle_on" if b.button_pressed else "toggle_off")
		else:
			play_sfx("click"))
	b.mouse_entered.connect(func() -> void:
		if b.has_meta("no_ui_sound") or b.disabled:
			return
		play_sfx("hover"))
