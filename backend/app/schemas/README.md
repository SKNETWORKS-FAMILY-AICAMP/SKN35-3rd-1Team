# schemas

API 요청·응답 형식을 Pydantic 모델로 정의합니다. 공식 계약은 [API 명세](../../../docs/api.md), 경로별 응답은 `app/api/routes/`를 기준으로 확인합니다.

| 파일 | 주요 모델 |
| --- | --- |
| `catalog.py` | `Movement`, `ArtistCard/Detail`, `ArtworkCard/Detail` |
| `chat.py` | `ChatRequest`, `ChatTurn`, `ChatResponse`, `Source`, `BasisSource`, 저장 메시지·내 대화 목록 |
| `library.py` | `CalendarDay`(마지막 감상 작품 `artwork` 포함), `ViewedArtwork` |
| `recommendation.py` | 카드에 `reason`을 더한 추천 작품·작가 |
| `diary.py` | 감상평 작성·수정·응답·커서 페이지 |
| `mypage.py` | 프로필, 컬렉션 생성·수정·목록·작품 페이지, 자동/AI 테마, 활동, 취향 소개, 채팅 제안 |
| `social.py` | 공개 회원 카드·프로필·팔로우 목록 공개 설정 |

카탈로그·좋아요·팔로우·채팅 목록은 JSON 배열입니다. 월별 내 다이어리는 배열입니다. 공개 피드·내 감상평 페이지(`/me/critiques`)·컬렉션 작품 목록은 `{items, next_cursor}` 커서 페이지이며, 자동 컬렉션 상세는 `{collection, items}`, AI 테마 갱신은 `{items, message}`입니다. 카탈로그에는 페이지네이션이 없고 목록별 규칙은 API 명세를 따릅니다.

채팅 요청은 `question`(1~500자), `history`(최대 12개), 선택 `explanation_style`(`easy|standard|deep`)입니다. 로그인 여부와 관계없이 요청 history로 맥락을 받으며 서버 저장 기록은 대화 복원에도 사용합니다. 답변은 `answer`·`refused`·`sources`와 선택 `suggestion`을 반환합니다. 출처는 검색된 문서의 메타데이터만 사용합니다.

작품 카드에 `is_liked`·`is_followed`는 없습니다. 로그인 후 `/api/me/likes`·`/api/me/follows`로 확인합니다. 공개 회원 식별자는 내부 사용자 ID 대신 `public_id`를 사용합니다. DB 모델·임베딩·Firebase UID는 응답에 노출하지 않습니다.

API 변경 시 스키마·라우트·공식 명세를 함께 갱신합니다. 현재 저장소에는 OpenAPI 계약을 고정하는 `test_api.py`가 없습니다.
