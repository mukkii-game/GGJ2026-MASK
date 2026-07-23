extends Node

#This class preloads all of our sound effects so that they can be played at a momets notice
#region Preloaded Sounds
const PLAYER_ATTACK_HIT = preload("res://Art/Audio/Effects/AttackHit.ogg")
const PLAYER_ATTACK_SWING = preload("res://Art/Audio/Effects/AttackSwing.ogg")
const ENEMY_HIT = preload("res://Art/Audio/Effects/Enemy_hit.ogg")
const BLOODY_HIT = preload("res://Art/Audio/Effects/bloody_hit.ogg")
const COIN_PICK = preload("res://Art/Audio/Effects/coin_pick.ogg")
const QUEST_SOUND = preload("res://Art/Audio/Effects/QuestSound.ogg")
## パワーエサ取得時（バクッ／ボワーン／強くなった系）。差し替え用に別定数
const POWER_BAIT_GET = preload("res://Art/Audio/Effects/QuestSound.ogg")
## 場外KOブラスト（撃破して場外へ吹っ飛ばしたとき）
const KILL_MASK = preload("res://Art/Audio/Effects/kill_mask.wav")
## 警告音（S4ボスの号令予告など）
const MASK_WARNING = preload("res://Art/Audio/Effects/mask_ambient1.wav")

const BGM_BATTLE := preload("res://Art/Audio/MainThemeNew.mp3")
const BGM_INTRO := preload("res://Art/Audio/Intro.mp3")
const BGM_ENDING_PATH := "res://Art/Audio/Ending.mp3"
const BGM_FALLBACK_PATH := "res://Art/Audio/MainTheme.mp3"
#endregion

var audio_players = []
var max_players = 24
var starting_players = 6
var _steal_index: int = 0

var _bgm_player: AudioStreamPlayer
var _bgm_finished_callback: Callable = Callable()

func _ready() -> void:
	initiate_audio_stream()
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	add_child(_bgm_player)
	_bgm_player.finished.connect(_on_bgm_finished)

func _configure_loop(stream: AudioStream, loop: bool) -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = loop
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop

func play_bgm(stream: AudioStream, volume_db: float = -8.0, loop: bool = true, start_offset: float = 0.0, on_finished: Callable = Callable()) -> void:
	if stream == null:
		return
	_configure_loop(stream, loop)
	_bgm_finished_callback = on_finished
	_bgm_player.volume_db = volume_db
	_bgm_player.stream = stream
	_bgm_player.play(start_offset)
	if not _bgm_player.playing:
		_bgm_player.call_deferred("play", start_offset)

func play_battle_bgm() -> void:
	if _bgm_player.stream == BGM_BATTLE and _bgm_player.playing:
		return
	play_bgm(BGM_BATTLE, -8.0, true, 0.0)

func play_intro_bgm(on_finished: Callable = Callable()) -> void:
	play_bgm(BGM_INTRO, 0.0, false, 0.0, on_finished)

func play_ending_bgm() -> void:
	var stream: AudioStream = null
	if ResourceLoader.exists(BGM_ENDING_PATH):
		stream = load(BGM_ENDING_PATH) as AudioStream
	elif ResourceLoader.exists(BGM_FALLBACK_PATH):
		stream = load(BGM_FALLBACK_PATH) as AudioStream
	if stream:
		play_bgm(stream, 0.0, true, 0.0)

func stop_bgm() -> void:
	_bgm_player.stop()
	_bgm_finished_callback = Callable()

## クリア演出用: カン・カン・カン（ゴング3回）
func play_gong_triple() -> void:
	var stream := _load_gong_stream()
	if stream == null:
		return
	_play_gong_burst(stream, 0.0)
	_play_gong_burst(stream, 0.38)
	_play_gong_burst(stream, 0.76)

## 登場画面など: ゴング1回
func play_gong_once() -> void:
	var stream := _load_gong_stream()
	if stream == null:
		return
	_play_gong_burst(stream, 0.0)

func _load_gong_stream() -> AudioStream:
	for path in ["res://Art/Audio/Effects/gong.ogg", "res://Art/Audio/Effects/gong.wav", "res://Art/Audio/Effects/mask_ambient1.wav", "res://Art/Audio/Effects/kill_mask.wav"]:
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null

func _play_gong_burst(stream: AudioStream, delay_sec: float) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = 2.0
	add_child(player)
	if delay_sec <= 0.0:
		player.play()
		player.finished.connect(player.queue_free)
	else:
		var t := get_tree().create_timer(delay_sec)
		t.timeout.connect(func() -> void:
			if is_instance_valid(player):
				player.play()
				player.finished.connect(player.queue_free)
		)

func _on_bgm_finished() -> void:
	if _bgm_finished_callback.is_valid():
		var cb := _bgm_finished_callback
		_bgm_finished_callback = Callable()
		cb.call()

#Play a sound, call this function from anywhere
#offset lets you start the sound with an offset, like starting the sound at 0.1s into the clip
#Arguments(audio_clip, offset, volume)
#Example when calling this function:
#AudioManager.play_sound(AudioManager.PLAYER_ATTACK_SWING, 0.25, 1)
func play_sound(audiostream : AudioStream, offset : float, volume : float):
	#Loop through and find an available player currently not playing a sound
	var available_player = null
	for player in audio_players:
		if not player.is_playing():
			available_player = player
			break

	# If no player is available and we havent reached the maximum amount of players, create a new one
	if available_player == null and audio_players.size() < max_players:
		available_player = AudioStreamPlayer.new()
		audio_players.append(available_player)
		add_child(available_player)

	# 上限に達していて全員再生中なら、ラウンドロビンで上書き（常に先頭を潰さない）
	if available_player == null:
		if audio_players.is_empty():
			return
		_steal_index = (_steal_index + 1) % audio_players.size()
		available_player = audio_players[_steal_index]

	available_player.stream = audiostream
	available_player.pitch_scale = randf_range(0.9, 1.1)
	available_player.volume_db = volume
	available_player.play(offset)

#Instantiate audiostreams into the scene
func initiate_audio_stream():
	for i in range(starting_players):
		var player = AudioStreamPlayer.new()
		audio_players.append(player)
		add_child(player)
