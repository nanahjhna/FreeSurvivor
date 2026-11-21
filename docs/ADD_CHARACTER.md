# 캐릭터 추가 안내

새 캐릭터의 설정은 `data/characters/charNN.tres` 한 파일에서 관리합니다. 이 파일에 모델, 기본 능력치, 애니메이션 이름표와 캐릭터 전용 스킬 리소스가 함께 저장됩니다. 스킬은 외부 `.tres` ID를 찾아 연결하지 않고 `CharacterData.skills` 안에 내장합니다.

## Godot 에디터에서 추가

1. `data/characters`에서 기존 캐릭터 `.tres`를 복사해 새 `charNN.tres`로 저장합니다.
2. Inspector에서 `id`, `legacy_id`, 이름, 모델, 기본 능력치를 수정합니다. 새 ID는 `charNN` 형식을 사용합니다.
3. `animation_aliases`에 캐릭터 모델의 AnimationPlayer 클립명을 등록합니다. 키는 `Idle`, `Walk`, `Run`, `AttackAlt`, `Kick`, `Hit`, `Death` 같은 동작 키이고 값은 실제 클립명 후보 배열입니다.
4. `skills` 배열에서 항목을 추가하거나 복제합니다. 배열 항목은 내장 `SkillData`이므로 이름, 설명, 쿨타임, 피해 계수, 효과 씬, `animation_key`를 같은 캐릭터 파일에서 편집합니다.
5. 각 스킬의 `slot_key`를 `q`, `w`, `e`, `r` 중 하나로 지정합니다. 패시브는 비워 둡니다. 스킬의 `animation_key`는 해당 캐릭터의 `animation_aliases` 키를 가리킵니다.

캐릭터 전용 스킬은 `id`와 `legacy_id`를 직접 맞출 필요가 없습니다. 비워 두면 런타임이 캐릭터 ID와 슬롯 키로 내부 저장 키를 만듭니다.

예를 들어 스킬의 `animation_key`가 `AttackAlt`이면 캐릭터 리소스의 `animation_aliases["AttackAlt"]`에서 모델에 실제 존재하는 애니메이션 클립을 찾아 재생합니다. 효과 씬은 전투 이펙트에 사용되고, 캐릭터 애니메이션 키와는 별도로 설정합니다.

기본 동작 키는 `Idle`, `Walk`, `Run`, `Hit`, `Knockdown`, `GetUp`, `Death`이며, 필요하면 `AttackBase`, `Attack`, `AttackAlt`, `Kick`, `Cast`, `Dodge`, `Block`, `Jump`, `Victory`도 등록할 수 있습니다. 값으로 후보 클립을 여러 개 넣으면 모델에 실제로 존재하는 첫 번째 클립을 사용합니다.

`CharacterRegistry`가 `data/characters`를 자동 스캔하므로 새 캐릭터 등록을 위해 매니저 코드나 별도 ID 매핑을 수정할 필요가 없습니다. 런타임 저장 호환에 필요한 기존 스킬 ID 필드는 직렬화용으로만 유지되며 Inspector에서는 숨겨져 있습니다.
