# UI illustration prompts

Generated with the built-in ImageGen tool. Each image is original art with no text or interface baked in.

## title_splash.png

Use case: stylized-concept. Asset type: original portrait splash background illustration for a Godot mobile fantasy survival RPG title screen, 9:16 composition. A single young adult martial artist hero in dark indigo travel clothes with wrapped fists stands in the foreground, confident and inviting, with a small village gate, winding path, ancient stone ruins and distant monsters behind. Painterly polished fantasy game key art with clear expressive silhouette, luminous teal magic accents, warm gold lantern light and deep navy atmosphere. Place the hero in the middle third, leave generous dark clean negative space in the upper quarter for a live game logo and lower quarter for live menu buttons. Strong depth, rich environmental storytelling, readable at phone size. Original design, no resemblance to any existing franchise or characters. No text, no logo, no interface, no watermark.

## stage_grassland.png

Use case: stylized-concept. Asset type: original stage selection card art for a portrait mobile fantasy survival RPG. Scene: sunlit grassland outside a gray stone village gate, winding path, low ruined walls, a few distant hostile silhouettes. Painterly premium fantasy game illustration, deep navy shadows, teal magical accents and warm gold highlights. Strong central composition readable in a narrow vertical card. No people in foreground, no text, no UI, no logo, no border, no watermark.

## stage_forest.png

Use case: stylized-concept. Asset type: original stage selection card art for a portrait mobile fantasy survival RPG. Scene: misty ancient forest path with twisted trunks, cyan fireflies and a distant ominous ruin, dark green and indigo palette with small warm gold light. Painterly premium fantasy game illustration, strong central composition readable in a narrow vertical card. No people in foreground, no text, no UI, no logo, no border, no watermark.

## stage_crypt.png

Use case: stylized-concept. Asset type: original stage selection card art for a portrait mobile fantasy survival RPG. Scene: underground stone crypt with stairs descending toward a sealed crimson glowing gate, broken columns and subtle violet magic. Painterly premium fantasy game illustration, deep navy and muted red with restrained gold highlights, strong central composition readable in a narrow vertical card. No people in foreground, no text, no UI, no logo, no border, no watermark.

## 레퍼런스 반영 배경

두 배경은 내장 ImageGen으로 제작했다.

### title_citadel_v2.png

Portrait 9:16 original environment-only cover art for FreeSurvivor mobile 3D action RPG. High-polish stylized 3D fantasy environment. A steep cobbled path of ancient ruined masonry rises toward a distant arched citadel, hanging blue-lavender cloudbanks and sharp silhouetted watchtowers. Warm amber glows from windows and a shaft of violet light through the mist. Light sky at top left, dense purple-blue and warm gold palette, crisp foreground stones, cinematic depth. Keep the center path clear for the playable 3D character Godot will draw separately. Absolutely no characters, people, silhouettes resembling people, beasts, creatures, weapons, text, lettering or UI. Landscape architecture only.

### dungeon_gate_v2.png

Create original vertical 9:16 environmental concept painting for the FreeSurvivor dungeon selection screen. Center a massive original medieval stone lancet arch, with a diamond-shaped cast-iron gate and amber firelight shining up from broken steps. Staggered oil lanterns and old carved basalt columns frame the entrance. Hand-painted stylized 3D fantasy game environment, carved silhouettes, toasty amber shadows, aged copper, charcoal, ember gold. Entrance takes central ~65% of the frame, use subdued top fifth and dim floor at bottom so overlaid controls can sit there. No text, no UI, no human characters, no copied door ornament or layouts.

## 승인 UI 이미지 스킨

2026-11-27 승인된 마을·장비 UI 시안을 바탕으로 내장 ImageGen 편집 모드에서 실제 배경과 아이콘에 쓸 투명 아틀라스를 분리했습니다.

### approved_interface_surfaces.png

```text
Use case: precise-object-edit, production UI sprite extraction. Input Image 1 is the user's approved FreeSurvivor equipment-management UI screenshot. Extract and isolate four blank pieces of its UI artwork, preserving their exact approved palette, clipped/rounded corner shapes, subtle material gradients, bronze bevels and thin edge highlights. This asset is to be applied as nine-slice textures in Godot. Remove all of the overlaid lettering and numbers and icons by continuing the existing material behind them. Absolutely no character, sword, item art, game environment, torch, scenery, logos, words, numbers, symbols, inner dividers, grunge ornament, or captions are part of the output.

Output one SQUARE PNG sprite sheet with real transparency outside the plates. Exactly four fully enclosed wide rectangular horizontal plates, stacked in a single centered column and separated by wide fully transparent gutters. Every plate has the same aspect ratio around 4.4:1, width about 82% of canvas, and height about 18% of canvas. Leave at least 3% of canvas between plates. Arrange in exactly this order, top to bottom:
1. The rust-orange primary action background from the original bottom '장착' button, same subtly bright top bevel, deep rust body, clean amber-copper rim.
2. The charcoal secondary button from the original top-right '증강 카드' tab, same dark iron fine face texture, gray-oxidized bronze rim, subtly clipped rounded corners. Dark neutral fill.
3. The amber highlighted selection from the original highlighted iron-sword inventory slot. Same graphite face, only the luminous golden thin selected edge and tiny restrained outer glow. Elongate it into the same wide rectangle while preserving corner shape. No item or glyph.
4. The graphite panel from the original '철검' comparison summary near the bottom. Same dark textured graphite fill, thin muted bronze bevel and clipped corner radius. Remove the inner divider as well as all text and icon. No lines inside.

They are four clean isolated reusable game UI faces seen completely orthographic and front-on. No perspective, visual mockup or card scenery. Keep each plate's center flat without an inner inset frame so dynamic text will read. Real alpha immediately outside each plate and in all gaps; no gray simulated transparency, no background drop shadow wash over the gutters, no extra shapes. A faithful material extraction from the reference, suitable for direct use as pixel artwork.
```

### approved_interface_icons.png

```text
Use case: precise-object-edit, production UI icon extraction for FreeSurvivor. Input 1 is the approved village HUD. Input 2 is the approved equipment HUD. Lift only their original simple warm ivory pictograms, with the same silhouettes, color, subtle highlights and weight, onto a single truly transparent square PNG icon sprite sheet. These will be displayed at about 24 to 36 pixels. Remove their backgrounds, button boxes, tip text, borders, accents and shadows. No character or scenery, no ornaments and no text of any kind.

EXACTLY 9 icons in an evenly spaced and accurately positioned regular 3 columns by 3 rows grid. Use these exact centers as fractions of the canvas for each cell: x=1/6, 1/2, 5/6 and y=1/6, 1/2, 5/6. Each icon is no wider and no taller than 62% of its individual cell so visible transparent gutters surround it. All icons upright as in the inputs. No containers around any icon. Icon color warm pale ivory in all nine.
Row one, left to right: person bust from the village bottom-left; shield from the village second nav item; big 4 point spark with little accents from the village third nav item.
Row two, left to right: compass with needle from the village fourth nav item; twin-tower gate pictogram from the village objective card; crossed swords from the equipment weapon slot.
Row three, left to right: chest armor silhouette from the equipment top-right slot; gem ring from the equipment bottom-left slot; side-view leather boot from the equipment bottom-right slot.
Require a real transparent alpha channel for the entire canvas outside the nine isolated glyphs. Crisp image elements, fully visible, no borders, no screenshots inside output, no text or numbering. Preserve the approved bold high-contrast pictograms as closely as possible so they can replace the game UI icons.
```

## 승인 화면 원본 적용

- `screen_reference_start.png`, `screen_reference_hero.png`, `screen_reference_codex.png`, `screen_reference_options.png`, `screen_reference_combat.png`는 사용자 첨부 원본입니다. 각 1672×941 이미지를 세 화면의 텍스처 영역으로 사용합니다.
- `screen_reference_smithy.png`는 원본에서 캐릭터와 검에 가렸던 대장간 배경을 복원한 이미지입니다. ImageGen에 원본 대장간 영역의 아치·벽·등불·화로·석재 바닥을 유지하고, 모델과 검 및 UI 글자를 지워 달라고 요청했습니다. 게임에서 실제 3D 모델과 합성할 해당 영역에만 사용합니다.
