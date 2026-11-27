extends SceneTree
## Run with a fresh user directory. This test activates a character and plays a run.

var failures := 0
var manager: Node
var transition: Node


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> bool:
	if not condition:
		failures += 1
		printerr("MOBILE INPUT FAIL: ", message)
	return condition


func _find_button(parent: Node, caption: String) -> Button:
	for child in parent.find_children("*", "Button", true, false):
		var button := child as Button
		if button.is_visible_in_tree() and caption in [button.text, button.accessibility_name, button.tooltip_text]:
			return button
	_check(false, "visible button missing: " + caption)
	return null


func _center(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas() * (control.size * 0.5)


func _touch(viewport_position: Vector2, down: bool, index: int = 0, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = root.get_final_transform() * viewport_position
	event.pressed = down
	event.canceled = canceled
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _tap(control: Control) -> void:
	if not is_instance_valid(control):
		_check(false, "tap target missing")
		return
	await _tap_at(_center(control))


func _tap_at(point: Vector2) -> void:
	_touch(point, true)
	await process_frame
	_touch(point, false)
	await process_frame
	await process_frame


func _wait_for_scene(path: String) -> bool:
	var deadline := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline:
		if not transition.is_transitioning:
			return _check(current_scene != null and current_scene.scene_file_path.ends_with(path), "screen did not open: " + path)
		await process_frame
	return _check(false, "screen transition timed out: " + path)


func _run() -> void:
	manager = root.get_node("GameManager")
	transition = root.get_node("SceneTransition")
	var data := root.get_node("GameData")
	data.input_mode = "mobile"
	if "--narrow" in OS.get_cmdline_user_args():
		root.size = Vector2i(360, 800)
		root.content_scale_size = Vector2i(360, 800)
	if "--battle-only" in OS.get_cmdline_user_args():
		manager.go_to_battle("stage_1")
		if await _wait_for_scene("stage_grassland.tscn"):
			await _check_battle()
		print("MOBILE INPUT COMPLETE: ", failures)
		quit(0 if failures == 0 else 1)
		return
	change_scene_to_file("res://scenes/ui/title_screen.tscn")
	await scene_changed
	await process_frame
	var title := current_scene
	if "--title-only" in OS.get_cmdline_user_args():
		if "--resize-title" in OS.get_cmdline_user_args():
			await _check_title_resizing(title)
		await _check_title_entry(title)
		print("TITLE ENTRY COMPLETE: ", failures)
		quit(0 if failures == 0 else 1)
		return
	await _tap(_find_button(title, "환경 설정"))
	var settings := title.get_node("SettingsUI")
	_check(settings.visible, "title settings tap did not work")
	await _tap(_find_button(settings, "완료"))
	_check(not settings.visible, "settings done tap did not work")
	await _tap(_find_button(title, "게스트로 시작"))
	if not await _wait_for_scene("character_select.tscn"):
		quit(1)
		return
	var selection := current_scene
	var info := _find_button(selection, "STR 상세 능력치")
	await _tap(info)
	var feedback := root.get_node("UiFeedback")
	_check(feedback._detail_root != null and feedback._detail_root.visible, "stat details tap did not work")
	if feedback._detail_root != null and feedback._detail_root.visible:
		await _tap(_find_button(feedback._detail_root, "확인"))
		_check(not feedback._detail_root.visible, "stat details did not close")
	await _tap(_find_button(selection, selection.new_character_button.text))
	if _check(selection.find_child("Approved_create", true, false) != null, "new character tap did not open creation"):
		var create := _find_button(selection, "캐릭터 생성")
		_check(create != null and create.disabled, "empty character name should disable creation")
		await _tap(selection.creation_name)
		_check(selection.creation_name.has_focus(), "name field did not receive touch focus")
		selection.creation_name.text = "터치 테스트"
		selection.creation_name.text_changed.emit(selection.creation_name.text)
		await create_timer(0.10).timeout
		await _tap(create)
		_check(data.get_profile_at_slot(1).get("name", "") == "터치 테스트", "valid character was not created by tapping")
	var profile: Dictionary = data.get_profile_at_slot(0)
	var slot: Button
	for button in selection.find_children("*", "Button", true, false):
		if button.is_visible_in_tree() and button.text.begins_with("⚔  " + str(profile.get("name", ""))):
			slot = button
			break
	await _tap(slot)
	if not transition.is_transitioning:
		await _tap(slot)
	if not await _wait_for_scene("village_lobby.tscn"):
		quit(1)
		return
	await _check_village()
	if not await _wait_for_scene("stage_grassland.tscn"):
		quit(1)
		return
	await _check_battle()
	print("MOBILE INPUT COMPLETE: ", failures)
	quit(0 if failures == 0 else 1)


func _check_title_entry(title: Node) -> void:
	var guest := _find_button(title, "게스트로 시작")
	if guest == null:
		return
	if "--native-touch" in OS.get_cmdline_user_args():
		Input.emulate_mouse_from_touch = false
	var point := _title_art_point(title, Vector2(279, 647))
	_touch(point, true)
	_touch(point, false, 0, true)
	await process_frame
	_check(not transition.is_transitioning and current_scene == title, "canceled guest press started a scene transition")
	var started_at := Time.get_ticks_msec()
	await _tap_at(point)
	_check(transition.is_transitioning or current_scene != title, "guest tap did not start a scene transition")
	if await _wait_for_scene("character_select.tscn"):
		print("TITLE ENTRY ELAPSED MS: ", Time.get_ticks_msec() - started_at)
		_check(current_scene.find_child("Approved_select", true, false) != null, "character selection did not finish building")
		_check(not paused, "character selection remained paused")


func _title_art_point(title: Node, point: Vector2) -> Vector2:
	var reference := title.get_node("Approved_title")
	var artwork := reference.page.get_child(0) as TextureRect
	return artwork.get_global_transform_with_canvas() * point


func _check_title_resizing(title: Node) -> void:
	var settings := title.get_node("SettingsUI")
	for window_size in [Vector2i(1280, 720), Vector2i(720, 1280), Vector2i(1080, 2400), Vector2i(480, 960)]:
		root.size = window_size
		await process_frame
		await process_frame
		await _tap_at(_title_art_point(title, Vector2(279, 743)))
		_check(settings.visible, "settings tap missed artwork after resize to %s" % str(window_size))
		if settings.visible:
			await _tap(_find_button(settings, "완료"))
		_check(not settings.visible, "settings did not close after resize to %s" % str(window_size))
		var guest := _find_button(title, "게스트로 시작")
		if guest != null:
			_check(guest.get_global_rect().has_point(_title_art_point(title, Vector2(279, 647))), "guest button did not align with artwork after resize to %s" % str(window_size))
		print("TITLE WINDOW / VIEWPORT: ", root.size, " / ", root.get_visible_rect().size)


func _check_village() -> void:
	var village := current_scene
	var hud := village.get_node("VillageHUD")
	await _tap(_find_button(hud, "장비"))
	_check(hud.active_screen_id == "inventory", "village equipment tap did not work")
	if hud.active_screen_id == "inventory":
		var inventory: Node = hud.screens.inventory
		await _tap(_find_button(inventory, "증강 카드"))
		var catalog := inventory.find_child("Approved_catalog", true, false) as Control
		_check(catalog != null and catalog.is_visible_in_tree(), "augment tab tap did not work")
		await _tap(_find_button(inventory, "×"))
		_check(hud.active_screen_id.is_empty() and not paused, "equipment close tap did not work")
	await _tap(hud.auto_move_button)
	_check(hud.fast_travel_root.visible, "auto travel tap did not work")
	hud.fast_travel_root.hide()
	await _tap(hud.objective_button)
	# Opening the dungeon prep directly through the village's action route
	# avoids waiting on navigation distance in this input test.
	if not hud.battle_prep_ui.visible:
		root.get_node("GameActions").trigger("battle_start")
	await process_frame
	await _tap(_find_button(hud.battle_prep_ui, hud.battle_prep_ui.start_button.text))


func _check_battle() -> void:
	var stage := current_scene
	var cards := stage.get_node("LevelUpPanel")
	if not _check(cards.has_method("show_upgrades"), "start card panel failed to load"):
		return
	for picks in range(10, 0, -1):
		if not _check(manager.starting_draft_picks == picks and cards.visible, "start cards did not advance by one"):
			break
		_check(paused and manager.current_state == manager.GameState.LEVEL_UP and is_zero_approx(manager.battle_time), "combat advanced during start card selection")
		_check(cards.title_label.text == "시작 카드 · %d / 10" % (11 - picks), "start card title did not show the current pick")
		if not _check(cards.cards_container.get_child_count() >= 3, "start card choices were not shown"):
			break
		await _tap(cards.cards_container.get_child(0) as Button)
	if not _check(not paused and not cards.visible and manager.starting_draft_picks == 0 and manager.current_state == manager.GameState.PLAYING, "combat did not start after the draft"):
		return
	var hud := stage.get_node("HUD")
	await _tap(hud.pause_button)
	_check(manager.current_state == manager.GameState.PAUSED, "combat pause tap did not work")
	var pause_menu := stage.get_node("PauseMenu")
	await _tap(_find_button(pause_menu, "전투 계속"))
	_check(manager.current_state == manager.GameState.PLAYING, "combat resume tap did not work")
	var skills := stage.get_node("Player/SkillManager")
	_check(skills.auto_battle_enabled, "auto cast is off at start")
	await _tap(hud.auto_battle_button)
	_check(not skills.auto_battle_enabled, "auto cast toggle tap did not work")
	var q := hud._skill_panels["q"] as Control
	var q_center := _center(q)
	for panel in hud._skill_panels.values():
		_check(root.get_visible_rect().encloses(panel.get_global_rect()), "combat skill slot extends beyond the viewport")
	var feedback := root.get_node("UiFeedback")
	await feedback.show_tooltip("입력 검사", "설명창이 아래 스킬 슬롯의 입력을 가리면 안 됩니다.", q_center)
	feedback._tooltip_panel.position = q_center - Vector2(20, 20)
	var auto_q: bool = skills.is_skill_auto_enabled("q")
	_touch(q_center, true)
	await create_timer(0.65).timeout
	_check(is_zero_approx(skills.get_cooldown("q")), "long press cast Q before release")
	_check(skills.is_skill_auto_enabled("q") != auto_q, "long press did not toggle Q auto cast")
	_touch(q_center, false)
	await process_frame
	_check(is_zero_approx(skills.get_cooldown("q")), "long press cast Q on release")
	_touch(q_center, true)
	_touch(q_center, false, 0, true)
	await process_frame
	_check(is_zero_approx(skills.get_cooldown("q")), "canceled touch cast Q")
	await _tap(q)
	_check(skills.get_cooldown("q") > 0, "tap did not cast Q")

	var data := root.get_node("GameData")
	for row in SurvivalCardDatabase.CARD_ROWS:
		data.survival_card_counts[str(row[0])] = 10000
	manager.level_card_picks = 1
	manager.enter_level_up()
	await process_frame
	await process_frame
	_check(not paused and not cards.visible, "exhausted augment pool trapped the player in a paused screen")
	manager.game_over()
	await process_frame
	var result := stage.get_node("GameOverScreen")
	await _tap(_find_button(result, "상세 전투 기록"))
	_check(result.legacy_layout.visible, "combat result details tap did not work")
