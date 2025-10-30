# LevelManager.gd
extends Node

const USER_PATH := "user://level_data.json"

var _data: Dictionary = {
	"unlocked": [],
	"cleared": [],
	"visible": [],  
}

func _ready() -> void:
	_ensure_file()
	_load_data()


# ========== ПУБЛИЧНИ АПИ ФУНКЦИИ ==========

func add_unlocked(level_id: Variant) -> void:
	if not _data["unlocked"].has(level_id):
		_data["unlocked"].append(level_id)
		_save_data()

func add_cleared(level_id: Variant) -> void:
	if not _data["cleared"].has(level_id):
		_data["cleared"].append(level_id)
		_save_data()

func add_visible(level_id: Variant) -> void:   
	if not _data["visible"].has(level_id):
		_data["visible"].append(level_id)
		_save_data()

func is_unlocked(level_id: Variant) -> bool:
	return _data["unlocked"].has(level_id)

func is_cleared(level_id: Variant) -> bool:
	return _data["cleared"].has(level_id)

func is_visible(level_id: Variant) -> bool:      
	return _data["visible"].has(level_id)

func get_unlocked() -> Array:
	return _data["unlocked"].duplicate()

func get_cleared() -> Array:
	return _data["cleared"].duplicate()

func get_visible() -> Array:                    
	return _data["visible"].duplicate()


# ========== ВЪТРЕШНИ ПОМОЩНИ ФУНКЦИИ ==========

func _ensure_file() -> void:
	if not FileAccess.file_exists(USER_PATH):
		# Нов файл: по подразбиране само ниво "1" е видимо и отключено
		_data = { "unlocked": [], "cleared": [], "visible": [] }
		_save_data()
		add_unlocked("1")
		add_visible("1")

func _load_data() -> void:
	if not FileAccess.file_exists(USER_PATH):
		return
	var f := FileAccess.open(USER_PATH, FileAccess.READ)
	if f == null:
		push_warning("Cannot open level data file for reading.")
		return
	var text := f.get_as_text()
	f.close()

	var parsed: Dictionary = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Level data file is corrupted or invalid. Recreating with defaults.")
		_data = { "unlocked": [], "cleared": [], "visible": [] }
		_save_data()
		add_unlocked("1")
		add_visible("1")
		return

	# Базова валидация
	var ok := true
	for key in ["unlocked", "cleared"]:
		if not parsed.has(key) or typeof(parsed[key]) != TYPE_ARRAY:
			ok = false
	if not ok:
		push_warning("Level data structure invalid. Recreating with defaults.")
		_data = { "unlocked": [], "cleared": [], "visible": [] }
		_save_data()
		add_unlocked("1")
		add_visible("1")
		return

	# Миграция/валидиране за 'visible'
	var modified := false
	if not parsed.has("visible") or typeof(parsed["visible"]) != TYPE_ARRAY:
		parsed["visible"] = []
		modified = true
	# гарантираме, че поне "1" е видимо
	if not parsed["visible"].has("1"):
		parsed["visible"].append("1")
		modified = true

	_data = parsed
	if modified:
		_save_data()

func _save_data() -> void:
	var f := FileAccess.open(USER_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Cannot open level data file for writing.")
		return
	f.store_string(JSON.stringify(_data, "\t"))
	f.close()
	
