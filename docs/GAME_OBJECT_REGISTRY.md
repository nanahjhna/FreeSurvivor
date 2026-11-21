# 게임 오브젝트 등록 구조

게임 플레이어, 몬스터, 스킬은 저장 데이터와 씬에서 이름 대신 안정적인 ID로 연결합니다. 새 오브젝트는 해당 레지스트리에 등록하고 기존 매니저를 통해 생성합니다.

## 플레이어 추가

1. `scripts/game_data.gd`의 `characters`에 고유 ID를 추가합니다.
2. `model_scene`, `model_scale`, 재사용할 `animation_profile`, `base_attributes`, 기본 HP/공격/방어와 표시 데이터를 등록합니다. 시작 장비가 있으면 `starting_gear`도 등록합니다.
3. `scripts/character_skill_database.gd`의 `CHARACTER_SKILL_ASSIGNMENTS`에 같은 ID를 추가하고, `scripts/skill_database.gd`에 등록된 스킬 ID를 연결합니다. 스킬 배정이 없는 캐릭터는 새 슬롯 캐릭터로 생성되지 않도록 검사합니다.
4. 플레이어 모델은 `PlayerManager.create_model(player_id, parent)`가 데이터의 `model_scene`에서 불러옵니다. `player.tscn`은 캐릭터 모델 목록을 직접 보유하지 않습니다.

새 애니메이션 프로필은 `scenes/player/player.gd`의 `_setup_model_animations()`에 한 번 구현합니다. 그 뒤 같은 프로필을 쓰는 캐릭터는 데이터 등록만으로 공유할 수 있습니다.

## 스킬 추가

1. `scripts/skill_database.gd`의 `GAME_SKILLS`에 고유 ID, 수치, 해금 레벨, `effect_scene`을 등록합니다.
2. 새 효과 씬의 스크립트는 `SkillEffectBase`를 상속하고 `cast(caster, target, direction, damage_multiplier, definition)`을 구현합니다.
3. 캐릭터에 스킬을 제공하려면 `CharacterSkillDatabase`의 해당 캐릭터 `skills`와 기본 `loadout`에 스킬 ID를 연결합니다.

기존 효과 종류를 조합할 때는 씬과 시전 메타데이터를 등록하면 됩니다. 예를 들어 `cast_pattern: "fan"`, `projectile_count`, `spread_radians`로 부채꼴 투사체를 구성할 수 있습니다. 회복 스킬은 `cast_type: "heal"`, 지속 효과는 `cast_type: "passive"`를 사용합니다.

## 몬스터 추가

1. `scripts/monster_database.gd`의 `MONSTERS`에 고유 ID, `BaseMonster` 파생 씬 경로, 기본 능력치, 처치 보상, 보스 여부를 등록합니다.
2. 생성할 때는 `MonsterManager.spawn_monster(id, parent, position, overrides)`를 사용합니다.
3. 서바이벌 출현 목록에 추가할 때만 `MonsterSpawner.monster_pool`에 ID를 넣습니다. 현재 기본 목록은 `infected`만 포함해 기존 등장 구성을 유지합니다.

보스도 같은 생성 함수를 사용하며, `boss_monster_id`와 개별 능력치 덮어쓰기로 설정합니다. 처치 골드·물약 확률·보스 보상은 몬스터 정의에 둡니다.

## 책임 분리

- `GameData.characters`: 플레이어 및 저장 진행 데이터
- `PlayerManager`: 등록된 플레이어 모델 로드
- `SkillDatabase` / `CharacterSkillDatabase`: 스킬 정의와 캐릭터별 장착 가능 스킬
- 씬의 `SkillManager`: 쿨타임, 자동 시전, 효과 객체 생성
- `MonsterDatabase`: 몬스터 정의와 드롭 정보
- `MonsterManager`: 몬스터 씬 생성 및 기본값 적용
- `MonsterSpawner`: 출현 시점, 수량, 위치와 ID 선택
