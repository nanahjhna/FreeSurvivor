# FreeSurvivor 구현/수정 요약 (검토용)

## 완료된 수정
- 경험치 구슬: 자동 흡수 비활성화, 직접 접촉 획득 (`scenes/effects/xp_gem.gd`)
- StatManager 생성 (`scripts/stat_manager.gd`): STR/AGI/VIT/INT/DEX/LUK 계산
- Player 연결: HP/ATK/SPD/MAG DEF/SP (`scenes/player/player.gd`)
- SkillLoadoutManager (`scripts/skill_loadout_manager.gd`): 6슬롯, 중복 방지
- CardManager (`scripts/card_manager.gd`): 보유/장착 최대 3장
- DeckManager (`scripts/deck_manager.gd`): 최대 8장 덱
- TutorialGuideManager (`scripts/tutorial_guide_manager.gd`)
- CharacterSlotManager (`scripts/character_slot_manager.gd`)
- GameManager에 매니저 등록 (`scripts/game_manager.gd`)
- 캐릭터 회전 방향 수정 (player/monster)
- 마을 카메라 줌아웃 (`scenes/stages/village_lobby.gd`)
- 레벨업 경험치 곡선 완화 (`scenes/player/player.gd`)

## 미완성/추가 필요
- 캐릭터 선택 UI 완전 구현 (3D 미리보기/이름 랜덤/슬롯)
- 능력치 투자 UI 및 저장 연동
- 스킬 퀵슬롯 UI 및 장착/교체
- 카드 상점/장착 UI
- 덱 던전 씬
- 직업별 모델/무기 미리보기, 효과음, 소멸 설정
- 런타임 레벨 vs 영구 스탯 분리
- 저장 호환 마이그레이션

## 권장 다음 작업
UI 씬별 연결 및 에셋 적용.