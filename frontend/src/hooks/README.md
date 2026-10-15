# hooks

조회·변경 로직과 캐시 관리를 커스텀 훅으로 분리합니다.

## 들어갈 파일

| 훅 | 하는 일 |
| --- | --- |
| `useArtworks`, `useArtwork` | 작품 목록·상세 조회 |
| `useArtists`, `useArtist` | 작가 목록·상세 조회 |
| `useLikeToggle` | 좋아요 등록·취소. 화면 즉시 반영, 실패 시 되돌림, 추천 캐시 무효화 |
| `useFollowToggle` | 팔로우 등록·취소. 추천 작가 캐시 무효화 |
| `useChat` | 대화 이력 보관, 질문 전송, 답변과 출처 추가 |
| `useRecordView` | 작품 상세에 들어왔을 때 열람 기록을 한 번 남김 |
| `useLibraryCalendar` | 월별 캘린더와 하루 상세 조회 |
| `useRecommendations` | 비슷한 작품, 맞춤 작품, 추천 작가 조회 |

## 규칙

- 좋아요가 바뀌면 맞춤 추천이 달라집니다. `useLikeToggle`이 성공한 뒤 추천 조회를 다시 불러오게 합니다.
- `useRecordView`는 화면이 다시 그려질 때마다 호출되지 않도록 작품 id가 바뀔 때만 실행합니다. 서버가 같은 날 중복을 합쳐 주지만 불필요한 요청은 줄입니다.
- 훅은 `api/`의 함수를 호출합니다. 훅 안에서 주소를 직접 쓰지 않습니다.
