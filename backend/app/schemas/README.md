# schemas

API 요청과 응답의 형식을 Pydantic 모델로 정의합니다. 프론트엔드의 `src/types/`와 필드 이름을 맞춥니다.

## 들어갈 파일

- `catalog.py`: `Movement`, `ArtistCard`/`ArtistDetail`, `ArtworkCard`/`ArtworkDetail`
- `chat.py`: `ChatRequest`(`question`, `history`), `ChatResponse`, `Source`, 저장 기록 `ChatMessageOut`, 내 대화 목록 `ChatSummary`
- `library.py`: `CalendarDay`(`date`, `artwork_count`, `total_views`), `ViewedArtwork`(작품 카드 + `view_count`, `last_viewed_at`)
- `recommendation.py`: `RecommendedArtwork`, `RecommendedArtist` (카드에 `reason`을 더한 평평한 형태)

로그인은 Firebase Auth라 인증 요청·응답 스키마는 없습니다. 좋아요·팔로우·열람·대화 초기화는 `204` 본문 없음입니다.

## 공통 계약 (2026-10-12 확정)

- **목록은 JSON 배열**을 그대로 반환합니다. `{items: ...}` 같은 래퍼를 쓰지 않습니다.
- **페이지네이션 없음.** 작품 219점·작가 8명 규모입니다. 규모가 커지면 기존 응답을 깨지 않도록 `?limit=&offset=` 쿼리를 추가하거나 별도 페이지네이션 계약(`/v2`)을 둡니다.
- **오류는 FastAPI 기본 형식** `{"detail": ...}`입니다. 인증 실패는 `401` + `WWW-Authenticate: Bearer`, 입력 검증 실패는 `422`입니다.
- 계약은 `tests/test_api.py`가 OpenAPI 기준으로 고정합니다. 스키마를 바꾸면 이 테스트도 함께 고칩니다.

## 미리 정해 둘 응답 형식

**챗봇 응답**에는 다음이 들어갑니다.

- `answer`: 답변 본문
- `refused`: 근거 문서가 없어 답변을 거절했는지 여부
- `sources`: 근거 목록. 항목마다 `document_id`, `title`, `doc_type`, `source_name`, `source_url`

**챗봇 요청**에는 `question`(1~500자)과 `history`(직전 메시지 최대 12개, 항목은 `{role: user|assistant, content}`)가 들어갑니다. 답변 맥락은 로그인 여부와 관계없이 요청의 `history`로 받습니다. 로그인 사용자의 질문과 답변은 서버에도 저장해 대화를 복원할 때 씁니다(`chat_sessions`, `chat_messages`).

**추천 응답** 항목은 카드 필드에 `reason`(예: 어떤 좋아요 작품과 비슷해서 추천됐는지, 없으면 `null`)을 더한 형태입니다.

## 규칙

- DB 모델을 그대로 반환하지 않습니다. `firebase_uid`나 `embedding`이 실수로 노출되는 것을 막습니다.
- 목록용(카드)과 상세용 스키마를 나눕니다. 목록 응답에 긴 설명을 싣지 않습니다.
- 작품 카드에는 로그인 사용자의 좋아요 여부(`is_liked`)를 포함할지 팀에서 정합니다. 포함하면 프론트의 추가 호출이 줄어듭니다.
