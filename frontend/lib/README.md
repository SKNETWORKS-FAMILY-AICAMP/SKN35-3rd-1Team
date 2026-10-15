# Flutter 소스 구조

2026-10-15 · dev `6f0b40a` 기반 lsh 정리.

| 위치 | 책임 |
| --- | --- |
| `main.dart`, `config.dart` | 앱 시작·해시 라우팅·빌드 설정 |
| `api/` | 요청·응답·Firebase Bearer·SSE·오류 |
| `auth/` | Firebase SDK·세션·이메일/Google |
| `conversations/` | 도슨트와 컬렉션 대화·진행 상태·계정 변경 |
| `pages/` | 탐색·작품/작가 상세·피드·컬렉션 페이지 |
| `ui/` | 공통 테마·버튼·이미지·채팅·캘린더·계정 패널 |
| `state*.dart` | 앱 데이터·요청 캐시·개인 기록·컬렉션·SNS 상태 |
| `models.dart`, `diary.dart`, `mypage.dart`, `social.dart` | API 응답 모델 |

React·Vite 소스는 제거했습니다. UI는 API를 직접 반복 구현하지 않고 상태와 `api/`를 통해 호출합니다. 개인 요청은 계정 변경 이후 응답을 버리고, 쓰기는 서버 소유권 검사를 거칩니다.

컬렉션 도우미는 요청→읽기 전용 제안→사용자 확인→CRUD로 저장합니다. 외부 MCP와 같은 서버 서비스를 쓰지만 브라우저에서 MCP를 직접 호출하지 않습니다. 전체 실행은 [프론트 README](../README.md)를 참고하세요.
