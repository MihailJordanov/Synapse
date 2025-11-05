# ItemManager.gd
extends Node

const USER_PATH := "user://item_data.json"

const KEY_COINS := "coins"
const KEY_VISUAL_BONUS := "visual_bonus"
const KEY_DECK_LEVEL := "deck_level"
const KEY_PLAYER_POINTS_LEVEL := "player_points_level"
const KEY_ENEMY_POINTS_LEVEL := "enemy_points_level"

const DEFAULTS := {
	"coins": 0,
	"visual_bonus": 0,
	"deck_level": 0,
	"player_points_level": 0,
	"enemy_points_level": 0,
}

var _data: Dictionary = {}

signal value_changed(key: String, value: int)

func _ready() -> void:
	_load_or_create()
	var changed := _ensure_schema(DEFAULTS)
	if changed:
		_save()

# ---------- Публични API ----------

func get_value(key: String) -> int:
	_ensure_key(key) 
	return int(_data[key])

func set_value(key: String, value: int) -> void:
	_ensure_key(key)
	_data[key] = int(max(0, value))
	_save()
	emit_signal("value_changed", key, _data[key])

func add(key: String, amount: int = 1) -> int:
	_ensure_key(key)
	_data[key] = int(max(0, int(_data[key]) + int(amount)))
	_save()
	emit_signal("value_changed", key, _data[key])
	return _data[key]


func remove(key: String, amount: int = 1) -> int:
	_ensure_key(key)
	_data[key] = int(max(0, int(_data[key]) - int(amount)))
	_save()
	emit_signal("value_changed", key, _data[key])
	return _data[key]


func get_all() -> Dictionary:
	return _data.duplicate(true)


func register_item(key: String, default_value: int = 0) -> void:
	if not _data.has(key):
		_data[key] = int(max(0, default_value))
		_save()
		emit_signal("value_changed", key, _data[key])


func reset_to_defaults() -> void:
	_data = DEFAULTS.duplicate(true)
	_save()
	for k in _data.keys():
		emit_signal("value_changed", String(k), _data[k])

# ---------- Вътрешни помощни ----------

func _ensure_key(key: String) -> bool:
	if not _data.has(key):
		_data[key] = 0
		_save()
		emit_signal("value_changed", key, 0)
		return true
	return false

func _ensure_schema(defaults: Dictionary) -> bool:
	var changed := false
	for k in defaults.keys():
		if not _data.has(k):
			_data[k] = int(max(0, defaults[k]))
			changed = true
	return changed

func _load_or_create() -> void:
	if FileAccess.file_exists(USER_PATH):
		var file := FileAccess.open(USER_PATH, FileAccess.READ)
		if file:
			var text := file.get_as_text()
			var parsed: Variant = JSON.parse_string(text)
			if typeof(parsed) == TYPE_DICTIONARY:
				_data = parsed as Dictionary
			else:
				_data = DEFAULTS.duplicate(true)
				_save()
		else:
			_data = DEFAULTS.duplicate(true)
			_save()
	else:
		_data = DEFAULTS.duplicate(true)
		_save()

func _save() -> void:
	var file := FileAccess.open(USER_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_data, "\t"))


# --- Money ---
func add_money(amount: int = 1) -> int:
	return add(KEY_COINS, amount)

func remove_money(amount: int = 1) -> int:
	return remove(KEY_COINS, amount)

func get_money() -> int:
	return get_value(KEY_COINS)

# --- Visual Bonus ---
func add_visual_bonus(amount: int = 1) -> int:
	return add(KEY_VISUAL_BONUS, amount)

func remove_visual_bonus(amount: int = 1) -> int:
	return remove(KEY_VISUAL_BONUS, amount)

func get_visual_bonus() -> int:
	return get_value(KEY_VISUAL_BONUS)

# --- Deck Level ---
func add_deck_level(inc: int = 1) -> int:
	return add(KEY_DECK_LEVEL, inc)

func remove_deck_level(dec: int = 1) -> int:
	return remove(KEY_DECK_LEVEL, dec)

func get_deck_level() -> int:
	return get_value(KEY_DECK_LEVEL)

# --- Player Points Level ---
func add_player_points_level(inc: int = 1) -> int:
	return add(KEY_PLAYER_POINTS_LEVEL, inc)

func remove_player_points_level(dec: int = 1) -> int:
	return remove(KEY_PLAYER_POINTS_LEVEL, dec)

func get_player_points_level() -> int:
	return get_value(KEY_PLAYER_POINTS_LEVEL)

# --- Enemy Points Level ---
func add_enemy_points_level(inc: int = 1) -> int:
	return add(KEY_ENEMY_POINTS_LEVEL, inc)

func remove_enemy_points_level(dec: int = 1) -> int:
	return remove(KEY_ENEMY_POINTS_LEVEL, dec)

func get_enemy_points_level() -> int:
	return get_value(KEY_ENEMY_POINTS_LEVEL)
