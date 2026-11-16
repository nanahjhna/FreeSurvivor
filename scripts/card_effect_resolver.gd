class_name CardEffectResolver
extends RefCounted

static func resolve(card: Dictionary, battle: Node) -> String:
	var card_type := str(card.get("type", ""))
	var base_value := float(card.get("value", 0))
	var scaling := str(card.get("scaling", "physical"))
	var hits := int(card.get("hits", 1))
	match card_type:
		"attack", "status_attack":
			var damage: float = float(battle.scale_card_damage(base_value, scaling))
			for _hit in range(hits):
				battle.damage_enemy(damage)
			if card_type == "status_attack":
				battle.add_enemy_status(str(card.get("status", "")), int(card.get("stacks", 1)), 3)
			return "%s: %d 피해" % [card.get("name", "공격"), int(damage) * hits]
		"block":
			var block_value: float = float(battle.scale_block(base_value))
			battle.player_block += block_value
			return "방어도 %d 획득" % int(block_value)
		"consume_status":
			var status_id := str(card.get("status", ""))
			var stacks: int = int(battle.consume_enemy_status(status_id))
			var combo_damage: float = float(battle.scale_card_damage(base_value * stacks, scaling))
			battle.damage_enemy(combo_damage)
			return "%s %d중첩 연계: %d 피해" % [status_id, stacks, int(combo_damage)]
		"block_attack":
			var bash_damage: float = float(battle.scale_card_damage(base_value, scaling)) + float(battle.player_block) * float(card.get("block_ratio", 0.0))
			battle.damage_enemy(bash_damage)
			return "방패 연계: %d 피해" % int(bash_damage)
		"finisher":
			var finish_damage: float = base_value + int(battle.attacks_used_this_turn) * float(card.get("per_attack", 0))
			finish_damage = battle.scale_card_damage(finish_damage, scaling)
			battle.damage_enemy(finish_damage)
			return "마무리 연계: %d 피해" % int(finish_damage)
		"buff":
			battle.add_player_status(str(card.get("status", "strength")), int(base_value), 99)
			return "%s +%d" % [card.get("status", "강화"), int(base_value)]
		"draw":
			battle.draw_cards(int(base_value))
			return "카드 %d장 드로우" % int(base_value)
		"energy":
			battle.energy = mini(battle.max_energy, battle.energy + int(base_value))
			return "에너지 %d 회복" % int(base_value)
	return "효과 없음"
