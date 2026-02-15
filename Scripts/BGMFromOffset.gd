extends AudioStreamPlayer
## BGMを指定位置から再生するスクリプト。MP3の場合はループ再生する。

@export var start_offset: float = 0.0

func _ready() -> void:
	if stream is AudioStreamMP3:
		stream.loop = true
	# _readyはシーン読み込み時に早すぎる可能性があるので、1フレーム待つ
	await get_tree().process_frame
	if stream and not playing:
		play(start_offset)
