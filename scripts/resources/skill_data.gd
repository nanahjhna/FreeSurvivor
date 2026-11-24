class_name SkillData
extends Resource

@export var id: String = ""
@export var legacy_id: String = ""
@export var champion_id: String = ""
@export var champion_name: String = ""
@export var slot_key: String = ""
@export var reference_name: String = ""
@export_multiline var reference_description: String = ""
@export var icon: String = "✨"
@export var icon_url: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var cost: int = 0
@export var mana_cost: int = 0
@export var cooldown: float = 0.0
@export var damage_ratio: float = 0.0
@export var cooldown_step: float = 0.0
@export var damage_step: float = 0.0
@export var range: float = 10.0
@export var unlock_level: int = 1
@export var cast_type: String = "unassigned"
## Semantic animation key looked up in CharacterData.animation_aliases.
@export var animation_key: String = "AttackAlt"
## Positive values protect the skill animation and cap playback at this many seconds.
@export var animation_duration: float = 0.0
## Delay from animation start until the hit effect is created.
@export var impact_delay: float = 0.0
@export var bonus_type: String = "physical"
@export var effect_scene: PackedScene
@export var effect_color: Color = Color.WHITE
@export var uses_magic_power: bool = false
@export var cast_pattern: String = ""
@export var projectile_count: int = 1
@export var spread_radians: float = 0.0
@export var projectile_pierce: int = 1
@export var heal_ratio: float = 0.0
@export var passive_handler: String = ""
@export var regen_delay: float = 0.0
@export var hp_regen_ratio: float = 0.0
@export var implemented: bool = false
@export var support_status: String = "unimplemented"


func to_game_dictionary() -> Dictionary:
	return {
		"name": display_name if not display_name.is_empty() else reference_name,
		"icon": icon,
		"desc": description if not description.is_empty() else reference_description,
		"base_cd": cooldown,
		"base_dmg_ratio": damage_ratio,
		"cd_step": cooldown_step,
		"dmg_step": damage_step,
		"cost_base": cost,
		"range": range,
		"unlock_level": unlock_level,
		"cast_type": cast_type,
		"animation_key": animation_key,
		"animation_duration": animation_duration,
		"impact_delay": impact_delay,
		"bonus_type": bonus_type,
		"effect_scene": effect_scene.resource_path if effect_scene != null else "",
		"visual_color": effect_color.to_html(false),
		"uses_magic_power": uses_magic_power,
		"cast_pattern": cast_pattern,
		"projectile_count": projectile_count,
		"spread_radians": spread_radians,
		"projectile_pierce": projectile_pierce,
		"heal_ratio": heal_ratio,
		"passive_handler": passive_handler,
		"regen_delay": regen_delay,
		"hp_regen_ratio": hp_regen_ratio,
		"game_ready": implemented,
		"game_support_status": support_status
	}
