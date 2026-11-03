extends "res://scripts/menu_modal.gd"

func _ready() -> void:
	super._ready()
	heading("leaderboard.title")
	var note := STYLE.label(I18n.t("leaderboard.local_only"), 15)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", STYLE.MUTED)
	content.add_child(note)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 8)
	content.add_child(rows)
	var records: Array = SaveStore.leaderboard()
	if records.is_empty():
		var empty := STYLE.label(I18n.t("leaderboard.empty"), 19)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var empty_card := PanelContainer.new()
		var empty_style := STYLE.plate(Color(STYLE.WOOL, 0.6), 20)
		empty_style.set_corner_radius_all(16)
		empty_style.border_color = Color(STYLE.STITCH, 0.5)
		empty_card.add_theme_stylebox_override("panel", empty_style)
		empty_card.add_child(empty)
		rows.add_child(empty_card)
	# Each record is a felt strip: a sewn rank button (gold/silver/bronze for the
	# podium), the name and a big stitched score on the right.
	var podium := [FeltKit.MUSTARD, Color("#b9b3a6"), Color("#c98a55")]
	for index in records.size():
		var record: Dictionary = records[index]
		var entry_card := PanelContainer.new()
		entry_card.name = "Record%d" % (index + 1)
		var entry_style := STYLE.plate(Color("#f7e3bd") if index % 2 == 0 else Color("#fbecd0"), 0)
		entry_style.set_corner_radius_all(14)
		entry_style.set_border_width_all(0)
		entry_style.content_margin_left = 58
		entry_style.content_margin_right = 16
		entry_style.content_margin_top = 8
		entry_style.content_margin_bottom = 10
		entry_card.add_theme_stylebox_override("panel", entry_style)
		var badge: Color = podium[index] if index < 3 else Color("#d9c29b")
		var rank := index + 1
		entry_card.material = FeltKit.felt_material()
		entry_card.draw.connect(func():
			FeltKit.draw_stitches(entry_card, Rect2(Vector2.ZERO, entry_card.size).grow(-4), 10, Color(STYLE.STITCH, 0.55), 1.4, 5, 4)
			var c := Vector2(30, entry_card.size.y * 0.5)
			entry_card.draw_circle(c + Vector2(0, 2), 17, Color(0.2, 0.08, 0.02, 0.22))
			entry_card.draw_circle(c, 17, badge.darkened(0.12))
			entry_card.draw_circle(c + Vector2(0, -1), 15, badge)
			FeltKit.draw_stitches(entry_card, Rect2(c - Vector2(12, 12), Vector2(24, 24)), 12, Color(FeltKit.THREAD, 0.9), 1.2, 3, 3)
			var font := STYLE.SMALL_HEADING
			var label := str(rank)
			var fs := 18
			var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			entry_card.draw_string_outline(font, c + Vector2(-tw * 0.5, 7), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, badge.darkened(0.45))
			entry_card.draw_string(font, c + Vector2(-tw * 0.5, 7), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#fff6e2")))
		rows.add_child(entry_card)
		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation", 0)
		entry_card.add_child(entry)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 12)
		entry.add_child(top)
		var who := STYLE.label(str(record.get("player_name", "")), 20)
		who.add_theme_font_override("font", STYLE.BOLD)
		who.add_theme_color_override("font_color", STYLE.COCOA)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		who.tooltip_text = I18n.t("leaderboard.row", {"rank": rank, "name": record.get("player_name", ""), "score": record.get("score", 0)})
		top.add_child(who)
		var points := Label.new()
		points.text = "%06d" % int(record.get("score", 0))
		STYLE.display(points, 26, Color("#fff6e2"), STYLE.COCOA, 6)
		points.add_theme_font_override("font", STYLE.trimmed(STYLE.SMALL_HEADING, 26, 0.24, 0.3))
		top.add_child(points)
		var stage_key := "stage." + str(record.get("stage", "sunlit_nook")) + ".name"
		var stage_name := I18n.t(stage_key)
		if stage_name == stage_key: stage_name = I18n.t("leaderboard.stage_unknown")
		var detail := STYLE.label(I18n.t("leaderboard.detail", {
			"stage": stage_name,
			"outcome": I18n.t("leaderboard.outcome." + str(record.get("outcome", "defeat"))),
			"seconds": roundi(float(record.get("duration", 0))),
			"mode": I18n.t("leaderboard.standard" if record.get("eligible", true) else "leaderboard.custom"),
		}), 14)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_theme_color_override("font_color", STYLE.MUTED)
		entry.add_child(detail)
	add_close_button()
