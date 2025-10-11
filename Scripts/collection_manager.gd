extends Node

const RES_PATH  := "res://Data/collection_data.json"
const USER_PATH := "user://collection_data.json"

# В памет:
# cards: map по id -> { id, self_element, self_kind, self_attack_style, card_texture,
#                       connect_element, connect_kind, connect_attack_style }
var cards: Dictionary = {}            # id (int или String) -> Dictionary (карта)
var unlocked: Array = []              # [id, id, ...]
var deck: Array = []                  # [id, id, ...]

func _ready() -> void:
	_load_all()

# ------------------------------------------------------------
# ПУБЛИЧНИ API
# ------------------------------------------------------------
func get_card(id) -> Dictionary:
	id = _norm_id(id)
	return cards.get(id, {})

func get_all_cards() -> Array:
	# връща списък от карти (Dictionary)
	return cards.values()

func is_unlocked(id) -> bool:
	id = _norm_id(id)
	return unlocked.has(id)

func in_deck(id) -> bool:
	id = _norm_id(id)
	return deck.has(id)

func unlock(id) -> bool:
	id = _norm_id(id)
	if not cards.has(id):
		push_warning("unlock(): No such card id: %s" % [id])
		return false
	if unlocked.has(id):
		return true
	unlocked.append(id)
	_save_user()
	return true

func add_to_deck(id) -> bool:
	id = _norm_id(id)
	if not is_unlocked(id):
		push_warning("add_to_deck(): card %s is not unlocked" % [id])
		return false
	if deck.has(id):
		return true
	deck.append(id)
	_save_user()
	return true

func remove_from_deck(id) -> bool:
	id = _norm_id(id)
	if deck.has(id):
		deck.erase(id)
		_save_user()
		return true
	return false


func reload() -> void:
	_load_all()

# ------------------------------------------------------------
# Вътрешно зареждане/съхранение
# ------------------------------------------------------------
func _load_all() -> void:
	var res_data := _load_json(RES_PATH)
	if res_data.is_empty():
		push_error("collection_data.json in res:// is missing or invalid.")
		return

	if res_data == null:
		push_error("collection_data.json in res:// is missing or invalid.")
		return

	# Ако няма user файл – създай го от res (cards) + празни unlocked/deck
	if not FileAccess.file_exists(USER_PATH):
		cards    = _cards_to_map(res_data.get("cards", []))
		unlocked = []
		deck     = []
		_save_user()
		return

	# Има user файл → синхронизирай cards с res, запази unlocked/deck
	var user_data := _load_json(USER_PATH)
	if user_data == null:
		# ако файлът е счупен, възстанови
		cards    = _cards_to_map(res_data.get("cards", []))
		unlocked = []
		deck     = []
		_save_user()
		return

	# базови стойности от user
	var user_cards_map := _cards_to_map(user_data.get("cards", []))
	unlocked = user_data.get("unlocked", [])
	deck     = user_data.get("deck", [])

	# -> синхронизирай карти от res (OVERRIDE/ADD)
	var res_cards_arr: Array = res_data.get("cards", [])
	for c in res_cards_arr:
		var cid = _norm_id(c.get("id"))
		if cid == null:
			continue
		# винаги копирай последната дефиниция от res върху user
		user_cards_map[cid] = _normalize_card_dict(c)

	# (по избор) ако не искаш „стари“ карти, които вече не съществуват в res, да останат:
	# user_cards_map = _filter_only_res_ids(user_cards_map, res_cards_arr)

	cards = user_cards_map
	_save_user()  # запиши обратно за да добавим/ъпдейтнем новите карти в user

func _save_user() -> void:
	var data := {
		"cards": cards.values(),   # в JSON пазим като списък, не като map
		"unlocked": unlocked,
		"deck": deck,
	}
	var f := FileAccess.open(USER_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))  # pretty
		f.close()

# ------------------------------------------------------------
# Помощни
# ------------------------------------------------------------
func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var p := JSON.new()
	var err := p.parse(txt)
	if err != OK:
		push_error("JSON parse error in %s: %s at line %d" % [path, p.get_error_message(), p.get_error_line()])
		return {}
	var data = p.data
	return data if typeof(data) == TYPE_DICTIONARY else {}




func _cards_to_map(arr: Array) -> Dictionary:
	var m := {}
	for c in arr:
		if typeof(c) == TYPE_DICTIONARY and c.has("id"):
			var cid = _norm_id(c["id"])
			if cid != null:
				m[cid] = _normalize_card_dict(c)
	return m

func _normalize_card_dict(c: Dictionary) -> Dictionary:
	# Подсигурява липсващи полета; имената са по твоята спецификация
	return {
		"id": _norm_id(c.get("id")),
		"self_element":          c.get("self_element", null),
		"self_kind":             c.get("self_kind", null),
		"self_attack_style":     c.get("self_attack_style", null),
		"card_texture":          c.get("card_texture", ""),
		"connect_element":       c.get("connect_element", null),
		"connect_kind":          c.get("connect_kind", null),
		"connect_attack_style":  c.get("connect_attack_style", null),
	}

func _norm_id(v) -> Variant:
	if v == null:
		return null
	if typeof(v) == TYPE_INT:
		return v
	if typeof(v) == TYPE_FLOAT:
		return int(v)
	if typeof(v) == TYPE_STRING:
		if v.is_valid_int():
			return int(v)
		if v.is_valid_float():
			return int(float(v))
	return str(v)


# опционално – ако искаш да премахваш от user карти, които вече не съществуват в res
func _filter_only_res_ids(user_map: Dictionary, res_arr: Array) -> Dictionary:
	var keep := {}
	var res_ids := {}
	for c in res_arr:
		var cid = _norm_id(c.get("id"))
		if cid != null:
			res_ids[cid] = true
	for k in user_map.keys():
		if res_ids.has(k):
			keep[k] = user_map[k]
	return keep
