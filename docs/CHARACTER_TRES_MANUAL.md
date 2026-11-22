# Character `.tres` Manual (FreeSurvivor)

이 문서는 `data/characters/*.tres` 캐릭터 정의 파일의 구조와 작성 규칙을 설명합니다.

## 1. 파일 위치/형식
- 경로: `data/characters/<id>.tres`
- 형식: Godot `Resource` (`script_class="CharacterData"`)
- 런타임 로드: `CharacterRegistry` + `PlayerManager`

## 2. 필수 상위 필드
- `id`: 캐릭터 고유 ID (예: `char01`)
- `legacy_id`: 구버전 호환 ID (없으면 `id`와 동일)
- `display_name`: UI 표시 이름
- `title`: 칭호
- `role`: 직업/역할
- `icon`: 아이콘(이모지/텍스트)
- `color`: 테마 색상
- `model_scene`: 3D 모델 씬 경로 (`res://assets/.../*.glb`)
- `animation_profile`: 애니메이션 프로필 이름
- `animation_aliases`: 애니메이션 클립 매핑 딕셔너리
- `base_*`: 능력치/전투 수치
- `skills`: 스킬 리소스 배열
- `signature_skill`: 대표 스킬 이름
- `weapon_name`, `weapon_scene`, `weapon_bone_name` 등 무기 장착 정보
- `combat_style`, `description`
- `starting_gear`

## 3. 모델/애니메이션
- `model_scene`은 실제 존재하는 `.glb` 경로여야 합니다.
- `animation_aliases`는 게임 내부 키(`Idle`, `Walk`, `Run`, `Attack` 등)를 모델 클립 이름으로 매핑합니다.
- 모델에 해당 클립이 없으면 애니메이션이 재생되지 않을 수 있습니다.

## 4. 스킬 정의
- `skills` 배열에 `SkillData` 서브리소스를 넣습니다.
- 각 스킬의 `slot_key`는 `q`, `w`, `e`, `r`, `a`, `s`, `d`, `f` 등으로 지정합니다.
- `implemented = true`인 스킬만 런타임에 노출됩니다.
- `effect_scene`은 실제 존재하는 씬 경로여야 합니다.

## 5. 무기 설정
- 무기가 없는 캐릭터는 `weapon_scene = null`, `weapon_name = "없음"`으로 둡니다.
- 무기가 있는 경우 `weapon_bone_name`, `weapon_mount_*`, `weapon_support_*` 값을 모델 뼈 이름에 맞게 설정합니다.

## 6. 주의사항
- 참조 경로(`model_scene`, `effect_scene`, `weapon_scene`)가 실제로 존재해야 합니다.
- `char01`/`char02` 외의 캐릭터는 GameData 카탈로그와 UI에서 노출 여부를 함께 확인해야 합니다.
- 기본 캐릭터(`FIGHTER_ID`) 변경 시 `DEFAULT_EQUIPPED_GEAR`, `DEFAULT_CHARACTER_STATS`도 함께 갱신해야 합니다.

## 7. 최소 예시 구조
```text
[resource]
script = ExtResource("character_data.gd")
id = "char01"
display_name = "검사"
role = "검사"
model_scene = ExtResource("char01.glb")
animation_profile = "archer"
skills = Array[SkillData]([...])
weapon_scene = null
```
