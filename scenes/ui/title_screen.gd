extends Control

@onready var start_button: Button = $Center/VBox/Buttons/StartBtn
@onready var continue_button: Button = $Center/VBox/Buttons/ContinueBtn
@onready var settings_button: Button = $Center/VBox/Buttons/SettingsBtn
@onready var quit_button: Button = $Center/VBox/Buttons/QuitBtn
@onready var settings_ui: CanvasLayer = $SettingsUI
@onready var version_label: Label = $BottomLeft/VersionLabel
@onready var notice_label: Label = $Center/VBox/NoticeLabel

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.current_location = GameManager.Location.TITLE
	
	if continue_button:
		continue_button.disabled = not GameData.has_save_data()
		if continue_button.disabled:
			continue_button.text = "📜 이어하기 (저장 없음)"
			continue_button.tooltip_text = "저장 데이터가 없습니다. 새 게임을 시작하세요."
		else:
			continue_button.text = "📜 이어하기"
			continue_button.tooltip_text = "마지막 저장 지점에서 계속합니다."
	if start_button:
		start_button.text = "🗡️ 새 게임 시작"
		start_button.tooltip_text = "새 모험을 시작합니다. 기존 저장 데이터는 초기화됩니다."
	if settings_button:
		settings_button.text = "⚙️ 환경 설정 [ESC]"
	if quit_button:
		quit_button.text = "🚪 게임 종료"
	
	if version_label:
		version_label.text = "FreeSurvivor v1.0.0 (Collector RPG Edition)  ·  이동: 방향키  ·  메뉴: 화면 버튼"

func _unhandled_input(event: InputEvent):
	if settings_ui and settings_ui.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_settings_btn_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		if continue_button and not continue_button.disabled:
			_on_continue_btn_pressed()
		else:
			_on_start_btn_pressed()
		get_viewport().set_input_as_handled()

func _on_start_btn_pressed():
	GameManager.go_to_character_select()

func _on_continue_btn_pressed():
	if not GameData.load_from_disk():
		notice_label.text = "저장 데이터를 불러오지 못했습니다. 새 게임을 시작해 주세요."
		push_error("Failed to load the save file.")
		return
	GameManager.go_to_lobby()

func _on_settings_btn_pressed():
	if settings_ui:
		settings_ui.call("open")

func _on_quit_btn_pressed():
	get_tree().quit()
