extends CanvasLayer

signal closed()

@onready var slots_container: HBoxContainer = $Panel/Margin/VBox/SlotsContainer
@onready var total_power_label: Label = $Panel/Margin/VBox/SummaryBox/TotalPowerLabel
@onready var roster_container: HBoxContainer = $Panel/Margin/VBox/RosterBox/Scroll/RosterContainer
@onready var prompt_label: Label = $Panel/Margin/VBox/PromptLabel

var active_slot_idx: int = -1
var _slot_scroll: ScrollContainer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	GameData.party_updated.connect(_refresh_ui)
	var slot_parent := slots_container.get_parent() as Control
	var slot_index := slots_container.get_index()
	slot_parent.remove_child(slots_container)
	_slot_scroll = ScrollContainer.new()
	_slot_scroll.name = "SlotScroll"
	_slot_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_slot_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_slot_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_scroll.custom_minimum_size.y = 192
	slot_parent.add_child(_slot_scroll)
	slot_parent.move_child(_slot_scroll, slot_index)
	_slot_scroll.add_child(slots_container)
	slots_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	get_viewport().size_changed.connect(_fit_layout)
	_fit_layout()

func _fit_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var compact := viewport_size.y >= viewport_size.x and viewport_size.x < 600.0
	UiStyle.fit_centered_panel($Panel, Vector2(980.0, 720.0), Vector2(12.0, 12.0))
	var margin := $Panel/Margin as MarginContainer
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12 if compact else 20)
	$Panel/Margin/VBox.add_theme_constant_override("separation", 10 if compact else 16)
	$Panel/Margin/VBox/Header/Title.add_theme_font_size_override("font_size", 18 if compact else 24)
	$Panel/Margin/VBox/PromptLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$Panel/Margin/VBox/PromptLabel.add_theme_font_size_override("font_size", 12 if compact else 14)
	$Panel/Margin/VBox/SummaryBox/BonusLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$Panel/Margin/VBox/SummaryBox/BonusLabel.add_theme_font_size_override("font_size", 11 if compact else 14)
	if _slot_scroll:
		_slot_scroll.custom_minimum_size.y = 174 if compact else 192

func open():
	visible = true
	active_slot_idx = -1
	_refresh_ui()

func close():
	visible = false
	closed.emit()

func _refresh_ui():
	_render_slots()
	_render_roster()
	var power = GameData.get_party_combat_power()
	total_power_label.text = "⚔️ 파티 총 전투력: %d" % power
	if active_slot_idx == -1:
		prompt_label.text = "💡 교체할 슬롯을 클릭한 뒤, 아래 캐릭터를 선택하세요."
	else:
		prompt_label.text = "👉 [%d번 슬롯]에 배치할 캐릭터를 아래에서 선택하세요." % (active_slot_idx + 1)

func _render_slots():
	for child in slots_container.get_children():
		child.queue_free()
	
	for i in range(6):
		var cid = GameData.party_slots[i] if i < GameData.party_slots.size() else ""
		var c = GameData.characters.get(cid, {})
		
		var slot_column = VBoxContainer.new()
		slot_column.add_theme_constant_override("separation", 4)
		var card = Button.new()
		card.custom_minimum_size = Vector2(130, 180)
		card.toggle_mode = true
		card.button_pressed = (i == active_slot_idx)
		UiStyle.apply_button(card)
		card.add_theme_font_size_override("font_size", 13)
		
		var vbox = VBoxContainer.new()
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_theme_constant_override("separation", 6)
		
		var slot_tag = Label.new()
		slot_tag.text = "슬롯 " + str(i + 1)
		if i == GameData.leader_index:
			slot_tag.text = "★ 리더"
			slot_tag.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
		else:
			slot_tag.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
		slot_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_tag.add_theme_font_size_override("font_size", 12)
		vbox.add_child(slot_tag)
		
		var icon = Label.new()
		icon.text = c.get("icon", "❓")
		icon.add_theme_font_size_override("font_size", 36)
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(icon)
		
		var name_lbl = Label.new()
		name_lbl.text = c.get("name", "미편성")
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		vbox.add_child(name_lbl)
		
		var lvl_lbl = Label.new()
		lvl_lbl.text = "%s · 영구 능력치" % c.get("role", "")
		lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lvl_lbl.add_theme_font_size_override("font_size", 11)
		lvl_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8))
		vbox.add_child(lvl_lbl)
		
		card.add_child(vbox)
		var slot_i = i
		card.pressed.connect(func(): _on_slot_clicked(slot_i))
		slot_column.add_child(card)
		var leader_button = Button.new()
		leader_button.custom_minimum_size = Vector2(130, 30)
		leader_button.text = "대표로 지정" if i != GameData.leader_index else "현재 대표"
		UiStyle.apply_button(leader_button)
		leader_button.add_theme_font_size_override("font_size", 12)
		leader_button.disabled = i == GameData.leader_index
		leader_button.pressed.connect(func(): _on_leader_selected(slot_i))
		slot_column.add_child(leader_button)
		slots_container.add_child(slot_column)

func _render_roster():
	for child in roster_container.get_children():
		child.queue_free()
	
	for cid in GameData.characters:
		var c = GameData.characters[cid]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(120, 110)
		UiStyle.apply_button(btn)
		btn.add_theme_font_size_override("font_size", 13)
		
		var vbox = VBoxContainer.new()
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var icon = Label.new()
		icon.text = c.get("icon", "⚔️")
		icon.add_theme_font_size_override("font_size", 28)
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(icon)
		
		var n_lbl = Label.new()
		n_lbl.text = c.get("name", "") + " (" + c.get("grade", "R") + ")"
		n_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n_lbl.add_theme_font_size_override("font_size", 13)
		n_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		vbox.add_child(n_lbl)
		
		var in_party = GameData.party_slots.has(cid)
		var status_lbl = Label.new()
		if in_party:
			var idx = GameData.party_slots.find(cid)
			status_lbl.text = "편성중 (#%d)" % (idx + 1)
			status_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
		else:
			status_lbl.text = "대기"
			status_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_lbl.add_theme_font_size_override("font_size", 11)
		vbox.add_child(status_lbl)
		
		btn.add_child(vbox)
		btn.pressed.connect(func(): _on_roster_char_clicked(cid))
		roster_container.add_child(btn)

func _on_slot_clicked(idx: int):
	active_slot_idx = idx
	_refresh_ui()

func _on_leader_selected(idx: int):
	GameData.leader_index = idx
	GameData.recalculate_party_stats()
	GameData.party_updated.emit()
	GameData.data_updated.emit()
	GameData.save_to_disk()
	_refresh_ui()

func _on_roster_char_clicked(cid: String):
	if active_slot_idx != -1:
		GameData.set_party_member(active_slot_idx, cid)
		active_slot_idx = -1
		_refresh_ui()

func _on_close_pressed():
	close()

func _unhandled_input(event: InputEvent):
	if visible and not GameActions.is_capturing() and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
