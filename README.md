# FreeSurvivor

Godot 4 기반의 세로형 모바일 3D 액션 서바이벌 RPG입니다. 기존 전투·이동·저장 시스템을 유지하면서 캐릭터, 던전, 장비, 성장, UI를 데이터 기반으로 확장합니다.

## 문서 시작점

- 개발 규칙: `AGENTS.md`
- 게임 규칙: `docs/GAME_DESIGN.md`
- UI 흐름과 화면 규격: `docs/UI_UX_SPEC.md`
- 데이터 구조: `docs/DATA_SCHEMA.md`
- 구현 현황: `docs/IMPLEMENTATION_STATUS.md`
- 문서와 대화 기록 규칙: `docs/DOCUMENTATION_RULES.md`
- 합의된 대화 기록: `docs/CHAT_HISTORY.md`

## 실행 환경

- Engine: Godot 4.x
- 기본 화면: 세로형 모바일, 기준 해상도 1080×1920
- 대상: Android 우선, PC 테스트 지원

## 작업 원칙

기존 씬, 스크립트, 데이터, 저장 호환성을 우선 보존합니다. 새 기능은 기존 시스템과 연결하고, 미구현 기능은 명확히 표시합니다.
