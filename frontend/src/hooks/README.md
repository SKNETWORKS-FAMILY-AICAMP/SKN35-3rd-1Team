# 목업 로컬 기록 훅

갱신: 2026-10-15 · dev `6f0b40a` 기준. **초기 React 목업 보존 문서**입니다.

실제 훅은 `useCollection.ts`입니다. localStorage에 좋아요·작가 팔로우·열람을 저장하며 같은 작품의 같은 날 목업 열람은 중복 저장하지 않습니다.

이전 `useChat`, `useLibraryCalendar`, `useRecommendations` 등은 구현된 서버 훅이 아닙니다. 운영 Flutter는 `ArtlogState`와 `DocentConversation`을 사용합니다. 실제 서버 열람은 나중 재방문도 기록하며 목업과 집계 의미가 다릅니다.

## 현재 Flutter 구현

- [현재 상태·요청 캐시](../../lib/state.dart)
- [현재 대화 상태](../../lib/docent_conversation.dart)
