extends Node
class_name DeckManager

const DEFAULT_DECK_SIZE = 12
var deck_size: int = DEFAULT_DECK_SIZE
var deck_name: String = "기본 덱"
var deck: Array = []
var hand: Array = []   # drawn cards

func set_deck(cards: Array) -> bool:
	if cards.size() != deck_size:
		return false
	deck = cards.duplicate()
	return true

func set_deck_checked(cards: Array, owned: Dictionary) -> bool:
	if cards.size() != deck_size:
		return false
	var used: Dictionary = {}
	for value in cards:
		var card_id := str(value)
		if CardDatabase.get_card(card_id).is_empty():
			return false
		used[card_id] = int(used.get(card_id, 0)) + 1
		if int(used[card_id]) > int(owned.get(card_id, 0)):
			return false
	deck = cards.duplicate()
	return true

func ensure_starter_deck(owned: Dictionary):
	if validate_deck(owned):
		return
	set_deck_checked(CardDatabase.STARTER_DECK, owned)

func validate_deck(owned: Dictionary) -> bool:
	return set_deck_checked(deck.duplicate(), owned)

func draw(count: int = 1):
	for i in range(count):
		if deck.is_empty():
			break
		hand.append(deck.pop_front())

func play_card(index: int) -> String:
	if index < 0 or index >= hand.size():
		return ""
	var c = hand[index]
	hand.remove_at(index)
	return c

func clear_hand():
	hand.clear()
