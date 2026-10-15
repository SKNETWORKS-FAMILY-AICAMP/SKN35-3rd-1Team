# 마이페이지 검증 (2026-10-14)

로컬 dev, Flutter 3.47.2 / Dart 3.13.2. 운영 반영 전 코드 검증입니다.

- Flutter 전체 테스트: 98개 통과.
- Flutter 분석: 이슈 없음.
- release 웹 빌드(미리보기): 성공, 34.2초.
- 백엔드 전체 테스트: 308개 통과, 경고 없음.
- Ruff: 통과. Git 공백 검사: 통과.
- Alembic 0001 → 0008 오프라인 SQL 생성 성공. 실제 DB에는 적용하지 않음.
- 모델 기준 ERD: 20테이블, Mermaid/PNG/SVG 재생성.
- 실제 MCP initialize / tools/list / tools/call과 소유권 거절을 TestClient·격리 SQLite로 검증.
- 320/1280px 위젯 테스트에서 설정 저장, 순서 변경, 컬렉션 생성·검색·담기 확인.
- 로컬 브라우저에서 컬렉션 ‘고요한 풍경’ 생성, 수련 담기, 새 탭에서 1점 유지 확인. 우선순위 변경·전문용어 스타일 저장과 390×844 레이아웃 확인. 브라우저 확인용 데이터는 로컬 미리보기에만 저장됨.
- 실제 Firebase 계정 두 개·운영 TiDB·Chroma·유료 모델을 연결한 통합 검증은 수행하지 않음. AI 생성 테스트는 가짜 모델 응답으로 수행하고 미리보기는 실제 AI 호출을 하지 않음.

| 파일 | 내용 |
| --- | --- |
| overview-desktop.jpg | 마이페이지, 다섯 탭, AI 소개 근거 |
| collection-artwork.jpg | 컬렉션 안 작품 검색·담기 결과 |
| settings-desktop.jpg | 이전 3단계 설정 화면 기록. 현재는 설명 순서 선택을 제거하고 생년월일·대화 스타일만 표시 |
| overview-mobile.jpg | 390×844 마이페이지 |
| settings-mobile.jpg | 모바일 설정 진입 |

최신 기능과 운영 반영 절차는 [인수인계](../../../docs/mypage-and-collections-2026-10-14.md)를 참고합니다.
