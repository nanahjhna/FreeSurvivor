extends CanvasLayer

signal closed()

@onready var stage_title_lbl: Label = $Panel/Margin/VBox/Body/StageInfo/Margin/VBox/TopRow/StageTitle
@onready var chapter_lbl: Label = $Panel/Margin/VBox/Body/StageInfo/Margin/VBox/TopRow/ChapterLabel
@onready var diff_lbl: Label = $Panel/Margin/VBox/Body/StageInfo/Margin/VBox/TopRow/DiffLabel
@onready var desc_lbl: Label = $Panel/Margin/VBox/Body/StageInfo/Margin/VBox/DescLabel
@onready var monsters_lbl: Label = $Panel/Margin/VBox/Body/StageInfo/Margin/VBox/MonstersLabel

@onready var party_preview_box: HBoxContainer = $Panel/Margin/VBox/Body/PartyPreview/MembersBox
@onready var power_lbl: Label = $Panel/Margin/VBox/Body/PartyPreview/PowerLabel

@onready var reward_gold_lbl: Label = $Panel/Margin/VBox/Body/RewardBox/Margin/HBox/GoldLabel
@onready var reward_xp_lbl: Label = $Panel/Margin/VBox/Body/RewardBox/Margin/HBox/XPLabel
@onready var reward_items_lbl: Label = $Panel/Margin/VBox/Body/RewardBox/Margin/HBox/ItemsLabel

@onready var stage_tabs: HBoxContainer = $Panel/Margin/VBox/StageTabs
@onready var start_button: Button = $Panel/Margin/VBox/BottomRow/StartBattleBtn
@onready var stage_tab_buttons: Array[Button] = [
	$Panel/Margin/VBox/StageTabs/Stage1Btn,
	$Panel/Margin/VBox/StageTabs/Stage2Btn,
	$Panel/Margin/VBox/StageTabs/Stage3Btn
]

var current_stage_id: String = "stage_1"
var stage_ids: Array[String] = ["stage_1", "stage_2", "stage_3"]

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func open(stage_id: String = "stage_1"):
	current_stage_id = stage_id if GameData.is_stage_unlocked(stage_id) else "stage_1"
	GameData.current_selected_stage_id = current_stage_id
	get_tree().paused = true
	visible = true
	_refresh_ui()

func close():
	visible = false
	get_tree().paused = false
	closed.emit()

func _refresh_ui():
	var stage = GameData.stages.get(current_stage_id, GameData.stages["stage_1"])
	stage_title_lbl.text = stage.name
	chapter_lbl.text = stage.chapter + " [권장 Lv." + str(stage.level_req) + "]"
	diff_lbl.text = "난이도: " + stage.difficulty
	if GameData.is_stage_unlocked(current_stage_id):
		desc_lbl.text = stage.desc
	else:
		desc_lbl.text = stage.desc + "\n🔒 이전 지역 클리어 및 권장 레벨 달성이 필요합니다."
	monsters_lbl.text = "출현 몬스터: " + ", ".join(stage.monster_types)
	start_button.disabled = not GameData.is_stage_unlocked(current_stage_id)
	if start_button.disabled:
		start_button.text = "🔒 잠긴 스테이지"
		start_button.tooltip_text = "이전 지역을 클리어하고 권장 레벨을 달성해야 입장할 수 있습니다."
	else:
		start_button.text = "⚔️ 전투 시작 [F]"
		start_button.tooltip_text = "현재 스테이지로 전투를 시작합니다."
	for i in range(stage_tab_buttons.size()):
		var tab = stage_tab_buttons[i]
		tab.disabled = not GameData.is_stage_unlocked(stage_ids[i])
		tab.button_pressed = stage_ids[i] == current_stage_id
		tab.tooltip_text = "" if not tab.disabled else "이전 지역 클리어 후 해금됩니다."
	
	reward_gold_lbl.text = "💰 골드: +" + str(stage.rewards.gold)
	reward_xp_lbl.text = "⭐ 경험치: +" + str(stage.rewards.xp)
	reward_items_lbl.text = "🎁 보상 아이템: " + ", ".join(stage.rewards.items)
	
	# Party Preview
	for child in party_preview_box.get_children():
		child.queue_free()
	
	for cid in GameData.party_slots:
		var c = GameData.characters.get(cid, {})
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(58, 64)
		var vb = VBoxContainer.new()
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		var ic = Label.new()
		ic.text = c.get("icon", "⚔️")
		ic.add_theme_font_size_override("font_size", 22)
		ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(ic)
		var nl = Label.new()
		nl.text = "Lv." + str(c.get("level", 1))
		nl.add_theme_font_size_override("font_size", 10)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(nl)
		card.add_child(vb)
		party_preview_box.add_child(card)
	
	var power = GameData.get_party_combat_power()
	power_lbl.text = "파티 전투력: %d  (권장: %d)" % [power, stage.level_req * 180]

func _on_stage_selected(stage_id: String):
	if not GameData.is_stage_unlocked(stage_id):
		return
	current_stage_id = stage_id
	GameData.current_selected_stage_id = stage_id
	_refresh_ui()

func _on_start_battle_pressed():
	if not GameData.is_stage_unlocked(current_stage_id):
		return
	close()
	GameManager.go_to_battle(current_stage_id)

func _on_close_pressed():
	close()

func _unhandled_input(event: InputEvent):
	if visible and not GameActions.is_capturing() and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
