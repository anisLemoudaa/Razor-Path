extends "res://scripts/menu_modal.gd"

const ANIS := preload("res://scripts/anis_character.gd")
var selected_skin := "default"

func _ready() -> void:
	super._ready()
	heading("المتجر")
	var balance := STYLE.label("عملات 1,250", 18)
	balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(balance)
	var tabs := STYLE.label("السكينات     تأثير الموت     ألوان العلم     أثر الحركة", 16)
	tabs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tabs.add_theme_color_override("font_color", STYLE.MUTED)
	content.add_child(tabs)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	content.add_child(grid)
	for skin_id: String in ANIS.skin_catalog().keys():
		var data: Dictionary = ANIS.skin_catalog()[skin_id]
		var card := Button.new()
		card.text = "%s\n%s" % [data.name, data.rarity]
		card.custom_minimum_size = Vector2(170, 92)
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_theme_font_override("font", STYLE.BOLD)
		card.add_theme_font_size_override("font_size", 16)
		card.add_theme_color_override("font_color", STYLE.INK)
		var fill: Color = data.primary
		var edge: Color = data.accent
		FeltKit.felt_button(card, &"tile", fill, edge, 14.0, 8.0)
		card.pressed.connect(func(): _equip(skin_id, card))
		grid.add_child(card)
	var preview := ANIS.new()
	preview.name = "SkinPreview"
	preview.custom_minimum_size = Vector2(0, 132)
	preview.configure(selected_skin)
	content.add_child(preview)
	var action := STYLE.button("شراء 350")
	action.pressed.connect(func(): _show_status(action, "تم تجهيز السكن المختار"))
	content.add_child(action)
	add_close_button()

func _equip(skin_id: String, card: Button) -> void:
	selected_skin = skin_id
	card.grab_focus()
	for child in content.get_children():
		if child.name == "SkinPreview" and child is AnisCharacter:
			child.configure(selected_skin)

func _show_status(button: Button, text: String) -> void:
	button.text = text
	button.disabled = true
