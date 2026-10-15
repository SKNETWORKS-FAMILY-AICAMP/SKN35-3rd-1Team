# 목업 작가 구성 계획

갱신: 2026-10-15 · dev `6f0b40a` 기준. **초기 React 목업 보존 문서**입니다.

이 폴더에는 별도 React 작가 컴포넌트 구현이 없습니다. 초기 목업의 작가 화면은 `src/pages/ArtistsPage.tsx`에 있습니다.

현재 Flutter는 작품 리스트의 작가 탭과 작가 상세를 사용합니다. 작가 하트는 `/artists/{id}/follow`의 PUT/DELETE로 연결되고 관심 작가는 내 피드에서 표시합니다.

## 현재 Flutter 구현

- [현재 작가 탭](../../../lib/pages/artworks_page.dart)
- [현재 작가 상세](../../../lib/pages/artists_page.dart)
