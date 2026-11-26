extends RefCounted
## Sprite atlas regions are defined in the approved PNGs' source coordinates.

const SURFACES := preload("res://assets/ui/approved_interface_surfaces.png")
const ICONS := preload("res://assets/ui/approved_interface_icons.png")
const SOURCE_SIZE := 1254.0

const SURFACE_REGIONS := {
	"primary": Rect2(50, 92, 1156, 215),
	"neutral": Rect2(53, 385, 1149, 211),
	"selected": Rect2(41, 652, 1172, 237),
	"panel": Rect2(52, 944, 1151, 221),
}
const ICON_REGIONS := {
	"person": Rect2(103, 105, 257, 257),
	"shield": Rect2(488, 106, 270, 270),
	"skill": Rect2(884, 104, 280, 280),
	"compass": Rect2(99, 493, 267, 267),
	"gate": Rect2(479, 488, 287, 287),
	"sword": Rect2(890, 487, 269, 269),
	"armor": Rect2(97, 872, 270, 270),
	"ring": Rect2(482, 871, 281, 281),
	"boots": Rect2(876, 869, 282, 282),
}

static func _import_region(source: Rect2, texture: Texture2D) -> Rect2:
	var ratio := texture.get_size() / SOURCE_SIZE
	return Rect2((source.position * ratio).round(), (source.size * ratio).round())

static func icon(kind: String) -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = ICONS
	result.region = _import_region(ICON_REGIONS[kind], ICONS)
	result.filter_clip = true
	return result

static func surface(kind: String, padding: Vector2, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var result := StyleBoxTexture.new()
	result.texture = SURFACES
	result.region_rect = _import_region(SURFACE_REGIONS[kind], SURFACES)
	result.modulate_color = tint
	var corner := roundf((52.0 if kind == "selected" else 39.0) * SURFACES.get_width() / SOURCE_SIZE)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		result.set_texture_margin(side, corner)
		result.set_content_margin(side, padding.x if side in [SIDE_LEFT, SIDE_RIGHT] else padding.y)
	return result
