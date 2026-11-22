# Skill Manager Manual (FreeSurvivor)

이 문서는 스킬 매니저(`scenes/skills/skill_manager.gd`)의 동작과 스킬 분류 규칙을 설명합니다.

## 1. 개요
- 스킬 매니저는 전투 중 스킬 쿨다운, 시전, 자동 전투, 패시브 효과를 관리합니다.
- 스킬 데이터는 캐릭터 `.tres`의 `skills` 배열에서 로드됩니다.

## 2. 슬롯/입력
- 기본 슬롯: `q`, `w`, `e`, `r`, `a`, `s`, `d`, `f` (8슬롯)
- 입력 액션: `skill_q`, `skill_w`, ... (game_actions.gd)
- HUD에서 슬롯별 버튼/쿨다운을 표시합니다.

## 3. 스킬 분류
- **원거리 (Ranged)**: `cast_type` = `wave`, `volley`, projectile 기반
- **근거리 (Melee)**: `cast_type` = `spin`, `burst`, 근접 범위
- **마법 (Magic)**: `uses_magic_power = true`, `bonus_type = fire/area`
- **물리 (Physical)**: `bonus_type = physical`, 기본 공격력 기반
- **패시브 (Passive)**: `cast_type = passive`, 쿨다운 없음, 자동 효과
- **직업 스킬**: 캐릭터별 고유 스킬 (`.tres`에 정의)

## 4. 쿨다운/시전 흐름
1. `press_skill(key)` → GameData에서 스킬 ID 조회
2. 해금 여부 확인 (`is_survival_skill_unlocked`)
3. `try_cast()` → 쿨다운/HP/효과 씬 검증
4. 효과 씬 인스턴스화 및 `cast()` 호출
5. 쿨다운 설정 및 UI 갱신

## 5. 자동 전투
- `auto_battle_enabled = true`일 때 `_run_auto_battle()` 실행
- HP 70% 이하 시 `s` 슬롯(회복) 시도
- 적 거리 내에서 `r, a, q, w, e` 순서로 시전

## 6. 패시브 처리
- `cast_type = passive` 스킬은 `get_passive_regen_amount()`에서 처리
- 예: `regen_after_damage` 패시브

## 7. 확장 가이드
- 새 슬롯 추가 시: `cooldowns` 딕셔너리, `game_actions.gd`, HUD 목록에 추가
- 새 분류 추가 시: `bonus_type`/`cast_type` 값을 정의하고 `_get_survival_skill_multiplier()`에 반영
- 새 패시브 추가 시: `get_passive_regen_amount()` 또는 별도 핸들러 추가
