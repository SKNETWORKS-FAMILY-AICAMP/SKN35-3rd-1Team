# 최신 ERD와 프론트 연결 점검

점검일: 2026-10-13 · 작업 브랜치: `lsh` · 원격 조회 후 dev: `a7a5fbe`

## 확인 기준

[ERD 원본](../../docs/db/00_erd.mmd)의 15개 테이블과 [DB 설계](../../docs/db/db-design.md), 실제 SQLAlchemy 모델·Alembic `20261012_0005`까지의 마이그레이션, [API 계약](../../docs/api.md)과 서비스 구현을 대조했습니다. 이번 조회에서 dev의 ERD 변경은 없었습니다. 소스 수정은 `frontend/` 안으로 제한했습니다.

ERD 컬럼이 있다는 이유만으로 프론트가 DB를 직접 조회하지 않습니다. API 응답으로 제공된 필드를 사용하고, 인증 사용자 ID는 서버가 검증 토큰에서 결정합니다.

## 테이블별 화면 대응

| ERD | API·화면 반영 | 확인·수정 |
| --- | --- | --- |
| `users.firebase_uid` UNIQUE | Firebase SDK → ID 토큰 → 서버의 사용자 매핑 | UID·user_id를 임의 요청 본문에 넣지 않음. 계정 변경 시 이전 요청·화면 데이터 분리 |
| `art_movements`, `artists`, `artworks` | 목록·상세·필터·작가 이동 | 작품의 `movement_id` 기준으로 필터. nullable 사조·이미지는 미분류·대체 표시. 숫자 ID로 API 호출 |
| `artworks.is_featured` | 큐레이터 대표 작품과 추천순 | API 첫 행을 대표 작품으로 가정하던 처리를 수정. featured 작품을 먼저 표시하며 그룹 안 서버 순서를 유지. featured가 없으면 기존 순서 사용 |
| `artwork_likes`, `artist_follows` 복합 PK | 좋아요·팔로우, 서재 목록, 추천 갱신 | PUT/DELETE 204 처리. 변경 완료 전 중복 클릭 방지. 사용자 변경 중 이전 응답 반영 차단 |
| `artwork_views` PK(`user_id`, `viewed_on`, `artwork_id`) | 열람 POST, 감상 캘린더·날짜별 작품 | 같은 날 같은 작품의 **재방문도 POST**하도록 수정. 동시에 진행 중인 같은 요청만 중복 억제. 일반 화면 재빌드는 재방문으로 세지 않음 |
| `artwork_views.view_count` | 날짜별 작품의 ‘이날 N회 감상’ | 응답 `view_count` 보존·표시. `artwork_count`(서로 다른 작품 수)와 `total_views`(반복 포함 횟수)를 분리해 달력과 월별 감상 횟수에 사용 |
| `chat_sessions` UNIQUE(`user_id`, `artwork_id`) | 작품별 대화 복원·이어보기·초기화 | 사용자별 작품 하나에 대화 하나. 임의 새 세션 생성 API를 호출하지 않음 |
| `chat_messages.role/content/refused/sources` | 저장 대화, 범위 밖 안내, 출처 모달 | 오래된 순서를 유지. 출처는 저장된 JSON 스냅샷 사용. DB의 NULL sources는 서비스가 `[]`로 변환하는 현재 API 계약을 따름 |
| `documents`, `document_basis_documents`, `basis_external_sources` | 답변 출처 원문·라이선스와 편집 보강 근거 | 원문과 보강 근거를 분리해 표시하는 선택 필드 `basis_sources` 지원. 필드가 없으면 기존 화면 유지 |
| `document_artists`, `document_artworks`, `document_chunks`, `artwork_embeddings` | 검색 범위·유사 작품·맞춤 추천 | 검색·벡터 계산은 서버에서 수행. API 추천 결과와 이유를 사용하며 프론트에 DB·벡터 비밀값을 넣지 않음 |

서울 날짜 경계는 서버의 `viewed_on`/`date` 응답을 따릅니다. 대화 시각은 서비스가 명시적인 UTC offset을 반환하고 프론트가 서울 시각으로 표시합니다.

## dev에 아직 없는 추가 계약

원격 `taemin`의 `3f927e3`에는 `Source.basis_sources` 선택 필드가 추가되어 있습니다. 최신 편집 근거 데이터와 ERD의 문서 근거 연결을 놓치지 않도록 **프론트의 선택 응답 지원만** 반영했습니다. 해당 브랜치 전체나 백엔드를 병합하지 않았으며, dev 서버가 이 필드를 제공한다고 가정하지 않습니다. `{source_name, source_url}` 배열을 받으면 원문 아래에 ‘편집 보강 근거’로 표시하고, 이름만 있는 근거는 링크 없이 표시합니다.

## 온보딩과 서버 후속 작업

- 현재 `users`에는 나이·성별·설명 스타일 컬럼이 없습니다. 별도 프로필 테이블·저장 API도 없습니다. 온보딩 정보는 UID별 브라우저 저장을 유지합니다.
- 나이대 enum을 임의로 나이 숫자나 생년월일로 변환하거나 `nickname`·chat history에 넣지 않습니다. 프로필 서버 저장과 설명 스타일 적용은 ERD 확장·마이그레이션·API 계약을 먼저 확정해야 합니다.
- 현재 도슨트 POST는 501이며 검색·답변 생성 및 `save_exchange` 연결은 서버 후속 작업입니다.
- `backend/app/db/ERD_설명.md`의 마지막 FAQ에 ‘채팅 내용 저장 구조가 없다’는 과거 설명이 남아 있습니다. 현재 ERD·모델·마이그레이션 `20261012_0004`에는 채팅 테이블 2개가 있으므로 프론트는 실제 구현을 기준으로 연결했습니다. 원문 문서는 이번 프론트 수정 범위 밖이라 담당자에게 정정 사항을 인계합니다.

## 검증

반복 열람과 동시 중복 호출, 화면 재빌드·재방문, 상세 로딩 실패 후 재시도, 작품 수/감상 횟수 구분, 보강 근거의 링크 유무·생략 호환을 검사합니다. 재방문 검증 중 발견된 화면 전환의 스크롤 제약과 Future를 반환하던 재시도 콜백도 함께 수정했습니다. 화면별 스크롤을 두고 오류 재시도 시 실제 재요청이 수행되도록 했습니다.

운영 DB의 마이그레이션 적용 여부·두 사용자 간 저장 분리·실제 Google 로그인 성공은 별도 운영 통합 검증 사항입니다. 이번 작업에서 Railway나 TiDB를 변경하지 않았습니다. 최종 검사·배포 기록은 [검증 기록](../verification/README.md), 팀 전달 문구는 [인수인계](frontend-handoff.md)를 참고하세요.
