# Rig Model Animation Manual (FreeSurvivor)

이 문서는 `rig-model.glb` (또는 리그 모델)의 애니메이션 클립을 정리/매핑하는 가이드입니다.

## 1. 목적
- 리그 모델에 포함된 애니메이션 클립 이름을 문서화합니다.
- 캐릭터 `.tres`의 `animation_aliases`와 1:1로 매핑할 수 있도록 기준을 제공합니다.

## 2. 기본 원칙
- 모델 내부 클립 이름은 **정확히** `.tres`의 `animation_aliases` 값과 일치해야 합니다.
- 대소문자/공백/언더스코어 차이도 매칭 실패를 유발합니다.
- 한 게임 키(`Idle`, `Walk`, `Run` 등)에 여러 후보 클립을 배열로 지정할 수 있습니다.

## 3. 권장 클립 키 목록
- `Idle`
- `Walk`
- `Run`
- `Attack`
- `AttackAlt`
- `AttackBase`
- `Cast`
- `Kick`
- `Hit`
- `Death`
- `Block`
- `Dodge`
- `Jump`
- `Fall`
- `GetUp`
- `Knockdown`
- `Reload`
- `Victory`

## 4. 매핑 예시
```gdscript
animation_aliases = {
	"Idle": ["Idle", "Rifle_Idle_RT"],
	"Walk": ["Walk", "Rifle_Walk_RT"],
	"Run": ["Run", "Rifle_Run_RT"],
	"Attack": ["Attack", "Rifle_Fire_RT"],
	"AttackAlt": ["AttackAlt", "Rifle_Fire_RT"],
	"Hit": ["Hit", "Rifle_Hit_To_Back_RT"],
	"Death": ["Death", "Rifle_Run_To_Dying_RT"]
}
```

## 5. 클립 점검 체크리스트
- [ ] 모델에 `Idle` 클립이 존재하는가?
- [ ] `Walk`/`Run` 클립이 구분되어 있는가?
- [ ] 공격 클립이 루프되지 않도록 `LOOP_NONE`으로 설정되어 있는가?
- [ ] 이동 클립은 `LOOP_LINEAR`로 설정되어 있는가?
- [ ] 클립 이름에 오타가 없는가?

## 6. 문서화 템플릿
| 게임 키 | 모델 클립 이름 | 루프 모드 | 비고 |
|---|---|---|---|
| Idle | Idle_Rig_RT | LOOP_LINEAR | 기본 대기 |
| Walk | Walk_Rig_RT | LOOP_LINEAR | 이동 |
| Run | Run_Rig_RT | LOOP_LINEAR | 달리기 |
| Attack | Attack_Rig_RT | LOOP_NONE | 공격 |

## 7. 적용 위치
- 캐릭터 `.tres`: `animation_aliases`
- 런타임: `scenes/player/player.gd` (`_setup_model_animations`, `_map_animation_alias`)
- 미리보기: `scenes/ui/character_select.gd` (`_set_preview_class`)
