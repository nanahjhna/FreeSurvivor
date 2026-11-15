extends Node
class_name DeckManager

var deck: Array = []   # up to 8 card ids
var hand: Array = []   # drawn cards

func set_deck(cards: Array) -> bool:
	if cards.size() > 8:
		return false
	deck = cards.duplicate()
	return true

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