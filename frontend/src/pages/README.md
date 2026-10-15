# 목업 화면

갱신: 2026-10-15 · dev `6f0b40a` 기준. **초기 React 목업 보존 문서**입니다.

현재 이 폴더의 React 화면은 `GalleryPage.tsx`, `ArtworkDetailPage.tsx`, `ArtistsPage.tsx`, `LibraryPage.tsx`입니다. `LoginPage.tsx`, `SignupPage.tsx`는 구현 파일이 아닙니다.

현재 운영 경로는 Flutter의 `/gallery`, `/artworks`, `/artwork/{id}`, `/artist/{id}`, `/community`, `/library`, `/user/{public_id}`, `/collection/{id}`, `/collection/auto/{key}`입니다. 로그인은 대화상자, 설정은 사이드 패널입니다. 이전 `/mypage`·`/settings`는 `/library`로 이동합니다.

## 현재 Flutter 구현

- [현재 라우팅](../../lib/main.dart)
- [현재 Flutter 페이지](../../lib/pages)
- [화면별 기능표](../../README.md)
