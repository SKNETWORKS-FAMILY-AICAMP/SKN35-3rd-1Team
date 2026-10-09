# api/routes

엔드포인트를 기능별 파일로 나눕니다. 아래 표는 초안이며, 팀에서 확정한 명세는 `docs/`에 둡니다.

## 파일과 엔드포인트 (초안)

| 파일 | 메서드와 경로 | 설명 | 로그인 |
| --- | --- | --- | --- |
| `auth.py` | `POST /api/auth/signup` | 회원가입 | |
| | `POST /api/auth/login` | 로그인, 토큰 발급 | |
| `movements.py` | `GET /api/movements` | 사조 목록 | |
| `artists.py` | `GET /api/artists` | 작가 목록 (`movement_id` 필터) | |
| | `GET /api/artists/{artist_id}` | 작가 상세 | |
| `artworks.py` | `GET /api/artworks` | 작품 목록 (`artist_id`, `movement_id` 필터) | |
| | `GET /api/artworks/{artwork_id}` | 작품 상세 | |
| `chat.py` | `POST /api/artworks/{artwork_id}/chat` | 작품 도슨트 질문. 답변과 출처 반환 | |
| `likes.py` | `PUT /api/artworks/{artwork_id}/like` | 좋아요 (여러 번 호출해도 결과 동일) | 필요 |
| | `DELETE /api/artworks/{artwork_id}/like` | 좋아요 취소 | 필요 |
| | `GET /api/me/likes` | 내가 좋아요한 작품 | 필요 |
| `follows.py` | `PUT /api/artists/{artist_id}/follow` | 팔로우 | 필요 |
| | `DELETE /api/artists/{artist_id}/follow` | 팔로우 취소 | 필요 |
| | `GET /api/me/follows` | 내가 팔로우한 작가 | 필요 |
| `library.py` | `POST /api/artworks/{artwork_id}/views` | 열람 기록 남기기 | 필요 |
| | `GET /api/me/library/calendar?month=2026-10` | 날짜별 열람 작품 수 | 필요 |
| | `GET /api/me/library/days/{date}` | 그날 본 작품 목록 | 필요 |
| `recommendations.py` | `GET /api/artworks/{artwork_id}/similar` | 이 작품과 비슷한 작품 3개 | |
| | `GET /api/me/recommendations/artworks` | 좋아요 기반 맞춤 작품 3개 | 필요 |
| | `GET /api/me/recommendations/artists` | 추천 작가 3명 | 필요 |

## 규칙

- 좋아요와 팔로우는 `PUT`/`DELETE`로 둡니다. 같은 요청이 두 번 와도 결과가 같아서 프론트가 재시도하기 쉽습니다.
- 사용자 id는 URL로 받지 않고 토큰에서 꺼냅니다. `/api/me/...` 경로를 쓰는 이유입니다.
- 챗봇 응답에는 답변 본문과 함께 출처 목록이 반드시 포함됩니다. 형식은 `schemas/README.md`를 따릅니다.
- 맞춤 추천은 좋아요가 없는 사용자에게도 빈 배열이 아니라 대체 추천을 돌려줍니다. 분기는 서비스가 합니다.
