# 초기 React 목업

갱신: 2026-10-15 · dev `6f0b40a` 기준. **초기 React 목업 보존 문서**입니다.

`src/`는 초기 UI 목업을 보존한 React 소스입니다. 현재 운영 서비스는 `lib/`의 Flutter Web이며 Vercel은 `src/`를 업로드에서 제외합니다.

| 실제 파일 | 목업 역할 |
| --- | --- |
| `main.tsx`, `App.tsx` | 시작·공통 레이아웃·hashchange 기반 화면 분기 |
| `pages/GalleryPage.tsx` | 작품 탐색 |
| `pages/ArtworkDetailPage.tsx` | 작품 상세·예시 도슨트 |
| `pages/ArtistsPage.tsx` | 작가 목록·상세 |
| `pages/LibraryPage.tsx` | 로컬 감상 기록 |
| `components/common/Header.tsx` | 목업 메뉴·로고 |
| `components/artwork/ArtworkCard.tsx` | 목업 작품 카드 |
| `components/chat/DocentChat.tsx` | 준비된 예시 답변 |
| `hooks/useCollection.ts` | localStorage 좋아요·작가 팔로우·열람 |
| `types/catalog.ts`, `data/` | 정적 목업 타입·카탈로그 |
| `assets/styles.css` | 목업 스타일 |

`npm run dev`·`npm run build`는 이 React 목업용이며 운영 Flutter 실행·배포 명령이 아닙니다. 별도 로그인·API 훅·서버 저장 구조가 구현됐다고 가정하지 않습니다.

## 현재 Flutter 구현

- [현재 시작·라우팅](../lib/main.dart)
- [현재 상태](../lib/state.dart)
- [현재 API](../lib/api/artlog_api.dart)
