# LevelManager.gd
extends Node

const USER_PATH := "user://level_data.json"

var _data: Dictionary = {
	"unlocked": [],
	"cleared": []
}

func _ready() -> void:
	_ensure_file()
	_load_data()


# ========== ПУБЛИЧНИ АПИ ФУНКЦИИ ==========

func add_unlocked(level_id: Variant) -> void:
	# Добавя ниво в unlocked; избягва дублиране и записва файла
	if not _data["unlocked"].has(level_id):
		_data["unlocked"].append(level_id)
		_save_data()

func add_cleared(level_id: Variant) -> void:
	# Добавя ниво в cleared; избягва дублиране и записва файла
	if not _data["cleared"].has(level_id):
		_data["cleared"].append(level_id)
		_save_data()

func is_unlocked(level_id: Variant) -> bool:
	return _data["unlocked"].has(level_id)

func is_cleared(level_id: Variant) -> bool:
	return _data["cleared"].has(level_id)

func get_unlocked() -> Array:
	# Връща копие, за да не се модифицира директно вътрешното състояние
	return _data["unlocked"].duplicate()

func get_cleared() -> Array:
	return _data["cleared"].duplicate()


# ========== ВЪТРЕШНИ ПОМОЩНИ ФУНКЦИИ ==========

func _ensure_file() -> void:
	if not FileAccess.file_exists(USER_PATH):
		_save_data()  
		add_unlocked("1")

func _load_data() -> void:
	if not FileAccess.file_exists(USER_PATH):
		return
	var f := FileAccess.open(USER_PATH, FileAccess.READ)
	if f == null:
		push_warning("Cannot open level data file for reading.")
		return
	var text := f.get_as_text()
	f.close()

	var parsed: Dictionary = JSON.parse_string(text) as Dictionary


	# Валидация на структурата; при проблем възстановява default и презаписва
	if typeof(parsed) == TYPE_DICTIONARY \
		and parsed.has("unlocked") and typeof(parsed["unlocked"]) == TYPE_ARRAY \
		and parsed.has("cleared") and typeof(parsed["cleared"]) == TYPE_ARRAY:
		_data = parsed
	else:
		push_warning("Level data file is corrupted or invalid. Recreating with defaults.")
		_data = { "unlocked": [], "cleared": [] }
		_save_data()

func _save_data() -> void:
	var f := FileAccess.open(USER_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Cannot open level data file for writing.")
		return
	# Красиво форматиран JSON (четим, но можеш да махнеш втория аргумент за по-компактен файл)
	f.store_string(JSON.stringify(_data, "\t"))
	f.close()
