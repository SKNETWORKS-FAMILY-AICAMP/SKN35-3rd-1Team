# ERD와 프론트엔드 연결

갱신: **2026-10-15 · dev `6f0b40a` 기준**. SQLAlchemy 모델·API·Flutter 호출을 대조했습니다.

## 기준

서비스 모델은 **22테이블**, Alembic head는 **`20261014_0011`**입니다. 0009의 사용자 팔로우, 0010의 작품별 감상, 0011의 AI 테마 캐시를 포함합니다. [기존 ERD 원본](../../docs/db/00_erd.mmd)과 [DB 설계](../../docs/db/db-design.md)에 이전 20테이블 표기가 남아 있을 수 있어 최신 수치는 실제 [모델](../../backend/app/models)·[마이그레이션](../../backend/alembic/versions)을 우선합니다. 이 문서 갱신은 운영 DB migration 적용을 수행하거나 보장하지 않습니다.

프론트는 DB에 직접 연결하지 않고 인증된 API를 사용합니다. 실제 엔드포인트는 [호출 표](endpoints.md)를 참고하세요.

## 테이블별 화면·계약 대응

| 영역 | 테이블 | 프론트 사용 |
| --- | --- | --- |
| 계정 | `users` | Firebase UID로 서버 사용자 매핑. 공개 프로필에는 `public_id`·닉네임 사용 |
| 계정 | `social_accounts` | 외부 공급자 연결 저장 구조. Flutter Google 로그인은 Firebase SDK를 사용하며 이 테이블을 직접 조작하지 않음 |
| 계정 | `user_preferences` | 프로필 어댑터·AI 취향 소개 캐시. 현재 회원정보 편집/온보딩 폼은 없음 |
| 카탈로그 | `art_movements` | 사조 필터 |
| 카탈로그 | `artists` | 작가 목록·상세·사진·좋아요 |
| 카탈로그 | `artworks` | 작품 목록·상세·출처·`is_featured` 대표 순서 |
| 카탈로그 | `artwork_embeddings` | 서버 유사/맞춤 추천에 사용. 벡터는 프론트에 보내지 않음 |
| 활동 | `artwork_likes` | 좋아요·취소·좋아요 모음·추천 갱신 |
| 활동 | `artist_follows` | 작가 좋아요·관심 작가 |
| 활동 | `artwork_views` | 상세 열람 기록, 서울 날짜 캘린더·자동 컬렉션 |
| 활동 | `user_follows` | 감상가 팔로우·팔로잉/팔로워 목록 |
| 감상 | `diary_entries` | 공개 피드·작품별 감상·내 기록, 공개/비공개·수정·삭제 |
| 컬렉션 | `collections` | 직접 저장 모음의 목록·제목·설명 |
| 컬렉션 | `collection_items` | 작품 추가·중복 방지·꺼내기·순서 |
| 대화 | `chat_sessions` | 사용자·작품별 대화 복원·초기화 |
| 대화 | `chat_messages` | 질문·답변·`refused`·출처 스냅샷 복원 |
| AI 테마 | `theme_collection_cache` | 사용자별 테마·신호 지문·생성 시각·시도 시각. 일반 저장 모음과 구분 |
| RAG | `documents` | 답변 원문 출처·라이선스 |
| RAG | `document_artists` | 작가별 자료 검색 범위, 서버 처리 |
| RAG | `document_artworks` | 작품별 자료 검색 범위, 서버 처리 |
| RAG | `document_basis_documents` | 선택 응답 `basis_sources`의 편집 보강 근거 |
| RAG | `document_chunks` | 서버 검색·근거 구성. 프론트는 최종 답변 출처 표시 |

## 식별자·권한

- 개인 사용자 ID는 검증된 Firebase 토큰에서 서버가 결정합니다. 클라이언트가 UID/user_id를 임의로 본문에 넣지 않습니다.
- 감상 삭제는 `entry_id`, 작품은 DB 숫자 ID, 공개 감상가 경로는 `public_id`를 사용합니다.
- 컬렉션·감상·대화 소유권은 서버에서 검사합니다. 프론트의 버튼 숨김과 계정 변경 시 화면 초기화만으로 권한을 보장하지 않습니다.
- 팔로우 목록 비공개 설정은 `users.follow_list_public`에 대응합니다. 서버가 숨긴 수치는 임의로 0으로 꾸며 표시하지 않습니다.

## 프로필·감상 계약

`user_preferences`의 `birth_date`, `conversation_style`, `onboarding_completed`는 GET/PUT `/me/profile` 어댑터에 연결돼 있습니다. 현재 화면에는 해당 입력 폼이 없습니다. `birth_year`, `gender`, `tone`, `explanation_level`, `explanation_priorities` 같은 이전 필드를 현재 필수 입력으로 설명하지 않습니다. AI 취향 소개는 같은 테이블의 `taste_summary`·fingerprint·생성 시각을 사용합니다.

0010 이후 작품 연결 감상은 사용자·작품당 한 편이며 하루 여러 편을 허용합니다. 작품 없는 감상도 `entry_id` 기준으로 수정·삭제합니다. 서버 날짜는 서울 기준 문자열을 따르고, offset이 있는 대화 시각은 서울 시각으로 표시합니다. 캘린더의 `artwork_count`와 반복 열람을 포함한 `total_views`/`view_count`는 다른 값입니다.

## 컬렉션·출처

사용자가 저장할 때 `collections`·`collection_items`가 생성되며 최대 10모음·각 30점입니다. 최근/반복/작가/월별 자동 모음과 AI 테마 캐시는 직접 저장한 모음과 다릅니다. AI 테마는 관심 신호 변경과 최소 30분 간격을 기준으로 재생성합니다.

답변의 `sources`는 저장된 출처 스냅샷이며 `basis_sources`는 편집 보강 근거입니다. 원문과 보강 근거를 같은 출처라고 합치지 않습니다. 검색 청크·임베딩·모델 내부 점수는 서버에서 관리합니다.
