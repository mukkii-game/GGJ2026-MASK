@tool
extends Node
## キャラ絵からエフェクト用画像を生成する（赤・白・青・黄：透明以外をその色で塗りつぶし）
## 使い方：このノードをルートにしたシーンを開き、run_generate を true にしてシーンを実行（F6）するか、
## エディタで run_generate を true にして保存すると _ready で生成される

@export var run_generate: bool = false

const EFFECT_COLORS := {
	"red": Color(1.0, 0.2, 0.2, 1.0),
	"white": Color(1.0, 1.0, 1.0, 1.0),
	"blue": Color(0.25, 0.5, 1.0, 1.0),
	"yellow": Color(1.0, 1.0, 0.3, 1.0),
}
const SOURCE_DIRS := [
	"res://Art/Sprites/",
	"res://Scenes/Player/Sprite/",
	"res://Scenes/NPC's/Enemy/Sprites/",
]
const OUTPUT_DIR := "res://Art/Sprites/Effect/"
const ALPHA_THRESHOLD := 0.01

func _ready() -> void:
	if not run_generate:
		if Engine.is_editor_hint():
			print("GenerateEffectSprites: run_generate を true にしてシーンを実行(F6)するとエフェクト用画像を生成します。")
		return
	run_generate = false
	generate_all()


func generate_all() -> void:
	if not DirAccess.dir_exists_absolute(OUTPUT_DIR):
		var err := DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
		if err != OK:
			push_error("GenerateEffectSprites: Failed to create output dir: %s" % OUTPUT_DIR)
			return
	var collected: PackedStringArray = PackedStringArray()
	for dir_path in SOURCE_DIRS:
		if not DirAccess.dir_exists_absolute(dir_path):
			continue
		var dir := DirAccess.open(dir_path)
		if not dir:
			continue
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.get_extension().to_lower() == "png" and not file_name.begins_with("effect_"):
				collected.append(dir_path.path_join(file_name))
			file_name = dir.get_next()
		dir.list_dir_end()
	for path in collected:
		generate_effect_variants(path)
	print("GenerateEffectSprites: Done. Processed %d images." % collected.size())


func generate_effect_variants(source_path: String) -> void:
	var img := Image.new()
	var err := img.load(source_path)
	if err != OK:
		push_warning("GenerateEffectSprites: Could not load: %s" % source_path)
		return
	var w := img.get_width()
	var h := img.get_height()
	var base_name := source_path.get_file().get_basename()
	for color_name in EFFECT_COLORS:
		var effect_color: Color = EFFECT_COLORS[color_name]
		var out_img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var c: Color = img.get_pixel(x, y)
				if c.a > ALPHA_THRESHOLD:
					out_img.set_pixel(x, y, Color(effect_color.r, effect_color.g, effect_color.b, c.a))
				else:
					out_img.set_pixel(x, y, Color(0, 0, 0, 0))
		var out_path := OUTPUT_DIR.path_join("effect_%s_%s.png" % [color_name, base_name])
		var save_err := out_img.save_png(out_path)
		if save_err != OK:
			push_warning("GenerateEffectSprites: Could not save: %s" % out_path)
		else:
			print("  wrote ", out_path)
