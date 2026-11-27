extends SceneTree

## Run with --script against the project or an exported pack and a fresh user directory.
## Run again with -- --verify-existing to check persistence across process restarts.

const CHARACTER_SELECT := "res://scenes/ui/character_select.tscn"
const TEST_NAME := "안드로이드 저장 검사"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("ANDROID EXPORT SMOKE: " + message)


func _run() -> void:
	var game := root.get_node("GameData")
	var characters := root.get_node("CharacterRegistry")
	_check(characters.get_by_id("char01") != null, "검사 리소스가 등록되지 않았습니다.")
	_check(characters.get_by_id("archer") == characters.get_by_id("char01"), "기존 직업 별칭이 끊겼습니다.")
	_check(not root.get_node("SkillRegistry").all().is_empty(), "스킬 리소스가 등록되지 않았습니다.")
	_check_infected_model()
	if _failures != 0:
		quit(1)
		return

	if "--verify-existing" in OS.get_cmdline_user_args():
		_check(game.get_profile_at_slot(1).get("name") == TEST_NAME, "재실행 후 생성한 캐릭터를 복원하지 못했습니다.")
		_check(game.get_profile_at_slot(1).get("class_id") == "char01", "저장한 직업 ID가 변경되었습니다.")
		_check(game.characters["char01"]["name"] == TEST_NAME, "선택한 캐릭터 이름이 게임에서 유지되지 않았습니다.")
		if _failures == 0:
			_check_backup_recovery(game)
	else:
		await _check_character_creation(game)

	print("ANDROID_EXPORT_SMOKE_OK" if _failures == 0 else "ANDROID_EXPORT_SMOKE_FAILED")
	quit(0 if _failures == 0 else 1)


func _check_infected_model() -> void:
	var infected: Resource = root.get_node("MonsterRegistry").get_by_id("infected")
	var packed: PackedScene = infected.model_scene if infected != null else null
	_check(packed != null, "감염자 씬이 등록되지 않았습니다.")
	if packed != null:
		var instance := packed.instantiate()
		_check(not instance.find_children("*", "MeshInstance3D", true, false).is_empty(), "감염자 모델이 번들에서 사라졌습니다.")
		instance.free()


func _check_character_creation(game: Node) -> void:
	var original_id: String = game.get_profile_at_slot(0).get("id", "")
	_check(not original_id.is_empty() and not game.get_profile_at_slot(1).has("id"), "초기 저장 또는 빈 슬롯이 없습니다.")
	if _failures != 0:
		return
	var error := change_scene_to_file(CHARACTER_SELECT)
	_check(error == OK, "캐릭터 선택 화면을 열지 못했습니다.")
	if error != OK:
		return
	await scene_changed
	var select := current_scene
	select._show_creation(1)
	select.creation_name.text = TEST_NAME
	select._update_create_button()
	_check(select.selected_class_id == "char01" and not select.create_button.disabled, "등록된 검사를 생성 화면에서 선택할 수 없습니다.")
	var preview: Node = select.preview_player
	_check(preview != null and preview.model_clips.has("Idle") and preview.model_clips.has("Attack"), "검사의 미리보기 애니메이션이 누락됐습니다.")

	var previous_json := FileAccess.get_file_as_string(game.SAVE_FILE_PATH)
	error = DirAccess.make_dir_absolute(game.SAVE_TEMP_PATH)
	_check(error == OK, "저장 실패를 재현할 수 없습니다.")
	if error != OK:
		return
	select.create_button.pressed.emit()
	_check(game.get_profile_at_slot(1).is_empty() and game.active_character_id == original_id, "저장 실패 후 캐릭터나 슬롯이 남았습니다.")
	_check(FileAccess.get_file_as_string(game.SAVE_FILE_PATH) == previous_json, "저장 실패로 기존 저장이 변경되었습니다.")
	DirAccess.remove_absolute(game.SAVE_TEMP_PATH)

	select.create_button.pressed.emit()
	var profile: Dictionary = game.get_profile_at_slot(1)
	var new_id := str(profile.get("id", ""))
	_check(not new_id.is_empty() and new_id != original_id, "생성 버튼 재시도 후 캐릭터가 저장되지 않았습니다.")
	_check(game.get_profile_at_slot(0).get("id") == original_id and FileAccess.file_exists(game.SAVE_BACKUP_PATH), "기존 슬롯 또는 백업이 누락됐습니다.")
	if not new_id.is_empty():
		game.characters["char01"]["name"] = TEST_NAME
		_check(game.save_to_disk(), "캐릭터 이름을 저장하지 못했습니다.")


func _check_backup_recovery(game: Node) -> void:
	if not game.save_to_disk():
		_check(false, "백업을 새로 작성하지 못했습니다.")
		return
	var backup := FileAccess.get_file_as_string(game.SAVE_BACKUP_PATH)
	var file := FileAccess.open(game.SAVE_FILE_PATH, FileAccess.WRITE)
	if file == null:
		_check(false, "손상된 저장을 재현할 수 없습니다.")
		return
	file.store_string("invalid json")
	file.close()
	_check(game.load_from_disk() and game.get_profile_at_slot(1).get("name") == TEST_NAME, "손상된 기본 저장을 백업에서 복원하지 못했습니다.")
	_check(game.save_to_disk(), "백업 복원 후 다시 저장하지 못했습니다.")
	_check(FileAccess.get_file_as_string(game.SAVE_BACKUP_PATH) == backup, "손상된 기본 저장이 복구용 백업을 덮어썼습니다.")
