# 통합 dev ERD와 프론트 연결 점검

> 2026-10-14 현재: Alembic head 0008, 서비스 모델·ERD 20테이블입니다. user_preferences의 birth_date·explanation_priorities·conversation_style·onboarding_completed·AI 소개 캐시, diary_entries, collections, collection_items를 API에 연결했습니다. 프로필 서버 저장과 도슨트 개인화를 구현했고, 나이대를 생년월일로 추정하지 않습니다. 아래 17테이블/501 표기는 이전 통합 스냅샷이며 [최신 인수인계](../../docs/mypage-and-collections-2026-10-14.md)를 참고합니다.


최종 갱신: 2026-10-13 · 기준: 모든 팀 브랜치를 병합한 dev

## 확인 기준

[최신 ERD](../../docs/db/00_erd.mmd), [DB 설계](../../docs/db/db-design.md), SQLAlchemy 모델과 Alembic `20261013_0006`, [API 계약](../../docs/api.md)을 대조했습니다. 최신 구조는 **서비스 테이블 17개**입니다. 이전 lsh 작업 시점의 15개 구조에 `social_accounts`·`user_preferences`가 추가되었습니다.

ERD 컬럼이 있어도 API 없이 DB에 직접 접근하지 않습니다. 토큰에서 사용자를 결정하는 서버 API를 통해 연결합니다.

## 화면 대응

| 테이블·컬럼 | 화면 대응·상태 |
| --- | --- |
| users.firebase_uid | 검증된 Firebase ID 토큰으로 서버 사용자 매핑. UID/user_id를 클라이언트 요청 본문에 넣지 않음 |
| social_accounts | 공급자별 외부 계정 연결용 저장 구조. 기존 Firebase UID 인증 유지. 프론트의 Google SDK 로그인과 별개로 서버 연결 정책은 후속 확인 |
| user_preferences | birth_year·gender·tone·explanation_level 저장 구조 준비. 조회/수정 API 미구현으로 온보딩은 UID별 브라우저 저장 유지 |
| art_movements, artists, artworks | 작품의 movement_id로 필터. 숫자 ID로 상세 조회. nullable 사조·이미지는 대체 표시 |
| artworks.is_featured | 대표 작품과 큐레이터 순서. 같은 featured 그룹 안 서버 순서 유지 |
| artwork_likes, artist_follows | 복합 PK에 맞춘 PUT/DELETE·중복 변경 억제·계정별 서재·추천 갱신 |
| artwork_views | 사용자·서울 날짜·작품별 행. 재방문도 POST하고 동시 호출만 중복 억제. artwork_count와 total_views·view_count 구분 |
| chat_sessions | 사용자·작품당 하나의 대화를 복원·이어보기·초기화 |
| chat_messages | role·content·refused·sources JSON 복원. 출처는 저장 스냅샷 사용. 서버가 NULL sources를 []로 변환 |
| documents, document_basis_documents | 원문·라이선스와 basis_sources 편집 보강 근거를 구분해 표시. 공통 API 계약에 포함됨 |
| document_artists, document_artworks, document_chunks, artwork_embeddings | 검색 범위·벡터 계산은 서버 수행. 프론트는 검색 답변과 유사/맞춤 추천 API를 사용 |

서울 감상 날짜는 서버 date 응답을 따르고 명시적 UTC offset의 대화 시각은 서울 시각으로 표시합니다.

## 프로필 계약의 남은 차이

프론트는 age_range·gender·explanation_style, DB는 birth_year·gender·tone·explanation_level입니다. 나이대를 임의의 출생연도로 바꾸지 않습니다. 선택형 출생연도 입력 또는 age_range 스키마 확장 중 무엇을 쓸지 결정한 다음 API·UI를 연결해야 합니다. enum 허용 값과 NULL·초기 설정·수정 정책도 함께 확정합니다.

최신 DB 설명 문서에서는 예전의 채팅 저장 관련 FAQ도 정정됐습니다. 실제 도슨트 POST는 아직 501이므로 검색/답변 생성 및 save_exchange 연결이 남아 있습니다. 이번 통합에서 운영 DB를 변경하지 않았습니다.

## 검증·담당

통합 프론트 테스트 81개와 Flutter 분석, 백엔드 279개와 Ruff, 배포 스크립트 4개 검사를 통과했습니다. 반복 열람, 화면 재방문·상단 메뉴, 재시도, 작품 수/감상 횟수, 출처·보강 근거 호환을 포함합니다.

최신 통합 이력·검수 대기 자료·담당별 남은 작업은 [dev 통합·분담표](../../docs/integration-and-task-board-2026-10-13.md), 프론트 사용·배포 기록은 [인수인계](frontend-handoff.md)를 참고하세요.
