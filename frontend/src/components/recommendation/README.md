# recommendation components

추천 결과를 보여 주는 컴포넌트를 둡니다.

## 들어갈 파일

- `SimilarArtworks.tsx`: 작품 상세의 "이 작품과 비슷한 작품" 3개. 로그인 없이도 표시
- `RecommendedArtworks.tsx`: 좋아요 기반 맞춤 작품 3개
- `RecommendedArtists.tsx`: 추천 작가 3명

## 규칙

- 추천 점수 계산은 FastAPI가 합니다. 프론트는 받은 순서대로 보여 주기만 합니다.
- 작품과 작가 표시는 `artwork/ArtworkCard`, `artist/ArtistCard`를 재사용합니다.
- 좋아요가 없는 사용자에게도 서버가 대체 추천을 돌려주므로, 빈 결과 화면은 오류 대비용으로만 둡니다.
- 좋아요를 누른 뒤 추천이 새로 불러와져야 합니다. 갱신은 `hooks/`의 좋아요 훅이 추천 캐시를 무효화해서 처리합니다.
